$ErrorActionPreference = 'Stop'

# Compiles PixelPreviewEngine.cs once per source hash and reuses the DLL afterwards,
# so a right-click preview does not pay the C# compile cost every time.
function Import-PixelPreviewEngine {
    if ('PixelPreviewEngine' -as [type]) { return }
    Add-Type -AssemblyName System.Drawing
    $source = Join-Path $PSScriptRoot 'PixelPreviewEngine.cs'
    $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.Substring(0, 16)
    $binDir = Join-Path $env:LOCALAPPDATA 'SideviewPixelPreview\bin'
    $dll = Join-Path $binDir "engine-$hash.dll"
    if (-not (Test-Path -LiteralPath $dll)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
        Add-Type -LiteralPath $source -ReferencedAssemblies System.Drawing -OutputAssembly $dll -OutputType Library
    }
    Add-Type -LiteralPath $dll
}

function Get-PixelPreviewRoot {
    Join-Path $env:LOCALAPPDATA 'SideviewPixelPreview\runs'
}
