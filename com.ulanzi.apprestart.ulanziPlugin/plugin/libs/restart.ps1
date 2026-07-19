param (
    [string]$ProcessName = "UlanziDeck"
)

$process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
if (-not $process) {
    $process = Get-Process -Name "Ulanzi Studio" -ErrorAction SilentlyContinue
}

if ($process) {
    $targetProcess = $process[0]
    $path = $targetProcess.Path
    
    if ($path) {
        # 一時VBScriptファイルを作成して、非表示でデタッチ遅延起動させる
        $vbsPath = Join-Path $PSScriptRoot "restart_temp.vbs"
        $vbsContent = @(
            "Set WshShell = CreateObject(`"WScript.Shell`")",
            "WScript.Sleep 3000",
            "WshShell.Run `"`"`"$path`"`"`", 1, False",
            "Set fso = CreateObject(`"Scripting.FileSystemObject`")",
            "fso.DeleteFile WScript.ScriptFullName"
        )
        Set-Content -Path $vbsPath -Value $vbsContent -Encoding Ascii
        
        # タスクスケジューラに一時的なタスクとして登録して即時実行 (wscript.exeを使用して黒画面を完全に非表示にする)
        $taskName = "UlanziRestart_Temp"
        schtasks /create /tn $taskName /tr "wscript.exe `"$vbsPath`"" /sc ONCE /st 00:00 /it /f | Out-Null
        schtasks /run /tn $taskName | Out-Null
        schtasks /delete /tn $taskName /f | Out-Null
        
        # 現在のプロセスをキルする
        Stop-Process -Name $targetProcess.ProcessName -Force
    } else {
        Write-Error "Failed to retrieve process path."
    }
} else {
    Write-Error "Process $ProcessName not found."
}
