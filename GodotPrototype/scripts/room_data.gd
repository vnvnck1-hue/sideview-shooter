class_name RoomData
extends RefCounted
## 전체 맵 정의 — 방 21개가 측벽문(같은 평면, 좌우)과 정면문(뒷벽, 다른 방으로 순간 이동)으로 이어진 그래프.
## 좌표계: 방 왼쪽 끝이 x=0, 바닥선은 모든 방이 FLOOR_Y(486). Y 는 아래로 증가. 천장은 방 모양에 따라 위(음수)로 올라간다.
##
## 방 한 칸의 키
##   title / zone / theme     제목, 구역 이름, RoomTheme 테마 id (workshop·corridor·hydroponics·crewquarters·power_relay)
##   shape                    열 프로필 [[폭 셀, 높이 셀], ...] — 128px 셀. 바닥 행은 공유하고 위로 쌓인다.
##                            높이 4 = 낮은 복도(천장 y 24), 5 = 보통 방(-104), 7 = 높은 방(-360), 9 = 굴뚝·성당(-616).
##                            같은 높이 구간은 2셀 이상(1칸 폭 기둥은 아트에 조각이 없음). tools/validate_map.gd 가 검사한다.
##   left_door / right_door   {"open": bool, "target": 방 id}. 열린 문은 걸어서 통과, 닫힌 문은 벽.
##   front_doors              [{"x": 문 왼쪽 x, "target": 방 id, "target_door": 상대 방의 정면문 번호}]. 양쪽이 서로 가리켜야 한다.
##   props                    바닥 프랍 {"tex": assets/props/<이름>.png 또는 res:// 경로, "x": 바닥 중심 x} — y 는 실제 불투명 픽셀이 바닥에 닿게 자동.
##                            벽걸이는 "cy"(그 열 천장 상단에서 아래로) 또는 "fy"(바닥선에서 위로) 를 주면 그 높이에 붙는다.
##                            특수 {"type": "cabinet"(파츠 파괴)|"capacitor"|"cart"|"breaker"(벽걸이, cy/fy)|"sentry"(바닥 격납 센트리건)}.
##                            sentry 는 평소 바닥 해치로 묻혀 있다가 W/↑ 로 전개·조종한다 (SentryTurret). 받침 폭 376px · 높이 440px 자리를 비워 둘 것.
##   lamps                    [x, ...] 천장 펜던트 램프(LampLight — 총으로 깨짐, 빛 기둥, 바닥 풀). 그 열의 천장 띠 아래에 매달린다.
##   fixtures                 장식 조명 [{"file": power_relay Lighting 이름, "x", "cy"|"fy", "radius", "color"(선택)}] — PointLight2D + 스프라이트.
##                            ceiling_lamp · dangling_lamp · fluorescent_lamp · wall_lamp · floor_work_light · indicator_beacon
##   fx                       환경 연출. 위치는 {"x", "cy"} (천장 기준) 로 적는다. beacon(회전 비상등) · leak(새는 수도관: dir, pressure) ·
##                            wire(끊긴 전선: length) · power_cable(전력 케이블: length) · fire({"x", "size"}: 바닥) · water({"level", x0/x1 선택}: 고인 물)
##   monsters / spawn         시작 배치 [{"type": "crawler", "x", "facing"}] · 지속 스폰 {"max": 살아 있는 최대 수, "interval": [최소, 최대 초]}.
##                            max 0 = 몬스터 없는 방. 2~5 = 적음. 9~14 = 아주 많음.
##
## 맵 (측벽문 ⇄, 정면문 ↕):
##   정비 구역     [에어록] ⇄ [서쪽 통로] ⇄ [작업실] ⇄ [대형 정비 홀] ⇄ [짧은 통로] ⇄ [격납고] ⇄ [창고]
##                                ↕                        ↕                          ↕            ↕
##   승무원 구역   [침실 A] ⇄ [숙소 복도] ⇄ [침실 B] ⇄ [식당·휴게실] ⇄ [세면실]        │            │
##                                ↕                          ↕                        │            │
##   전력 구역     [케이블 덕트] ⇄ [전력 릴레이실] ⇄ [축전기 저장고] ⇄ [비상 발전실]      │            │
##                                                                                    ↕            ↕
##   수경재배 구역 [재배실 전실] ⇄ [대형 재배실] ⇄ [급수 통로] ⇄ [저수조실] ⇄ [육묘실]  (재배실↔격납고, 전실↔창고)

const FLOOR_Y := 486
const TILE_HEIGHT := 560                # 옛 스트립 높이 — 카메라 초기값 등 호환용
const FRONT_DOOR_W := 315
const START_ROOM := "airlock"           # 메인 게임 시작 방
const TEST_ROOM := "tank_room"          # 테스트(원버튼) 시작 방 — 물이 고인 저수조실 (액체 셰이더 확인용)

