param([ValidateSet(1,2,3)][int]$Revision = 3, [ValidatePattern('^r[1-3](-[a-z0-9-]+)?$')][string]$RunName)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/PropStyleLab'
if(-not $RunName){$RunName="r$Revision"}
if($RunName -notmatch "^r$Revision(-|$)"){throw 'RunName must start with the selected revision.'}
$out=Join-Path $lab $RunName
if(Test-Path -LiteralPath $out){ throw "Study already exists. Preserve authored sources and use a new revision: $out" }
New-Item -ItemType Directory -Path $out -Force | Out-Null
$baseline=Join-Path $lab 'baseline'
New-Item -ItemType Directory -Path $baseline -Force | Out-Null
$specs=@{analysis_bench=@(96,53);cold_storage=@(56,75);specimen_chamber=@(52,84)}
foreach($name in $specs.Keys){
    $old=Join-Path $root "Assets/GameReady/Native4/Props/research_analysis/research_analysis_$name.png"
    $frozen=Join-Path $baseline "$name.png"
    if(-not(Test-Path -LiteralPath $frozen)){Copy-Item -LiteralPath $old -Destination $frozen}
}
Invoke-Aseprite -Arguments @('--batch','--script-param',"output_root=$out",'--script-param',"revision=$Revision",'--script',(Join-Path $PSScriptRoot 'create_prop_style_studies.lua'))
foreach($name in $specs.Keys){
    $base=Join-Path $out $name
    Invoke-Aseprite -Arguments @('--batch',"$base.aseprite",'--save-as',"$base.png")
    & (Join-Path $PSScriptRoot 'verify_native_pixel_art.ps1') -Path "$base.png" -ExpectedWidth $specs[$name][0] -ExpectedHeight $specs[$name][1] -MaxOpaqueColors 16 -RequireBinaryAlpha -RequireTransparentBorder
}
Write-Output "STUDY ONLY: $out (no runtime publishing)"
