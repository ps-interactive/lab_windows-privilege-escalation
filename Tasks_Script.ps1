# NOTE for learners:
# This script is used to enable privesc opportunities.
# If you read this file it will reveal vulnerabilities and credentials
# You are only cheating yourself!
# .
# .
# .
# .
# .
# .
# .
# .
# .
# .
# .
# .
# .
# .
# disable Defender
Set-MpPreference -DisableRealtimeMonitoring $true

# TECHNIQUE 1 - Credentials in plaintext
# ---------------------------------------------------------------------------------------------------

# create profiles
if (!(Test-Path "C:\Users\jack.frost")) {
    $Cred = New-Object System.Management.Automation.PSCredential(".\jack.frost", $Password)
    Start-Process -Credential $Cred -FilePath "cmd.exe" -ArgumentList "/c exit" -LoadUserProfile
}

if (!(Test-Path "C:\Users\jack.frost.admin")) {
    $Cred = New-Object System.Management.Automation.PSCredential(".\jack.frost.admin", $Password)
    Start-Process -Credential $Cred -FilePath "cmd.exe" -ArgumentList "/c exit" -LoadUserProfile
}

# drop password scripts
if (!(Test-Path "C:\Users\jack.frost\tasks.ps1")) {
    Add-Content -Path "C:\Users\jack.frost\tasks.ps1" -Value @'
    C:\Users\student\Scripts\run.ps1 
    $Username = "jack.frost.admin"
    $Password = "ItsColdOutside!"
    Invoke-Command -ComputerName 127.0.0.1 -Credential (New-Object System.Management.Automation.PSCredential($Username,(ConvertTo-SecureString $Password -AsPlainText -Force)))
'@
}

if (!(Test-Path "C:\Users\jack.frost\start.bat")) {
    Add-Content -Path "C:\Users\jack.frost\start.bat" -Value @'
    C:\Users\Public\start.bat
    set USER=jack.frost.admin
    set PASS=ItsColdOutside!
    powershell -Command "Start-Process -FilePath 'cmd.exe' -Credential (New-Object System.Management.Automation.PSCredential('%USER%',(ConvertTo-SecureString '%PASS%' -AsPlainText -Force)))"
'@
}




# TECHNIQUE 8 - AlwaysInstallElevated
# ---------------------------------------------------------------------------------------------------
# implemented in main script