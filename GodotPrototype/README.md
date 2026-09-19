# 사이드뷰 작업실 방 이동 프로토타입 (Godot 4.7)

`Docs/RESOURCE_USAGE_GUIDE.md` 의 규칙대로 GameReady 모듈러 타일(5 테마)·프랍·캐릭터를 조립해,
붉은 후드 정비공을 움직여 **방 21개 · 구역 4개**의 맵을 탐색하는 프로토타입이다. GDScript 로만 작성됐다.

## 실행

- 새 PC: `setup.bat` (Godot 설치) → `run.bat`. `run.bat` 은 설치된 Godot 을 자동으로 찾는다. 자세한 건 `SETUP.md`
- 또는 Godot 에디터에서 이 폴더의 `project.godot` 을 열고 F5

## 로비 (`scenes/Lobby.tscn`, 시작 씬)

마우스 버튼으로 고른다. 시작 방은 `scripts/app_flow.gd` 의 정적 값으로 넘긴다.

| 버튼 | 동작 |
|---|---|
| ▶ 메인 게임 | `scenes/MainGame.tscn`(`scripts/main_game.gd`, `main.gd` 상속). **에어록**(`RoomData.START_ROOM`)에서 시작해 측벽문·정면문으로 전체 맵을 탐색한다. 우상단에 구역 · 몬스터 밀도(안전/적음/위험) · 탐색한 방 수 |
| ⚙ 테스트 — 랜덤한 방에서 시작 | `scenes/Main.tscn`. 방 하나를 무작위로 골라 바로 플레이 (원버튼) |
| ⌖ 센트리건 테스트 — 작업실에서 시작 | `scenes/Main.tscn` 을 **작업실**(`workshop`)에서 연다. 바닥 해치 옆에서 W/↑ 로 센트리건을 전개·조종한다 |
| ▦ 맵 뷰어 | `scenes/MapViewer.tscn`(`scripts/map_viewer.gd`). 방을 `Room.build` 로 통째로 조립해 자유 카메라로 본다. **[ ]** 이전/다음 방 · 휠 줌 · 휠클릭/WASD 이동 · F 방 전체 보기 · G 격자·문 표시 · L 전체 밝게 · R 다시 조립 |
| ✕ 종료 | 프로그램 종료 |

게임·뷰어 안에서는 **F1** 로 로비로 돌아온다.

## 조작

| 키 | 동작 |
|---|---|
| A / D, ← / → | 좌우 이동 최고 588px/s (840 에서 30% 감속). 가속 5200·감속 3600 px/s² 이징(출발·정지가 부드럽고 살짝 미끄러짐). 걷기 애니 속도는 실제 속도에 비례, 조준 반대로 걸으면 뒷걸음 역재생 |
| 마우스 | 조준 — 팔+총이 실시간으로 포인터를 가리키고, 머리(후드)도 목을 축으로 최대 ≈24° 안에서 포인터를 바라본다. 바라보는 방향도 포인터가 결정 |
| 좌클릭 (J) | 사격 — **누르고 있으면 연사**(0.09초 간격 ≈ 11발/초, 첫 발 즉발). **장탄 14발**, 비면 자동 재장전 1.15초(팔이 내려가 총을 흔듦, 우하단 HUD). 탄착점은 연사 열에 비례해 산탄(첫 발 0.012rad → 열 최대 0.067rad, 조준점도 벌어짐). **포인터 위치가 곧 탄착점**. 쏠 때마다 포인터가 실제로 사방으로 튀고(반동), 연사할수록 커진다 — 절반은 자동 복귀, 나머지는 직접 끌어내려야 한다. 총구→탄착점 한 줄 궤적이 찍히고 0.05초 안에 사라진다. 탄피가 뒤·위로 튀어 바닥에서 튕긴다 |
| Space | 구르기 — 이동 중이면 그 방향, 아니면 바라보는 방향. 0.30초 · ≈430px. 앞 42% 구간에서 느리고 부드럽게 가속해 정점(2720px/s)을 찍고 점점 느려진다(회전은 이동 거리에 비례). 끝나면 SPEED×0.85 의 관성이 남아 0.4초 동안 약한 감속(1500px/s²)으로 살짝 더 미끄러진다. 구르는 동안 사격 불가 |
| R | 수동 재장전 |
| F2 | (비교 중) **공간감 프리셋 A/B**: 1 이전(평면) ↔ 2 근경 분리(기본). 같은 방·위치에서 씬을 다시 로드한다. 우상단 표시 |
| F4 / Shift+F4 | **CRT 모니터 프리셋** 다음/이전 (모든 씬 공통, 기본 "아케이드 모니터"). 화면 위 토스트로 이름·설명 표시. 로비의 "CRT 모니터" 드롭다운으로도 선택. 아래 "CRT 모니터 후처리" 참고 |
| Ctrl (S / ↓) | 앉기 (홀드) — 앉은 채로 조준·사격 가능 |
| W / ↑ | 정면문 앞에서 다른 방으로 진입. **센트리건 옆에서는 센트리건 전개·조종(해제)** 이 먼저다 |
| F1 | 로비로 돌아가기 |
| F11 | 전체화면 토글 |

## 맵과 방 모양 — 데이터로 찍는 모듈러 타일맵

맵 전체는 `scripts/room_data.gd` 의 `ROOMS` 하나에 들어 있다. 방마다 **테마**와 **열 프로필**(`"shape": [[폭 셀, 높이 셀], ...]`, 128px 셀)을 적으면
`RoomTiles.build`(`scripts/room_tiles.gd`) 가 실행 중에 TileMapLayer 두 장(`Background` 채움 6종 랜덤 · `Frame` 외곽선)을 찍는다. 씬 파일·TileSet 파일은 없다.

- **열 프로필**: 바닥 행은 모든 열이 공유하고 위로 쌓인다. 높이 4 = 낮은 복도(천장 y 24) · 5 = 보통(-104) · 7 = 높은 방(-360) · 9 = 굴뚝·성당(-616).
  성당형(`[[5,5],[14,8],[5,5]]` 대형 정비 홀) · 계단형(격납고) · 굴뚝(창고) · H자(침실 B) · 피라미드(대형 재배실) · ㄱ자(축전기 저장고) 처럼 자유롭게.
  높이가 바뀌는 곳의 오목 코너에는 **L-벤드** 조각이 자동으로 들어간다. 같은 높이 구간은 2셀 이상(1칸 폭 기둥·1칸 높이 구간은 아트에 조각이 없다).
- **테마** (`scripts/room_theme.gd`): `workshop` · `corridor` · `hydroponics` · `crewquarters` · `power_relay`. 테마마다 시트 세 장 — 배경 3×2, 프레임 3×3(외곽 8조각 + 투명 내부), L-벤드 4×1 —
  을 `tools/build_theme_tile_sheets.py` 가 `Assets/GameReady` 낱장 PNG 에서 합성한다(GodotPrototype 폴더에서 `python tools/build_theme_tile_sheets.py`, 멱등).
  같은 스크립트가 옛 스트립 타일의 천장 램프를 잘라 `assets/lights/pendant_lamp.png`(+`.json` 전구 영역)을 만들고 수경재배·숙소 프랍을 `assets/props/` 로 복사한다.
  복사한 프랍은 저장소 루트에서 `python Tools/bake_pixel_grid.py` → `python Tools/build_normal_maps.py props` 로 굽는다.
