param([int]$Revision=1)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'PropStyleReview.cs') -ReferencedAssemblies System.Drawing
$root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$lab=Join-Path $root 'Assets/Generated/PropStyleLab'
$out=Join-Path $lab "review-r$Revision"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$refs=@{analysis_bench='workshop_workbench_game_scale';cold_storage='workshop_locker_game_scale';specimen_chamber='hydroponics_growth_tank_full'}
$rows=New-Object System.Collections.Generic.List[string]
$rows.Add('role,file,width,height,opaque,colors,partialAlpha,border,minX,minY,maxX,maxY,opaqueNeighborPairs,delta24Percent')
foreach($name in @('analysis_bench','cold_storage','specimen_chamber')){
    $paths=@((Join-Path $lab "references/$($refs[$name]).png"),(Join-Path $lab "baseline/$name.png"),(Join-Path $lab "r$Revision/$name.png"))
    $labels=@('RUNTIME REFERENCE','PREVIOUS / BLOCKOUT',"STUDY R$Revision")
    foreach($scale in @(1,2,3,6)){
        [PropStyleReview]::Plate((Join-Path $out "$name-x$scale.png"),$paths,$labels,$scale,$false)
    }
    [PropStyleReview]::Plate((Join-Path $out "$name-gray-x3.png"),$paths,$labels,3,$true)
    [PropStyleReview]::Plate((Join-Path $out "$name-detail-x6.png"),@($paths[2]),@("R$Revision / $name"),6,$false)
    $roles=@('reference','baseline',"r$Revision")
    for($i=0;$i -lt $paths.Count;$i++){$rows.Add($roles[$i]+','+[PropStyleReview]::Stats($paths[$i]))}
}
$rows | Set-Content -LiteralPath (Join-Path $out 'metrics.csv') -Encoding UTF8
$rows
$scenePaths=@((Join-Path $lab 'references/workshop_workbench_game_scale.png'),(Join-Path $lab "r$Revision/analysis_bench.png"),(Join-Path $lab "r$Revision/cold_storage.png"),(Join-Path $lab 'references/idle_01.png'),(Join-Path $lab "r$Revision/specimen_chamber.png"))
foreach($theme in @('workshop','research_analysis')){
    foreach($scale in @(1,2,3,6)){
        [PropStyleReview]::Assembly((Join-Path $out "assembly-$theme-x$scale.png"),(Join-Path $lab "references/${theme}_background_WORLD.png"),$scenePaths,$scale)
    }
}
