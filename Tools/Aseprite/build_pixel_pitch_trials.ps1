param([ValidatePattern('^[a-z0-9-]+$')][string]$RunName='pixel-pitch-r2',[ValidateSet('fine','coarse')][string]$PitchSet='fine')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path @((Join-Path $PSScriptRoot 'PreservePropReview.cs'),(Join-Path $PSScriptRoot 'PixelPitchReview.cs')) -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/ApprovedPropPixelTrial'
$out=Join-Path $lab $RunName
if(Test-Path -LiteralPath $out){throw 'Existing trial must not be overwritten'}
New-Item -ItemType Directory -Path $out,(Join-Path $out 'prepared'),(Join-Path $out 'review'),(Join-Path $out 'roundtrip') -Force|Out-Null
$specs=@(@{name='crew_wash_station';folder='CrewQuarters';crop=@(70,154,48,64)},@{name='workshop_locker_game_scale';folder='Workshop';crop=@(174,142,48,72)},@{name='workshop_armchair_game_scale';folder='Workshop';crop=@(200,130,48,64)})
$levels=@(@{id='a-125';step='1.25'},@{id='b-150';step='1.5'},@{id='c-200';step='2'})
if($PitchSet -eq 'coarse'){$levels=@(@{id='a-200';step='2'},@{id='b-300';step='3'},@{id='c-400';step='4'})}
$steps=@(1.0);foreach($l in $levels){$steps+=[double]::Parse($l.step,[cultureinfo]::InvariantCulture)}
[PixelPitchReview]::SetSteps([double[]]$steps)
$approval=Get-Content -Raw -Encoding UTF8 (Join-Path $lab 'crisp-final-r1/verification.json')|ConvertFrom-Json
$records=@()
foreach($s in $specs){
 $n=$s.name;$src=Join-Path $lab "r2/sources/$n.png";$original=Join-Path $root "Assets/GameReady/Props/$($s.folder)/$n.png"
 $a=$approval|Where-Object name -eq $n
 if((Get-FileHash $src).Hash -ne $a.sourceSHA256 -or (Get-FileHash $original).Hash -ne $a.sourceSHA256){throw 'Source hash mismatch'}
 $approved=Join-Path $lab "crisp-final-r1/$n.png"
 if((Get-FileHash $approved).Hash -ne $a.pngSHA256){throw 'Approved baseline changed'}
 $prepared=Join-Path $out "prepared/$n.aseprite";$preparedPng=Join-Path $out "prepared/$n.png"
 Invoke-Aseprite -Arguments @('--batch','--script-param',"input=$src",'--script-param',"output=$prepared",'--script-param','tolerance=12','--script-param','snap=20','--script-param','coherent=true','--script-param','passes=3','--script',(Join-Path $PSScriptRoot 'preserve_crisp_prop.lua'))
 Invoke-Aseprite -Arguments @('--batch',$prepared,'--save-as',$preparedPng)
 [PreservePropReview]::Equal($approved,$preparedPng)
 $paths=@($approved)
 foreach($l in $levels){
  $dir=Join-Path $out $l.id;New-Item -ItemType Directory -Path $dir -Force|Out-Null
  $ase=Join-Path $dir "$n.aseprite";$png=Join-Path $dir "$n.png";$rt=Join-Path $out "roundtrip/$($l.id)-$n.png"
  Invoke-Aseprite -Arguments @('--batch','--script-param',"input=$src",'--script-param',"prepared=$prepared",'--script-param',"step=$($l.step)",'--script-param',"output=$ase",'--script',(Join-Path $PSScriptRoot 'coarsen_crisp_prop.lua'))
  Invoke-Aseprite -Arguments @('--batch',$ase,'--save-as',$png)
  Invoke-Aseprite -Arguments @('--batch',$ase,'--script-param',"png=$png",'--script',(Join-Path $PSScriptRoot 'verify_pixel_pitch.lua'),'--save-as',$rt)
  [PreservePropReview]::Equal($png,$rt)
  $metrics=[PixelPitchReview]::Validate($src,$approved,$png,[double]::Parse($l.step,[cultureinfo]::InvariantCulture))|ConvertFrom-Json
  $paths+=$png
  $records+=[ordered]@{name=$n;level=$l.id;pixelPitch=$l.step;sourceSHA256=$a.sourceSHA256;approvedBaselineSHA256=$a.pngSHA256;freshPreparationMatchesApproved=$true;roundtripMatch=$true;metrics=$metrics;pngSHA256=(Get-FileHash $png).Hash;asepriteSHA256=(Get-FileHash $ase).Hash;userApproval='pending';gameImported=$false}
 }
 $sourceBitmap=[System.Drawing.Bitmap]::new($src)
 [PixelPitchReview]::Plate((Join-Path $out "review/$n-levels.png"),$paths,$sourceBitmap.Width,$sourceBitmap.Height)
 $sourceBitmap.Dispose();$c=$s.crop
 [PixelPitchReview]::Detail((Join-Path $out "review/$n-detail.png"),$paths,$c[0],$c[1],$c[2],$c[3])
 if((Get-FileHash $approved).Hash -ne $a.pngSHA256 -or (Get-FileHash $original).Hash -ne $a.sourceSHA256){throw 'Source/baseline changed during run'}
}
$records|ConvertTo-Json -Depth 8|Set-Content -Encoding UTF8 -LiteralPath (Join-Path $out 'verification.json')
$records|ForEach-Object{"$($_.name) $($_.level): $($_.metrics|ConvertTo-Json -Compress)"}
