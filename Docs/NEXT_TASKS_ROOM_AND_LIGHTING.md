# 다음 작업 — 방 연결 · 문 가독성 · 조명 정리 · 자산 구조화

작성: 2026-09-20 · 브랜치 `feature/env-vfx-lighting` 기준
이 문서는 **아직 구현하지 않은 계획**이다. 2026-09-23에 규격 정립을 빠른 착수 항목으로 추가했다. 아래 4건의 기존 계획과 함께 관리한다.

## 빠른 착수 필요 — 캐릭터·배경 규격 정립

- **우선순위: 높음 / 상태: 착수 대기** (2026-09-23 등록)
- 캐릭터가 움직이는 테스트 씬에서 배경 타일·문·통로·프랍의 크기를 그레이박스로 비교하고, 검증한 규격으로 실제 배경을 제작한다.
- 첫 작업은 대표 캐릭터의 외형·충돌·이동 성능과 카메라 조건 측정, 이어서 치수 비교용 테스트 씬 구성이다.
- **배경 타일·프랍의 본격 제작 전에 우선 진행**한다. 기존 SpaceLab은 공간감 확인용이며, 규격 비교는 별도 씬을 기본안으로 한다.
- 실행 순서·산출물·완료 기준: [`SCALE_STANDARDIZATION_PLAN.md`](SCALE_STANDARDIZATION_PLAN.md).

---

## 1. 같은 층은 트랜지션 없이 이어지는 다방(多房) 구조

### 지금 상태
- `scripts/main.gd` 는 한 번에 방 **한 개만** 살려 둔다. `_load_room()` 이 `current_room.queue_free()` 로 이전 방을 통째로 버리고 새 `Room` 을 만든다.
- 측벽문 통과는 `main.gd:310-313` 에서 플레이어 x 가 방 양끝에 닿으면 `_go_to_room()` → `_transition()` (페이드) 으로 넘어간다.
  즉 **같은 평면 좌우 이동에도 페이드가 끼어든다.**
- `RoomData.ROOMS` 의 각 방은 자기 좌표계(왼쪽 끝 x=0, 바닥 `FLOOR_Y` 486)를 쓰고, 방끼리의 전역 좌표가 없다.

### 목표
- 같은 층(= 같은 `floor` / 체인)에 속한 방들을 **가로로 이어 붙여** 문을 열면 페이드 없이 옆방이 그대로 보이도록 한다.
- 문이 닫혀 있는 동안에는 옆방이 **보이지 않아야** 한다. 열리는 순간 트랜지션 없이 드러난다.
- 엘리베이터·계단 등 **층 이동만** 기존 페이드 트랜지션을 유지한다. 정면문(`front_doors`)도 다른 평면으로 가므로 트랜지션 유지.

### 먼저 만든 것 — 감각 확인용 테스트 씬 (2026-09-22)
구현 판단에 앞서 **느낌만 먼저** 보려고 `scenes/SpaceLab.tscn` 을 만들었다.
방 5개와 연결 통로 4개를 **열 프로필 하나로 이어 붙인 단일 Room**(20,096 × 1,152px)이라
아래 1~6번(다중 방 로딩·좌표 변환·스트리밍)을 하나도 건드리지 않고도 "페이드 없이 옆방이 열리는 그림" 을 볼 수 있다.
2026-09-23 갱신: 여기에 **구역 문(`SectionGate`)** 을 더했다 — 닫혀 있는 동안 그 너머를 불투명 장막으로 가려 두었다가
W/↑ 로 열면 페이드 없이 저쪽 구역이 이쪽과 한 화면에 이어진다. 위 4번("닫힌 문 = 시야 차단")과 아래 2번의
"문에 자기 발광 요소(빨강=잠김 / 초록=열림)" 를 **한 방 안에서 먼저 구현해 본 것**이다.
구성·근거·한계와 성능 실측은 [`SPACE_TEST_SCENE.md`](SPACE_TEST_SCENE.md).
아래 계획은 **진짜 다중 방**(방 인스턴스를 여러 개 띄우는 것)을 위한 것이라 그대로 남긴다.

