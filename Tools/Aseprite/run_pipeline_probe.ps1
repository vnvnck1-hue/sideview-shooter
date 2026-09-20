param(
    [string] $OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repositoryRoot 'Assets\Generated\AsepritePipeline'
}

$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

$luaScript = Join-Path $PSScriptRoot 'create_pipeline_probe.lua'
$sourceFile = Join-Path $outputPath 'native32_pipeline_probe.aseprite'
$sheetFile = Join-Path $outputPath 'native32_pipeline_probe_sheet.png'
$dataFile = Join-Path $outputPath 'native32_pipeline_probe_sheet.json'

Invoke-Aseprite -Arguments @(
    '--batch',
    '--script-param', "output_dir=$outputPath",
    '--script', $luaScript
)

if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
    throw "The Lua probe did not create $sourceFile"
}

& (Join-Path $PSScriptRoot 'export_sprite.ps1') `
    -Source $sourceFile `
    -Sheet $sheetFile `
    -Data $dataFile `
    -SheetType horizontal `
    -Tag pulse

& (Join-Path $PSScriptRoot 'verify_native_pixel_art.ps1') `
    -Path $sheetFile `
    -ExpectedWidth 128 `
    -ExpectedHeight 32 `
    -MaxOpaqueColors 8 `
    -RequireBinaryAlpha `
    -RequireTransparentBorder

Write-Output "Aseprite pipeline probe passed: $outputPath"

