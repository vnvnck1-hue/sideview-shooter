$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'CreatureSourcePrep.cs') -ReferencedAssemblies System.Drawing,System.Core
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$baseDir = Join-Path $repoRoot 'Assets\Generated\CreatureProductionV1'
$names = @{
 CeilingBell=@('idle','anticipate','strike','hold','retract','close','hurt','death')
 RingSpine=@('idle','roll','uncoil','lash','recoil','coil','hurt','death')
 SeamAmbusher=@('dormant','emerge','snap','hold','release','withdraw','hurt','death')
}
$adjustments = @{}
foreach($creatureId in @('CeilingBell','RingSpine','SeamAmbusher')) {
 $frames = @{}
 for($batch=0;$batch -lt 2;$batch++) {
  $letter = @('A','B')[$batch]
  $sourceFile = Join-Path $baseDir "sources\${creatureId}_$letter.png"
  $prepDir = Join-Path $baseDir "prepared\$creatureId"
  $clips = $names[$creatureId][($batch*4)..($batch*4+3)]
  $poses = [CreatureSourcePrep]::Run($sourceFile,$prepDir,$clips)
  foreach($pose in $poses) {$frames[$pose.key]=$pose}
 }
 $adjustments[$creatureId]=@{frames=$frames;pitch=3}
 if($creatureId -eq 'RingSpine'){$adjustments[$creatureId].pitch=4}
}
$adjustments | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $baseDir 'adjustments.json') -Encoding UTF8
Write-Output 'Prepared all 96 isolated source poses using connected components; no grid-boundary amputations.'
