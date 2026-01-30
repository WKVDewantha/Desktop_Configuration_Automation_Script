# Desktop Configuration Automation Guide

## Overview
This guide provides step-by-step instructions for deploying the automated configuration script across your company's desktop computers.

## What the Script Does
1. **Creates a 250GB partition** - Only on systems with 800GB+ storage capacity. Automatically shrinks the C: drive if needed and creates a new 250GB data partition
2. **Configures static IP address** - Checks if a static IP in the 192.168.130.X range already exists. If found, prompts user to confirm if they want to change it (Y/N). If user selects 'Y' or no IP is configured, prompts for IP address (192.168.130.X format) and configures both IPv4 and IPv6 network settings. **Done EARLY to avoid security context errors**
3. **Sets timezone to Sri Lanka** - Configures system timezone to Sri Lanka Standard Time (UTC+05:30) for Sri Jayawardenepura Kotte
4. **Backs up files** - **Prompts user** if they want to copy files (Y/N). If files already exist in the destination, asks if they should be overwritten (Y/N). Uses Windows **robocopy** tool with **visual progress display** showing file names, transfer speed, and estimated time remaining to reliably copy **all files from the parent directory** (including large files) to the newly created partition in a "setup" folder. For example, if the script is located at `E:\Software\Desktop_Configuration_Automation_Script\Desktop_Configuration.ps1`, it will copy everything from `E:\Software\` to the backup location. **Note: Log files are NOT backed up, only source files**. Robocopy handles large files, network interruptions, and provides reliable multi-threaded copying.
5. **Renames local administrator account** - Searches for "HP" account (common on HP computers) and renames it to "Admin". If "Admin" account already exists, skips renaming. If "HP" account not found, renames the built-in Administrator account instead. **Done LAST to avoid permission issues**
6. **Sets Admin account password** - Sets the password for the "Admin" account to "12345" for standardization across all systems
7. **Tests network connectivity** - Verifies gateway, DNS, and internet connectivity after configuration
8. **Logs all activities** - Creates detailed logs in C:\Logs for troubleshooting (logs remain in C:\Logs only)

## Backup Behavior Details
The script provides **interactive file backup** to the newly created partition using **Windows robocopy**:
- **User Confirmation**: Prompts "Do you want to copy files to the backup location? (Y/N)"
  - Answer 'Y' to proceed with backup
  - Answer 'N' to skip backup
- **Overwrite Detection**: If files already exist in destination, prompts "Overwrite existing files? (Y/N)"
  - Answer 'Y' to overwrite all existing files
  - Answer 'N' to skip files that already exist
- **Source**: Parent directory of the script location
  - Example: Script at `E:\Software\Desktop_Configuration_Automation_Script\script.ps1`
  - Copies from: `E:\Software\` (entire folder with all subfolders)
- **Destination**: `D:\setup\` or `E:\setup\` (on the newly created 250GB partition)
- **Copy Method**: robocopy (Windows built-in tool)
  - **Visual progress** - Shows each file being copied
  - **Transfer speed** - Displays MB/s or GB/s
  - **Estimated time** - Shows time remaining
  - **File details** - Shows file names and sizes
  - Multi-threaded copying (8 threads) for faster performance
  - Handles large files reliably
  - Automatic retry on failures (3 attempts)
- **What's copied**:
  - **All files and folders from the parent directory**
  - Preserves folder structure
  - Includes large files (ISO, installers, etc.)
- **What's NOT copied**:
  - **Log files from C:\Logs** (logs remain only in C:\Logs)
  - Existing "setup" folders (to prevent recursion)
- **Progress Display**: Real-time visual feedback with file names, sizes, and transfer statistics
- **Note**: Backup only occurs if a 250GB partition is successfully created

## Network Configuration Details
- **IP Detection**: Script checks if a static IP in 192.168.130.X range already exists
- **Change Confirmation**: If existing IP found, prompts "Do you want to change the IP address? (Y/N)"
  - Answer 'Y' or 'y' to change the IP
  - Answer 'N' or 'n' to keep existing IP
- **IPv4 Address Format**: 192.168.130.X (X is user input, e.g., 05, 10, 12, 100)
- **IPv4 Subnet Mask**: 255.255.255.128 (/25)
- **IPv4 Default Gateway**: 192.168.130.1
- **DNS Server**: 192.168.0.10
- **IPv6 Address Format**: 2401:dd00:79:c002::X (X matches IPv4, e.g., 05, 10, 12, 100)
- **IPv6 Prefix Length**: /64
- **IPv6 Default Gateway**: 2401:dd00:79:c002::1
- **Connectivity Tests**: Automatic ping tests to IPv4 gateway, IPv6 gateway, DNS, and internet

### IPv4 and IPv6 Address Mapping Examples:
| User Input | IPv4 Address      | IPv6 Address             |
|------------|-------------------|--------------------------|
| 05         | 192.168.130.5     | 2401:dd00:79:c002::5     |
| 10         | 192.168.130.10    | 2401:dd00:79:c002::10    |
| 12         | 192.168.130.12    | 2401:dd00:79:c002::12    |
| 100        | 192.168.130.100   | 2401:dd00:79:c002::100   |
| 101        | 192.168.130.101   | 2401:dd00:79:c002::101   |

## Security Notes
- **Default Password**: The script sets "Admin" account password to "12345" for initial deployment and standardization
- **Production Recommendation**: After deployment, consider implementing a more secure password policy
- **Password Changes**: Users can change the password using: `net user Admin NewPassword` or through Windows settings

---

## Deployment Methods

### Method 1: Manual Deployment (Single Computer)

1. **Copy the script** to the target computer (USB drive, network share, etc.)

2. **Open PowerShell as Administrator**:
   - Right-click on Start Menu
   - Select "Windows Terminal (Admin)" or "PowerShell (Admin)"

3. **Navigate to script location**:
   ```powershell
   cd C:\Path\To\Script
   ```

4. **Allow script execution** (if needed):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   ```

