param([ValidateSet(1,2,3)][int]$Revision=3)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'PropStyleReview.cs') -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/PropStyleLab'
$out=Join-Path $lab "review-r$Revision/export-check"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$specs=@{analysis_bench=@(96,53);cold_storage=@(56,75);specimen_chamber=@(52,84)}
$results=@()
foreach($name in $specs.Keys){
    $source=Join-Path $lab "r$Revision/$name.aseprite"
    $png=Join-Path $lab "r$Revision/$name.png"
    $export=Join-Path $out "$name.png"
    $layers=4;if($Revision -eq 3){$layers=5}
    Invoke-Aseprite -Arguments @('--batch',$source,'--script-param',"layers=$layers",'--script',(Join-Path $PSScriptRoot 'verify_prop_study_source.lua'),'--save-as',$export)
    [PropStyleReview]::AssertEqual($png,$export)
    $technical=(& (Join-Path $PSScriptRoot 'verify_native_pixel_art.ps1') -Path $png -ExpectedWidth $specs[$name][0] -ExpectedHeight $specs[$name][1] -MaxOpaqueColors 16 -RequireBinaryAlpha -RequireTransparentBorder) | ConvertFrom-Json
    $results += [ordered]@{name=$name;technical=$technical;sourceLayers=$layers;roundTripPixelsEqual=$true;sourceSHA256=(Get-FileHash $source -Algorithm SHA256).Hash;pngSHA256=(Get-FileHash $png -Algorithm SHA256).Hash;generatorSHA256=(Get-FileHash (Join-Path $PSScriptRoot 'create_prop_style_studies.lua')).Hash;baselineSHA256=(Get-FileHash (Join-Path $lab "baseline/$name.png")).Hash;artApproval='not-evaluated-by-validator';scope='technical-only'}
}
$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $lab "review-r$Revision/verification.json") -Encoding UTF8
$results | ConvertTo-Json -Depth 8