- **방 키**: `left_door`/`right_door`(측벽문, 열림·목적지) · `front_doors`(뒷벽 정면문, 서로 가리켜야 함) · `props`(`{"tex", "x"}` 바닥 중심 — 접지 자동, `cy`/`fy` 로 벽걸이, `type` 으로 전력실 전용) ·
  `lamps`(펜던트 램프 x 목록 — 그 열 천장에 매달림, 총으로 깨짐) · `fixtures`(장식 조명: 전력실 Lighting 6종 + 색) · `fx`(비상등·누수·전선·케이블·불·고인 물, 위치는 `x` + `cy` 천장 기준) ·
  `monsters`/`spawn`(시작 배치·지속 스폰. `max` 0 = 없음, 2~5 = 적음, 9~14 = 위험). 자세한 설명은 `room_data.gd` 머리 주석.
- **벽은 실제로 막혀 있다** (`scripts/room_solid.gd`): 같은 열 프로필에서 충돌 기하(`RoomSolid`)를 뽑는다. 열린 공간은 열마다 위 = 천장 타일 상단 + 천장 띠(48),
  아래 = 바닥선, 좌우 = 막힌 이웃 열 경계에서 벽 띠(56) 안쪽 — 계단형 방의 단차 벽면도 포함하고, 그 밖(방 밖 어둠)은 전부 벽이다. 물리 노드는 쓰지 않는다(좌우 이동뿐인 사이드뷰라 기하 판정으로 충분).
  사격은 `Room.clip_shot` 이 선분을 벽면까지 잘라 **조준점이 벽 너머라도 탄은 벽에서 멈춘다**(총구가 벽 띠 안이어도 벽을 빠져나온 뒤부터 본다). 탄피·프랍 파편·불꽃은 벽에 튕기고, 독액은 벽에서 자국 없이 터진다.
- **벽 바깥 어둠** (`scripts/wall_shadow.gd`): 방 실루엣 밖을 검정으로 덮고 실루엣 안쪽으로 짧은 그라데이션(벽 60 · 천장 52 · 바닥 66px, 지수 2.0)을 넣는 층(z8, 근경 위, 라이트 받지 않음).
  방 모양에서 16px 텍셀 알파 텍스처를 구워 한 장으로 그린다. 이게 없으면 비상등 회전 광선·램프 빛·근경 실루엣이 벽 너머 검은 여백으로 새어나가 "벽 뒤에 공간이 있다" 처럼 보인다.
- **검사**: `godot --path . --headless --script res://tools/validate_map.gd` — 모양(조각 없는 셀), 문 연결(양방향), 정면문 위치, 프랍 벽 밖·겹침, 리소스 존재, 시작 방에서 전 방 도달, 테마·밀도 커버리지. 방마다 문자 지도를 찍는다.
- **스크린샷**: `godot --path . --script res://tools/map_shots.gd -- [bright|lit]` → `user://shots/map/<방 id>_<모드>.png` 방 21장. 한 방은 `tools/room_shot.gd -- <방 id> [main|game|viewer]`.

## 확정 세팅

카메라 **표준**, 불 **잉걸·검은 연기**, 배경 라이팅 **그라데이션 필**, 림라이트 **부드러운 중간**(폭 15px, 외곽선에서 안쪽으로 스며듦) + 도달 범위 **이전(좁음)**(HUD 1번 — 5종 비교 후 확정, 림이 광원 감쇠 곡선을 그대로 따름), **렌더 "베이크 자산 · 풀해상도"**(1600×900 ×1 · zoom 0.5 · 4px 블록 베이크 자산 · 부드러운 광원 · 스냅 없음 — 2026-09-18 5종 비교 후 확정, 나머지 프리셋과 `assets_original/` 폐기), **반동 "라이트 (단발 40px)"**(`Player.RECOIL`, 미디엄·헤비 폐기). 프리셋 전환 키와 HUD 는 제거했고 데이터(`PRESETS`)와 `set_*` 함수만 개발용으로 남겨 두었다.

비교 중인 것은 **공간감 프리셋**(F2, `scripts/depth_preset.gd`) 하나다 — 아래 "공간감: 층 분리" 참고.

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

방마다 `CanvasModulate`(0.42, 0.43, 0.55 — 배경 색이 보이도록 0.26,0.28,0.40 에서 올림, `VFX_AMB` 환경변수로 실험 가능) 로 깔고, 방 데이터 `lamps` 의 x 자리(그 열의 천장 띠 아래)에 펜던트 램프 `LampLight`(PointLight2D, 반지름 560, energy 1.0, height 140) 를 단다. 램프는 미세하게 흔들리고 3~9초마다 0.2~0.55초 깜빡인다. 총구·탄착에도 짧은 PointLight2D 가 붙는다. 배경 밖은 완전한 검정.

램프는 **총으로 깨진다**: 전구 60px 안에 탄착하면 0.22초 글리치 셰이더로 지직거리며 꺼지고(그 뒤 0.35초 잔상), 전구 픽셀 위에 어두운 커버가 덮이며 유리 파편이 쏟아진다(`LampLight.break_lamp`).

## 표면 라이팅: 강한 노멀 반응 + 림라이트 + 열 잔광 (`lit_common.gdshaderinc`)

**림 도달 범위 (확정 2026-09-18 — "이전 (좁음)", `Lighting.RIM`)**: 림은 광원 디퓨즈와 같은 감쇠 곡선으로 꺼진다(reach 0 · 반경 배율 1). Godot 의 `LIGHT_COLOR` 는 (라이트 색, 텍스처 알파 = 거리 감쇠)라 감쇠는 `.a` 에서 읽는다(`shaders/light_falloff.gdshaderinc`). F3 로 비교한 완만·넓게(×1.6)·아주 넓게(×2.2)·방 전체(×3) 프리셋은 폐기 — 결론은 림의 두께·범위가 아니라 **림 색의 블렌딩**이 어색함의 원인이라는 것.

**바닥 조명**: 램프마다 바로 아래 바닥선에 납작한 풀 라이트(`LampLight.FloorPool`, 반경 400, 램프 밝기의 0.35, 램프와 함께 깜빡이고 깨지면 꺼짐) + 그라데이션 필 무드에 바닥선을 따라 700px 간격의 넓은 난색 바닥 라이트(energy 0.28).

