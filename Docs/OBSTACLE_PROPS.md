# 장애물 프랍 구현 — 2026-09-28

## 사용하기

기존 런처로 게임을 실행한 뒤 로비 오른쪽 **장애물 프랍 테스트 / 점프 · 파괴 · 가스통 폭발** 버튼을 누른다.
A/D 이동, W/↑ 점프, Space 구르기, 마우스 좌클릭 사격, Q 무기 교체, F1 로비.
테스트를 다시 열면 프랍이 초기화된다. 메인 게임에는 대형 정비 홀(hall)에 5종, 창고(storage)에 상자와 가스통 2개를 배치했다.

## 동작과 크기 (2026-09-28 개편)

캐릭터 서기 키 약 265(머리 포함) 기준으로 원화에서 다시 뽑았다. 모두 4px 격자(1 art px = 4 월드 px)라 캐릭터와 픽셀 밀도가 같다.

| 종류 | 런타임 PNG | 캐릭터 대비 | 내구도(위력 1 기준) | 동작 |
|---|---|---|---|---|
| 철제 방호벽 | 192×96 | 무릎 (36%) | 파괴 불가 | 걷기·구르기 차단, 점프·위에 착지 가능, 첫 피격에 찌그러진 외형 |
| 케이블 드럼 | 144×124 | 골반 (47%) | 파괴 불가 | 걷기·구르기 차단, 점프·위에 착지 가능 |
| 목재 보급 상자 | 176×128 | 엄폐 높이 128 (48%) | 4 | 서서 쏘면(총구 160) 넘기고 웅크리면 가려진다, 점프 또는 사격 파괴 |
| 균열 콘크리트 | 192×220 | 83% | 8 | 점프 정점(≈200)보다 높다 — 사격으로 뚫어야 통행 |
| 가스통 | 64×152 | 가슴 (57%) | 3 | 피격 누출 → 점화 → 폭발 → 빈 외피가 튕겨 날아가 떨어짐 |

예전 크기(224×112 · 176×152 · 192×144 · 200×260 · 88×196)는 가스통이 캐릭터 몸통만 하고 콘크리트가 키와 같아 비율이 어긋났다.
파괴 잔해는 시각 효과이고 이동/사격 충돌은 제거한다. 파손 상태(날아간 외피가 떨어진 자리 포함)는 현재 플레이 세션에서 방 재진입 시 유지한다.

## 타격감

**한 발마다** (`ObstacleProp._react`)
- 맞은 반대쪽으로 밀렸다 돌아오는 스프링 흔들림 + 바닥 고정 눌림(스쿼시) + 기울기. 무거운 프랍(mass)일수록 덜 움직인다.
- 전신 백색 섬광(prop_surface 프리셋 1 White Snap).
- 재질 파티클: 나무 = 가시 파편·톱밥 / 콘크리트 = 자갈·분진 / 금속(방호벽·드럼·가스통) = 불꽃 + 쇳소리.
- 탄착 이펙트 종류도 재질을 따른다: 나무만 PROP, 금속·콘크리트는 벽 탄착(불꽃·돌 소리). 장애물 명중은 카메라를 0.9 더 흔든다.
- 누적 균열: 맞은 자리에서 뻗는 4px 칸 균열(검은 틈 + 아래 턱의 속살색). 나무는 결을 따라, 콘크리트는 여러 갈래.

**파괴** (상자·콘크리트)
- 원화를 판자 줄(목재)·덩어리(콘크리트)로 잘라 제자리에서 탄착점 반대로 터뜨린다(ChunkDebris, 노멀맵 유지).
- 긴 판자 파편 30개·쇠 모서리 장식 / 자갈 34개·녹슨 철근 토막, 몸통을 가리는 먼지 구름, 바닥을 타고 퍼지는 먼지 띠.
- 잔해 원화가 눌렸다 펴지며 자리 잡는다. 히트스톱 0.05초(콘크리트 0.07) + 카메라 흔들림 5.5(7.5).
- 소리 2겹: 목재 impactWood_heavy + impactPlank / 콘크리트 impactMining + stonesHit.

**가스통**
- 첫 구멍 자리에서 쏜 쪽으로 흰 가스 줄기가 뿜어지고 쉬익 루프음(절차 합성)이 난다. 통이 미세하게 떤다.
- 체력 0 → 즉시 터지지 않고 0.5초 점화: 가스 줄기가 불꽃 혀로 바뀌고, 통이 점점 세게 떨며 적열 발광, 쉬익 소리가 커지고 높아진다. 점화 중에 또 쏘면 바로 터진다.
- 폭발에 휘말린 가스통은 0.14~0.28초로 짧게 끓어 연쇄가 "쾅-쾅" 박자로 터진다.