### 해야 할 일
1. **방 체인 정의** — `scripts/room_data.gd` 에 층/체인 개념 추가.
   - 각 방에 `floor`(층 id) 를 주고, 같은 층에서 `left_door`/`right_door` 로 이어진 방들을 하나의 체인으로 계산한다.
   - 체인 안에서 방의 **전역 x 오프셋**을 누적해서 구한다 (앞 방 width 합). 바닥선은 이미 전 방 공통(486)이라 y 는 그대로 쓸 수 있다.
   - `tools/validate_map.gd` 에 "좌우 문이 서로를 가리키는지 / 체인이 순환하지 않는지" 검사 추가.
2. **다중 방 로딩** — `main.gd` 를 "현재 방 하나" → "현재 체인의 활성 방 집합" 으로 바꾼다.
   - `Room` 인스턴스를 체인 오프셋 위치에 배치(`position.x = offset`)하고, 플레이어 좌표는 전역 좌표 하나로 통일한다.
   - 스트리밍: 현재 방 + 좌우 인접 1칸만 살려 두고 나머지는 해제. 방 경계를 넘는 순간 로드/언로드.
   - 방 내부의 x 기준 API(`npc_near` `sentry_near` `terminal_near` `front_door_near`)는 로컬 x 를 받으므로 전역↔로컬 변환 지점을 한 곳으로 모은다.
3. **문 개폐 상태를 런타임 상태로** — 지금 `left_door.open` 은 `RoomData` 의 정적 값이다.
   닫힘/열림을 런타임에서 바꿀 수 있게 하고(잠금·카드키·단말기 연동 여지), 닫힌 문은 옆방 렌더를 막는다.
4. **닫힌 문 = 시야 차단** — 닫힌 측벽문 위치에서 그 너머가 안 보이게 한다.
   `WallShadow` 가 이미 방 실루엣 밖을 덮고 있으므로, 닫힌 문 쪽만 실루엣을 닫아 두고 열릴 때 그 구간을 여는 식으로 재사용할 수 있다.
5. **카메라** — `game_camera.gd` 의 `set_room(width, SIDE_PAD)` 가 방 한 칸 폭에 갇혀 있다.
   체인 전체 범위(또는 활성 구간)를 한계로 받도록 바꾸고, 방 경계를 지날 때 한계가 튀지 않게 보간한다.
6. **몬스터/스폰** — 방 단위 스폰(`spawn.max`)이 인접 방에서도 계속 도는지, 비활성 방에서 멈추는지 규칙을 정한다.
   문이 열려 있으면 몬스터가 방을 넘어올 수 있는지도 결정 필요(현재는 방 안에 갇혀 있음).

### 결정해야 할 것
- 체인을 **선형(1차원)** 으로만 둘지, 층 안에 분기를 허용할지. 분기는 전역 오프셋 계산을 복잡하게 만든다 → 우선 선형만.
- 현재 27개 방 중 어떤 묶음을 같은 층으로 볼지 (`room_data.gd` 상단 맵 주석의 구역 구분과 층은 별개다).

---

## 2. 문이 있는지 없는지 구분되는 벽 가장자리

### 지금 상태
- `scripts/wall_shadow.gd` 가 방 실루엣 안쪽으로 그라데이션 어둠을 넣는다 (`FADE_SIDE` 60px, `EXP` 2.0).
- 측벽문 스프라이트(`_add_side_door`, `room.gd:633`)는 방 양끝 x=0 / x=width 에 붙는데, 바로 그 자리가 **가장 어두운 구간**이라
  열린 문(`sidewall_shutter_open_frame`)과 닫힌 문(`sidewall_shutter_closed_edge`), 그리고 아예 문이 없는 벽이 모두 똑같이 보인다.

