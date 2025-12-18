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

# Vuln 2 – Insecure Desktop shortcut
$binPath        = "C:\Services\Bin Files\AdminTools.exe"
$publicDesktop  = "C:\Users\Default\Desktop"
$lnkPath        = Join-Path $publicDesktop "Admin Tools.lnk"

$user     = "ps-win-1\jack.frost.admin"
$password = "StartWarsWookie1!"
$taskName = "RunAdminTools_FromShortcut"


# Create vulnerable binary + shortcut
if (-not (Test-Path $binPath)) {

    Copy-Item "C:\Windows\System32\cmd.exe" $binPath -Force

    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnkPath)
    $sc.TargetPath       = $binPath
    $sc.WorkingDirectory = "C:\Services\Bin Files"
    $sc.WindowStyle      = 1
    $sc.Description      = "Admin Tools"
    $sc.Save()

    icacls $binPath /inheritance:r `
        /grant:r "Administrators:F" "SYSTEM:F" `
        /deny "Users:W" | Out-Null

    icacls $lnkPath /grant "Everyone:F" | Out-Null
    icacls $publicDesktop /grant "Everyone:F" | Out-Null
}

# Resolve shortcut target (headless)
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnkPath)

$targetPath = $sc.TargetPath
$arguments  = $sc.Arguments

# Execute resolved target as admin
$taskCmd = "`"$targetPath`" $arguments"

schtasks /create `
    /tn $taskName `
    /tr $taskCmd `
    /sc once `
    /st 00:00 `
    /ru $user `
    /rp $password `
    /rl highest `
    /f | Out-Null

schtasks /run /tn $taskName | Out-Null

Start-Sleep -Seconds 5

schtasks /delete /tn $taskName /f | Out-Null


# Vuln 3 - Unquoted Service Path
if (-not (Get-Service -Name "GloboAgent" -ErrorAction SilentlyContinue)) {
    $binPath = 'C:\Services\Bin Files\GloboAgent.exe'
    # Create the service
    New-Service -Name "GloboAgent" -BinaryPathName $binPath -DisplayName "Globomantics Agent" -Description "Building the ideal society." -StartupType Automatic
}
icacls "C:\Services\Bin Files\GloboAgent.exe" /deny "Remote Management Users:F"
sc.exe stop GloboAgent
timeout /t 3 > nul
sc.exe start GloboAgent


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
sc.exe stop GloboCore
timeout /t 3 > nul
sc.exe start GloboCore

    
# Vuln 5 - Insecure File/Folder Permissions (change bat file)
if(-not(Test-Path("C:\Scripts"))) {
    New-Item -Path "C:\Scripts" -ItemType Directory
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
}

# create a vulnerable task to run every minute
if (-not (Get-ScheduledTask -TaskName "GloboST" -ErrorAction SilentlyContinue)) {
    $Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c C:\Scripts\GloboScript.bat"
    $TimeTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(10) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 31)
    $StartupTrigger = New-ScheduledTaskTrigger -AtStartup
    Register-ScheduledTask -TaskName "GloboST" -Action $Action -Trigger @($TimeTrigger, $StartupTrigger) -RunLevel Highest -User "SYSTEM"
}
icacls 'C:\Scripts\GloboScript.bat' /grant "Remote Management Users:(F)"
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
sc.exe stop GloboHostMgr
timeout /t 3 > nul
sc.exe start GloboHostMgr


# Vuln 10 - Token Impersonation
if(-not (Get-WindowsFeature -Name Web-Server).Installed) {
    Install-WindowsFeature Web-Server, Web-Asp-Net45, Web-Net-Ext45 -IncludeManagementTools
}
icacls "C:\inetpub\wwwroot" /grant "Remote Management Users:(F)"
