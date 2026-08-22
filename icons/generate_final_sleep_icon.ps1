Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing

function Generate-FinalSleepIcon {
    param(
        [string]$OutputPath,
        [int]$Size = 232
    )

    $dg = New-Object System.Windows.Media.DrawingGroup
    $ctx = $dg.Open()

    $whiteBrush = [System.Windows.Media.Brushes]::White
    
    # Scale from 100x100 to target size
    $scale = $Size / 100.0
    $transform = New-Object System.Windows.Media.ScaleTransform($scale, $scale)
    $ctx.PushTransform($transform)

    # Stroke pen setup (crisp, rounded ends)
    $pen = New-Object System.Windows.Media.Pen($whiteBrush, 5.8)
    $pen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    # 1. Crescent Moon (Smooth continuous contour)
    # Balanced outer and inner curves
    $moonPath = [System.Windows.Media.Geometry]::Parse("M 46,11 C 19,15 9,35 9,56 C 9,78 27,92 56,92 C 70,92 80,86 86,76 C 58,78 27,62 27,42 C 27,25 36,15 46,11 Z")
    $ctx.DrawGeometry($null, $pen, $moonPath)

    # 2. Power Symbol (Perfect alignment inside the moon)
    # Center at (57, 51), radius = 17.5
    # Power circle open arc:
    $powerArc = [System.Windows.Media.Geometry]::Parse("M 48,37.5 A 17.5,17.5 0 1 0 66,37.5")
    $ctx.DrawGeometry($null, $pen, $powerArc)

    # Power vertical bar: from (57, 25) to (57, 47)
    $powerBar = [System.Windows.Media.Geometry]::Parse("M 57,25 L 57,47")
    $ctx.DrawGeometry($null, $pen, $powerBar)

    $ctx.Pop()
    $ctx.Close()

    # Render
    $drawingVisual = New-Object System.Windows.Media.DrawingVisual
    $visualContext = $drawingVisual.RenderOpen()
    $visualContext.DrawDrawing($dg)
    $visualContext.Close()

    $renderTarget = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($Size, $Size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $renderTarget.Render($drawingVisual)

    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($renderTarget))
    
    $parentDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $stream = [System.IO.File]::Create($OutputPath)
    $encoder.Save($stream)
    $stream.Close()
    Write-Host "Generated: $OutputPath ($Size x $Size)"
}

# 1. Generate to local plugin assets
$assetsDir = "C:\ULANZIkinou\com.ulanzi.pcsleep.ulanziPlugin\assets"
Generate-FinalSleepIcon -OutputPath "$assetsDir\icon.png" -Size 144
Generate-FinalSleepIcon -OutputPath "$assetsDir\actionDefaultImage.png" -Size 232
Generate-FinalSleepIcon -OutputPath "$assetsDir\categoryIcon.png" -Size 196
Generate-FinalSleepIcon -OutputPath "$assetsDir\actionIcon.png" -Size 40

# 2. Deploy directly to Ulanzi Deck roaming plugins directory
$deployAssetsDir = "C:\Users\toshi\AppData\Roaming\Ulanzi\UlanziDeck\Plugins\com.ulanzi.pcsleep.ulanziPlugin\assets"
Generate-FinalSleepIcon -OutputPath "$deployAssetsDir\icon.png" -Size 144
Generate-FinalSleepIcon -OutputPath "$deployAssetsDir\actionDefaultImage.png" -Size 232
Generate-FinalSleepIcon -OutputPath "$deployAssetsDir\categoryIcon.png" -Size 196
Generate-FinalSleepIcon -OutputPath "$deployAssetsDir\actionIcon.png" -Size 40

# 3. Generate preview in artifact directory
$previewDir = "C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea"
Generate-FinalSleepIcon -OutputPath "$previewDir\final_sleep_icon.png" -Size 232
