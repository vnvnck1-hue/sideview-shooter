param([ValidatePattern('^[a-z0-9-]+$')][string]$RunName='two-x-r1')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -Path @((Join-Path $PSScriptRoot 'PreservePropReview.cs'),(Join-Path $PSScriptRoot 'PixelPitchReview.cs'),(Join-Path $PSScriptRoot 'EnvironmentPitchReview.cs')) -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$name='retro_medical_triage_room_concept_v1'
$lab=Join-Path $root "Assets/Generated/EnvironmentPixelTrials/$name"
$out=Join-Path $lab $RunName
if(Test-Path -LiteralPath $out){throw 'Existing result must not be overwritten'}
$previousRecords=Get-Content -Raw -Encoding UTF8 (Join-Path $lab 'r2/verification.json')|ConvertFrom-Json
$previous=$previousRecords[0]
$source=$previous.source
if((Get-FileHash $source).Hash -ne $previous.sourceSHA256){throw 'Source changed'}
$prepared=Join-Path $lab "r2/prepared/$name.aseprite";$prepPng=Join-Path $lab "r2/prepared/$name.png"
$prepHash=(Get-FileHash $prepared).Hash;$prepPngHash=(Get-FileHash $prepPng).Hash
Invoke-Aseprite -Arguments @('--batch',$prepared,'--script-param',"input=$source",'--script-param',"png=$prepPng",'--script',(Join-Path $PSScriptRoot 'verify_crisp_prop.lua'))
New-Item -ItemType Directory -Path $out,(Join-Path $out 'review'),(Join-Path $out 'roundtrip') -Force|Out-Null
$ase=Join-Path $out "$name.aseprite";$png=Join-Path $out "$name.png";$rt=Join-Path $out "roundtrip/$name.png"
Invoke-Aseprite -Arguments @('--batch','--script-param',"input=$source",'--script-param',"prepared=$prepared",'--script-param','step=2','--script-param',"output=$ase",'--script',(Join-Path $PSScriptRoot 'coarsen_crisp_prop.lua'))
Invoke-Aseprite -Arguments @('--batch',$ase,'--save-as',$png)
Invoke-Aseprite -Arguments @('--batch',$ase,'--script-param',"png=$png",'--script',(Join-Path $PSScriptRoot 'verify_pixel_pitch.lua'),'--save-as',$rt)
[PreservePropReview]::Equal($png,$rt)
$metrics=[PixelPitchReview]::Validate($source,$prepPng,$png,2)|ConvertFrom-Json
[void]([PixelPitchReview]::Validate($source,$source,$png,2))
[EnvironmentPitchReview]::Preview((Join-Path $out 'review/2x-source-size.png'),$png,$previous.sourceWidth,$previous.sourceHeight,2)
$crops=@(@{id='monitor';x=900;y=412;w=120;h=152},@{id='wash';x=210;y=459;w=144;h=148},@{id='bed';x=704;y=478;w=136;h=128})
foreach($c in $crops){[EnvironmentPitchReview]::CompareCrop((Join-Path $out "review/$($c.id)-source-2x-3x.png"),@($source,$png,(Join-Path $lab "r2/3x/$name.png")),@(1,2,3),@('SOURCE','NEW / 2.0x','PREVIOUS / 3.0x'),$c.x,$c.y,$c.w,$c.h)}
if((Get-FileHash $source).Hash -ne $previous.sourceSHA256 -or (Get-FileHash $prepared).Hash -ne $prepHash -or (Get-FileHash $prepPng).Hash -ne $prepPngHash){throw 'Source/preparation changed'}
$record=[ordered]@{name=$name;pixelPitch=2;source=$source;sourceWidth=$previous.sourceWidth;sourceHeight=$previous.sourceHeight;sourceSHA256=$previous.sourceSHA256;preparationSource=$prepared;preparationSHA256=$prepHash;preparationPNG_SHA256=$prepPngHash;preparationSettings=$previous.preparationSettings;metrics=$metrics;roundtripMatch=$true;referenceAndLayersVerified=$true;pngSHA256=(Get-FileHash $png).Hash;asepriteSHA256=(Get-FileHash $ase).Hash;gridGeneratorSHA256=(Get-FileHash (Join-Path $PSScriptRoot 'coarsen_crisp_prop.lua')).Hash;userDirection='Use 2x; 3x and 4x lose too much detail';userApproval='pixel_pitch_selected_final_visual_pending';gameImported=$false}
$record|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $out 'verification.json') -Encoding UTF8
$metrics|ConvertTo-Json -Compress
