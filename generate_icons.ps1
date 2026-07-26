Add-Type -AssemblyName System.Drawing

$assetsDir = "c:\ULANZIkinou\com.ulanzi.mycustomplugin.ulanziPlugin\assets"

for ($i = 0; $i -le 10; $i++) {
    $v = $i * 10
    $bmp = New-Object System.Drawing.Bitmap(144, 144)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 21, 24, 34))
    $g.FillRectangle($bgBrush, 0, 0, 144, 144)

    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 0, 229, 255), 4)
    $g.DrawRectangle($pen, 2, 2, 140, 140)

    $fontSize = if ($v -eq 100) { 30 } else { 36 }
    $font = New-Object System.Drawing.Font("Arial", $fontSize, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 229, 255))
    
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center

    $rect = New-Object System.Drawing.RectangleF(0, 0, 144, 144)
    $g.DrawString("$v%", $font, $brush, $rect, $sf)

    $g.Dispose()
    $outputPath = Join-Path $assetsDir "vol_$v.png"
    $bmp.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

Write-Host "Generated clean 144x144 high-res icons."
