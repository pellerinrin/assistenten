Add-Type -AssemblyName System.Drawing

$root = $PSScriptRoot
$paper = [System.Drawing.Color]::FromArgb(255, 0xF7, 0xF3, 0xEA)
$paperDark = [System.Drawing.Color]::FromArgb(255, 0xEF, 0xE8, 0xD8)
$ink = [System.Drawing.Color]::FromArgb(255, 0x37, 0x50, 0x3F)

function New-Icon {
  param(
    [int]$Size,
    [string]$Path,
    [double]$Padding = 0.0   # safe-zone för maskable-ikoner
  )

  $bmp = [System.Drawing.Bitmap]::new($Size, $Size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear([System.Drawing.Color]::Transparent)

  $pad = [int]($Size * $Padding)
  $rectSize = $Size - (2 * $pad)
  $rect = [System.Drawing.Rectangle]::new($pad, $pad, $rectSize, $rectSize)

  # rundad kvadrat i papperston
  $radius = [int]($rectSize * 0.24)
  $bgPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $d = $radius * 2
  $bgPath.AddArc($rect.X, $rect.Y, $d, $d, 180, 90)
  $bgPath.AddArc($rect.Right - $d, $rect.Y, $d, $d, 270, 90)
  $bgPath.AddArc($rect.Right - $d, $rect.Bottom - $d, $d, $d, 0, 90)
  $bgPath.AddArc($rect.X, $rect.Bottom - $d, $d, $d, 90, 90)
  $bgPath.CloseFigure()

  $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, $paper, $paperDark, 90)
  $g.FillPath($brush, $bgPath)

  # serif-A i bläckgrönt, centrerat
  $fontSize = [single]($rectSize * 0.52)
  $font = [System.Drawing.Font]::new('Georgia', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fmt = [System.Drawing.StringFormat]::new()
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $inkBrush = [System.Drawing.SolidBrush]::new($ink)
  $textRect = [System.Drawing.RectangleF]::new($rect.X, $rect.Y + ($rectSize * 0.02), $rectSize, $rectSize)
  $g.DrawString('A', $font, $inkBrush, $textRect, $fmt)

  # liten bronsprick som punkt efter A:et
  $bronze = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 0xA8, 0x83, 0x4B))
  $dotR = $rectSize * 0.045
  $g.FillEllipse($bronze, [single]($rect.X + $rectSize * 0.72), [single]($rect.Y + $rectSize * 0.66), [single]($dotR * 2), [single]($dotR * 2))

  $g.Dispose()
  $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

New-Icon -Size 192 -Path (Join-Path $root 'icon-192.png') -Padding 0.0
New-Icon -Size 512 -Path (Join-Path $root 'icon-512.png') -Padding 0.0
New-Icon -Size 512 -Path (Join-Path $root 'icon-maskable-512.png') -Padding 0.10
New-Icon -Size 180 -Path (Join-Path $root 'apple-touch-icon.png') -Padding 0.0
New-Icon -Size 32  -Path (Join-Path $root 'favicon-32.png') -Padding 0.0

Write-Host "Icons generated in $root"
