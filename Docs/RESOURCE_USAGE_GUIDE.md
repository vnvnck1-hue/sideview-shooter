# 타일·캐릭터 리소스 사용 가이드

이 문서는 현재 제작된 작업실 배경 타일과 붉은 후드 정비공 캐릭터 애니메이션을 실제 게임 장면에 배치하는 방법을 설명한다.

## 1. 사용할 리소스

### 작업실 배경 타일

경로: `Assets/GameReady/Tiles/Workshop/`

| 파일 | 크기 | 용도 |
|---|---:|---|
| `workshop_cap_left.png` | 160 × 560 | 방의 왼쪽 끝 |
| `workshop_cap_right.png` | 160 × 560 | 방의 오른쪽 끝 |
| `workshop_wall_a.png` | 256 × 560 | 중앙 벽 변형 A |
| `workshop_wall_b.png` | 256 × 560 | 중앙 벽 변형 B |
| `workshop_wall_c.png` | 256 × 560 | 중앙 벽 변형 C |
| `workshop_wall_c_mirror.png` | 256 × 560 | C의 좌우 반전 변형 |
| `workshop_wall_d.png` | 256 × 560 | 중앙 벽 변형 D |
| `workshop_wall_d_mirror.png` | 256 × 560 | D의 좌우 반전 변형 |
| `workshop_wall_repeat.png` | 256 × 560 | 눈에 띄는 장식이 적은 반복 구간 |

이 타일은 작은 지형 셀을 칠하는 일반 타일맵용 타일이 아니라, 천장·벽·바닥·기초를 한 번에 연결하는 세로 매크로 타일이다.

### 추가 배경 테마

작업실과 동일한 규격으로 다음 테마가 제공된다.

| 테마 | 경로 | 용도 |
|---|---|---|
| Corridor | `Assets/GameReady/Tiles/Corridor/` | 프랍이 없는 방 연결 구간 |
| Hydroponics | `Assets/GameReady/Tiles/Hydroponics/` | 수경재배실 배경 |
| CrewQuarters | `Assets/GameReady/Tiles/CrewQuarters/` | 승무원 숙소 배경 |

각 테마는 `cap_left`, `cap_right`, `wall_a`, `wall_b`, `wall_c`, `wall_d`, `wall_c_mirror`, `wall_d_mirror`, `wall_repeat`의 9개 타일을 가진다. 파일명 앞에는 테마 이름이 붙는다.

### 추가 방 프랍

수경재배실 프랍 경로: `Assets/GameReady/Props/Hydroponics/`

- 성장 탱크 3종
- 제어 콘솔과 실린더
- 바퀴 달린 식물 랙
- 세척대와 수도관

승무원 숙소 프랍 경로: `Assets/GameReady/Props/CrewQuarters/`

- 거울·선반·세면대 통합 프랍
- 배기 파이프가 포함된 난로
- 책과 머그가 놓인 협탁
- 좌우 침대 2종
- 이동식 가림막

프랍은 실제 알파 투명 PNG이며 기본 피벗은 Bottom Center다. 세면대처럼 벽에 붙는 프랍은 배치 JSON의 오프셋을 기준으로 벽 높이를 맞춘다.

### 캐릭터 애니메이션

경로: `Assets/GameReady/Characters/HoodedMechanic/`

- 전체 시트: `Sheets/hooded_mechanic_all_4x4_v1.png`
- 클립별 시트: `Sheets/hooded_mechanic_<clip>_4f_v1.png`
- 개별 프레임: `Frames/<clip>/<clip>_01.png`부터 `04.png`
- 피벗 및 클립 정보: `hooded_mechanic_animation_v1.json`

마스터 시트는 1280 × 1280 px이며 320 × 320 px 셀 16개로 구성된다.

| 마스터 시트 행 | 클립 | 프레임 | 권장 재생 | 반복 |
|---:|---|---:|---:|---|
| 1 | Idle | 4 | 4 FPS | 사용 |
| 2 | Walk | 4 | 8 FPS | 사용 |
| 3 | Shoot | 4 | 10 FPS | 사용 안 함 |
| 4 | Crouch | 4 | 6 FPS | 사용 안 함 |

행 번호는 이미지 위에서 아래 방향이다.

## 2. 공통 임포트 설정

타일과 캐릭터에 동일한 Pixels Per Unit 값을 적용한다. PPU의 실제 숫자는 프로젝트 기준에 맞춰 선택할 수 있지만 두 리소스군 사이에서는 반드시 같아야 한다.

- 필터링: Point 또는 Nearest
- 압축: None 또는 무손실
- 밉맵: 끔
- 메시: Full Rect
- 색 공간과 알파: 원본 PNG의 RGBA 유지
- 회전 패킹: 사용하지 않음
- 비정수 스케일: 사용하지 않음

