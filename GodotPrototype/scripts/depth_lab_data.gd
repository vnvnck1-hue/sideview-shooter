class_name DepthLabData
extends RefCounted
## 공간감 테스트 씬(scenes/DepthLab.tscn)의 수치 — 공간 구역 · 발판/사다리 · 레이어 역할 · 패럴렉스 속도 · 조명 · 카메라 프리셋.
## 씬 설명과 근거: Docs/DEPTH_TEST_SCENE.md · 메탈슬러그 비교: Docs/BACKGROUND_RESEARCH_LOG.md §7
## 서사 근거: AI_Robot_Base_Narrative_Design_Notes.md (붕괴 중인 연구·산업 기지, UNIT-7) · Docs/STATION_MAP.md
##
## 좌표: 월드 px. 방 왼쪽 끝 x = 0. **높이 h 는 바닥선 위 px** (위가 +). 레이어 도형은 바닥선이 y 0, 위가 음수.
## 방 하나(ROOM_ID)에 구역 다섯이 한 줄로 이어진다 — 아래층 바닥은 끝까지 이어지고, 샤프트에서 올라가면
## 전력 홀 위 캣워크(윗길)로 이어져 끝에서 사다리로 다시 내려온다. 페이드·방 전환은 없다.

const ROOM_ID := "depth_lab"
const CELL := 128
const ART_CELL := 4.0
const THEME := "workshop"                  # 타일은 숨긴다 — 충돌(RoomSolid)과 몬스터 벽 타기만 방 모양을 쓴다

# ── 레이어 역할 ────────────────────────────────────────────────────────────────
## z 는 월드(Stage) 안 그리는 순서. 방 노드들(프랍 z2 · 먼지 z3~4 · 인물 z5~6)보다 배경은 뒤, 근경은 앞.
const ROLES := {
	"sky":    {"name": "배경판", "z": -80},
	"far3":   {"name": "원경 3", "z": -70},
	"far2":   {"name": "원경 2", "z": -60},
	"far1":   {"name": "원경 1", "z": -50},
	"back":   {"name": "뒤벽",   "z": -40},
	"ground": {"name": "땅",     "z": -30},
	"front":  {"name": "앞 난간", "z": 11},       # 발판 앞 모서리 난간 — 계수 1, 인물(5~6) 앞
	"fg1":    {"name": "근경 1", "z": 12},       # 조준점(z20) 아래
	"fg2":    {"name": "근경 2", "z": 14},
}
const ORDER := ["sky", "far3", "far2", "far1", "back", "ground", "fg1", "fg2"]

## 레이어 구성 (L) — 많음 / 기본 / 적음
const COMPOSITIONS := [
	{"id": "many", "name": "많음 8", "roles": ["sky", "far3", "far2", "far1", "back", "ground", "fg1", "fg2"]},
	{"id": "mid", "name": "기본 6", "roles": ["sky", "far2", "far1", "back", "ground", "fg1"]},
	{"id": "few", "name": "적음 4", "roles": ["sky", "far2", "ground", "fg1"]},
]
const COMPOSITION_DEFAULT := 0

## 패럴렉스 속도 프리셋 (1 · 2 · 3). 가로·세로 모두 같은 계수로 움직인다 (세로 공간에서 먼 곳이 덜 올라간다).
const SPEED_PRESETS := [
	{"id": "shallow", "name": "① 얕은 무대",
		"f": {"sky": 0.30, "far3": 0.45, "far2": 0.58, "far1": 0.72, "back": 0.88, "ground": 1.0, "fg1": 1.10, "fg2": 1.22}},
	{"id": "arcade", "name": "② 아케이드 표준",
		"f": {"sky": 0.06, "far3": 0.18, "far2": 0.32, "far1": 0.52, "back": 0.80, "ground": 1.0, "fg1": 1.30, "fg2": 1.65}},
	{"id": "deep", "name": "③ 깊은 공동",
		"f": {"sky": 0.00, "far3": 0.06, "far2": 0.16, "far1": 0.36, "back": 0.70, "ground": 1.0, "fg1": 1.60, "fg2": 2.30}},
]
const SPEED_DEFAULT := 1

