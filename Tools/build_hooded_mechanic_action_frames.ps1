param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot)
)

Add-Type -AssemblyName System.Drawing

$sourceRoot = Join-Path $WorkspaceRoot 'Assets\Generated\CharacterAnimation\HoodedMechanic'
$outputRoot = Join-Path $WorkspaceRoot 'GodotPrototype\assets\character\Action'
$outputSize = 320
$frameCount = 6
$alphaThreshold = 32
# The current Split idle player composite occupies y=-264..-2 from the
# ground pivot (263 visible pixels). Match that measured height instead of
# filling the whole 320px cell.
$targetVisibleHeight = 263

$clips = @(
    [ordered]@{ Name = 'reload'; Source = 'hooded_mechanic_reload_6f_v1.png' },
    [ordered]@{ Name = 'roll'; Source = 'hooded_mechanic_roll_6f_v1.png' }
)

function Get-AlphaBounds {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Left,
        [int]$Right,
        [int]$Threshold
    )

    $minX = $Right - $Left
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = $Left; $x -lt $Right; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -lt $Threshold) { continue }
            $localX = $x - $Left
            if ($localX -lt $minX) { $minX = $localX }
            if ($y -lt $minY) { $minY = $y }
            if ($localX -gt $maxX) { $maxX = $localX }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }

    if ($maxX -lt 0) {
        return [System.Drawing.Rectangle]::Empty
    }

    return New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
}

$frameData = @()
$maxVisibleHeightByClip = @{}

foreach ($clip in $clips) {
    $sourcePath = Join-Path $sourceRoot $clip.Source
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Missing source image: $sourcePath"
    }

    $source = [System.Drawing.Bitmap]::FromFile($sourcePath)
    try {
        for ($index = 0; $index -lt $frameCount; $index++) {
            $left = [int][Math]::Round($index * $source.Width / $frameCount)
            $right = [int][Math]::Round(($index + 1) * $source.Width / $frameCount)
            $bounds = Get-AlphaBounds -Bitmap $source -Left $left -Right $right -Threshold $alphaThreshold
            if ($bounds.IsEmpty) {
                throw "No visible pixels in $($clip.Name) frame $($index + 1)"
            }

            if (-not $maxVisibleHeightByClip.Contains($clip.Name) -or $bounds.Height -gt $maxVisibleHeightByClip[$clip.Name]) {
                $maxVisibleHeightByClip[$clip.Name] = $bounds.Height
            }

            $frameData += [ordered]@{
                Clip = $clip.Name
                SourcePath = $sourcePath
                SourceWidth = $source.Width
                Index = $index
                Left = $left
                Right = $right
                Bounds = $bounds
            }
        }
    }
    finally {
        $source.Dispose()
    }
}

foreach ($clip in $clips) {
    $clipOutputRoot = Join-Path $outputRoot $clip.Name
    New-Item -ItemType Directory -Force -Path $clipOutputRoot | Out-Null
	# Normalize each clip's tallest upright pose to the measured Split height.
	# This removes the small scale drift between the two generated source strips.
	$scale = $targetVisibleHeight / $maxVisibleHeightByClip[$clip.Name]

    $source = [System.Drawing.Bitmap]::FromFile((Join-Path $sourceRoot $clip.Source))
    try {
        foreach ($frame in ($frameData | Where-Object { $_.Clip -eq $clip.Name })) {
            $bounds = $frame.Bounds
            $targetWidth = [int][Math]::Max(1, [Math]::Round($bounds.Width * $scale))
            $targetHeight = [int][Math]::Max(1, [Math]::Round($bounds.Height * $scale))
            # Center the visible pose inside the runtime cell. The generated
            # strip has a few poses whose backpack or weapon reaches the cell
            # edge, so preserving the raw cell-center offset would clip them.
            $targetLeft = [int][Math]::Round(($outputSize - $targetWidth) / 2.0)
            # Put the last visible pixel at y=318, matching the existing
            # Split body's ground baseline inside its 320px cell.
            $targetTop = $outputSize - 1 - $targetHeight

            $output = New-Object System.Drawing.Bitmap($outputSize, $outputSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            $graphics = [System.Drawing.Graphics]::FromImage($output)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
                $destination = New-Object System.Drawing.Rectangle($targetLeft, $targetTop, $targetWidth, $targetHeight)
                $graphics.DrawImage($source, $destination, $frame.Left + $bounds.X, $bounds.Y, $bounds.Width, $bounds.Height, [System.Drawing.GraphicsUnit]::Pixel)
            }
            finally {
                $graphics.Dispose()
            }

            $frameName = '{0}_{1:d2}.png' -f $clip.Name, ($frame.Index + 1)
            $framePath = Join-Path $clipOutputRoot $frameName
            $output.Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
            $output.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

$scaleSummary = ($clips | ForEach-Object { "{0}={1:N4}" -f $_.Name, ($targetVisibleHeight / $maxVisibleHeightByClip[$_.Name]) }) -join ', '
Write-Output ("Built action frames at {0} using per-clip scales {1}" -f $outputRoot, $scaleSummary)
