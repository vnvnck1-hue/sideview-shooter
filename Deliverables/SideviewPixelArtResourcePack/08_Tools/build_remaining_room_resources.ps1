param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$generatedRoot = Join-Path $WorkspaceRoot 'Assets\Generated'
$gameRoot = Join-Path $WorkspaceRoot 'Assets\GameReady'
$validationRoot = Join-Path $gameRoot 'Validation'
$sourcePropSheetRoot = Join-Path $generatedRoot 'RoomPropSheets'

New-Item -ItemType Directory -Force -Path $validationRoot | Out-Null

function New-ArgbBitmap {
    param([int]$Width, [int]$Height)
    return [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
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
    param([System.Drawing.Bitmap]$Source, [System.Drawing.Rectangle]$Bounds)
    $cropped = New-ArgbBitmap -Width $Bounds.Width -Height $Bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($cropped)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.DrawImage(
            $Source,
            [System.Drawing.Rectangle]::new(0, 0, $Bounds.Width, $Bounds.Height),
            $Bounds,
            [System.Drawing.GraphicsUnit]::Pixel
        )
    }
    finally { $graphics.Dispose() }
    return $cropped
}

function Get-AlphaBounds {
    param([System.Drawing.Bitmap]$Bitmap)
    $rect = [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $stride = [Math]::Abs($data.Stride)
        $bytes = [byte[]]::new($stride * $Bitmap.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        $minX = $Bitmap.Width
        $minY = $Bitmap.Height
        $maxX = -1
        $maxY = -1
        for ($y = 0; $y -lt $Bitmap.Height; $y++) {
            $row = $y * $stride
            for ($x = 0; $x -lt $Bitmap.Width; $x++) {
                if ($bytes[$row + ($x * 4) + 3] -gt 0) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }
    }
    finally { $Bitmap.UnlockBits($data) }
    if ($maxX -lt 0) { throw 'Sprite contains no visible pixels.' }
    return [System.Drawing.Rectangle]::new($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
}

function Resize-Nearest {
    param([System.Drawing.Bitmap]$Source, [int]$TargetHeight)
    $targetWidth = [Math]::Max(1, [int][Math]::Round($Source.Width * ($TargetHeight / [double]$Source.Height)))
    $resized = New-ArgbBitmap -Width $targetWidth -Height $TargetHeight
    $graphics = [System.Drawing.Graphics]::FromImage($resized)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $targetWidth, $TargetHeight), 0, 0, $Source.Width, $Source.Height, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally { $graphics.Dispose() }
    return $resized
}

function Convert-CheckerCellToAlpha {
    param(
        [System.Drawing.Bitmap]$SourceCell,
        [bool]$ClearAllLightNeutral = $false
    )

    $width = $SourceCell.Width
    $height = $SourceCell.Height
    $pixelCount = $width * $height
    $packedColors = [int[]]::new($pixelCount)
    $candidate = [bool[]]::new($pixelCount)
    $clear = [bool[]]::new($pixelCount)

    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $index = ($y * $width) + $x
            $color = $SourceCell.GetPixel($x, $y)
            $packedColors[$index] = $color.ToArgb()
            $minimum = [Math]::Min($color.R, [Math]::Min($color.G, $color.B))
            $maximum = [Math]::Max($color.R, [Math]::Max($color.G, $color.B))
            $candidate[$index] = ($minimum -ge 180) -and (($maximum - $minimum) -le 12)
        }
    }

    $queue = [System.Collections.Generic.Queue[int]]::new()
    for ($x = 0; $x -lt $width; $x++) {
        foreach ($y in @(0, ($height - 1))) {
            $index = ($y * $width) + $x
            if ($candidate[$index] -and -not $clear[$index]) { $clear[$index] = $true; $queue.Enqueue($index) }
        }
    }
    for ($y = 0; $y -lt $height; $y++) {
        foreach ($x in @(0, ($width - 1))) {
            $index = ($y * $width) + $x
            if ($candidate[$index] -and -not $clear[$index]) { $clear[$index] = $true; $queue.Enqueue($index) }
        }
    }

    while ($queue.Count -gt 0) {
        $index = $queue.Dequeue()
        $x = $index % $width
        $y = [int][Math]::Floor($index / $width)
        if ($x -gt 0) {
            $next = $index - 1
            if ($candidate[$next] -and -not $clear[$next]) { $clear[$next] = $true; $queue.Enqueue($next) }
        }
        if ($x -lt ($width - 1)) {
            $next = $index + 1
            if ($candidate[$next] -and -not $clear[$next]) { $clear[$next] = $true; $queue.Enqueue($next) }
        }
        if ($y -gt 0) {
            $next = $index - $width
            if ($candidate[$next] -and -not $clear[$next]) { $clear[$next] = $true; $queue.Enqueue($next) }
        }
        if ($y -lt ($height - 1)) {
            $next = $index + $width
            if ($candidate[$next] -and -not $clear[$next]) { $clear[$next] = $true; $queue.Enqueue($next) }
        }
    }

    if ($ClearAllLightNeutral) {
        for ($index = 0; $index -lt $pixelCount; $index++) {
            if ($candidate[$index]) { $clear[$index] = $true }
        }
    }

    $result = New-ArgbBitmap -Width $width -Height $height
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $index = ($y * $width) + $x
            if ($clear[$index]) {
                $result.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
            }
            else {
                $sourceColor = [System.Drawing.Color]::FromArgb($packedColors[$index])
                $result.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $sourceColor.R, $sourceColor.G, $sourceColor.B))
            }
        }
    }
    return $result
}

