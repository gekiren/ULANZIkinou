Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing

function Generate-NeonSleepIcon {
    param(
        [string]$OutputPath,
        [int]$Size = 232
    )

    $dg = New-Object System.Windows.Media.DrawingGroup
    $ctx = $dg.Open()

    # Scale from 100x100 to target size
    $scale = $Size / 100.0
    $transform = New-Object System.Windows.Media.ScaleTransform($scale, $scale)
    $ctx.PushTransform($transform)

    # Neon Gradient Brush (From Purple/Magenta at bottom-left to Cyan/SkyBlue at top-right)
    $gradientBrush = New-Object System.Windows.Media.LinearGradientBrush
    $gradientBrush.StartPoint = New-Object System.Windows.Point(0.2, 0.9)
    $gradientBrush.EndPoint = New-Object System.Windows.Point(0.8, 0.1)
    
    # Purple/Magenta (#C084FC / #A855F7 / #D946EF) -> Cyan/Electric Blue (#06B6D4 / #38BDF8 / #00F0FF)
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 192, 132, 252), 0.0))) # Purple
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 147, 197, 253), 0.5))) # Light blue-violet
    $gradientBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 56, 189, 248), 1.0)))  # Bright cyan

    # Stroke pen setup (crisp, rounded ends)
    $pen = New-Object System.Windows.Media.Pen($gradientBrush, 6.0)
    $pen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    # 1. Crescent Moon (Smooth continuous contour)
    $moonPath = [System.Windows.Media.Geometry]::Parse("M 46,11 C 19,15 9,35 9,56 C 9,78 27,92 56,92 C 70,92 80,86 86,76 C 58,78 27,62 27,42 C 27,25 36,15 46,11 Z")
    $ctx.DrawGeometry($null, $pen, $moonPath)

    # 2. Power Symbol (Inside the moon)
    $powerArc = [System.Windows.Media.Geometry]::Parse("M 48,37.5 A 17.5,17.5 0 1 0 66,37.5")
    $ctx.DrawGeometry($null, $pen, $powerArc)

    # Power vertical bar
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

$previewDir = "C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea"
Generate-NeonSleepIcon -OutputPath "$previewDir\neon_sleep_preview.png" -Size 232