카메라와 오브젝트 위치도 가능하면 정수 픽셀 또는 정수 PPU 단위에 맞춘다. Bilinear 필터, 자동 리사이즈, 비정수 확대를 사용하면 청키 픽셀이 흐려진다.

## 3. 배경 타일 조립 방법

### 3-0. Workshop Modular v2 — X/Y 확장형 두 레이어 타일

기존 `Tiles/<Theme>/`의 560px 세로 매크로 타일과 별개로, `Tiles/<Theme>_Modular/`에는 Workshop, Corridor, Hydroponics, CrewQuarters 공통의 128×128 셀 기반 확장형 리소스가 있다.

- `Background/`: 방 내부를 X/Y 방향으로 반복하는 불투명 배경 셀 6종
- `Frame/`: 외곽 벽 라인만 남긴 투명 오버레이 8종(모서리 4 + 변 4)
- `Frame/InnerCorners/`: 안쪽으로 꺾이는 오목 코너 4종

조립 순서는 `Background`로 전체 바탕을 채운 뒤, 모서리를 한 번 배치하고 `top`/`bottom`을 X축으로, `left`/`right`를 Y축으로 반복하는 방식이다. 안쪽으로 꺾이는 벽이나 룰타일 오목 코너에는 `Frame/InnerCorners/`의 4종을 사용한다. 검증 미리보기는 `Assets/GameReady/Validation/<theme>_modular_12x6_preview.png`, 셀·파일 목록은 `<theme>_modular_tiles_v2.json`, 룰 패턴은 `<theme>_modular_ruletile_rules_v2.json`에 있다. 고정 램프·환기구·문·프랍은 반복 타일에 포함하지 않고 별도 레이어로 배치한다.

네 테마를 모두 다시 가공할 때는 `Tools/build_all_modular_room_tiles.ps1`를 사용한다. 개별 테마만 만들 때는 `build_workshop_modular_tiles.ps1 -Theme Corridor|Hydroponics|CrewQuarters`처럼 실행한다.

### 기본 규칙

1. 모든 타일의 피벗을 Bottom Left로 설정한다.
2. 모든 타일을 같은 Y 좌표에 둔다.
3. 첫 타일로 `workshop_cap_left`를 배치한다.
4. 필요한 길이만큼 256px 중앙 벽 타일을 오른쪽으로 이어 붙인다.
5. 마지막에 `workshop_cap_right`를 배치한다.
6. 타일 사이에 간격을 두거나 서로 겹치지 않는다.

다음 타일의 X 좌표는 `현재 타일 X + 현재 타일 폭`으로 계산한다.

### 현재 검증된 조립 순서

```text
cap_left
wall_a
wall_b
wall_c
wall_d
wall_c_mirror
wall_d_mirror
wall_c
cap_right
```

각 타일의 시작 X 오프셋은 다음과 같다.

| 순서 | 타일 | 시작 X |
|---:|---|---:|
| 1 | cap_left | 0 |
| 2 | wall_a | 160 |
| 3 | wall_b | 416 |
| 4 | wall_c | 672 |
| 5 | wall_d | 928 |
| 6 | wall_c_mirror | 1184 |
| 7 | wall_d_mirror | 1440 |
| 8 | wall_c | 1696 |
| 9 | cap_right | 1952 |

이 조합의 전체 방 너비는 2112px이다.

같은 순서를 Corridor, Hydroponics, CrewQuarters 타일에도 사용할 수 있다. 테마가 다른 타일을 한 방 안에서 섞기보다 방 또는 복도 블록 단위로 전환한다.

### 바닥선과 충돌면

타일 전체 높이는 560px이지만 플레이어가 서는 바닥 표면은 이미지 최하단이 아니다.

- 이미지 위쪽 기준 바닥선: Y = 486px
- 이미지 아래쪽 기준 바닥선: Y = 74px

따라서 Bottom Left 피벗과 Y-up 좌표계를 사용하는 엔진에서는 타일 Transform Y보다 74px 위에 걷기용 바닥 충돌면을 둔다. PPU가 `N`이라면 월드 좌표 오프셋은 `74 / N`이다.

기초 영역 전체에 충돌을 자동 생성하기보다 바닥 표면에 단순한 수평 콜라이더를 별도로 두는 편이 안정적이다.

### 반복 무늬 관리

- 같은 벽 변형을 연속해서 여러 번 사용하지 않는다.
- 큰 균열, 조명, 환기구가 반복되어 패턴처럼 보이면 `wall_repeat` 또는 미러 변형을 사이에 넣는다.
- 좌우 캡은 방 끝에서만 사용한다.
- 프랍, 문과 캐릭터는 배경 타일 이미지에 합치지 않고 별도 레이어로 유지한다.

## 4. 캐릭터 시트 사용 방법

### 권장 방식: 개별 프레임 사용

