# ============================================================
# WARNING!
# NOTE for learners:
#
# This script simulates user activity and vulnerabilities.
# Reading it reveals credentials and weaknesses.
# You are only cheating yourself :-)
# ============================================================

$debugPath = "C:\Windows\log.txt"

if (-not (Test-Path $debugPath)) {
    New-Item -Path $debugPath -ItemType File -Force | Out-Null
}

function Write-DebugLog {
    param (
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp][$Level] $Message"

    Add-Content -Path $debugPath -Value $entry
}

# ----------------------------
# Helper: Isolated vuln runner
# ----------------------------
function Invoke-Vuln {
    param (
        [string]$Name,
        [scriptblock]$Action
    )

    Write-DebugLog "`n[*] Configuring $Name"

    try {
        & $Action
        Write-DebugLog "[+] $Name configured successfully"
    }
    catch {
        Write-DebugLog "[!] $Name failed to configure"
        Write-DebugLog $_.Exception.Message

        # Pull recent SCM errors (last 60 seconds)
        $scmEvents = Get-WinEvent -FilterHashtable @{
            LogName      = 'System'
            ProviderName = 'Service Control Manager'
            StartTime    = (Get-Date).AddSeconds(-60)
        } -ErrorAction SilentlyContinue
    
        foreach ($evt in $scmEvents) {
            Write-DebugLog "SCM Event $($evt.Id): $($evt.Message)" "ERROR"
        }
    }
}


# ----------------------------
# Disable Defender (lab only)
# ----------------------------
Set-MpPreference -DisableRealtimeMonitoring $true

# ----------------------------
# Create Lab Accounts
# ----------------------------
$PasswordUser  = ConvertTo-SecureString "ItsColdOutside!" -AsPlainText -Force
$PasswordAdmin = ConvertTo-SecureString "StartWarsWookie1!" -AsPlainText -Force

if (-not (Get-LocalUser -Name "jack.frost.admin" -ErrorAction SilentlyContinue)) {
    New-LocalUser `
        -Name "jack.frost.admin" `
        -Password $PasswordAdmin `
        -FullName "Jack Frost Admin" `
        -Description "Pass: StartWarsWookie1!"
    Add-LocalGroupMember -Group "Administrators" -Member "jack.frost.admin"
}

if (-not (Get-LocalUser -Name "jack.frost" -ErrorAction SilentlyContinue)) {
    New-LocalUser `
        -Name "jack.frost" `
        -Password $PasswordUser `
        -FullName "Jack Frost"
    Add-LocalGroupMember -Group "Remote Desktop Users" -Member "jack.frost"
    Add-LocalGroupMember -Group "Remote Management Users" -Member "jack.frost"
}

# ============================================================
# Vuln 1 – Credentials in Files
# ============================================================
Invoke-Vuln "Vuln 1 - Credentials in Files" {

    Set-Content "C:\Windows\tasks.ps1" @'
$Username = "jack.frost.admin"
$Password = "StartWarsWookie1!"
Invoke-Command -ComputerName 127.0.0.1 -Credential (
    New-Object System.Management.Automation.PSCredential(
        $Username,
        (ConvertTo-SecureString $Password -AsPlainText -Force)
    )
)
'@

    $psrl = "C:\Users\jack.frost\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine"
    New-Item $psrl -ItemType Directory -Force | Out-Null

    Set-Content "$psrl\ConsoleHost_history.txt" @'
New-StoredCredential -Target "globomantics/wks01" `
-Username "jack.frost.admin" `
-Password "StartWarsWookie1!" `
-Persist LocalMachine
'@
}

# ============================================================
# Vuln 2 – Insecure Desktop Shortcut
# ============================================================
Invoke-Vuln "Vuln 2 – Insecure Desktop Shortcut" {

    $binPath = "C:\Services\Bin Files\AdminTools.exe"
    $desktop = "C:\Users\Default\Desktop"
    $lnk     = Join-Path $desktop "Admin Tools.lnk"

    if (-not (Test-Path $binPath)) {
        Copy-Item "C:\Windows\System32\cmd.exe" $binPath -Force
    }

    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($lnk)
    $sc.TargetPath = $binPath
    $sc.WorkingDirectory = "C:\Services\Bin Files"
    $sc.Save()

    icacls $lnk /grant "Everyone:F" | Out-Null
    icacls $desktop /grant "Everyone:F" | Out-Null
}

# ============================================================
# Vuln 3 – Unquoted Service Path
# ============================================================
Invoke-Vuln "Vuln 3 - Unquoted Service Path" {

    if (-not (Get-Service "GloboAgent" -ErrorAction SilentlyContinue)) {
        New-Service `
            -Name "GloboAgent" `
            -BinaryPathName "C:\Services\Bin Files\GloboAgent.exe" `
            -DisplayName "Globomantics Agent" `
            -StartupType Automatic
    }

    Stop-Service -Name "GloboAgent" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Service -Name "GloboAgent"
}

