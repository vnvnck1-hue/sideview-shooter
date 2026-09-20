param([ValidatePattern('^[a-z0-9-]+$')][string]$RunName='crisp-final-r1',[ValidateRange(1,24)][int]$Tolerance=12,[ValidateRange(0,40)][int]$Snap=20,[switch]$Coherent=$true,[ValidateRange(0,8)][int]$Passes=3)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path @((Join-Path $PSScriptRoot 'PreservePropReview.cs'),(Join-Path $PSScriptRoot 'CrispPropReview.cs')) -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/ApprovedPropPixelTrial'
$out=Join-Path $lab $RunName
if(Test-Path -LiteralPath $out){throw 'Output exists; choose a fresh run name'}
New-Item -ItemType Directory -Path $out,(Join-Path $out 'review'),(Join-Path $out 'roundtrip') -Force|Out-Null
$specs=@(
 @{name='crew_wash_station';folder='CrewQuarters';crop=@(108,78,94,150)},
 @{name='workshop_locker_game_scale';folder='Workshop';crop=@(174,76,104,128)},
 @{name='workshop_armchair_game_scale';folder='Workshop';crop=@(164,99,104,116)}
)
$records=@()
foreach($s in $specs){
 $n=$s.name;$src=Join-Path $lab "r2/sources/$n.png"
 $original=Join-Path $root "Assets/GameReady/Props/$($s.folder)/$n.png"
 $sha=(Get-FileHash $src).Hash
 if($sha -ne (Get-FileHash $original).Hash){throw 'Approved source mismatch'}
 $ase=Join-Path $out "$n.aseprite";$png=Join-Path $out "$n.png"
 Invoke-Aseprite -Arguments @('--batch','--script-param',"input=$src",'--script-param',"output=$ase",'--script-param',"tolerance=$Tolerance",'--script-param',"snap=$Snap",'--script-param',"passes=$Passes",'--script-param',"coherent=$($Coherent.IsPresent.ToString().ToLowerInvariant())",'--script',(Join-Path $PSScriptRoot 'preserve_crisp_prop.lua'))
 Invoke-Aseprite -Arguments @('--batch',$ase,'--save-as',$png)
 $check=Join-Path $out "roundtrip/$n.png"
 Invoke-Aseprite -Arguments @('--batch',$ase,'--script-param',"input=$src",'--script-param',"png=$png",'--script',(Join-Path $PSScriptRoot 'verify_crisp_prop.lua'),'--save-as',$check)
 [PreservePropReview]::Equal($png,$check)
 $metrics=[PreservePropReview]::Compare($src,$png,1)|ConvertFrom-Json
 $audit=[CrispPropReview]::Audit($src,(Join-Path $lab "final-r1/$n.png"),$png)|ConvertFrom-Json
 if($metrics.partialAlpha -ne 0 -or $metrics.opaqueBorder -ne 0 -or $metrics.silhouetteIoU -ne 1){throw 'Native mask invariant failed'}
 [PreservePropReview]::Plate((Join-Path $out "review/$n-comparison.png"),$src,@((Join-Path $lab "final-r1/$n.png"),$png),@(2,1),@('PREVIOUS / x2','CRISP NATIVE / x1'))
 $c=$s.crop
 [PreservePropReview]::Detail((Join-Path $out "review/$n-detail.png"),$src,$png,1,$c[0],$c[1],$c[2],$c[3],3)
 if($sha -ne (Get-FileHash $original).Hash -or $sha -ne (Get-FileHash $src).Hash){throw 'Source mutated'}
 $records+=[ordered]@{name=$n;sourceSHA256=$sha;sourcePixelBlock=1;nativePadding=1;metrics=$metrics;edgeAudit=$audit;roundtripPixelMatch=$true;referenceAndLayersVerified=$true;tolerance=$Tolerance;snap=$Snap;coherent=$Coherent.IsPresent;passes=$Passes;pngSHA256=(Get-FileHash $png).Hash;asepriteSHA256=(Get-FileHash $ase).Hash;generatorSHA256=(Get-FileHash (Join-Path $PSScriptRoot 'preserve_crisp_prop.lua')).Hash;userApproval='pending';gameImported=$false}
}
$sourcePaths=@();$candidatePaths=@()
foreach($s in $specs){$sourcePaths+=Join-Path $lab "r2/sources/$($s.name).png";$candidatePaths+=Join-Path $out "$($s.name).png"}
[CrispPropReview]::Summary((Join-Path $out 'review/three-props-source-new.png'),$sourcePaths,$candidatePaths)
$crops=@(@(54,154,72,72),@(170,130,72,100),@(180,124,72,80))
for($i=0;$i -lt $specs.Count;$i++){$n=$specs[$i].name;$c=$crops[$i];[CrispPropReview]::Crop((Join-Path $out "review/$n-edge-comparison.png"),$sourcePaths[$i],(Join-Path $lab "final-r1/$n.png"),$candidatePaths[$i],$c[0],$c[1],$c[2],$c[3])}
$records|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $out 'verification.json') -Encoding UTF8
$records|ConvertTo-Json -Depth 8