## 폭발

- 반경 410, 거리 감쇠. 몬스터 최대 8 HP, 주변 프랍 최대 위력 12, 플레이어 최대 60 피해 + 넉백 700~1300(독액 480보다 세다). 벽 너머는 피해 없음.
- 0.00초: 4px 격자 가시 별 섬광 + 바닥 위 반원 충격파. **히트스톱 0.09초**가 이 프레임을 붙잡는다. 카메라 흔들림 최대 18(상한 18), 색수차 +7, 화면 주황 가산 섬광.
- 원화 불덩이 6프레임을 1배(격자 유지)로 네 덩이 — 중심·좌·우·위를 시차(0/0.05/0.085/0.13초)와 좌우 반전으로 겹쳐 하나의 큰 화구로 보이게 했다. (예전엔 1.61배 확대라 픽셀이 뭉개졌다)
- 불꽃 알갱이 44 + 불씨 덩이 26(바닥에 떨어져 식는다), 짙은 연기 기둥 18덩이(최대 3.2초), 바닥 분진 띠, 쇳조각 외피 파편.
- 바닥 잔불 7개가 약 2.4초 일렁이고 조명 풀 슬롯 하나가 함께 깜빡인다. 뒷벽·바닥에 그을음 자국이 방을 나갈 때까지 남는다.
- 매달린 램프·끊긴 전선이 폭압에 크게 흔들린다.
- 소리 3겹: explosionCrunch(5종 중 하나) + lowFrequency_explosion + 절차 합성 굉음 꼬리(1.6초), 0.3초 뒤 잔해 떨어지는 소리. 외피가 바닥에 닿을 때 쇳소리.

## 에셋과 재생성

- GodotPrototype/assets/audio/sfx/props/: Kenney CC0(Impact / Foley / Sci-Fi Sounds) 18개. 라이선스 사본은 assets/audio/_licenses/ 에 이미 있다. audio_manager.gd 의 prop_* · gas_explosion* 키.

- Assets/Generated/ObstacleProps/props_source.png: 확정 v2 컨셉을 참조해 내장 image_gen으로 생성한 투명 5×2 원형/파손 아틀라스.
- Assets/Generated/ObstacleProps/explosion_source.png: 내장 image_gen으로 생성한 투명 3×2 폭발 애니메이션 원화.
- GodotPrototype/assets/props/obstacles/: 원형 5장 + 파손/피격 5장.
- GodotPrototype/assets/normals/props/obstacles/: 대응 노멀맵 10장.
- GodotPrototype/assets/effects/obstacles/: 고정 캔버스 폭발 프레임 6장.
- Tools/ImageProcessing/build_obstacle_assets.ps1: C# System.Drawing으로 원화 알파 경계 추출, 셀 분리, nearest-neighbor 정규화, 4배 픽셀 그리드와 노멀맵 생성. 원화는 보존한다.

