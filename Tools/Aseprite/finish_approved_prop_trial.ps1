param([ValidatePattern('^[a-z0-9-]+$')][string]$RunName='final-r1')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'PreservePropReview.cs') -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/ApprovedPropPixelTrial'
$out=Join-Path $lab $RunName
if(Test-Path -LiteralPath $out){throw 'Preserve existing trial; choose a new run name'}
New-Item -ItemType Directory -Path $out,(Join-Path $out 'review'),(Join-Path $out 'roundtrip') -Force|Out-Null
$specs=@(
 @{name='crew_wash_station';folder='CrewQuarters';protect='wash_soap';crop=@(108,78,94,150)},
 @{name='workshop_locker_game_scale';folder='Workshop';protect='none';crop=@(174,76,104,128)},
 @{name='workshop_armchair_game_scale';folder='Workshop';protect='none';crop=@(164,99,104,116)}
)
$results=@()
foreach($s in $specs){
 $n=$s.name;$src=Join-Path $lab "r2/sources/$n.png"
 $original=Join-Path $root "Assets/GameReady/Props/$($s.folder)/$n.png"
 if((Get-FileHash $src).Hash -ne (Get-FileHash $original).Hash){throw 'Approved source changed'}
 $ase=Join-Path $out "$n.aseprite";$png=Join-Path $out "$n.png"
 Invoke-Aseprite -Arguments @('--batch','--script-param',"input=$src",'--script-param',"output=$ase",'--script-param','step=2','--script-param','colors=96','--script-param',"protect=$($s.protect)",'--script',(Join-Path $PSScriptRoot 'preserve_approved_prop.lua'))
 Invoke-Aseprite -Arguments @('--batch',$ase,'--save-as',$png)
 $m=[PreservePropReview]::Compare($src,$png,2)|ConvertFrom-Json
 $check=Join-Path $out "roundtrip/$n.png"
 Invoke-Aseprite -Arguments @('--batch',$ase,'--script-param',"width=$($m.width)",'--script-param',"height=$($m.height)",'--script',(Join-Path $PSScriptRoot 'verify_preserved_prop.lua'),'--save-as',$check)
 [PreservePropReview]::Equal($png,$check)
 [PreservePropReview]::Plate((Join-Path $out "review/$n-before-after.png"),$src,@($png),@(2),@('PIXEL CONVERSION / x2'))
 $c=$s.crop;[PreservePropReview]::Detail((Join-Path $out "review/$n-detail.png"),$src,$png,2,$c[0],$c[1],$c[2],$c[3],3)
 $results+=[ordered]@{name=$n;approvedSource=$original;sourceSHA256=(Get-FileHash $src).Hash;sourcePixelBlock=2;nativePadding=1;sourceMapping='floor(sourceCoordinate / 2) + 1';nativeMetrics=$m;roundtripPixelMatch=$true;layers=@('source_mapped_pixels','pixel_cleanup');localColourRepair=$s.protect;sourceSHA256Unchanged=((Get-FileHash $src).Hash -eq (Get-FileHash $original).Hash);asepriteSHA256=(Get-FileHash $ase).Hash;pngSHA256=(Get-FileHash $png).Hash;userApproval='pending';gameImported=$false}
}
$results|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $out 'verification.json') -Encoding UTF8
$sourcePaths=@();$candidatePaths=@();foreach($s in $specs){$sourcePaths+=Join-Path $lab "r2/sources/$($s.name).png";$candidatePaths+=Join-Path $out "$($s.name).png"}
[PreservePropReview]::Summary((Join-Path $out 'review/three-props-before-after.png'),$sourcePaths,$candidatePaths,@('WASH STATION','LOCKER','ARMCHAIR'))
$results|ForEach-Object{"$($_.name): $($_.nativeMetrics|ConvertTo-Json -Compress)"}
