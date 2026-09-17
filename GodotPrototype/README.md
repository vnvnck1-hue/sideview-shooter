# 사이드뷰 작업실 방 이동 프로토타입 (Godot 4.7)

`Docs/RESOURCE_USAGE_GUIDE.md` 의 규칙대로 GameReady 타일·프랍·캐릭터를 조립해,
붉은 후드 정비공을 움직여 4개의 방을 오갈 수 있는 프로토타입이다. GDScript 로만 작성됐다.

## 실행

- 새 PC: `setup.bat` (Godot 설치) → `run.bat`. `run.bat` 은 설치된 Godot 을 자동으로 찾는다. 자세한 건 `SETUP.md`
- 또는 Godot 에디터에서 이 폴더의 `project.godot` 을 열고 F5

## 로비 (`scenes/Lobby.tscn`, 시작 씬)

마우스 버튼으로 고른다. 씬은 로비와 Main 두 개이고, 시작 방은 `scripts/app_flow.gd` 의 정적 값으로 넘긴다.

| 버튼 | 동작 |
|---|---|
| 방 드롭다운 | 아래 두 버튼이 쓰는 방. 타일맵 씬(`scenes/rooms/<방 id>.tscn`) 유무가 옆에 표시된다 |
| ▶ 게임 시작 | 고른 방에서 플레이 |
| ▦ 타일 씬 보기 | 고른 방의 타일 씬만 자유 카메라로 띄우는 뷰어(`scenes/TileViewer.tscn`). 휠 줌 · 휠클릭/WASD 이동 · G 격자 · L 옛 스트립 반투명 참고 · **R 디스크에서 다시 읽기**(Godot 에디터에서 저장한 직후 반영) |
| ✕ 종료 | 프로그램 종료 |

게임·뷰어 안에서는 **F1** 로 로비로 돌아온다. 실행 중인 게임 안에서 TileMap 을 찍는 기능은 Godot 에디터 전용이라 없다 — 편집은 에디터에서, 확인은 뷰어나 게임에서 한다.

## 조작

| 키 | 동작 |
|---|---|
| A / D, ← / → | 좌우 이동 최고 588px/s (840 에서 30% 감속). 가속 5200·감속 3600 px/s² 이징(출발·정지가 부드럽고 살짝 미끄러짐). 걷기 애니 속도는 실제 속도에 비례, 조준 반대로 걸으면 뒷걸음 역재생 |
| 마우스 | 조준 — 팔+총이 실시간으로 포인터를 가리키고, 머리(후드)도 목을 축으로 최대 ≈24° 안에서 포인터를 바라본다. 바라보는 방향도 포인터가 결정 |
| 좌클릭 (J) | 사격 — **누르고 있으면 연사**(0.09초 간격 ≈ 11발/초, 첫 발 즉발). **장탄 14발**, 비면 자동 재장전 1.15초(팔이 내려가 총을 흔듦, 우하단 HUD). 탄착점은 연사 열에 비례해 산탄(첫 발 0.012rad → 열 최대 0.067rad, 조준점도 벌어짐). **포인터 위치가 곧 탄착점**. 쏠 때마다 포인터가 실제로 사방으로 튀고(반동), 연사할수록 커진다 — 절반은 자동 복귀, 나머지는 직접 끌어내려야 한다. 총구→탄착점 한 줄 궤적이 찍히고 0.05초 안에 사라진다. 탄피가 뒤·위로 튀어 바닥에서 튕긴다 |
| Space | 구르기 — 이동 중이면 그 방향, 아니면 바라보는 방향. 0.30초 · ≈430px. 앞 42% 구간에서 느리고 부드럽게 가속해 정점(2720px/s)을 찍고 점점 느려진다(회전은 이동 거리에 비례). 끝나면 SPEED×0.85 의 관성이 남아 0.4초 동안 약한 감속(1500px/s²)으로 살짝 더 미끄러진다. 구르는 동안 사격 불가 |
| R | 수동 재장전 |
| P | (비교 중) 반동 프리셋 순환: 1 라이트 / 2 미디엄 / 3 헤비 (모두 튕김 없는 단발 펄스). 우상단 표시 |
| Ctrl (S / ↓) | 앉기 (홀드) — 앉은 채로 조준·사격 가능 |
| W / ↑ | 정면문 앞에서 다른 방으로 진입 |
| F1 | 로비로 돌아가기 |
| F11 | 전체화면 토글 |

## 모듈러 타일맵 — Godot 내장 룰타일(터레인 오토타일)로 방 배경 만들기

`Assets/GameReady/Tiles/Workshop_Modular` 의 128px 두 레이어 타일(배경 채움 6종 + 외곽 프레임 8종)을
Godot 에디터의 **TileMap 터레인(Terrains) 브러시**로 찍는다. 별도 툴 없이 Godot 표준 기능만 쓴다.

- TileSet: `tiles/workshop_modular_tileset.tres` — `tools/build_workshop_tileset.gd` 가 생성(재실행하면 덮어씀)
  - 터레인 세트 0 **배경 채움**: 소스 0, 채움 a~f. 피어링 비트 없음 + 같은 확률 → 찍을 때마다 무늬가 랜덤으로 섞인다
  - 터레인 세트 1 **프레임**: 소스 1, `workshop_modular_frame_terrain_3x3.png`(외곽 8조각 + 투명 내부 1칸). 빈 이웃 방향에 맞는 모서리·변이 자동으로 붙는다
  - 소스 2 **안쪽 모서리** 4종(`InnerCorners/`): 터레인 없이 **Tiles** 탭에서 수동 배치. 함께 들어온 `workshop_modular_ruletile_rules_v2.json` 은 Unity RuleTile 규격이라 Godot 터레인 이웃 패턴 대응은 정해지면 `build_workshop_tileset.gd` 에 비트만 추가하면 된다.
    단, 이 조각은 **벽 띠가 천장 띠를 지나 아래로 이어지는 T자** 모양이라 낮은 천장이 높은 벽과 만나는 곳에 놓으면 벽이 한 칸 튀어나와 보인다.
  - 소스 3 **L-벤드** 4종(`workshop_modular_frame_bend_sheet_4x1.png`): 오목 코너용. 벽 띠 × 천장(바닥) 띠가 겹치는 56×48 사각형만 남긴 조각으로, 위 셀의 벽이 천장 높이에서 멈추고 옆 셀의 천장으로 꺾인다.
    `tools/make_frame_bend_tiles.py`(Pillow) 가 프레임 3×3 시트에서 합성한다. 순서: top_left · top_right · bottom_left · bottom_right = 띠가 남는 사각형 위치. 검증 목업은 `Assets/GameReady/Validation/workshop_modular_bend_*_preview.png`
