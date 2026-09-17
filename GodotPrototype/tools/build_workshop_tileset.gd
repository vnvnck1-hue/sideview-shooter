extends SceneTree
## Workshop_Modular TileSet(터레인 오토타일) + 예시 방 타일맵 씬 생성기.
## 실행:  godot --path . --headless --script res://tools/build_workshop_tileset.gd
## 만드는 것
##   res://tiles/workshop_modular_tileset.tres
##     터레인 세트 0 "배경 채움" — 소스 0: 채움 6종. 피어링 비트 없음(어떤 이웃이든 채워짐) + 같은 확률 → 랜덤 무늬
##     터레인 세트 1 "프레임"    — 소스 1: 외곽 8조각(안쪽 방향 비트) + 투명 내부 1칸(8방향 비트)
##     소스 2 "안쪽 모서리" 4종 — 터레인 없음. Tiles 탭에서 수동 배치 (Unity RuleTile 규칙 JSON 기준이라 Godot 이웃 패턴 대응은 미정)
##     ※ 아트에 없는 형태(1칸 폭 기둥·1칸 높이 복도·외딴 1칸)는 맞는 조각이 없어 빈 셀로 남는다. 방은 2×2 셀 이상으로.
##   res://scenes/rooms/workshop.tscn            — 16×4 셀 예시 방 (없을 때만 새로 만든다. 이미 있으면 건너뜀)
## TileSet 은 다시 실행하면 덮어쓴다. 방 씬은 사용자가 편집하는 파일이므로 보존한다.

const CELL := 128
const BG_SHEET := "res://assets/tiles/workshop_modular/workshop_modular_background_sheet_3x2.png"
const FRAME_SHEET := "res://assets/tiles/workshop_modular/workshop_modular_frame_terrain_3x3.png"
const INNER_SHEET := "res://assets/tiles/workshop_modular/workshop_modular_frame_inner_corners_sheet_4x1.png"
const TILESET_PATH := "res://tiles/workshop_modular_tileset.tres"
const EXAMPLE_ROOM := "res://scenes/rooms/workshop.tscn"

const SET_BG := 0
const SET_FRAME := 1

## 프레임 시트 3x3 배치와, 각 조각이 "같은 터레인(방 안쪽)"으로 이어지는 방향.
## 바깥(빈) 방향은 비트를 두지 않는다 → 터레인 브러시가 빈 이웃 방향에 맞는 조각을 고른다.
const FRAME_TILES := {
	Vector2i(0, 0): ["top_left",     ["R", "BR", "B"]],
	Vector2i(1, 0): ["top",          ["L", "R", "B", "BL", "BR"]],
	Vector2i(2, 0): ["top_right",    ["L", "BL", "B"]],
	Vector2i(0, 1): ["left",         ["T", "B", "R", "TR", "BR"]],
	Vector2i(1, 1): ["right",        ["T", "B", "L", "TL", "BL"]],
	Vector2i(2, 1): ["bottom_left",  ["R", "TR", "T"]],
	Vector2i(0, 2): ["bottom",       ["L", "R", "T", "TL", "TR"]],
	Vector2i(1, 2): ["bottom_right", ["L", "TL", "T"]],
	Vector2i(2, 2): ["inner(투명)",   ["R", "BR", "B", "BL", "L", "TL", "T", "TR"]],   # 8방향 모두 안쪽 = 방 내부
}
const BIT_OF := {
	"R": TileSet.CELL_NEIGHBOR_RIGHT_SIDE, "BR": TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	"B": TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, "BL": TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	"L": TileSet.CELL_NEIGHBOR_LEFT_SIDE, "TL": TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	"T": TileSet.CELL_NEIGHBOR_TOP_SIDE, "TR": TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
}


