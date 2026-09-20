# Kenney All-in-1 오디오 — 우리 게임용 선별 결과

> 조사일: 2026-09-20
> 원본: `D:\2020_이전승찬파일\작업,내파일\Kenney Game Assets All-in-1 3.4.0 (Windows)\Kenney Game Assets All-in-1 3.7.0\Audio`
> **이 문서는 후보 조사 기록이다.** 2026-09-20 오디션에서 17종이 확정되었고,
> 실제 적용·믹싱 내용은 `Docs/AUDIO_MIX.md` 를 본다. 채택되지 않은 사운드는 사용하지 않는다.
>
> 라이선스: 전 팩 **CC0 1.0** — 개인·교육·상업 전부 허용, 크레딧 불필요 (각 팩 `License.txt` 확인 완료)

---

## 1. 보유 팩 전체 (16개)

| 팩 | 우리 게임 적합도 | 비고 |
|---|---|---|
| **Impact Sounds** | ★★★ 최상 | 발소리·탄착·유리·목재·금속. **가장 많이 씀** |
| **Sci-Fi Sounds** | ★★★ 최상 | 문 개폐, 금속 충격, 폭발, 엔진 루프 |
| **Foley Sounds** | ★★☆ 높음 | 물방울, 금속판, 돌, woosh |
| **RPG Audio** | ★★☆ 높음 | 천 스침, 삐걱임, 금속 래치 |
| **Digital Audio** | ★☆☆ 부분 | zap 2종만 (조명 파괴용) |
| **Interface Sounds** | ★★☆ 높음 | UI 전반 + glitch 4종 |
| UI Audio | ★☆☆ 중복 | Interface Sounds가 상위 호환 |
| Retro Sounds 1 / 2 | ✗ | 8비트 톤. 현재 아트 방향과 불일치 |
| Music Jingles / Music Loops | ✗ | 전부 밝고 코믹한 톤. 지하 분위기와 정반대 |
| Casino Audio | ✗ | — |
| Synth Voice 1 / 2 | ✗ | — |
| Voiceover Pack / Fighter | ✗ | 영어 음성. 현재 불필요 |

---

## 2. 이벤트별 매칭 (스크립트 기준)

`GodotPrototype/scripts/` 에서 실제로 발생하는 이벤트에 직접 대응시킨 표.

| 이벤트 | 코드 | Kenney 원본 | 판정 |
|---|---|---|---|
| 걷기 | `player.gd:169` | `Impact Sounds/footstep_concrete_000~004` | ✅ **완벽** — 콘크리트 5배리에이션, 그대로 사용 |
| 앉기/일어서기 | `player.gd` crouch | `RPG Audio/cloth1~4` | ✅ 좋음 |
| 구르기 | `player.gd:297` | `Foley/Woosh/woosh1~8` + `Impact/impactSoft_medium_000~004` | ✅ woosh + 착지 2레이어로 조합 |
| 발사 | `player.gd:257` | `Sci-Fi/laserSmall_000~004` | ⚠️ **임시** — 아래 3번 참고 |
| 탄피 낙하 | `shell_casing.gd` | `Impact/impactTin_medium_000~004` | ✅ 가장 근접. 피치 +3~5 반음 권장 |
| 탄착·금속 | `bullet.gd:144` | `Impact/impactMetal_light_000~004` | ✅ 좋음 |
| 탄착·콘크리트 | `bullet.gd:144` | `Impact/impactMining_000~004` | ✅ 광산 곡괭이 계열. 돌 재질에 잘 맞음 |
| 탄착·목재 | `bullet.gd:144` | `Impact/impactWood_medium_000~004` | ✅ 좋음 |
| 유리 금가기 | `glass_window.gd:29` | `Impact/impactGlass_light_000~004` | ✅ **완벽** — light/medium/heavy 3단계 전부 있음 |
| 유리 파손 | `glass_window.gd:29` | `Impact/impactGlass_heavy_000~004` | ✅ 완벽 |
| 프랍 타격 | `hit_prop.gd:52` | `Foley/Plating/platesHit1~10`, `Foley/Rocks/stoneHit1~5`, `Impact/impactPlank_medium_*` | ✅ 재질별로 충분 |
| 조명 파괴 | `lamp_light.gd:105` | `Impact/impactGlass_light` + `Digital/zap1~2` + `Interface/glitch_001~004` | ✅ **3레이어 조합 권장** (전구 파열 → 전기 스파크 → 회로 글리치) |
| 조명 점멸/버즈 | `lamp_light.gd:133` | `Sci-Fi/forceField_000~004` | ⚠️ 가공 필요. 로우패스 + 피치다운해야 형광등 험이 됨 |
| 문 개폐 / 방 이동 | `room.gd:131` | `Sci-Fi/doorOpen_000~002`, `doorClose_000~002` | ✅ SF 해치 톤. 현재 벌크헤드 도어 아트와 맞음 |
| 문 삐걱 / 래치 | `room.gd` | `RPG/creak1~3`, `metalLatch`, `metalClick` | ✅ 낡은 느낌 보강용 |
| 물방울 앰비언스 | `room.gd` | `Foley/Water/drip1~4` | ✅ 지하 분위기에 직결 |
| 기계 험 앰비언스 | — | `Sci-Fi/engineCircular_000~004`(약 180KB, 긴 루프), `spaceEngineLow_000~004` | ⚠️ 가공 필요. 볼륨 낮추고 로우패스 |
| 터미널 | — | `Sci-Fi/computerNoise_000~003` | ✅ 배경 소품용 |
| 대형 파괴 | — | `Sci-Fi/explosionCrunch_000~004`, `lowFrequency_explosion_000~001` | ✅ |
| UI | 미구현 | `Interface Sounds` 전체 (약 100개) | ✅ 충분하고도 남음 |