# ── 카메라 워킹 프리셋 (C) ─────────────────────────────────────────────────────
## 앞 7 키는 GameCamera 프리셋과 같은 뜻이다 (mouse_weight · mouse_max_x/y · facing_lead · follow_speed · look_speed · deadzone).
## 뒤 키는 이 씬의 DepthCamFx 가 더한다:
##   hold      사격 버튼을 누르는 동안 마우스 리드 배율 (조준 밀어 넣기)
##   kick      한 발마다 조준 반대쪽으로 튕기는 양 (px) — 반동
##   punch     한 발마다 조준 쪽으로 밀리는 양 (px) — 사격 방향으로 화면이 쏠린다
##   vel_lead  이동 속도 × 초 만큼 앞을 내다본다
##   y_speed   발판 높이가 바뀔 때 세로가 따라가는 속도
##   drift     느린 숨쉬기 흔들림 (px)
const CAMERA_PRESETS := [
	{"id": "standard", "name": "표준", "desc": "본편 기본값 — 포인터 쪽 1/3 까지",
		"mouse_weight": 0.32, "mouse_max_x": 360.0, "mouse_max_y": 60.0, "facing_lead": 150.0,
		"follow_speed": 9.0, "look_speed": 6.0, "deadzone": 30.0,
		"hold": 1.0, "kick": 0.0, "punch": 0.0, "vel_lead": 0.0, "y_speed": 5.0, "drift": 0.0},
	{"id": "aim_push", "name": "조준 밀기", "desc": "쏘는 동안 포인터 쪽으로 화면을 크게 밀어 넣는다 — 위아래도 본다",
		"mouse_weight": 0.36, "mouse_max_x": 520.0, "mouse_max_y": 260.0, "facing_lead": 120.0,
		"follow_speed": 10.0, "look_speed": 7.0, "deadzone": 20.0,
		"hold": 1.9, "kick": 0.0, "punch": 5.0, "vel_lead": 0.0, "y_speed": 6.0, "drift": 0.0},
	{"id": "recoil", "name": "반동 킥", "desc": "한 발마다 화면이 조준 반대로 튕겼다 돌아온다 — 총이 무겁게 느껴진다",
		"mouse_weight": 0.30, "mouse_max_x": 380.0, "mouse_max_y": 120.0, "facing_lead": 150.0,
		"follow_speed": 11.0, "look_speed": 8.0, "deadzone": 30.0,
		"hold": 1.2, "kick": 16.0, "punch": 0.0, "vel_lead": 0.0, "y_speed": 6.0, "drift": 0.0},
	{"id": "twin", "name": "중간점 (트윈스틱)", "desc": "캐릭터와 포인터의 가운데를 본다 — 멀리 쏠수록 멀리 보인다",
		"mouse_weight": 0.50, "mouse_max_x": 900.0, "mouse_max_y": 420.0, "facing_lead": 0.0,
		"follow_speed": 14.0, "look_speed": 10.0, "deadzone": 0.0,
		"hold": 1.0, "kick": 6.0, "punch": 0.0, "vel_lead": 0.0, "y_speed": 8.0, "drift": 0.0},
	{"id": "momentum", "name": "속도 앞보기", "desc": "달리는 방향으로 먼저 열린다. 멈추면 캐릭터 쪽으로 돌아온다",
		"mouse_weight": 0.22, "mouse_max_x": 300.0, "mouse_max_y": 90.0, "facing_lead": 60.0,
		"follow_speed": 7.0, "look_speed": 4.0, "deadzone": 40.0,
		"hold": 1.3, "kick": 4.0, "punch": 0.0, "vel_lead": 0.55, "y_speed": 4.0, "drift": 0.0},
	{"id": "cinema", "name": "시네마틱", "desc": "느리게 따라오고 크게 내다본다. 숨쉬듯 흔들린다 — 넓은 공간을 보여 주는 용도",
		"mouse_weight": 0.26, "mouse_max_x": 640.0, "mouse_max_y": 320.0, "facing_lead": 260.0,
		"follow_speed": 3.2, "look_speed": 2.2, "deadzone": 60.0,
		"hold": 1.1, "kick": 3.0, "punch": 0.0, "vel_lead": 0.25, "y_speed": 2.5, "drift": 10.0},
	{"id": "snappy", "name": "민첩", "desc": "본편 민첩형 + 반동. 즉각적이고 공격적",
		"mouse_weight": 0.62, "mouse_max_x": 720.0, "mouse_max_y": 200.0, "facing_lead": 260.0,
		"follow_speed": 15.0, "look_speed": 12.0, "deadzone": 0.0,
		"hold": 1.25, "kick": 9.0, "punch": 3.0, "vel_lead": 0.0, "y_speed": 9.0, "drift": 0.0},
]
const CAMERA_DEFAULT := 1