func _init() -> void:
	var ts := _build_tileset()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tiles"))
	var err := ResourceSaver.save(ts, TILESET_PATH)
	print("TileSet -> %s (%s)" % [TILESET_PATH, error_string(err)])
	if not FileAccess.file_exists(EXAMPLE_ROOM):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/rooms"))
		err = _build_example_room(load(TILESET_PATH))
		print("Example room -> %s (%s)" % [EXAMPLE_ROOM, error_string(err)])
	else:
		print("Example room exists, kept: ", EXAMPLE_ROOM)
	quit()


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	ts.add_terrain_set()                       # 세트 0: 배경
	ts.set_terrain_set_mode(SET_BG, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(SET_BG)
	ts.set_terrain_name(SET_BG, 0, "배경 채움 (랜덤 a~f)")
	ts.set_terrain_color(SET_BG, 0, Color(0.35, 0.55, 0.95))
	ts.add_terrain_set()                       # 세트 1: 프레임
	ts.set_terrain_set_mode(SET_FRAME, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(SET_FRAME)
	ts.set_terrain_name(SET_FRAME, 0, "프레임 (외곽선 자동)")
	ts.set_terrain_color(SET_FRAME, 0, Color(1.0, 0.75, 0.25))

	# 소스 0: 배경 채움 — 피어링 비트를 두지 않는다(비트가 있으면 빈 이웃과 맞지 않아 가장자리 셀이 비는 것을 확인).
	#         확률 같게 → 터레인 브러시가 셀마다 랜덤으로 고른다.
	var bg := TileSetAtlasSource.new()
	bg.resource_name = "Background 채움 a~f"
	bg.texture = load(BG_SHEET)
	bg.texture_region_size = Vector2i(CELL, CELL)
	var names := ["a", "b", "c", "d", "e", "f"]
	for i in range(6):
		var c := Vector2i(i % 3, i / 3)
		bg.create_tile(c)
		var td := bg.get_tile_data(c, 0)
		td.terrain_set = SET_BG
		td.terrain = 0
		td.probability = 1.0
		bg.set_meta("tile_%d_%d" % [c.x, c.y], "bg_fill_" + names[i])
	ts.add_source(bg, 0)

	# 소스 1: 프레임 — 조각마다 안쪽 방향만 비트. (2,2) 는 투명 내부 타일(방 안쪽을 메운다).
	var fr := TileSetAtlasSource.new()
	fr.resource_name = "Frame 외곽선 8조각 + 투명 내부"
	fr.texture = load(FRAME_SHEET)
	fr.texture_region_size = Vector2i(CELL, CELL)
	for c in FRAME_TILES.keys():
		fr.create_tile(c)
		var td := fr.get_tile_data(c, 0)
		td.terrain_set = SET_FRAME
		td.terrain = 0
		for key in FRAME_TILES[c][1]:
			td.set_terrain_peering_bit(BIT_OF[key], 0)
	ts.add_source(fr, 1)

	# 소스 2: 안쪽 모서리 4종 (InnerCorners) — 터레인 비트 없이 수동 배치용
	var inner := TileSetAtlasSource.new()
	inner.resource_name = "Frame 안쪽 모서리 4종 (수동 배치)"
	inner.texture = load(INNER_SHEET)
	inner.texture_region_size = Vector2i(CELL, CELL)
	for i in range(4):
		inner.create_tile(Vector2i(i, 0))
	ts.add_source(inner, 2)
	return ts


## 예시 방: 원점 (0,24) · 16×4 셀. 두 레이어 모두 터레인 connect 로 채워 오토타일 결과 그대로 저장한다.
func _build_example_room(ts: TileSet) -> Error:
	var root := Node2D.new()
	root.name = "RoomTiles"
	root.position = Vector2(0, 24)
	root.set_script(load("res://scripts/room_tiles.gd"))

	var cells: Array[Vector2i] = []
	for y in range(4):
		for x in range(16):
			cells.append(Vector2i(x, y))

	var bg := TileMapLayer.new()
	bg.name = "Background"
	bg.tile_set = ts
	bg.set_cells_terrain_connect(cells, SET_BG, 0)
	root.add_child(bg)
	bg.owner = root

	var fr := TileMapLayer.new()
	fr.name = "Frame"
	fr.tile_set = ts
	fr.set_cells_terrain_connect(cells, SET_FRAME, 0)
	root.add_child(fr)
	fr.owner = root

	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		return err
	return ResourceSaver.save(packed, EXAMPLE_ROOM)
