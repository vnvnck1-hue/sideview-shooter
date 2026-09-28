param([string[]]$Creature = @('CeilingBell','RingSpine','SeamAmbusher'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
foreach ($creatureId in $Creature) {
    Invoke-Aseprite -Arguments @('--batch','--script-param',"root=$repoRoot",'--script-param',"id=$creatureId",'--script',(Join-Path $PSScriptRoot 'build_creature_production.lua'))
    $out = Join-Path $repoRoot "Assets\Generated\CreatureProductionV1\processed\$creatureId"
    Invoke-Aseprite -Arguments @('--batch',(Join-Path $out "$creatureId.aseprite"),'--sheet',(Join-Path $out 'atlas.png'),'--data',(Join-Path $out 'atlas.json'),'--format','json-array','--sheet-type','rows','--sheet-columns','4','--list-tags','--list-layers')
    Invoke-Aseprite -Arguments @('--batch',(Join-Path $out "$creatureId.aseprite"),'--script-param',"root=$repoRoot",'--script-param',"id=$creatureId",'--script',(Join-Path $PSScriptRoot 'verify_creature_production.lua'))
    Invoke-Aseprite -Arguments @('--batch','--script-param',"root=$repoRoot",'--script-param',"id=$creatureId",'--script',(Join-Path $PSScriptRoot 'preview_creature_production.lua'))
}
