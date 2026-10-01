# Run a modeling script in an isolated Blender process.
# Example: .\Tools\Blender\run_blender.ps1 -Script .\Tools\Blender\setup_probe.py
# Use -InputBlend to modify a copy of an existing scene. Scripts choose output paths.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Script,
    [string]$InputBlend,
    [string[]]$ScriptArgs = @()
)
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not (Test-Path -LiteralPath $config.executable -PathType Leaf)) {
    throw 'Blender executable is missing. Update Tools/Blender/config.json.'
}
$scriptPath = (Resolve-Path -LiteralPath $Script).Path
$blenderArguments = @('--background', '--factory-startup', '--disable-autoexec')
if ($InputBlend) { $blenderArguments += (Resolve-Path -LiteralPath $InputBlend).Path }
$blenderArguments += @('--python-exit-code', '1', '--python', $scriptPath)
if ($ScriptArgs.Count -gt 0) { $blenderArguments += @('--') + $ScriptArgs }
& $config.executable @blenderArguments
if ($LASTEXITCODE -ne 0) { throw "Blender failed with exit code $LASTEXITCODE" }
