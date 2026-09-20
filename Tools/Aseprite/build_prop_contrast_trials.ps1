param([ValidatePattern('^[a-z0-9-]+$')][string]$RunName='contrast-r1')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path @((Join-Path $PSScriptRoot 'PreservePropReview.cs'),(Join-Path $PSScriptRoot 'PropContrastReview.cs')) -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/ApprovedPropPixelTrial'
$out=Join-Path $lab $RunName
if(Test-Path -LiteralPath $out){throw 'Refuse overwrite; choose a new run name'}
New-Item -ItemType Directory -Path $out,"$out/review","$out/roundtrip","$out/medium","$out/strong" -Force|Out-Null
$specs=@(
 @{name='crew_wash_station';label='WASH';crop=@(12,130,122,82)},
 @{name='workshop_locker_game_scale';label='LOCKER';crop=@(174,136,96,100)},
 @{name='workshop_armchair_game_scale';label='CHAIR';crop=@(160,96,104,112)}
)
$records=@();$sources=@();$allVariants=[System.Collections.Generic.List[string[]]]::new();$labels=@()
foreach($s in $specs){
 $n=$s.name;$src=Join-Path $lab "r2/sources/$n.png";$base=Join-Path $lab "final-r1/$n.aseprite";$basePng=Join-Path $lab "final-r1/$n.png"
 $protected=@($src,$base,$basePng);$before=@{};foreach($p in $protected){$before[$p]=(Get-FileHash $p).Hash}
 $variants=@($basePng)
 foreach($strength in @('medium','strong')){
  $ase=Join-Path $out "$strength/$n.aseprite";$png=Join-Path $out "$strength/$n.png"
  Invoke-Aseprite -Arguments @('--batch',$base,'--script-param',"source=$src",'--script-param',"output=$ase",'--script-param',"strength=$strength",'--script',(Join-Path $PSScriptRoot 'emphasize_preserved_prop.lua'))
  Invoke-Aseprite -Arguments @('--batch',$ase,'--save-as',$png)
  [PropContrastReview]::Validate($basePng,$png)
  $check=Join-Path $out "roundtrip/$n-$strength.png"
  Invoke-Aseprite -Arguments @('--batch',$ase,'--script-param',"baseline=$basePng",'--script-param',"strength=$strength",'--script',(Join-Path $PSScriptRoot 'verify_prop_contrast.lua'),'--save-as',$check)
  [PreservePropReview]::Equal($png,$check)
  $m=[PreservePropReview]::Compare($src,$png,2)|ConvertFrom-Json
  $records+=[ordered]@{name=$n;strength=$strength;baselineSHA256=$before[$basePng];sourceSHA256=$before[$src];nativeMetrics=$m;maskIdenticalToBaseline=$true;roundtripPixelMatch=$true;layerToggleRestoresBaseline=$true;asepriteSHA256=(Get-FileHash $ase).Hash;pngSHA256=(Get-FileHash $png).Hash;userApproval='pending';gameImported=$false}
  $variants+=$png
 }
 foreach($p in $protected){if((Get-FileHash $p).Hash -ne $before[$p]){throw 'Protected input modified'}}
 [PreservePropReview]::Plate("$out/review/$n-comparison.png",$src,$variants,@(2,2,2),@('BASELINE','A / MEDIUM','B / STRONG'))
 $c=$s.crop;[PropContrastReview]::Crop("$out/review/$n-detail.png",$src,$variants,$c[0],$c[1],$c[2],$c[3],2)
 $sources+=$src;$allVariants.Add([string[]]$variants);$labels+=$s.label
}
[PropContrastReview]::Grid("$out/review/all-comparison.png",$sources,$allVariants.ToArray(),$labels)
$records|ConvertTo-Json -Depth 8|Set-Content -LiteralPath "$out/verification.json" -Encoding UTF8
$records|ForEach-Object{"$($_.name) $($_.strength) - silhouette unchanged, roundtrip PASS"}