const PROP_DIR := "res://assets/props/"
const CONNECTOR_DIR := "res://assets/connectors/"
const POWER_RELAY_DIR := "res://assets/power_relay_room/"
const LIGHTS_DIR := "res://assets/lights/"

const FRONT_DOOR_TEX := CONNECTOR_DIR + "front_bulkhead_door_game_scale.png"
const SIDE_DOOR_CLOSED_TEX := CONNECTOR_DIR + "sidewall_shutter_closed_edge_game_scale.png"
const SIDE_DOOR_OPEN_TEX := CONNECTOR_DIR + "sidewall_shutter_open_frame_game_scale.png"

const ZONE_WORKSHOP := "정비 구역"
const ZONE_POWER := "전력 구역"
const ZONE_CREW := "승무원 구역"
const ZONE_HYDRO := "수경재배 구역"

const GROW_LIGHT := Color(0.72, 1.0, 0.82)      # 수경재배 형광등(생장등) 색
const WARM_LIGHT := Color(1.0, 0.54, 0.25)      # 전력실 텅스텐 색

const ROOMS := {
	# ───────────────────────────── 정비 구역 (workshop) ─────────────────────────────
	"airlock": {
		# 시작 방. 작고 안전하다 — 몬스터 없음.
		"title": "에어록 (Airlock)", "zone": ZONE_WORKSHOP, "theme": "workshop",
		"shape": [[7, 5]],
		"left_door": {"open": false}, "right_door": {"open": true, "target": "corr_west"},
		"front_doors": [],
		"props": [
			{"tex": "workshop_locker_game_scale", "x": 320},
			{"tex": "workshop_armchair_game_scale", "x": 610},
		],
		"lamps": [448],
		"fixtures": [],
		"fx": [
			{"type": "leak", "x": 560, "cy": 96, "dir": Vector2(0.3, 1.0), "pressure": 0.6},
		],
		"monsters": [], "spawn": {"max": 0, "interval": [9.0, 9.0]},
	},
	"corr_west": {
		# 길고 낮은 복도. 적음. 정면문으로 숙소 복도와 이어진다.
		"title": "서쪽 정비 통로 (West Passage)", "zone": ZONE_WORKSHOP, "theme": "corridor",
		"shape": [[18, 4]],
		"left_door": {"open": true, "target": "airlock"}, "right_door": {"open": true, "target": "workshop"},
		"front_doors": [{"x": 1000, "target": "quarters_corr", "target_door": 0}],
		"props": [],
		"lamps": [500, 1800],
		"fixtures": [{"file": "fluorescent_lamp", "x": 1400, "cy": 52, "radius": 260}],
		"fx": [
			{"type": "beacon", "x": 700, "cy": 90},
			{"type": "wire", "x": 1560, "cy": 44, "length": 220.0},
			{"type": "fire", "x": 1950, "size": Vector2(150.0, 190.0)},
		],
		"monsters": [{"type": "crawler", "x": 1500, "facing": -1}],
		"spawn": {"max": 3, "interval": [3.0, 5.0]},
	},
	"workshop": {
		# 가운데가 한 단 높은 작업실 (천창 형태). 적음.
		"title": "작업실 (Workshop)", "zone": ZONE_WORKSHOP, "theme": "workshop",
		"shape": [[3, 5], [8, 7], [3, 5]],
		"left_door": {"open": true, "target": "corr_west"}, "right_door": {"open": true, "target": "hall"},
		"front_doors": [],
		"props": [
			{"tex": "workshop_locker_game_scale", "x": 260},
			{"tex": "workshop_workbench_game_scale", "x": 760},
			{"type": "sentry", "x": 1230},
			{"tex": "workshop_armchair_game_scale", "x": 1500},
		],
		"lamps": [420, 900, 1380],
		"fixtures": [
			{"file": "wall_lamp", "x": 110, "cy": 150, "radius": 180},
			{"file": "wall_lamp", "x": 1680, "cy": 150, "radius": 180},
		],
		"fx": [
			{"type": "beacon", "x": 1370, "cy": 130},
			{"type": "leak", "x": 462, "cy": 100, "dir": Vector2(0.42, 1.0), "pressure": 1.0},
			{"type": "wire", "x": 1230, "cy": 44, "length": 300.0},
		],
		"monsters": [
			{"type": "crawler", "x": 1000, "facing": -1},
			{"type": "crawler", "x": 320, "facing": 1},
		],
		"spawn": {"max": 4, "interval": [2.2, 4.0]},
	},
	"hall": {
		# 성당형 대형 홀 — 중앙 고층부 8행 + 양 날개 5행. 아주 많음. 정면문으로 전력 릴레이실.
		"title": "대형 정비 홀 (Assembly Hall)", "zone": ZONE_WORKSHOP, "theme": "workshop",
		"shape": [[5, 5], [14, 8], [5, 5]],
		"left_door": {"open": true, "target": "workshop"}, "right_door": {"open": true, "target": "corr_mid"},
		"front_doors": [{"x": 2250, "target": "power_relay", "target_door": 0}],
		"props": [
			{"tex": "workshop_locker_game_scale", "x": 330},
			{"tex": "workshop_workbench_game_scale", "x": 900},
			{"tex": "workshop_armchair_game_scale", "x": 1500},
			{"tex": "workshop_workbench_game_scale", "x": 1900},
			{"tex": "workshop_locker_game_scale", "x": 2800},
		],
		"lamps": [800, 1300, 1800, 2300],
		"fixtures": [
			{"file": "wall_lamp", "x": 320, "cy": 150, "radius": 180},
			{"file": "wall_lamp", "x": 2750, "cy": 150, "radius": 180},
		],
		"fx": [
			{"type": "beacon", "x": 700, "cy": 74},
			{"type": "beacon", "x": 2370, "cy": 74},
			{"type": "wire", "x": 1180, "cy": 48, "length": 520.0},
			{"type": "wire", "x": 1900, "cy": 48, "length": 460.0},
			{"type": "wire", "x": 2860, "cy": 44, "length": 190.0},
			{"type": "leak", "x": 420, "cy": 164, "dir": Vector2(0.45, 1.0), "pressure": 1.0},
			{"type": "fire", "x": 1380, "size": Vector2(190.0, 240.0)},
		],
		"monsters": [
			{"type": "crawler", "x": 1100, "facing": 1},
			{"type": "crawler", "x": 1800, "facing": -1},
			{"type": "crawler", "x": 2550, "facing": -1},
		],
		"spawn": {"max": 10, "interval": [1.4, 2.6]},
	},
	"corr_mid": {
		# 아주 짧은 연결 통로. 몬스터 없음 — 격납고 전의 숨 고르기.
		"title": "짧은 연결 통로 (Short Link)", "zone": ZONE_WORKSHOP, "theme": "corridor",
		"shape": [[5, 4]],
		"left_door": {"open": true, "target": "hall"}, "right_door": {"open": true, "target": "hangar"},
		"front_doors": [],
		"props": [],
		"lamps": [],
		"fixtures": [{"file": "fluorescent_lamp", "x": 320, "cy": 52, "radius": 260}],
		"fx": [{"type": "leak", "x": 440, "cy": 96, "dir": Vector2(-0.3, 1.0), "pressure": 0.7}],
		"monsters": [], "spawn": {"max": 0, "interval": [9.0, 9.0]},
	},
	"hangar": {
		# 가장 큰 방. 왼쪽 9행에서 오른왽 5행까지 계단처럼 내려가는 천장. 아주 많음. 정면문으로 대형 재배실.
		"title": "격납고 (Hangar)", "zone": ZONE_WORKSHOP, "theme": "workshop",
		"shape": [[6, 9], [6, 8], [8, 7], [6, 6], [6, 5]],
		"left_door": {"open": true, "target": "corr_mid"}, "right_door": {"open": true, "target": "storage"},
		"front_doors": [{"x": 2200, "target": "greenhouse", "target_door": 0}],
		"props": [
			{"tex": "workshop_locker_game_scale", "x": 300},
			{"tex": "workshop_workbench_game_scale", "x": 1000},
			{"type": "cart", "x": 1500},
			{"tex": "workshop_armchair_game_scale", "x": 1950},
			{"tex": "workshop_locker_game_scale", "x": 2700},
			{"tex": "workshop_workbench_game_scale", "x": 3150},
			{"type": "sentry", "x": 3495},
			{"tex": "workshop_locker_game_scale", "x": 3800},
		],
		"lamps": [500, 1200, 1900, 2600, 3300, 3900],
		"fixtures": [
			{"file": "dangling_lamp", "x": 760, "cy": 48, "radius": 240},
			{"file": "dangling_lamp", "x": 2900, "cy": 48, "radius": 240},
		],
		"fx": [
			{"type": "beacon", "x": 1560, "cy": 130},
			{"type": "beacon", "x": 3300, "cy": 130},
			{"type": "fire", "x": 2600, "size": Vector2(210.0, 260.0)},
			{"type": "leak", "x": 1636, "cy": 100, "dir": Vector2(0.5, 1.0), "pressure": 1.1},
			{"type": "leak", "x": 3934, "cy": 100, "dir": Vector2(-0.25, 1.0), "pressure": 0.8},
			{"type": "wire", "x": 700, "cy": 44, "length": 400.0},
			{"type": "wire", "x": 2980, "cy": 44, "length": 200.0},
		],
		"monsters": [
			{"type": "crawler", "x": 900, "facing": -1},
			{"type": "crawler", "x": 1500, "facing": -1},
			{"type": "crawler", "x": 2400, "facing": -1},
			{"type": "crawler", "x": 3150, "facing": -1},
			{"type": "crawler", "x": 3600, "facing": -1},
		],
		"spawn": {"max": 14, "interval": [1.2, 2.4]},
	},
	"storage": {
		# 낮은 창고(9열) + 오른쪽 끝의 9행 굴뚝(수직 샤프트, 4열). 적음. 정면문으로 재배실 전실. 동쪽 막다른 끝.
		"title": "창고 (Storage)", "zone": ZONE_WORKSHOP, "theme": "workshop",
		"shape": [[9, 4], [4, 9]],
		"left_door": {"open": true, "target": "hangar"}, "right_door": {"open": false},
		"front_doors": [{"x": 300, "target": "hydro_lock", "target_door": 0}],
		"props": [
			{"tex": "workshop_workbench_game_scale", "x": 900},
			{"tex": "workshop_locker_game_scale", "x": 1345},
		],
		"lamps": [500, 1400],
		"fixtures": [{"file": "wall_lamp", "x": 1230, "cy": 400, "radius": 180}],
		"fx": [
			{"type": "leak", "x": 606, "cy": 100, "dir": Vector2(0.35, 1.0), "pressure": 0.9},
			{"type": "wire", "x": 1330, "cy": 44, "length": 520.0},
			{"type": "beacon", "x": 1560, "cy": 200},
		],
		"monsters": [
			{"type": "crawler", "x": 1100, "facing": -1},
			{"type": "crawler", "x": 700, "facing": -1},
		],
		"spawn": {"max": 3, "interval": [2.5, 4.5]},
	},

	# ───────────────────────────── 전력 구역 (power_relay) ─────────────────────────────
	"cable_run": {
		# 길고 낮은 케이블 덕트. 적음. 서쪽 막다른 끝.
		"title": "케이블 덕트 (Cable Run)", "zone": ZONE_POWER, "theme": "power_relay",
		"shape": [[16, 4]],
		"left_door": {"open": false}, "right_door": {"open": true, "target": "power_relay"},
		"front_doors": [],
		"props": [
			{"tex": POWER_RELAY_DIR + "Props/power_relay_conduit_junction.png", "x": 500, "fy": 300},
			{"type": "breaker", "x": 1000, "fy": 330},
			{"tex": POWER_RELAY_DIR + "Props/power_relay_conduit_junction.png", "x": 1500, "fy": 300},
		],
		"lamps": [1250],
		"fixtures": [
			{"file": "fluorescent_lamp", "x": 400, "cy": 52, "radius": 260, "color": WARM_LIGHT},
			{"file": "fluorescent_lamp", "x": 1700, "cy": 52, "radius": 260, "color": WARM_LIGHT},
		],
		"fx": [
			{"type": "power_cable", "x": 300, "cy": 54, "length": 180.0},
			{"type": "power_cable", "x": 900, "cy": 54, "length": 200.0},
			{"type": "power_cable", "x": 1600, "cy": 54, "length": 160.0},
			{"type": "beacon", "x": 1100, "cy": 100},
		],
		"monsters": [{"type": "crawler", "x": 1400, "facing": -1}],
		"spawn": {"max": 3, "interval": [3.0, 5.0]},
	},
	"power_relay": {
		# 8행 높이의 전력 릴레이·축전실. 보통. 정면문으로 대형 정비 홀.
		"title": "전력 릴레이·축전실 (Power Relay Room)", "zone": ZONE_POWER, "theme": "power_relay",
		"shape": [[14, 8]],
		"left_door": {"open": true, "target": "cable_run"}, "right_door": {"open": true, "target": "capacitor_vault"},
		"front_doors": [{"x": 560, "target": "hall", "target_door": 0}],
		"props": [
			{"type": "cabinet", "x": 310},
			{"type": "capacitor", "x": 1050},
			{"type": "breaker", "x": 1190, "cy": 240},
			{"type": "cart", "x": 1480},
		],
		"lamps": [],
		"fixtures": [
			{"file": "ceiling_lamp", "x": 520, "cy": 112, "radius": 280, "color": WARM_LIGHT},
			{"file": "wall_lamp", "x": 1130, "cy": 330, "radius": 190, "color": WARM_LIGHT},
			{"file": "indicator_beacon", "x": 1180, "cy": 150, "radius": 150, "color": WARM_LIGHT},
		],
		"fx": [
			{"type": "power_cable", "x": 430, "cy": 78, "length": 300.0},
			{"type": "power_cable", "x": 930, "cy": 78, "length": 250.0},
			{"type": "power_cable", "x": 1420, "cy": 92, "length": 210.0},
		],
		"monsters": [
			{"type": "crawler", "x": 620, "facing": 1},
			{"type": "crawler", "x": 1320, "facing": -1},
		],
		"spawn": {"max": 5, "interval": [2.0, 3.8]},
	},
	"capacitor_vault": {
		# ㄱ자 — 왼쪽 6열은 9행 높이, 오른쪽 8열은 5행. 아주 많음.
		"title": "축전기 저장고 (Capacitor Vault)", "zone": ZONE_POWER, "theme": "power_relay",
		"shape": [[6, 9], [8, 5]],
		"left_door": {"open": true, "target": "power_relay"}, "right_door": {"open": true, "target": "generator"},
		"front_doors": [],
		"props": [
			{"type": "capacitor", "x": 330},
			{"type": "cabinet", "x": 720},
			{"type": "capacitor", "x": 1150},
			{"type": "breaker", "x": 1450, "cy": 200},
			{"type": "cart", "x": 1500},
		],
		"lamps": [],
		"fixtures": [
			{"file": "dangling_lamp", "x": 380, "cy": 48, "radius": 240, "color": WARM_LIGHT},
			{"file": "dangling_lamp", "x": 600, "cy": 48, "radius": 240, "color": WARM_LIGHT},
			{"file": "ceiling_lamp", "x": 1150, "cy": 112, "radius": 280, "color": WARM_LIGHT},
			{"file": "indicator_beacon", "x": 1500, "cy": 120, "radius": 150, "color": WARM_LIGHT},
		],
		"fx": [
			{"type": "power_cable", "x": 200, "cy": 78, "length": 420.0},
			{"type": "power_cable", "x": 560, "cy": 78, "length": 380.0},
			{"type": "beacon", "x": 1000, "cy": 90},
			{"type": "power_cable", "x": 1350, "cy": 70, "length": 160.0},
		],
		"monsters": [
			{"type": "crawler", "x": 500, "facing": 1},
			{"type": "crawler", "x": 1000, "facing": -1},
			{"type": "crawler", "x": 1400, "facing": -1},
		],
		"spawn": {"max": 9, "interval": [1.5, 2.8]},
	},
	"generator": {
		# 작은 비상 발전실. 몬스터 없음 — 전력 구역의 대피소. 정면문으로 식당. 동쪽 막다른 끝.
		"title": "비상 발전실 (Emergency Generator)", "zone": ZONE_POWER, "theme": "power_relay",
		"shape": [[9, 5]],
		"left_door": {"open": true, "target": "capacitor_vault"}, "right_door": {"open": false},
		"front_doors": [{"x": 540, "target": "mess_hall", "target_door": 1}],
		"props": [{"type": "cabinet", "x": 330}],
		"lamps": [],
		"fixtures": [
			{"file": "wall_lamp", "x": 200, "cy": 150, "radius": 190, "color": WARM_LIGHT},
			{"file": "floor_work_light", "x": 950, "fy": 66, "radius": 320, "color": WARM_LIGHT},
		],
		"fx": [{"type": "power_cable", "x": 700, "cy": 60, "length": 200.0}],
		"monsters": [], "spawn": {"max": 0, "interval": [9.0, 9.0]},
	},

	# ───────────────────────────── 승무원 구역 (crewquarters) ─────────────────────────────
	"quarters_corr": {
		# 숙소 복도. 적음. 정면문 둘 — 서쪽 정비 통로, 식당.
		"title": "숙소 복도 (Quarters Corridor)", "zone": ZONE_CREW, "theme": "corridor",
		"shape": [[14, 4]],
		"left_door": {"open": true, "target": "bunk_a"}, "right_door": {"open": true, "target": "bunk_b"},
		"front_doors": [
			{"x": 300, "target": "corr_west", "target_door": 0},
			{"x": 1150, "target": "mess_hall", "target_door": 0},
		],
		"props": [],
		"lamps": [900],
		"fixtures": [
			{"file": "fluorescent_lamp", "x": 700, "cy": 52, "radius": 260},
			{"file": "fluorescent_lamp", "x": 1450, "cy": 52, "radius": 260},
		],
		"fx": [
			{"type": "wire", "x": 1000, "cy": 44, "length": 220.0},
			{"type": "beacon", "x": 600, "cy": 90},
		],
		"monsters": [{"type": "crawler", "x": 1200, "facing": -1}],
		"spawn": {"max": 3, "interval": [3.0, 5.0]},
	},
	"bunk_a": {
		# 작은 침실. 몬스터 없음. 서쪽 막다른 끝.
		"title": "침실 A (Bunk Room A)", "zone": ZONE_CREW, "theme": "crewquarters",
		"shape": [[9, 5]],
		"left_door": {"open": false}, "right_door": {"open": true, "target": "quarters_corr"},
		"front_doors": [],
		"props": [
			{"tex": "crew_bunk_left", "x": 345},
			{"tex": "crew_bedside_cabinet", "x": 580},
			{"tex": "crew_privacy_screen", "x": 780},
			{"tex": "crew_heater", "x": 985},
		],
		"lamps": [576],
		"fixtures": [{"file": "wall_lamp", "x": 200, "cy": 140, "radius": 180}],
		"fx": [{"type": "leak", "x": 1000, "cy": 100, "dir": Vector2(-0.3, 1.0), "pressure": 0.5}],
		"monsters": [], "spawn": {"max": 0, "interval": [9.0, 9.0]},
	},
	"bunk_b": {
		# H자 — 양 끝 6행, 가운데 4행으로 낮아지는 침실. 적음.
		"title": "침실 B (Bunk Room B)", "zone": ZONE_CREW, "theme": "crewquarters",
		"shape": [[4, 6], [6, 4], [4, 6]],
		"left_door": {"open": true, "target": "quarters_corr"}, "right_door": {"open": true, "target": "mess_hall"},
		"front_doors": [],
		"props": [
			{"tex": "crew_bunk_right", "x": 330},
			{"tex": "crew_bedside_cabinet", "x": 560},
			{"tex": "crew_bunk_left", "x": 950},
			{"tex": "crew_heater", "x": 1250},
			{"tex": "crew_privacy_screen", "x": 1470},
		],
		"lamps": [256, 1536],
		"fixtures": [{"file": "fluorescent_lamp", "x": 896, "cy": 52, "radius": 260}],
		"fx": [
			{"type": "wire", "x": 1400, "cy": 44, "length": 240.0},
			{"type": "leak", "x": 700, "cy": 96, "dir": Vector2(0.3, 1.0), "pressure": 0.7},
		],
		"monsters": [{"type": "crawler", "x": 1100, "facing": -1}],
		"spawn": {"max": 3, "interval": [2.6, 4.6]},
	},
	"mess_hall": {
		# 가운데가 높은 식당·휴게실. 아주 많음. 정면문 둘 — 숙소 복도, 비상 발전실.
		"title": "식당·휴게실 (Mess Hall)", "zone": ZONE_CREW, "theme": "crewquarters",
		"shape": [[4, 5], [10, 7], [4, 5]],
		"left_door": {"open": true, "target": "bunk_b"}, "right_door": {"open": true, "target": "wash_room"},
		"front_doors": [
			{"x": 330, "target": "quarters_corr", "target_door": 1},
			{"x": 1700, "target": "generator", "target_door": 0},
		],
		"props": [
			{"tex": "workshop_armchair_game_scale", "x": 760},
			{"tex": "crew_bedside_cabinet", "x": 1000},
			{"tex": "workshop_armchair_game_scale", "x": 1220},
			{"tex": "crew_heater", "x": 1450},
		],
		"lamps": [700, 1150, 1600],
		"fixtures": [
			{"file": "wall_lamp", "x": 150, "cy": 150, "radius": 180},
			{"file": "wall_lamp", "x": 2150, "cy": 150, "radius": 180},
		],
		"fx": [
			{"type": "beacon", "x": 1900, "cy": 74},
			{"type": "fire", "x": 1300, "size": Vector2(170.0, 210.0)},
			{"type": "wire", "x": 900, "cy": 44, "length": 360.0},
			{"type": "leak", "x": 2100, "cy": 164, "dir": Vector2(-0.4, 1.0), "pressure": 0.85},
		],
		"monsters": [
			{"type": "crawler", "x": 900, "facing": -1},
			{"type": "crawler", "x": 1500, "facing": -1},
			{"type": "crawler", "x": 2000, "facing": -1},
		],
		"spawn": {"max": 10, "interval": [1.4, 2.6]},
	},
	"wash_room": {
		# 낮은 세면실. 바닥에 물이 얕게 고여 있다. 아주 적음. 동쪽 막다른 끝.
		"title": "세면실 (Wash Room)", "zone": ZONE_CREW, "theme": "crewquarters",
		"shape": [[7, 4]],
		"left_door": {"open": true, "target": "mess_hall"}, "right_door": {"open": false},
		"front_doors": [],
		"props": [
			{"tex": "crew_wash_station", "x": 330},
			{"tex": "crew_wash_station", "x": 560},
		],
		"lamps": [448],
		"fixtures": [],
		"fx": [
			{"type": "leak", "x": 300, "cy": 96, "dir": Vector2(0.3, 1.0), "pressure": 1.0},
			{"type": "leak", "x": 600, "cy": 96, "dir": Vector2(-0.3, 1.0), "pressure": 0.9},
			{"type": "water", "level": 14},
		],
		"monsters": [{"type": "crawler", "x": 650, "facing": -1}],
		"spawn": {"max": 2, "interval": [3.5, 6.0]},
	},

	# ───────────────────────────── 수경재배 구역 (hydroponics) ─────────────────────────────
	"hydro_lock": {
		# 재배실 전실. 몬스터 없음. 정면문으로 창고. 서쪽 막다른 끝.
		"title": "재배실 전실 (Hydroponics Vestibule)", "zone": ZONE_HYDRO, "theme": "hydroponics",
		"shape": [[7, 5]],
		"left_door": {"open": false}, "right_door": {"open": true, "target": "greenhouse"},
		"front_doors": [{"x": 230, "target": "storage", "target_door": 0}],
		"props": [{"tex": "hydroponics_utility_sink", "x": 640}],
		"lamps": [448],
		"fixtures": [],
		"fx": [{"type": "leak", "x": 620, "cy": 96, "dir": Vector2(0.0, 1.0), "pressure": 0.5}],
		"monsters": [], "spawn": {"max": 0, "interval": [9.0, 9.0]},
	},
	"greenhouse": {
		# 피라미드형 — 양 끝 5행에서 한 단씩 올라가 중앙 9행. 아주 많음. 정면문으로 격납고.
		"title": "대형 재배실 (Greenhouse)", "zone": ZONE_HYDRO, "theme": "hydroponics",
		"shape": [[4, 5], [4, 6], [4, 7], [6, 9], [4, 7], [4, 6], [4, 5]],
		"left_door": {"open": true, "target": "hydro_lock"}, "right_door": {"open": true, "target": "pump_corr"},
		"front_doors": [{"x": 1750, "target": "hangar", "target_door": 0}],
		"props": [
			{"tex": "hydroponics_growth_tank_full", "x": 350},
			{"tex": "hydroponics_plant_rack", "x": 650},
			{"tex": "hydroponics_growth_tank_narrow", "x": 950},
			{"tex": "hydroponics_control_console", "x": 1250},
			{"tex": "hydroponics_plant_rack", "x": 1500},
			{"tex": "hydroponics_growth_tank_tall", "x": 2250},
			{"tex": "hydroponics_plant_rack", "x": 2600},
			{"tex": "hydroponics_growth_tank_full", "x": 2950},
			{"tex": "hydroponics_utility_sink", "x": 3250},
			{"tex": "hydroponics_growth_tank_narrow", "x": 3550},
		],
		"lamps": [500, 1200, 1900, 2600, 3300],
		"fixtures": [
			{"file": "fluorescent_lamp", "x": 800, "cy": 52, "radius": 280, "color": GROW_LIGHT},
			{"file": "fluorescent_lamp", "x": 1600, "cy": 52, "radius": 280, "color": GROW_LIGHT},
			{"file": "fluorescent_lamp", "x": 2200, "cy": 52, "radius": 280, "color": GROW_LIGHT},
			{"file": "fluorescent_lamp", "x": 3000, "cy": 52, "radius": 280, "color": GROW_LIGHT},
		],
		"fx": [
			{"type": "leak", "x": 1100, "cy": 100, "dir": Vector2(0.4, 1.0), "pressure": 1.0},
			{"type": "leak", "x": 2800, "cy": 100, "dir": Vector2(-0.3, 1.0), "pressure": 0.9},
			{"type": "wire", "x": 1650, "cy": 48, "length": 500.0},
			{"type": "wire", "x": 2150, "cy": 48, "length": 420.0},
			{"type": "beacon", "x": 3400, "cy": 74},
		],
		"monsters": [
			{"type": "crawler", "x": 800, "facing": 1},
			{"type": "crawler", "x": 1600, "facing": -1},
			{"type": "crawler", "x": 2400, "facing": -1},
			{"type": "crawler", "x": 3200, "facing": -1},
		],
		"spawn": {"max": 12, "interval": [1.3, 2.5]},
	},
	"pump_corr": {
		# 낮은 급수 통로, 가운데에 6행 펌프 알코브가 솟아 있다. 적음.
		"title": "급수 통로 (Pump Corridor)", "zone": ZONE_HYDRO, "theme": "corridor",
		"shape": [[5, 4], [4, 6], [6, 4]],
		"left_door": {"open": true, "target": "greenhouse"}, "right_door": {"open": true, "target": "tank_room"},
		"front_doors": [],
		"props": [
			{"tex": POWER_RELAY_DIR + "Props/power_relay_conduit_junction.png", "x": 900, "fy": 300},
			{"tex": "hydroponics_utility_sink", "x": 1400},
		],
		"lamps": [896],
		"fixtures": [
			{"file": "fluorescent_lamp", "x": 350, "cy": 52, "radius": 260},
			{"file": "fluorescent_lamp", "x": 1550, "cy": 52, "radius": 260},
		],
		"fx": [
			{"type": "leak", "x": 800, "cy": 96, "dir": Vector2(0.2, 1.0), "pressure": 1.2},
			{"type": "power_cable", "x": 1000, "cy": 60, "length": 280.0},
			{"type": "beacon", "x": 1700, "cy": 90},
		],
		"monsters": [{"type": "crawler", "x": 1300, "facing": -1}],
		"spawn": {"max": 3, "interval": [2.8, 4.8]},
	},
	"tank_room": {
		# 6행 저수조실 — 바닥에 물이 고여 반사된다. 적음.
		"title": "저수조실 (Reservoir)", "zone": ZONE_HYDRO, "theme": "hydroponics",
		"shape": [[12, 6]],
		"left_door": {"open": true, "target": "pump_corr"}, "right_door": {"open": true, "target": "nursery"},
		"front_doors": [],
		"props": [
			{"tex": "hydroponics_growth_tank_full", "x": 330},
			{"tex": "hydroponics_growth_tank_tall", "x": 520},
			{"tex": "hydroponics_growth_tank_narrow", "x": 710},
			{"tex": "hydroponics_plant_rack", "x": 1000},
			{"tex": "hydroponics_control_console", "x": 1300},
		],
		"lamps": [500, 1100],
		"fixtures": [{"file": "fluorescent_lamp", "x": 800, "cy": 52, "radius": 280, "color": GROW_LIGHT}],
		"fx": [
			{"type": "water", "level": 26},
			{"type": "leak", "x": 450, "cy": 100, "dir": Vector2(0.4, 1.0), "pressure": 1.0},
			{"type": "leak", "x": 1200, "cy": 100, "dir": Vector2(-0.3, 1.0), "pressure": 0.8},
			{"type": "wire", "x": 1000, "cy": 44, "length": 220.0},
		],
		"monsters": [{"type": "crawler", "x": 900, "facing": -1}],
		"spawn": {"max": 3, "interval": [2.5, 4.5]},
	},
	"nursery": {
		# 육묘실. 몬스터 없음. 동쪽 막다른 끝.
		"title": "육묘실 (Nursery)", "zone": ZONE_HYDRO, "theme": "hydroponics",
		"shape": [[9, 5]],
		"left_door": {"open": true, "target": "tank_room"}, "right_door": {"open": false},
		"front_doors": [],
		"props": [
			{"tex": "hydroponics_plant_rack", "x": 330},
			{"tex": "hydroponics_plant_rack", "x": 620},
			{"tex": "hydroponics_growth_tank_narrow", "x": 850},
		],
		"lamps": [400, 800],
		"fixtures": [{"file": "fluorescent_lamp", "x": 576, "cy": 52, "radius": 280, "color": GROW_LIGHT}],
		"fx": [{"type": "leak", "x": 700, "cy": 96, "dir": Vector2(0.3, 1.0), "pressure": 0.5}],
		"monsters": [], "spawn": {"max": 0, "interval": [9.0, 9.0]},
	},
}