- 방 씬: `scenes/rooms/<방 id>.tscn` — 루트 `RoomTiles`(`scripts/room_tiles.gd`) 아래 `Background`·`Frame` TileMapLayer 두 개.
  `Room.build` 가 방 id 와 같은 이름의 씬이 있으면 인스턴스해서 옛 스트립 타일 위에 올린다. 예시로 `workshop.tscn`(16×4 셀)이 들어 있다.
- 루트 `position` 이 격자 원점. 기본 `(0, 24)`: 4행이 방 높이(560) 안에 들고 3번째 행 바닥 프레임의 밟는 띠 윗선이 바닥선(486)에 온다.
  층고를 높이려면 바닥 행은 그대로 두고 위로 행을 늘린다 — 원점 y = 408 − 128 × (행 수 − 1). 8행이면 `(0, -488)`.
- `RoomTiles.hide_legacy_tiles`(인스펙터 체크박스): 옛 560px 스트립을 숨기고 타일맵만 배경으로 쓴다. 바닥선·문·프랍 좌표는 `RoomData` 기준이고,
  방 폭은 `"width"`, 천장은 `"ceiling_y"` 키로 타일맵에 맞춰 준다(카메라 세로 중심·비상등 스윕·먼지 범위가 따라간다). 숨긴 스트립의 램프 위치는 그대로 쓰인다.
- **대형 정비 홀 `hall.tscn`** — 모듈러 타일맵만으로 그린 첫 방. 24×8 셀(3072×1024), 중앙 고층부 14×8 + 양 날개 5×5 의 성당형 실루엣.
  `tools/build_hall_room.gd` 가 만든다(`SHAPE` 사각형 합집합 → Frame 조각을 이웃 판정으로 직접 고르고, 날개 천장이 고층부 벽과 만나는 오목 코너 2곳에 소스 2 안쪽 모서리를 놓는다).
  다시 돌리면 덮어쓰므로 에디터에서 손본 뒤에는 실행하지 않는다. 격납고 오른쪽 측벽문으로 이어진다.

### 찍는 순서 (Godot 에디터)

1. `scenes/rooms/workshop.tscn` 을 열거나, 새 방이면 이 씬을 복제해 `<방 id>.tscn` 으로 저장한다 (id 는 `RoomData.ROOMS` 키).
2. `Background` 레이어 선택 → 하단 TileMap 패널 → **Terrains** 탭 → "배경 채움" → 방 전체 영역을 사각형(또는 붓)으로 채운다.
3. `Frame` 레이어 선택 → **Terrains** 탭 → "프레임" → 같은 영역을 채운다. 테두리 셀만 그려지고 안쪽은 투명 타일이다.
4. 문 자리 등 예외는 **Tiles** 탭에서 조각을 직접 놓거나 지운다(지우기: 우클릭).
5. 방은 2×2 셀 이상으로. 1칸 폭 기둥·1칸 높이 복도·외딴 1칸은 맞는 조각이 아트에 없어 빈 셀로 남는다.

TileSet 을 다시 만들 때:

```bash
godot --path GodotPrototype --headless --script res://tools/build_workshop_tileset.gd
```

## 확정 세팅

카메라 **표준**, 불 **잉걸·검은 연기**, 배경 라이팅 **그라데이션 필**, 림라이트 **부드러운 중간**(폭 15px, 외곽선에서 안쪽으로 스며듦). 프리셋 전환 키와 HUD 는 제거했고 데이터(`PRESETS`)와 `set_*` 함수만 개발용으로 남겨 두었다.

## 카메라 (`scripts/game_camera.gd`)

카메라는 플레이어를 고정 추적하지 않고 **마우스 포인터와 캐릭터 시선 방향으로 앞을 내다본다**.
목표 위치 = 플레이어 X + 시선 리드(바라보는 쪽 고정 거리) + 마우스 리드(화면 중심 대비 포인터 오프셋 × 가중치, 상한 클램프).
추적과 리드는 각각 지수 보간(follow_speed / look_speed)으로 따라간다. 화면보다 좁은 방은 방 가운데를 기준으로 두고 리드만 움직인다.
사격 흔들림(`add_shake`)도 이 노드가 관리한다. 값은 모두 월드 px(줌 0.5 → 가시 폭 3200px).

| 프리셋 | 마우스 가중치 / 상한 X·Y | 시선 리드 | 추적 / 리드 속도 | 데드존 | 느낌 |
|---|---|---|---|---|---|
| 1 안정형 | 0.10 / 110 · 0 | 60 | 5 / 2.5 | 90px | 캐릭터에 거의 붙어 천천히. 멀미 최소 |
| 2 표준 (기본) | 0.32 / 360 · 60 | 150 | 9 / 6 | 30px | 포인터 쪽으로 화면 1/3 정도 내다봄 |
| 3 민첩형 | 0.62 / 720 · 130 | 260 | 15 / 12 | 0 | 화면 절반 가까이, 즉각적·공격적 |

