param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$SourcePath = '',
    [ValidateSet('Workshop','Corridor','Hydroponics','CrewQuarters')]
    [string]$Theme = 'Workshop'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$generatedRoot = Join-Path $WorkspaceRoot 'Assets\Generated\Environments'
$assetPrefix = $Theme.ToLowerInvariant()
$gameRoot = Join-Path $WorkspaceRoot ("Assets\GameReady\Tiles\{0}_Modular" -f $Theme)
$backgroundRoot = Join-Path $gameRoot 'Background'
$frameRoot = Join-Path $gameRoot 'Frame'
$innerFrameRoot = Join-Path $gameRoot 'Frame\InnerCorners'
$validationRoot = Join-Path $WorkspaceRoot 'Assets\GameReady\Validation'

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $sourceFile = switch ($Theme) {
        'Workshop' { 'workshop_empty_background_plate_v1.png' }
        'Corridor' { 'empty_connector_corridor_block_v1.png' }
        'Hydroponics' { 'hydroponics_empty_background_plate_v2.png' }
        'CrewQuarters' { 'crew_quarters_empty_background_plate_v2.png' }
    }
    $SourcePath = Join-Path $generatedRoot $sourceFile
}

@($gameRoot, $backgroundRoot, $frameRoot, $innerFrameRoot, $validationRoot) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}

[int]$Cell = 128

function New-ArgbBitmap {
    param([int]$Width, [int]$Height)
    return [System.Drawing.Bitmap]::new(
        $Width,
        $Height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
}

function Load-BitmapCopy {
    param([string]$Path)
    $source = [System.Drawing.Bitmap]::FromFile($Path)
    try {
        $copy = New-ArgbBitmap -Width $source.Width -Height $source.Height
        $graphics = [System.Drawing.Graphics]::FromImage($copy)
        try {
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.DrawImageUnscaled($source, 0, 0)
        }
        finally { $graphics.Dispose() }
        return $copy
    }
    finally { $source.Dispose() }
}

function Crop-Bitmap {
    param(
        [System.Drawing.Bitmap]$Source,
        [System.Drawing.Rectangle]$Bounds
    )
    $cropped = New-ArgbBitmap -Width $Bounds.Width -Height $Bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($cropped)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $Bounds.Width, $Bounds.Height), $Bounds, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally { $graphics.Dispose() }
    return $cropped
}

function Save-Png {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Clear-Outside {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [scriptblock]$Keep
    )
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if (-not (& $Keep $x $y)) {
                $pixel = $Bitmap.GetPixel($x, $y)
                $Bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, $pixel.R, $pixel.G, $pixel.B))
            }
        }
    }
}

function Export-BackgroundTile {
    param(
        [System.Drawing.Bitmap]$Source,
        [string]$Name,
        [int]$SourceX,
        [int]$SourceY,
        [bool]$FlipX = $false,
        [bool]$FlipY = $false
    )
    $tile = Crop-Bitmap -Source $Source -Bounds ([System.Drawing.Rectangle]::new($SourceX, $SourceY, $Cell, $Cell))
    try {
        if ($FlipX -and $FlipY) { $tile.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
        elseif ($FlipX) { $tile.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX) }
        elseif ($FlipY) { $tile.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipY) }
        $path = Join-Path $backgroundRoot ($Name + '.png')
        Save-Png -Bitmap $tile -Path $path
    }
    finally { $tile.Dispose() }
}

function Export-FrameTile {
    param(
        [System.Drawing.Bitmap]$Source,
        [string]$Name,
        [int]$SourceX,
        [int]$SourceY,
        [ValidateSet('top','bottom','left','right','top_left','top_right','bottom_left','bottom_right')]
        [string]$Kind
    )
    $tile = Crop-Bitmap -Source $Source -Bounds ([System.Drawing.Rectangle]::new($SourceX, $SourceY, $Cell, $Cell))
    try {
        $top = $Kind -in @('top','top_left','top_right')
        $bottom = $Kind -in @('bottom','bottom_left','bottom_right')
        $left = $Kind -in @('left','top_left','bottom_left')
        $right = $Kind -in @('right','top_right','bottom_right')
        Clear-Outside -Bitmap $tile -Keep {
            param($x, $y)
            (($top -and $y -lt 48) -or
             ($bottom -and $y -ge 80) -or
             ($left -and $x -lt 56) -or
             ($right -and $x -ge 72))
        }
        $path = Join-Path $frameRoot ($Name + '.png')
        Save-Png -Bitmap $tile -Path $path
    }
    finally { $tile.Dispose() }
}

