$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'PropStyleReview.cs') -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$batch=Join-Path $root 'Assets/Generated/PropStyleLab/batch2'
$result=@()
foreach($name in @('microscope_station','sample_cart','server_rack')){
 $source=Join-Path $batch "r4/$name.aseprite"
 Invoke-Aseprite -Arguments @('--batch',$source,'--script-param',"name=$name",'--script',(Join-Path $PSScriptRoot 'verify_prop_geometry.lua'))
 foreach($suffix in @('', '-structure')){
  [PropStyleReview]::AssertEqual((Join-Path $batch "r4/$name$suffix.png"),(Join-Path $batch "r4-repro/$name$suffix.png"))
 }
 if((Get-FileHash $source).Hash -ne (Get-FileHash (Join-Path $batch "r4-repro/$name.aseprite")).Hash){throw 'Aseprite reproduction differs'}
 $result+=[ordered]@{name=$name;sourceSHA256=(Get-FileHash $source).Hash;pngSHA256=(Get-FileHash (Join-Path $batch "r4/$name.png")).Hash;geometryContracts=$true;negativeControl=$true;reproducedStructureAndFinalPixels=$true;reproducedAsepriteBytes=$true;artApproval='not-evaluated-by-validator'}
}
$result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $batch 'review-r4/geometry-verification.json') -Encoding UTF8
Write-Output 'PASS: 3 geometry contracts, 3 negative controls, 6 pixel reproductions, 3 source reproductions.'
