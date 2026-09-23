# Hooded Mechanic

> **2026-09-23 — 고화질 원화로 전면 교체 (현행).** 게임이 쓰는 플레이어 리소스는 이제
> `Tools/build_hooded_mechanic_hq.py` 가 원화 한 장
> (`Assets/Generated/PlayerConcepts/hooded_mechanic_hq_source_v1.webp`, 128² 네이티브 · 키 93 art px)에서
> 파츠 리그(머리 / 팔+총 / 몸통 / 다리 3관절 IK)로 전부 다시 만든다.
> - 셀 512² (네이티브 128² × 4), 피벗 바닥 중심. 전신 높이 372 월드 px (구 v1 은 260).
> - 출력: `GodotPrototype/assets/character/{Split,Action,Frames}` + 검수물 `HQ/` (네이티브 원화·파츠·검수 시트).
> - 이후 `python Tools/build_normal_maps.py character/Split`. 인게임 검수: `tools/player_pose_shot.gd`.
> - 아래 v1 문서와 `build_hooded_mechanic_{animation,split,head_split,run}` · `action_frames` 스크립트는 **구 리소스용**이다.
>   다시 돌리면 새 리소스를 덮어쓰니 실행하지 않는다.

---

## (구) Hooded Mechanic Animation v1

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