**림 색 블렌딩 (확정 2026-09-18 — "명도 계단 3단", `Lighting.RIM_BLEND`)**: 림의 두께·범위가 아니라 **색**이 어색함의 원인이었다. 원래 방식은 두 겹이 전부 덧셈 — ① 광원색 × mix(표면색, 흰색, 35~60%) ② 광원과 무관한 고정 키 파랑 (0.40, 0.50, 0.74) — 이고 그 위에 CanvasModulate 앰비언트 (0.42, 0.43, 0.55) 가 라이트 기여분까지 곱해져 따뜻한 램프 림도 푸르게 탈색됐다. 확정 방식은 **색**을 표면색 × 광원 휘도로 잡아 색상·채도를 유지하고(광원 색조는 25% 만), **세기**를 `mix(3단 계단, 연속, 0.28)` 로 섞는다 — 연속 성분이 바닥에 깔려 약한 빛에서도 림이 보이고 (`rim_cont` 가 평소 가시성), 계단 성분이 문턱 `rim_knee` 를 넘으면 외곽이 확 켜진다. 고정 키 림은 앰비언트 파생색 × 표면색. F3 로 비교한 7종(덧셈·흰색 / 앰비언트 보정 / 덧셈·표면색 / 스크린 / 명도 부스트 / 광원색 치환 / 팔레트)과 계단 변형 3종(2단 · 2단 하드 · 2단 연속 강조)은 폐기했다.

**캐릭터 림 (확정 2026-09-18 — "두껍게", `Lighting.CHAR_RIM`)**: 플레이어(몸·머리·팔)와 크롤러는 `Lighting.character_material()` 로 만든 머티리얼(`rim_character` 메타)이라 배경 값 위에 폭 24px · 감쇠 1.2 · 세기 1.8 · 흰색 60% · 고정 키 0.65 를 덮어쓴다. 폭은 플레이어 스케일 기준 텍스처 px 이고 크롤러(0.4 배)는 `rim_px_scale` 메타로 나눠 화면 두께를 맞춘다. 배경과 같음·굵고 선명·외곽선 강조 프리셋은 F4 비교 후 폐기.

림은 실루엣 폭 `rim_width_px` 안에서 8방향×3링 알파 커버리지로 부드럽게 계산하고 `rim_falloff` 지수로 예리함을 정한다(예전 1px 이웃 비교는 너무 얇고 예리했다). 값은 `Lighting.RIM`(배경)·`Lighting.CHAR_RIM`(캐릭터), `Lighting.shader_material` 이 만든 머티리얼을 WeakRef 로 기억해 `apply_rim_preset` 으로 한 번에 다시 적용한다. 타일(0)·파편(0.6)처럼 개별 앰비언트 림을 정한 머티리얼은 `rim_ambient_fixed` 메타로 보호.

타일·문·프랍·캐릭터(몸통·팔)·파편은 전부 `lit_surface` / `prop_surface` 셰이더로 그린다. 공용 코드는 `shaders/lit_common.gdshaderinc` 에 있고 `#include` 로 끌어온다.

- **노멀 강조**: `light()` 에서 `pow(N·L, normal_response=1.9)` 디퓨즈 + Blinn 스페큘러(`specular_power` 16). 램프·총구·탄착·비상등·불 라이트가 벽돌·리벳·프랍 모서리를 또렷하게 굴린다.
- **림라이트**: 실루엣(알파 경계)을 이웃 4점 샘플로 찾고, 바깥 방향을 `dFdx/dFdy` 야코비안으로 **화면 공간**으로 바꿔(플립·회전 보정) 광원을 향한 외곽선만 밝힌다. 광원이 없어도 우상단 고정 키(`rim_ambient`)로 외곽선이 은은하게 읽힌다(타일은 0). 노멀이 기울어진 면엔 프레넬 림.
- **열 잔광**: `HeatSurface` 가 머티리얼마다 탄착 UV 목록(`heat_hits[12]`: u, v, 세기, 경과)을 관리하고 `Main` 이 매 프레임 `tick_all` 로 시간을 올린다. 탄착점이 붉게(겹치면 흰 열) 달아올랐다가 `exp(-t/3.4s)` 로 식는다. 벽·문·프랍 모두.
- **캐릭터 노멀맵**: `Tools/build_normal_maps.py` 가 `assets/character/Split/**` 도 재귀 생성한다(`assets/normals/character/Split/...`). `Player` 는 프레임을 `Lighting.textured()` 로 읽는다.

## 환경 연출 (`RoomData.ROOMS[...]["fx"]`)

방 데이터의 `fx` 목록에 항목만 추가하면 `Room.build` 가 조립한다. 모두 공기층(Air, z 4: 프랍 앞·캐릭터 뒤)에 올라간다. 부유 먼지는 근경 분리 프리셋에서 z 3(프랍 앞·빛 기둥 뒤)로 내려간다.

| 종류 | 데이터 | 구현 |
|---|---|---|
| 회전 비상등 `beacon` | `pos`(벽 좌표) | `EmergencyLight`. 하우징·붉은 돔(발광)을 `_draw`, 양방향 광선 텍스처(`Lighting.beam_texture`)를 단 `PointLight2D`(height 110) + 부채꼴 볼류메트릭 `Polygon2D`(`beacon_sweep.gdshader`, 방 사각형 밖은 클립)가 2.4rad/s 로 돈다. 광선이 정면을 스칠 때 돔·에너지가 가장 밝다. **맞으면 스파크를 뿌리며 지직거리다 꺼진다** |
| 새는 수도관 `leak` | `pos`(균열), `dir`(분사 방향), `pressure` | `WaterLeak`. 압력 맥동하는 물줄기(초당 75방울)가 포물선으로 떨어져 바닥에서 3~6개로 사방으로 튀고, 균열 주위엔 미세 분무. 착지점을 미리 시뮬레이션해 그 자리에 **물웅덩이**(`puddle.gdshader`: 흐르는 결 + 물방울마다 파문 고리, 45초 동안 넓어짐)를 깐다. 물방울은 한 노드가 `_draw` 로 그린다 |
| 끊긴 전선 `wire` | `pos`(천장 앵커), `length` | `BrokenWire`. 12 마디 **버렛 체인**(중력·감쇠·미풍, 제약 5회 반복, 바닥 통과 금지). 총알 궤적이 30px 안으로 스치면 그 방향으로 튀고, 탄착 240px 안이면 충격파로 밀리고(`apply_shot`), 플레이어가 지나가면 몸이 밀친다(`apply_body`, `Room._process`). 끝의 구리선에서 0.35~1.9초마다 **파란 아크**(지그재그 `Line2D`, 몇 프레임마다 갈아끼움) + 스파크 + `PointLight2D` 가 빠지직 튀고 방전 반동으로 끝이 살짝 튄다 |
| 불 `fire` | `pos`(바닥 중심), `size` | `FireSource`. 절차 불꽃 `Polygon2D`(`fire.gdshader`: fbm 노이즈, 4px 양자화, 4단계 포스터라이즈, 발광 배율 2.4로 심이 글로우), 일렁이는 주황 라이트(반지름 600, height 110, 노이즈 흔들림) + 심 라이트, 떠오르는 불티(`_draw`), 타는 잔해 더미, 뒤 벽 **그을음**(`soot.gdshader`, 곱셈). **연기**는 `GPUParticles2D` 64개: `CanvasTexture`(연기 뭉치 디퓨즈 + **반구 노멀맵**)를 달고 `smoke.gdshader` 의 `light()` 가 래핑 디퓨즈+가장자리 산란으로 **주변 광원(불·램프·비상등)에 부피감 있게 반응**한다. 위로 80~135px/s 로 올라가 감쇠하며 천장 아래 고인다 |
| 고인 물 `water` | `level`(수면선이 바닥선 위로 올라오는 px, 기본 26), `x0`/`x1`(선택 범위), `tint`(선택) | `WaterPool`. 수면선 아래 방 전체를 덮는 `Polygon2D` 하나에 `water_surface.gdshader`. **스크린 텍스처 반사**(`hint_screen_texture`, 이미 그려진 화면을 수면선 기준으로 뒤집어 샘플) + 물속 굴절(정수 뷰픽셀 좌우 흔들림, 4단계 포스터라이즈) + 수면선 1px 하이라이트 + `light()` 로 램프·비상등이 결 마스크를 따라 길게 비침. 인물·몬스터가 비쳐야 하므로 **인물 층 위(z6)** 에 올린다 — 발목 아래는 물에 잠겨 보인다. 수면선→화면 거리는 varying 의 `dFdy` 로 구해 카메라 줌·렌더 프리셋에 무관. CanvasModulate 로 두 번 어두워지는 반사상은 `ambient_inv`×`reflect_gain` 으로 되살린다. **스프링 수면**: 4px 간격 스프링 열(Hoffman, 60Hz 고정 스텝)의 높이를 N×1 RF 텍스처로 넘겨 수면선이 픽셀 단위로 오르내리고 기울기가 반사를 흔든다. 총알 착수·탄피·파편·수도관 물방울은 `splash`/`disturb`, 플레이어가 걸으면 `wake`. **총알 착수**(`bullet_splash`): 수면을 깊게 누르고 양옆을 들어 왕관 모양으로 되튀게 해 큰 파동이 멀리 가고, 4px 블록 물기둥(중심 1 + 옆 1~2, 총알 방향으로 기울음) + 흰 심 물방울 10 + 잔방울 22 + 좌우로 퍼지는 수면 물보라 점선. 총알은 `Bullet.Impact.WATER`(청백 납작 플래시·물색 라이트, 불꽃·파편 없음). 검증: `tools/water_shot.gd`(저수조실에서 빈 수면에 한 발 쏘고 N 프레임 뒤 저장). 다른 노드는 정적 `WaterPool.active` 로 찾는다. 로비 **테스트** 버튼이 물이 고인 저수조실(`RoomData.TEST_ROOM`)에서 시작한다. 다음 후보는 메타볼 체액 |

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
| 고인 물 수면 | 스크린 텍스처 반사(수면선 기준 뒤집기) + 정수 픽셀 굴절 + 수면선 하이라이트 + `light()` 스페큘러 결 | `water_surface.gdshader` |
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

