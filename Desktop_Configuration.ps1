#requires -RunAsAdministrator
<#
.SYNOPSIS
    Automated configuration script for Desktop PCs
    
.DESCRIPTION
    This script performs the following tasks in order:
    1. Creates a 250GB partition on disks with 800GB or more capacity
    2. Configures static IP address (IPv4: 192.168.130.X and IPv6: 2401:dd00:79:c002::X with user input)
    3. Sets timezone to Sri Lanka Standard Time (UTC+05:30)
    4. Backs up files from parent directory to the newly created partition (NO log files)
    5. Renames the local "HP" administrator account to "Admin" (if "Admin" doesn't already exist)
    6. Sets the "Admin" account password to "12345"
    7. Falls back to renaming built-in Administrator if "HP" account not found
    
.NOTES
    - Must be run as Administrator
    - Designed for HP ProDesk 280 G9 with Windows 11 Pro
    - Partition creation only occurs on disks 800GB or larger
    - Network configuration is done BEFORE account changes to avoid security context errors
    - Admin account changes are done LAST to prevent permission issues
    - Script includes error handling and logging
    - SECURITY NOTE: Password "12345" is set for standardization. Change after deployment for production use.
    - Network settings: 
      - IPv4: Subnet 255.255.255.128, Gateway 192.168.130.1, DNS 192.168.0.10
      - IPv6: Prefix 2401:dd00:79:c002::X/64, Gateway 2401:dd00:79:c002::1
    
.AUTHOR
    https://github.com/WKVDewantha
    
.DATE
    January 2026
#>

# Set error action preference
$ErrorActionPreference = "Stop"

# Create log file
$LogPath = "C:\Logs"
$LogFile = "$LogPath\HP_Configuration_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create log directory if it doesn't exist
if (-not (Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Function to write log entries
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARNING','ERROR','SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Write to console with color
    switch ($Level) {
        'INFO'    { Write-Host $LogEntry -ForegroundColor Cyan }
        'WARNING' { Write-Host $LogEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $LogEntry -ForegroundColor Red }
        'SUCCESS' { Write-Host $LogEntry -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogEntry
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main script execution
Write-Log "========================================" -Level INFO
Write-Log "Desktop Configuration Automation Script" -Level INFO
Write-Log "========================================" -Level INFO

# Check administrator privileges
if (-not (Test-Administrator)) {
    Write-Log "This script must be run as Administrator!" -Level ERROR
    Write-Log "Please right-click and select 'Run as Administrator'" -Level ERROR
    pause
    exit 1
}

Write-Log "Administrator privileges confirmed" -Level SUCCESS

# =====================================
# STEP 1: Create 250GB Partition
# =====================================

Write-Log "Starting disk partition configuration..." -Level INFO

try {
    # Get the primary disk (usually Disk 0)
    $Disk = Get-Disk | Where-Object { $_.Number -eq 0 }
    
    if ($null -eq $Disk) {
        throw "Primary disk (Disk 0) not found!"
    }
    
    $DiskSizeGB = [math]::Round($Disk.Size/1GB, 2)
    Write-Log "Found Disk 0: $($Disk.FriendlyName) - Total Size: $DiskSizeGB GB" -Level INFO
    
    # Check if disk size is 800GB or more
    if ($DiskSizeGB -lt 800) {
        Write-Log "Disk size ($DiskSizeGB GB) is less than 800GB. Skipping partition creation." -Level WARNING
        Write-Log "Partition creation only applies to disks with 800GB or more capacity." -Level INFO
    } else {
        Write-Log "Disk size ($DiskSizeGB GB) meets requirement (800GB+). Proceeding with partition creation..." -Level INFO
        
        # Check if 250GB partition already exists
        $ExistingDataPartition = Get-Volume | Where-Object { 
            $_.FileSystemLabel -eq "Data" -and 
            $_.Size -ge 240GB -and 
            $_.Size -le 260GB 
        }
        
        if ($ExistingDataPartition) {
            Write-Log "250GB partition already exists (Drive $($ExistingDataPartition.DriveLetter):). Skipping creation." -Level SUCCESS
        } else {
            # Get maximum available space
            $CDrive = Get-Partition -DriveLetter C
            $MaxSize = (Get-PartitionSupportedSize -DiskNumber 0 -PartitionNumber $CDrive.PartitionNumber).SizeMax
            $AvailableSpaceGB = [math]::Round(($MaxSize - $CDrive.Size)/1GB, 2)
            
            Write-Log "Available unallocated space: $AvailableSpaceGB GB" -Level INFO
            
            # Check if there's enough space for 250GB partition
            if ($AvailableSpaceGB -lt 250) {
                Write-Log "Insufficient unallocated space ($AvailableSpaceGB GB). Attempting to shrink C: drive..." -Level WARNING
                
                # Calculate shrink size (250GB + buffer)
                $ShrinkSize = 250GB + 5GB  # Extra 5GB for safety
                
                # Get supported size for shrinking
                $SupportedSize = Get-PartitionSupportedSize -DriveLetter C
                $MinSize = $SupportedSize.SizeMin
                $CurrentSize = $CDrive.Size
                
                if (($CurrentSize - $ShrinkSize) -gt $MinSize) {
                    Write-Log "Shrinking C: drive by $([math]::Round($ShrinkSize/1GB, 2)) GB..." -Level INFO
                    Resize-Partition -DriveLetter C -Size ($CurrentSize - $ShrinkSize)
                    Write-Log "C: drive shrunk successfully" -Level SUCCESS
                    Start-Sleep -Seconds 5  # Wait for disk to stabilize
                } else {
                    throw "Cannot shrink C: drive enough to create 250GB partition. Available shrink space is insufficient."
                }
            }
            
            # Find next available drive letter
            $UsedLetters = Get-Volume | Select-Object -ExpandProperty DriveLetter | Where-Object { $_ -ne $null }
            $AllLetters = 68..90 | ForEach-Object { [char]$_ }  # D-Z
            $AvailableLetter = $AllLetters | Where-Object { $UsedLetters -notcontains $_ } | Select-Object -First 1
            
            if ($null -eq $AvailableLetter) {
                throw "No available drive letters found!"
            }
            
            Write-Log "Creating new 250GB partition with drive letter $AvailableLetter..." -Level INFO
            
            # Create new partition
            $NewPartition = New-Partition -DiskNumber 0 -Size 250GB -DriveLetter $AvailableLetter
            
            # Format the partition
            Write-Log "Formatting partition as NTFS..." -Level INFO
            Format-Volume -DriveLetter $AvailableLetter -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false | Out-Null
            
            Write-Log "Successfully created and formatted 250GB partition as $AvailableLetter`:" -Level SUCCESS
        }
    }
    
} catch {
    Write-Log "Error during partition creation: $($_.Exception.Message)" -Level ERROR
    Write-Log "Continuing with administrator account configuration..." -Level WARNING
}

# =====================================
# STEP 2: Configure Network Settings
# =====================================

Write-Log "Starting network configuration..." -Level INFO

try {
    # Get active network adapter (Ethernet)
    $NetworkAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -eq "802.3" } | Select-Object -First 1
    
    if ($null -eq $NetworkAdapter) {
        Write-Log "No active Ethernet adapter found. Skipping network configuration." -Level WARNING
    } else {
        Write-Log "Found active network adapter: $($NetworkAdapter.Name)" -Level INFO
        
        # Display current IP configuration
        $CurrentIP = Get-NetIPAddress -InterfaceIndex $NetworkAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                     Where-Object { $_.IPAddress -notlike "169.254.*" }  # Exclude APIPA addresses
        
        $NeedToConfigureIP = $true
        
        if ($CurrentIP -and $CurrentIP.IPAddress -like "192.168.130.*") {
            Write-Log "Current IP Address: $($CurrentIP.IPAddress)" -Level INFO
            Write-Log "Static IP is already configured in the 192.168.130.X range" -Level INFO
            
            # Ask if user wants to change the IP
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host "Existing IP Configuration Detected" -ForegroundColor Yellow
            Write-Host "========================================" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Current IP: $($CurrentIP.IPAddress)" -ForegroundColor Cyan
            Write-Host ""
            
            $ChangeIP = Read-Host "Do you want to change the IP address? (Y/N)"
            
            if ($ChangeIP -notlike "Y*" -and $ChangeIP -notlike "y*") {
                Write-Log "User chose to keep existing IP configuration" -Level INFO
                $NeedToConfigureIP = $false
            } else {
                Write-Log "User chose to change IP address" -Level INFO
            }
        } elseif ($CurrentIP) {
            Write-Log "Current IP Address: $($CurrentIP.IPAddress)" -Level INFO
        }
        
        if ($NeedToConfigureIP) {
            # Prompt for IP address
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Network Configuration" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Base IP: 192.168.130.X" -ForegroundColor Yellow
            Write-Host "Enter the last part of the IP address (e.g., 05, 10, 12, 100)" -ForegroundColor Yellow
            Write-Host ""
            
            $IPLastPart = Read-Host "Enter IP address (last digits only)"
            
            # Validate input
            if ([string]::IsNullOrWhiteSpace($IPLastPart)) {
                Write-Log "No IP address provided. Skipping network configuration." -Level WARNING
            } else {
            # Remove leading zeros and validate
            $IPLastPart = $IPLastPart.TrimStart('0')
            if ([string]::IsNullOrWhiteSpace($IPLastPart)) {
                $IPLastPart = "0"
            }
            
            # Validate it's a number
            if ($IPLastPart -notmatch '^\d+$') {
                Write-Log "Invalid IP address format. Must be numeric. Skipping network configuration." -Level ERROR
            } elseif ([int]$IPLastPart -lt 1 -or [int]$IPLastPart -gt 254) {
                Write-Log "Invalid IP address. Must be between 1 and 254. Skipping network configuration." -Level ERROR
            } else {
                # Network configuration
                $IPAddress = "192.168.130.$IPLastPart"
                $SubnetMask = "255.255.255.128"
                $PrefixLength = 25  # /25 for 255.255.255.128
                $DefaultGateway = "192.168.130.1"
                $DNSServer = "192.168.0.10"
                
                # IPv6 configuration - matches the IPv4 pattern
                $IPv6Address = "2401:dd00:79:c002::$IPLastPart"
                $IPv6PrefixLength = 64
                $IPv6Gateway = "2401:dd00:79:c002::1"
                
                Write-Log "Configuring network with the following settings:" -Level INFO
                Write-Log "  IPv4 Address: $IPAddress" -Level INFO
                Write-Log "  Subnet Mask: $SubnetMask (/$PrefixLength)" -Level INFO
                Write-Log "  Default Gateway: $DefaultGateway" -Level INFO
                Write-Log "  DNS Server: $DNSServer" -Level INFO
                Write-Log "  IPv6 Address: $IPv6Address" -Level INFO
                Write-Log "  IPv6 Gateway: $IPv6Gateway" -Level INFO
                
                # Remove existing IP configuration
                Write-Log "Removing existing IP configuration..." -Level INFO
                Remove-NetIPAddress -InterfaceIndex $NetworkAdapter.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
                Remove-NetRoute -InterfaceIndex $NetworkAdapter.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
                
                Start-Sleep -Seconds 2
                
                # Set new IPv4 address
                Write-Log "Setting new IPv4 address: $IPAddress" -Level INFO
                New-NetIPAddress -InterfaceIndex $NetworkAdapter.InterfaceIndex `
                                 -IPAddress $IPAddress `
                                 -PrefixLength $PrefixLength `
                                 -DefaultGateway $DefaultGateway `
                                 -AddressFamily IPv4 `
                                 -ErrorAction Stop | Out-Null
                
                Write-Log "IPv4 address configured successfully" -Level SUCCESS
                
                # Set new IPv6 address
                Write-Log "Setting new IPv6 address: $IPv6Address" -Level INFO
                try {
                    New-NetIPAddress -InterfaceIndex $NetworkAdapter.InterfaceIndex `
                                     -IPAddress $IPv6Address `
                                     -PrefixLength $IPv6PrefixLength `
                                     -AddressFamily IPv6 `
                                     -ErrorAction Stop | Out-Null
                    
                    Write-Log "IPv6 address configured successfully" -Level SUCCESS
                    
                    # Set IPv6 default gateway
                    Write-Log "Setting IPv6 default gateway: $IPv6Gateway" -Level INFO
                    New-NetRoute -InterfaceIndex $NetworkAdapter.InterfaceIndex `
                                 -DestinationPrefix "::/0" `
                                 -NextHop $IPv6Gateway `
                                 -AddressFamily IPv6 `
                                 -ErrorAction Stop | Out-Null
                    
                    Write-Log "IPv6 gateway configured successfully" -Level SUCCESS
                    
                } catch {
                    Write-Log "Error configuring IPv6: $($_.Exception.Message)" -Level WARNING
                    Write-Log "IPv4 configuration completed successfully. Continuing..." -Level INFO
                }
                
                # Set DNS server
                Write-Log "Setting DNS server: $DNSServer" -Level INFO
                Set-DnsClientServerAddress -InterfaceIndex $NetworkAdapter.InterfaceIndex `
                                          -ServerAddresses $DNSServer `
                                          -ErrorAction Stop
                
                Write-Log "DNS server configured successfully" -Level SUCCESS
                
                # Test connectivity
                Write-Log "Testing network connectivity..." -Level INFO
                
                Start-Sleep -Seconds 3  # Wait for network to stabilize
                
                # Test IPv4 gateway
                $GatewayTest = Test-Connection -ComputerName $DefaultGateway -Count 2 -Quiet
                if ($GatewayTest) {
                    Write-Log "IPv4 Gateway connectivity test: PASSED" -Level SUCCESS
                } else {
                    Write-Log "IPv4 Gateway connectivity test: FAILED" -Level WARNING
                }
                
                # Test DNS
                $DNSTest = Test-Connection -ComputerName $DNSServer -Count 2 -Quiet
                if ($DNSTest) {
                    Write-Log "DNS server connectivity test: PASSED" -Level SUCCESS
                } else {
                    Write-Log "DNS server connectivity test: FAILED" -Level WARNING
                }
                
                # Test IPv6 connectivity (ping IPv6 gateway)
                try {
                    $IPv6Test = Test-Connection -ComputerName $IPv6Gateway -Count 2 -Quiet -ErrorAction SilentlyContinue
                    if ($IPv6Test) {
                        Write-Log "IPv6 Gateway connectivity test: PASSED" -Level SUCCESS
                    } else {
                        Write-Log "IPv6 Gateway connectivity test: FAILED" -Level INFO
                    }
                } catch {
                    Write-Log "IPv6 connectivity test skipped" -Level INFO
                }
                
                # Test internet connectivity
                $InternetTest = Test-Connection -ComputerName "8.8.8.8" -Count 2 -Quiet -ErrorAction SilentlyContinue
                if ($InternetTest) {
                    Write-Log "Internet connectivity test: PASSED" -Level SUCCESS
                } else {
                    Write-Log "Internet connectivity test: FAILED (This may be expected)" -Level INFO
                }
            }
            }
        }
    }
    
} catch {
    Write-Log "Error during network configuration: $($_.Exception.Message)" -Level ERROR
}

# =====================================
# STEP 3: Set Timezone to Sri Lanka
# =====================================

Write-Log "Starting timezone configuration..." -Level INFO

try {
    # Get current timezone
    $CurrentTimezone = Get-TimeZone
    Write-Log "Current timezone: $($CurrentTimezone.Id) - $($CurrentTimezone.DisplayName)" -Level INFO
    
    # Sri Lanka timezone ID
    $SriLankaTimezone = "Sri Lanka Standard Time"
    
    # Check if already set to Sri Lanka timezone
    if ($CurrentTimezone.Id -eq $SriLankaTimezone) {
        Write-Log "Timezone is already set to Sri Lanka Standard Time (UTC+05:30). No changes needed." -Level SUCCESS
    } else {
        Write-Log "Setting timezone to Sri Lanka Standard Time (UTC+05:30)..." -Level INFO
        
        # Set the timezone
        Set-TimeZone -Id $SriLankaTimezone
        
        # Verify the change
        $NewTimezone = Get-TimeZone
        if ($NewTimezone.Id -eq $SriLankaTimezone) {
            Write-Log "Successfully changed timezone to: $($NewTimezone.DisplayName)" -Level SUCCESS
            Write-Log "Current time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO
        } else {
            Write-Log "Timezone change verification failed" -Level WARNING
        }
    }
    
} catch {
    Write-Log "Error during timezone configuration: $($_.Exception.Message)" -Level ERROR
}

# =====================================
# STEP 4: Backup Files
# =====================================

Write-Log "Starting backup process..." -Level INFO

try {
    # Find the newly created data partition
    $DataPartition = Get-Volume | Where-Object { 
        $_.FileSystemLabel -eq "Data" -and 
        $_.Size -gt 240GB -and 
        $_.Size -lt 260GB -and
        $_.DriveLetter -ne $null
    } | Select-Object -First 1
    
    if ($DataPartition) {
        $BackupDrive = $DataPartition.DriveLetter
        $SetupFolder = "$BackupDrive`:\setup"
        
        Write-Log "Backup location: $SetupFolder" -Level INFO
        
        # Create setup folder
        if (-not (Test-Path $SetupFolder)) {
            New-Item -Path $SetupFolder -ItemType Directory -Force | Out-Null
            Write-Log "Created backup folder: $SetupFolder" -Level SUCCESS
        } else {
            Write-Log "Backup folder already exists: $SetupFolder" -Level INFO
        }
        
        # Ask user if they want to backup files
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "File Backup to New Partition" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Source: " -NoNewline -ForegroundColor Yellow
        
        # Copy script files from current location
        $ScriptPath = $PSScriptRoot
        if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
            $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        
        if (-not [string]::IsNullOrWhiteSpace($ScriptPath) -and (Test-Path $ScriptPath)) {
            # Get parent directory (e.g., E:\Software if script is in E:\Software\HP_Desktop_Configuration)
            $ParentPath = Split-Path -Parent $ScriptPath
            
            # If the script is in a subdirectory, use the parent directory
            # Otherwise, use the script directory itself
            $SourcePath = $ParentPath
            
            # Validate the source path exists
            if ([string]::IsNullOrWhiteSpace($SourcePath) -or -not (Test-Path $SourcePath)) {
                Write-Host "$ScriptPath" -ForegroundColor White
                $SourcePath = $ScriptPath
            } else {
                Write-Host "$SourcePath" -ForegroundColor White
            }
            
            Write-Host "Destination: " -NoNewline -ForegroundColor Yellow
            Write-Host "$SetupFolder" -ForegroundColor White
            Write-Host ""
            
            # Check if files already exist in destination
            $ExistingFiles = Get-ChildItem -Path $SetupFolder -Recurse -File -ErrorAction SilentlyContinue
            $FilesExist = $ExistingFiles.Count -gt 0
            
            if ($FilesExist) {
                Write-Host "WARNING: Files already exist in the destination folder!" -ForegroundColor Yellow
                Write-Host "Existing files: $($ExistingFiles.Count)" -ForegroundColor Yellow
                Write-Host ""
            }
            
            $CopyFiles = Read-Host "Do you want to copy files to the backup location? (Y/N)"
            
            if ($CopyFiles -notlike "Y*" -and $CopyFiles -notlike "y*") {
                Write-Log "User chose to skip file backup" -Level INFO
            } else {
                Write-Log "User chose to backup files" -Level INFO
                
                # If files exist, ask about overwriting
                $OverwriteMode = "/E"  # Default: skip existing files
                
                if ($FilesExist) {
                    Write-Host ""
                    $Overwrite = Read-Host "Overwrite existing files? (Y/N)"
                    
                    if ($Overwrite -like "Y*" -or $Overwrite -like "y*") {
                        Write-Log "User chose to overwrite existing files" -Level INFO
                        $OverwriteMode = "/E /IS"  # Include same files (overwrite)
                    } else {
                        Write-Log "User chose to skip existing files" -Level INFO
                        $OverwriteMode = "/E"  # Skip existing files
                    }
                }
                
                Write-Log "Script location: $ScriptPath" -Level INFO
                Write-Log "Copying files from: $SourcePath" -Level INFO
                Write-Log "Destination: $SetupFolder" -Level INFO
            
            try {
                # Use robocopy for reliable copying of large files
                Write-Log "Using Windows robocopy for reliable file copying..." -Level INFO
                Write-Log "This may take several minutes depending on file size..." -Level INFO
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "Starting File Copy Operation" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green
                Write-Host ""
                
                # Robocopy parameters:
                # /E = Copy subdirectories, including empty ones
                # /R:3 = Retry 3 times on failed copies
                # /W:5 = Wait 5 seconds between retries
                # /MT:8 = Multi-threaded copying (8 threads)
                # /XD = Exclude directories
                # /V = Verbose output (show file names)
                # /ETA = Show estimated time
                # /BYTES = Show file sizes in bytes
                
                $RobocopyArgs = @(
                    $SourcePath,
                    $SetupFolder
                )
                
                # Add overwrite mode
                if ($OverwriteMode -eq "/E /IS") {
                    $RobocopyArgs += "/E"
                    $RobocopyArgs += "/IS"  # Include same files (overwrite)
                } else {
                    $RobocopyArgs += "/E"  # Skip existing files by default
                }
                
                # Add other parameters
                $RobocopyArgs += "/R:3"         # Retry 3 times
                $RobocopyArgs += "/W:5"         # Wait 5 seconds between retries
                $RobocopyArgs += "/MT:8"        # Multi-threaded (8 threads)
                $RobocopyArgs += "/XD"
                $RobocopyArgs += "setup"        # Exclude any existing setup folders
                $RobocopyArgs += "/V"           # Verbose (show file names)
                $RobocopyArgs += "/ETA"         # Show estimated time
                $RobocopyArgs += "/BYTES"       # Show sizes in bytes
                $RobocopyArgs += "/NP"          # No percentage (cleaner output)
                
                Write-Log "Starting robocopy operation..." -Level INFO
                Write-Host "Copying files... (Press Ctrl+C to cancel)" -ForegroundColor Yellow
                Write-Host ""
                
                # Run robocopy with visible output
                & robocopy.exe $RobocopyArgs
                
                $ExitCode = $LASTEXITCODE
                
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                
                # Robocopy exit codes: 0-7 are success, 8+ are errors
                if ($ExitCode -le 7) {
                    Write-Host "File Copy Completed Successfully!" -ForegroundColor Green
                    Write-Host "========================================" -ForegroundColor Green
                    Write-Log "Robocopy completed successfully (Exit code: $ExitCode)" -Level SUCCESS
                    
                    # Count files in destination
                    Write-Host ""
                    Write-Host "Counting files in backup location..." -ForegroundColor Cyan
                    $CopiedFiles = (Get-ChildItem -Path $SetupFolder -Recurse -File -ErrorAction SilentlyContinue).Count
                    $TotalSizeGB = [math]::Round((Get-ChildItem -Path $SetupFolder -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
                    
                    Write-Host "Total files in backup: " -NoNewline -ForegroundColor Yellow
                    Write-Host "$CopiedFiles files" -ForegroundColor White
                    Write-Host "Total size: " -NoNewline -ForegroundColor Yellow
                    Write-Host "$TotalSizeGB GB" -ForegroundColor White
                    Write-Host ""
                    
                    Write-Log "Total files in backup location: $CopiedFiles ($TotalSizeGB GB)" -Level SUCCESS
                    Write-Log "All files from $SourcePath have been backed up to $SetupFolder" -Level SUCCESS
                } else {
                    Write-Host "File Copy Completed with Warnings/Errors" -ForegroundColor Yellow
                    Write-Host "========================================" -ForegroundColor Yellow
                    Write-Log "Robocopy completed with warnings/errors (Exit code: $ExitCode)" -Level WARNING
                    Write-Log "Some files may not have been copied. Check the setup folder." -Level WARNING
                }
                
            } catch {
                Write-Log "Error during file backup: $($_.Exception.Message)" -Level ERROR
            }
            }
        } else {
            Write-Log "Could not determine script location. Skipping file backup." -Level WARNING
        }
        
    } else {
        Write-Log "Data partition not found. Skipping backup." -Level WARNING
        Write-Log "Note: Backup only occurs when 250GB partition is created." -Level INFO
    }
    
} catch {
    Write-Log "Error during backup process: $($_.Exception.Message)" -Level ERROR
}

# =====================================
# STEP 5: Rename Administrator Account
# =====================================

Write-Log "Starting administrator account configuration..." -Level INFO

try {
    # First check if "Admin" account already exists
    $AdminAccount = Get-LocalUser -Name "Admin" -ErrorAction SilentlyContinue
    $AdminAccountRenamed = $false
    
    if ($AdminAccount) {
        Write-Log "'Admin' account already exists. No renaming needed." -Level SUCCESS
        Write-Log "Account details: Name=$($AdminAccount.Name), Enabled=$($AdminAccount.Enabled)" -Level INFO
    } else {
        Write-Log "'Admin' account not found. Checking for accounts to rename..." -Level INFO
        
        # Try to find the "HP" account (common in HP computers)
        $HPAccount = Get-LocalUser -Name "HP" -ErrorAction SilentlyContinue
        
        if ($HPAccount) {
            Write-Log "Found 'HP' local administrator account" -Level INFO
            
            # Rename HP account to Admin
            Write-Log "Renaming 'HP' account to 'Admin'..." -Level INFO
            Rename-LocalUser -Name "HP" -NewName "Admin"
            Write-Log "Successfully renamed 'HP' account to 'Admin'" -Level SUCCESS
            $AdminAccountRenamed = $true
            
            # Verify the rename
            $AdminAccount = Get-LocalUser -Name "Admin" -ErrorAction SilentlyContinue
            if ($AdminAccount) {
                Write-Log "Verification successful: 'Admin' account exists" -Level SUCCESS
            }
        } else {
            Write-Log "'HP' account not found. Checking for built-in Administrator account..." -Level INFO
            
            # Get the built-in Administrator account (SID ends with -500)
            $BuiltInAdmin = Get-LocalUser | Where-Object { $_.SID -like "*-500" }
            
            if ($null -eq $BuiltInAdmin) {
                Write-Log "Built-in Administrator account not found!" -Level WARNING
                
                # List all local accounts for troubleshooting
                Write-Log "Available local user accounts:" -Level INFO
                $AllAccounts = Get-LocalUser | Select-Object Name, Enabled, Description
                foreach ($Account in $AllAccounts) {
                    Write-Log "  - $($Account.Name) (Enabled: $($Account.Enabled))" -Level INFO
                }
                
                throw "Neither 'HP' account nor built-in Administrator account found for renaming."
            }
            
            $OldName = $BuiltInAdmin.Name
            Write-Log "Found built-in Administrator account: $OldName" -Level INFO
            
            # Rename the administrator account
            Write-Log "Renaming '$OldName' to 'Admin'..." -Level INFO
            Rename-LocalUser -Name $OldName -NewName "Admin"
            
            Write-Log "Successfully renamed administrator account from '$OldName' to 'Admin'" -Level SUCCESS
            $AdminAccountRenamed = $true
            
            # Verify the rename
            $AdminAccount = Get-LocalUser -Name "Admin" -ErrorAction SilentlyContinue
            if ($AdminAccount) {
                Write-Log "Verification successful: 'Admin' account exists" -Level SUCCESS
            }
        }
    }
    
    # Set password for Admin account
    if ($AdminAccount) {
        Write-Log "Setting password for 'Admin' account..." -Level INFO
        
        try {
            # Create secure string for password
            $NewPassword = ConvertTo-SecureString "12345" -AsPlainText -Force
            
            # Set the password
            Set-LocalUser -Name "Admin" -Password $NewPassword
            
            Write-Log "Successfully set password for 'Admin' account" -Level SUCCESS
            
            # Enable the account if it's disabled
            if (-not $AdminAccount.Enabled) {
                Write-Log "'Admin' account is disabled. Enabling account..." -Level INFO
                Enable-LocalUser -Name "Admin"
                Write-Log "Successfully enabled 'Admin' account" -Level SUCCESS
            }
            
        } catch {
            Write-Log "Error setting password for 'Admin' account: $($_.Exception.Message)" -Level ERROR
        }
    }
    
} catch {
    Write-Log "Error during administrator account configuration: $($_.Exception.Message)" -Level ERROR
}

# =====================================
# Final Summary
# =====================================

Write-Log "" -Level INFO
Write-Log "========================================" -Level INFO
Write-Log "Configuration Complete!" -Level SUCCESS
Write-Log "========================================" -Level INFO
Write-Log "Log file saved to: $LogFile" -Level INFO
Write-Log "" -Level INFO

# Display system information
Write-Log "System Information:" -Level INFO
try {
    $ComputerInfo = Get-ComputerInfo -ErrorAction Stop
    Write-Log "  Computer Name: $($ComputerInfo.CsName)" -Level INFO
    Write-Log "  OS: $($ComputerInfo.OsName)" -Level INFO
    Write-Log "  OS Version: $($ComputerInfo.OsVersion)" -Level INFO
    Write-Log "  Total RAM: $([math]::Round($ComputerInfo.CsTotalPhysicalMemory/1GB, 2)) GB" -Level INFO
    Write-Log "  Processor: $($ComputerInfo.CsProcessors.Name)" -Level INFO
} catch {
    # Fallback to WMI if Get-ComputerInfo fails
    $CS = Get-WmiObject -Class Win32_ComputerSystem
    $OS = Get-WmiObject -Class Win32_OperatingSystem
    $CPU = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
    
    Write-Log "  Computer Name: $($CS.Name)" -Level INFO
    Write-Log "  OS: $($OS.Caption)" -Level INFO
    Write-Log "  OS Version: $($OS.Version)" -Level INFO
    Write-Log "  Total RAM: $([math]::Round($CS.TotalPhysicalMemory/1GB, 2)) GB" -Level INFO
    Write-Log "  Processor: $($CPU.Name)" -Level INFO
}

$CurrentTZ = Get-TimeZone
Write-Log "  Timezone: $($CurrentTZ.DisplayName)" -Level INFO
Write-Log "  Current Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level INFO

# Display disk information
Write-Log "" -Level INFO
Write-Log "Disk Configuration:" -Level INFO
try {
    Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -ne $null } | ForEach-Object {
        Write-Log "  Drive $($_.DriveLetter): - $($_.FileSystemLabel) - $([math]::Round($_.Size/1GB, 2)) GB Total, $([math]::Round($_.SizeRemaining/1GB, 2)) GB Free" -Level INFO
    }
} catch {
    # Fallback to Get-PSDrive if Get-Volume fails
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name.Length -eq 1 } | ForEach-Object {
        $Used = $_.Used
        $Free = $_.Free
        $Total = $Used + $Free
        Write-Log "  Drive $($_.Name): - $([math]::Round($Total/1GB, 2)) GB Total, $([math]::Round($Free/1GB, 2)) GB Free" -Level INFO
    }
}

Write-Log "" -Level INFO
Write-Log "Press any key to exit..." -Level INFO
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
