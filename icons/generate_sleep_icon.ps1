Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing

function Generate-SleepIcon {
    param(
        [string]$OutputPath,
        [int]$Size = 232
    )

    $drawingGroup = New-Object System.Windows.Media.DrawingGroup
    $drawingContext = $drawingGroup.Open()

    $whiteBrush = [System.Windows.Media.Brushes]::White
    
    # Scale from 100x100
    $scale = $Size / 100.0
    $transform = New-Object System.Windows.Media.ScaleTransform($scale, $scale)
    $drawingContext.PushTransform($transform)

    # Stroke setup (stroke thickness ~ 6.5 in 100x100 space)
    $strokePen = New-Object System.Windows.Media.Pen($whiteBrush, 6.5)
    $strokePen.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $strokePen.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $strokePen.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    # 1. Crescent Moon (Elegant outline/stroke or thin crescent)
    # Let's draw a beautiful crescent moon outline using Geometry
    # Outer arc from top to bottom-right, then inner arc curving back
    # Top tip at (45, 12), bottom-right tip at (76, 76)
    # Outer curve passes through (12, 50)
    # Inner curve passes through (38, 50)
    $moonGeometry = [System.Windows.Media.Geometry]::Parse("M 44,12 C 20,16 10,34 10,54 C 10,76 28,92 56,92 C 68,92 78,86 86,76 C 58,82 34,66 34,44 C 34,30 40,18 44,12 Z")
    $drawingContext.DrawGeometry($whiteBrush, $null, $moonGeometry)

    # 2. Power Symbol (Inside the moon's embrace, centered around 58, 52)
    # Power circle arc: center (58, 52), radius 18
    # Start at angle 310 deg (58 + 18*cos(310) = 58+11.5=69.5, 52 - 18*sin(310) = 52 - 13.8 = 38.2)
    # End at angle 230 deg (58 - 18*cos(230) = 58-11.5=46.5, 38.2)
    $powerArcGeometry = [System.Windows.Media.Geometry]::Parse("M 48.5,38.2 A 18,18 0 1 0 67.5,38.2")
    $drawingContext.DrawGeometry($null, $strokePen, $powerArcGeometry)

    # Power vertical bar: from (58, 25) to (58, 48)
    $powerBarGeometry = [System.Windows.Media.Geometry]::Parse("M 58,25 L 58,48")
    $drawingContext.DrawGeometry($null, $strokePen, $powerBarGeometry)

    $drawingContext.Pop()
    $drawingContext.Close()

    # Render to BitmapSource
    $drawingVisual = New-Object System.Windows.Media.DrawingVisual
    $visualContext = $drawingVisual.RenderOpen()
    $visualContext.DrawDrawing($drawingGroup)
    $visualContext.Close()

    $renderTarget = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($Size, $Size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $renderTarget.Render($drawingVisual)

    # Save to PNG
    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($renderTarget))
    
    $parentDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $stream = [System.IO.File]::OpenWrite($OutputPath)
    $encoder.Save($stream)
    $stream.Close()
}

$previewDir = "C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea"
Generate-SleepIcon -OutputPath "$previewDir\sleep_icon_preview.png" -Size 232
