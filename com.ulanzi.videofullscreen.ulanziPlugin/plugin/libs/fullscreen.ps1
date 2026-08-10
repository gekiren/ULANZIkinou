# PowerShell script to detect active window process and send appropriate fullscreen key
Add-Type -AssemblyName System.Windows.Forms

$signature = @"
[DllImport("user32.dll")]
public static extern IntPtr GetForegroundWindow();

[DllImport("user32.dll", SetLastError=true)]
public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
"@

$user32 = Add-Type -MemberDefinition $signature -Name "User32Utils" -Namespace "Win32UtilsNamespace" -PassThru

$hwnd = [Win32UtilsNamespace.User32Utils]::GetForegroundWindow()
if ($hwnd -eq [IntPtr]::Zero) {
    Write-Output "No active window found."
    exit 0
}

$processId = 0
[Win32UtilsNamespace.User32Utils]::GetWindowThreadProcessId($hwnd, [ref]$processId) | Out-Null

if ($processId -eq 0) {
    Write-Output "Failed to get process ID."
    exit 0
}

$proc = Get-Process -Id $processId -ErrorAction SilentlyContinue
if (-not $proc) {
    Write-Output "Process not found."
    exit 0
}

$procName = $proc.ProcessName.ToLower()
Write-Output "Active Process: $procName"

# Safety Guard for Desktop/System Shell
if ($procName -eq "explorer" -or $procName -eq "shellexperiencehost" -or $procName -eq "searchhost") {
    Write-Output "Skipping system shell window."
    exit 0
}

$browserProcesses = @("chrome", "msedge", "firefox", "brave", "opera", "vivaldi", "thorium")
$mediaPlayerProcesses = @("vlc", "mpc-hc", "mpc-hc64", "mpc-be", "potplayermini64", "wmplayer", "kmplayer", "mpv")

if ($browserProcesses -contains $procName) {
    Write-Output "Target: Browser -> Sending F11"
    [System.Windows.Forms.SendKeys]::SendWait("{F11}")
} elseif ($mediaPlayerProcesses -contains $procName) {
    Write-Output "Target: Media Player -> Sending Alt+Enter"
    [System.Windows.Forms.SendKeys]::SendWait("%{ENTER}")
} else {
    Write-Output "Target: General App -> Sending F11"
    [System.Windows.Forms.SendKeys]::SendWait("{F11}")
}
