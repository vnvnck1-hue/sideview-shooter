param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'PropStyleReview.cs') -ReferencedAssemblies System.Drawing
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$out = Join-Path $root 'Assets/Generated/PropStyleLab/references'
$provenance=Join-Path $out 'provenance.json'
if(Test-Path -LiteralPath $provenance){
    foreach($record in (Get-Content -LiteralPath $provenance -Raw -Encoding UTF8 | ConvertFrom-Json)){
        $live=Join-Path $root $record.source
        if((Get-FileHash -LiteralPath $live).Hash -ne $record.sha256){throw "Reference changed. Preserve this study; start a separately versioned comparison instead: $live"}
    }
}
New-Item -ItemType Directory -Force -Path $out | Out-Null
$refs = @('props/workshop_workbench_game_scale.png','props/workshop_locker_game_scale.png','props/workshop_armchair_game_scale.png','props/hydroponics_control_console.png','props/hydroponics_growth_tank_full.png','props/hydroponics_utility_sink.png','character/Frames/idle/idle_01.png')
$records=@()
foreach($ref in $refs) {
    $inputPath = Join-Path $root "GodotPrototype/assets/$ref"
    $outputPath = Join-Path $out ([IO.Path]::GetFileName($ref))
    $extraction=[PropStyleReview]::Extract($inputPath,$outputPath)
    $extraction
    [PropStyleReview]::Stats($outputPath)
    $records += [ordered]@{source="GodotPrototype/assets/$ref";sha256=(Get-FileHash $inputPath).Hash;nativeCopy=[IO.Path]::GetFileName($outputPath);gridAudit=$extraction}
}
foreach($theme in @('workshop','research_analysis')){
    $rel="tiles/${theme}_modular/${theme}_modular_background_sheet_3x2.png"
    $source=Join-Path $root "GodotPrototype/assets/$rel"
    $copy=Join-Path $out "${theme}_background_WORLD.png"
    Copy-Item -LiteralPath $source -Destination $copy -Force
    $records += [ordered]@{source="GodotPrototype/assets/$rel";sha256=(Get-FileHash $source).Hash;worldCopy=[IO.Path]::GetFileName($copy);gridAudit='Kept unchanged at world resolution; NOT a native art reference.'}
}
$records | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'provenance.json') -Encoding UTF8
