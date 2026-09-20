param([ValidatePattern('^[a-z0-9-]+$')][string]$RunName='r1')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'PreservePropReview.cs') -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out=Join-Path $root "Assets/Generated/ApprovedPropPixelTrial/$RunName"
if(Test-Path -LiteralPath $out){throw "Do not overwrite existing trial: $out"}
New-Item -ItemType Directory -Path $out,(Join-Path $out 'sources'),(Join-Path $out 'review') -Force|Out-Null
$specs=@(
 @{name='crew_wash_station';folder='CrewQuarters';crop=@(110,82,84,152)},
 @{name='workshop_locker_game_scale';folder='Workshop';crop=@(174,76,104,128)},
 @{name='workshop_armchair_game_scale';folder='Workshop';crop=@(164,99,104,116)}
)
$variants=@(@{tag='grid4-c96';step=4;colors=96},@{tag='grid2-c64';step=2;colors=64},@{tag='grid2-c96';step=2;colors=96})
$records=@()
foreach($spec in $specs){
 $source=Join-Path $root "Assets/GameReady/Props/$($spec.folder)/$($spec.name).png"
 $hash=(Get-FileHash -LiteralPath $source).Hash
 $frozen=Join-Path $out "sources/$($spec.name).png";Copy-Item -LiteralPath $source -Destination $frozen
 $paths=@();$steps=@();$labels=@()
 foreach($v in $variants){
  $dir=Join-Path $out $v.tag;New-Item -ItemType Directory -Path $dir -Force|Out-Null
  $ase=Join-Path $dir "$($spec.name).aseprite";$png=Join-Path $dir "$($spec.name).png"
  Invoke-Aseprite -Arguments @('--batch','--script-param',"input=$frozen",'--script-param',"output=$ase",'--script-param',"step=$($v.step)",'--script-param',"colors=$($v.colors)",'--script',(Join-Path $PSScriptRoot 'preserve_approved_prop.lua'))
  Invoke-Aseprite -Arguments @('--batch',$ase,'--save-as',$png)
  $metrics=[PreservePropReview]::Compare($frozen,$png,$v.step)|ConvertFrom-Json
  if($metrics.partialAlpha -ne 0 -or $metrics.opaqueBorder -ne 0){throw 'Pixel format violation'}
  $records+=[ordered]@{name=$spec.name;variant=$v.tag;source=$source;sourceSHA256=$hash;step=$v.step;paletteBudget=$v.colors;metrics=$metrics;sourceOffsetNative=@(1,1);asepriteSHA256=(Get-FileHash $ase).Hash;pngSHA256=(Get-FileHash $png).Hash;status='candidate-not-user-approved'}
  $paths+=$png;$steps+=$v.step;$labels+=$v.tag.ToUpper()
 }
 [PreservePropReview]::Plate((Join-Path $out "review/$($spec.name)-candidates.png"),$frozen,$paths,$steps,$labels)
 $c=$spec.crop
 [PreservePropReview]::Detail((Join-Path $out "review/$($spec.name)-detail.png"),$frozen,$paths[2],2,$c[0],$c[1],$c[2],$c[3],3)
 if((Get-FileHash $source).Hash -ne $hash){throw 'Source changed'}
}
$records|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $out 'candidates.json') -Encoding UTF8
$records|ForEach-Object{"$($_.name) $($_.variant): $($_.metrics|ConvertTo-Json -Compress)"}