사격 연출: 총구 화염(shoot_03 에서 추출)·총구 라이트 + **절차적 연쇄 반동** — 팔(뒤로 16px·위로 0.16rad, 스프링 k900/감쇠30, 즉시) → 머리(0.03초 뒤, 뒤로 젖혀짐 0.13rad·4px, k380/17) → 몸통(0.05초 뒤, 뒤로 9px·기울기 0.045rad, k240/15). 세 부위가 다른 스프링으로 따로 흔들려 무게가 느껴진다 + 카메라 미세 흔들림 + 조준점 벌어짐 + 탄착(플래시·충격 링·불꽃 스파크 8·중력 받는 파편 8·라이트 — 벽/유리/프랍별 색과 양이 다름). **총구·궤적·탄착·피격 플래시·라이트는 모두 붉은 팔레트**(`Lighting.RED_*`, `GUN_LIGHT`, `IMPACT_LIGHT`)를 공유한다. 탄피만 황동색.
Idle/앉기 중에는 발을 고정한 채 몸 스케일이 2.6초 주기로 잔잔하게 숨쉰다.

## 라이팅

방마다 `CanvasModulate`(0.42, 0.43, 0.55 — 배경 색이 보이도록 0.26,0.28,0.40 에서 올림, `VFX_AMB` 환경변수로 실험 가능) 로 깔고, 타일 속 천장 램프 위치(`RoomData.TILE_LAMPS`: wall_b, wall_repeat)에 `LampLight`(PointLight2D, 반지름 560, energy 1.0, height 140) 를 단다. 램프는 미세하게 흔들리고 3~9초마다 0.2~0.55초 깜빡인다. 총구·탄착에도 짧은 PointLight2D 가 붙는다. 배경 밖은 완전한 검정.

램프는 **총으로 깨진다**: 전구 60px 안에 탄착하면 0.22초 글리치 셰이더로 지직거리며 꺼지고(그 뒤 0.35초 잔상), 전구 픽셀 위에 어두운 커버가 덮이며 유리 파편이 쏟아진다(`LampLight.break_lamp`).

## 표면 라이팅: 강한 노멀 반응 + 림라이트 + 열 잔광 (`lit_common.gdshaderinc`)

**림 도달 범위**: `light()` 에서 광원 텍스처 감쇠를 `pow(fall, rim_reach=0.4)` 로 펴서 림·프레넬에만 쓴다. 디퓨즈·스페큘러는 원래 감쇠 그대로라 광원 자체는 밝아지지 않고, 멀리 있는 사물의 외곽선만 광원 쪽으로 물든다 (빛의 공간감). 광원 텍스처 반경 밖은 여전히 림이 없다.

**바닥 조명**: 램프마다 바로 아래 바닥선에 납작한 풀 라이트(`LampLight.FloorPool`, 반경 400, 램프 밝기의 0.35, 램프와 함께 깜빡이고 깨지면 꺼짐) + 그라데이션 필 무드에 바닥선을 따라 700px 간격의 넓은 난색 바닥 라이트(energy 0.28).

림은 실루엣 폭 `rim_width_px` 안에서 8방향×3링 알파 커버리지로 부드럽게 계산하고 `rim_falloff` 지수로 예리함을 정한다(예전 1px 이웃 비교는 너무 얇고 예리했다). 프리셋 3종은 `Lighting.RIM_PRESETS`, `Lighting.shader_material` 이 만든 머티리얼을 WeakRef 로 기억해 `apply_rim_preset` 으로 한 번에 바꾼다. 타일(0)·파편(0.6)처럼 개별 앰비언트 림을 정한 머티리얼은 `rim_ambient_fixed` 메타로 보호.

타일·문·프랍·캐릭터(몸통·팔)·파편은 전부 `lit_surface` / `prop_surface` 셰이더로 그린다. 공용 코드는 `shaders/lit_common.gdshaderinc` 에 있고 `#include` 로 끌어온다.

- **노멀 강조**: `light()` 에서 `pow(N·L, normal_response=1.9)` 디퓨즈 + Blinn 스페큘러(`specular_power` 16). 램프·총구·탄착·비상등·불 라이트가 벽돌·리벳·프랍 모서리를 또렷하게 굴린다.
- **림라이트**: 실루엣(알파 경계)을 이웃 4점 샘플로 찾고, 바깥 방향을 `dFdx/dFdy` 야코비안으로 **화면 공간**으로 바꿔(플립·회전 보정) 광원을 향한 외곽선만 밝힌다. 광원이 없어도 우상단 고정 키(`rim_ambient`)로 외곽선이 은은하게 읽힌다(타일은 0). 노멀이 기울어진 면엔 프레넬 림.
- **열 잔광**: `HeatSurface` 가 머티리얼마다 탄착 UV 목록(`heat_hits[12]`: u, v, 세기, 경과)을 관리하고 `Main` 이 매 프레임 `tick_all` 로 시간을 올린다. 탄착점이 붉게(겹치면 흰 열) 달아올랐다가 `exp(-t/3.4s)` 로 식는다. 벽·문·프랍 모두.
- **캐릭터 노멀맵**: `Tools/build_normal_maps.py` 가 `assets/character/Split/**` 도 재귀 생성한다(`assets/normals/character/Split/...`). `Player` 는 프레임을 `Lighting.textured()` 로 읽는다.

## 환경 연출 (`RoomData.ROOMS[...]["fx"]`)

방 데이터의 `fx` 목록에 항목만 추가하면 `Room.build` 가 조립한다. 모두 공기층(Air, z 4: 프랍 앞·캐릭터 뒤)에 올라간다.

