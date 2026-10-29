# ChatFlux: generates the Android launcher icons from one source PNG (transparent background).
# Usage: powershell -File tool/chatflux/make-android-icons.ps1 -Source tool/chatflux/chatflux-logo.png
param(
	[Parameter(Mandatory = $true)][string]$Source,
	[string]$Background = '#FFFFFF'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$res = Join-Path $root 'android\app\src\main\res'
$src = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
$bg = [System.Drawing.ColorTranslator]::FromHtml($Background)

# shape: 'none' (transparent), 'square' (rounded square), 'circle'
function New-Icon([int]$size, [double]$logoFraction, [string]$shape) {
	$bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.Clear([System.Drawing.Color]::Transparent)
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$brush = New-Object System.Drawing.SolidBrush $bg
	if ($shape -eq 'circle') {
		$g.FillEllipse($brush, 0, 0, $size - 1, $size - 1)
	} elseif ($shape -eq 'square') {
		$r = [int]($size * 0.18)
		$path = New-Object System.Drawing.Drawing2D.GraphicsPath
		$path.AddArc(0, 0, 2 * $r, 2 * $r, 180, 90)
		$path.AddArc($size - 1 - 2 * $r, 0, 2 * $r, 2 * $r, 270, 90)
		$path.AddArc($size - 1 - 2 * $r, $size - 1 - 2 * $r, 2 * $r, 2 * $r, 0, 90)
		$path.AddArc(0, $size - 1 - 2 * $r, 2 * $r, 2 * $r, 90, 90)
		$path.CloseFigure()
		$g.FillPath($brush, $path)
	}
	$box = $size * $logoFraction
	$scale = [Math]::Min($box / $src.Width, $box / $src.Height)
	$w = $src.Width * $scale; $h = $src.Height * $scale
	$g.DrawImage($src, [single](($size - $w) / 2), [single](($size - $h) / 2), [single]$w, [single]$h)
	$g.Dispose()
	return $bmp
}

function Save-Png($bmp, [string]$path) {
	New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
	$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
}

# Adaptive icon foreground: 108dp canvas, the safe zone is the inner 66dp circle.
Save-Png (New-Icon 432 0.56 'none') (Join-Path $res 'drawable-nodpi\chatflux_launcher_foreground.png')

# Legacy launcher icons (Android 7 and older), replacing the upstream .webp ones.
$densities = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($d in $densities.Keys) {
	$dir = Join-Path $res "mipmap-$d"
	Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $dir 'ic_launcher.webp'), (Join-Path $dir 'ic_launcher_round.webp')
	$s = $densities[$d]
	Save-Png (New-Icon $s 0.78 'square') (Join-Path $dir 'ic_launcher.png')
	Save-Png (New-Icon $s 0.70 'circle') (Join-Path $dir 'ic_launcher_round.png')
}

# In-app artwork (used e.g. as audio attachment cover).
Save-Png (New-Icon 1024 0.80 'square') (Join-Path $root 'assets\images\app_icon.png')

$src.Dispose()
Write-Host 'Android icons written.'
