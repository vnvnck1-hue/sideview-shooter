extends SceneTree
## "hall"(대형 정비 홀) 모듈러 타일맵 씬 생성기 — Workshop_Modular v2 두 레이어(Background / Frame)로 방 실루엣을 찍는다.
## 실행:  godot --path . --headless --script res://tools/build_hall_room.gd
## 만드는 것: res://scenes/rooms/hall.tscn  (이미 있으면 덮어쓴다 — 손으로 고친 뒤에는 다시 돌리지 말 것)
##
## 방 실루엣(셀, 원점 = 고층부 천장 왼쪽 위):
##       col 0..4      col 5..18 (14)      col 19..23
##   row 0 ┌────────────────────────────┐           ← 중앙 고층부 천장 (y -488)
##   ...   │           고층부            │
##   row 3 ┌──────┤                    ├──────┐    ← 양 날개 천장 (y -104), 오목 코너 2개
##   ...   │ 날개 │                    │ 날개 │
##   row 7 └──────┴────────────────────┴──────┘    ← 바닥 행(밟는 띠 윗선 = 바닥선 486)
##
## Frame 조각은 터레인 브러시 대신 이웃 판정으로 직접 고른다 — 오목 코너는 터레인 규칙에 없어 자동으로 붙지 않기 때문이다.
## Background 는 터레인 connect 로 채워 6종 무늬가 랜덤으로 섞인다.
## 판정: 4방 이웃 중 방 밖인 방향 → 그쪽 변/모서리 조각. 4방이 모두 방 안인데 대각 하나가 밖 → 오목 코너 = L-벤드(소스 3).
##       배포된 InnerCorners(소스 2)는 벽 띠가 천장을 지나 아래로 이어지는 T자라 여기선 쓰지 않는다 (make_frame_bend_tiles.py 참고).

const CELL := 128
const TILESET_PATH := "res://tiles/workshop_modular_tileset.tres"
const ROOM_SCRIPT := "res://scripts/room_tiles.gd"
const OUT_PATH := "res://scenes/rooms/hall.tscn"

## 격자 원점(월드 px). 바닥 행(7행) 타일 상단이 408 이어야 밟는 띠 윗선(+78)이 바닥선 486 에 온다: 408 - 7*128 = -488
const ORIGIN := Vector2(0, -488)
## 방 실루엣: 포함 범위 [x0, y0, x1, y1] 사각형들의 합집합
const SHAPE := [
	[5, 0, 18, 7],     # 중앙 고층부 14×8
	[0, 3, 4, 7],      # 왼쪽 날개 5×5
	[19, 3, 23, 7],    # 오른쪽 날개 5×5
]

const SRC_BG := 0
const SRC_FRAME := 1
const SRC_INNER := 2       # InnerCorners(벽 띠가 아래로 이어지는 T자) — 여기서는 쓰지 않는다
const SRC_BEND := 3        # L-벤드(벽이 천장 높이에서 멈추고 꺾임) — 오목 코너에 쓴다
const SET_BG := 0

## 프레임 시트(3×3) 아틀라스 좌표
const FRAME := {
	"top_left": Vector2i(0, 0), "top": Vector2i(1, 0), "top_right": Vector2i(2, 0),
	"left": Vector2i(0, 1), "right": Vector2i(1, 1), "bottom_left": Vector2i(2, 1),
	"bottom": Vector2i(0, 2), "bottom_right": Vector2i(1, 2), "inner": Vector2i(2, 2),
}
## 오목 코너 → L-벤드 시트(4×1, 소스 3) 아틀라스 좌표. 이름은 띠가 남는 사각형의 위치.
##   왼쪽 위가 방 밖(왼쪽 날개 천장이 고층부 왼벽과 만남) → 벽이 내려와 왼쪽으로 꺾임 → bend_top_left
##   오른쪽 위가 방 밖 → bend_top_right.  아래쪽이 밖인 경우(바닥 단차)는 bottom 계열.
const BEND := {
	"bend_top_left": Vector2i(0, 0), "bend_top_right": Vector2i(1, 0),
	"bend_bottom_left": Vector2i(2, 0), "bend_bottom_right": Vector2i(3, 0),
}