| 종류 | 데이터 | 구현 |
|---|---|---|
| 회전 비상등 `beacon` | `pos`(벽 좌표) | `EmergencyLight`. 하우징·붉은 돔(발광)을 `_draw`, 양방향 광선 텍스처(`Lighting.beam_texture`)를 단 `PointLight2D`(height 110) + 부채꼴 볼류메트릭 `Polygon2D`(`beacon_sweep.gdshader`, 방 사각형 밖은 클립)가 2.4rad/s 로 돈다. 광선이 정면을 스칠 때 돔·에너지가 가장 밝다. **맞으면 스파크를 뿌리며 지직거리다 꺼진다** |
| 새는 수도관 `leak` | `pos`(균열), `dir`(분사 방향), `pressure` | `WaterLeak`. 압력 맥동하는 물줄기(초당 75방울)가 포물선으로 떨어져 바닥에서 3~6개로 사방으로 튀고, 균열 주위엔 미세 분무. 착지점을 미리 시뮬레이션해 그 자리에 **물웅덩이**(`puddle.gdshader`: 흐르는 결 + 물방울마다 파문 고리, 45초 동안 넓어짐)를 깐다. 물방울은 한 노드가 `_draw` 로 그린다 |
| 끊긴 전선 `wire` | `pos`(천장 앵커), `length` | `BrokenWire`. 12 마디 **버렛 체인**(중력·감쇠·미풍, 제약 5회 반복, 바닥 통과 금지). 총알 궤적이 30px 안으로 스치면 그 방향으로 튀고, 탄착 240px 안이면 충격파로 밀리고(`apply_shot`), 플레이어가 지나가면 몸이 밀친다(`apply_body`, `Room._process`). 끝의 구리선에서 0.35~1.9초마다 **파란 아크**(지그재그 `Line2D`, 몇 프레임마다 갈아끼움) + 스파크 + `PointLight2D` 가 빠지직 튀고 방전 반동으로 끝이 살짝 튄다 |
| 불 `fire` | `pos`(바닥 중심), `size` | `FireSource`. 절차 불꽃 `Polygon2D`(`fire.gdshader`: fbm 노이즈, 4px 양자화, 4단계 포스터라이즈, 발광 배율 2.4로 심이 글로우), 일렁이는 주황 라이트(반지름 600, height 110, 노이즈 흔들림) + 심 라이트, 떠오르는 불티(`_draw`), 타는 잔해 더미, 뒤 벽 **그을음**(`soot.gdshader`, 곱셈). **연기**는 `GPUParticles2D` 64개: `CanvasTexture`(연기 뭉치 디퓨즈 + **반구 노멀맵**)를 달고 `smoke.gdshader` 의 `light()` 가 래핑 디퓨즈+가장자리 산란으로 **주변 광원(불·램프·비상등)에 부피감 있게 반응**한다. 위로 80~135px/s 로 올라가 감쇠하며 천장 아래 고인다 |

먼지 레이어(`DustLayer`)는 이제 램프뿐 아니라 `light_info()` 를 제공하는 비상등·불·전선 아크도 광원으로 받아 **그 색으로** 먼지를 비춘다(붉은 비상등이 스치면 먼지가 붉게 드러남). 어둠 속에서도 `ambient` 0.10 으로 희미하게 떠다니는 엠비언트 먼지 + 큰 느린 알갱이 층이 추가됐다.

전구 파손(`LampLight.break_lamp`)은 유리 파편에 더해 **뜨거운 스파크 30개**가 바닥으로 흩뿌려져 튕기고, 0.5초 동안 잔불이 흘러내린다(`SparkBurst`: 한 노드가 알갱이들을 `_draw`, 흰 열→붉은 열로 식음, 짧은 라이트).

> 4.7.2 메모: `ParticleProcessMaterial.turbulence` 는 2D 픽셀 스케일에서 속도를 0 으로 만들어 파티클이 제자리에 멈춘다. 연기는 turbulence 를 끄고 접선 가속으로 흐르게 했다.

## 비주얼 셰이더 (`shaders/`)

글로우는 `WorldEnvironment` 를 **LDR(HDR 2D 꺼짐)** 상태에서 임계값 0.85 로 잡는다 — 거의 흰 픽셀(전구·총구·스파크·피격 플래시 중심)만 번진다.
HDR 2D 도 시험했지만 2D 가 선형 색공간으로 섞이면서 어두운 채널이 눌려 기존 조명 톤이 깨져 되돌렸다. 덕분에 `CanvasModulate`·energy 수치는 이전과 같은 체감 밝기다.
라이트에는 `height`(램프 140, 총구·탄착 90) 를 줘서 노멀맵이 각도에 반응한다. height 가 있으면 램프 바로 밑이 더 밝아지므로 램프 energy 는 1.7 → 1.0 으로 낮춰 같은 밝기를 유지했다.
튜닝 환경변수: `VFX_AMB=r,g,b` `VFX_LAMP=에너지` `VFX_H=높이` (`Lighting` 의 static var 기본값을 덮는다).

