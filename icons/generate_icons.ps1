Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing

$pathData = "M19.355 18.538a68.967 68.959 0 0 0 1.858-2.954.81.81 0 0 0-.062-.9c-.516-.685-1.504-2.075-2.042-3.362-.553-1.321-.636-3.375-.64-4.377a1.707 1.707 0 0 0-.358-1.05l-3.198-4.064a3.744 3.744 0 0 1-.076.543c-.106.503-.307 1.004-.536 1.5-.134.29-.29.6-.446.914l-.31.626c-.516 1.068-.997 2.227-1.132 3.59-.124 1.26.046 2.73.815 4.481.128.011.257.025.386.044a6.363 6.363 0 0 1 3.326 1.505c.916.79 1.744 1.922 2.415 3.5zM8.199 22.569c.073.012.146.02.22.02.78.024 2.095.092 3.16.29.87.16 2.593.64 4.01 1.055 1.083.316 2.198-.548 2.355-1.664.114-.814.33-1.735.725-2.58l-.01.005c-.67-1.87-1.522-3.078-2.416-3.849a5.295 5.295 0 0 0-2.778-1.257c-1.54-.216-2.952.19-3.84.45.532 2.218.368 4.829-1.425 7.531zM5.533 9.938c-.023.1-.056.197-.098.29L2.82 16.059a1.602 1.602 0 0 0 .313 1.772l4.116 4.24c2.103-3.101 1.796-6.02.836-8.3-.728-1.73-1.832-3.081-2.55-3.831zM9.32 14.01c.615-.183 1.606-.465 2.745-.534-.683-1.725-.848-3.233-.716-4.577.154-1.552.7-2.847 1.235-3.95.113-.235.223-.454.328-.664.149-.297.288-.577.419-.86.217-.47.379-.885.46-1.27.08-.38.08-.72-.014-1.043-.095-.325-.297-.675-.68-1.06a1.6 1.6 0 0 0-1.475.36l-4.95 4.452a1.602 1.602 0 0 0-.513.952l-.427 2.83c.672.59 2.328 2.316 3.335 4.711.09.21.175.43.253.653z"

$outDir = "C:\ULANZIkinou\icons"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force }

$brushConv = New-Object System.Windows.Media.BrushConverter