function Export-InnerCornerTile {
    param(
        [string]$Name,
        [string]$HorizontalEdge,
        [string]$VerticalEdge
    )
    $tile = New-ArgbBitmap -Width $Cell -Height $Cell
    $graphics = [System.Drawing.Graphics]::FromImage($tile)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        foreach ($edge in @($HorizontalEdge, $VerticalEdge)) {
            $edgeTile = Load-BitmapCopy -Path (Join-Path $frameRoot ($edge + '.png'))
            try { $graphics.DrawImageUnscaled($edgeTile, 0, 0) }
            finally { $edgeTile.Dispose() }
        }
        Save-Png -Bitmap $tile -Path (Join-Path $innerFrameRoot ($Name + '.png'))
    }
    finally { $graphics.Dispose(); $tile.Dispose() }
}

function Build-Sheet {
    param(
        [string]$Root,
        [string]$SheetName,
        [string[]]$Names,
        [int]$Columns
    )
    $rows = [int][Math]::Ceiling($Names.Count / [double]$Columns)
    $sheet = New-ArgbBitmap -Width ($Columns * $Cell) -Height ($rows * $Cell)
    $graphics = [System.Drawing.Graphics]::FromImage($sheet)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear([System.Drawing.Color]::Transparent)
        for ($i = 0; $i -lt $Names.Count; $i++) {
            $tile = Load-BitmapCopy -Path (Join-Path $Root ($Names[$i] + '.png'))
            try { $graphics.DrawImageUnscaled($tile, (($i % $Columns) * $Cell), ([int][Math]::Floor($i / [double]$Columns) * $Cell)) }
            finally { $tile.Dispose() }
        }
        Save-Png -Bitmap $sheet -Path (Join-Path $gameRoot $SheetName)
    }
    finally { $graphics.Dispose(); $sheet.Dispose() }
}

function Draw-Tile {
    param([System.Drawing.Graphics]$Graphics, [string]$Path, [int]$X, [int]$Y)
    $tile = Load-BitmapCopy -Path $Path
    try { $Graphics.DrawImageUnscaled($tile, $X, $Y) }
    finally { $tile.Dispose() }
}

$source = Load-BitmapCopy -Path $SourcePath
try {
    # The clean workshop plate has a quiet lower-wall band at y=430..558.
    # These six samples keep the distressed surface while excluding fixed lamps,
    # vents, props, and the outer frame.
    $backgroundDefinitions = @(
        @{ Name=($assetPrefix + '_bg_fill_a'); X=250; Y=430; FlipX=$false; FlipY=$false },
        @{ Name=($assetPrefix + '_bg_fill_b'); X=390; Y=430; FlipX=$false; FlipY=$false },
        @{ Name=($assetPrefix + '_bg_fill_c'); X=540; Y=430; FlipX=$true;  FlipY=$false },
        @{ Name=($assetPrefix + '_bg_fill_d'); X=820; Y=430; FlipX=$false; FlipY=$false },
        @{ Name=($assetPrefix + '_bg_fill_e'); X=1010; Y=430; FlipX=$true; FlipY=$false },
        @{ Name=($assetPrefix + '_bg_fill_f'); X=1230; Y=430; FlipX=$false; FlipY=$true }
    )
    foreach ($definition in $backgroundDefinitions) {
        Export-BackgroundTile -Source $source -Name $definition.Name -SourceX $definition.X -SourceY $definition.Y -FlipX $definition.FlipX -FlipY $definition.FlipY
    }

    # Source room frame bounds: x=145..1517, top=184..228, side=145..197 / 1469..1517,
    # floor/base=658..710. Each exported frame tile is a transparent overlay.
    $frameDefinitions = @(
        @{ Name=($assetPrefix + '_frame_top_left');     X=145;  Y=184; Kind='top_left' },
        @{ Name=($assetPrefix + '_frame_top');          X=273;  Y=184; Kind='top' },
        @{ Name=($assetPrefix + '_frame_top_right');    X=1389; Y=184; Kind='top_right' },
        @{ Name=($assetPrefix + '_frame_left');         X=145;  Y=312; Kind='left' },
        @{ Name=($assetPrefix + '_frame_right');        X=1389; Y=312; Kind='right' },
        @{ Name=($assetPrefix + '_frame_bottom_left');  X=145;  Y=582; Kind='bottom_left' },
        @{ Name=($assetPrefix + '_frame_bottom');       X=273;  Y=582; Kind='bottom' },
        @{ Name=($assetPrefix + '_frame_bottom_right'); X=1389; Y=582; Kind='bottom_right' }
    )
    foreach ($definition in $frameDefinitions) {
        Export-FrameTile -Source $source -Name $definition.Name -SourceX $definition.X -SourceY $definition.Y -Kind $definition.Kind
    }
}
finally { $source.Dispose() }