| 효과 | 구현 | 위치 |
|---|---|---|
| 노멀맵 라이팅 | 타일·문·프랍을 `CanvasTexture`(diffuse + normal) 로 그린다. 노멀맵은 `assets/normals/<종류>/<이름>.png`, `python Tools/build_normal_maps.py` 로 재생성(밝기+알파 베벨 → Sobel, OpenGL Y+) | `Lighting.textured()` |
| 글로우 | `Environment.glow` (additive, 레벨 1~4, 임계 0.85, 세기 0.8). 발광체는 `modulate` 를 `Lighting.EMISSIVE(4.5)` / `EMISSIVE_SOFT(2.6)` 로 올려 CanvasModulate 를 이기고 흰색에 닿게 한다: 총구 화염, 탄 궤적·코어·탄두, 탄착 플래시·링·스파크 | `main.gd _setup_environment` |
| 전구 발광 + 글리치 | 타일에서 램프 영역을 `AtlasTexture` 로 잘라 같은 자리에 올린 `LampSprite`. 전구 픽셀만 `emit` 배율로 발광(CanvasModulate 역수 보정, 목표 휘도 1.7), 깜빡일 때 약하게·깨질 때 강하게 가로 찢김+스캔라인 | `lamp_glitch.gdshader` |
| 볼류메트릭 빛 기둥 | 전구 아래 → 바닥까지 사다리꼴 `Polygon2D`, 가산 블렌드. 노이즈가 천천히 흘러 먼지 낀 공기, 빛살 줄무늬. 램프 밝기(깜빡임·깨짐)에 연동. 사다리꼴은 UV 가 어파인 왜곡되므로 VERTEX 로 좌표를 직접 계산 | `light_cone.gdshader` |
| 부유 먼지 | 방 전체 `DustLayer`(Polygon2D). 4 층의 셀 그리드 먼지가 떠다니고, 어둠 속엔 희미하게(ambient), 광원(램프 원뿔·비상등·불·아크) 근처에선 그 색으로 밝게 | `dust.gdshader` |
| 표면 라이팅 | 타일·문·캐릭터·파편: 강한 노멀 반응 + 림라이트 + 열 잔광 (위 단락) | `lit_surface.gdshader` (+`lit_common.gdshaderinc`) |
| 프랍 표면 | lit_surface + **파츠 마스크**(깨진 셀 투명, 파단면 어둡게) + 붉은 피격 플래시 — `HitProp` 이 맞으면 **탄착점 반경 70px 만** 0.11초 붉게 번쩍. 탄착 PointLight2D(반지름 260, height 90)가 주변 노멀을 비춘다 | `prop_surface.gdshader` |
| 비상등 광선 | 회전 부채꼴 볼류메트릭, 거리·각도 감쇠, 방 밖 클립 | `beacon_sweep.gdshader` |
| 물웅덩이 | 반투명 물 + 흐르는 스페큘러 결 + 파문 고리 6개 | `puddle.gdshader` |
| 불꽃 | fbm 절차 불꽃, 4px 양자화, 4단계 포스터라이즈 | `fire.gdshader` |
| 연기 | 반구 노멀 + `light()` 래핑 디퓨즈 → 광원에 부피감 있게 반응, 알파 4단계 | `smoke.gdshader` |
| 그을음 | 불 뒤 벽 곱셈 어둡힘, 위로 옅어짐 | `soot.gdshader` |
| 창문 유리 + 균열 | `RoomData.TILE_WINDOWS`(wall_d, wall_d_mirror 의 환기창) 영역을 `GlassWindow` 로 올린다. 사선 하이라이트가 천천히 스치고, 맞으면 탄착점에서 방사형 금 9개+동심 고리가 퍼진다(발수록 누적). 탄착은 GLASS 파편 | `glass_window.gdshader` |
| 사격 색수차 + 비네트 | `CanvasLayer 9` 풀스크린 `ColorRect`. 사격마다 색수차 +2.2px(최대 6) 후 빠르게 감쇠, 정수 픽셀 스냅으로 픽셀이 뭉개지지 않음. 비네트 0.35 상시 | `post_fx.gdshader` |

레이어(z): 타일 0 → 램프 스프라이트·창문·그을음·비상등(Lights, 0) → 뒷벽 문 1 → 프랍·웅덩이·파편 2 → 빛 기둥·비상등 팬·불꽃·연기·물줄기·전선·먼지(Air, 4) → 캐릭터 5 → 탄 6 → 조준점 20. 후처리는 CanvasLayer 9, UI 는 10.

## 프랍 피격 반응

프랍은 `HitProp`. 축은 몸 중앙이 아니라 **총이 날아온 반대편 바닥 모서리**다. 맞으면 맞은 쪽이 딱 들리고(각속도 1.15rad/s, 각중력 22rad/s², 최대 0.085rad) 중력으로 떨어져 바닥에 '탁' 닿으며 작게 한 번 튕긴다. 반대편은 접지 마찰로 붙어 있고, 한 발마다 탄 방향으로 1.6px 씩 밀린다(접촉 그림자도 함께). 위쪽을 맞을수록 더 들린다. 캐비넷(+18px)·소파(+12px)는 이미지 하단 투명 여백만큼 내려 바닥선에 붙였다.

**파츠 파괴**: 프랍 텍스처를 26px 격자 셀로 나누고 셀마다 내구도를 둔다. 탄착점 44px 안의 셀에 피해가 누적돼(중심 0.78/발) 1.0 을 넘으면 마스크에서 사라지고(뒤의 벽이 보임, 파단면은 어둡게) 그 조각이 `ChunkDebris`(원본 `CanvasTexture` 의 `AtlasTexture` — 노멀맵·림 유지)로 탄 방향으로 날아가 회전하며 바닥에 떨어져 잔해로 남았다가 3.2초 뒤 사라진다. 한 발에 최대 4조각. 구멍이 난 자리를 다시 맞히면 총알은 통과해 뒤의 벽이 맞는다(`HitProp.is_solid_at`). 투명 비율 22% 미만인 셀은 조각으로 치지 않는다.

열린 측벽문(초록등)은 걸어서 그대로 통과한다. 닫힌 측벽문(주황등)은 벽으로 막힌다.

## 몬스터: 독성 종양 크롤러 (`scripts/crawler.gd`)

바닥을 기어다니는 몬스터. `RoomData.ROOMS[...]["monsters"]` 에 `{"type": "crawler", "x": 발 밑 X, "facing": ±1}` 를 적으면 `Room.build` 가 캐릭터와 같은 층(z 5)에 놓는다 (작업실 2 · 창고 2 · 격납고 6 · 숙소 2). 원본의 **40% 크기**(`Crawler.SCALE`, 60% 축소 — 플레이어 무릎 높이)로 그린다.