## 센트리건 (`scripts/sentry_turret.gd`)

바닥 격납형 거치 화기. `RoomData.ROOMS[...]["props"]` 에 `{"type": "sentry", "x": 바닥 중심}` 을 적으면 `Room.build` 가 놓는다 (작업실 1230 · 격납고 3495). 평소엔 바닥과 같은 높이의 해치로 묻혀 있고, 옆에 서서 **W / ↑** 를 누르면 솟아오른다.

| 단계 | 내용 |
|---|---|
| 전개 | `sentry_turret_deploy_direct_v1_sheet` 8프레임 10fps (해치 열림 → 하부 상승 → 머리 세움 → 포신 전개). 시작·끝에 바닥 먼지(`CPUParticles2D`)·불꽃(`SparkBurst`)·카메라 흔들림 6.0/3.5. 끝나면 기동시킨 사람이 그대로 조종을 잡는다 |
| 조준 | 마지막 프레임을 **머리(포신 어셈블리 + 급탄 호스)** 와 **받침(요동 실린더 · 기둥 · 해치 꽃잎)** 으로 분리해 머리만 요동축에서 부앙한다. 한계 ±0.45rad(≈26°), 보간 16/s. 좌우는 전체를 x 반전 — 호스가 항상 포신 반대쪽에 온다. 머리를 받침 **뒤**에 그려 분리 단면이 실린더에 가린다 |
| 사격 | 좌클릭 홀드 — 위·아래 포신이 **번갈아** 0.11초 간격(≈9발/초). 탄띠 48발, 비면 2.1초 급탄(우하단 HUD). 산탄 0.016rad. 탄·탄착·벽 클리핑은 플레이어 사격과 같은 경로(`Main._spawn_shot`), 카메라 흔들림만 5.2 로 더 묵직하다. 포신은 2차 스프링으로 최대 16px 후퇴 |
| 발사 VFX | `MuzzleBlast` — 십자 섬광 → 화염 원뿔 + 잎 3~4장 + 흰 심(가산 블렌드, 글로우 임계 초과) · 총구 연기(월드 좌표, 0.22초마다) · 화약 불꽃 · 0.075초 `PointLight2D`. 탄피는 플레이어와 같은 `ShellCasing` |
| 대기·격납 | 조종을 놓으면 천천히 좌우를 훑다가 14초 뒤 해치 안으로 접힌다(역재생). 광학 조준경의 호박색 라이트는 대기 0.45 · 조종 중 1.5 |

조종 중에는 플레이어 입력이 꺼지고(이동·사격·구르기 없음) 같은 마우스가 포신을 끈다. **W / ↑** 를 다시 누르면 놓는다. 방을 떠나면 자동으로 풀린다.

**자산**: `Tools/build_sentry_turret_parts.py` 가 원본 시트(4×2 · 416×468)를 프레임마다 **접지선·받침 중심**에 맞춰 정렬하고(원본은 프레임마다 중심이 218 → 190px 로 흘러 그대로 쓰면 전개 중 떨린다), 마지막 프레임을 머리/받침으로 갈라 `assets/props/defense/sentry/` 에 저장한다(`sentry_turret.json` 에 앵커·요동축·총구·배출구). 노멀맵은 `python Tools/build_normal_maps.py props`. 확인용 스크린샷: `godot --path . --script res://tools/sentry_shot.gd`

## 몬스터: 독성 종양 크롤러 (`scripts/crawler.gd`)

바닥을 기어다니는 몬스터. `RoomData.ROOMS[...]["monsters"]` 에 `{"type": "crawler", "x": 발 밑 X, "facing": ±1}` 를 적으면 `Room.build` 가 캐릭터와 같은 층(z 5)에 놓는다 (작업실 2 · 창고 2 · 격납고 6 · 숙소 2). 원본의 **40% 크기**(`Crawler.SCALE`, 60% 축소 — 플레이어 무릎 높이)로 그린다.

**지속 스폰**: 방마다 `"spawn": {"max": 살아 있는 최대 수, "interval": [최소, 최대 초]}` (기본 6마리 · 1.8~3.5초, 복도 4 · 2.5~4.5초, 격납고 12 · 1.3~2.5초). `Room._tick_spawner` 가 살아 있는 수가 max 미만이면 interval 마다 한 마리를 **플레이어에서 900px 이상 떨어진 자리**(8회 시도, 없으면 먼 쪽 끝)에 독액 방울과 함께 0.35초 페이드로 만든다(`Crawler.spawn_in`).

