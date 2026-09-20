param(
    [Parameter(Mandatory = $true)][string]$RotarySource,
    [Parameter(Mandatory = $true)][string]$AcceleratorSource
)

Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'Assets\GameReady\Props\Defense\CeilingTwinSentry'
$gameDir = Join-Path $root 'GodotPrototype\assets\props\defense\ceiling_twin_sentry'
$mountPath = Join-Path $outDir 'ceiling_twin_sentry_mount.png'
New-Item -ItemType Directory -Path $outDir, $gameDir -Force | Out-Null

function New-Canvas([int]$width, [int]$height) {
    return [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Draw-Nearest($target, $source, $destRect, $sourceRect) {
    $g = [System.Drawing.Graphics]::FromImage($target)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $g.DrawImage($source, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally { $g.Dispose() }
}

function Save-Asset($bitmap, [string]$name) {
    $path = Join-Path $outDir $name
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Copy-Item -LiteralPath $path -Destination (Join-Path $gameDir $name) -Force
}

$mount = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $mountPath))
$comparison = New-Canvas 1024 224
try {
    $specs = @(
        @{ name = 'rotary'; source = $RotarySource; x = 0; y = 15; panel = 0 },
        @{ name = 'accelerator'; source = $AcceleratorSource; x = 5; y = 19; panel = 1 }
    )
    foreach ($spec in $specs) {
        $source = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $spec.source))
        $head = New-Canvas 512 224
        $preview = New-Canvas 512 224
        try {
            $w = [int][Math]::Round($source.Width * 0.267)
            $h = [int][Math]::Round($source.Height * 0.267)
            Draw-Nearest $head $source ([System.Drawing.Rectangle]::new($spec.x, $spec.y, $w, $h)) ([System.Drawing.Rectangle]::new(0, 0, $source.Width, $source.Height))
            Draw-Nearest $preview $mount ([System.Drawing.Rectangle]::new(0, 0, 448, 224)) ([System.Drawing.Rectangle]::new(0, 0, 448, 224))
            Draw-Nearest $preview $head ([System.Drawing.Rectangle]::new(0, 0, 512, 224)) ([System.Drawing.Rectangle]::new(0, 0, 512, 224))
            Save-Asset $head "ceiling_sentry_$($spec.name)_head.png"
            Save-Asset $preview "ceiling_sentry_$($spec.name)_assembled.png"
            Draw-Nearest $comparison $preview ([System.Drawing.Rectangle]::new($spec.panel * 512, 0, 512, 224)) ([System.Drawing.Rectangle]::new(0, 0, 512, 224))
        }
        finally {
            $source.Dispose()
            $head.Dispose()
            $preview.Dispose()
        }
    }
    Save-Asset $comparison 'ceiling_sentry_firing_variants_comparison.png'
}
finally {
    $mount.Dispose()
    $comparison.Dispose()
}