var _cells := {}          # Vector2i → true (방 안)


func _init() -> void:
	for r in SHAPE:
		for y in range(r[1], r[3] + 1):
			for x in range(r[0], r[2] + 1):
				_cells[Vector2i(x, y)] = true

	var ts: TileSet = load(TILESET_PATH)
	var root := Node2D.new()
	root.name = "RoomTiles"
	root.position = ORIGIN
	root.set_script(load(ROOM_SCRIPT))
	root.set("hide_legacy_tiles", true)          # 옛 560 스트립은 숨기고 이 타일맵만 배경으로 쓴다

	var cells: Array[Vector2i] = []
	for c in _cells.keys():
		cells.append(c)

	var bg := TileMapLayer.new()
	bg.name = "Background"
	bg.tile_set = ts
	bg.set_cells_terrain_connect(cells, SET_BG, 0)
	root.add_child(bg)
	bg.owner = root

	var fr := TileMapLayer.new()
	fr.name = "Frame"
	fr.tile_set = ts
	var counts := {}
	for c in cells:
		var piece := _piece_for(c)
		if BEND.has(piece):
			fr.set_cell(c, SRC_BEND, BEND[piece])
		else:
			fr.set_cell(c, SRC_FRAME, FRAME[piece])
		counts[piece] = counts.get(piece, 0) + 1
	root.add_child(fr)
	fr.owner = root

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/rooms"))
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_PATH)
	print("hall room -> %s (%s)" % [OUT_PATH, error_string(err)])
	var used := bg.get_used_rect()
	print("  origin %s  cells %d  used %s (%d×%d px)" % [ORIGIN, cells.size(), used, used.size.x * CELL, used.size.y * CELL])
	print("  frame pieces: ", counts)
	_print_map(used)
	quit()


func _inside(c: Vector2i) -> bool:
	return _cells.has(c)


func _piece_for(c: Vector2i) -> String:
	var t := not _inside(c + Vector2i.UP)
	var b := not _inside(c + Vector2i.DOWN)
	var l := not _inside(c + Vector2i.LEFT)
	var r := not _inside(c + Vector2i.RIGHT)
	if t and l: return "top_left"
	if t and r: return "top_right"
	if b and l: return "bottom_left"
	if b and r: return "bottom_right"
	if t: return "top"
	if b: return "bottom"
	if l: return "left"
	if r: return "right"
	# 4방이 모두 방 안 — 대각이 비면 오목 코너. 비는 대각 쪽 사각형에만 띠가 남는 L-벤드를 놓는다
	if not _inside(c + Vector2i(-1, -1)): return "bend_top_left"
	if not _inside(c + Vector2i(1, -1)): return "bend_top_right"
	if not _inside(c + Vector2i(-1, 1)): return "bend_bottom_left"
	if not _inside(c + Vector2i(1, 1)): return "bend_bottom_right"
	return "inner"


## 콘솔 확인용 문자 지도: ┌┐└┘ 모서리, ─│ 변, 오목 코너도 꺾이는 방향의 ┌┐└┘, · 내부
func _print_map(used: Rect2i) -> void:
	const GLYPH := {
		"top_left": "┌", "top_right": "┐", "bottom_left": "└", "bottom_right": "┘",
		"top": "─", "bottom": "─", "left": "│", "right": "│", "inner": "·",
		"bend_top_left": "┘", "bend_top_right": "└", "bend_bottom_left": "┐", "bend_bottom_right": "┌",
	}
	for y in range(used.position.y, used.end.y):
		var line := "  "
		for x in range(used.position.x, used.end.x):
			var c := Vector2i(x, y)
			line += GLYPH[_piece_for(c)] if _inside(c) else " "
		print(line)
