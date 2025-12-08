# WARNING!
# NOTE for learners:
#
# This script is used to simulate user activities and vulnerabilities.
#
# If you read this file it will reveal vulnerabilities and credentials
# You are only cheating yourself! :-)
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#

# disable anti-malware
Set-MpPreference -DisableRealtimeMonitoring $true

# Create accounts
$Password = ConvertTo-SecureString "ItsColdOutside!" -AsPlainText -Force
$Password2 = ConvertTo-SecureString "StartWarsWookie1!" -AsPlainText -Force

if (-not (Get-LocalUser -Name "jack.frost.admin" -ErrorAction SilentlyContinue)) {
    $User = "jack.frost.admin"
    New-LocalUser -Name $User -Password $Password2 -FullName "Jack Frost Admin" -Description "Pass: StartWarsWookie1!"
    Add-LocalGroupMember -Group "Administrators" -Member $User
}
if (-not (Get-LocalUser -Name "jack.frost" -ErrorAction SilentlyContinue)) {
    $User = "jack.frost"
    New-LocalUser -Name $User -Password $Password -FullName "Jack Frost" -Description "Jacks account."
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member $User
    Add-LocalGroupMember -Group "Remote Management Users" -Member $User
}

# Vuln 1 - Credentials in files
# drop password in script
Set-Content -Path "C:\Windows\tasks.ps1" -Value @'
C:\Users\student\Scripts\run.ps1 
$Username = "jack.frost.admin"
$Password = "StartWarsWookie1!"
Invoke-Command -ComputerName 127.0.0.1 -Credential (New-Object System.Management.Automation.PSCredential($Username,(ConvertTo-SecureString $Password -AsPlainText -Force)))
'@

New-Item -Path "C:\Users\jack.frost\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\" -ItemType Directory -Force 

$Cred = New-Object System.Management.Automation.PSCredential(".\jack.frost", $Password)
Start-Process -Credential $Cred -FilePath "cmd.exe" -ArgumentList "/c exit" -LoadUserProfile -Wait
Set-Content -Path "C:\Users\jack.frost\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -Value @'
Install-Module -Name CredentialManager -Scope CurrentUser -Force
New-StoredCredential -Target "globomantics/wks01" -Username "jack.frost.admin" -Password "StartWarsWookie1!" -Persist LocalMachine
$stored = Get-StoredCredential -Target "globomantics/wks01"
$secure = ConvertTo-SecureString $stored.Password -AsPlainText -Force
$pscred = New-Object System.Management.Automation.PSCredential($stored.UserName, $secure)
$pscred
'@

# Vuln 2 - Insecure Logon Script
if(-not (Test-Path "C:\Services\Bin Files\AdminTools.exe")) {

    # Create vulnerable binary
    $binPath = "C:\Services\Bin Files\AdminTools.exe"
    Copy-Item "C:\Windows\System32\cmd.exe" $binPath

    # Create vulnerable shortcut on Public Desktop
    $publicDesktop = "C:\Users\Default\Desktop\"
    $shortcutPath = Join-Path $publicDesktop "Admin Tools.lnk"

    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($shortcutPath)
    $sc.TargetPath = $binPath
    $sc.WorkingDirectory = "C:\Services\Bin Files"
    $sc.WindowStyle = 1
    $sc.Description = "Admin Tools"
    $sc.Save()

    icacls $binPath /inheritance:r /grant:r "Administrators:F" "SYSTEM:F" /deny "Users:W" | Out-Null
    icacls $shortcutPath /grant "Everyone:F" | Out-Null
    icacls $publicDesktop /grant "Everyone:F" | Out-Null
}

# Create interactive Session 1 for privileged user
$user = "ps-win-1\jack.frost.admin"
$password = "StartWarsWookie1!"
$taskName = "CreateSession1_ForShortcutVuln"

$action = New-ScheduledTaskAction -Execute "cmd.exe"
$trigger = New-ScheduledTaskTrigger -AtLogOn

Register-ScheduledTask `
    -TaskName $taskName `
    -User $user `
    -Password $password `
    -Trigger $trigger `
    -Action $action `
    -RunLevel Highest | Out-Null

schtasks /run /tn $taskName | Out-Null
Start-Sleep -Seconds 6
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null

# Automatically trigger the (possibly hijacked) LNK inside Session 1
$lnkPath = "C:\Users\Default\Desktop\Admin Tools.lnk"
$runTask = "RunHijackedShortcut"

$action2 = New-ScheduledTaskAction -Execute $lnkPath
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)

Register-ScheduledTask `
    -TaskName $runTask `
    -User $user `
    -Password $password `
    -Trigger $trigger2 `
    -Action $action2 `
    -RunLevel Highest | Out-Null

schtasks /run /tn $runTask | Out-Null
Start-Sleep -Seconds 5
Unregister-ScheduledTask -TaskName $runTask -Confirm:$false | Out-Null


# Vuln 3 - Unquoted Service Path
if (-not (Get-Service -Name "GloboAgent" -ErrorAction SilentlyContinue)) {
    $binPath = 'C:\Services\Bin Files\GloboAgent.exe'
    # Create the service
    New-Service -Name "GloboAgent" -BinaryPathName $binPath -DisplayName "Globomantics Agent" -Description "Building the ideal society." -StartupType Automatic
}
icacls "C:\Services\Bin Files\GloboAgent.exe" /deny "Remote Management Users:F"
Restart-Service -Name "GloboAgent" -Force

