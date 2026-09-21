param(
    [Parameter(Mandatory = $true)]
    [string]$Source,

    [Parameter(Mandatory = $true)]
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourcePath = [System.IO.Path]::GetFullPath($Source)
$outputPath = [System.IO.Path]::GetFullPath($OutDir)

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Source image not found: $sourcePath"
}

if (Test-Path -LiteralPath $outputPath) {
    throw "Output directory already exists: $outputPath"
}

[System.IO.Directory]::CreateDirectory($outputPath) | Out-Null

$nativeWidth = 72
$nativeHeight = 52
$contentWidth = 69
$contentHeight = 47
$worldWidth = $nativeWidth * 4
$worldHeight = $nativeHeight * 4
$contentX = 1
$contentY = 2
$alphaBoundsThreshold = 224
$alphaBinaryThreshold = 128

$sourceBitmap = [System.Drawing.Bitmap]::FromFile($sourcePath)
try {
    $minX = $sourceBitmap.Width
    $minY = $sourceBitmap.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $sourceBitmap.Height; $y++) {
        for ($x = 0; $x -lt $sourceBitmap.Width; $x++) {
            if ($sourceBitmap.GetPixel($x, $y).A -ge $alphaBoundsThreshold) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($maxX -lt $minX -or $maxY -lt $minY) {
        throw 'No sufficiently opaque robot pixels were found.'
    }

    $sourceBounds = [System.Drawing.Rectangle]::FromLTRB($minX, $minY, $maxX + 1, $maxY + 1)
    $nativeBitmap = New-Object System.Drawing.Bitmap($nativeWidth, $nativeHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($nativeBitmap)
        try {
            $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $destinationBounds = New-Object System.Drawing.Rectangle($contentX, $contentY, $contentWidth, $contentHeight)
            $graphics.DrawImage($sourceBitmap, $destinationBounds, $sourceBounds, [System.Drawing.GraphicsUnit]::Pixel)
        }
        finally {
            $graphics.Dispose()
        }

        for ($y = 0; $y -lt $nativeBitmap.Height; $y++) {
            for ($x = 0; $x -lt $nativeBitmap.Width; $x++) {
                $pixel = $nativeBitmap.GetPixel($x, $y)
                if ($pixel.A -ge $alphaBinaryThreshold) {
                    $nativeBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $pixel.R, $pixel.G, $pixel.B))
                }
                else {
                    $nativeBitmap.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
                }
            }
        }

        $nativeFile = Join-Path $outputPath 'quadruped_78_idle_native.png'
        $nativeBitmap.Save($nativeFile, [System.Drawing.Imaging.ImageFormat]::Png)

        $worldBitmap = New-Object System.Drawing.Bitmap($worldWidth, $worldHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            for ($nativeY = 0; $nativeY -lt $nativeBitmap.Height; $nativeY++) {
                for ($nativeX = 0; $nativeX -lt $nativeBitmap.Width; $nativeX++) {
                    $pixel = $nativeBitmap.GetPixel($nativeX, $nativeY)
                    for ($offsetY = 0; $offsetY -lt 4; $offsetY++) {
                        for ($offsetX = 0; $offsetX -lt 4; $offsetX++) {
                            $worldBitmap.SetPixel(($nativeX * 4) + $offsetX, ($nativeY * 4) + $offsetY, $pixel)
                        }
                    }
                }
            }

            $worldFile = Join-Path $outputPath 'quadruped_78_idle_4x.png'
            $worldBitmap.Save($worldFile, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $worldBitmap.Dispose()
        }
    }
    finally {
        $nativeBitmap.Dispose()
    }

    [PSCustomObject]@{
        source_bounds = @($sourceBounds.X, $sourceBounds.Y, $sourceBounds.Width, $sourceBounds.Height)
        native_canvas = @($nativeWidth, $nativeHeight)
        native_content = @($contentWidth, $contentHeight)
        world_canvas = @($worldWidth, $worldHeight)
        pivot_native = @([int]($nativeWidth / 2), $nativeHeight)
        alpha = 'binary'
    } | ConvertTo-Json -Depth 4
}
finally {
    $sourceBitmap.Dispose()
}
