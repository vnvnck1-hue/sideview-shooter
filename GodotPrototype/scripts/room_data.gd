class_name RoomData
extends RefCounted
## 방 정의 데이터.
## 좌표계: 방 타일의 좌상단이 (0,0), Y 는 아래로 증가(Godot 기본).
## RESOURCE_USAGE_GUIDE.md 기준 — 타일 높이 560, 바닥선은 타일 상단에서 486px.

const TILE_HEIGHT := 560
const FLOOR_Y := 486
const CAP_WIDTH := 160
const WALL_WIDTH := 256

const TILE_DIR := "res://assets/tiles/"
const PROP_DIR := "res://assets/props/"
const CONNECTOR_DIR := "res://assets/connectors/"

const FRONT_DOOR_TEX := CONNECTOR_DIR + "front_bulkhead_door_game_scale.png"
const SIDE_DOOR_CLOSED_TEX := CONNECTOR_DIR + "sidewall_shutter_closed_edge_game_scale.png"
const SIDE_DOOR_OPEN_TEX := CONNECTOR_DIR + "sidewall_shutter_open_frame_game_scale.png"

## 프랍 top-left 좌표는 Validation JSON 의 캔버스 좌표에서 roomOrigin(96,184)을 뺀 값이다.
## 단, 캐비넷(+18)·소파(+12)는 이미지 하단 투명 여백만큼 내려 바닥선(486)에 실제 픽셀이 닿게 보정했다.
## 정면문은 (1120-96, 364-184) = (1024, 180).
## "fx": 환경 연출. beacon(회전 비상등, 벽 좌표) · leak(새는 수도관: pos=균열, dir=분사 방향) ·
##       wire(끊긴 전선: pos=천장 앵커, length) · fire(불: pos=바닥 중심, size). 수도관은 wall_a 의 가로 파이프(y≈96) 위.
## "monsters": 시작 배치. {"type": "crawler", "x": 발 밑 X, "facing": 1|-1}
## "spawn": 지속 스폰 {"max": 살아 있는 최대 수, "interval": [최소, 최대 초]}. 없으면 Room.SPAWN_DEFAULT(6마리, 1.8~3.5초). 긴 격납고는 더 많이, 복도는 적게.
## "width"(선택): 방 폭 px. 모듈러 타일맵(scenes/rooms/<id>.tscn)으로 그리는 방은 옛 스트립 합계 대신 이 값을 쓴다.
## "ceiling_y"(선택): 천장 y px(기본 0). 층고가 높은 방은 음수(예: 8행 방 = -488). 카메라 중심·비상등·먼지 범위가 따라간다.
const ROOMS := {
	"workshop": {
		"title": "작업실 (Workshop)",
		"tiles": [
			"workshop_cap_left", "workshop_wall_a", "workshop_wall_b", "workshop_wall_c",
			"workshop_wall_d", "workshop_wall_c_mirror", "workshop_wall_d_mirror",
			"workshop_wall_c", "workshop_cap_right",
		],
		"props": [
			{"tex": "workshop_locker_game_scale", "pos": Vector2(154, 192)},
			{"tex": "workshop_workbench_game_scale", "pos": Vector2(554, 254)},
			{"tex": "workshop_armchair_game_scale", "pos": Vector2(1414, 261)},
		],
		"front_doors": [
			{"x": 1024, "target": "quarters", "target_door": 0},
		],
		"left_door": {"open": false},
		"right_door": {"open": true, "target": "corridor"},
		"fx": [
			{"type": "beacon", "pos": Vector2(1370, 118)},
			{"type": "leak", "pos": Vector2(462, 100), "dir": Vector2(0.42, 1.0), "pressure": 1.0},
			{"type": "wire", "pos": Vector2(1230, 42), "length": 210.0},
		],
		"monsters": [
			{"type": "crawler", "x": 760, "facing": 1},
			{"type": "crawler", "x": 320, "facing": 1},
		],
		"spawn": {"max": 6, "interval": [1.8, 3.5]},
	},
	"corridor": {
		"title": "연결 복도 (Corridor)",
		"tiles": [
			"workshop_cap_left", "workshop_wall_repeat", "workshop_wall_a",
			"workshop_wall_repeat", "workshop_cap_right",
		],
		"props": [],
		"front_doors": [],
		"left_door": {"open": true, "target": "workshop"},
		"right_door": {"open": true, "target": "storage"},
		"fx": [
			{"type": "beacon", "pos": Vector2(600, 112)},
			{"type": "wire", "pos": Vector2(880, 42), "length": 240.0},
			{"type": "fire", "pos": Vector2(330, 486), "size": Vector2(150.0, 190.0)},
		],
		"spawn": {"max": 4, "interval": [2.5, 4.5]},
	},
	"storage": {
		"title": "창고 (Storage)",
		"tiles": [
			"workshop_cap_left", "workshop_wall_b", "workshop_wall_d",
			"workshop_wall_repeat", "workshop_wall_c_mirror", "workshop_cap_right",
		],
		"props": [
			{"tex": "workshop_locker_game_scale", "pos": Vector2(160, 192)},
			{"tex": "workshop_workbench_game_scale", "pos": Vector2(880, 254)},
		],
		"front_doors": [
			{"x": 560, "target": "quarters", "target_door": 1},
		],
		"left_door": {"open": true, "target": "corridor"},
		"right_door": {"open": true, "target": "hangar"},
		"fx": [
			{"type": "leak", "pos": Vector2(606, 100), "dir": Vector2(0.35, 1.0), "pressure": 0.9},
			{"type": "wire", "pos": Vector2(1100, 42), "length": 190.0},
		],
		"monsters": [
			{"type": "crawler", "x": 1300, "facing": -1},
			{"type": "crawler", "x": 1800, "facing": -1},
		],
		"spawn": {"max": 6, "interval": [1.8, 3.5]},
	},
	"hangar": {
		# 화면(월드 3200px)보다 훨씬 긴 방 - 카메라 스크롤 확인용. 폭 4416px
		"title": "격납고 (Hangar)",
		"tiles": [
			"workshop_cap_left",
			"workshop_wall_repeat", "workshop_wall_a", "workshop_wall_b", "workshop_wall_c",
			"workshop_wall_repeat", "workshop_wall_d", "workshop_wall_c_mirror", "workshop_wall_b",
			"workshop_wall_repeat", "workshop_wall_d_mirror", "workshop_wall_a", "workshop_wall_b",
			"workshop_wall_repeat", "workshop_wall_c", "workshop_wall_d", "workshop_wall_repeat",
			"workshop_cap_right",
		],
		"props": [
			{"tex": "workshop_locker_game_scale", "pos": Vector2(230, 192)},
			{"tex": "workshop_workbench_game_scale", "pos": Vector2(1180, 254)},
			{"tex": "workshop_armchair_game_scale", "pos": Vector2(2050, 261)},
			{"tex": "workshop_locker_game_scale", "pos": Vector2(2700, 192)},
			{"tex": "workshop_workbench_game_scale", "pos": Vector2(3400, 254)},
			{"tex": "workshop_locker_game_scale", "pos": Vector2(4050, 192)},
		],
		"front_doors": [],
		"left_door": {"open": true, "target": "storage"},
		"right_door": {"open": true, "target": "hall"},
		"fx": [
			{"type": "beacon", "pos": Vector2(1560, 118)},
			{"type": "beacon", "pos": Vector2(3300, 118)},
			{"type": "fire", "pos": Vector2(2560, 486), "size": Vector2(210.0, 260.0)},
			{"type": "leak", "pos": Vector2(1636, 100), "dir": Vector2(0.5, 1.0), "pressure": 1.1},
			{"type": "leak", "pos": Vector2(3934, 100), "dir": Vector2(-0.25, 1.0), "pressure": 0.8},
			{"type": "wire", "pos": Vector2(700, 42), "length": 230.0},
			{"type": "wire", "pos": Vector2(2980, 42), "length": 200.0},
		],
		"monsters": [
			{"type": "crawler", "x": 1500, "facing": -1},
			{"type": "crawler", "x": 3150, "facing": -1},
			{"type": "crawler", "x": 3900, "facing": -1},
			{"type": "crawler", "x": 900, "facing": -1},
			{"type": "crawler", "x": 2400, "facing": -1},
			{"type": "crawler", "x": 4250, "facing": -1},
		],
		"spawn": {"max": 12, "interval": [1.3, 2.5]},
	},
	"quarters": {
		"title": "숙소 (Crew Quarters)",
		"tiles": [
			"workshop_cap_left", "workshop_wall_c", "workshop_wall_repeat",
			"workshop_wall_d_mirror", "workshop_wall_b", "workshop_cap_right",
		],
		"props": [
			{"tex": "workshop_armchair_game_scale", "pos": Vector2(520, 261)},
		],
		"front_doors": [
			{"x": 140, "target": "workshop", "target_door": 0},
			{"x": 860, "target": "storage", "target_door": 0},
		],
		"left_door": {"open": false},
		"right_door": {"open": false},
		"fx": [
			{"type": "leak", "pos": Vector2(1054, 100), "dir": Vector2(-0.4, 1.0), "pressure": 0.85},
			{"type": "wire", "pos": Vector2(1200, 42), "length": 200.0},
			{"type": "beacon", "pos": Vector2(760, 112)},
		],
		"monsters": [
			{"type": "crawler", "x": 1250, "facing": -1},
			{"type": "crawler", "x": 350, "facing": 1},
		],
		"spawn": {"max": 6, "interval": [1.8, 3.5]},
	},
	"hall": {
		# 모듈러 타일맵(Workshop_Modular v2)으로만 그리는 첫 방. 폭 24셀(3072) · 중앙 고층부 8행(1024), 양 날개 5행.
		# 격자 원점 (0, -488): 바닥 행(7행)의 밟는 띠 윗선이 바닥선 486 에 온다. 생성기: tools/build_hall_room.gd
		# 옛 스트립 "tiles" 는 숨겨지고 램프 위치(wall_b·wall_repeat)만 빌려 쓴다. 창문 타일(wall_d)은 넣지 않는다.
		"title": "대형 정비 홀 (Assembly Hall)",
		"width": 3072,
		"ceiling_y": -488,
		"tiles": [
			"workshop_cap_left",
			"workshop_wall_repeat", "workshop_wall_a", "workshop_wall_b", "workshop_wall_c",
			"workshop_wall_c_mirror", "workshop_wall_repeat", "workshop_wall_c",
			"workshop_wall_c_mirror", "workshop_wall_b", "workshop_wall_a", "workshop_wall_repeat",
			"workshop_cap_right",
		],
		"props": [
			{"tex": "workshop_locker_game_scale", "pos": Vector2(210, 192)},
			{"tex": "workshop_workbench_game_scale", "pos": Vector2(900, 254)},
			{"tex": "workshop_armchair_game_scale", "pos": Vector2(1560, 261)},
			{"tex": "workshop_workbench_game_scale", "pos": Vector2(2020, 254)},
			{"tex": "workshop_locker_game_scale", "pos": Vector2(2700, 192)},
		],
		"front_doors": [],
		"left_door": {"open": true, "target": "hangar"},
		"right_door": {"open": false},
		"fx": [
			# 비상등 두 개 — 날개 천장(-104) 바로 아래 높이에 둔다. 더 높이 올리면(고층부 x 640~2432 밖) 스윕 광선이
			# 날개 위 빈 공간(방 밖)으로 새어 나간다. 이 높이면 방 전체 폭을 붉게 훑는다.
			{"type": "beacon", "pos": Vector2(700, -30)},
			{"type": "beacon", "pos": Vector2(2370, -30)},
			# 높은 천장에서 길게 늘어진 끊긴 전선
			{"type": "wire", "pos": Vector2(1180, -440), "length": 520.0},
			{"type": "wire", "pos": Vector2(1900, -440), "length": 460.0},
			# 날개 천장(-104) 아래 짧은 전선과 벽 균열 누수
			{"type": "wire", "pos": Vector2(2860, -60), "length": 190.0},
			{"type": "leak", "pos": Vector2(420, 60), "dir": Vector2(0.45, 1.0), "pressure": 1.0},
			{"type": "fire", "pos": Vector2(1380, 486), "size": Vector2(190.0, 240.0)},
		],
		"monsters": [
			{"type": "crawler", "x": 1100, "facing": 1},
			{"type": "crawler", "x": 1800, "facing": -1},
			{"type": "crawler", "x": 2550, "facing": -1},
		],
		"spawn": {"max": 9, "interval": [1.5, 3.0]},
	},
}