function Remove-DetachedArtifacts {
    param([System.Drawing.Bitmap]$Bitmap)

    $width = $Bitmap.Width
    $height = $Bitmap.Height
    $visited = [bool[]]::new($width * $height)

    for ($startY = 0; $startY -lt $height; $startY++) {
        for ($startX = 0; $startX -lt $width; $startX++) {
            $startIndex = ($startY * $width) + $startX
            if ($visited[$startIndex] -or $Bitmap.GetPixel($startX, $startY).A -eq 0) { continue }

            $queue = [System.Collections.Generic.Queue[int]]::new()
            $component = [System.Collections.Generic.List[int]]::new()
            $visited[$startIndex] = $true
            $queue.Enqueue($startIndex)
            $minX = $startX
            $maxX = $startX
            $minY = $startY
            $maxY = $startY

            while ($queue.Count -gt 0) {
                $index = $queue.Dequeue()
                $component.Add($index)
                $x = $index % $width
                $y = [int][Math]::Floor($index / $width)
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }

                foreach ($next in @(($index - 1), ($index + 1), ($index - $width), ($index + $width))) {
                    if ($next -lt 0 -or $next -ge ($width * $height) -or $visited[$next]) { continue }
                    $nextX = $next % $width
                    $nextY = [int][Math]::Floor($next / $width)
                    if ([Math]::Abs($nextX - $x) + [Math]::Abs($nextY - $y) -ne 1) { continue }
                    if ($Bitmap.GetPixel($nextX, $nextY).A -gt 0) {
                        $visited[$next] = $true
                        $queue.Enqueue($next)
                    }
                }
            }

            $componentWidth = $maxX - $minX + 1
            $componentHeight = $maxY - $minY + 1
            $isTiny = $component.Count -lt 50
            $isThinBar = (($componentHeight -le 16) -and ($componentWidth -ge 16)) -or ($componentWidth -ge ($componentHeight * 4))
            if ($isTiny -or $isThinBar) {
                foreach ($index in $component) {
                    $x = $index % $width
                    $y = [int][Math]::Floor($index / $width)
                    $Bitmap.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
                }
            }
        }
    }
}