### 해야 할 일
- 문 주변만 어둠을 면제(마스크 구멍)하거나, 문 스프라이트를 `WallShadow` 위 레이어로 올린다.
- 문 자체에 **자기 발광 요소**를 준다: 문틀 인디케이터 등(초록=열림 / 빨강=잠김), 문 안쪽에서 새어나오는 빛 웨지.
  힌트 문구에 이미 "측벽문(초록등)은 걸어서 통과" 라고 써 있으므로 그 초록등을 실제로 보이게 만드는 작업이다.
- 문이 **없는** 벽 끝은 지금처럼 어둠으로 닫아 둬서 "여긴 못 나간다" 가 바로 읽히게 한다.
- 1번의 "닫힌 문은 옆방을 가린다" 와 같은 코드 경로를 쓰므로 **1번과 함께 작업**하는 게 낫다.

---

## 3. 조명 프랍 구조 정리

### 지금 상태 — 세 갈래가 섞여 있다
| 갈래 | 정의 위치 | 스크립트 | 파괴 | 자산 |
|---|---|---|---|---|
| `lamps: [x, ...]` | `RoomData` | `lamp_light.gd` | **깨짐** (총격) | `assets/lights/pendant_lamp.png` (1개뿐) |
| `fixtures: [{file, x, cy/fy, radius, color}]` | `RoomData` | `room.gd:_build_fixtures` | 안 깨짐 | `assets/power_relay_room/Lighting/power_relay_*.png` (6종) |
| `fx: beacon` 등 | `RoomData` | `emergency_light.gd` | 별도 | 코드 생성 |

- 같은 "천장 조명" 인데 `lamps` 로 두면 깨지고 `fixtures.ceiling_lamp` 로 두면 안 깨진다. 방마다 제멋대로 섞여 있다.
- 조명 자산이 한 방(power_relay)용 폴더에 얹혀 있어 경로가 `POWER_RELAY_DIR + "Lighting/..."` 로 꼬여 있다.

### 목표 구조
1. **단일 진입점** — `lamps` 와 `fixtures` 를 하나의 `lights: [{kind, x, cy|fy, ...}]` 로 통합한다.
2. **`kind` 별 규칙을 코드 한 곳에 고정** — 종류마다 (깨짐 여부 / 반경 / 색 / 높이 / 매다는 기준)을 테이블로 둔다.
   - 깨지는 것: 펜던트 램프, 형광등 — 깨지면 그 구역이 어두워지는 **게임플레이 요소**.
   - 안 깨지는 것: 비상등·인디케이터 비콘·벽등 — 방의 **기본 밝기 바닥**을 담당. 여기까지 깨지면 방이 완전히 캄캄해진다.
   - 즉 "깨지는 조명은 연출 대비용, 안 깨지는 조명은 최소 시인성 보장" 으로 역할을 나눈다.
3. **자산 이동** — 조명 스프라이트를 `assets/lights/` 로 모으고 `power_relay_room/Lighting` 참조를 끊는다 (4번과 함께).
4. `tools/light_budget.gd` 로 방별 광원 수를 재검사 — `Lighting.split_by_depth` 로 층마다 PointLight2D 가 복제되므로 한도를 넘기기 쉽다.

---

## 4. 임시 배경 타일 · 프랍 자산 구조화

### 지금 상태
```
GodotPrototype/assets/
  tiles/           159  (테마별 타일 — RoomTheme 이 id 로 고른다)
  props/            89  (평평한 한 폴더 — 파일 이름 접두사로만 구분)
  power_relay_room/ 54  (Cables/Destruction/Lighting/Props/Tiles/Validation — 방 하나만 폴더 구조가 있음)
  connectors/        3  (정면문 1 + 측벽문 2)
  lights/            1
  normals/         319  (본체와 짝이 맞는지 보장 없음)
  character/       159
```
- 원본은 `Assets/GameReady/Native4/...` 와 `Assets/GameReady/<방이름>/...` 두 계열이 섞여 있고,
  Godot 쪽 `assets/` 는 그때그때 복사해 온 결과라 **원본↔런타임 대응이 문서화돼 있지 않다.**