# ── 공간 구역 ──────────────────────────────────────────────────────────────────
## x0/x1: 구역 범위 · cols: 열 프로필 [[폭 셀, 높이 셀]] (합이 (x1-x0)/128)
## axis: 구도 성격 (X 가로 · Y 세로 · XY 복합) — 정보 표시용
## zoom: 들어서면 옮겨 가는 줌 단계 (표준 0 · 넓게 −1 · 가깝게 +1)
## frame: 세로 프레이밍 (0 = 본편처럼 바닥을 화면 62% 에 · 1 = 몸을 화면 가운데 — 위아래를 같이 봐야 하는 세로 공간)
## ambient: 인물이 받는 기본 밝기 (구역 경계에서 섞인다) · f_over: 이 구역에서만 바꾸는 패럴렉스 계수
## tone: 공기 원근 모델 — base = lerp(albedo, fog, haze[역할]) · 면 대비 × (1 − haze)
##       key: 주광 방향 ("top" 위에서 · "bottom" 아래에서 올라오는 빛 · "back" 역광 — 윗모서리 림)
const ZONES := [
	{"id": "dock", "name": "도킹 관측 회랑", "axis": "X",
		"desc": "외벽 쪽 긴 회랑. 유리창 너머로 행성 가장자리와 자매 정거장이 보인다 — 가장 넓은 공간",
		"x0": 0, "x1": 4096, "cols": [[32, 10]], "zoom": -1, "frame": 0.0, "ambient": 0.80,
		"tone": {"fog": 0.10, "albedo": 0.30, "haze": {"far3": 0.55, "far2": 0.45, "far1": 0.30, "back": 0.12, "ground": 0.0},
			"sky": [0.01, 0.05, 0.03], "fg": {"fg1": 0.04, "fg2": 0.02}, "rim": 0.34, "key": "back",
			"floor_top": 0.46, "floor_face": 0.12, "prop": 0.30, "lamp": 0.55, "height_fog": 0.0,
			"tint_far": Color(0.86, 0.95, 1.14), "tint_lamp": Color(0.9, 1.0, 1.1)}},
	{"id": "hangar", "name": "다층 정비 격납고", "axis": "XY",
		"desc": "상자를 밟고 1층 갠트리로, 사다리로 2층 갠트리로. 천장 투광등이 층마다 빛 웅덩이를 떨군다",
		"x0": 4096, "x1": 8960, "cols": [[2, 9], [34, 12], [2, 9]], "zoom": 0, "frame": 0.35, "ambient": 0.72,
		"tone": {"fog": 0.08, "albedo": 0.40, "haze": {"far3": 0.84, "far2": 0.68, "far1": 0.48, "back": 0.26, "ground": 0.0},
			"sky": [0.02, 0.08, 0.05], "fg": {"fg1": 0.035, "fg2": 0.015}, "rim": 0.12, "key": "top",
			"floor_top": 0.46, "floor_face": 0.15, "prop": 0.36, "lamp": 1.0, "height_fog": 0.65,
			"tint_far": Color(0.92, 0.97, 1.08), "tint_lamp": Color(1.14, 1.0, 0.78)}},
	{"id": "duct", "name": "환풍 덕트", "axis": "X",
		"desc": "머리 위가 바로 막힌 좁은 통로. 기어가야 하는 구간 뒤로 거대 환풍기실이 열린다 — 회전 날개가 빛을 자른다",
		"x0": 8960, "x1": 12288, "cols": [[2, 5], [8, 3], [8, 7], [6, 3], [2, 5]], "zoom": 1, "frame": 0.1, "ambient": 0.45,
		"f_over": {"back": 0.96, "far1": 0.82},
		"tone": {"fog": 0.02, "albedo": 0.34, "haze": {"far3": 0.9, "far2": 0.8, "far1": 0.55, "back": 0.10, "ground": 0.0},
			"sky": [0.0, 0.02, 0.01], "fg": {"fg1": 0.02, "fg2": 0.01}, "rim": 0.10, "key": "top",
			"floor_top": 0.34, "floor_face": 0.08, "prop": 0.26, "lamp": 0.85, "height_fog": 0.8,
			"tint_far": Color(0.95, 1.0, 1.05), "tint_lamp": Color(1.15, 0.72, 0.6)}},
	{"id": "shaft", "name": "수직 케이블 샤프트", "axis": "Y",
		"desc": "사다리와 턱을 번갈아 밟고 2,200px 를 오른다. 위는 채광 빛, 아래는 어둠 — 올라갈수록 밝아진다",
		"x0": 12288, "x1": 13952, "cols": [[13, 27]], "zoom": -1, "frame": 1.0, "ambient": 0.55,
		"tone": {"fog": 0.04, "albedo": 0.32, "haze": {"far3": 0.86, "far2": 0.72, "far1": 0.50, "back": 0.18, "ground": 0.0},
			"sky": [0.10, 0.03, 0.0], "fg": {"fg1": 0.03, "fg2": 0.012}, "rim": 0.16, "key": "top",
			"floor_top": 0.38, "floor_face": 0.10, "prop": 0.32, "lamp": 0.8, "height_fog": 0.9,
			"tint_far": Color(0.9, 0.97, 1.1), "tint_lamp": Color(1.1, 1.0, 0.85)}},
	{"id": "relay", "name": "전력 홀 상층 캣워크", "axis": "X+Y",
		"desc": "2,240px 높이의 캣워크. 아래는 코일 탑이 늘어선 전력 홀 — 빛이 아래에서 올라온다. 끊긴 구간은 달려서 뛴다",
		"x0": 13952, "x1": 18560, "cols": [[2, 21], [34, 27], [0, 0]], "zoom": -1, "frame": 0.55, "ambient": 0.62,
		"tone": {"fog": 0.05, "albedo": 0.28, "haze": {"far3": 0.80, "far2": 0.62, "far1": 0.42, "back": 0.20, "ground": 0.0},
			"sky": [0.0, 0.03, 0.10], "fg": {"fg1": 0.03, "fg2": 0.012}, "rim": 0.22, "key": "bottom",
			"floor_top": 0.40, "floor_face": 0.12, "prop": 0.30, "lamp": 1.0, "height_fog": 0.0,
			"tint_far": Color(1.12, 0.92, 0.76), "tint_lamp": Color(1.2, 0.86, 0.6)}},
]

