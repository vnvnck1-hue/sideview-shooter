param([switch]$GenerateLegacyBlockouts)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Aseprite.Common.ps1')

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if (-not $GenerateLegacyBlockouts) {
    throw 'This generator produces rejected low-detail blockouts, not approved art. Use build_prop_style_studies.ps1 for the reviewed process. To reproduce the historical blockouts in staging only, specify -GenerateLegacyBlockouts.'
}
$nativeRoot = Join-Path $repositoryRoot ('Assets\Generated\ResearchFacilityBlockouts\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
if (Test-Path -LiteralPath $nativeRoot) { throw "Output already exists: $nativeRoot" }
$luaScript = Join-Path $PSScriptRoot 'create_research_facility_props.lua'

$specs = [ordered]@{
    research_analysis = [ordered]@{
        specimen_chamber = @(52, 84); analysis_bench = @(96, 53); microscope_station = @(55, 59)
        cold_storage = @(56, 75); sample_cart = @(63, 48)
    }
    research_isolation = [ordered]@{
        decon_arch = @(79, 102); isolation_pod = @(102, 62); wash_station = @(65, 59)
        medical_cabinet = @(54, 79); uv_sterilizer = @(54, 68)
    }
    research_diagnostics = [ordered]@{
        diagnostic_console = @(94, 62); server_rack = @(61, 88); wall_display = @(100, 53)
        signal_scope = @(58, 65); drone_dock = @(80, 55)
    }
}

foreach ($theme in $specs.Keys) {
    New-Item -ItemType Directory -Path (Join-Path $nativeRoot $theme) -Force | Out-Null
}

Invoke-Aseprite -Arguments @(
    '--batch',
    '--script-param', "output_root=$nativeRoot",
    '--script', $luaScript
)

foreach ($theme in $specs.Keys) {
    foreach ($name in $specs[$theme].Keys) {
        $size = $specs[$theme][$name]
        $base = Join-Path (Join-Path $nativeRoot $theme) "${theme}_${name}"
        $source = "$base.aseprite"
        $png = "$base.png"

        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Aseprite source was not created: $source"
        }

        if (Test-Path -LiteralPath $png) { throw "Refusing to overwrite: $png" }
        Invoke-Aseprite -Arguments @('--batch', $source, '--save-as', $png)
        & (Join-Path $PSScriptRoot 'verify_native_pixel_art.ps1') `
            -Path $png `
            -ExpectedWidth $size[0] `
            -ExpectedHeight $size[1] `
            -MaxOpaqueColors 11 `
            -RequireBinaryAlpha `
            -RequireTransparentBorder
    }
}

Write-Output "Generated 15 HISTORICAL BLOCKOUTS in staging only: $nativeRoot. Technical checks do not imply art approval. No runtime or tiles were modified."