# Vuln 4 - Service Binary/Registry Writeable
if (-not (Get-Service -Name "GloboCore" -ErrorAction SilentlyContinue)) {
    $binPath = '"C:\Services\Bin Files\GloboCore.exe"'
    # Create the service
    New-Service -Name "GloboCore" -BinaryPathName $binPath -DisplayName "Globomantics Core" -Description "Building the ideal society." -StartupType Automatic
}
$acl = Get-Acl "HKLM:\SYSTEM\CurrentControlSet\Services\GloboCore"
$rule = New-Object System.Security.AccessControl.RegistryAccessRule(
    "Remote Management Users",
    "FullControl",
    "ContainerInherit,ObjectInherit",
    "None",
    "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl -Path "HKLM:\SYSTEM\CurrentControlSet\Services\GloboCore" -AclObject $acl
Restart-Service -Name "GloboCore" -Force
    
# Vuln 5 - Insecure File/Folder Permissions (change bat file)
if(-not(Test-Path("C:\Scripts"))) {
    New-Item -Path "C:\Scripts" -ItemType Directory
}
$bat_script = @'
@echo off
setlocal EnableDelayedExpansion

echo Initialising GloboNet Services...
ping -n 2 127.0.0.1 >nul

echo Verifying node integrity...
for %%G in (CoreSys AuthSvc NetStack ConfigSync) do (
    echo   [OK] %%G module loaded.
    ping -n 2 127.0.0.1 >nul
)

echo Applying baseline policies...
ping -n 3 127.0.0.1 >nul
echo Done.

endlocal
'@

Set-Content -Path "C:\Scripts\GloboScript.bat" -Value $bat_script

# create a vulnerable task to run every minute
if (-not (Get-ScheduledTask -TaskName "GloboST" -ErrorAction SilentlyContinue)) {
    $Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c C:\Scripts\GloboScript.bat"
    $TimeTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddSeconds(10) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 31)
    $StartupTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "GloboST" -Action $Action -Trigger @($TimeTrigger, $StartupTrigger) -RunLevel Highest -User "SYSTEM"
}
icacls 'C:\Scripts\GloboScript.bat', /grant, "Remote Management Users:(F)"
icacls "C:\Windows\System32\Tasks" /grant "Users:(RX)"

# Vuln 6 - Insecure Scheduled
icacls 'C:\Windows\System32\Tasks\GloboST', /grant, "Remote Management Users:(F)"

# Vuln 9 - DLL Hijacking - Service
if (-not (Get-Service -Name "GloboHostMgr" -ErrorAction SilentlyContinue)) {
    $binPath = '"C:\Services\Bin Files\GloboHostMgr.exe"'
    # Create the service
    New-Service -Name "GloboHostMgr" -BinaryPathName $binPath -DisplayName "Globomantics Host Manager" -Description "Building the ideal society." -StartupType Automatic
}
icacls "C:\Services\Bin Files\GloboHostMgr.exe" /deny "Remote Management Users:F"
Restart-Service -Name "GloboHostMgr" -Force

# Vuln 10 - Token Impersonation
if(-not (Get-WindowsFeature -Name Web-Server).Installed) {
    Install-WindowsFeature Web-Server, Web-Asp-Net45, Web-Net-Ext45 -IncludeManagementTools
}
icacls "C:\inetpub\wwwroot" /grant "Remote Management Users:(F)"

# =====================================================================
# Vulnerability 11 – Custom COM Misconfiguration (SweetPotato Enabled)
# =====================================================================

# Marker location to prevent repeated creation
$markerPath = "HKLM:\SOFTWARE\LabVulns"
$markerName = "SweetPotatoCLSID"

# Create marker key if missing
if (-not (Test-Path $markerPath)) {
    New-Item -Path $markerPath -Force | Out-Null
}

# If CLSID already created, exit safely
if (Get-ItemProperty -Path $markerPath -Name $markerName -ErrorAction SilentlyContinue) {
    return   # <-- Already set up, nothing more to do
}

$clsid = "{11111111-2222-3333-4444-555555555555}"
$appid = "{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}"

New-Item -Path "HKLM:\SOFTWARE\Classes\CLSID\$clsid" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\CLSID\$clsid" -Name "(Default)" -Value "Lab Vulnerable COM Object"
Set-ItemProperty "HKLM:\SOFTWARE\Classes\CLSID\$clsid" -Name "AppID" -Value $appid

New-Item -Path "HKLM:\SOFTWARE\Classes\CLSID\$clsid\LocalServer32" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\CLSID\$clsid\LocalServer32" -Name "(Default)" -Value "C:\Windows\System32\cmd.exe"

New-Item -Path "HKLM:\SOFTWARE\Classes\AppID\$appid" -Force | Out-Null
Set-ItemProperty "HKLM:\SOFTWARE\Classes\AppID\$appid" -Name "(Default)" -Value "Lab Vulnerable COM Object"
Set-ItemProperty "HKLM:\SOFTWARE\Classes\AppID\$appid" -Name "RunAs" -Value "NT AUTHORITY\SYSTEM"

$sd = ([System.Text.Encoding]::ASCII.GetBytes(
    "O:BAG:BAD:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"
))

Set-ItemProperty "HKLM:\SOFTWARE\Classes\AppID\$appid" -Name "LaunchPermission" -Value $sd
Set-ItemProperty "HKLM:\SOFTWARE\Classes\AppID\$appid" -Name "AccessPermission" -Value $sd
New-ItemProperty -Path $markerPath -Name $markerName -Value "Created" -PropertyType String -Force | Out-Null