## 발판 (높이 = 바닥 위 px)
##   oneway: 아래에서 뛰어 통과하고 위에서 선다. S + W 로 내려선다 (캣워크·갠트리·턱)
##   solid:  옆이 막힌 덩어리 (상자 더미·관측대). 위에 설 수 있고 옆으로는 못 지나간다
const PLATFORMS := [
	# 도킹 회랑 — 관측대 (계단 한 칸 + 단)
	{"x0": 1640, "x1": 1720, "h": 48, "kind": "solid", "look": "step"},
	{"x0": 1720, "x1": 1800, "h": 96, "kind": "solid", "look": "step"},
	{"x0": 1800, "x1": 2960, "h": 144, "kind": "solid", "look": "deck"},
	{"x0": 2960, "x1": 3040, "h": 96, "kind": "solid", "look": "step"},
	{"x0": 3040, "x1": 3120, "h": 48, "kind": "solid", "look": "step"},
	# 격납고 — 상자 두 단 → 1층 갠트리 → (사다리) → 2층 갠트리
	{"x0": 4880, "x1": 5040, "h": 160, "kind": "solid", "look": "crate"},
	{"x0": 5040, "x1": 5200, "h": 320, "kind": "solid", "look": "crate"},
	{"x0": 5200, "x1": 6720, "h": 360, "kind": "oneway", "look": "gantry"},
	{"x0": 6400, "x1": 7900, "h": 760, "kind": "oneway", "look": "gantry"},
	{"x0": 7300, "x1": 7460, "h": 160, "kind": "solid", "look": "crate"},
	# 덕트 — 환풍기실 가운데 점검대
	{"x0": 10420, "x1": 11080, "h": 240, "kind": "oneway", "look": "grate"},
	# 샤프트 — 좌우 턱을 번갈아 (사다리 A·B·C 와 점프로 잇는다)
	{"x0": 12344, "x1": 13100, "h": 600, "kind": "oneway", "look": "ledge"},
	{"x0": 13020, "x1": 13896, "h": 760, "kind": "oneway", "look": "ledge"},
	{"x0": 13020, "x1": 13896, "h": 1360, "kind": "oneway", "look": "ledge"},
	{"x0": 12344, "x1": 12980, "h": 1520, "kind": "oneway", "look": "ledge"},
	{"x0": 12344, "x1": 13300, "h": 2120, "kind": "oneway", "look": "ledge"},
	# 전력 홀 — 캣워크 (15600~15900 끊김 — 달려서 뛴다) · 크레인 발판 두 개로 내려가는 길
	{"x0": 13240, "x1": 15600, "h": 2240, "kind": "oneway", "look": "catwalk"},
	{"x0": 15900, "x1": 18480, "h": 2240, "kind": "oneway", "look": "catwalk"},
	{"x0": 16300, "x1": 16900, "h": 1440, "kind": "oneway", "look": "crane"},
	{"x0": 17200, "x1": 17700, "h": 720, "kind": "oneway", "look": "crane"},
]

