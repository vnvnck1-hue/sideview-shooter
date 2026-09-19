param(
    [Parameter(Mandatory=$true)][string]$BaseSource,
    [Parameter(Mandatory=$true)][string]$FiringSource,
    [Parameter(Mandatory=$true)][string]$AmmoSource,
    [string]$OutputRoot = "Assets\GameReady\Native4\Props\Defense",
    [string]$GameRoot = "GodotPrototype\assets\props\defense",
    [string]$SourceRoot = "Assets\Generated\SentryTurret\Source",
    [string]$Version = "v1",
    [string]$MountSource = "",
    [string]$OpticSource = "",
    [string]$FrontSource = "",
    [string]$BodySource = "",
    [string]$BodyCoreSource = ""
)

Add-Type -AssemblyName System.Drawing

function Ensure-Dir([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Get-AlphaBounds([System.Drawing.Bitmap]$Bitmap) {
    $left = $Bitmap.Width; $top = $Bitmap.Height; $right = -1; $bottom = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -ge 16) {
                if ($x -lt $left) { $left = $x }
                if ($y -lt $top) { $top = $y }
                if ($x -gt $right) { $right = $x }
                if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }
    if ($right -lt 0) { throw "Source image has no visible pixels: $($Bitmap)" }
    return @{ Left=$left; Top=$top; Width=($right-$left+1); Height=($bottom-$top+1) }
}

function Set-BinaryAlpha([System.Drawing.Bitmap]$Bitmap) {
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $p = $Bitmap.GetPixel($x, $y)
            if ($p.A -lt 128) {
                $Bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $p.R, $p.G, $p.B))
            } else {
                $Bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $p.R, $p.G, $p.B))
            }
        }
    }
}

function Make-Native([string]$Source, [string]$Target, [int]$Width, [int]$Height) {
    $src = [System.Drawing.Bitmap]::new($Source)
    $bounds = Get-AlphaBounds $src
    $srcRect = [System.Drawing.Rectangle]::new([int]$bounds.Left, [int]$bounds.Top, [int]$bounds.Width, [int]$bounds.Height)
    $crop = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gc = [System.Drawing.Graphics]::FromImage($crop)
    $gc.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $gc.DrawImage($src, [System.Drawing.Rectangle]::new(0, 0, $bounds.Width, $bounds.Height), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $gc.Dispose(); $src.Dispose()

    $dst = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.Clear([System.Drawing.Color]::Transparent)
    $scale = [Math]::Min($Width / [double]$crop.Width, $Height / [double]$crop.Height)
    $dw = [Math]::Max(1, [int][Math]::Round($crop.Width * $scale))
    $dh = [Math]::Max(1, [int][Math]::Round($crop.Height * $scale))
    $dx = [int](($Width - $dw) / 2); $dy = [int](($Height - $dh) / 2)
    $g.DrawImage($crop, $dx, $dy, $dw, $dh)
    $g.Dispose(); $crop.Dispose()
    Set-BinaryAlpha $dst
    $dst.Save($Target, [System.Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
}

function Make-Upscaled([string]$Source, [string]$Target) {
    $src = [System.Drawing.Bitmap]::new($Source)
    $dst = [System.Drawing.Bitmap]::new($src.Width*4, $src.Height*4, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.DrawImage($src, 0, 0, $dst.Width, $dst.Height)
    $g.Dispose(); $src.Dispose()
    Set-BinaryAlpha $dst
    $dst.Save($Target, [System.Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
}

Ensure-Dir $SourceRoot
Ensure-Dir $OutputRoot
Ensure-Dir $GameRoot

$items = @(
    @{ Source=$BaseSource; Name=("sentry_turret_base_" + $Version); Width=112; Height=112 },
    @{ Source=$FiringSource; Name=("sentry_turret_firing_" + $Version); Width=120; Height=56 },
    @{ Source=$AmmoSource; Name=("sentry_turret_ammo_feed_" + $Version); Width=96; Height=64 }
)

foreach ($item in $items) {
    $sourceCopy = Join-Path $SourceRoot ($item.Name + '.png')
    if ([System.IO.Path]::GetFullPath($item.Source) -ne [System.IO.Path]::GetFullPath($sourceCopy)) {
        Copy-Item -LiteralPath $item.Source -Destination $sourceCopy -Force
    }
    $native = Join-Path $OutputRoot ($item.Name + '.png')
    Make-Native $item.Source $native $item.Width $item.Height
    Make-Upscaled $native (Join-Path $GameRoot ($item.Name + '.png'))
}

if ($MountSource -ne "") {
    $mountName = "sentry_turret_mount_" + $Version
    Copy-Item -LiteralPath $MountSource -Destination (Join-Path $SourceRoot ($mountName + '.png')) -Force
    $mountNative = Join-Path $OutputRoot ($mountName + '.png')
    Make-Native $MountSource $mountNative 128 48
    Make-Upscaled $mountNative (Join-Path $GameRoot ($mountName + '.png'))
}

$splitItems = @(
    @{ Source=$OpticSource; Name=("sentry_turret_optic_" + $Version); Width=96; Height=64 },
    @{ Source=$FrontSource; Name=("sentry_turret_front_" + $Version); Width=128; Height=64 },
    @{ Source=$BodySource; Name=("sentry_turret_body_" + $Version); Width=128; Height=96 },
    @{ Source=$BodyCoreSource; Name=("sentry_turret_body_core_" + $Version); Width=128; Height=64 }
)

foreach ($item in $splitItems) {
    if ($item.Source -eq "") { continue }
    $sourceCopy = Join-Path $SourceRoot ($item.Name + '.png')
    if ([System.IO.Path]::GetFullPath($item.Source) -ne [System.IO.Path]::GetFullPath($sourceCopy)) {
        Copy-Item -LiteralPath $item.Source -Destination $sourceCopy -Force
    }
    $native = Join-Path $OutputRoot ($item.Name + '.png')
    Make-Native $item.Source $native $item.Width $item.Height
    Make-Upscaled $native (Join-Path $GameRoot ($item.Name + '.png'))
}
