param(
    [string]$AssetRoot = "Assets\GameReady\Native4\Props\Defense",
    [string]$OutputRoot = "Assets\GameReady\Native4\Props\Defense",
    [string]$GameRoot = "GodotPrototype\assets\props\defense",
    [string]$SourceRoot = "Assets\Generated\SentryTurret\Animation"
)

Add-Type -AssemblyName System.Drawing

function Ensure-Dir([string]$Path) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
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

function Load-Bitmap([string]$Path) {
    return [System.Drawing.Bitmap]::new((Join-Path (Get-Location) $Path))
}

function Draw-Sprite(
    [System.Drawing.Graphics]$Graphics,
    [System.Drawing.Bitmap]$Bitmap,
    [double]$PivotX,
    [double]$PivotY,
    [double]$WorldX,
    [double]$WorldY,
    [double]$Scale,
    [double]$Angle
) {
    $r = $Angle * [Math]::PI / 180.0
    $c = $Scale * [Math]::Cos($r)
    $s = $Scale * [Math]::Sin($r)
    $dx = $WorldX - ($PivotX * $c) - ($PivotY * (-$s))
    $dy = $WorldY - ($PivotX * $s) - ($PivotY * $c)
    $matrix = [System.Drawing.Drawing2D.Matrix]::new([single]$c, [single]$s, [single](-$s), [single]$c, [single]$dx, [single]$dy)
    $Graphics.Transform = $matrix
    $Graphics.DrawImage($Bitmap, 0, 0, $Bitmap.Width, $Bitmap.Height)
    $Graphics.ResetTransform()
    $matrix.Dispose()
}

function Rotate-Local([double]$X, [double]$Y, [double]$Angle) {
    $r = $Angle * [Math]::PI / 180.0
    return @(
        ($X * [Math]::Cos($r) - $Y * [Math]::Sin($r)),
        ($X * [Math]::Sin($r) + $Y * [Math]::Cos($r))
    )
}

