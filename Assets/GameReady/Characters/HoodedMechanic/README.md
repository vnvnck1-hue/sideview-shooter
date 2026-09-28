# Hooded Mechanic

> **2026-09-23 — 캐릭터 규격을 NPC 기준으로 확정. 게임은 v1 리소스(셀 320)를 쓴다 (현행).**
> - 셀 320² (네이티브 80² × 4), 피벗 바닥 중심. 서 있는 키 262~267 월드 px로 NPC(252~272)와 같은 비율이다.
> - 치수 단일 기준: `Docs/SCALE_CHARACTER_BASELINE.md`. 재측정: `python Tools/measure_character_scale.py --sheet`.
> - 게임 리소스 `GodotPrototype/assets/character/{Split,Action,Frames}` 는 아래 v1 문서와
>   `build_hooded_mechanic_{animation,split,head_split,run}` · `action_frames` 스크립트가 만든 것이다.
>
> **고화질판 (보류).** 같은 날 만든 고화질 원화 교체본(셀 512, 키 372)은 NPC보다 약 1.4배 커서 기준에서 제외했다.
> 원화·파츠·검수 시트는 `HQ/`, 빌드 스크립트 `Tools/build_hooded_mechanic_hq.py` 로 보존한다.
> 이 스크립트는 **실행하면 현행 리소스를 덮어쓰므로** 규격을 다시 정하기 전에는 돌리지 않는다.
> 게임 반입본은 커밋 98b8feb 에 남아 있다.

---

## Hooded Mechanic Animation v1 (현행 게임 리소스)

붉은 후드 정비공 캐릭터의 러프 최소 키프레임 리소스다.

## 구성

- 마스터 시트: `Sheets/hooded_mechanic_all_4x4_v1.png`
- 클립별 시트: `Sheets/hooded_mechanic_<clip>_4f_v1.png`
- 개별 프레임: `Frames/<clip>/<clip>_01.png`부터 `04.png`
- 메타데이터: `hooded_mechanic_animation_v1.json`

## 마스터 시트 배열

- 1행: Idle 4프레임
- 2행: Walk 4프레임
- 3행: Shoot 4프레임
- 4행: Crouch 4프레임

각 셀은 320 × 320 px이며 캐릭터는 오른쪽을 바라본다.

## 공통 피벗

- 피벗: Bottom Center
- 정규화 좌표: X = 0.5, Y = 0.0
- 모든 프레임의 최하단 접촉 픽셀: 셀 Y = 319

총과 팔이 오른쪽으로 뻗는 사격 프레임에서도 몸통 기준 위치를 옮기지 않는다.

## 권장 재생값

- Idle: 4 FPS, Loop
- Walk: 8 FPS, Loop
- Shoot: 10 FPS, No Loop
- Crouch: 6 FPS, No Loop

러프 키프레임이므로 실제 조작감에 맞춰 프레임 유지 시간을 조절한다.

## 임포트 권장값

- Filter Mode: Point / Nearest
- Compression: None
- Mip Maps: Off
- Mesh Type: Full Rect
- Pivot: Bottom Center
