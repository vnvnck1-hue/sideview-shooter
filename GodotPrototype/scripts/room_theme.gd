class_name RoomTheme
extends RefCounted
## 방 테마 표 — 테마별 모듈러 타일 시트(128px 셀)와 실행 중에 만든 TileSet 캐시.
## 시트 세 장은 tools/build_theme_tile_sheets.py 가 준비한다:
##   배경 채움 3×2 (a~f 6종) · 프레임 3×3 (외곽 8조각 + 투명 내부) · L-벤드 4×1 (오목 코너)
## TileSet 소스 번호: 0 배경, 1 프레임, 2 L-벤드. 터레인은 쓰지 않고 RoomTiles 가 이웃 판정으로 조각을 고른다.

const CELL := 128

const THEMES := {
	"workshop": {
		"title": "작업실 (Workshop)",
		"dir": "res://assets/tiles/workshop_modular/",
		"prefix": "workshop",
	},
	"corridor": {
		"title": "복도 (Corridor)",
		"dir": "res://assets/tiles/corridor_modular/",
		"prefix": "corridor",
	},
	"hydroponics": {
		"title": "수경재배실 (Hydroponics)",
		"dir": "res://assets/tiles/hydroponics_modular/",
		"prefix": "hydroponics",
	},
	"crewquarters": {
		"title": "승무원 숙소 (Crew Quarters)",
		"dir": "res://assets/tiles/crewquarters_modular/",
		"prefix": "crewquarters",
	},
	"power_relay": {
		"title": "전력 릴레이실 (Power Relay)",
		"dir": "res://assets/power_relay_room/Tiles/",
		"prefix": "power_relay",
	},
}

const SRC_BG := 0
const SRC_FRAME := 1
const SRC_BEND := 2

## 프레임 3×3 시트 아틀라스 좌표
const FRAME := {
	"top_left": Vector2i(0, 0), "top": Vector2i(1, 0), "top_right": Vector2i(2, 0),
	"left": Vector2i(0, 1), "right": Vector2i(1, 1), "bottom_left": Vector2i(2, 1),
	"bottom": Vector2i(0, 2), "bottom_right": Vector2i(1, 2), "inner": Vector2i(2, 2),
}
## L-벤드 4×1 시트 아틀라스 좌표. 이름은 띠가 남는 사각형의 위치 (= 방 밖인 대각 방향).
const BEND := {
	"bend_top_left": Vector2i(0, 0), "bend_top_right": Vector2i(1, 0),
	"bend_bottom_left": Vector2i(2, 0), "bend_bottom_right": Vector2i(3, 0),
}

static var _tilesets := {}


static func ids() -> Array:
	return THEMES.keys()


static func title(theme: String) -> String:
	return THEMES[theme]["title"]


static func sheet(theme: String, kind: String) -> String:
	var t: Dictionary = THEMES[theme]
	match kind:
		"bg": return t["dir"] + t["prefix"] + "_modular_background_sheet_3x2.png"
		"frame": return t["dir"] + t["prefix"] + "_modular_frame_terrain_3x3.png"
		"bend": return t["dir"] + t["prefix"] + "_modular_frame_bend_sheet_4x1.png"
	return ""


## 테마의 TileSet (처음 한 번 만들고 캐시)
static func tileset(theme: String) -> TileSet:
	if _tilesets.has(theme):
		return _tilesets[theme]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(CELL, CELL)
	ts.add_source(_atlas(sheet(theme, "bg"), Vector2i(3, 2), "배경 채움 a~f"), SRC_BG)
	ts.add_source(_atlas(sheet(theme, "frame"), Vector2i(3, 3), "프레임 외곽 8조각 + 투명 내부"), SRC_FRAME)
	ts.add_source(_atlas(sheet(theme, "bend"), Vector2i(4, 1), "L-벤드 4종 (오목 코너)"), SRC_BEND)
	_tilesets[theme] = ts
	return ts


static func _atlas(path: String, grid: Vector2i, label: String) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.resource_name = label
	src.texture = load(path)
	src.texture_region_size = Vector2i(CELL, CELL)
	for y in range(grid.y):
		for x in range(grid.x):
			src.create_tile(Vector2i(x, y))
	return src