5. **Run the script**:
   ```powershell
   .\Desktop_Configuration.ps1
   ```

6. **Review the output** and check the log file in C:\Logs

---

### Method 2: Network Deployment (Multiple Computers)

#### Setup Steps:

1. **Create a network share**:
   ```powershell
   # On your deployment server
   New-Item -Path "C:\DeploymentShare" -ItemType Directory
   New-SMBShare -Name "Deployment" -Path "C:\DeploymentShare" -FullAccess "Everyone"
   ```

2. **Copy the script** to the network share:
   ```
   \\ServerName\Deployment\Desktop_Configuration.ps1
   ```

3. **On each target computer**, run as Administrator:
   ```powershell
   # Map network drive (optional)
   net use Z: \\ServerName\Deployment
   
   # Allow script execution
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
   
   # Run the script
   \\ServerName\Deployment\Desktop_Configuration.ps1
   ```

---

### Method 3: Group Policy Deployment (Domain Environment)

1. **Create a GPO**:
   - Open Group Policy Management
   - Create new GPO: "HP Desktop Configuration"

2. **Configure startup script**:
   - Edit GPO → Computer Configuration → Policies → Windows Settings → Scripts → Startup
   - Add script: `\\Domain\NETLOGON\Desktop_Configuration.ps1`
   - Set PowerShell parameters: `-ExecutionPolicy Bypass -File`

3. **Link GPO** to the OU containing your HP computers

4. **Force update** on target computers:
   ```powershell
   gpupdate /force
   ```

---

### Method 4: Remote Deployment with PSRemoting

**Requirements**: PowerShell Remoting enabled on target computers

```powershell
# Enable PSRemoting on target computers first
Enable-PSRemoting -Force

# From your admin workstation
$Computers = @("PC001", "PC002", "PC003")  # Add all computer names

foreach ($Computer in $Computers) {
    Write-Host "Configuring $Computer..." -ForegroundColor Cyan
    
    Invoke-Command -ComputerName $Computer -FilePath ".\Desktop_Configuration.ps1" -ErrorAction Continue
    
    Write-Host "Completed $Computer" -ForegroundColor Green
}
```

---

## Customizing the Script

You can easily customize the script to match your specific network and deployment requirements. Below are the most common customizations:

### Network Settings Customization

**Location in script:** Lines 258-267 (Step 2: Configure Network Settings)

**Default values:**
```powershell
$IPAddress = "192.168.130.$IPLastPart"
$SubnetMask = "255.255.255.128"
$PrefixLength = 25  # /25 for 255.255.255.128
$DefaultGateway = "192.168.130.1"
$DNSServer = "192.168.0.10"

# IPv6 configuration
$IPv6Address = "2401:dd00:79:c002::$IPLastPart"
$IPv6PrefixLength = 64
$IPv6Gateway = "2401:dd00:79:c002::1"
```