---

## 3. 메울 수 없는 갭 3가지

Kenney만으로는 해결되지 않는 것. 외부 CC0 소스가 필요하다.

### ① 실사 총성 — 가장 큰 갭
Kenney의 총 소리는 전부 `laserSmall` / `laserLarge` / `laserRetro` 즉 **SF 레이저**다.
현재 아트 가이드는 "낡고 불안한 지하"이고 캐릭터는 정비공이므로, 건조한 실총 계열이 맞다.

- 임시: `laserSmall_000~004`를 `fire_temp_*`로 넣어 두고 타이밍 작업 진행
- 최종: [Freesound CC0](https://freesound.org/browse/tags/cc0/) 에서 `pistol`, `gunshot dry`, 또는 [Sonniss GDC 번들](https://sonniss.com/gameaudiogdc/) 무기 카테고리
- 대안 조합: `impactMetal_light` + `explosionCrunch`를 짧게 겹치면 꽤 그럴듯한 둔탁한 발사음이 나온다. 먼저 시도해 볼 것

> **2026-09-20 후속 조사 완료 → `Docs/GUNSHOT_SOUND_RESEARCH.md`.**
> Freesound `michorvath` 의 CC0 총기 9종으로 발사·재장전·빈 탄창·원거리 테일이 전부 해결된다.

### ② 형광등 버즈 루프
Kenney에 전기 험 루프가 없다. `forceField_*`를 가공하거나 Freesound에서 `fluorescent hum` / `electrical buzz` CC0로 받는 게 빠르다.

### ③ 방 앰비언스 베이스(룸톤)
`engineCircular` / `spaceEngineLow` 는 우주선 엔진 톤이라 그대로는 안 맞는다.
[Freesound 산업·실내 룸톤 팩(mzui)](https://freesound.org/people/mzui/packs/12983/) 쪽이 정답에 가깝다.

**단, 이 3개는 전부 프로토타입 단계에서는 없어도 된다.** 1~2번은 임시 대체가 되고, 3번은 나중에 붙이는 레이어다.

---

## 4. 확정 결과

위 후보 중 **17종이 채택**되었다. 스테이징 스크립트(`Tools/stage_kenney_audio.ps1`)는 그 17종만 복사하도록
갱신되었고, 목적지도 `GodotPrototype/assets/audio/` 로 바뀌었다.

```bash
powershell -ExecutionPolicy Bypass -File Tools\stage_kenney_audio.ps1
```

채택 목록·레벨·버스 구성·아직 무음인 이벤트는 전부 `Docs/AUDIO_MIX.md` 에 있다.
후보를 다시 들어보려면 `Tools/build_audio_audition.py` 로 오디션 페이지를 생성한다.
