param(
    [Parameter(Mandatory = $true)]
    [string] $Source,

    [Parameter(Mandatory = $true)]
    [string] $Sheet,

    [Parameter(Mandatory = $true)]
    [string] $Data,

    [ValidateSet('horizontal', 'vertical', 'rows', 'columns', 'packed')]
    [string] $SheetType = 'horizontal',

    [string] $Tag = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')

$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$sheetPath = [System.IO.Path]::GetFullPath($Sheet)
$dataPath = [System.IO.Path]::GetFullPath($Data)

$sheetDirectory = Split-Path -Parent $sheetPath
$dataDirectory = Split-Path -Parent $dataPath
New-Item -ItemType Directory -Path $sheetDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $dataDirectory -Force | Out-Null

$arguments = @(
    '--batch',
    $sourcePath,
    '--sheet', $sheetPath,
    '--data', $dataPath,
    '--format', 'json-array',
    '--sheet-type', $SheetType,
    '--list-tags',
    '--list-layers',
    '--filename-format', '{title}-{tag}-{frame1}'
)

if (-not [string]::IsNullOrWhiteSpace($Tag)) {
    $arguments += @('--tag', $Tag)
}

Invoke-Aseprite -Arguments $arguments

if (-not (Test-Path -LiteralPath $sheetPath -PathType Leaf)) {
    throw "Aseprite did not create the sprite sheet: $sheetPath"
}
if (-not (Test-Path -LiteralPath $dataPath -PathType Leaf)) {
    throw "Aseprite did not create the metadata file: $dataPath"
}

Write-Output "Sheet: $sheetPath"
Write-Output "Data:  $dataPath"

