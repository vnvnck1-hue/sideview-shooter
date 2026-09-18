param(
    [string]$WorkspaceRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$builder = Join-Path $PSScriptRoot 'build_workshop_modular_tiles.ps1'
$themes = @('Workshop', 'Corridor', 'Hydroponics', 'CrewQuarters')

foreach ($theme in $themes) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $builder -WorkspaceRoot $WorkspaceRoot -Theme $theme
    if ($LASTEXITCODE -ne 0) {
        throw "Modular tile build failed for theme: $theme"
    }
}

Write-Output 'All modular room tile sets generated.'
