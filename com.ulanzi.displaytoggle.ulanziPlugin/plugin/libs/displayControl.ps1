param(
    [string]$Action
)

Add-Type -AssemblyName System.Windows.Forms

if ($Action -eq "GetStatus") {
    $screenCount = [System.Windows.Forms.Screen]::AllScreens.Length
    if ($screenCount -eq 1) {
        Write-Output "Internal"
    } else {
        Write-Output "Extend"
    }
} elseif ($Action -eq "Toggle") {
    $screenCount = [System.Windows.Forms.Screen]::AllScreens.Length
    if ($screenCount -eq 1) {
        # 現在PCのみ -> 拡張へ変更
        & "$env:SystemRoot\System32\DisplaySwitch.exe" /extend
        Start-Sleep -Milliseconds 500
        $newCount = [System.Windows.Forms.Screen]::AllScreens.Length
        if ($newCount -gt 1) {
            Write-Output "Extend"
        } else {
            Write-Output "Internal"
        }
    } else {
        # 現在拡張 -> PCのみへ変更
        & "$env:SystemRoot\System32\DisplaySwitch.exe" /internal
        Start-Sleep -Milliseconds 500
        $newCount = [System.Windows.Forms.Screen]::AllScreens.Length
        if ($newCount -eq 1) {
            Write-Output "Internal"
        } else {
            Write-Output "Extend"
        }
    }
}
