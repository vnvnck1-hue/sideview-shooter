# Proves that the C# preview engine reproduces the approved Aseprite outputs pixel for pixel.
#   props : r2/sources -> Preserve(12/20/true/3)            == crisp-final-r1/*.png
#   room  : r2/source  -> Preserve(4/20/true/3)             == r2/prepared/*.png
#           r2/prepared -> Coarsen(step 2)                  == two-x-r1/*.png
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PixelPreview.Common.ps1')
Import-PixelPreviewEngine
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$props = Join-Path $root 'Assets/Generated/ApprovedPropPixelTrial'
$room = Join-Path $root 'Assets/Generated/EnvironmentPixelTrials/retro_medical_triage_room_concept_v1'
$roomName = 'retro_medical_triage_room_concept_v1'
$failed = 0

function Test-Case([string]$label, [PixelPreviewEngine+Raster]$actual, [string]$expectedPath, [long]$ms) {
    $expected = [PixelPreviewEngine]::Load($expectedPath)
    $diff = [PixelPreviewEngine]::Mismatch($actual, $expected)
    $ok = $diff -eq 0
    if (-not $ok) { $script:failed++ }
    '{0,-6} {1,-40} {2}x{3}  mismatch={4}  {5} ms' -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $label, $actual.W, $actual.H, $diff, $ms
}

foreach ($n in 'crew_wash_station', 'workshop_locker_game_scale', 'workshop_armchair_game_scale') {
    $src = [PixelPreviewEngine]::Load((Join-Path $props "r2/sources/$n.png"))
    $sw = [Diagnostics.Stopwatch]::StartNew(); $st = $null
    $out = [PixelPreviewEngine]::Preserve($src, 12, 20, $true, 3, [ref]$st)
    Test-Case "preserve $n" $out (Join-Path $props "crisp-final-r1/$n.png") $sw.ElapsedMilliseconds
}

$src = [PixelPreviewEngine]::Load((Join-Path $room 'r2/source.png'))
$sw = [Diagnostics.Stopwatch]::StartNew(); $st = $null
$prepared = [PixelPreviewEngine]::Preserve($src, 4, 20, $true, 3, [ref]$st)
Test-Case "preserve $roomName" $prepared (Join-Path $room "r2/prepared/$roomName.png") $sw.ElapsedMilliseconds

# Coarsen from the stored preparation, then also from the freshly computed one.
$stored = [PixelPreviewEngine]::Load((Join-Path $room "r2/prepared/$roomName.png"))
$sw = [Diagnostics.Stopwatch]::StartNew()
$two = [PixelPreviewEngine]::Coarsen($stored, $src.W, $src.H, 2)
Test-Case "coarsen x2 (stored prep)" $two (Join-Path $room "two-x-r1/$roomName.png") $sw.ElapsedMilliseconds
$sw = [Diagnostics.Stopwatch]::StartNew()
$two = [PixelPreviewEngine]::Coarsen($prepared, $src.W, $src.H, 2)
Test-Case "coarsen x2 (fresh prep)" $two (Join-Path $room "two-x-r1/$roomName.png") $sw.ElapsedMilliseconds

if ($failed) { throw "$failed parity case(s) failed" }
'All parity cases passed.'