재생성: PowerShell에서 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File Tools/ImageProcessing/build_obstacle_assets.ps1` 실행 후 Godot 에디터로 임포트한다.

## 구현

ObstacleProp: 데이터 기반 프랍 인스턴스, HitProp와 같은 hit/is_solid_at 인터페이스.
Room: 배치, 총알 선분 차단, 수평 이동 sweep, 착지 표면, 방별 파손 기록, 범위 피해.
Player: 기존 자체 이동/점프 구조에 충돌·위에 착지·지지 프랍 파괴 시 낙하 연결.
ObstacleExplosion: 가스통 폭발 연출(섬광·충격파·불덩이·잔불·그을음)과 사운드.
PropFx: 재질 파티클(나무·돌·가스·불씨·연기) 공용 노드. 4px 격자로 그리고, 라이팅 아래에서 묻히지 않게 밝기를 보정한다(LIT_BOOST/PUFF_BOOST).
ObstaclePlaytest: 로비에서 들어가는 실제 Main 게임 기반 테스트 공간.

## 검증

- scenes/ObstacleValidation.tscn: 실제 Main/Player/Room/Crawler/WeaponProjectile을 통해 **60개 검증, 실패 0** (2026-09-28 개편 후: 판자 조각 파괴·파편 구름, 점화 퓨즈, 점화 중 충돌 유지, 짧은 연쇄 퓨즈 추가). 세 무기, 걸음/구르기 차단, 양방향 점프, 착지, 지지물 파괴, 큰 프레임 간격 충돌, 폭발/연쇄/범위, 플레이어 피해/재등장, 이펙트 정리, 상태 유지, 실제 맵 배치, 일반 방 이동 회귀 포함.
- scenes/ObstacleEntryValidation.tscn: 실제 로비 버튼으로 Main 테스트 방 진입 성공. 1600×900에서 신규 버튼이 다른 메뉴 버튼을 가리지 않음을 확인. 같은 작업공간에 추가된 역광 테스트 진입점도 보존했다.
- 기존 tools/validate_locomotion.gd의 --script 실행은 Audio 오토로드를 찾지 못해 시작 단계에서 실패했다. 이 결과를 통과로 간주하지 않았으며, 위 실제 Main 씬 기반 검증에서 일반 방 걷기 속도·점프 복귀와 프랍 이동을 검증했다.
- tools/validate_map.gd: 신규 obstacle 타입 및 상태별 텍스처 검사를 추가. 전체 맵 오류 0. 배경 가구와 플레이 경로 프랍의 시각 중첩 경고 16개는 남아 있으며 실제 레이어를 분리해 표시한다. 기존 경고도 포함한다.
- 타격감 시간순 캡처: `scenes/ObstacleFxCapture.tscn`(창 모드) → research-images/obstacle-props-v2/ (01 크기 비교, 02~06 상자, 07~09 콘크리트, 10~17 가스 누출·점화·폭발·연쇄·연기·잔불·잔해).
- (개편 전) Vulkan Forward+ 실제 렌더 캡처: research-images/obstacle-props/01_all_props.png, 02_gas_before.png, 03_gas_explosion.png, 04_gas_after.png, 05_campaign_hall.png.
- 샌드박스 실행 로그에는 Windows 인증서 저장소 접근 및 외부 셰이더 캐시 저장 경고가 발생했다. 새 스크립트 런타임 오류 없이 검증과 PNG 저장이 완료되었다.

## 생성 프롬프트

### 프랍 아틀라스
Use case: precise-object-edit / game production sprite sheet. Convert the attached APPROVED concept sheet into a clean transparent production sprite atlas. EXACTLY 5 columns and 2 rows, evenly sized cells, no text, no floor strips, no characters, no shadows outside sprites, no background. Transparent alpha throughout empty areas. Preserve these exact approved pixel art designs including crate RIGHT SIDE FACE visible.
Top row: intact steel barricade, cable reel, wooden crate with right face visible, cracked concrete upright rubble, red gas cylinder with protected valve flame pictogram.
Bottom row directly under each: bullet-dented but still solid barricade, dented but solid cable reel, collapsed wooden crate planks, collapsed small concrete rubble, ruptured empty red gas cylinder shell lying horizontally WITHOUT flame or smoke.
Each object fully isolated with generous transparent padding inside its cell; bottom aligned within each cell. Pixel-art sprites crisp edges chunky consistent pixel clusters, limited palette matching source. No labels, no extra effects. Same object designs, no redesign. Wide landscape 5x2 grid. The damaged wood and concrete and gas remains must be very low profile, about one quarter intact object height.

### 폭발 아틀라스
Use case: stylized-concept. Production 2D side-scroller pixel-art gas cylinder explosion animation SPRITE SHEET on true TRANSPARENT background. Exactly SIX frames in a regular 3 columns x 2 rows grid, reading left to right top to bottom. Each cell same size with generous empty transparent padding so no sprites touch or overlap. Frames share same fixed center near lower half and common baseline. NO text labels numbers ground cylinder or environment. Frame1 small white-yellow sharp ignition star with orange sparks. Frame2 expanding bright orange fireball white yellow hot core scalloped pixel lobes. Frame3 peak wide orange fireball with angular tongues yellow center and dark red rim. Frame4 curling orange flame lobes breaking into charcoal-purple smoke billows. Frame5 mostly blue charcoal gray smoke plume with isolated orange glowing embers. Frame6 thin dissipating separated small smoke curls and dim embers. Authentic chunky pixel art with hard stepped contours and discrete solid-color clusters, limited color palette, near-black dark smoke purple shades, warm orange and cream highlights, no smooth gradients, no airbrush, no photorealism, no solid background, no text. Match a gritty industrial pixel art shooter with blue brick background. All six frames fully contained in cell, finished game-ready animation art.