## 타일 안의 천장 램프(전구) 위치 - 타일 로컬 픽셀. 실제 라이팅(PointLight2D)을 여기에 단다.
## bulb 는 전구 픽셀의 타일 로컬 영역 (깨졋을 때 어두운 커버를 덮는 곳)
## sprite 는 램프(갓+전구) 픽셀 전체 영역 — 발광·글리치 셰이더용 아틀라스로 잘라 같은 자리에 올린다.
const TILE_LAMPS := {
	"workshop_wall_b": [{"pos": Vector2(194, 158), "bulb": Rect2(186, 154, 20, 9), "sprite": Rect2(140, 60, 112, 110)}],
	"workshop_wall_repeat": [{"pos": Vector2(50, 158), "bulb": Rect2(42, 154, 20, 9), "sprite": Rect2(0, 60, 108, 110)}],
}

## 타일 안의 창문 유리 영역(타일 로컬). 유리 셰이더를 올리고, 맞으면 균열이 생긴다.
const TILE_WINDOWS := {
	"workshop_wall_d": [Rect2(105, 135, 80, 50)],
	"workshop_wall_d_mirror": [Rect2(71, 135, 80, 50)],
}


static func get_room(id: String) -> Dictionary:
	return ROOMS[id]


## 방 폭(px). "width" 가 있으면 그 값(모듈러 타일맵 폭), 없으면 옛 스트립 타일 폭의 합.
static func room_width(id: String) -> int:
	var data: Dictionary = ROOMS[id]
	if data.has("width"):
		return int(data["width"])
	var w := 0
	for t in data["tiles"]:
		w += tile_width(t)
	return w


## 방 천장 y(px). 기본 0(옛 560 스트립 상단). 층고가 높은 모듈러 방은 "ceiling_y" 로 음수 값을 준다.
static func room_ceiling(id: String) -> int:
	return int(ROOMS[id].get("ceiling_y", 0))


## 방의 세로 범위 사각형 (천장 ~ 스트립 하단 560). 카메라 중심·비상등 스윕·먼지 레이어 범위에 쓴다.
static func room_rect(id: String) -> Rect2:
	var top := room_ceiling(id)
	return Rect2(0, top, room_width(id), TILE_HEIGHT - top)


static func tile_width(tile_name: String) -> int:
	return CAP_WIDTH if tile_name.ends_with("cap_left") or tile_name.ends_with("cap_right") else WALL_WIDTH