## 사다리 [축 x, 아래 높이, 위 높이]
const LADDERS := [
	[6600, 360, 760],       # 격납고 1층 → 2층 갠트리
	[7840, 0, 760],         # 격납고 2층 → 바닥
	[12480, 0, 600],        # 샤프트 A
	[13780, 760, 1360],     # 샤프트 B
	[12420, 1520, 2120],    # 샤프트 C
	[18400, 0, 2240],       # 전력 홀 끝 — 캣워크에서 바닥까지 긴 사다리
]

## 머리 위 장애물 (월드 좌표 사각형 대신 [x0, x1, 틈 높이]) — 이 아래는 기어서만 지나간다
const CRAWLS := [
	[11520, 11904, 200],
]

## 시작 위치
const SPAWN_X := 900.0
const HALF_W := 34.0            # 플레이어 몸 반폭 (발판 판정)
const STEP := 52.0              # 걸어서 오르는 턱 한계 (관측대 계단 48)
const STAND_H := 267.0
const CROUCH_H := 150.0


static func world_w() -> int:
	var w := 0
	for z in ZONES:
		w = maxi(w, int(z["x1"]))
	return w


static func zone_index(x: float) -> int:
	for i in range(ZONES.size()):
		if x < float(ZONES[i]["x1"]):
			return i
	return ZONES.size() - 1


