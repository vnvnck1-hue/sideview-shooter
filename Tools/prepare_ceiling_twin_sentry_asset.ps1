param([Parameter(Mandatory = $true)][string]$Source)

Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'Assets\GameReady\Props\Defense\CeilingTwinSentry'
$gameDir = Join-Path $root 'GodotPrototype\assets\props\defense\ceiling_twin_sentry'
New-Item -ItemType Directory -Path $outDir, $gameDir -Force | Out-Null

function New-Canvas {
    return [System.Drawing.Bitmap]::new(448, 224, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Draw-Sprite($target, $source, $clip) {
    $g = [System.Drawing.Graphics]::FromImage($target)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        if ($null -ne $clip) { $g.SetClip($clip) }
        $g.DrawImage($source, [System.Drawing.Rectangle]::new(4, 4, 440, 210), [System.Drawing.Rectangle]::new(55, 80, 1610, 770), [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally { $g.Dispose() }
}

function Save-Sprite($sprite, [string]$name) {
    $out = Join-Path $outDir $name
    $sprite.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    Copy-Item -LiteralPath $out -Destination (Join-Path $gameDir $name) -Force
}

$sourceImage = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $Source))
$full = $null
$mount = $null
$head = $null
try {
    $full = New-Canvas
    $mount = New-Canvas
    $head = New-Canvas
    Draw-Sprite $full $sourceImage $null
    # Both layers share one 448 × 224 canvas, so their zero positions register exactly.
    # The 2-pixel overlap preserves the hinge/receiver connection while the head rotates.
    Draw-Sprite $mount $sourceImage ([System.Drawing.Rectangle]::new(0, 0, 448, 81))
    Draw-Sprite $head $sourceImage ([System.Drawing.Rectangle]::new(0, 79, 448, 145))
    Save-Sprite $full 'ceiling_twin_sentry_assembled.png'
    Save-Sprite $mount 'ceiling_twin_sentry_mount.png'
    Save-Sprite $head 'ceiling_twin_sentry_head.png'
}
finally {
    $sourceImage.Dispose()
    if ($null -ne $full) { $full.Dispose() }
    if ($null -ne $mount) { $mount.Dispose() }
    if ($null -ne $head) { $head.Dispose() }
}