| 항목 | 값 |
|---|---|
| 리소스 | `assets/character/ToxicTumorCrawler/<clip>/<clip>_NN.png` (543×756 셀, 4프레임 × walk 8fps·jump 8·death 10·attack 10·roar 8). `Tools/build_crawler_frames.py` 가 GameReady 원본을 복사하며 **프레임별 발 밑 줄**(walk 550 · attack 520 · death 578~589 · jump 610~626 · roar 629 — 클립마다 baseline 이 달라 셀 하단을 그대로 쓰면 튄다)과 내용 영역을 `crawler_meta.json` 에 적는다. 노멀맵은 `build_normal_maps.py character/ToxicTumorCrawler` |
| 체력 | 6발 (`MAX_HP`). 맞으면 탄착점 주변(텍스처 200px ≈ 월드 80px) 붉은 플래시(`prop_surface` 재사용) + 독액 방울 9개 + 초록 체액 7개가 탄 방향으로 + 탄 방향으로 26px 밀림 + **스케일 펀치**(1.30×0.72 로 눌렸다가 스프링 복귀) + 뒤 벽에 작은 체액 자국 |
| 쫀득함 | 발 밑을 축으로 한 **스케일 스프링**(`_squash`, k 210 · 감쇠 13). 걷기: 프레임 2장마다 x −5%·y +8% 바운스. 점프: 웅크림 1.18×0.80 → 도약 0.82×1.24 → 착지 1.34×0.68. 공격 예비 0.92×1.10, 뱉을 때 1.12×0.92 반동 |
| 이동 | 플레이어 쪽으로 270px/s 기어감(뒷걸음은 60%·역재생, 걷기 애니는 135px/s 기준 1배속이라 2배속으로 다리를 놀린다). 150px 앞에서 멈추고, 더 가까우면 물러난다. 착지·공격 뒤 0.35~0.9초 멈칫 |
| 포효 | 걷는 중 7~14초마다 시도(플레이어가 220px 이상 떨어져 있을 때만) + 스폰 직후 45% 확률로 등장 포효. `roar` 재생 — 시작 1.10×0.90 웅크림, 입을 가장 크게 벌린 roar_03 에서 0.38초 **멈춰 몸을 떨며**(0.90×1.14 늘어남 + 스케일 지터) 이어서 재생. roar_02·03 으로 넘어갈 때 입(`ROAR_MOUTH`, 프레임별 위치)에서 **침 4·7방울**, 유지 중엔 0.045초마다 1방울씩 샌다(`SparkBurst` 재사용, 거의 흰 연두색 · 발광 0.45 로 독액보다 둔함). 900px 안이면 카메라가 거리 반비례로 0.4~2.2 울린다(`Crawler.roared` → `Room.monster_roared` → `Main`). 포효 중에도 맞는다. 끝나면 0.28~0.72초 멈칫 |
| 점프 | 걷는 중 2.6~5.2초마다 시도. 플레이어가 260px 이상 떨어져 있으면 그쪽으로 300~560px 포물선(높이 110, 공중 0.62초). jump_01 웅크림 0.14초 → jump_02/03 공중 → jump_04 착지 0.18초 + 양옆 먼지 |
| 공격 | 720px 안이면 `attack` 재생, attack_03 프레임에서 입(`MOUTH_LOCAL`)으로 **독액 `AcidGlob`** 을 뱉는다(쿨다운 1.5~2.6초). 독액은 플레이어 몸 중심(이동 예측 포함)으로 0.55초 포물선. 맞으면 `Room.player_hit` → 카메라 흔들림 7·색수차·플레이어 480px/s 밀림(`Player.knockback`, **구르기 중이면 회피**). 바닥에 떨어지면 튀며 4.5초 독 웅덩이 |
| 죽음 | `death` 재생 + 1.55×0.55 펀치 + 독액 22개·**초록 체액 34개** 사방 분출(+짧은 라이트) + **육편 9조각**(`ChunkDebris` — 현재 프레임 텍스처를 90px 격자로 잘라 노멀맵째 **피격당한 쪽 반대편(탄 진행 방향) ±32° 부채꼴**로 날림, 바닥 튕김 후 3.2초 잔해) + **벽 체액 자국**(`BloodStain`, 탄 방향으로 길게 22방울 + 바닥선 8방울, 큰 방울은 1.5초 동안 흘러내림, 28초 뒤 페이드, 방당 최대 48개). 잔해(마지막 프레임)로 7초 남았다가 1.2초 페이드. 죽은 뒤엔 히트 박스가 꺼져 뒤의 벽이 맞는다 |
| 피격 판정 | `Room.hit_at` 이 몬스터를 맨 먼저 검사. 히트 박스는 **현재 프레임 내용 영역**(공중에선 함께 뜬다). 탄착은 `Bullet.Impact.FLESH`(불꽃 적고 어두운 살점) |

개발용: `AutoTest` 의 `aimm`(첫 살아 있는 몬스터 조준) · `mjump`(강제 점프) · `mattack`(강제 공격) · `mroar`(강제 포효 — 공격 중이면 끊는다) 스텝으로 m0~m5 스크린샷을 찍는다.

## 맵 (방 21개 · 구역 4개)

측벽문 ⇄ 은 같은 평면에서 걸어서 통과, 정면문 ↕ 은 뒷벽 문 앞에서 W 로 진입. 시작은 **에어록**.

```
정비 구역     [에어록] ⇄ [서쪽 통로] ⇄ [작업실] ⇄ [대형 정비 홀] ⇄ [짧은 통로] ⇄ [격납고] ⇄ [창고]
  workshop     7×5 안전    18×4 적음    14×5/7 적음   24×5/8/5 위험    5×4 안전    32×9→5 위험  13×4+9 적음
                              ↕                          ↕                          ↕            ↕
승무원 구역   [침실 A] ⇄ [숙소 복도] ⇄ [침실 B] ⇄ [식당·휴게실] ⇄ [세면실]          │            │
  crew         9×5 안전   14×4 적음   14×6/4/6 적음  18×5/7/5 위험   7×4 적음(물)   │            │
                              ↕                          ↕                          │            │
전력 구역     [케이블 덕트] ⇄ [전력 릴레이실] ⇄ [축전기 저장고] ⇄ [비상 발전실]      │            │
  power_relay  16×4 적음       14×8 적음        14×9/5 위험        9×5 안전         │            │
                                                                                    ↕            ↕
수경재배 구역 [재배실 전실] ⇄ [대형 재배실] ⇄ [급수 통로] ⇄ [저수조실] ⇄ [육묘실]
  hydroponics  7×5 안전       30×5…9…5 위험    15×4/6/4 적음  12×6 적음(물)  9×5 안전
```

몬스터 없는 방 6 · 적음 10 · 위험 5. 방 모양·연결·프랍·조명은 `scripts/room_data.gd`, 검사는 `tools/validate_map.gd`.

## 구조

