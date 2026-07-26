Add-Type -AssemblyName System.Drawing

$assetsDir = "c:\ULANZIkinou\com.ulanzi.mycustomplugin.ulanziPlugin\assets"

function Make-WideIcon($v, $text, $colorHex, [float]$fSize) {
    $width = 252
    $height = 160

    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    
    # 背景
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 21, 24, 34))
    $g.FillRectangle($bgBrush, 0, 0, $width, $height)

    $font = New-Object System.Drawing.Font("Arial", $fSize, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($colorHex))
    
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    $rect = New-Object System.Drawing.RectangleF(0, 0, $width, $height)
    $g.DrawString($text, $font, $brush, $rect, $sf)

    $g.Dispose()
    $outputPath = Join-Path $assetsDir "vol_$v.png"
    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# 0% 〜 95% (5%刻み 計20枚)
0..19 | ForEach-Object {
    $v = $_ * 5
    Make-WideIcon $v "$v%" "#00E5FF" 76.0
}
# 100%
Make-WideIcon 100 "100%" "#00E5FF" 62.0

# MUTE
Make-WideIcon "mute" "MUTE" "#FF4D4D" 58.0

Write-Host "Generated 5-percent step volume PNG icons (total 22 icons) clean."