현재 러프 리소스에서는 `Frames/` 아래의 개별 PNG를 직접 사용하는 방식이 가장 단순하다. 모든 프레임이 이미 320 × 320 px로 통일돼 있어 자동 트리밍을 끄고 그대로 애니메이션에 넣으면 된다.

중요한 설정은 다음과 같다.

- 피벗: Bottom Center
- 정규화 피벗: X = 0.5, Y = 0.0
- 공통 바닥 접촉선: 셀 Y = 319
- 캐릭터 기본 방향: 오른쪽
- 프레임 자동 자르기 또는 Tight Mesh: 사용하지 않음

프레임마다 투명 여백을 잘라내면 몸통과 발의 기준점이 달라져 애니메이션이 흔들린다. 반드시 전체 320 × 320 사각형을 유지한다.

### 시트를 직접 자르는 경우

- 마스터 시트: 4열 × 4행
- 셀 크기: 320 × 320
- 간격과 패딩: 0
- 각 셀 피벗: Bottom Center

일부 엔진의 스프라이트 편집기는 아래 행부터 번호를 붙인다. 마스터 시트의 행 순서는 위에서부터 Idle, Walk, Shoot, Crouch이므로 자동 생성된 이름만 믿지 말고 시각적으로 클립을 확인한다. 혼동을 피하려면 클립별 1280 × 320 시트를 사용한다.

### 장면 배치

캐릭터 Transform의 위치를 바닥 월드 좌표에 둔다. 스프라이트 교체 중 Transform 위치는 변경하지 않는다. 발과 몸의 최하단 접촉 픽셀이 모든 프레임에서 같은 피벗을 사용하므로 별도의 프레임 오프셋이 필요하지 않다.

왼쪽을 바라보게 할 때는 별도 이미지를 만들기보다 렌더러의 X축 뒤집기를 사용한다. 뒤집기의 중심도 Bottom Center 피벗을 유지해야 한다.

## 5. 애니메이션 상태 구성

### Idle

- 이동 입력이 없고, 사격하거나 숙이지 않을 때 재생한다.
- 4 FPS로 반복한다.
- 호흡과 후드의 작은 움직임만 표현한다.

### Walk

- 수평 이동 속도가 기준값보다 클 때 재생한다.
- 8 FPS로 반복한다.
- 실제 이동은 애니메이션의 루트 모션이 아니라 게임 이동 코드가 담당한다.

### Shoot

- 사격 입력 시 처음부터 한 번 재생한다.
- 10 FPS, 반복하지 않는다.
- 3번째 프레임에 총구 화염이 있다. 투사체 생성이나 히트 판정은 시각 프레임과 별도 로직으로 관리하되 이 프레임에 이벤트를 연결할 수 있다.
- 재생이 끝나면 현재 이동 상태에 따라 Idle 또는 Walk로 돌아간다.

### Crouch

- 숙이기 시작 시 1번부터 4번까지 재생한다.
- 숙이기 입력을 유지하는 동안 마지막 프레임을 유지한다.
- 현재 러프 단계에서는 일어설 때 프레임을 역순으로 재생할 수 있다.
- 숙인 상태에서는 별도의 낮은 콜라이더를 사용하되 콜라이더 바닥 좌표는 서 있을 때와 같게 유지한다.

### 권장 상태 우선순위

```text
Shoot > Crouch > Walk > Idle
```

게임 규칙상 숙인 채 사격이 필요해지면 전용 Crouch Shoot 클립이 추가되기 전까지는 상태 우선순위를 별도로 정의해야 한다.

## 6. 레이어와 정렬

뒤에서 앞으로 다음 순서를 권장한다.

```text
Background Tiles
Back-wall Doors
Floor Props
Character
Front Effects / Muzzle Flash
Foreground Frame
```

캐릭터 발이 배경 바닥선에 닿는지 확인하고, 가구와 겹칠 때는 오브젝트의 바닥 접점 또는 명시적인 Sorting Layer로 앞뒤 관계를 정한다.

## 7. Unity 적용 예시

### 타일

1. 타일 PNG 전체를 선택하고 Filter Mode를 `Point (no filter)`로 설정한다.
2. Compression을 `None`, Generate Mip Maps를 끈다.
3. Sprite Mode는 `Single`, Mesh Type은 `Full Rect`, Pivot은 `Bottom Left`로 둔다.
4. 빈 GameObject 아래에 타일 SpriteRenderer들을 자식으로 배치한다.
5. 각 자식의 X 위치를 이미지 폭을 PPU로 나눈 값만큼 누적한다.
6. 방 바닥에는 타일과 별도의 BoxCollider2D 또는 EdgeCollider2D를 둔다.

현재 리소스는 Unity Tilemap의 작은 격자 페인팅보다 프리팹형 Room Block으로 조립하는 방식이 더 적합하다.