## x 에서 구역 i 가 차지하는 비중 (경계 ±BLEND 안에서 선형으로 섞인다)
const BLEND := 420.0
static func zone_weights(x: float) -> Array:
	var w: Array = []
	var total := 0.0
	for z in ZONES:
		var a := float(z["x0"])
		var b := float(z["x1"])
		var k := clampf((x - (a - BLEND)) / (2.0 * BLEND), 0.0, 1.0) * clampf(((b + BLEND) - x) / (2.0 * BLEND), 0.0, 1.0)
		w.append(k)
		total += k
	for i in range(w.size()):
		w[i] = w[i] / maxf(total, 0.0001)
	return w


static func zone_value(x: float, key: String) -> float:
	var w := zone_weights(x)
	var v := 0.0
	for i in range(ZONES.size()):
		v += float(ZONES[i][key]) * float(w[i])
	return v


static func factor(preset: int, role: String, zone := -1) -> float:
	if role == "ground" or role == "front":
		return 1.0
	if zone >= 0:
		var ov: Dictionary = ZONES[zone].get("f_over", {})
		if ov.has(role):
			return float(ov[role])
	return float(SPEED_PRESETS[preset]["f"][role])


## 역할의 대표 명도 (범례 견본·명도만 보기)
static func base_value(tone: Dictionary, role: String) -> float:
	match role:
		"sky":
			return float(tone["sky"][1])
		"fg1", "fg2":
			return float(tone["fg"][role])
		"ground":
			return float(tone["floor_top"])
	return lerpf(float(tone["albedo"]), float(tone["fog"]), float(tone["haze"][role]))


static func contrast(tone: Dictionary, role: String) -> float:
	if tone["haze"].has(role):
		return 1.0 - float(tone["haze"][role])
	return 1.0


## 방 열린 천장 (바닥 위 px) — 열 높이 n 셀이면 30 + 128(n−1) (RoomSolid.open_top_at 과 같은 식)
static func clearance_cells(n: int) -> float:
	return 30.0 + CELL * (n - 1)


# ── 방 등록 ────────────────────────────────────────────────────────────────────

static func register() -> String:
	RoomData.register_extra(ROOM_ID, build())
	return ROOM_ID


static func shape() -> Array:
	var s: Array = []
	for z in ZONES:
		for seg in z["cols"]:
			if int(seg[0]) > 0:
				s.append([int(seg[0]), int(seg[1])])
	return s


static func build() -> Dictionary:
	return {
		"title": "공간감 테스트 — 이어진 다섯 공간",
		"zone": RoomData.ZONE_WORKSHOP, "theme": THEME,
		"shape": shape(),
		"vista": false,
		"left_door": {"open": false}, "right_door": {"open": false},
		"front_doors": [],
		"props": [
			# 센트리건 — 바닥 해치 (받침 폭 376 · 높이 440 자리를 비워 둔다)
			{"type": "sentry", "id": "depth_sentry_hangar", "x": 8420},
			{"type": "sentry", "id": "depth_sentry_relay", "x": 16950},
			# 버그봇 (사족보행 기체) — 전력 홀 바닥
			{"type": "walker", "id": "depth_bugbot", "name": "버그봇 B-2", "x": 15200},
		],
		"lamps": [], "fixtures": [], "fx": [],
		"monsters": [
			{"type": "crawler", "x": 6000, "facing": -1},
			{"type": "crawler", "x": 7600, "facing": -1},
			{"type": "crawler", "x": 10800, "facing": -1},
			{"type": "crawler", "x": 14600, "facing": 1},
			{"type": "crawler", "x": 17800, "facing": -1},
		],
		"spawn": {
			"max": 9, "interval": [2.4, 4.2], "band": 2600.0, "giant": 0.08,
			"wave": {"interval": 34.0, "size": [3, 5], "gap": 0.5, "first": 20.0},
		},
	}