| 파일 | 역할 |
|---|---|
| `scripts/room_data.gd` | 전체 맵 데이터 — 방 21개의 테마·열 프로필(모양)·문 연결·프랍·램프·조명 기구·환경 연출 `fx`·몬스터 밀도. 새 방은 여기에 항목만 추가 |
| `scripts/room_theme.gd` / `scripts/room_tiles.gd` | 테마 표 + 실행 중 TileSet 캐시 / 열 프로필 → 타일맵(프레임 조각 이웃 판정, L-벤드, 조각 없는 셀 검사, 문자 지도) |
| `scripts/room_solid.gd` | 방의 벽 충돌 기하 — 열 프로필 → 열린 공간(천장 띠·바닥선·벽 띠·단차 벽면). `is_solid` · `clip_ray`(사격) · `confine`/`bounce_walls`(탄피·파편·불꽃·독액). `RoomSolid.active` 로 현재 방 참조 |
| `scripts/wall_shadow.gd` | 벽 바깥 어둠 층(z8) — 방 모양에서 구운 알파 그라데이션 + 그 바깥 검은 여백. 빛·근경이 벽 너머로 새지 않게 한다 |
| `scripts/room.gd` | 데이터로 타일맵·펜던트 램프·조명 기구·문·프랍(접지 자동)·fx 를 조립. 레이어 순서: 타일 → 뒷벽 문 → 프랍 → 캐릭터 → 투사체 |
| `scripts/player.gd` | 캐릭터. `BodyPivot/Body`(머리 없는 몸통 애니) + `BodyPivot/HeadPivot/Head`(목 기준 회전하는 후드+마스크, 프레임별 텍스처) + `ArmPivot/Arm·Muzzle·Flash`(어깨 기준 회전하는 팔+총). 상태 Roll > Crouch > Walk > Idle |
| `scripts/crawler.gd` | 몬스터 — 독성 종양 크롤러. 상태 IDLE/WALK/JUMP/ATTACK/DEAD, 프레임별 발 밑 보정, 히트 박스, 체력·피격·죽음 |
| `scripts/blood_stain.gd` | 벽면 초록 체액 자국 — 방울 무리 `_draw`, 흘러내림, 장기 잔존 후 페이드 |
| `scripts/acid_glob.gd` | 크롤러의 독액 — 포물선 비행, 플레이어 명중(구르기 회피)·바닥 웅덩이, `_draw` |
| `scripts/bullet.gd` | 고속 탄환(10400px/s) — 총구→목표점 Line2D 궤적, 목표점에 정확히 탄착 후 스파크·궤적 페이드 |
| `scripts/lighting.gd` | 라이트 공용 값·원형 감쇠 텍스처·노멀맵 `CanvasTexture`/셰이더 로더·발광 배율 |
| `scripts/lamp_light.gd` | 천장 펜던트 램프(`assets/lights/pendant_lamp.png`) PointLight2D — 미세 흔들림 + 랜덤 깜빡임, 램프 스프라이트(발광·글리치)·빛 기둥·바닥 풀 관리. 근경 분리 시 배경 층 전용 + 인물 층 거울 라이트 |
| `scripts/glass_window.gd` | 창문 유리 — 하이라이트, 피격 균열 (창문 타일이 있던 옛 스트립용. 모듈러 방에는 아직 창문이 없어 미사용) |
| `scripts/dust_layer.gd` | 방 전체 엠비언트 먼지 레이어 (램프·비상등·불·아크 광원 색에 반응) |
| `scripts/hit_prop.gd` | 피격 시 들썩이는 프랍 + 파츠 파괴(셀 마스크·조각 방출) + 붉은 피격 플래시 + 열 잔광 |
| `scripts/heat_surface.gd` | 표면 열 잔광 관리자 (머티리얼별 탄착 UV 목록, `tick_all`) |
| `scripts/chunk_debris.gd` | 프랍에서 떨어진 조각 (중력·튕김·회전·잔해) |
| `scripts/spark_burst.gd` | 뜨거운 불꽃 알갱이 뭉치 (전구 파손·전선·비상등 공용, `_draw`) |
| `scripts/emergency_light.gd` | 회전 비상등 (광선 라이트 + 볼류메트릭 팬 + 돔, 파손) |
| `scripts/water_leak.gd` | 새는 수도관 (물줄기·튐·분무·웅덩이·파문) |
| `scripts/water_pool.gd` | 고인 물 (fx `water`) — 수면선 아래 폴리곤 + `water_surface` 반사·굴절 셰이더. |
| `scripts/broken_wire.gd` | 끊긴 전선 (버렛 체인 물리, 총알·플레이어 반응, 아크 방전) |
| `scripts/fire_source.gd` | 불 (절차 불꽃·라이트·불티·잔해·그을음·부피감 연기 파티클). `STYLES` 3종 — 채도 낮춘 팔레트, 연기는 불의 붉은기로 시작해 검게 (`smoke.gdshader use_particle_color`) |
| `scripts/sentry_turret.gd` | 바닥 격납형 센트리건 — 전개 애니, 머리/받침 분리 조준, 조종, 사격·탄띠, 대기 스캔·격납 |
| `scripts/muzzle_blast.gd` | 중화기 총구 화염 — 십자 섬광·화염 원뿔·흰 심(`_draw`, 가산) + 연기 파티클 + 불꽃 + 라이트 |
| `scripts/shell_casing.gd` | 탄피 — 중력·바닥 튕김·회전, 1.6초 후 페이드 |
| `scripts/crosshair.gd` | 마우스 위치의 조준점 (사격 시 벌어짐) |
| `scripts/mouse_recoil.gd` | 사격 반동을 실제 마우스 포인터에 적용 (`Viewport.warp_mouse`). 한 발 약 21px 사방 랜덤 방향(직전 방향과 60° 이상 벌림), 연사 heat 에 비례해 커지고 55% 는 자동 복귀. 포인터 잔떨림은 반올림 드리프트 때문에 두지 않음(카메라 흔들림·조준점 벌어짐이 담당) |
| `scripts/game_camera.gd` | 동적 카메라 — 플레이어 추적 + 마우스·시선 리드, 감도 프리셋 3종, 방 한계, 사격 흔들림 |
| `scripts/light_mood.gd` | 배경 라이팅 무드 프리셋 3종 (`PRESETS`, preload 로 사용) — 앰비언트 색 + 방 전체 보조 광원(채광 필 라이트 / LED 스트립·표시등·창문 외광). `Room.apply_mood` 가 얹는다 |
| `scripts/lobby.gd` / `scripts/app_flow.gd` / `scripts/map_viewer.gd` | 로비 UI(메인 게임·테스트·맵 뷰어) / 씬 흐름·시작 방 전달 / 맵 뷰어(방 통째 조립, [ ] 전환) |
| `tools/sentry_shot.gd` | 센트리건 전개→조준→사격 단계별 스크린샷 (`user://shots/sentry_*.png`) |
| `tools/validate_map.gd` / `tools/map_shots.gd` / `tools/room_shot.gd` | 맵 데이터 검사(헤드리스) / 방 21장 스크린샷 / 방 한 장 스크린샷 (`-- <방 id> [main\|game\|viewer] [프레임]`) |
| `tools/build_theme_tile_sheets.py` | 테마별 타일 시트(3×2·3×3·L-벤드 4×1) 합성 + 펜던트 램프 추출 + 테마 프랍 복사 |
| `scripts/crt_overlay.gd` (autoload `CrtFx`) / `scripts/crt_preset.gd` / `shaders/crt.gdshader` | 전역 CRT 모니터 후처리(루트 뷰포트 층 100 풀스크린) · 프리셋 표 · 셰이더. F4 순환, `user://crt.cfg` 저장, 환경 변수 `CRT_PRESET`. 스크린샷 `tools/crt_shot.gd` |
| `scripts/main.gd` / `scripts/main_game.gd` | 방 로딩·페이드 전환·HUD·입력 맵·마우스 → 월드 조준점·글로우 환경·후처리·공간감 프리셋 F2 전환 / 메인 게임 HUD(구역·밀도·탐색 수) |
| `scripts/depth_preset.gd` / `scripts/light_mirror.gd` / `scripts/foreground_layer.gd` | 공간감 프리셋 표(이전/근경 분리, 층 번호·인물 층 조명 비율) / 인물 층 전용 거울 라이트 / 근경 실루엣 층(배관·케이블·기둥·상자·트레이, 플레이어 기준 패럴랙스 1.045×, 윤곽 림) |
| `scripts/foreground_lab.gd` / `tools/depth_ab_shot.gd` / `tools/foreground_lab_shot.gd` | 근경 랩 편집 오버레이 / 공간감 프리셋 A/B 스크린샷 도구 / 근경 랩 스모크 샷 |
| `scripts/auto_test.gd` | 개발용 자동 테스트. `AutoTest.tscn` 을 실행하면 입력을 시뮬레이션하고 `user://shots/` 에 스크린샷 저장 |

