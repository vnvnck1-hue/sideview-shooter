# Right-click pixel preview: runs the preservation pipeline in memory (PixelPreviewEngine,
# pixel-equal to the Aseprite Lua scripts) for several pixel pitches and opens a viewer.
# Nothing is written next to the source or into the repository; runs live under
# %LOCALAPPDATA%\SideviewPixelPreview\runs.
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)][string[]]$Path,
    [string]$Pitches = '1,2,3,4',
    [ValidateRange(1, 24)][int]$Tolerance = 12,
    [ValidateRange(0, 40)][int]$Snap = 20,
    [switch]$NoCoherent,
    [ValidateRange(0, 8)][int]$Passes = 3,
    [switch]$NoOpen,
    [switch]$Gui
)
$ErrorActionPreference = 'Stop'
$status = $null
try {
    if ($Gui) {
        Add-Type -AssemblyName System.Windows.Forms
        $status = New-Object System.Windows.Forms.Form
        $status.Text = '픽셀 미리보기'; $status.Width = 340; $status.Height = 90; $status.TopMost = $true
        $status.FormBorderStyle = 'FixedToolWindow'; $status.StartPosition = 'CenterScreen'; $status.ControlBox = $false
        $label = New-Object System.Windows.Forms.Label
        $label.Dock = 'Fill'; $label.TextAlign = 'MiddleCenter'; $label.Text = '미리보기 생성 중…'
        $status.Controls.Add($label); $status.Show(); [System.Windows.Forms.Application]::DoEvents()
    }
    . (Join-Path $PSScriptRoot 'PixelPreview.Common.ps1')
    Import-PixelPreviewEngine
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $pitchList = [double[]]@($Pitches -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [double]::Parse($_, $inv) })
    foreach ($p in $pitchList) { if ($p -lt 1 -or $p -gt 4) { throw "Pitch $p is outside 1..4" } }
    $coherent = -not $NoCoherent
    $builder = (Resolve-Path (Join-Path $PSScriptRoot '../Aseprite/build_native_from_source.ps1')).Path
    $template = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'viewer.html') -Raw -Encoding UTF8
    $views = @()
    foreach ($item in $Path) {
        $src = (Resolve-Path -LiteralPath $item).Path
        if ([IO.Path]::GetExtension($src) -ne '.png') { throw "PNG만 지원합니다: $src" }
        if ($label) { $label.Text = "미리보기 생성 중… $([IO.Path]::GetFileName($src))"; [System.Windows.Forms.Application]::DoEvents() }
        $stem = [IO.Path]::GetFileNameWithoutExtension($src)
        $run = Join-Path (Get-PixelPreviewRoot) ("$stem-" + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        $json = [PixelPreviewEngine]::Run($src, $run, $pitchList, $Tolerance, $Snap, $coherent, $Passes)
        Set-Content -LiteralPath (Join-Path $run 'manifest.json') -Value $json -Encoding UTF8

        $make = [ordered]@{}; $cmdFiles = [ordered]@{}
        foreach ($p in $pitchList) {
            $key = $p.ToString('0.###', $inv)
            $args = "-Source `"$src`" -Pitch $key -Tolerance $Tolerance -Snap $Snap -Passes $Passes" + $(if ($coherent) { '' } else { ' -NoCoherent' })
            $make[$key] = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$builder`" $args"
            $cmd = Join-Path $run ("make-pitch-" + $key.Replace('.', '_') + '.cmd')
            # cmd.exe reads batch files in the ANSI/OEM code page, so write with the system default.
            Set-Content -LiteralPath $cmd -Encoding Default -Value @('@echo off', $make[$key], 'pause')
            $cmdFiles[$key] = $cmd
        }
        $data = [ordered]@{ manifest = ($json | ConvertFrom-Json); make = $make; cmdFiles = $cmdFiles }
        $html = $template.Replace('/*__DATA__*/null', ($data | ConvertTo-Json -Depth 8 -Compress))
        $index = Join-Path $run 'index.html'
        [IO.File]::WriteAllText($index, $html, (New-Object System.Text.UTF8Encoding($false)))
        $views += $index
        "PREVIEW $stem -> $index"
    }
    if ($status) { $status.Close() }
    if (-not $NoOpen) { foreach ($v in $views) { Start-Process -FilePath $v } }
}
catch {
    if ($status) { $status.Close() }
    if ($Gui) {
        [System.Windows.Forms.MessageBox]::Show("미리보기 실패:`n$($_.Exception.Message)", '픽셀 미리보기', 'OK', 'Error') | Out-Null
    }
    throw
}