**To customize:**
1. Open `Desktop_Configuration.ps1` in a text editor (Notepad++, VS Code, etc.)
2. Find the network configuration section (Step 2)
3. Modify the values as needed:

```powershell
# Example: Change to different subnet
$IPAddress = "10.0.50.$IPLastPart"        # Change IP range
$SubnetMask = "255.255.255.0"             # Change subnet mask
$PrefixLength = 24                         # Change to /24
$DefaultGateway = "10.0.50.1"             # Change gateway
$DNSServer = "10.0.0.53"                  # Change DNS server

# Example: Change IPv6 prefix
$IPv6Address = "2001:db8:1234:5678::$IPLastPart"
$IPv6Gateway = "2001:db8:1234:5678::1"
```

### Partition Size Customization

**Location in script:** Around line 160 (Step 1: Create Partition)

**Default value:**
```powershell
# Create new partition
$NewPartition = New-Partition -DiskNumber 0 -Size 250GB -DriveLetter $AvailableLetter
```

**To customize:**
```powershell
# Example: Create 500GB partition instead
$NewPartition = New-Partition -DiskNumber 0 -Size 500GB -DriveLetter $AvailableLetter

# Example: Use all available space
$NewPartition = New-Partition -DiskNumber 0 -UseMaximumSize -DriveLetter $AvailableLetter
```

### Minimum Disk Size Customization

**Location in script:** Around line 140 (Step 1)

**Default value:**
```powershell
if ($DiskSizeGB -lt 800) {
    Write-Log "Disk size ($DiskSizeGB GB) is less than 800GB. Skipping partition creation."
```

**To customize:**
```powershell
# Example: Require 500GB minimum instead
if ($DiskSizeGB -lt 500) {
    Write-Log "Disk size ($DiskSizeGB GB) is less than 500GB. Skipping partition creation."
```

### Administrator Password Customization

**Location in script:** Around line 609 (Step 5: Rename Administrator Account)

**Default value:**
```powershell
# Create secure string for password
$NewPassword = ConvertTo-SecureString "12345" -AsPlainText -Force
```

**To customize:**
```powershell
# Example: Use a more secure password
$NewPassword = ConvertTo-SecureString "YourSecureP@ssw0rd!" -AsPlainText -Force
```

### Timezone Customization

**Location in script:** Around line 390 (Step 3: Set Timezone)

**Default value:**
```powershell
$SriLankaTimezone = "Sri Lanka Standard Time"
```

**To customize:**
```powershell
# Example: Change to different timezone
$CustomTimezone = "Eastern Standard Time"     # US Eastern
$CustomTimezone = "Pacific Standard Time"     # US Pacific
$CustomTimezone = "India Standard Time"       # India
$CustomTimezone = "China Standard Time"       # China

# Get list of all available timezones:
# Run in PowerShell: Get-TimeZone -ListAvailable
```

### Robocopy Thread Count Customization

**Location in script:** Around line 508 (Step 4: Backup Files)

**Default value:**
```powershell
$RobocopyArgs += "/MT:8"        # Multi-threaded (8 threads)
```

**To customize:**
```powershell
# Example: Use more threads for faster copying
$RobocopyArgs += "/MT:16"       # 16 threads (if powerful CPU)

# Example: Use fewer threads for older systems
$RobocopyArgs += "/MT:4"        # 4 threads
```

### Log File Location Customization

**Location in script:** Lines 29-30 (Top of script)

**Default value:**
```powershell
$LogPath = "C:\Logs"
$LogFile = "$LogPath\HP_Configuration_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
```

**To customize:**
```powershell
# Example: Use different log location
$LogPath = "C:\DeploymentLogs"

# Example: Include computer name in log file
$LogFile = "$LogPath\$env:COMPUTERNAME`_Config_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
```

### Testing Your Customizations

After making changes:

1. **Test on a single computer first**
2. **Review the log file** in C:\Logs for errors
3. **Verify all changes** took effect
4. **Create a backup** of your customized script
5. **Document your changes** for future reference

### Best Practices for Customization

- ✅ Always test changes on a non-production system first
- ✅ Keep a backup of the original script
- ✅ Comment your changes with `# Custom: reason for change`
- ✅ Update the script version/date in the header
- ✅ Document all customizations in a separate file
- ✅ Test with different scenarios (existing IP, existing files, etc.)

---

## Pre-Deployment Checklist