## 가이드 적용 사항

- **렌더링 확정 — "베이크 자산 · 풀해상도" (2026-09-18)**: 월드는 `Main._setup_view` 가 만드는 1600×900 `SubViewport`(×1, Nearest) 에 그리고 카메라 zoom 0.5 → 가시 월드 3200×1800. **그림은 4×4 월드 px 단색 블록으로 구운 픽셀 아트(아트 1px = 월드 4px = 화면 2px), 조명·파티클·이동은 풀해상도로 부드럽게**(`snap_2d_transforms_to_pixel` 끔, `Lighting.radial_texture` 는 부드러운 3점 그라데이션). 글로우 환경과 `PostFX` 는 SubViewport 안, HUD(`UI` CanvasLayer)와 페이드는 바깥. `window/stretch/scale_mode=integer`.
  - 이력: 800×450 ×2 → 534×300 ×3(4px 블록, 계단형 5단계 광원) → 8px ×6 방식 B 시험·롤백 → 2026-09-18 프리셋 5종(픽셀레이트 이전 / 534×300 ×3 / 800×450 ×2 / 베이크 자산·풀해상도 / 원본 자산·2px 격자) 실시간 비교 후 **베이크 자산·풀해상도 확정**. `scripts/render_preset.gd`·`tools/render_ab_shot.gd`·`assets_original/`(314190d 에서 꺼낸 비교용 원본 143장) 는 폐기 — 원본은 `git show 314190d:` 로 언제든 꺼낼 수 있다. 8px 네이티브 규격은 `Docs/ART_GUIDE.md` §10.
  - **자산은 `Tools/bake_pixel_grid.py` 로 굽는다**: 각 4×4 블록(크롤러는 10×10 — scale 0.4)을 단색 하나(불투명 픽셀 평균에 가장 가까운 실제 색)로 채우고 알파를 다수결(50%)로 잘라 AA·잡티를 없앤다. 크기는 원본과 같아 타일셋·좌표는 그대로. 프랍·캐릭터는 블록 안 색 분산이 최소인 격자 오프셋을 찾고, 타일은 128px 이음새 때문에 오프셋 0. 멱등. **자산 파이프라인 순서**: `build_hooded_mechanic_split.py` → `build_hooded_mechanic_head_split.py` / `build_crawler_frames.py` → **`bake_pixel_grid.py`** → `build_normal_maps.py` → `godot --headless --import`.
  - 화면 px = 뷰 px(×1). 색수차(`ABERRATION_*`)·`post_fx`·마우스 반동(`MouseRecoil.KICK_PX`)·카메라 `deadzone` 모두 창 px. 월드 px 로 그리는 것(조준점 `Crosshair` 굵기 4, 파편, 탄피)은 **4 의 배수**로 두어야 아트 격자에 맞는다.
  - 월드 → 창 좌표는 `Main.world_to_screen()` (AutoTest 마우스 워프가 쓴다). AutoTest 의 첫 `aimm` 사격(0.9초)은 크롤러가 화면 밖이라 빗나간다(이후 처치는 정상).
  - 아직 안 한 것: HUD 픽셀 폰트(안에 넣기), 크롤러 `crawler_meta.json` 발밑 줄 재측정(알파 컷으로 최대 10px 달라질 수 있음).
