$ErrorActionPreference = 'Stop'

function Get-AsepriteExecutable {
    $candidates = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($env:ASEPRITE_EXE)) {
        $candidates.Add($env:ASEPRITE_EXE)
    }

    $command = Get-Command aseprite -ErrorAction SilentlyContinue
    if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
        $candidates.Add($command.Source)
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Aseprite\current\Aseprite.exe'))
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Aseprite\1.3.18.5\Aseprite.exe'))
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'AsepriteSourceBuild\aseprite-v1.3.18.5\build\bin\Aseprite.exe'))
    }

    $candidates.Add('C:\Program Files\Aseprite\Aseprite.exe')
    $candidates.Add('C:\Program Files (x86)\Aseprite\Aseprite.exe')
    $candidates.Add('C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe')

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw @'
Aseprite executable was not found.
Set ASEPRITE_EXE or install Aseprite under %LOCALAPPDATA%\Programs\Aseprite\current.
'@
}

function Invoke-Aseprite {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $Arguments
    )

    $executable = Get-AsepriteExecutable
    $previousUserFolder = $env:ASEPRITE_USER_FOLDER
    $temporaryUserFolder = Join-Path ([System.IO.Path]::GetTempPath()) 'sideview-shooter-aseprite-user'
    New-Item -ItemType Directory -Path $temporaryUserFolder -Force | Out-Null

    try {
        # Keep unattended CLI runs isolated from a developer's GUI preferences.
        $env:ASEPRITE_USER_FOLDER = $temporaryUserFolder

        $quotedArguments = foreach ($argument in $Arguments) {
            if ($argument -match '[\s"]') {
                '"' + $argument.Replace('"', '\"') + '"'
            }
            else {
                $argument
            }
        }

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $executable
        $startInfo.Arguments = ($quotedArguments -join ' ')
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void] $process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result

        if (-not [string]::IsNullOrWhiteSpace($stdout)) {
            Write-Output $stdout.TrimEnd()
        }
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            Write-Warning $stderr.TrimEnd()
        }
        if ($process.ExitCode -ne 0) {
            throw "Aseprite failed with exit code $($process.ExitCode)."
        }
    }
    finally {
        $env:ASEPRITE_USER_FOLDER = $previousUserFolder
    }
}
