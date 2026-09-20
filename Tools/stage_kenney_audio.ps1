# 채택한 Kenney 사운드만 Godot 프로젝트로 복사한다.
#
# 2026-09-20 오디션(Tools/build_audio_audition.py)에서 확정된 17개만 다룬다.
# 채택되지 않은 사운드는 쓰지 않는다 — 후보를 늘리려면 먼저 오디션 페이지에서 고를 것.
#
# 원본은 전부 CC0 이며 각 팩의 License.txt 도 함께 복사해 증빙으로 남긴다.
#
# 사용:
#   powershell -ExecutionPolicy Bypass -File Tools\stage_kenney_audio.ps1
#   powershell -ExecutionPolicy Bypass -File Tools\stage_kenney_audio.ps1 -WhatIf

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$KenneyRoot = "D:\2020_이전승찬파일\작업,내파일\Kenney Game Assets All-in-1 3.4.0 (Windows)\Kenney Game Assets All-in-1 3.7.0\Audio",
    [string]$OutRoot = (Join-Path $PSScriptRoot "..\GodotPrototype\assets\audio")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $KenneyRoot)) {
    throw "Kenney 오디오 경로를 찾을 수 없습니다: $KenneyRoot"
}

# 채택 17종. Dest 는 audio_manager.gd 의 SOUNDS 가 참조하는 경로와 정확히 일치해야 한다.
$files = @(
    # 플레이어
    @{ Pack = "Impact Sounds";  Src = "Audio/footstep_concrete_004.ogg"; Dest = "sfx/player/footstep_01.ogg" }
    @{ Pack = "RPG Audio";      Src = "Audio/cloth1.ogg";                Dest = "sfx/player/cloth_01.ogg" }
    @{ Pack = "RPG Audio";      Src = "Audio/cloth2.ogg";                Dest = "sfx/player/cloth_02.ogg" }
    @{ Pack = "RPG Audio";      Src = "Audio/cloth3.ogg";                Dest = "sfx/player/cloth_03.ogg" }
    @{ Pack = "Impact Sounds";  Src = "Audio/impactSoft_medium_000.ogg"; Dest = "sfx/player/roll_land_01.ogg" }

    # 무기 — 발사음은 fire_metal(어택) + fire_low(보디) 2레이어로 합성한다
    @{ Pack = "Sci-Fi Sounds";  Src = "Audio/impactMetal_000.ogg";            Dest = "sfx/weapon/fire_metal_01.ogg" }
    @{ Pack = "Sci-Fi Sounds";  Src = "Audio/impactMetal_001.ogg";            Dest = "sfx/weapon/fire_metal_02.ogg" }
    @{ Pack = "Sci-Fi Sounds";  Src = "Audio/lowFrequency_explosion_000.ogg"; Dest = "sfx/weapon/fire_low_01.ogg" }
    @{ Pack = "Impact Sounds";  Src = "Audio/impactTin_medium_000.ogg";       Dest = "sfx/weapon/shell_01.ogg" }

    # 탄착
    @{ Pack = "Impact Sounds";  Src = "Audio/impactWood_medium_004.ogg"; Dest = "sfx/impact/wood_01.ogg" }
    @{ Pack = "Foley Sounds";   Src = "Audio/Rocks/stoneHit5.ogg";       Dest = "sfx/impact/stone_01.ogg" }

    # 앰비언스
    @{ Pack = "Foley Sounds";   Src = "Audio/Water/drip3.ogg";         Dest = "ambience/drip_01.ogg" }
    @{ Pack = "Sci-Fi Sounds";  Src = "Audio/engineCircular_000.ogg";  Dest = "ambience/machine_01.ogg" }
    @{ Pack = "Sci-Fi Sounds";  Src = "Audio/spaceEngineLow_000.ogg";  Dest = "ambience/rumble_01.ogg" }
    @{ Pack = "Sci-Fi Sounds";  Src = "Audio/spaceEngineLow_001.ogg";  Dest = "ambience/rumble_02.ogg" }
    @{ Pack = "Sci-Fi Sounds";  Src = "Audio/spaceEngineLow_002.ogg";  Dest = "ambience/rumble_03.ogg" }

    # UI
    @{ Pack = "Interface Sounds"; Src = "Audio/tick_001.ogg"; Dest = "ui/tick_01.ogg" }
)

$copied = 0
$missing = @()

foreach ($f in $files) {
    $src = Join-Path $KenneyRoot (Join-Path $f.Pack $f.Src)
    if (-not (Test-Path $src)) {
        $missing += "$($f.Pack)/$($f.Src)"
        continue
    }
    $dst = Join-Path $OutRoot $f.Dest
    $dir = Split-Path $dst -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if ($PSCmdlet.ShouldProcess($dst, "Copy")) {
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
    $copied++
}

# 라이선스 증빙
$licDir = Join-Path $OutRoot "_licenses"
if (-not (Test-Path $licDir)) { New-Item -ItemType Directory -Force -Path $licDir | Out-Null }
foreach ($pack in ($files | ForEach-Object { $_.Pack } | Sort-Object -Unique)) {
    $lic = Join-Path $KenneyRoot (Join-Path $pack "License.txt")
    if (Test-Path $lic) {
        Copy-Item -LiteralPath $lic -Destination (Join-Path $licDir ("Kenney_" + ($pack -replace '\s', '_') + "_License.txt")) -Force
    }
}

Write-Host "복사 완료: $copied / $($files.Count) -> $OutRoot"
if ($missing.Count -gt 0) {
    Write-Host "찾지 못한 원본 $($missing.Count) 개:"
    $missing | ForEach-Object { Write-Host "  $_" }
}