- `props/` 가 평평해서 어떤 프랍이 어느 테마/방 소속인지 파일명 규칙에만 의존한다.
- `normals/` 가 본체와 1:1 인지 확인하는 수단이 없다 (없으면 조명이 밋밋해진다).

### 해야 할 일
1. **디렉터리 규약 확정** — `props/<theme>/<name>.png` 처럼 테마별로 나누고, 공용 프랍은 `props/common/` 에 둔다.
   `power_relay_room` 의 하위 구조(Props/Tiles/Lighting/Destruction)를 표준으로 삼아 다른 테마에도 적용.
2. **원본 → 런타임 동기화 스크립트** — `Assets/GameReady/...` 에서 `GodotPrototype/assets/...` 로 복사하는 절차를 `Tools/` 에 스크립트로 고정한다.
   지금은 수동 복사라 어느 쪽이 최신인지 알 수 없다.
3. **매니페스트** — `power_relay_room_manifest_v1.json` 같은 것을 테마마다 만들고, 코드가 하드코딩 경로 대신 매니페스트를 읽게 한다.
4. **노멀맵 짝 검사** — `assets/normals/` 에 본체와 짝이 없는 파일 / 본체만 있고 노멀이 없는 파일을 뽑는 검증 툴 추가.
5. **미사용 자산 정리** — 프로토타입 중 버려진 임시 타일·프랍을 찾아내 제거하거나 `_scratch/` 로 격리.
6. `RoomData` 의 `PROP_DIR` `CONNECTOR_DIR` `POWER_RELAY_DIR` `LIGHTS_DIR` 상수들이 새 규약을 따르도록 정리.

---

## 작업 순서 제안
0. **규격 정립(빠른 착수)** — 캐릭터·카메라 기준 측정 → 그레이박스 비교 → 소규모 아트 검증. 배경 타일·프랍의 본격 제작에 앞서 진행한다.
1. **2번(문 가독성)** 을 먼저 손보되 1번과 같은 코드(닫힌 문 = 시야 차단)를 건드리므로 **1번과 묶어서** 진행.
2. **1번(다방 구조)** — 가장 크고, 카메라·스폰·좌표계까지 영향이 간다. 먼저 `validate_map` 으로 체인 정의를 세우고 시작.
3. **3번(조명 정리)** — `RoomData` 스키마를 바꾸므로 1번의 스키마 변경과 같은 타이밍에 하면 마이그레이션이 한 번으로 끝난다.
4. **4번(자산 구조화)** — 3번의 자산 이동을 포함하므로 마지막에 한 번에.

## 참고 파일
- 맵 정의 · 스키마 주석: [scripts/room_data.gd](../GodotPrototype/scripts/room_data.gd)
- 방 조립: [scripts/room.gd](../GodotPrototype/scripts/room.gd) · [scripts/room_tiles.gd](../GodotPrototype/scripts/room_tiles.gd) · [scripts/room_solid.gd](../GodotPrototype/scripts/room_solid.gd)
- 방 전환 · 플레이 루프: [scripts/main.gd](../GodotPrototype/scripts/main.gd) · [scripts/main_game.gd](../GodotPrototype/scripts/main_game.gd)
- 벽 어둠: [scripts/wall_shadow.gd](../GodotPrototype/scripts/wall_shadow.gd)
- 조명: [scripts/lighting.gd](../GodotPrototype/scripts/lighting.gd) · [scripts/lamp_light.gd](../GodotPrototype/scripts/lamp_light.gd) · [scripts/emergency_light.gd](../GodotPrototype/scripts/emergency_light.gd)
- 검증 툴: [tools/validate_map.gd](../GodotPrototype/tools/validate_map.gd) · [tools/light_budget.gd](../GodotPrototype/tools/light_budget.gd)
