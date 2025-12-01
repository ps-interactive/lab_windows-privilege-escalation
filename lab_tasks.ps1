# WARNING!
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
#

# disable anti-malware
Set-MpPreference -DisableRealtimeMonitoring $true

# Create accounts
$Password = ConvertTo-SecureString "ItsColdOutside!" -AsPlainText -Force
$User = "jack.frost.admin"
New-LocalUser -Name $User -Password $Password -FullName "Jack Frost Admin" -Description "Pass: ItsColdOutside!"
Add-LocalGroupMember -Group "Administrators" -Member $User
$User = "jack.frost"
New-LocalUser -Name $User -Password $Password -FullName "Jack Frost" -Description "Jacks account."
Add-LocalGroupMember -Group "Remote Desktop Users" -Member $User
Add-LocalGroupMember -Group "Remote Management Users" -Member $User

# Vuln 1 - Credentials in files
# drop password in script
Add-Content -Path "C:\Windows\tasks.ps1" -Value @'
C:\Users\student\Scripts\run.ps1 
$Username = "jack.frost.admin"
$Password = "ItsColdOutside!"
Invoke-Command -ComputerName 127.0.0.1 -Credential (New-Object System.Management.Automation.PSCredential($Username,(ConvertTo-SecureString $Password -AsPlainText -Force)))
'@

$Cred = New-Object System.Management.Automation.PSCredential(".\jack.frost", $Password)
Start-Process -Credential $Cred -FilePath "cmd.exe" -ArgumentList "/c exit" -LoadUserProfile -Wait
Add-Content -Path "C:\Users\jack.frost\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" -Value @'
Install-Module -Name CredentialManager -Scope CurrentUser -Force
New-StoredCredential -Target "globomantics/wks01" -Username "jack.frost.admin" -Password "ItsColdOutside!" -Persist LocalMachine
$stored = Get-StoredCredential -Target "globomantics/wks01"
$secure = ConvertTo-SecureString $stored.Password -AsPlainText -Force
$pscred = New-Object System.Management.Automation.PSCredential($stored.UserName, $secure)
$pscred
'@

# Vuln 2 - UAC Bypass
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
-Name 'ConsentPromptBehaviorAdmin' -Value 2
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
-Name 'PromptOnSecureDesktop' -Value 0

# TODO: Vuln 3 - Unsecured Startup Application

# Vuln 4 - Unquoted Service Path
$binPath = '"C:\Services\Bin Files\GloboAgent.exe"'
# Create the service
New-Service -Name "GloboAgent" -BinaryPathName $binPath -DisplayName "Globomantics Agent" -Description "Building the ideal society." -StartupType Automatic
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\GloboAgent" -Name "ObjectName" -Value "NT AUTHORITY\LocalSystem"

# TODO: Vuln 5 - Service Binary/Registry Writeable
$binPath = 'C:\Services\Bin Files\GloboCore.exe'
# Create the service
New-Service -Name "GloboCore" -BinaryPathName $binPath -DisplayName "Globomantics Core" -Description "Building the ideal society." -StartupType Automatic
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\GloboCore" -Name "ObjectName" -Value "NT AUTHORITY\LocalSystem"

    
# TODO: Vuln 6 - Insecure File/Folder Permissions
# MAYBE IIS
    
# TODO: Vuln 7 - Misconfigured Scheduled Tasks

# TODO: Vuln 9 - DLL Hijacking - Service
$binPath = 'C:\Services\Bin Files\GloboHostMgr.exe'
# Create the service
New-Service -Name "GloboHostMgr" -BinaryPathName $binPath -DisplayName "Globomantics Host Manager" -Description "Building the ideal society." -StartupType Automatic
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\GloboHostMgr" -Name "ObjectName" -Value "NT AUTHORITY\LocalSystem"

# TODO: Vuln 10 - Token Impersonation
Install-WindowsFeature Web-Server, Web-Asp-Net45, Web-Net-Ext45 -IncludeManagementTools
Start-Process icacls -ArgumentList 'C:\intepub\wwwroot', '/grant:r', '"Remote Management Users:(OI)(CI)(F)"', '/T' -WindowStyle Hidden

# TODO: Vuln 11 - Unsecured Pipes
# TODO: Vuln 12 - Vulnerable Signed Drivers
