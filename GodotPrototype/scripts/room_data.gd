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
		"right_door": {"open": false},
		"fx": [
			{"type": "beacon", "pos": Vector2(1560, 118)},
			{"type": "beacon", "pos": Vector2(3300, 118)},
			{"type": "fire", "pos": Vector2(2560, 486), "size": Vector2(210.0, 260.0)},
			{"type": "leak", "pos": Vector2(1636, 100), "dir": Vector2(0.5, 1.0), "pressure": 1.1},
			{"type": "leak", "pos": Vector2(3934, 100), "dir": Vector2(-0.25, 1.0), "pressure": 0.8},
			{"type": "wire", "pos": Vector2(700, 42), "length": 230.0},
			{"type": "wire", "pos": Vector2(2980, 42), "length": 200.0},
		],
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


static func room_width(id: String) -> int:
	var w := 0
	for t in ROOMS[id]["tiles"]:
		w += tile_width(t)
	return w


static func tile_width(tile_name: String) -> int:
	return CAP_WIDTH if tile_name.ends_with("cap_left") or tile_name.ends_with("cap_right") else WALL_WIDTH
