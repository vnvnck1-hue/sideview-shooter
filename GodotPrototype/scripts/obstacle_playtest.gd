class_name ObstaclePlaytest
extends RefCounted
const ROOM_ID := "obstacle_playtest"

static func register_room() -> void:
	RoomData.register_extra(ROOM_ID, {
		"title": "장애물 프랍 · 점프 / 파괴 / 폭발", "zone": "프랍 테스트", "theme": "workshop",
		"shape": [[24,6]], "left_door": {"open": false}, "right_door": {"open": false},
		"front_doors": [],
		"props": [
			{"type":"obstacle","kind":"barricade","x":450},
			{"type":"obstacle","kind":"cable_reel","x":900},
			{"type":"obstacle","kind":"supply_crate","x":1320},
			{"type":"obstacle","kind":"rubble_block","x":1740},
			{"type":"obstacle","kind":"gas_cylinder","x":2210},
			{"type":"obstacle","kind":"gas_cylinder","x":2430},
			{"type":"obstacle","kind":"supply_crate","x":2640},
		],
		"lamps": [450,1000,1550,2150,2650], "fixtures": [], "fx": [],
		"monsters": [{"type":"crawler","x":2770,"facing":-1}], "spawn": {"max":0,"interval":[100,100]},
	})

static func start(tree: SceneTree) -> void:
	register_room()
	Room.obstacle_history.clear()
	AppFlow.visited = {}
	AppFlow.start_room = ROOM_ID
	AppFlow.resume_x = 180.0
	AppFlow.resume_facing = 1
	tree.change_scene_to_file(AppFlow.TEST_SCENE)