**지속 스폰**: 방마다 `"spawn": {"max": 살아 있는 최대 수, "interval": [최소, 최대 초]}` (기본 6마리 · 1.8~3.5초, 복도 4 · 2.5~4.5초, 격납고 12 · 1.3~2.5초). `Room._tick_spawner` 가 살아 있는 수가 max 미만이면 interval 마다 한 마리를 **플레이어에서 900px 이상 떨어진 자리**(8회 시도, 없으면 먼 쪽 끝)에 독액 방울과 함께 0.35초 페이드로 만든다(`Crawler.spawn_in`).

| 항목 | 값 |
|---|---|
| 리소스 | `assets/character/ToxicTumorCrawler/<clip>/<clip>_NN.png` (543×756 셀, 4프레임 × walk 8fps·jump 8·death 10·attack 10). `Tools/build_crawler_frames.py` 가 GameReady 원본을 복사하며 **프레임별 발 밑 줄**(walk 550 · attack 520 · death 578~589 · jump 610~626 — 클립마다 baseline 이 달라 셀 하단을 그대로 쓰면 튄다)과 내용 영역을 `crawler_meta.json` 에 적는다. 노멀맵은 `build_normal_maps.py character/ToxicTumorCrawler` |
| 체력 | 6발 (`MAX_HP`). 맞으면 탄착점 주변(텍스처 200px ≈ 월드 80px) 붉은 플래시(`prop_surface` 재사용) + 독액 방울 9개 + 초록 체액 7개가 탄 방향으로 + 탄 방향으로 26px 밀림 + **스케일 펀치**(1.30×0.72 로 눌렸다가 스프링 복귀) + 뒤 벽에 작은 체액 자국 |
| 쫀득함 | 발 밑을 축으로 한 **스케일 스프링**(`_squash`, k 210 · 감쇠 13). 걷기: 프레임 2장마다 x −5%·y +8% 바운스. 점프: 웅크림 1.18×0.80 → 도약 0.82×1.24 → 착지 1.34×0.68. 공격 예비 0.92×1.10, 뱉을 때 1.12×0.92 반동 |
| 이동 | 플레이어 쪽으로 270px/s 기어감(뒷걸음은 60%·역재생, 걷기 애니는 135px/s 기준 1배속이라 2배속으로 다리를 놀린다). 150px 앞에서 멈추고, 더 가까우면 물러난다. 착지·공격 뒤 0.35~0.9초 멈칫 |
| 점프 | 걷는 중 2.6~5.2초마다 시도. 플레이어가 260px 이상 떨어져 있으면 그쪽으로 300~560px 포물선(높이 110, 공중 0.62초). jump_01 웅크림 0.14초 → jump_02/03 공중 → jump_04 착지 0.18초 + 양옆 먼지 |
| 공격 | 720px 안이면 `attack` 재생, attack_03 프레임에서 입(`MOUTH_LOCAL`)으로 **독액 `AcidGlob`** 을 뱉는다(쿨다운 1.5~2.6초). 독액은 플레이어 몸 중심(이동 예측 포함)으로 0.55초 포물선. 맞으면 `Room.player_hit` → 카메라 흔들림 7·색수차·플레이어 480px/s 밀림(`Player.knockback`, **구르기 중이면 회피**). 바닥에 떨어지면 튀며 4.5초 독 웅덩이 |
| 죽음 | `death` 재생 + 1.55×0.55 펀치 + 독액 22개·**초록 체액 34개** 사방 분출(+짧은 라이트) + **육편 9조각**(`ChunkDebris` — 현재 프레임 텍스처를 90px 격자로 잘라 노멀맵째 **피격당한 쪽 반대편(탄 진행 방향) ±32° 부채꼴**로 날림, 바닥 튕김 후 3.2초 잔해) + **벽 체액 자국**(`BloodStain`, 탄 방향으로 길게 22방울 + 바닥선 8방울, 큰 방울은 1.5초 동안 흘러내림, 28초 뒤 페이드, 방당 최대 48개). 잔해(마지막 프레임)로 7초 남았다가 1.2초 페이드. 죽은 뒤엔 히트 박스가 꺼져 뒤의 벽이 맞는다 |
| 피격 판정 | `Room.hit_at` 이 몬스터를 맨 먼저 검사. 히트 박스는 **현재 프레임 내용 영역**(공중에선 함께 뜬다). 탄착은 `Bullet.Impact.FLESH`(불꽃 적고 어두운 살점) |

개발용: `AutoTest` 의 `aimm`(첫 살아 있는 몬스터 조준) · `mjump`(강제 점프) · `mattack`(강제 공격) 스텝으로 m0~m4 스크린샷을 찍는다.

## 방 연결

```
                 [숙소 Quarters]
                 정면문0      정면문1
                   ↕            ↕
[작업실 Workshop] ⇄ [복도 Corridor] ⇄ [창고 Storage] ⇄ [격납고 Hangar] ⇄ [대형 정비 홀 Hall]
   (측벽문)             (측벽문)             (측벽문)   폭 4416 — 카메라 스크롤   (측벽문)  3072×1024 — 모듈러 타일맵·높은 층고
```

## 구조