function Export-PropSheet {
    param(
        [string]$SourcePath,
        [string]$AlphaSheetPath,
        [string]$OutputRoot,
        [array]$Definitions
    )

    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
    $source = Load-BitmapCopy -Path $SourcePath
    $alphaSheet = New-ArgbBitmap -Width $source.Width -Height $source.Height
    $sheetGraphics = [System.Drawing.Graphics]::FromImage($alphaSheet)
    $sheetGraphics.Clear([System.Drawing.Color]::Transparent)
    $exports = @()
    try {
        $cellWidth = [int]($source.Width / 3)
        $cellHeight = [int]($source.Height / 2)
        foreach ($definition in $Definitions) {
            $sourceCell = Crop-Bitmap -Source $source -Bounds ([System.Drawing.Rectangle]::new(($definition.Column * $cellWidth), ($definition.Row * $cellHeight), $cellWidth, $cellHeight))
            try {
                $clearAllLightNeutral = ($definition.PSObject.Properties.Name -contains 'ClearAllLightNeutral') -and $definition.ClearAllLightNeutral
                $alphaCell = Convert-CheckerCellToAlpha -SourceCell $sourceCell -ClearAllLightNeutral $clearAllLightNeutral
                try {
                    Remove-DetachedArtifacts -Bitmap $alphaCell
                    $sheetGraphics.DrawImageUnscaled($alphaCell, ($definition.Column * $cellWidth), ($definition.Row * $cellHeight))
                    $bounds = Get-AlphaBounds -Bitmap $alphaCell
                    $cropped = Crop-Bitmap -Source $alphaCell -Bounds $bounds
                    try {
                        $resized = Resize-Nearest -Source $cropped -TargetHeight $definition.TargetHeight
                        try {
                            $outputPath = Join-Path $OutputRoot ($definition.Name + '.png')
                            $resized.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
                            $exports += [pscustomobject]@{ Name=$definition.Name; Path=$outputPath; Width=$resized.Width; Height=$resized.Height }
                        }
                        finally { $resized.Dispose() }
                    }
                    finally { $cropped.Dispose() }
                }
                finally { $alphaCell.Dispose() }
            }
            finally { $sourceCell.Dispose() }
        }
        $alphaSheet.Save($AlphaSheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $sheetGraphics.Dispose()
        $alphaSheet.Dispose()
        $source.Dispose()
    }
    return $exports
}

function Export-ThemeTiles {
    param([string]$Theme, [string]$SourcePath)
    $tileRoot = Join-Path $gameRoot ("Tiles\$Theme")
    New-Item -ItemType Directory -Force -Path $tileRoot | Out-Null
    $source = Load-BitmapCopy -Path $SourcePath
    $definitions = @(
        [pscustomobject]@{ Name='cap_left'; X=144; Width=160 },
        [pscustomobject]@{ Name='wall_a'; X=304; Width=256 },
        [pscustomobject]@{ Name='wall_b'; X=560; Width=256 },
        [pscustomobject]@{ Name='wall_repeat'; X=704; Width=256 },
        [pscustomobject]@{ Name='wall_c'; X=816; Width=256 },
        # The 960-1216 span avoids slicing the unique right-side electrical box or other wall fixtures.
        [pscustomobject]@{ Name='wall_d'; X=960; Width=256 },
        [pscustomobject]@{ Name='cap_right'; X=1360; Width=160 }
    )
    try {
        foreach ($definition in $definitions) {
            $tile = Crop-Bitmap -Source $source -Bounds ([System.Drawing.Rectangle]::new($definition.X, 184, $definition.Width, 560))
            try { $tile.Save((Join-Path $tileRoot ("{0}_{1}.png" -f $Theme.ToLowerInvariant(), $definition.Name)), [System.Drawing.Imaging.ImageFormat]::Png) }
            finally { $tile.Dispose() }
        }
    }
    finally { $source.Dispose() }

    foreach ($baseName in @('wall_c','wall_d')) {
        $sourceTilePath = Join-Path $tileRoot ("{0}_{1}.png" -f $Theme.ToLowerInvariant(), $baseName)
        $tile = Load-BitmapCopy -Path $sourceTilePath
        try {
            $tile.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX)
            $tile.Save((Join-Path $tileRoot ("{0}_{1}_mirror.png" -f $Theme.ToLowerInvariant(), $baseName)), [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally { $tile.Dispose() }
    }
    return $tileRoot
}

function New-ThemeBackground {
    param([string]$Theme, [string]$TileRoot)
    $canvas = New-ArgbBitmap -Width 2304 -Height 941
    $graphics = [System.Drawing.Graphics]::FromImage($canvas)
    $sequence = @('cap_left','wall_a','wall_b','wall_c','wall_d','wall_c_mirror','wall_d_mirror','wall_repeat','cap_right')
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 7, 9, 20))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $cursorX = 96
        foreach ($part in $sequence) {
            $path = Join-Path $TileRoot ("{0}_{1}.png" -f $Theme.ToLowerInvariant(), $part)
            $tile = Load-BitmapCopy -Path $path
            try { $graphics.DrawImageUnscaled($tile, $cursorX, 184); $cursorX += $tile.Width }
            finally { $tile.Dispose() }
        }
    }
    finally { $graphics.Dispose() }
    return [pscustomobject]@{ Bitmap=$canvas; Sequence=$sequence }
}

function Draw-ImageAtFloor {
    param([System.Drawing.Graphics]$Graphics, [string]$Path, [int]$X, [int]$FloorY)
    $image = Load-BitmapCopy -Path $Path
    try {
        $y = $FloorY - $image.Height
        $Graphics.DrawImageUnscaled($image, $X, $y)
        return [ordered]@{ x=$X; y=$y; width=$image.Width; height=$image.Height }
    }
    finally { $image.Dispose() }
}

