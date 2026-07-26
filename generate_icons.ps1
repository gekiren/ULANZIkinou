Add-Type -AssemblyName System.Drawing

$assetsDir = "c:\ULANZIkinou\com.ulanzi.mycustomplugin.ulanziPlugin\assets"

function Make-WideIcon($v) {
    # 横長アスペクト比 252x160 px
    $width = 252
    $height = 160

    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    
    # 背景
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 21, 24, 34))
    $g.FillRectangle($bgBrush, 0, 0, $width, $height)

    # 圧倒的な特大フォント (100%は62pt、2桁は76pt)
    [float]$fontSize = if ($v -eq 100) { 62.0 } else { 76.0 }
    $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 229, 255))
    
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    $rect = New-Object System.Drawing.RectangleF(0, 0, $width, $height)
    $g.DrawString("$v%", $font, $brush, $rect, $sf)

    $g.Dispose()
    $outputPath = Join-Path $assetsDir "vol_$v.png"
    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

0..10 | ForEach-Object {
    Make-WideIcon ($_ * 10)
}

Write-Host "Generated ultra-wide massive text PNG icons clean."
