param(
    [Parameter(Mandatory=$true)][string]$Source,
    [string]$GeneratedTarget = "Assets\Generated\SentryTurret\Animation\sentry_turret_deploy_direct_v1_sheet.png",
    [string]$GameTarget = "GodotPrototype\assets\props\defense\sentry_turret_deploy_direct_v1_sheet.png"
)

Add-Type -AssemblyName System.Drawing

function Ensure-Dir([string]$Path) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path (Get-Location) $Path)) | Out-Null
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

$src = [System.Drawing.Bitmap]::new($Source)
$targetWidth = 1664
$targetHeight = 936
$dst = [System.Drawing.Bitmap]::new($targetWidth, $targetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$g.Clear([System.Drawing.Color]::Transparent)
$g.DrawImage($src, 0, 0, $targetWidth, $targetHeight)
$g.Dispose(); $src.Dispose()
Set-BinaryAlpha $dst

Ensure-Dir $GeneratedTarget
Ensure-Dir $GameTarget
$dst.Save((Join-Path (Get-Location) $GeneratedTarget), [System.Drawing.Imaging.ImageFormat]::Png)
$dst.Save((Join-Path (Get-Location) $GameTarget), [System.Drawing.Imaging.ImageFormat]::Png)
$dst.Dispose()
