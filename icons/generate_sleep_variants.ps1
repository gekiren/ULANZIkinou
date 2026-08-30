Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing

function Generate-SleepVariants {
    param([string]$OutDir)

    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

    $whiteBrush = [System.Windows.Media.Brushes]::White

    # ----------------------------------------------------
    # Style 1: Pure Line / Stroke (Exact Match to Modern Deck Icon)
    # ----------------------------------------------------
    $dg1 = New-Object System.Windows.Media.DrawingGroup
    $ctx1 = $dg1.Open()
    
    $pen1 = New-Object System.Windows.Media.Pen($whiteBrush, 6.0)
    $pen1.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen1.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen1.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    # Crescent Moon Path (Single smooth open curve or contour)
    # Outer arc and inner curve
    $moonStroke = [System.Windows.Media.Geometry]::Parse("M 50,12 C 22,12 8,32 8,56 C 8,78 26,92 56,92 C 68,92 78,88 84,82 C 54,84 26,68 26,46 C 26,28 36,18 50,12 Z")
    
    # Let's draw Moon as a stroked shape
    # Crescent moon outline: Outer arc (50,10) -> (10,50) -> (70,90), inner arc (70,90) -> (30,50) -> (50,10)
    $moonOutline = [System.Windows.Media.Geometry]::Parse("M 46,12 C 20,16 10,34 10,54 C 10,76 28,90 56,90 C 68,90 78,84 84,76 C 58,78 30,62 30,42 C 30,26 38,16 46,12")
    $ctx1.DrawGeometry($null, $pen1, $moonOutline)

    # Power circle arc: center (58, 52), radius 17
    $powerArc1 = [System.Windows.Media.Geometry]::Parse("M 49,39 A 17,17 0 1 0 67,39")
    $ctx1.DrawGeometry($null, $pen1, $powerArc1)

    # Power vertical bar: (58, 25) to (58, 48)
    $powerBar1 = [System.Windows.Media.Geometry]::Parse("M 58,25 L 58,48")
    $ctx1.DrawGeometry($null, $pen1, $powerBar1)

    $ctx1.Close()
    Save-DrawingGroup -DrawingGroup $dg1 -FilePath "$OutDir\variant1_line.png" -Size 232

    # ----------------------------------------------------
    # Style 2: Elegant Solid Moon + Power Stroke
    # ----------------------------------------------------
    $dg2 = New-Object System.Windows.Media.DrawingGroup
    $ctx2 = $dg2.Open()

    $pen2 = New-Object System.Windows.Media.Pen($whiteBrush, 6.0)
    $pen2.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen2.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen2.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    # Smooth solid moon
    $moonSolid = [System.Windows.Media.Geometry]::Parse("M 46,12 C 22,15 10,32 10,52 C 10,74 26,88 54,88 C 66,88 76,82 82,74 C 58,76 28,62 28,42 C 28,26 36,16 46,12 Z")
    $ctx2.DrawGeometry($whiteBrush, $null, $moonSolid)

    # Power circle arc: center (58, 50), radius 17
    $powerArc2 = [System.Windows.Media.Geometry]::Parse("M 49,37 A 17,17 0 1 0 67,37")
    $ctx2.DrawGeometry($null, $pen2, $powerArc2)

    # Power vertical bar: (58, 23) to (58, 46)
    $powerBar2 = [System.Windows.Media.Geometry]::Parse("M 58,23 L 58,46")
    $ctx2.DrawGeometry($null, $pen2, $powerBar2)

    $ctx2.Close()
    Save-DrawingGroup -DrawingGroup $dg2 -FilePath "$OutDir\variant2_solid_moon.png" -Size 232

    # ----------------------------------------------------
    # Style 3: Clean Nested Line Icon (Centered and balanced)
    # ----------------------------------------------------
    $dg3 = New-Object System.Windows.Media.DrawingGroup
    $ctx3 = $dg3.Open()

    $pen3 = New-Object System.Windows.Media.Pen($whiteBrush, 5.5)
    $pen3.StartLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen3.EndLineCap = [System.Windows.Media.PenLineCap]::Round
    $pen3.LineJoin = [System.Windows.Media.PenLineJoin]::Round

    # Moon arc (outer stroke and inner stroke creating closed crescent)
    $moonPath3 = [System.Windows.Media.Geometry]::Parse("M 45,10 C 18,14 8,34 8,55 C 8,78 26,92 56,92 C 70,92 80,86 86,76 C 58,78 26,62 26,42 C 26,24 35,14 45,10 Z")
    $ctx3.DrawGeometry($null, $pen3, $moonPath3)

    # Power circle
    $powerArc3 = [System.Windows.Media.Geometry]::Parse("M 49,38 A 17.5,17.5 0 1 0 67,38")
    $ctx3.DrawGeometry($null, $pen3, $powerArc3)

    $powerBar3 = [System.Windows.Media.Geometry]::Parse("M 58,24 L 58,47")
    $ctx3.DrawGeometry($null, $pen3, $powerBar3)

    $ctx3.Close()
    Save-DrawingGroup -DrawingGroup $dg3 -FilePath "$OutDir\variant3_line_closed.png" -Size 232
}

function Save-DrawingGroup {
    param($DrawingGroup, $FilePath, $Size)

    $scale = $Size / 100.0
    $transform = New-Object System.Windows.Media.ScaleTransform($scale, $scale)

    $drawingVisual = New-Object System.Windows.Media.DrawingVisual
    $visualContext = $drawingVisual.RenderOpen()
    $visualContext.PushTransform($transform)
    $visualContext.DrawDrawing($DrawingGroup)
    $visualContext.Pop()
    $visualContext.Close()

    $renderTarget = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($Size, $Size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $renderTarget.Render($drawingVisual)

    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($renderTarget))
    
    $stream = [System.IO.File]::OpenWrite($FilePath)
    $encoder.Save($stream)
    $stream.Close()
}

$previewDir = "C:\Users\toshi\.gemini\antigravity\brain\b4865e86-f582-453f-a427-2171ab096bea"
Generate-SleepVariants -OutDir $previewDir
