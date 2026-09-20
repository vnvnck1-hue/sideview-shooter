param(
    [Parameter(Mandatory = $true)][string]$HeadSource,
    [Parameter(Mandatory = $true)][string]$HatchSource
)

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'Assets\GameReady\Props\Defense\WallRotary'
$gameDir = Join-Path $root 'GodotPrototype\assets\props\defense\wall_rotary'
New-Item -ItemType Directory -Path $outDir, $gameDir -Force | Out-Null

function New-Canvas([int]$width, [int]$height) {
    $bmp = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bmp.SetResolution(96, 96)
    return $bmp
}

function Draw-Nearest($target, $source, $destRect, $sourceRect) {
    $graphics = [System.Drawing.Graphics]::FromImage($target)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.DrawImage($source, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally { $graphics.Dispose() }
}

function Save-Asset($bitmap, [string]$name) {
    $path = Join-Path $outDir $name
    $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    Copy-Item -LiteralPath $path -Destination (Join-Path $gameDir $name) -Force
}

$head = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $HeadSource))
$hatch = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $HatchSource))
try {
    $headSprite = New-Canvas 320 176
    # Raw image's unused transparent margins are removed; nearest sampling keeps the game pixel clusters crisp.
    Draw-Nearest $headSprite $head ([System.Drawing.Rectangle]::new(5, 5, 305, 149)) ([System.Drawing.Rectangle]::new(110, 130, 1450, 708))
    Save-Asset $headSprite 'wall_rotary_head_game.png'

    $stageSpecs = @(
        @{ name = 'wall_rotary_hatch_closed.png'; x = 60; w = 300 },
        @{ name = 'wall_rotary_hatch_opening.png'; x = 450; w = 530 },
        @{ name = 'wall_rotary_hatch_open.png'; x = 1040; w = 700 }
    )
    $frames = @()
    foreach ($spec in $stageSpecs) {
        $frame = New-Canvas 320 384
        $w = [int][Math]::Round($spec.w * 0.42)
        Draw-Nearest $frame $hatch ([System.Drawing.Rectangle]::new(20, 10, $w, 373)) ([System.Drawing.Rectangle]::new($spec.x, 0, $spec.w, 887))
        Save-Asset $frame $spec.name
        $frames += $frame
    }

    $preview = New-Canvas 440 384
    Draw-Nearest $preview $frames[2] ([System.Drawing.Rectangle]::new(0, 0, 320, 384)) ([System.Drawing.Rectangle]::new(0, 0, 320, 384))
    # Pivot (147, 140) on the head lands at (155, 250) on the open lower guide.
    Draw-Nearest $preview $headSprite ([System.Drawing.Rectangle]::new(8, 110, 320, 176)) ([System.Drawing.Rectangle]::new(0, 0, 320, 176))
    Save-Asset $preview 'wall_rotary_assembled_preview.png'
}
finally {
    $head.Dispose()
    $hatch.Dispose()
    if ($null -ne $headSprite) { $headSprite.Dispose() }
    if ($null -ne $preview) { $preview.Dispose() }
    if ($null -ne $frames) { foreach ($frame in $frames) { $frame.Dispose() } }
}
