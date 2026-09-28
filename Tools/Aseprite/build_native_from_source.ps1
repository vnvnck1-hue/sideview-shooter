# Generic entry for the approved preservation route (ASEPRITE_PIPELINE.md v1.13):
#   preserve_crisp_prop.lua (source 1px, colour clusters + edge cleanup)
#   -> coarsen_crisp_prop.lua (weighted colour-mode grid) when Pitch > 1.
# Settings normally come from a pixel preview choice (Tools/PixelPreview). The result is
# staging only: it is written under Assets/Generated/NativeFromSource and never imported.
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [ValidateRange(1.0, 4.0)][double]$Pitch = 1,
    [ValidateRange(1, 24)][int]$Tolerance = 12,
    [ValidateRange(0, 40)][int]$Snap = 20,
    [switch]$NoCoherent,
    [ValidateRange(0, 8)][int]$Passes = 3,
    [ValidatePattern('^[a-z0-9-]+$')][string]$RunName
)
$ErrorActionPreference = 'Stop'
$Coherent = -not $NoCoherent
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
. (Join-Path $PSScriptRoot '../PixelPreview/PixelPreview.Common.ps1')
Import-PixelPreviewEngine

$Source = (Resolve-Path -LiteralPath $Source).Path
[void](Get-AsepriteExecutable)  # fail before creating any output folder
# Aseprite trial builds exit 0 without saving, so every expected file is checked.
function Assert-Written([string[]]$Files) { foreach ($f in $Files) { if (-not (Test-Path -LiteralPath $f)) { throw "Aseprite did not write $f (a trial build cannot save or run scripts)" } } }
if ([IO.Path]::GetExtension($Source) -ne '.png') { throw 'Source must be a PNG' }
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$stem = [IO.Path]::GetFileNameWithoutExtension($Source)
$pitchTag = $Pitch.ToString('0.###', [Globalization.CultureInfo]::InvariantCulture).Replace('.', '_')
if (-not $RunName) { $RunName = 'p' + $pitchTag.Replace('_', '-') + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') }
$out = Join-Path $root "Assets/Generated/NativeFromSource/$stem/$RunName"
if (Test-Path -LiteralPath $out) { throw 'Output exists; choose a fresh run name' }
New-Item -ItemType Directory -Path $out, (Join-Path $out 'roundtrip') -Force | Out-Null

$sha = (Get-FileHash -LiteralPath $Source).Hash
$coherentText = $Coherent.ToString().ToLowerInvariant()
$prepAse = Join-Path $out "$stem.prepared.aseprite"; $prepPng = Join-Path $out "$stem.prepared.png"
Invoke-Aseprite -Arguments @('--batch', '--script-param', "input=$Source", '--script-param', "output=$prepAse", '--script-param', "tolerance=$Tolerance", '--script-param', "snap=$Snap", '--script-param', "passes=$Passes", '--script-param', "coherent=$coherentText", '--script', (Join-Path $PSScriptRoot 'preserve_crisp_prop.lua'))
Assert-Written $prepAse
Invoke-Aseprite -Arguments @('--batch', $prepAse, '--save-as', $prepPng)
Assert-Written $prepPng
$prepCheck = Join-Path $out "roundtrip/$stem.prepared.png"
Invoke-Aseprite -Arguments @('--batch', $prepAse, '--script-param', "input=$Source", '--script-param', "png=$prepPng", '--script', (Join-Path $PSScriptRoot 'verify_crisp_prop.lua'), '--save-as', $prepCheck)
Assert-Written $prepCheck
if ([PixelPreviewEngine]::MismatchFiles($prepPng, $prepCheck) -ne 0) { throw 'Preparation roundtrip mismatch' }

$ase = Join-Path $out "$stem.aseprite"; $png = Join-Path $out "$stem.png"
if ($Pitch -eq 1) {
    Move-Item -LiteralPath $prepAse -Destination $ase; Move-Item -LiteralPath $prepPng -Destination $png
    $generator = 'preserve_crisp_prop.lua'
}
else {
    $step = $Pitch.ToString([Globalization.CultureInfo]::InvariantCulture)
    Invoke-Aseprite -Arguments @('--batch', '--script-param', "input=$Source", '--script-param', "prepared=$prepAse", '--script-param', "step=$step", '--script-param', "output=$ase", '--script', (Join-Path $PSScriptRoot 'coarsen_crisp_prop.lua'))
    Assert-Written $ase
    Invoke-Aseprite -Arguments @('--batch', $ase, '--save-as', $png)
    Assert-Written $png
    $check = Join-Path $out "roundtrip/$stem.png"
    Invoke-Aseprite -Arguments @('--batch', $ase, '--script-param', "png=$png", '--script', (Join-Path $PSScriptRoot 'verify_pixel_pitch.lua'), '--save-as', $check)
    Assert-Written $check
    if ([PixelPreviewEngine]::MismatchFiles($png, $check) -ne 0) { throw 'Grid roundtrip mismatch' }
    $generator = 'preserve_crisp_prop.lua + coarsen_crisp_prop.lua'
}

# The preview must be what the pipeline makes; a mismatch means the engine port drifted.
$src = [PixelPreviewEngine]::Load($Source); $st = $null
$preview = [PixelPreviewEngine]::Preserve($src, $Tolerance, $Snap, $Coherent, $Passes, [ref]$st)
if ($Pitch -ne 1) { $preview = [PixelPreviewEngine]::Coarsen($preview, $src.W, $src.H, $Pitch) }
$previewMismatch = [PixelPreviewEngine]::Mismatch($preview, [PixelPreviewEngine]::Load($png))
if ($previewMismatch -ne 0) { throw "Preview engine differs from Aseprite output by $previewMismatch px; fix Tools/PixelPreview/PixelPreviewEngine.cs" }
if ((Get-FileHash -LiteralPath $Source).Hash -ne $sha) { throw 'Source mutated' }

$final = [PixelPreviewEngine]::Load($png)
$record = [ordered]@{
    name = $stem; source = $Source; sourceSHA256 = $sha; sourceWidth = $src.W; sourceHeight = $src.H
    pixelPitch = $Pitch; nativePadding = 1; nativeWidth = $final.W; nativeHeight = $final.H
    colours = [PixelPreviewEngine]::CountColours($final)
    tolerance = $Tolerance; snap = $Snap; coherent = $Coherent; passes = $Passes
    generator = $generator; roundtripPixelMatch = $true; previewPixelMatch = $true
    pngSHA256 = (Get-FileHash -LiteralPath $png).Hash; asepriteSHA256 = (Get-FileHash -LiteralPath $ase).Hash
    userApproval = 'pending'; gameImported = $false
}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'verification.json') -Encoding UTF8
"NATIVE $stem pitch=$Pitch -> $png ($($final.W)x$($final.H), $($record.colours) colours)"