static func get_room(id: String) -> Dictionary:
	return ROOMS[id]


static func ids() -> Array:
	return ROOMS.keys()


static func random_id() -> String:
	var keys := ROOMS.keys()
	return keys[randi() % keys.size()]


## 열별 높이(셀) 배열
static func heights(id: String) -> Array:
	return RoomTiles.expand(ROOMS[id]["shape"])


## 방 기하: rows · origin(격자 원점) · width · ceiling_y(가장 높은 천장) · bottom_y
static func layout(id: String) -> Dictionary:
	return RoomTiles.layout(heights(id))


static func room_width(id: String) -> int:
	return int(layout(id)["width"])


## 가장 높은 천장 y (방 사각형 상단)
static func room_ceiling(id: String) -> int:
	return int(layout(id)["ceiling_y"])


## x 열의 천장 타일 상단 y
static func ceiling_at(id: String, x: float) -> float:
	return RoomTiles.ceiling_at(heights(id), x)


static func floor_y(_id: String) -> int:
	return FLOOR_Y


## 방을 감싸는 사각형 (가장 높은 천장 ~ 바닥 타일 하단). 카메라 중심·비상등 스윕·먼지 레이어 범위.
static func room_rect(id: String) -> Rect2:
	var lay := layout(id)
	return Rect2(0, lay["ceiling_y"], lay["width"], lay["bottom_y"] - lay["ceiling_y"])


## 정면문 index 의 바닥 중심 x (다른 방에서 이 문으로 들어올 때 등장 위치)
static func front_door_center(id: String, index: int) -> float:
	var doors: Array = ROOMS[id]["front_doors"]
	if index >= 0 and index < doors.size():
		return float(doors[index]["x"]) + FRONT_DOOR_W * 0.5
	return room_width(id) * 0.5


## 몬스터 밀도 등급 — 없음 / 적음 / 아주 많음 (HUD·맵 표시용)
static func danger(id: String) -> String:
	var cap := int(ROOMS[id].get("spawn", {}).get("max", 0))
	if cap <= 0:
		return "안전"
	if cap <= 5:
		return "적음"
	return "위험"
