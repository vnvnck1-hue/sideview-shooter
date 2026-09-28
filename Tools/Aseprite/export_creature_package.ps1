$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'CreatureExport.cs') -ReferencedAssemblies System.Drawing
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$baseDir=Join-Path $repoRoot 'Assets\Generated\CreatureProductionV1'
foreach($id in @('CeilingBell','RingSpine','SeamAmbusher')) {
 $dir=Join-Path $baseDir "processed\$id"
 $m=Get-Content -LiteralPath (Join-Path $dir 'animation.json') -Raw | ConvertFrom-Json
 foreach($fr in $m.frames) {
  $rel="$($fr.clip)\$($fr.key).png"
  [CreatureExport]::Export((Join-Path $dir "frames\$rel"),(Join-Path $dir "runtime4x\frames\$rel"),(Join-Path $dir "normals\$rel"),(Join-Path $dir "runtime4x\normals\$rel"))
 }
 [string[]]$sheets=@($m.clips | ForEach-Object {Join-Path $dir $_.sheet})
 [string[]]$labels=@($m.clips | ForEach-Object {$_.name})
 [CreatureExport]::Contact($sheets,$labels,(Join-Path $dir 'preview\contact_sheet.png'),$m.cell[0],$m.cell[1])
 $first=$m.frames[0]
 [CreatureExport]::Compare((Join-Path $baseDir "prepared\$id\$($first.key).png"),(Join-Path $dir "frames\$($first.clip)\$($first.key).png"),(Join-Path $dir 'preview\source_native_comparison.png'))
 Write-Output "EXPORTED $id native normals, Native4 runtime color/normal pairs, review images"
}
$records=Get-ChildItem -LiteralPath (Join-Path $baseDir 'sources') -Filter '*.png' | ForEach-Object { @{file=('sources/'+$_.Name);sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()} }
$sourceManifest=@{generator='built-in image_gen';sourceSheets=$records;selectedConcepts=@();generatedSourceCount=6;gameImported=$false;pixelResultApproval='pending user review'}
foreach($file in @('01_ceiling_bell.png','04_ring_spine.png','05_seam_ambusher.png')){
 $p=(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'Deliverables') -Recurse -Filter $file -File | Select-Object -First 1).FullName
 if(-not $p){throw "Missing selected concept: $file"}
 $relative=$p.Substring($repoRoot.Length+1).Replace('\','/')
 $sourceManifest.selectedConcepts+=@{file=$relative;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant();authorization='User selected concepts 1, 4, 5 and requested production assets and clips.'}
}
$sourceManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $baseDir 'source_manifest.json') -Encoding UTF8