function Draw-ContactShadow {
    param([System.Drawing.Graphics]$Graphics, [int]$X, [int]$Width, [int]$FloorY)
    $inset = [Math]::Max(8, [int][Math]::Round($Width * 0.12))
    $shadowWidth = [Math]::Max(12, $Width - ($inset * 2))
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(150, 4, 3, 10))
    try {
        $Graphics.FillRectangle($brush, ($X + $inset), ($FloorY - 3), $shadowWidth, 7)
        $Graphics.FillRectangle($brush, ($X + $inset + 10), ($FloorY - 6), ([Math]::Max(8, $shadowWidth - 20)), 4)
    }
    finally { $brush.Dispose() }
}

function Export-Validation {
    param(
        [string]$Theme,
        [string]$TileRoot,
        [array]$Placements,
        [string]$OutputPrefix
    )
    $backgroundResult = New-ThemeBackground -Theme $Theme -TileRoot $TileRoot
    $background = $backgroundResult.Bitmap
    $backgroundPath = Join-Path $validationRoot ($OutputPrefix + '_background_tiles_only.png')
    $background.Save($backgroundPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $scene = New-ArgbBitmap -Width $background.Width -Height $background.Height
    $graphics = [System.Drawing.Graphics]::FromImage($scene)
    $placementMetadata = [ordered]@{}
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.DrawImageUnscaled($background, 0, 0)
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None

        foreach ($placement in $Placements) {
            $image = Load-BitmapCopy -Path $placement.Path
            try {
                if ($placement.Shadow) { Draw-ContactShadow -Graphics $graphics -X $placement.X -Width $image.Width -FloorY 670 }
            }
            finally { $image.Dispose() }
        }
        foreach ($placement in $Placements) {
            $placementMetadata[$placement.Name] = Draw-ImageAtFloor -Graphics $graphics -Path $placement.Path -X $placement.X -FloorY (670 + $placement.FloorOffset)
        }
    }
    finally {
        $graphics.Dispose()
        $background.Dispose()
    }

    $scenePath = Join-Path $validationRoot ($OutputPrefix + '_tile_prop_validation.png')
    $scene.Save($scenePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $scene.Dispose()

    $metadata = [ordered]@{
        formatVersion = 1
        theme = $Theme
        canvas = [ordered]@{ width=2304; height=941 }
        roomOrigin = [ordered]@{ x=96; y=184 }
        floorY = 670
        constructionTileHeight = 560
        floorFromTileBottom = 74
        tileSequence = $backgroundResult.Sequence
        placements = $placementMetadata
    }
    $metadataPath = Join-Path $validationRoot ($OutputPrefix + '_tile_prop_validation.json')
    $metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $metadataPath -Encoding UTF8
    return [pscustomobject]@{ Background=$backgroundPath; Scene=$scenePath; Metadata=$metadataPath }
}

$hydroDefinitions = @(
    [pscustomobject]@{ Name='hydroponics_growth_tank_narrow'; Row=0; Column=0; TargetHeight=380 },
    [pscustomobject]@{ Name='hydroponics_growth_tank_full'; Row=0; Column=1; TargetHeight=380 },
    [pscustomobject]@{ Name='hydroponics_growth_tank_tall'; Row=0; Column=2; TargetHeight=380 },
    [pscustomobject]@{ Name='hydroponics_control_console'; Row=1; Column=0; TargetHeight=180 },
    [pscustomobject]@{ Name='hydroponics_plant_rack'; Row=1; Column=1; TargetHeight=240 },
    [pscustomobject]@{ Name='hydroponics_utility_sink'; Row=1; Column=2; TargetHeight=185 }
)
$crewDefinitions = @(
    [pscustomobject]@{ Name='crew_wash_station'; Row=0; Column=0; TargetHeight=300 },
    [pscustomobject]@{ Name='crew_heater'; Row=0; Column=1; TargetHeight=330 },
    [pscustomobject]@{ Name='crew_bedside_cabinet'; Row=0; Column=2; TargetHeight=160 },
    [pscustomobject]@{ Name='crew_bunk_left'; Row=1; Column=0; TargetHeight=290; ClearAllLightNeutral=$true },
    [pscustomobject]@{ Name='crew_privacy_screen'; Row=1; Column=1; TargetHeight=280 },
    [pscustomobject]@{ Name='crew_bunk_right'; Row=1; Column=2; TargetHeight=290; ClearAllLightNeutral=$true }
)

$hydroPropRoot = Join-Path $gameRoot 'Props\Hydroponics'
$crewPropRoot = Join-Path $gameRoot 'Props\CrewQuarters'
$hydroProps = Export-PropSheet -SourcePath (Join-Path $sourcePropSheetRoot 'hydroponics_props_sheet_3x2_rgb_v1.png') -AlphaSheetPath (Join-Path $sourcePropSheetRoot 'hydroponics_props_sheet_3x2_alpha_v1.png') -OutputRoot $hydroPropRoot -Definitions $hydroDefinitions
$crewProps = Export-PropSheet -SourcePath (Join-Path $sourcePropSheetRoot 'crew_quarters_props_sheet_3x2_rgb_v1.png') -AlphaSheetPath (Join-Path $sourcePropSheetRoot 'crew_quarters_props_sheet_3x2_alpha_v1.png') -OutputRoot $crewPropRoot -Definitions $crewDefinitions

$corridorTiles = Export-ThemeTiles -Theme 'Corridor' -SourcePath (Join-Path $generatedRoot 'Environments\empty_connector_corridor_block_v1.png')
$hydroTiles = Export-ThemeTiles -Theme 'Hydroponics' -SourcePath (Join-Path $generatedRoot 'Environments\hydroponics_empty_background_plate_v2.png')
$crewTiles = Export-ThemeTiles -Theme 'CrewQuarters' -SourcePath (Join-Path $generatedRoot 'Environments\crew_quarters_empty_background_plate_v2.png')

$characterPath = Join-Path $gameRoot 'Props\Workshop\mechanic_character_game_scale.png'

$corridorValidation = Export-Validation -Theme 'Corridor' -TileRoot $corridorTiles -Placements @(
    [pscustomobject]@{ Name='character'; Path=$characterPath; X=1030; FloorOffset=6; Shadow=$true }
) -OutputPrefix 'corridor_long'

$hydroValidation = Export-Validation -Theme 'Hydroponics' -TileRoot $hydroTiles -Placements @(
    [pscustomobject]@{ Name='growthTankNarrow'; Path=(Join-Path $hydroPropRoot 'hydroponics_growth_tank_narrow.png'); X=180; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='growthTankFull'; Path=(Join-Path $hydroPropRoot 'hydroponics_growth_tank_full.png'); X=420; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='growthTankTall'; Path=(Join-Path $hydroPropRoot 'hydroponics_growth_tank_tall.png'); X=660; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='controlConsole'; Path=(Join-Path $hydroPropRoot 'hydroponics_control_console.png'); X=990; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='plantRack'; Path=(Join-Path $hydroPropRoot 'hydroponics_plant_rack.png'); X=1320; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='utilitySink'; Path=(Join-Path $hydroPropRoot 'hydroponics_utility_sink.png'); X=1830; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='character'; Path=$characterPath; X=1110; FloorOffset=6; Shadow=$true }
) -OutputPrefix 'hydroponics_long_room'

$crewValidation = Export-Validation -Theme 'CrewQuarters' -TileRoot $crewTiles -Placements @(
    [pscustomobject]@{ Name='washStation'; Path=(Join-Path $crewPropRoot 'crew_wash_station.png'); X=170; FloorOffset=-14; Shadow=$false },
    [pscustomobject]@{ Name='heater'; Path=(Join-Path $crewPropRoot 'crew_heater.png'); X=500; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='bedsideCabinet'; Path=(Join-Path $crewPropRoot 'crew_bedside_cabinet.png'); X=790; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='bunkLeft'; Path=(Join-Path $crewPropRoot 'crew_bunk_left.png'); X=980; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='privacyScreen'; Path=(Join-Path $crewPropRoot 'crew_privacy_screen.png'); X=1450; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='bunkRight'; Path=(Join-Path $crewPropRoot 'crew_bunk_right.png'); X=1740; FloorOffset=3; Shadow=$true },
    [pscustomobject]@{ Name='character'; Path=$characterPath; X=900; FloorOffset=6; Shadow=$true }
) -OutputPrefix 'crew_quarters_long_room'

Write-Output "Corridor tiles: $corridorTiles"
Write-Output "Hydroponics tiles: $hydroTiles"
Write-Output "Hydroponics props: $hydroPropRoot"
Write-Output "Crew quarters tiles: $crewTiles"
Write-Output "Crew quarters props: $crewPropRoot"
Write-Output "Validation: $validationRoot"
