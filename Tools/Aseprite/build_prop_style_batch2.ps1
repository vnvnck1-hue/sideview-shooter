param([ValidateSet(1,2,3,4)][int]$Revision=4, [ValidatePattern('^[a-z0-9-]+$')][string]$RunName='')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'PropStyleReview.cs') -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/PropStyleLab'
$batch=Join-Path $lab 'batch2'
$tag=if($RunName){$RunName}else{"r$Revision"}
$out=Join-Path $batch $tag
$review=Join-Path $batch "review-$tag"
if(Test-Path -LiteralPath $out){throw "Preserve existing source; use a new revision: $out"}
New-Item -ItemType Directory -Force -Path $out,$review,(Join-Path $review 'export-check'),(Join-Path $batch 'baseline') | Out-Null
$specs=@(
 @{name='microscope_station';w=55;h=59;theme='research_analysis';ref='hydroponics_control_console'},
 @{name='sample_cart';w=63;h=48;theme='research_analysis';ref='workshop_workbench_game_scale'},
 @{name='server_rack';w=61;h=88;theme='research_diagnostics';ref='workshop_locker_game_scale'}
)
$lua=Join-Path $PSScriptRoot 'create_prop_style_batch2.lua'
if($Revision -eq 4){$lua=Join-Path $PSScriptRoot 'create_prop_geometry_revision.lua'}
Invoke-Aseprite -Arguments @('--batch','--script-param',"output_root=$out",'--script-param',"revision=$Revision",'--script',$lua)
$results=@()
foreach($spec in $specs){
 $name=$spec.name;$source=Join-Path $out "$name.aseprite";$png=Join-Path $out "$name.png"
 $original=Join-Path $root "Assets/GameReady/Native4/Props/$($spec.theme)/$($spec.theme)_$name.png"
 $baseline=Join-Path $batch "baseline/$name.png"
 if(-not(Test-Path -LiteralPath $baseline)){Copy-Item -LiteralPath $original -Destination $baseline}
 [PropStyleReview]::AssertEqual($baseline,$original)
 Invoke-Aseprite -Arguments @('--batch',$source,'--save-as',$png)
 if($Revision -eq 4){
  $structure=Join-Path $out "$name-structure.png"
  Invoke-Aseprite -Arguments @('--batch',(Join-Path $out "$name-structure.aseprite"),'--save-as',$structure)
  foreach($scale in @(1,2,3,6)){
   [PropStyleReview]::Plate((Join-Path $review "$name-geometry-x$scale.png"),@((Join-Path $batch "r3/$name.png"),$structure,$png),@('BEFORE / R3','LOCKED STRUCTURE','REBUILT / R4'),$scale,$false)
  }
 }
 $technical=(& (Join-Path $PSScriptRoot 'verify_native_pixel_art.ps1') -Path $png -ExpectedWidth $spec.w -ExpectedHeight $spec.h -MaxOpaqueColors 16 -RequireBinaryAlpha -RequireTransparentBorder)|ConvertFrom-Json
 $check=Join-Path $review "export-check/$name.png"
 Invoke-Aseprite -Arguments @('--batch',$source,'--script-param','layers=5','--script',(Join-Path $PSScriptRoot 'verify_prop_study_source.lua'),'--save-as',$check)
 [PropStyleReview]::AssertEqual($png,$check)
 if($Revision -eq 4){
  Invoke-Aseprite -Arguments @('--batch',$source,'--script-param',"name=$name",'--script',(Join-Path $PSScriptRoot 'verify_prop_geometry.lua'))
 }
 $reference=Join-Path $lab "references/$($spec.ref).png"
 foreach($scale in @(1,2,3,6)){
   [PropStyleReview]::Plate((Join-Path $review "$name-x$scale.png"),@($reference,$baseline,$png),@('RUNTIME REFERENCE','PREVIOUS / BLOCKOUT',"BATCH 2 R$Revision"),$scale,$false)
 }
 [PropStyleReview]::Plate((Join-Path $review "$name-detail-x6.png"),@($png),@($name),6,$false)
 [PropStyleReview]::Plate((Join-Path $review "$name-gray-x3.png"),@($reference,$baseline,$png),@('RUNTIME REFERENCE','PREVIOUS / BLOCKOUT',"BATCH 2 R$Revision"),3,$true)
 $results+=[ordered]@{name=$name;technical=$technical;roundTripPixelsEqual=$true;sourceLayers=5;geometryContracts=($Revision -eq 4);geometryNegativeControl=($Revision -eq 4);sourceSHA256=(Get-FileHash $source).Hash;pngSHA256=(Get-FileHash $png).Hash;baselineSHA256=(Get-FileHash $baseline).Hash;referenceSHA256=(Get-FileHash $reference).Hash;artApproval='not-evaluated-by-validator'}
}
$paths=@();foreach($spec in $specs){$paths+=Join-Path $out "$($spec.name).png"}
foreach($scale in @(2,3,4)){
 [PropStyleReview]::Plate((Join-Path $review "new-props-x$scale.png"),$paths,@('MICROSCOPE STATION','SAMPLE CART','SERVER RACK'),$scale,$false)
}
$scenePaths=@((Join-Path $lab 'r3/analysis_bench.png'),$paths[0],$paths[1],(Join-Path $lab 'references/idle_01.png'),$paths[2])
foreach($theme in @('workshop','research_analysis')){
 foreach($scale in @(2,3,6)){
  [PropStyleReview]::Assembly((Join-Path $review "assembly-$theme-x$scale.png"),(Join-Path $lab "references/${theme}_background_WORLD.png"),$scenePaths,$scale)
 }
}
$results|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $review 'verification.json') -Encoding UTF8
$results|ConvertTo-Json -Depth 8
Write-Output 'STAGING ONLY: existing game assets and previous studies were not modified.'