$backgroundNames = @(
    ($assetPrefix + '_bg_fill_a'), ($assetPrefix + '_bg_fill_b'), ($assetPrefix + '_bg_fill_c'),
    ($assetPrefix + '_bg_fill_d'), ($assetPrefix + '_bg_fill_e'), ($assetPrefix + '_bg_fill_f')
)
$frameNames = @(
    ($assetPrefix + '_frame_top_left'), ($assetPrefix + '_frame_top'), ($assetPrefix + '_frame_top_right'),
    ($assetPrefix + '_frame_left'), ($assetPrefix + '_frame_right'), ($assetPrefix + '_frame_bottom_left'),
    ($assetPrefix + '_frame_bottom'), ($assetPrefix + '_frame_bottom_right')
)
$innerCornerNames = @(
    ($assetPrefix + '_frame_inner_top_left'), ($assetPrefix + '_frame_inner_top_right'),
    ($assetPrefix + '_frame_inner_bottom_left'), ($assetPrefix + '_frame_inner_bottom_right')
)
$innerCornerRules = @(
    [ordered]@{ tile=$innerCornerNames[0]; openQuadrant='top_left'; visibleBands=@('bottom','right'); pattern='X X X / X * . / X . .' },
    [ordered]@{ tile=$innerCornerNames[1]; openQuadrant='top_right'; visibleBands=@('bottom','left'); pattern='X X X / . * X / . . X' },
    [ordered]@{ tile=$innerCornerNames[2]; openQuadrant='bottom_left'; visibleBands=@('top','right'); pattern='X . . / X * . / X X X' },
    [ordered]@{ tile=$innerCornerNames[3]; openQuadrant='bottom_right'; visibleBands=@('top','left'); pattern='. . X / . * X / X X X' }
)
Build-Sheet -Root $backgroundRoot -SheetName ($assetPrefix + '_modular_background_sheet_3x2.png') -Names $backgroundNames -Columns 3
Build-Sheet -Root $frameRoot -SheetName ($assetPrefix + '_modular_frame_sheet_4x2.png') -Names $frameNames -Columns 4

# Concave/inside corners for RuleTile notches and rooms with recessed wall lines.
# The name describes the missing/open quadrant; the visible bands occupy the
# opposite two edges (e.g. inner_top_left = bottom + right).
Export-InnerCornerTile -Name $innerCornerNames[0] -HorizontalEdge $frameNames[6] -VerticalEdge $frameNames[4]
Export-InnerCornerTile -Name $innerCornerNames[1] -HorizontalEdge $frameNames[6] -VerticalEdge $frameNames[3]
Export-InnerCornerTile -Name $innerCornerNames[2] -HorizontalEdge $frameNames[1] -VerticalEdge $frameNames[4]
Export-InnerCornerTile -Name $innerCornerNames[3] -HorizontalEdge $frameNames[1] -VerticalEdge $frameNames[3]
Build-Sheet -Root $innerFrameRoot -SheetName ($assetPrefix + '_modular_frame_inner_corners_sheet_4x1.png') -Names $innerCornerNames -Columns 4

# Validation preview: 12x6 background cells surrounded by the separate frame layer.
$previewWidth = 14 * $Cell
$previewHeight = 8 * $Cell
$previewPath = Join-Path $validationRoot ($assetPrefix + '_modular_12x6_preview.png')
$preview = New-ArgbBitmap -Width $previewWidth -Height $previewHeight
$graphics = [System.Drawing.Graphics]::FromImage($preview)
try {
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 7, 9, 20))
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None

    # Fill the complete footprint first so transparent portions of the frame have
    # a continuous dark wall behind them.
    for ($y = 0; $y -lt $previewHeight; $y += $Cell) {
        for ($x = 0; $x -lt $previewWidth; $x += $Cell) {
            $name = $backgroundNames[((($x / $Cell) + ($y / $Cell) * 2) % $backgroundNames.Count)]
            Draw-Tile -Graphics $graphics -Path (Join-Path $backgroundRoot ($name + '.png')) -X $x -Y $y
        }
    }

    Draw-Tile -Graphics $graphics -Path (Join-Path $frameRoot ($frameNames[0] + '.png')) -X 0 -Y 0
    Draw-Tile -Graphics $graphics -Path (Join-Path $frameRoot ($frameNames[2] + '.png')) -X (13 * $Cell) -Y 0
    Draw-Tile -Graphics $graphics -Path (Join-Path $frameRoot ($frameNames[5] + '.png')) -X 0 -Y (7 * $Cell)
    Draw-Tile -Graphics $graphics -Path (Join-Path $frameRoot ($frameNames[7] + '.png')) -X (13 * $Cell) -Y (7 * $Cell)
    for ($x = $Cell; $x -lt (13 * $Cell); $x += $Cell) {
        Draw-Tile -Graphics $graphics -Path (Join-Path $frameRoot ($frameNames[1] + '.png')) -X $x -Y 0
        Draw-Tile -Graphics $graphics -Path (Join-Path $frameRoot ($frameNames[6] + '.png')) -X $x -Y (7 * $Cell)
    }
    for ($y = $Cell; $y -lt (7 * $Cell); $y += $Cell) {
        Draw-Tile -Graphics $graphics -Path (Join-Path $frameRoot ($frameNames[3] + '.png')) -X 0 -Y $y
        Draw-Tile -Graphics $graphics -Path (Join-Path $frameRoot ($frameNames[4] + '.png')) -X (13 * $Cell) -Y $y
    }
    Save-Png -Bitmap $preview -Path $previewPath
}
finally { $graphics.Dispose(); $preview.Dispose() }

