# Desktop Configuration Automation - Quick Reference Card

## Basic Deployment (Single PC)

1. **Copy files to USB drive**
   - HP_Desktop_Configuration.ps1
   - Run_HP_Configuration.bat

2. **On target computer**:
   - Insert USB drive
   - Right-click `Run_HP_Configuration.bat`
   - Select **"Run as Administrator"**
   - **If IP already configured**: Answer Y/N to change prompt
   - **Enter IP address when prompted** (e.g., 05, 10, 12, 100)
   - **Backup prompt**: Answer Y/N to copy files
   - **If files exist**: Answer Y/N to overwrite
   - Watch visual progress of file copying
   - Wait for completion (3-10 minutes depending on file size)

3. **Verify**:
   - Open File Explorer
   - Check for new drive letter (usually D: or E:)
   - Check network connectivity
   - Check D:\setup or E:\setup for backup files
   - Check C:\Logs for success messages

---

## Quick Commands

### Run Script Directly
```powershell
# Right-click PowerShell icon → Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Desktop_Configuration.ps1
```

### Check Partition Status
```powershell
Get-Volume
```

### Check Admin Account Name
```powershell
Get-LocalUser -Name "Admin"
# Or list all accounts
Get-LocalUser | Select-Object Name, Enabled
```

### Check Timezone
```powershell
Get-TimeZone
```

### Check Network Configuration
```powershell
# View IPv4 address
Get-NetIPAddress -AddressFamily IPv4

# View IPv6 address
Get-NetIPAddress -AddressFamily IPv6

# Test IPv4 connectivity
Test-Connection 192.168.130.1 -Count 2

# Test IPv6 connectivity
Test-Connection 2401:dd00:79:c002::1 -Count 2
```

### View Last Log
```powershell
Get-Content (Get-ChildItem C:\Logs\HP_Configuration_*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
```

---

## Expected Results

✅ **New 250GB partition created** (Drive letter D:, E:, or F:) - *Only on systems with 800GB+ storage*  
✅ **Static IP configured** (IPv4: 192.168.130.X, IPv6: 2401:dd00:79:c002::X)  
✅ **IP change prompt** if existing static IP detected  
✅ **Timezone set to Sri Lanka Standard Time** (UTC+05:30)  
✅ **Interactive file backup** with Y/N prompts and visual progress  
✅ **Overwrite confirmation** if files already exist  
✅ **"HP" account renamed to "Admin"** (done LAST)  
✅ **Admin password set to "12345"**  
✅ **Log file created in C:\Logs** (NOT backed up)  
✅ **No restart required**  
✅ **Process takes 3-10 minutes** (varies with file size)

**Backup Note**: Shows real-time progress with file names, transfer speed, and estimated time remaining.

---

## Network Configuration

**IP Change Prompt**:
- If IP already configured in 192.168.130.X range
- Script asks: "Do you want to change the IP address? (Y/N)"
- Y = Change IP, N = Keep existing IP

**IPv4 Configuration:**
- Address Format: 192.168.130.X (you enter X)  
- Subnet Mask: 255.255.255.128  
- Gateway: 192.168.130.1  
- DNS: 192.168.0.10  

**IPv6 Configuration:**
- Address Format: 2401:dd00:79:c002::X (X matches IPv4)
- Prefix: /64
- Gateway: 2401:dd00:79:c002::1

**Examples of valid input**:
- Enter `05` → IPv4: 192.168.130.5, IPv6: 2401:dd00:79:c002::5
- Enter `10` → IPv4: 192.168.130.10, IPv6: 2401:dd00:79:c002::10
- Enter `100` → IPv4: 192.168.130.100, IPv6: 2401:dd00:79:c002::100

---

## Default Admin Credentials

**After script completion:**
- Username: `Admin`
- Password: `12345`

**To change password:**
```powershell
net user Admin NewPassword
```

---

## Common Issues & Quick Fixes

| Issue | Quick Fix |
|-------|-----------|
| "Cannot load script" | Run as Administrator |
| "Disk size less than 800GB" | Normal - partition only for 800GB+ drives |
| "Insufficient space" | Free up space on C: drive |
| Script doesn't start | Use the .bat launcher file |
| Access denied | Disable antivirus temporarily |
| "HP account not found" | Normal if using different account name |
| No network connectivity | Check Ethernet cable, verify adapter |
| Can't ping gateway | Verify IP is in correct subnet |
| Backup folder not created | Requires 250GB partition first |

---

## Verification Checklist

- [ ] New volume appears in File Explorer (if disk is 800GB+)
- [ ] C:\Logs contains configuration log
- [ ] Log shows "Configuration Complete!"
- [ ] No error messages in log
- [ ] "Admin" account exists (use `Get-LocalUser -Name "Admin"`)
- [ ] "HP" account no longer exists (if it existed before)
- [ ] Admin password is "12345" (test with `runas /user:Admin cmd`)
- [ ] Timezone is "Sri Lanka Standard Time" (use `Get-TimeZone`)
- [ ] IPv4 address is configured (use `ipconfig`)
- [ ] IPv6 address is configured (use `ipconfig`)
- [ ] Can ping IPv4 gateway: `ping 192.168.130.1`
- [ ] Can ping IPv6 gateway: `ping 2401:dd00:79:c002::1`
- [ ] Backup folder exists (check D:\setup or E:\setup)
- [ ] Source files backed up to setup folder
- [ ] Log files in C:\Logs (NOT in setup folder)

---

## Support

**Log Location**: C:\Logs\HP_Configuration_[date]_[time].log (NOT backed up)  
**Backup Location**: D:\setup or E:\setup (source files only, on newly created partition)  
**Script Duration**: 3-7 minutes typical  
**Restart Required**: No  

If issues persist, check the full deployment guide.

---

**Version 1.0** | January 2026