### 캐릭터

1. 개별 프레임 PNG를 모두 같은 설정으로 임포트한다.
2. Sprite Mode는 `Single`, Mesh Type은 `Full Rect`, Pivot은 `Bottom Center`로 설정한다.
3. Idle, Walk, Shoot, Crouch AnimationClip을 만들고 각 폴더의 01~04 프레임을 순서대로 넣는다.
4. Idle과 Walk만 Loop Time을 켠다.
5. Animator 또는 코드 기반 상태 머신에서 권장 FPS와 상태 우선순위를 적용한다.
6. SpriteRenderer의 Flip X로 왼쪽 방향을 처리한다.

마스터 시트를 사용할 경우 Sprite Mode를 `Multiple`로 설정하고 320 × 320 Grid by Cell Size로 자른 뒤 모든 조각에 Bottom Center 피벗을 적용한다.

## 8. 검증 체크리스트

- 타일 경계에 1px 틈이나 겹침이 없는가?
- 모든 타일의 Y 좌표와 PPU가 같은가?
- 캐릭터 발이 타일 하단이 아니라 실제 바닥선에 서 있는가?
- 애니메이션 전환 중 캐릭터 Transform이 흔들리지 않는가?
- 모든 캐릭터 프레임이 320 × 320 Full Rect를 유지하는가?
- Shoot가 반복되지 않고 총구 화염 프레임이 한 번만 나오는가?
- Crouch 마지막 프레임을 유지할 때 콜라이더 바닥이 움직이지 않는가?
- 카메라와 스프라이트가 정수 픽셀 기준에 맞아 흐려지지 않는가?

## 9. 참고 파일

- 타일·프랍 배치 결과: `Assets/GameReady/Validation/workshop_long_room_tile_prop_validation.png`
- 타일 배치 순서와 좌표: `Assets/GameReady/Validation/workshop_long_room_tile_prop_validation.json`
- 복도 조립 검증: `Assets/GameReady/Validation/corridor_long_tile_prop_validation.png`
- 수경재배실 조립 검증: `Assets/GameReady/Validation/hydroponics_long_room_tile_prop_validation.png`
- 승무원 숙소 조립 검증: `Assets/GameReady/Validation/crew_quarters_long_room_tile_prop_validation.png`
- 추가 테마 좌표: 위 검증 이미지와 같은 이름의 JSON 파일
- 캐릭터 피벗과 클립 데이터: `Assets/GameReady/Characters/HoodedMechanic/hooded_mechanic_animation_v1.json`
- 누적 스타일 규칙: `Docs/ART_GUIDE.md`

현재 캐릭터 애니메이션은 게임 플레이 검증을 위한 최소 키프레임 버전이다. 최종 리소스로 발전시킬 때도 셀 크기, Bottom Center 피벗과 공통 바닥선은 변경하지 않는다.

## 10. Power Relay Room — 방식 B 신규 룸

새 지하 전력 릴레이·축전실 테마는 `Assets/GameReady/PowerRelayRoom/`에 있다. 네이티브 8px 규격 원본은 `Assets/GameReady/Native8/PowerRelayRoom/`, Godot에서 바로 읽는 game-scale 출력은 `GodotPrototype/assets/power_relay_room/`에 배치했다.

- 모듈형 배경: `Tiles/Background/` 16×16 art px 셀 6종, X/Y 반복 가능
- 외곽 프레임: `Tiles/Frame/` 8종과 `InnerCorners/` 4종
- 프랍: `Props/`의 릴레이 캐비닛·축전기 뱅크·차단기·정비 카트·작업 램프·배관 접속부
- 조명 프랍: `Lighting/`에 실제 기구만 분리. 빛의 범위는 코드 광원으로 별도 처리
- 물리 전선: `Cables/`에 고정점이 명확한 직선·처짐·수직·엘보·분리 끝단 변형
- 분해 파츠: `Destruction/`에 릴레이 캐비닛 조립본과 문짝·코어·상부 캡·베이스·힌지·전선 조각·파편을 각각 분리

Godot 런타임에는 `RoomData`의 `power_relay` 방으로 연결돼 있다. `scripts/power_relay_prop.gd`와 `scripts/power_relay_part.gd`가 캐비닛의 기능별 파츠를 충격 누적에 따라 RigidBody2D로 분리하고, `scripts/power_relay_cable.gd`가 케이블 텍스처를 물리 처짐 체인에 입힌다.

조립 및 충격 분리 순서는 `Assets/GameReady/PowerRelayRoom/README.md`, 전체 크기·피벗·물리 권장값은 `power_relay_room_manifest_v1.json`을 따른다. 검증 미리보기는 `Assets/GameReady/PowerRelayRoom/Validation/power_relay_room_modular_preview.png`다.