$innerPreviewPath = Join-Path $validationRoot ($assetPrefix + '_modular_inner_corners_preview.png')
$innerPreview = New-ArgbBitmap -Width (4 * $Cell) -Height $Cell
$innerGraphics = [System.Drawing.Graphics]::FromImage($innerPreview)
try {
    $innerGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $innerGraphics.Clear([System.Drawing.Color]::FromArgb(255, 7, 9, 20))
    $innerGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $innerGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $innerGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $innerGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    for ($i = 0; $i -lt $innerCornerNames.Count; $i++) {
        $x = $i * $Cell
        Draw-Tile -Graphics $innerGraphics -Path (Join-Path $backgroundRoot ($backgroundNames[0] + '.png')) -X $x -Y 0
        Draw-Tile -Graphics $innerGraphics -Path (Join-Path $innerFrameRoot ($innerCornerNames[$i] + '.png')) -X $x -Y 0
    }
    Save-Png -Bitmap $innerPreview -Path $innerPreviewPath
}
finally { $innerGraphics.Dispose(); $innerPreview.Dispose() }

$manifest = [ordered]@{
    formatVersion = 2
    theme = $Theme
    source = [ordered]@{ path = ('Assets/Generated/Environments/' + (Split-Path -Leaf $SourcePath)); purpose = 'clean canonical plate; fixed props and fixtures are intentionally not part of repeat tiles' }
    coordinateSystem = 'top-left, +x right, +y down'
    cellSizePx = 128
    backgroundLayer = [ordered]@{
        folder = 'Background'
        tileCount = 6
        repeatAxes = @('x','y')
        sheet = ($assetPrefix + '_modular_background_sheet_3x2.png')
        tiles = $backgroundNames
    }
    frameLayer = [ordered]@{
        folder = 'Frame'
        overlay = $true
        sheet = ($assetPrefix + '_modular_frame_sheet_4x2.png')
        tiles = $frameNames
        assembly = 'one-cell perimeter: corners once, top/bottom edges repeat on x, left/right edges repeat on y'
        innerCorners = [ordered]@{
            folder = 'Frame/InnerCorners'
            sheet = ($assetPrefix + '_modular_frame_inner_corners_sheet_4x1.png')
            tiles = $innerCornerNames
            purpose = 'concave corners for recessed/notched wall lines and RuleTile inside-corner states'
            rules = $innerCornerRules
        }
    }
    preview = [ordered]@{ file = ('Assets/GameReady/Validation/' + $assetPrefix + '_modular_12x6_preview.png'); innerCornersFile = ('Assets/GameReady/Validation/' + $assetPrefix + '_modular_inner_corners_preview.png'); interiorCells = [ordered]@{ width = 12; height = 6 }; footprintCells = [ordered]@{ width = 14; height = 8 } }
    import = [ordered]@{ filter = 'nearest/point'; compression = 'lossless or none'; mipmaps = $false; alpha = 'frame layer preserves transparency'; pivot = 'top-left for Godot Sprite2D / bottom-left equivalent when using the legacy guide' }
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $gameRoot ($assetPrefix + '_modular_tiles_v2.json')) -Encoding UTF8
$ruleTileSpec = [ordered]@{
    formatVersion = 1
    tile = ($Theme + '_Modular_Frame_RuleTile')
    grid = 'rectangular'
    requiredUnityPackages = @('com.unity.2d.tilemap', 'com.unity.2d.tilemap.extras')
    analysis = [ordered]@{ method = '3x3 alpha/connection grid'; center = '*'; thisNeighbor = '.'; dontCareNeighbor = 'X'; note = 'Patterns are top-to-bottom and map the visible bands to connected frame neighbors.' }
    insideCornerRules = $innerCornerRules
}
$ruleTileSpec | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $gameRoot ($assetPrefix + '_modular_ruletile_rules_v2.json')) -Encoding UTF8

Write-Output "$Theme modular tiles: $gameRoot"
Write-Output "Validation preview: $previewPath"