- [ ] Ensure Windows 11 Pro is installed and activated
- [ ] Verify computers are connected to network (for network deployment)
- [ ] Backup any existing data on computers
- [ ] **Organize deployment files**: Place the script in a folder structure like `E:\Software\Desktop_Configuration\` so that the entire `E:\Software\` folder gets backed up
- [ ] Test script on a single computer first
- [ ] Verify administrator credentials
- [ ] Check available disk space (should have at least 250GB free)
- [ ] Prepare list of IP addresses for each computer

## Backup Example

**Script Location Structure:**
```
E:\Software\
├── Desktop_Configuration\
│   ├── Desktop_Configuration.ps1
│   └── Run_Configuration.bat
├── Drivers\
│   └── [driver files]
├── Applications\
│   └── [application installers]
└── Documentation\
    └── [manuals and guides]
```

**After Script Runs:**
```
D:\setup\  (or E:\setup\)
├── Desktop_Configuration\
│   ├── Desktop_Configuration.ps1
│   └── Run_Configuration.bat
├── Drivers\
│   └── [driver files]
├── Applications\
│   └── [application installers]
└── Documentation\
    └── [manuals and guides]
```

All contents from `E:\Software\` are copied to the setup folder. **Note: Log files remain in C:\Logs and are NOT copied to setup folder.**

---

## Post-Deployment Verification

After running the script, verify the following:

1. **Check Partition Creation** (only for 800GB+ drives):
   ```powershell
   Get-Volume
   ```
   You should see a new 250GB volume (if disk is 800GB or larger)

2. **Verify Administrator Rename**:
   ```powershell
   Get-LocalUser -Name "Admin"
   ```
   Should return the Admin account details

3. **Test Admin Account Login**:
   - Username: `Admin`
   - Password: `12345`
   - You can test with: `runas /user:Admin cmd` (will prompt for password)

4. **Check all local accounts**:
   ```powershell
   Get-LocalUser | Select-Object Name, Enabled
   ```
   Verify "Admin" exists and no "HP" account remains

5. **Verify Timezone**:
   ```powershell
   Get-TimeZone
   ```
   Should show "Sri Lanka Standard Time" with BaseUtcOffset of 05:30:00

6. **Check Network Configuration**:
   ```powershell
   # View IPv4 configuration
   Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.130.*" }
   
   # View IPv6 configuration
   Get-NetIPAddress -AddressFamily IPv6 | Where-Object { $_.IPAddress -like "2401:dd00:79:c002::*" }
   
   # View full network config
   Get-NetIPConfiguration
   
   # Test IPv4 connectivity
   Test-Connection -ComputerName 192.168.130.1 -Count 2
   Test-Connection -ComputerName 192.168.0.10 -Count 2
   
   # Test IPv6 connectivity
   Test-Connection -ComputerName 2401:dd00:79:c002::1 -Count 2
   ```
   Should show configured IPv4 (192.168.130.X) and IPv6 (2401:dd00:79:c002::X) addresses with successful pings

7. **Verify Backup Files**:
   - Check the newly created partition (D:, E:, or F:)
   - Look for "setup" folder containing source files (NOT logs)
   - Path should be similar to: `D:\setup\` or `E:\setup\`
   - Verify all files from source directory are copied

8. **Review Log Files**:
   - Check **C:\Logs** for detailed execution logs
   - **Note**: Log files are NOT backed up to the setup folder
   - Review for any errors or warnings

---

## Troubleshooting

### Issue: "Script cannot be loaded because running scripts is disabled"
**Solution**: Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### Issue: "Disk size is less than 800GB. Skipping partition creation"
**Expected Behavior**: This is normal for systems with smaller drives. The script only creates partitions on drives 800GB or larger.
**Action**: No action needed - this is intentional behavior.

### Issue: "Insufficient space for 250GB partition"
**Solution**: 
- Check current disk usage: `Get-Volume`
- Ensure C: drive has at least 300GB allocated
- Manually free up space or use Disk Management to shrink C: drive further

### Issue: "'HP' account not found" or "Built-in Administrator account not found"
**Solution**:
- Check the log file - it will list all available local accounts
- Manually verify account names: `Get-LocalUser`
- If using a custom account name, manually rename it: `Rename-LocalUser -Name "OldName" -NewName "Admin"`

### Issue: "Access Denied" when renaming administrator
**Solution**:
- Ensure script is running as Administrator
- Check that the account is not currently logged in
- Disable any third-party security software temporarily

### Issue: Network configuration fails or "No active Ethernet adapter found"
**Solution**:
- Verify Ethernet cable is connected
- Check adapter status: `Get-NetAdapter`
- Ensure adapter drivers are installed
- If using Wi-Fi, the script only configures Ethernet adapters

### Issue: Cannot ping gateway or DNS after configuration
**Solution**:
- Verify IP address is in correct subnet (192.168.130.1-126 for /25 mask)
- Check physical network connection
- Verify gateway and DNS server addresses with network admin
- Restart network adapter: `Restart-NetAdapter -Name "Ethernet"`
- For IPv6 issues, ensure network infrastructure supports IPv6

### Issue: IPv6 configuration fails
**Solution**:
- Check if IPv6 is enabled on the network adapter
- Verify router/switch supports IPv6
- Check Windows IPv6 stack: `netsh interface ipv6 show config`
- Re-enable IPv6 if needed: `Enable-NetAdapterBinding -Name "Ethernet" -ComponentID ms_tcpip6`
- IPv4 will still work even if IPv6 fails

### Issue: Backup files not found in setup folder
**Solution**:
- Verify 250GB partition was created (check with `Get-Volume`)
- Ensure script had access to source files location
- Check log file for backup errors
- Manually copy files if needed

### Issue: Script fails to shrink C: drive
**Possible causes**:
- Hibernation file or page file preventing shrink
- Fragmented disk

**Solution**:
```powershell
# Disable hibernation temporarily
powercfg /h off

