# 사이드뷰 작업실 방 이동 프로토타입 (Godot 4.7)

`Docs/RESOURCE_USAGE_GUIDE.md` 의 규칙대로 GameReady 타일·프랍·캐릭터를 조립해,
붉은 후드 정비공을 움직여 4개의 방을 오갈 수 있는 프로토타입이다. GDScript 로만 작성됐다.

## 실행

- 새 PC: `setup.bat` (Godot 설치) → `run.bat`. `run.bat` 은 설치된 Godot 을 자동으로 찾는다. 자세한 건 `SETUP.md`
- 또는 Godot 에디터에서 이 폴더의 `project.godot` 을 열고 F5

## 조작

| 키 | 동작 |
|---|---|
| A / D, ← / → | 좌우 이동 최고 840px/s. 가속 5200·감속 3600 px/s² 이징(출발·정지가 부드럽고 살짝 미끄러짐). 걷기 애니 속도는 실제 속도에 비례, 조준 반대로 걸으면 뒷걸음 역재생 |
| 마우스 | 조준 — 팔+총이 실시간으로 포인터를 가리킨다. 바라보는 방향도 포인터가 결정 |
| 좌클릭 (J) | 사격 — 클릭마다 한 발(단발, 최소 간격 0.09초). **포인터 위치가 곧 탄착점**. 총구→탄착점 한 줄 궤적이 찍히고 0.05초 안에 사라진다. 탄피가 뒤·위로 튀어 바닥에서 튕긴다 |
| Space | 구르기 — 이동 중이면 그 방향, 아니면 바라보는 방향. 0.18초 · 3150px/s, 구르는 동안 사격 불가 |
| Ctrl (S / ↓) | 앉기 (홀드) — 앉은 채로 조준·사격 가능 |
| W / ↑ | 정면문 앞에서 다른 방으로 진입 |
| F11 | 전체화면 토글 |

사격 연출: 총구 화염(shoot_03 에서 추출)·총구 라이트 + 팔 반동(뒤로 14px·위로 0.14rad) + 카메라 미세 흔들림 + 조준점 벌어짐 + 탄착(플래시·충격 링·불꽃 스파크 8·중력 받는 파편 8·라이트 — 벽/유리/프랍별 색과 양이 다름). **총구·궤적·탄착·피격 플래시·라이트는 모두 붉은 팔레트**(`Lighting.RED_*`, `GUN_LIGHT`, `IMPACT_LIGHT`)를 공유한다. 탄피만 황동색.
Idle/앉기 중에는 발을 고정한 채 몸 스케일이 2.6초 주기로 잔잔하게 숨쉰다.

## 라이팅

방마다 `CanvasModulate`(0.26, 0.28, 0.40) 로 어둡게 깔고, 타일 속 천장 램프 위치(`RoomData.TILE_LAMPS`: wall_b, wall_repeat)에 `LampLight`(PointLight2D, 반지름 560, energy 1.0, height 140) 를 단다. 램프는 미세하게 흔들리고 3~9초마다 0.2~0.55초 깜빡인다. 총구·탄착에도 짧은 PointLight2D 가 붙는다. 배경 밖은 완전한 검정.

램프는 **총으로 깨진다**: 전구 60px 안에 탄착하면 0.22초 글리치 셰이더로 지직거리며 꺼지고(그 뒤 0.35초 잔상), 전구 픽셀 위에 어두운 커버가 덮이며 유리 파편이 쏟아진다(`LampLight.break_lamp`).

## 표면 라이팅: 강한 노멀 반응 + 림라이트 + 열 잔광 (`lit_common.gdshaderinc`)

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

## 방 연결

```
                 [숙소 Quarters]
                 정면문0      정면문1
                   ↕            ↕
[작업실 Workshop] ⇄ [복도 Corridor] ⇄ [창고 Storage] ⇄ [격납고 Hangar]
   (측벽문)             (측벽문)             (측벽문)   폭 4416 — 카메라 스크롤
```

## 구조

| 파일 | 역할 |
|---|---|
| `scripts/room_data.gd` | 방 정의 데이터(타일 순서, 프랍 좌표, 문 연결, 환경 연출 `fx`). 새 방은 여기에 항목만 추가 |
| `scripts/room.gd` | 데이터로 타일·문·프랍을 조립. 레이어 순서: 타일 → 뒷벽 문 → 프랍 → 캐릭터 → 투사체 |
| `scripts/player.gd` | 캐릭터. `BodyPivot/Body`(몸통 애니) + `ArmPivot/Arm·Muzzle·Flash`(어깨 기준 회전하는 팔+총). 상태 Roll > Crouch > Walk > Idle |
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
| `scripts/fire_source.gd` | 불 (절차 불꽃·라이트·불티·잔해·그을음·부피감 연기 파티클) |
| `scripts/shell_casing.gd` | 탄피 — 중력·바닥 튕김·회전, 1.6초 후 페이드 |
| `scripts/crosshair.gd` | 마우스 위치의 조준점 (사격 시 벌어짐) |
| `scripts/main.gd` | 방 로딩·페이드 전환·카메라 제한/흔들림·HUD·입력 맵·마우스 → 월드 조준점·글로우 환경·후처리 |
| `scripts/auto_test.gd` | 개발용 자동 테스트. `AutoTest.tscn` 을 실행하면 입력을 시뮬레이션하고 `user://shots/` 에 스크린샷 저장 |

## 가이드 적용 사항

- 리소스는 원본 픽셀 1:1 (뷰포트 1600×900), Nearest 필터, 밉맵 없음
- 타일: Bottom Left 피벗, 같은 Y, `X += 폭` 누적, 캡은 방 끝에만
- 바닥선: 타일 상단 기준 Y = 486 — 캐릭터·프랍 접지 기준
- 캐릭터: 320×320 Full Rect 프레임, 발 밑이 원점(Bottom Center), `flip_h` 로 왼쪽 방향

## 캐릭터 팔·총 분리 리소스 (`assets/character/Split/`)

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