- **CRT 모니터 후처리 (2026-09-18, F4 로 프리셋 선택, `scripts/crt_preset.gd`)**: autoload `CrtFx`(`scripts/crt_overlay.gd`) 가 루트 뷰포트 맨 위 CanvasLayer(100) 에 풀스크린 ColorRect + `shaders/crt.gdshader` 를 두어 로비·게임·맵 뷰어·근경 랩 **화면 전체(월드 + HUD)** 에 적용한다. 셰이더 요소: 배럴 굽힘(`curvature`)·둥근 모서리(`corner_radius`)·비네트 / 주사선(`scanline_count` 450 = 아트 1px 행마다 한 줄, 밝은 픽셀은 빔이 굵어져 줄이 얕음) / 형광체 마스크(`mask_type` 1 애퍼처 그릴 · 2 섀도 마스크 · 3 슬롯 마스크, `mask_px` 는 실제 화면 px) / 색 분리(`aberration`)·가로 번짐(`bleed`)·헐레이션 / 잡음·깜빡임·흐르는 밝기 띠 / 밝기·대비·채도·틴트(채도 0 + 틴트 = 단색 형광). 프리셋 7종: **1 끄기**(ColorRect 자체를 숨겨 비용 0) · **2 은은한 주사선**(평면, 픽셀 거의 그대로) · **3 아케이드 모니터**(기본 — 약한 굽힘·선명한 주사선·애퍼처 그릴·헐레이션) · **4 가정용 TV**(굽음·300줄·섀도 마스크·색 번짐·잡음·띠) · **5 낡은 모니터**(심한 굽힘·슬롯 마스크·강한 열화·탈색) · **6 녹색 단색 형광** · **7 호박색 단색 형광**. 선택은 `user://crt.cfg` 에 저장되고 환경 변수 `CRT_PRESET=<번호|id>` 가 우선한다. 토스트 라벨은 오버레이 위에 그려져 CRT 효과를 받지 않는다. 비교 스크린샷: `--script res://tools/crt_shot.gd -- <방 id> [번호,...] [대기 프레임]` → `user://shots/crt_<방>_p<번호>_<id>.png`.
- **공간감: 층 분리 (2026-09-18, F2 로 이전/이후 A/B 비교 중)**: `scripts/depth_preset.gd` — 0 이전(평면) / 1 근경 분리(기본). 전환은 같은 방·플레이어 위치·카메라 프리셋을 `AppFlow.reload_in_place` 에 남기고 Main 을 다시 로드한다(층 구성이 `Room.build` 에서 정해지므로). 환경 변수 `DEPTH_PRESET=<0|1>` 로 시작 프리셋 고정, 검증 도구 `--script res://tools/depth_ab_shot.gd -- <방 id> [1,0] [프레임]` 이 `user://shots/depth_*.png` 저장.
  - **층**: 타일 0 · 뒷벽 문 1 · 프랍 2 · **먼지 3** · 빛 기둥·환경 연출 4 │ 플레이어·몬스터 5 · 탄 6 │ **근경 7** · 조준점 20. 이전엔 먼지가 Air(4)+2 = z6 로 캐릭터까지 덮어 화면이 평평했다.
  - **조명 분리** (`Lighting.split_by_depth`, `scripts/light_mirror.gd`): 벽 램프(+바닥 풀)·채광 필·바닥 라이트·비상등 광선/글로우·Power Relay 조명은 `range_z_max=4` 로 배경 층만 정면으로 비추고, 인물 층(z5~6)은 자식 `LightMirror`(원본의 energy·enabled·color 를 매 프레임 따라감, 램프 55% · 바닥 75%) 가 비춘다. 벽이 인물보다 밝아 실루엣이 앞으로 떠 보인다. 총구·탄착·불·아크·독액처럼 인물 층에 있는 광원은 분리하지 않는다(모든 층 그대로). PointLight2D 는 표면을 물들이는 방식이라 z 순서로는 앞뒤가 안 생기고, 이 방법으로만 층별 밝기 차가 난다.
  - **근경 실루엣** (`scripts/foreground_layer.gd`, z7): 근경은 방 윤곽을 덮어 방을 바깥 어둠과 이어 주는 층이다 — 경계에서 짧게 끊기면 그 뒤로 배경 벽이 다시 보인다. 절차 생성 규칙(작업실 `foreground/workshop.json` 수작업 배치에서 뽑음): **천장선마다** 두께 48px 배관을 천장선 가운데에 깔고(마디 틈 28px + 플랜지·행거), 방 끝이나 옆 열이 더 낮은 쪽(위가 어둠)으로 320px 더 뻗음 · **바닥 밴드 하단선**에 두께 56~60px 트레이(양쪽 어둠으로 320px, 마디 틈 96~230px, 위에 잔해) · 실내 **기둥**(방 1300px 당 1, 폭 64~100, 그 열의 천장 위 44px ~ 바닥 밴드 아래 32px) · **상자 무리**(방 1100px 당 1, 바닥선 38px 아래에 닿음, 위에 작은 상자) · 가장 높은 천장 배관에서 처진 **케이블** 1~3. 기둥·상자·케이블은 램프·정면문·방 가운데·서로에서 200px 이상 떨어진 자리. 계단형 천장은 열별 천장(`col_ceilings`)으로 구간을 나눠 처리한다. 몸체는 `light_mask=0` 으로 라이트 제외, 색 (0.07,0.07,0.10) 에 앰비언트가 다시 곱해져 방 밖 순검정과 거의 구분되지 않는다(형체는 림이 알려준다). **윤곽 림**: 사각형 네 변에 4px 띠를 두르고 `shaders/foreground_rim.gdshader` 를 입힌다 — 정점 색에 담긴 변의 바깥 법선이 광원(`LIGHT_DIRECTION`)을 향할 때만 그 광원 색으로 밝아지고(`rim_strength` 0.8, 감쇠는 `pow(0.55)` 로 펴서 멀리서도 살짝), **방 밖(어둠)에 있는 띠와 가까운 방 경계(측벽·열별 천장·바닥 밴드 하단) 쪽을 향한 면은 경계 240px 안에서 림이 0** 이 된다(`room_factor`). 거울 라이트(`LightMirror`) 범위를 z7 까지 넓혀 램프·비상등 림이 닿고, 불·총구·아크는 원래 모든 층을 비춘다. 패럴랙스 기준은 **카메라 화면 중심**(사격 흔들림 `offset` 제외): 마우스·시선 리드로 카메라가 내다볼 때 근경이 반대로 밀리고, 걷기만 할 때는 카메라가 따라오는 만큼만 조금 반응한다. 이동의 **0.045배**, 지수 평활(5/s) 뒤 4px 격자에 한 칸 이상 벌어질 때만 옮기는 히스테리시스로 서 있을 때의 떨림을 막는다. (플레이어 X 기준·같은 방향은 시험 후 롤백) 모양은 방 id 시드로 고정.
  - 글로우(스크린 공간 블룸)는 그대로 모든 층 위. 확정되면 프리셋 0 분기(`DepthPreset.enabled()`)와 F2·HUD 를 제거한다.
  - **그림 근경** (`ForegroundLayer.SPRITES`): `assets/props/foreground_pipe_bracket_v2.png`(파이프 브래킷, 천장 배관에서 내려오는 세로관+밸브)·`foreground_utility_housing_v2.png`(바닥 유틸리티 하우징)를 kind `pipe_bracket`/`utility_housing` 으로 놓는다. 불투명 영역(region)을 항목 size 로 늘리고(기본 원본의 절반: 420×616 · 806×280), 실루엣과 같은 층·같은 어둠(라이트 제외, `SPRITE_TINT` 0.55 × 앰비언트). 시험 방(`SPRITE_ROOMS`: airlock·corr_west·workshop·tank_room)의 절차 생성에 하나씩 들어가고(브래킷은 가장 높은 천장 배관 아래, 하우징은 바닥선 38px 아래에 닿음), 작업실 저장 파일에도 둘을 추가했다. 랩에서 7·8 로 어느 방에나 놓을 수 있다.
  - **근경 랩** (로비 → "근경 랩", `scripts/foreground_lab.gd`, `AppFlow.start_foreground_lab`): 실제 방·조명·플레이어 위에서 근경을 편집한다. 근경은 `ForegroundLayer.items = [{kind, pos, size}]` 데이터로 그려지고(kind: pipe·pillar·crate·tray·dark·cable), 방마다 `foreground/<방 id>.json` 이 있으면 그것을, 없으면 방 id 시드 절차 생성을 쓴다. 랩에서 **클릭·드래그 이동, 우하단 모서리 드래그 크기, 1~6 추가, Del 삭제, Tab 종류 순환, Q/E 그리기 순서, 방향키 4px(Shift 32px), Ctrl+D·Shift 드래그 복제, R 절차 생성 초기화, H 윤곽선, A/D 카메라, [ ] 방 전환, S 저장**. 저장 파일은 프로젝트 안(`foreground/`)이라 커밋된다. 스모크 테스트: `--script res://tools/foreground_lab_shot.gd -- <방 id>`.
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