# Defragment the drive
Optimize-Volume -DriveLetter C -Defrag -Verbose

# Re-enable hibernation after configuration
powercfg /h on
```

---

## Mass Deployment Workflow

For deploying to all computers efficiently:

1. **Preparation Phase** (Day 1)
   - Test script on 2-3 pilot computers
   - Document any issues
   - Adjust script if needed

2. **Staged Deployment** (Days 2-3)
   - Deploy to 10% of computers
   - Monitor for issues
   - Collect logs for review

3. **Full Deployment** (Days 4-5)
   - Deploy to remaining computers
   - Use parallel deployment for efficiency

4. **Verification Phase** (Day 6)
   - Run verification scripts on all computers
   - Generate compliance report

---

## Creating a Verification Report

Run this script to verify all computers are configured correctly:

```powershell
$Computers = Get-Content "C:\computers.txt"  # List of computer names

$Results = foreach ($Computer in $Computers) {
    try {
        # Check disk size and partition
        $DiskInfo = Invoke-Command -ComputerName $Computer -ScriptBlock {
            $Disk = Get-Disk -Number 0
            $DiskSizeGB = [math]::Round($Disk.Size/1GB, 2)
            $Partition = Get-Volume | Where-Object { $_.Size -gt 240GB -and $_.Size -lt 260GB }
            
            [PSCustomObject]@{
                DiskSize = $DiskSizeGB
                PartitionExists = if ($Partition) { "Yes" } else { "No" }
                PartitionRequired = if ($DiskSizeGB -ge 800) { "Yes" } else { "No" }
            }
        }
        
        # Check for Admin account, timezone, and Adobe startup
        $SystemConfig = Invoke-Command -ComputerName $Computer -ScriptBlock {
            $Admin = Get-LocalUser -Name "Admin" -ErrorAction SilentlyContinue
            $HP = Get-LocalUser -Name "HP" -ErrorAction SilentlyContinue
            $Timezone = Get-TimeZone
            $AdobeTasks = Get-ScheduledTask | Where-Object { 
                $_.TaskName -like "*Adobe*Creative*Cloud*" -and $_.State -eq "Ready" 
            }
            $AdobeStartup = Get-CimInstance -ClassName Win32_StartupCommand | Where-Object {
                $_.Command -like "*CCXProcess.exe*"
            }
            
            [PSCustomObject]@{
                AdminExists = if ($Admin) { "Yes" } else { "No" }
                HPExists = if ($HP) { "Yes" } else { "No" }
                TimezoneId = $Timezone.Id
                TimezoneCorrect = if ($Timezone.Id -eq "Sri Lanka Standard Time") { "Yes" } else { "No" }
                AdobeStartupDisabled = if (-not $AdobeTasks -and -not $AdobeStartup) { "Yes" } else { "No" }
            }
        }
        
        # Determine overall status
        $PartitionStatus = if ($DiskInfo.PartitionRequired -eq "Yes" -and $DiskInfo.PartitionExists -eq "No") {
            "Failed"
        } elseif ($DiskInfo.PartitionRequired -eq "No") {
            "N/A (< 800GB)"
        } else {
            "Success"
        }
        
        $AccountStatus = if ($SystemConfig.AdminExists -eq "Yes" -and $SystemConfig.HPExists -eq "No") {
            "Success"
        } else {
            "Failed"
        }
        
        $TimezoneStatus = if ($SystemConfig.TimezoneCorrect -eq "Yes") {
            "Success"
        } else {
            "Failed"
        }
        
        $AdobeStatus = if ($SystemConfig.AdobeStartupDisabled -eq "Yes") {
            "Success"
        } else {
            "Warning"
        }
        
        [PSCustomObject]@{
            ComputerName = $Computer
            DiskSize = "$($DiskInfo.DiskSize) GB"
            PartitionStatus = $PartitionStatus
            AdminAccountRenamed = $AccountStatus
            HPAccountRemains = $SystemConfig.HPExists
            TimezoneStatus = $TimezoneStatus
            CurrentTimezone = $SystemConfig.TimezoneId
            AdobeStartupStatus = $AdobeStatus
            OverallStatus = if ($PartitionStatus -ne "Failed" -and $AccountStatus -eq "Success" -and $TimezoneStatus -eq "Success") { 
                if ($AdobeStatus -eq "Warning") { "Success (Adobe Warning)" } else { "Success" }
            } else { 
                "Needs Attention" 
            }
        }
    }
    catch {
        [PSCustomObject]@{
            ComputerName = $Computer
            DiskSize = "Unknown"
            PartitionStatus = "Error"
            AdminAccountRenamed = "Error"
            HPAccountRemains = "Unknown"
            TimezoneStatus = "Error"
            CurrentTimezone = "Unknown"
            AdobeStartupStatus = "Error"
            OverallStatus = "Failed: $($_.Exception.Message)"
        }
    }
}