| 파일 | 역할 |
|---|---|
| `scripts/room_data.gd` | 방 정의 데이터(타일 순서, 프랍 좌표, 문 연결, 환경 연출 `fx`). 새 방은 여기에 항목만 추가 |
| `scripts/room.gd` | 데이터로 타일·문·프랍을 조립. 레이어 순서: 타일 → 뒷벽 문 → 프랍 → 캐릭터 → 투사체 |
| `scripts/player.gd` | 캐릭터. `BodyPivot/Body`(머리 없는 몸통 애니) + `BodyPivot/HeadPivot/Head`(목 기준 회전하는 후드+마스크, 프레임별 텍스처) + `ArmPivot/Arm·Muzzle·Flash`(어깨 기준 회전하는 팔+총). 상태 Roll > Crouch > Walk > Idle |
| `scripts/crawler.gd` | 몬스터 — 독성 종양 크롤러. 상태 IDLE/WALK/JUMP/ATTACK/DEAD, 프레임별 발 밑 보정, 히트 박스, 체력·피격·죽음 |
| `scripts/blood_stain.gd` | 벽면 초록 체액 자국 — 방울 무리 `_draw`, 흘러내림, 장기 잔존 후 페이드 |
| `scripts/acid_glob.gd` | 크롤러의 독액 — 포물선 비행, 플레이어 명중(구르기 회피)·바닥 웅덩이, `_draw` |
| `scripts/bullet.gd` | 고속 탄환(10400px/s) — 총구→목표점 Line2D 궤적, 목표점에 정확히 탄착 후 스파크·궤적 페이드 |
| `scripts/lighting.gd` | 라이트 공용 값·원형 감쇠 텍스처·노멀맵 `CanvasTexture`/셰이더 로더·발광 배율 |
| `scripts/lamp_light.gd` | 천장 램프 PointLight2D — 미세 흔들림 + 랜덤 깜빡임, 램프 스프라이트(발광·글리치)·빛 기둥 관리 |
| `scripts/glass_window.gd` | 타일 속 창문 유리 — 하이라이트, 피격 균열 |
| `scripts/dust_layer.gd` | 방 전체 엠비언트 먼지 레이어 (램프·비상등·불·아크 광원 색에 반응) |
| `scripts/hit_prop.gd` | 피격 시 들썩이는 프랍 + 파츠 파괴(셀 마스크·조각 방출) + 붉은 피격 플래시 + 열 잔광 |
| `scripts/heat_surface.gd` | 표면 열 잔광 관리자 (머티리얼별 탄착 UV 목록, `tick_all`) |
| `scripts/chunk_debris.gd` | 프랍에서 떨어진 조각 (중력·튕김·회전·잔해) |
| `scripts/spark_burst.gd` | 뜨거운 불꽃 알갱이 뭉치 (전구 파손·전선·비상등 공용, `_draw`) |
| `scripts/emergency_light.gd` | 회전 비상등 (광선 라이트 + 볼류메트릭 팬 + 돔, 파손) |
| `scripts/water_leak.gd` | 새는 수도관 (물줄기·튐·분무·웅덩이·파문) |
| `scripts/broken_wire.gd` | 끊긴 전선 (버렛 체인 물리, 총알·플레이어 반응, 아크 방전) |
| `scripts/fire_source.gd` | 불 (절차 불꽃·라이트·불티·잔해·그을음·부피감 연기 파티클). `STYLES` 3종 — 채도 낮춘 팔레트, 연기는 불의 붉은기로 시작해 검게 (`smoke.gdshader use_particle_color`) |
| `scripts/shell_casing.gd` | 탄피 — 중력·바닥 튕김·회전, 1.6초 후 페이드 |
| `scripts/crosshair.gd` | 마우스 위치의 조준점 (사격 시 벌어짐) |
| `scripts/mouse_recoil.gd` | 사격 반동을 실제 마우스 포인터에 적용 (`Viewport.warp_mouse`). 한 발 약 21px 사방 랜덤 방향(직전 방향과 60° 이상 벌림), 연사 heat 에 비례해 커지고 55% 는 자동 복귀. 포인터 잔떨림은 반올림 드리프트 때문에 두지 않음(카메라 흔들림·조준점 벌어짐이 담당) |
| `scripts/game_camera.gd` | 동적 카메라 — 플레이어 추적 + 마우스·시선 리드, 감도 프리셋 3종, 방 한계, 사격 흔들림 |
| `scripts/light_mood.gd` | 배경 라이팅 무드 프리셋 3종 (`PRESETS`, preload 로 사용) — 앰비언트 색 + 방 전체 보조 광원(채광 필 라이트 / LED 스트립·표시등·창문 외광). `Room.apply_mood` 가 얹는다 |
| `scripts/lobby.gd` / `scripts/app_flow.gd` / `scripts/tile_viewer.gd` | 로비 UI(마우스 버튼) / 씬 흐름·시작 방 전달 / 타일 씬 뷰어 |
| `scripts/room_tiles.gd` / `tools/build_workshop_tileset.gd` | 방 타일맵 씬 루트(라이팅 머티리얼·옛 스트립 숨김) / TileSet(터레인) 생성기 |
| `tools/build_hall_room.gd` / `tools/room_shot.gd` | 대형 정비 홀 타일맵 씬 생성기(실루엣 → Frame 조각·오목 코너 자동 선택) / 방 한 장 스크린샷 도구 (`--script res://tools/room_shot.gd -- <방 id> [main\|viewer] [프레임]`) |
| `scripts/main.gd` | 방 로딩·페이드 전환·카메라 프리셋 키 처리·HUD·입력 맵·마우스 → 월드 조준점·글로우 환경·후처리 |
| `scripts/auto_test.gd` | 개발용 자동 테스트. `AutoTest.tscn` 을 실행하면 입력을 시뮬레이션하고 `user://shots/` 에 스크린샷 저장 |

## 가이드 적용 사항

