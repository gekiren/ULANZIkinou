Add-Type -AssemblyName System.Drawing, PresentationCore, PresentationFramework, WindowsBase

$srcPath = "C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea\.user_uploaded\media_1787428071880.jpg"
$srcBmp = New-Object System.Drawing.Bitmap($srcPath)

$w = $srcBmp.Width
$h = $srcBmp.Height

# Create 32-bit ARGB bitmap
$dstBmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

# Lock bits for high-speed pixel manipulation
$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$srcData = $srcBmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$dstData = $dstBmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

$bytes = [Math]::Abs($srcData.Stride) * $h
$srcBytes = New-Object byte[] $bytes
$dstBytes = New-Object byte[] $bytes

[System.Runtime.InteropServices.Marshal]::Copy($srcData.Scan0, $srcBytes, 0, $bytes)
$srcBmp.UnlockBits($srcData)

# Bounding box trackers
$minX = $w; $minY = $h; $maxX = 0; $maxY = 0

for ($i = 0; $i -lt $bytes; $i += 4) {
    $b = [double]$srcBytes[$i]
    $g = [double]$srcBytes[$i + 1]
    $r = [double]$srcBytes[$i + 2]

    # Calculate brightness
    $maxVal = [Math]::Max($r, [Math]::Max($g, $b))

    # Black floor cutoff
    $floor = 18.0
    if ($maxVal -gt $floor) {
        $alphaNorm = ($maxVal - $floor) / (255.0 - $floor)
        # Apply smooth alpha curve
        $alpha = [Math]::Min(255.0, $alphaNorm * 255.0 * 1.35)
        
        # Color boost
        $boost = [Math]::Min(1.8, [Math]::Max(1.0, 255.0 / [Math]::Max($alpha, 30.0)))
        $rOut = [byte][Math]::Min(255.0, $r * $boost)
        $gOut = [byte][Math]::Min(255.0, $g * $boost)
        $bOut = [byte][Math]::Min(255.0, $b * $boost)
        $aOut = [byte]$alpha

        $dstBytes[$i] = $bOut
        $dstBytes[$i + 1] = $gOut
        $dstBytes[$i + 2] = $rOut
        $dstBytes[$i + 3] = $aOut

        if ($aOut -gt 25) {
            $pixelIdx = $i / 4
            $px = $pixelIdx % $w
            $py = [Math]::Floor($pixelIdx / $w)
            if ($px -lt $minX) { $minX = $px }
            if ($px -gt $maxX) { $maxX = $px }
            if ($py -lt $minY) { $minY = $py }
            if ($py -gt $maxY) { $maxY = $py }
        }
    } else {
        $dstBytes[$i] = 0
        $dstBytes[$i + 1] = 0
        $dstBytes[$i + 2] = 0
        $dstBytes[$i + 3] = 0
    }
}

[System.Runtime.InteropServices.Marshal]::Copy($dstBytes, 0, $dstData.Scan0, $bytes)
$dstBmp.UnlockBits($dstData)
$srcBmp.Dispose()

# Crop to bounding box
$cropWidth = $maxX - $minX + 1
$cropHeight = $maxY - $minY + 1
$cropRect = New-Object System.Drawing.Rectangle($minX, $minY, $cropWidth, $cropHeight)
$croppedBmp = $dstBmp.Clone($cropRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$dstBmp.Dispose()

# Create padded square bitmap (adding ~25% padding for deck button comfort)
$maxDim = [Math]::Max($cropWidth, $cropHeight)
$targetDim = [int]($maxDim * 1.30)

$paddedBmp = New-Object System.Drawing.Bitmap($targetDim, $targetDim, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($paddedBmp)
$g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$offsetX = ($targetDim - $cropWidth) / 2
$offsetY = ($targetDim - $cropHeight) / 2
$g.DrawImage($croppedBmp, [float]$offsetX, [float]$offsetY, [float]$cropWidth, [float]$cropHeight)
$g.Dispose()
$croppedBmp.Dispose()

# Function to save resized PNG
function Save-Resized {
    param([string]$Path, [int]$Size)

    $parent = [System.IO.Path]::GetDirectoryName($Path)
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    $outBmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gOut = [System.Drawing.Graphics]::FromImage($outBmp)
    $gOut.Clear([System.Drawing.Color]::Transparent)
    $gOut.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gOut.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gOut.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $gOut.DrawImage($paddedBmp, 0, 0, $Size, $Size)
    $gOut.Dispose()

    $outBmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $outBmp.Dispose()
    Write-Host "Saved: $Path ($Size x $Size)"
}

# Target paths
$assetsDir = "C:\ULANZIkinou\com.ulanzi.pcsleep.ulanziPlugin\assets"
$deployDir = "C:\Users\toshi\AppData\Roaming\Ulanzi\UlanziDeck\Plugins\com.ulanzi.pcsleep.ulanziPlugin\assets"
$previewDir = "C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea"

foreach ($dir in @($assetsDir, $deployDir)) {
    Save-Resized -Path "$dir\icon.png" -Size 144
    Save-Resized -Path "$dir\actionDefaultImage.png" -Size 232
    Save-Resized -Path "$dir\categoryIcon.png" -Size 196
    Save-Resized -Path "$dir\actionIcon.png" -Size 40
}

Save-Resized -Path "$previewDir\reference_based_sleep_icon.png" -Size 232

$paddedBmp.Dispose()
