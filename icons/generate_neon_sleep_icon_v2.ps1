Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing

function Generate-NeonSleepIconV2 {
    param(
        [string]$OutputPath,
        [int]$Size = 232,
        [bool]$AddGlow = $true
    )

    $dg = New-Object System.Windows.Media.DrawingGroup
    $ctx = $dg.Open()

    $scale = $Size / 100.0
    $transform = New-Object System.Windows.Media.ScaleTransform($scale, $scale)
    $ctx.PushTransform($transform)

    # Vivid Neon Gradient: Purple/Magenta -> Electric Cyan
    $gradientBrush = New-Object System.Windows.Media.LinearGradientBrush
    $gradientBrush.StartPoint = New-Object System.Windows.Point(0.15, 0.85)
    $gradientBrush.EndPoint = New-Object System.Windows.Point(0.85, 0.15)
    
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 175, 75, 255), 0.0)))  # Neon Purple (#AF4BFF)
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 110, 160, 255), 0.45))) # Blue Violet
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 0, 225, 255), 1.0)))    # Electric Cyan (#00E1FF)

    # Geometries
    $moonPath = [System.Windows.Media.Geometry]::Parse("M 46,11 C 19,15 9,35 9,56 C 9,78 27,92 56,92 C 70,92 80,86 86,76 C 58,78 27,62 27,42 C 27,25 36,15 46,11 Z")
    $powerArc = [System.Windows.Media.Geometry]::Parse("M 48,37.5 A 17.5,17.5 0 1 0 66,37.5")
    $powerBar = [System.Windows.Media.Geometry]::Parse("M 57,25 L 57,47")

    if ($AddGlow) {
        # Soft outer neon glow stroke
        $glowBrush = New-Object System.Windows.Media.LinearGradientBrush
        $glowBrush.StartPoint = New-Object System.Windows.Point(0.15, 0.85)
        $glowBrush.EndPoint = New-Object System.Windows.Point(0.85, 0.15)
        $glowBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(80, 175, 75, 255), 0.0)))
        $glowBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(80, 110, 160, 255), 0.45)))
        $glowBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(80, 0, 225, 255), 1.0)))

        $glowPen = New-Object System.Windows.Media.Pen($glowBrush, 10.0)
        $glowPen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
        $glowPen.EndLineCap = [System.Windows.Media.PenLineCap]::Round
        $glowPen.LineJoin = [System.Windows.Media.PenLineJoin]::Round

        $ctx.DrawGeometry($null, $glowPen, $moonPath)
        $ctx.DrawGeometry($null, $glowPen, $powerArc)
        $ctx.DrawGeometry($null, $glowPen, $powerBar)
    }

    # Core stroke pen
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
}

$previewDir = "C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea"
Generate-NeonSleepIconV2 -OutputPath "$previewDir\neon_sleep_glow.png" -Size 232 -AddGlow $true
Generate-NeonSleepIconV2 -OutputPath "$previewDir\neon_sleep_noglow.png" -Size 232 -AddGlow $false
