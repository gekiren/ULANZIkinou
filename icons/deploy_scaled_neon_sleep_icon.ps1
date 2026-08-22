Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing

function Generate-ScaledNeonSleepIcon {
    param(
        [string]$OutputPath,
        [int]$Size = 232,
        [double]$IconScale = 0.76  # ~76% size for perfect padding on deck button
    )

    $dg = New-Object System.Windows.Media.DrawingGroup
    $ctx = $dg.Open()

    # Base scale to target size
    $baseScale = $Size / 100.0
    $transformGroup = New-Object System.Windows.Media.TransformGroup
    
    # 1. Scale down around center (50, 50)
    $innerScale = New-Object System.Windows.Media.ScaleTransform($IconScale, $IconScale, 50, 50)
    $transformGroup.Children.Add($innerScale)

    # 2. Scale to bitmap resolution
    $resScale = New-Object System.Windows.Media.ScaleTransform($baseScale, $baseScale)
    $transformGroup.Children.Add($resScale)

    $ctx.PushTransform($transformGroup)

    # Vivid Neon Gradient
    $gradientBrush = New-Object System.Windows.Media.LinearGradientBrush
    $gradientBrush.StartPoint = New-Object System.Windows.Point(0.15, 0.85)
    $gradientBrush.EndPoint = New-Object System.Windows.Point(0.85, 0.15)
    
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 175, 75, 255), 0.0)))  # Neon Purple
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 110, 160, 255), 0.45))) # Blue Violet
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 0, 225, 255), 1.0)))    # Electric Cyan

    # Geometries
    $moonPath = [System.Windows.Media.Geometry]::Parse("M 46,11 C 19,15 9,35 9,56 C 9,78 27,92 56,92 C 70,92 80,86 86,76 C 58,78 27,62 27,42 C 27,25 36,15 46,11 Z")
    $powerArc = [System.Windows.Media.Geometry]::Parse("M 48,37.5 A 17.5,17.5 0 1 0 66,37.5")
    $powerBar = [System.Windows.Media.Geometry]::Parse("M 57,25 L 57,47")

    # Soft outer neon glow stroke
    $glowBrush = New-Object System.Windows.Media.LinearGradientBrush
    $glowBrush.StartPoint = New-Object System.Windows.Point(0.15, 0.85)
    $glowBrush.EndPoint = New-Object System.Windows.Point(0.85, 0.15)
    $glowBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(90, 175, 75, 255), 0.0)))
    $glowBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(90, 110, 160, 255), 0.45)))
    $glowBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(90, 0, 225, 255), 1.0)))

    $glowPen = New-Object System.Windows.Media.Pen($glowBrush, 9.5)
    $glowPen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $glowPen.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $glowPen.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    $ctx.DrawGeometry($null, $glowPen, $moonPath)
    $ctx.DrawGeometry($null, $glowPen, $powerArc)
    $ctx.DrawGeometry($null, $glowPen, $powerBar)

    # Core crisp stroke pen
    $corePen = New-Object System.Windows.Media.Pen($gradientBrush, 6.0)
    $corePen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $corePen.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $corePen.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    $ctx.DrawGeometry($null, $corePen, $moonPath)
    $ctx.DrawGeometry($null, $corePen, $powerArc)
    $ctx.DrawGeometry($null, $corePen, $powerBar)

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

# 1. Local plugin assets
$assetsDir = "C:\ULANZIkinou\com.ulanzi.pcsleep.ulanziPlugin\assets"
Generate-ScaledNeonSleepIcon -OutputPath "$assetsDir\icon.png" -Size 144
Generate-ScaledNeonSleepIcon -OutputPath "$assetsDir\actionDefaultImage.png" -Size 232
Generate-ScaledNeonSleepIcon -OutputPath "$assetsDir\categoryIcon.png" -Size 196
Generate-ScaledNeonSleepIcon -OutputPath "$assetsDir\actionIcon.png" -Size 40

# 2. Deployed Plugin assets
$deployAssetsDir = "C:\Users\toshi\AppData\Roaming\Ulanzi\UlanziDeck\Plugins\com.ulanzi.pcsleep.ulanziPlugin\assets"
Generate-ScaledNeonSleepIcon -OutputPath "$deployAssetsDir\icon.png" -Size 144
Generate-ScaledNeonSleepIcon -OutputPath "$deployAssetsDir\actionDefaultImage.png" -Size 232
Generate-ScaledNeonSleepIcon -OutputPath "$deployAssetsDir\categoryIcon.png" -Size 196
Generate-ScaledNeonSleepIcon -OutputPath "$deployAssetsDir\actionIcon.png" -Size 40

# 3. Preview
$previewDir = "C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea"
Generate-ScaledNeonSleepIcon -OutputPath "$previewDir\scaled_neon_sleep_icon.png" -Size 232