- **저해상도 픽셀아트 렌더링 (2026-09-17 전환)**: 월드는 `Main._setup_view` 가 만드는 534×300 `SubViewport`(Nearest · `snap_2d_transforms_to_pixel`) 에 그리고 `SubViewportContainer`(stretch_shrink 3, Nearest) 로 **정수 3배** 확대해 1600×900 창에 띄운다(1602×900, 좌우 1px 잘림). 카메라 zoom 0.25 → 가시 월드 2136×1200. **원본 4×4 픽셀 블록 = 뷰 1px = 화면 3px.** HUD(`UI` CanvasLayer)와 페이드는 바깥 풀해상도. 글로우 환경과 `PostFX` 는 SubViewport 안. `window/stretch/scale_mode=integer`. 이력: 800×450 ×2 → 534×300 ×3(4px 블록). 2026-09-18 에 8px 블록 ×6 "방식 B" 를 기존 그림의 수식 축소로 시험했다가 롤백 — 가는 요소가 뭉개져서, B 는 **네이티브 규격으로 직접 그린 자산**으로 간다(`Docs/ART_GUIDE.md` §10 규격·크기표).
  - **자산은 `Tools/bake_pixel_grid.py` 로 굽는다**: 각 4×4 블록(크롤러는 10×10 — scale 0.4)을 단색 하나(불투명 픽셀 평균에 가장 가까운 실제 색)로 채우고 알파를 다수결(50%)로 잘라 AA·잡티를 없앤다. 크기는 원본과 같아 타일셋·좌표는 그대로. 프랍·캐릭터는 블록 안 색 분산이 최소인 격자 오프셋을 찾고, 타일은 128px 이음새 때문에 오프셋 0. 멱등. **자산 파이프라인 순서**: `build_hooded_mechanic_split.py` → `build_hooded_mechanic_head_split.py` / `build_crawler_frames.py` → **`bake_pixel_grid.py`** → `build_normal_maps.py` → `godot --headless --import`.
  - 조명은 `Lighting.radial_texture` 가 CONSTANT 그라데이션 5단계 고리(ART_GUIDE "단계적 픽셀 클러스터"). 램프 풀·총구·탄착 라이트가 모두 공유한다.
  - 화면 px 상수는 **뷰 px(1/3)** 인지 **창 px** 인지 구분한다: 색수차(`ABERRATION_*`)·`post_fx` 는 뷰 px, 마우스 반동(`MouseRecoil.KICK_PX`)·카메라 `deadzone` 프리셋은 창 px(카메라가 `view_scale` 로 나눈다). 월드 px 로 그리는 것(조준점 `Crosshair`, 파편, 탄피)은 **4 의 배수**로 두어야 뷰 픽셀 한 칸에 맞는다.
  - 월드 → 창 좌표는 `Main.world_to_screen()` (AutoTest 마우스 워프가 쓴다). AutoTest 는 `user://shots/lo/` 에 534×300 원본도 저장한다. 카메라가 2배 시절보다 1.5배 가까워져 작업실도 살짝 스크롤하며, AutoTest 의 첫 `aimm` 사격(0.9초)은 크롤러가 화면 밖이라 빗나간다(이후 처치는 정상).
  - 아직 안 한 것: HUD 픽셀 폰트(안에 넣기), 크롤러 `crawler_meta.json` 발밑 줄 재측정(알파 컷으로 최대 10px 달라질 수 있음). 방식 B 전환 시: `VIEW_SIZE` 267×150 · `VIEW_SCALE` 6 · `CAMERA_ZOOM` 0.125 · `Crosshair` 상수 ×2 · 불 `pixel_step` ×2 · 색수차 절반 · bake 블록 8/20 (2026-09-18 시험에서 확인한 변경 목록).
- 리소스는 원본 픽셀 기준(타일 128px, 월드 좌표 = 원본 px), Nearest 필터, 밉맵 없음
- 타일: Bottom Left 피벗, 같은 Y, `X += 폭` 누적, 캡은 방 끝에만
- 바닥선: 타일 상단 기준 Y = 486 — 캐릭터·프랍 접지 기준
- 캐릭터: 320×320 Full Rect 프레임, 발 밑이 원점(Bottom Center), `flip_h` 로 왼쪽 방향

## 캐릭터 팔·총·머리 분리 리소스 (`assets/character/Split/`)

머리는 `Tools/build_hooded_mechanic_head_split.py` 가 몸통 프레임에서 목선(idle 기준 셀 좌표 175,172) 위를 잘라 `head/<clip>/<clip>_NN.png` 로 만들고 `split_meta.json` 에 `neck_from_pivot` 을 적는다. 목선 아래 후드 자락 28px 는 머리·몸통 양쪽에 중복시켜 머리가 기울어도 틈이 안 보인다. 빌드 순서: `build_hooded_mechanic_split.py` → `build_hooded_mechanic_head_split.py` → `build_normal_maps.py`.

`Tools/build_hooded_mechanic_split.py` 가 원본 프레임에서 자동 생성한다 (`python Tools/build_hooded_mechanic_split.py`).

| 파일 | 내용 |
|---|---|
| `arm_gun.png` | shoot_01 의 어깨 오른쪽 영역(팔+총). 어깨가 회전 원점, 총구 좌표는 `split_meta.json` |
| `muzzle_flash.png` | shoot_03 의 총구 화염만 색으로 추출 |
| `body/idle/idle_01.png` | shoot_01 에서 팔을 지운 조준 자세 몸통 (1프레임) |
| `body/walk/walk_0N.png` | 위 조준 몸통(상체, y<236) + 원본 walk 다리(하체) 합성. 걷기 상하 흔들림만큼 상체를 따라 올림 |
| `body/crouch/crouch_0N.png` | 원본 그대로. 팔은 오버레이 |
| `split_meta.json` | 프레임별 어깨 앵커(`shoulder_from_pivot`, 발 밑 기준·오른쪽 방향). 왼쪽은 X 부호 반전 |

왼쪽 조준 시 `ArmPivot.scale.y = -1` 로 팔 축 기준 상하 반전해 총이 뒤집히지 않는다. 원본 `Frames/` 는 레퍼런스로 남겨 두었다.
- 프랍 좌표는 `Validation/workshop_long_room_tile_prop_validation.json` 의 캔버스 좌표에서 roomOrigin(96,184) 을 뺀 값
