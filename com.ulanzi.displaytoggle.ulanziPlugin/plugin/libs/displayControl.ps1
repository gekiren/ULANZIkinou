param(
    [string]$Action
)

Add-Type -AssemblyName System.Windows.Forms

# SystemRoot環境変数の解決（フォールバック付き）
$sysRoot = $env:SystemRoot
if (-not $sysRoot) {
    $sysRoot = "C:\Windows"
}
$displaySwitch = Join-Path $sysRoot "System32\DisplaySwitch.exe"

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
        & $displaySwitch /extend
        Start-Sleep -Milliseconds 800  # 画面切り替えのOS処理待ちを少し長めにする
        $newCount = [System.Windows.Forms.Screen]::AllScreens.Length
        if ($newCount -gt 1) {
            Write-Output "Extend"
        } else {
            Write-Output "Internal"
        }
    } else {
        # 現在拡張 -> PCのみへ変更
        & $displaySwitch /internal
        Start-Sleep -Milliseconds 800  # 画面切り替えのOS処理待ちを少し長めにする
        $newCount = [System.Windows.Forms.Screen]::AllScreens.Length
        if ($newCount -eq 1) {
            Write-Output "Internal"
        } else {
            Write-Output "Extend"
        }
    }
}