function Save-Upscaled([System.Drawing.Bitmap]$Native, [string]$Target) {
    $dst = [System.Drawing.Bitmap]::new($Native.Width * 4, $Native.Height * 4, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.DrawImage($Native, 0, 0, $dst.Width, $dst.Height)
    $g.Dispose()
    Set-BinaryAlpha $dst
    $dst.Save($Target, [System.Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
}

Ensure-Dir $OutputRoot
Ensure-Dir $GameRoot
Ensure-Dir $SourceRoot

$mount = Load-Bitmap (Join-Path $AssetRoot 'sentry_turret_mount_v3.png')
$base = Load-Bitmap (Join-Path $AssetRoot 'sentry_turret_base_v3.png')
$body = Load-Bitmap (Join-Path $AssetRoot 'sentry_turret_body_core_v3.png')
$front = Load-Bitmap (Join-Path $AssetRoot 'sentry_turret_front_v3.png')
$optic = Load-Bitmap (Join-Path $AssetRoot 'sentry_turret_optic_v3.png')

$frameW = 256
$frameH = 160
$frameCount = 8
$sheet = [System.Drawing.Bitmap]::new($frameW * $frameCount, $frameH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$sheetGraphics = [System.Drawing.Graphics]::FromImage($sheet)
$sheetGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$sheetGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$sheetGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$sheetGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$sheetGraphics.Clear([System.Drawing.Color]::Transparent)

# All values are native 4px-block coordinates. The weapon starts folded into the hatch,
# the body rises first, then the head and optic stand up and extend into firing position.
$frames = @(
    @{ BaseScale=0.12; BodyScale=0.20; FrontScale=0.16; OpticScale=0.16; RootX=112; RootY=127; BodyAngle=-78; HeadFold=-18 },
    @{ BaseScale=0.24; BodyScale=0.29; FrontScale=0.23; OpticScale=0.22; RootX=112; RootY=115; BodyAngle=-66; HeadFold=-16 },
    @{ BaseScale=0.36; BodyScale=0.38; FrontScale=0.30; OpticScale=0.29; RootX=112; RootY=102; BodyAngle=-53; HeadFold=-13 },
    @{ BaseScale=0.48; BodyScale=0.47; FrontScale=0.37; OpticScale=0.36; RootX=112; RootY=90;  BodyAngle=-39; HeadFold=-10 },
    @{ BaseScale=0.58; BodyScale=0.54; FrontScale=0.44; OpticScale=0.43; RootX=112; RootY=80;  BodyAngle=-26; HeadFold=-7 },
    @{ BaseScale=0.64; BodyScale=0.59; FrontScale=0.50; OpticScale=0.51; RootX=112; RootY=73;  BodyAngle=-14; HeadFold=-4 },
    @{ BaseScale=0.68; BodyScale=0.63; FrontScale=0.56; OpticScale=0.58; RootX=112; RootY=68;  BodyAngle=-5;  HeadFold=-2 },
    @{ BaseScale=0.70; BodyScale=0.66; FrontScale=0.60; OpticScale=0.62; RootX=112; RootY=65;  BodyAngle=0;   HeadFold=0 }
)

for ($i = 0; $i -lt $frameCount; $i++) {
    $f = $frames[$i]
    $offsetX = $i * $frameW

    # Flush floor hatch stays fixed while the lower station rises out of it.
    Draw-Sprite $sheetGraphics $mount 64 24 ($offsetX + 96) 132 1.0 0

    $baseW = 112 * $f.BaseScale
    $baseH = 112 * $f.BaseScale
    $baseX = $offsetX + 128 - ($baseW / 2)
    $baseY = 132 - $baseH
    Draw-Sprite $sheetGraphics $base 0 0 $baseX $baseY $f.BaseScale 0

    # Body is the animation root. It begins folded against the mast and levels out.
    Draw-Sprite $sheetGraphics $body 44 36 ($offsetX + $f.RootX) $f.RootY $f.BodyScale $f.BodyAngle

    # Front firing module follows the body socket, with a small extra fold angle.
    $frontLocal = Rotate-Local (84 * $f.BodyScale) (-3 * $f.BodyScale) $f.BodyAngle
    $frontX = $offsetX + $f.RootX + $frontLocal[0]
    $frontY = $f.RootY + $frontLocal[1]
    Draw-Sprite $sheetGraphics $front 12 32 $frontX $frontY $f.FrontScale ($f.BodyAngle + $f.HeadFold)

    # Optic follows a separate upper bracket and stands up last with the head.
    $opticLocal = Rotate-Local (66 * $f.BodyScale) (-12 * $f.BodyScale) $f.BodyAngle
    $opticX = $offsetX + $f.RootX + $opticLocal[0]
    $opticY = $f.RootY + $opticLocal[1]
    Draw-Sprite $sheetGraphics $optic 48 52 $opticX $opticY $f.OpticScale ($f.BodyAngle + $f.HeadFold)
}

$sheetGraphics.Dispose()
Set-BinaryAlpha $sheet

$nativePath = Join-Path $SourceRoot 'sentry_turret_deploy_v3_sheet_native.png'
$sheet.Save($nativePath, [System.Drawing.Imaging.ImageFormat]::Png)
$nativeGamePath = Join-Path $OutputRoot 'sentry_turret_deploy_v3_sheet_native.png'
$sheet.Save($nativeGamePath, [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()

$native = [System.Drawing.Bitmap]::new($nativePath)
$gamePath = Join-Path $GameRoot 'sentry_turret_deploy_v3_sheet.png'
Save-Upscaled $native $gamePath
$native.Dispose()

foreach ($b in @($mount, $base, $body, $front, $optic)) { $b.Dispose() }

@{
    id = 'sentry_turret_deploy_v3'
    frame_count = 8
    frame_size_native = @($frameW, $frameH)
    frame_size_game = @([int]($frameW * 4), [int]($frameH * 4))
    sheet_native = 'sentry_turret_deploy_v3_sheet_native.png'
    sheet_game = 'sentry_turret_deploy_v3_sheet.png'
    fps = 12
    loop = $false
    sequence = @(
        'hatch_open_stowed',
        'base_rises_body_folded',
        'body_unfolds',
        'head_lifts',
        'head_levels',
        'optic_stands',
        'barrels_extend',
        'deployed_ready'
    )
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputRoot 'sentry_turret_deploy_v3.json') -Encoding UTF8
