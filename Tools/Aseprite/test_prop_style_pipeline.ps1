param()
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'PropStyleReview.cs') -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/PropStyleLab'
[PropStyleReview]::SelfTest((Join-Path $lab 'tests'))
Write-Output 'PASS: grid phase, lossless round trip, off-grid rejection, alpha denominator, delta threshold'
$blocked=$false
try {& (Join-Path $PSScriptRoot 'build_research_facility_props.ps1')}catch{$blocked=$_.Exception.Message -like '*rejected low-detail blockouts*'}
if(-not $blocked){throw 'Historical blockout generator did not reject default invocation'}
Write-Output 'PASS: historical generator is disabled by default'
$blocked=$false
try {& (Join-Path $PSScriptRoot 'build_prop_style_studies.ps1') -Revision 3}catch{$blocked=$_.Exception.Message -like '*Study already exists*'}
if(-not $blocked){throw 'Study source overwrite was not rejected'}
Write-Output 'PASS: existing authored study sources cannot be overwritten'
foreach($name in @('analysis_bench','cold_storage','specimen_chamber')){
    [PropStyleReview]::AssertEqual((Join-Path $lab "baseline/$name.png"),(Join-Path $root "Assets/GameReady/Native4/Props/research_analysis/research_analysis_$name.png"))
}
Write-Output 'PASS: original three Native4 PNGs remain identical to frozen baseline'
$reproName='r3-repro-'+[DateTime]::UtcNow.ToString('yyyyMMddHHmmssfff')
& (Join-Path $PSScriptRoot 'build_prop_style_studies.ps1') -Revision 3 -RunName $reproName
foreach($name in @('analysis_bench','cold_storage','specimen_chamber')){
    [PropStyleReview]::AssertEqual((Join-Path $lab "r3/$name.png"),(Join-Path $lab "$reproName/$name.png"))
}
Write-Output 'PASS: separate deterministic regeneration matches all r3 PNGs exactly'
[ordered]@{passed=$true;reproRun=$reproName;checks=@('grid-phase','lossless-round-trip','off-grid-rejection','opaque-pairs-only','delta24-threshold','legacy-default-blocked','source-overwrite-blocked','baseline-preserved','fresh-r3-regeneration-equal')} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $lab 'tests/pipeline-result.json') -Encoding UTF8