function Render-ObsidianIcon {
    param(
        [string]$Filename,
        [int]$Size = 232,
        [string]$Style = "deck", # "deck", "purple_glow", "transparent", "solid"
        [string]$Label = ""
    )

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Width = $Size
    $grid.Height = $Size

    if ($Style -eq "deck") {
        # Ulanzi Deck Dark Theme with subtle blue-purple gradient and border
        $bg = New-Object System.Windows.Shapes.Rectangle
        $bg.Width = $Size - 8
        $bg.Height = $Size - 8
        $bg.RadiusX = 40
        $bg.RadiusY = 40
        
        $brush = New-Object System.Windows.Media.LinearGradientBrush
        $brush.StartPoint = New-Object System.Windows.Point(0, 0)
        $brush.EndPoint = New-Object System.Windows.Point(1, 1)
        $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 22, 27, 42), 0.0)))
        $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 11, 14, 24), 1.0)))
        $bg.Fill = $brush
        $bg.Stroke = $brushConv.ConvertFromString("#38BDF8")
        $bg.StrokeThickness = 4
        
        $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadow.Color = [System.Windows.Media.Color]::FromArgb(255, 56, 189, 248)
        $shadow.BlurRadius = 16
        $shadow.ShadowDepth = 0
        $shadow.Opacity = 0.5
        $bg.Effect = $shadow

        $grid.Children.Add($bg) | Out-Null
    }
    elseif ($Style -eq "purple_glow") {
        # Obsidian Purple Neon Theme
        $bg = New-Object System.Windows.Shapes.Rectangle
        $bg.Width = $Size - 8
        $bg.Height = $Size - 8
        $bg.RadiusX = 40
        $bg.RadiusY = 40
        
        $brush = New-Object System.Windows.Media.LinearGradientBrush
        $brush.StartPoint = New-Object System.Windows.Point(0, 0)
        $brush.EndPoint = New-Object System.Windows.Point(1, 1)
        $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 28, 18, 48), 0.0)))
        $brush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 14, 9, 26), 1.0)))
        $bg.Fill = $brush
        $bg.Stroke = $brushConv.ConvertFromString("#A855F7")
        $bg.StrokeThickness = 4
        
        $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadow.Color = [System.Windows.Media.Color]::FromArgb(255, 168, 85, 247)
        $shadow.BlurRadius = 20
        $shadow.ShadowDepth = 0
        $shadow.Opacity = 0.6
        $bg.Effect = $shadow

        $grid.Children.Add($bg) | Out-Null
    }
    elseif ($Style -eq "solid") {
        $bg = New-Object System.Windows.Shapes.Rectangle
        $bg.Width = $Size - 8
        $bg.Height = $Size - 8
        $bg.RadiusX = 40
        $bg.RadiusY = 40
        $bg.Fill = $brushConv.ConvertFromString("#7C3AED")
        $grid.Children.Add($bg) | Out-Null
    }

    # Inner container for path & text
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    $stack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    # Add Obsidian Logo Path
    $path = New-Object System.Windows.Shapes.Path
    $geom = [System.Windows.Media.Geometry]::Parse($pathData)
    $path.Data = $geom
    $path.Stretch = [System.Windows.Media.Stretch]::Uniform
    
    if ($Style -eq "solid") {
        $path.Fill = [System.Windows.Media.Brushes]::White
        $path.Width = if ($Label -ne "") { $Size * 0.52 } else { $Size * 0.65 }
        $path.Height = if ($Label -ne "") { $Size * 0.52 } else { $Size * 0.65 }
    }
    elseif ($Style -eq "transparent") {
        $logoBrush = New-Object System.Windows.Media.LinearGradientBrush
        $logoBrush.StartPoint = New-Object System.Windows.Point(0, 0)
        $logoBrush.EndPoint = New-Object System.Windows.Point(0.4, 1)
        $logoBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 216, 180, 254), 0.0)))
        $logoBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 168, 85, 247), 0.4)))
        $logoBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 124, 58, 237), 0.8)))
        $logoBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 91, 33, 182), 1.0)))
        $path.Fill = $logoBrush
        $path.Width = $Size * 0.85
        $path.Height = $Size * 0.85

        $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadow.Color = [System.Windows.Media.Color]::FromArgb(255, 168, 85, 247)
        $shadow.BlurRadius = 18
        $shadow.ShadowDepth = 0
        $shadow.Opacity = 0.7
        $path.Effect = $shadow
    }
    else {
        $logoBrush = New-Object System.Windows.Media.LinearGradientBrush
        $logoBrush.StartPoint = New-Object System.Windows.Point(0, 0)
        $logoBrush.EndPoint = New-Object System.Windows.Point(0.4, 1)
        $logoBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 233, 213, 255), 0.0)))
        $logoBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 192, 132, 252), 0.35)))
        $logoBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 147, 51, 234), 0.7)))
        $logoBrush.GradientStops.Add((New-Object System.Windows.Media.GradientStop([System.Windows.Media.Color]::FromArgb(255, 107, 33, 168), 1.0)))
        $path.Fill = $logoBrush
        $path.Width = if ($Label -ne "") { $Size * 0.50 } else { $Size * 0.60 }
        $path.Height = if ($Label -ne "") { $Size * 0.50 } else { $Size * 0.60 }

        $shadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $shadow.Color = [System.Windows.Media.Color]::FromArgb(255, 192, 132, 252)
        $shadow.BlurRadius = 24
        $shadow.ShadowDepth = 0
        $shadow.Opacity = 0.9
        $path.Effect = $shadow
    }

    $stack.Children.Add($path) | Out-Null

    if ($Label -ne "") {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $Label
        $tb.Foreground = [System.Windows.Media.Brushes]::White
        $tb.FontFamily = New-Object System.Windows.Media.FontFamily("Yu Gothic UI, Segoe UI, sans-serif")
        $tb.FontWeight = [System.Windows.FontWeights]::Bold
        $tb.FontSize = 26
        $tb.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
        $tb.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
        
        $tbShadow = New-Object System.Windows.Media.Effects.DropShadowEffect
        $tbShadow.Color = [System.Windows.Media.Color]::FromArgb(255, 0, 0, 0)
        $tbShadow.BlurRadius = 8
        $tbShadow.ShadowDepth = 2
        $tb.Effect = $tbShadow
        
        $stack.Children.Add($tb) | Out-Null
    }

    $grid.Children.Add($stack) | Out-Null

    # Measure and arrange
    $grid.Measure((New-Object System.Windows.Size($Size, $Size)))
    $grid.Arrange((New-Object System.Windows.Rect(0, 0, $Size, $Size)))
    $grid.UpdateLayout()

    # Render to bitmap
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($Size, $Size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($grid)

    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))

    $outPath = Join-Path $outDir $Filename
    $fs = [System.IO.File]::OpenWrite($outPath)
    $encoder.Save($fs)
    $fs.Close()
    Write-Output "Generated: $outPath ($Size x $Size)"
}

Render-ObsidianIcon -Filename "obsidian_deck_neon.png" -Size 232 -Style "deck"
Render-ObsidianIcon -Filename "obsidian_purple_glow.png" -Size 232 -Style "purple_glow"
Render-ObsidianIcon -Filename "obsidian_transparent.png" -Size 232 -Style "transparent"
Render-ObsidianIcon -Filename "obsidian_solid_purple.png" -Size 232 -Style "solid"
Render-ObsidianIcon -Filename "obsidian_deck_label.png" -Size 232 -Style "deck" -Label "Obsidian"
Render-ObsidianIcon -Filename "obsidian_purple_clean_label.png" -Size 232 -Style "purple_glow" -Label "安全起動"
