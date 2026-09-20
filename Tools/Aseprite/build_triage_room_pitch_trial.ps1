param([ValidatePattern('^[a-z0-9-]+$')][string]$RunName='r2',[ValidateRange(1,24)][int]$Tolerance=4)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path @((Join-Path $PSScriptRoot 'PreservePropReview.cs'),(Join-Path $PSScriptRoot 'PixelPitchReview.cs'),(Join-Path $PSScriptRoot 'EnvironmentPitchReview.cs')) -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$name='retro_medical_triage_room_concept_v1'
$original=Join-Path $root "Assets/Generated/Environments/$name.png"
$out=Join-Path $root "Assets/Generated/EnvironmentPixelTrials/$name/$RunName"
if(Test-Path -LiteralPath $out){throw 'Existing trial must not be overwritten'}
New-Item -ItemType Directory -Path $out,(Join-Path $out 'prepared'),(Join-Path $out 'review'),(Join-Path $out 'roundtrip') -Force|Out-Null
$hash=(Get-FileHash $original).Hash
$source=Join-Path $out 'source.png';Copy-Item -LiteralPath $original -Destination $source
$bitmap=[System.Drawing.Bitmap]::new($source);$width=$bitmap.Width;$height=$bitmap.Height;$bitmap.Dispose()
$prepared=Join-Path $out "prepared/$name.aseprite";$prepPng=Join-Path $out "prepared/$name.png"
$scriptHash=(Get-FileHash (Join-Path $PSScriptRoot 'preserve_crisp_prop.lua')).Hash
Write-Output "Preparing full source $width x $height with source-colour tolerance=$Tolerance; source SHA256=$hash"
Invoke-Aseprite -Arguments @('--batch','--script-param',"input=$source",'--script-param',"output=$prepared",'--script-param',"tolerance=$Tolerance",'--script-param','snap=20','--script-param','coherent=true','--script-param','passes=3','--script',(Join-Path $PSScriptRoot 'preserve_crisp_prop.lua'))
Invoke-Aseprite -Arguments @('--batch',$prepared,'--save-as',$prepPng)
Invoke-Aseprite -Arguments @('--batch',$prepared,'--script-param',"input=$source",'--script-param',"png=$prepPng",'--script',(Join-Path $PSScriptRoot 'verify_crisp_prop.lua'))
$prepMetrics=[PixelPitchReview]::Validate($source,$source,$prepPng,1)|ConvertFrom-Json
$records=@();$candidates=@()
foreach($step in @(3,4)){
 $dir=Join-Path $out "${step}x";New-Item -ItemType Directory -Path $dir -Force|Out-Null
 $ase=Join-Path $dir "$name.aseprite";$png=Join-Path $dir "$name.png";$roundtrip=Join-Path $out "roundtrip/${step}x.png"
 Invoke-Aseprite -Arguments @('--batch','--script-param',"input=$source",'--script-param',"prepared=$prepared",'--script-param',"step=$step",'--script-param',"output=$ase",'--script',(Join-Path $PSScriptRoot 'coarsen_crisp_prop.lua'))
 Invoke-Aseprite -Arguments @('--batch',$ase,'--save-as',$png)
 Invoke-Aseprite -Arguments @('--batch',$ase,'--script-param',"png=$png",'--script',(Join-Path $PSScriptRoot 'verify_pixel_pitch.lua'),'--save-as',$roundtrip)
 [PreservePropReview]::Equal($png,$roundtrip)
 $metrics=[PixelPitchReview]::Validate($source,$prepPng,$png,$step)|ConvertFrom-Json
 # Independently check all final RGBs also belong to the original, not just the prepared layer.
 [void]([PixelPitchReview]::Validate($source,$source,$png,$step))
 [EnvironmentPitchReview]::Preview((Join-Path $out "review/${step}x-source-size.png"),$png,$width,$height,$step)
 $candidates+=$png
 $records+=[ordered]@{name=$name;pixelPitch=$step;source=$original;sourceWidth=$width;sourceHeight=$height;sourceSHA256=$hash;preparationSettings=@{tolerance=$Tolerance;snap=20;coherent=$true;passes=3};preparationMetrics=$prepMetrics;preparationGeneratorSHA256=$scriptHash;gridGeneratorSHA256=(Get-FileHash (Join-Path $PSScriptRoot 'coarsen_crisp_prop.lua')).Hash;metrics=$metrics;roundtripMatch=$true;referenceAndLayersVerified=$true;pngSHA256=(Get-FileHash $png).Hash;asepriteSHA256=(Get-FileHash $ase).Hash;userApproval='pending';gameImported=$false}
 Write-Output "${step}x: $($metrics|ConvertTo-Json -Compress)"
}
$crops=@(@{id='wash-and-towel';x=210;y=459;w=144;h=148},@{id='monitor-and-drawers';x=900;y=412;w=120;h=152},@{id='bed-and-blanket';x=704;y=478;w=136;h=128},@{id='curtain-and-lamp';x=1086;y=288;w=144;h=168})
foreach($c in $crops){[EnvironmentPitchReview]::Crop((Join-Path $out "review/$($c.id).png"),$source,$candidates[0],$candidates[1],$c.x,$c.y,$c.w,$c.h)}
if((Get-FileHash $original).Hash -ne $hash -or (Get-FileHash $source).Hash -ne $hash){throw 'Source changed'}
$records|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $out 'verification.json') -Encoding UTF8
Write-Output "Completed $out"
