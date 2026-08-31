$plugins = @(
    "com.ulanzi.apprestart.ulanziPlugin",
    "com.ulanzi.pcsleep.ulanziPlugin",
    "com.ulanzi.ulanzistudio.displaytoggle.ulanziPlugin",
    "com.ulanzi.ulanzistudio.lineincontrol.ulanziPlugin",
    "com.ulanzi.ulanzistudio.mastervolume.ulanziPlugin",
    "com.ulanzi.videofullscreen.ulanziPlugin"
)
$sourceLib = "c:\ULANZIkinou\KOUSIKI\UlanziDeckPlugin-SDK-main\UlanziDeckSimulator\plugins\com.ulanzi.displaytoggle.ulanziPlugin\plugin\libs\ulanziNodeApi.js"
if (-not (Test-Path $sourceLib)) {
    $sourceLib = "c:\ULANZIkinou\com.ulanzi.apprestart.ulanziPlugin\plugin\libs\ulanziNodeApi.js"
}

foreach ($p in $plugins) {
    $targetDir = "c:\ULANZIkinou\$p\plugin\libs"
    if (-not (Test-Path $targetDir)) {
        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path $sourceLib -Destination "$targetDir\ulanziNodeApi.js" -Force
    Write-Host "Synced ulanziNodeApi.js to $p"
}
