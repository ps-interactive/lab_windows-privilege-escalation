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

function Invoke-RunInActiveSession {
    param(
        [string]$Exe,
        [string]$Arguments = "",
        [string]$WorkingDirectory = ""
    )

    Add-Type -AssemblyName System.Runtime.InteropServices

    $source = @"
using System;
using System.Runtime.InteropServices;

public class SessionRunner {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("Wtsapi32.dll", SetLastError = true)]
    public static extern bool WTSQueryUserToken(UInt32 SessionId, out IntPtr Token);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool CreateProcessAsUser(
        IntPtr hToken,
        string lpApplicationName,
        string lpCommandLine,
        IntPtr lpProcessAttributes,
        IntPtr lpThreadAttributes,
        bool bInheritHandles,
        uint dwCreationFlags,
        IntPtr lpEnvironment,
        string lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo,
        out PROCESS_INFORMATION lpProcessInformation
    );

    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO {
        public uint cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public uint dwX;
        public uint dwY;
        public uint dwXSize;
        public uint dwYSize;
        public uint dwXCountChars;
        public uint dwYCountChars;
        public uint dwFillAttribute;
        public uint dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION {
        public IntPtr hProcess;
        public IntPtr hThread;
        public uint dwProcessId;
        public uint dwThreadId;
    }
}
"@

    Add-Type $source

    # Get interactive session ID (session with explorer.exe)
    $session = (Get-Process explorer -ErrorAction Stop | Select-Object -First 1).SessionId

    # Duplicate token
    [IntPtr]$uToken = [IntPtr]::Zero
    [SessionRunner]::WTSQueryUserToken($session, [ref]$uToken) | Out-Null

    # Prepare structures
    $si = New-Object SessionRunner+STARTUPINFO
    $si.cb = [Runtime.InteropServices.Marshal]::SizeOf($si)

    $pi = New-Object SessionRunner+PROCESS_INFORMATION

    $cmd = "`"$Exe`" $Arguments".Trim()

    # Launch inside user session
    [SessionRunner]::CreateProcessAsUser(
        $uToken,
        $Exe,
        $cmd,
        [IntPtr]::Zero,
        [IntPtr]::Zero,
        $false,
        0,
        [IntPtr]::Zero,
        $WorkingDirectory,
        [ref]$si,
        [ref]$pi
    ) | Out-Null
}

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
    Copy-Item "C:\Windows\System32\cmd.exe" "C:\Services\Bin Files\AdminTools.exe"
    $publicDesktop = "C:\Users\Default\Desktop\"
    $shortcutPath = Join-Path $publicDesktop "Admin Tools.lnk"

    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($shortcutPath)
    $sc.TargetPath = $dst
    $sc.WorkingDirectory = $binPath
    $sc.WindowStyle = 1
    $sc.Description = "Admin Tools"
    $sc.Save()

    icacls "C:\Services\Bin Files\AdminTools.exe" /inheritance:r /grant:r "Administrators:F" "SYSTEM:F" /deny "Users:W" | Out-Null
    icacls "$shortcutPath" /grant "Everyone:F" | Out-Null
    icacls "$publicDesktop" /grant "Everyone:F" | Out-Null
}

if (Test-Path "C:\Services\Bin Files\AdminTools.exe") {

    $user = "ps-win-1\jack.frost.admin"
    $pass = ConvertTo-SecureString "StartWarsWookie1!" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $pass)

    $lnk = "C:\Users\Default\Desktop\Admin Tools.lnk"

    # Resolve the shortcut to the EXE
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($lnk)
    $target = $shortcut.TargetPath

    Invoke-RunInActiveSession -Exe $target -WorkingDirectory (Split-Path $target)
}


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
icacls "C:\intepub\wwwroot" /grant "Remote Management Users:(F)"
