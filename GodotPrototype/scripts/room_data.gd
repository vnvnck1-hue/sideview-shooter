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