$Results | Export-Csv "C:\DeploymentReport.csv" -NoTypeInformation
$Results | Format-Table -AutoSize
```

---

## Safety Features Built Into Script

1. **Administrator Check**: Ensures script runs with proper privileges
2. **Error Handling**: Continues execution even if one task fails
3. **Detailed Logging**: Creates timestamped logs for audit trail
4. **Validation Checks**: Verifies sufficient disk space before shrinking
5. **Conflict Resolution**: Handles existing "Admin" accounts gracefully
6. **No Data Loss**: Only creates new partitions, doesn't delete existing data
7. **Account Enablement**: Automatically enables Admin account if disabled

---

## Password Management

**Default Credentials After Script:**
- Username: `Admin`
- Password: `12345`

**To Change Password on Individual Computer:**
```powershell
# Change password via PowerShell
$NewPassword = Read-Host "Enter new password" -AsSecureString
Set-LocalUser -Name "Admin" -Password $NewPassword

# Or via Command Prompt
net user Admin YourNewPassword
```

**To Change Password Across All Computers:**
```powershell
# Create a script to change passwords remotely
$Computers = Get-Content "C:\computers.txt"
$NewPassword = ConvertTo-SecureString "YourNewSecurePassword" -AsPlainText -Force

foreach ($Computer in $Computers) {
    Invoke-Command -ComputerName $Computer -ScriptBlock {
        param($Pass)
        Set-LocalUser -Name "Admin" -Password $Pass
    } -ArgumentList $NewPassword
}
```

**Password Policy Recommendations:**
- Minimum 8 characters
- Include uppercase, lowercase, numbers, and special characters
- Change passwords regularly (every 90 days recommended)
- Consider implementing Windows password policies via Group Policy

---

## Support and Maintenance

**Log Location**: C:\Logs\HP_Configuration_[timestamp].log

**Recommended Log Retention**: 90 days

**Cleanup Old Logs**:
```powershell
Get-ChildItem "C:\Logs\HP_Configuration_*.log" | 
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-90) } | 
    Remove-Item
```

---

## Additional Notes

- The script is idempotent (can be run multiple times safely)
- If partition already exists, it will skip creation
- If account is already named "Admin", it will skip renaming
- All actions are logged for compliance and auditing
- No restart is required after running the script

---

## Contact Information

For issues or questions about this deployment:
- Review the log files in C:\Logs
- Check the troubleshooting section above
- Contact your IT administrator

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Compatible With**: Windows 11 Pro, PowerShell 5.1+
