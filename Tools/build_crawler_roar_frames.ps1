param(
    [string]$Source = "Assets\Generated\CharacterAnimation\ToxicTumorCrawler\toxic_tumor_crawler_roar_strip_generated_v1.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $root $Source
$gameReady = Join-Path $root "Assets\GameReady\Characters\ToxicTumorCrawler"
$sheetPath = Join-Path $gameReady "Sheets\toxic_tumor_crawler_roar_4f_v1.png"
$framesDir = Join-Path $gameReady "Frames\roar"
$cellWidth = 543
$cellHeight = 756
$frameCount = 4

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Roar source sheet not found: $sourcePath"
}

$sourceBitmap = [System.Drawing.Bitmap]::FromFile($sourcePath)
try {
    if ($sourceBitmap.Width -ne ($cellWidth * $frameCount)) {
        throw "Expected a 4-frame 543px-wide strip, got $($sourceBitmap.Width)x$($sourceBitmap.Height)."
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sheetPath), $framesDir | Out-Null

    $canvas = [System.Drawing.Bitmap]::new($cellWidth * $frameCount, $cellHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($canvas)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            # The generated strip is shorter than the canonical cell. Bottom-align it so the
            # monster keeps the same ground pivot as the existing crawler clips.
            $top = $cellHeight - $sourceBitmap.Height
            $graphics.DrawImageUnscaled($sourceBitmap, 0, $top)
        } finally {
            $graphics.Dispose()
        }

        $canvas.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
        for ($frame = 0; $frame -lt $frameCount; $frame++) {
            $rect = [System.Drawing.Rectangle]::new($frame * $cellWidth, 0, $cellWidth, $cellHeight)
            $frameBitmap = $canvas.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            try {
                $framePath = Join-Path $framesDir ("toxic_tumor_crawler_roar_{0:00}.png" -f ($frame + 1))
                $frameBitmap.Save($framePath, [System.Drawing.Imaging.ImageFormat]::Png)
            } finally {
                $frameBitmap.Dispose()
            }
        }
    } finally {
        $canvas.Dispose()
    }
} finally {
    $sourceBitmap.Dispose()
}

Write-Output "Created $sheetPath and $frameCount roar frames."