# ============================================================
# Vuln 4 – Writable Service Registry
# ============================================================
Invoke-Vuln "Vuln 4 - Writable Service Registry (GloboCore)" {

    if (-not (Get-Service "GloboCore" -ErrorAction SilentlyContinue)) {
        New-Service `
            -Name "GloboCore" `
            -BinaryPathName '"C:\Services\Bin Files\GloboCore.exe"' `
            -DisplayName "Globomantics Core" `
            -StartupType Automatic
    }

    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\GloboCore"

    $acl = Get-Acl $regPath
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
        "Remote Management Users","FullControl","Allow"
    )
    $acl.SetAccessRule($rule)
    Set-Acl $regPath $acl

    Stop-Service -Name "GloboCore" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Service -Name "GloboCore"

}

# ============================================================
# Vuln 5 – Insecure Script Permissions
# ============================================================
Invoke-Vuln "Vuln 5 - Insecure Script Permissions" {

    New-Item "C:\Scripts" -ItemType Directory -Force | Out-Null

    $path = "C:\Scripts\GloboScript.bat"

    if (-not (Test-Path $path) -or (Get-Content $path -Raw).Length -eq 0) {
        Set-Content "C:\Scripts\GloboScript.bat" "@echo off
echo Running Globo maintenance tasks...
"
    }

    icacls "C:\Scripts\GloboScript.bat" /grant "Remote Management Users:(F)" | Out-Null
    icacls "C:\Windows\System32\Tasks" /grant "Remote Management Users:(OI)(CI)(RX)"
}

# ============================================================
# Vuln 6 – Insecure Scheduled Task (COM / SDDL – CORRECT)
# ============================================================
Invoke-Vuln "Vuln 6 - Insecure Scheduled Task" {

    $taskName = "GloboST"
    $taskPath = "\"
    $taskFile = "C:\Windows\System32\Tasks\GloboST"

    # ------------------------------------------------------------
    # 1. Create task if it does not exist
    # ------------------------------------------------------------
    if (-not (schtasks /query /tn "$taskPath$taskName" 2>$null)) {

        $action = New-ScheduledTaskAction `
            -Execute "cmd.exe" `
            -Argument '/c C:\Scripts\GloboScript.bat' `
            -WorkingDirectory "C:\Scripts"

        $trigger = New-ScheduledTaskTrigger `
            -Once `
            -At (Get-Date) `
            -RepetitionInterval (New-TimeSpan -Minutes 1) `
            -RepetitionDuration (New-TimeSpan -Days 999)

        Register-ScheduledTask `
            -TaskName $taskName `
            -TaskPath $taskPath `
            -Action $action `
            -Trigger $trigger `
            -RunLevel Highest `
            -User "SYSTEM"
    }

    # ------------------------------------------------------------
    # 2. Use Task Scheduler COM API to modify Security Descriptor
    #    (This is the OSDeploy pattern)
    # ------------------------------------------------------------
    $service = New-Object -ComObject "Schedule.Service"
    $service.Connect()

    $rootFolder = $service.GetFolder("\")
    $task       = $rootFolder.GetTask($taskName)

    # Read existing SDDL
    $currentSDDL = $task.GetSecurityDescriptor(0xF)

    # ACE for Remote Management Users (S-1-5-32-580)
    $rmuAce = "(A;;0x1f01ff;;;S-1-5-32-580)"

    # Only add if not already present
    if ($currentSDDL -notmatch ";;;RM") {
        $newSDDL = $currentSDDL + $rmuAce
        $task.SetSecurityDescriptor($newSDDL, 0)
    }

    # ------------------------------------------------------------
    # 3. Weaken NTFS permissions on task file
    # ------------------------------------------------------------
    icacls $taskFile /grant "Remote Management Users:(R,W)" | Out-Null

    # ------------------------------------------------------------
    # 4. Start task once
    # ------------------------------------------------------------
    schtasks /run /tn "$taskPath$taskName" | Out-Null
}

# ============================================================
# Vuln 9 – DLL Hijacking Service
# ============================================================
Invoke-Vuln "Vuln 9 - DLL Hijacking (Service)" {

    if (-not (Get-Service "GloboHostMgr" -ErrorAction SilentlyContinue)) {
        New-Service `
            -Name "GloboHostMgr" `
            -BinaryPathName '"C:\Services\Bin Files\GloboHostMgr.exe"' `
            -DisplayName "Globomantics Host Manager" `
            -StartupType Automatic
    }

    Stop-Service -Name "GloboHostMgr" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Service -Name "GloboHostMgr"
}

$IISFlag = "C:\Windows\.iis_installing"
$IISDone = "C:\Windows\.iis_installed"

# ============================================================
# Vuln 10 – Token Impersonation (IIS)
# ============================================================
Invoke-Vuln "Vuln 10 - Token Impersonation" {

    if (-not (Test-Path $IISDone) -and -not (Test-Path $IISFlag)) {

        Write-DebugLog "Starting IIS installation in background"
        New-Item $IISFlag -ItemType File -Force | Out-Null

        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Install-WindowsFeature Web-Server,Web-Asp-Net45 -IncludeManagementTools; New-Item '$IISDone' -ItemType File -Force; Remove-Item '$IISFlag' -Force`"" `
            -WindowStyle Hidden

        return
    }

    if (-not (Test-Path $IISDone)) {
        Write-DebugLog "IIS still installing, skipping ACL changes"
        return
    }

    icacls "C:\inetpub\wwwroot" /grant "Remote Management Users:(F)" | Out-Null
}

Write-DebugLog "`n[*] Lab configuration complete."
