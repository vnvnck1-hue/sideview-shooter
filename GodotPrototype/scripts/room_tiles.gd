class_name RoomTiles
extends Node2D
## 방 하나의 모듈러 타일맵 — 테마와 "열 높이 프로필"로 실행 중에 찍는다 (씬 파일 없음).
## 프로필 heights[i] = i 번째 열(128px)에 쌓는 셀 수. 바닥 행은 모든 열이 공유하고 위로 쌓이므로
## 열마다 천장 높이가 달라 성당형·계단형·굴뚝형 등 어떤 실루엣도 된다. 바닥은 항상 한 줄(사이드뷰 좌우 이동만 있음).
##
## 자식 TileMapLayer 두 개: "Background"(채움 6종 랜덤, 방 id 시드) 와 "Frame"(외곽선 오버레이).
## Frame 조각은 4방 이웃 판정으로 고른다 — 방 밖인 방향의 변/모서리. 4방이 모두 방 안인데 대각 하나가 밖이면 오목 코너 → L-벤드.
## 아트에 없는 형태(1칸 폭 기둥: 좌우가 모두 밖 · 1칸 높이: 상하가 모두 밖)는 조각이 없어 빈 셀이 된다 → invalid_cells() 로 검사한다.
##
## 이 노드의 position 이 격자 원점. 바닥 행 타일 상단 + FLOOR_BAND(78) = 밟는 띠 윗선 = 바닥선(RoomData.FLOOR_Y 486).

const CELL := RoomTheme.CELL
const FLOOR_BAND := 78          # 바닥 프레임 조각에서 밟는 띠 윗선까지의 오프셋
const CEILING_BAND := 48        # 천장 띠 두께 (램프·전선은 이 아래에 매단다)
const WALL_BAND := 56           # 좌우 벽 띠 두께
# 타일맵이 캔버스 아이템으로 쪼개지는 단위(셀). 조명 한도는 아이템마다 따로 걸리므로
# 청크가 작을수록 한 청크가 받는 라이트 수가 줄어 한도(15)에 덜 부딪힌다 — Lighting 의 "청크당 라이트 한도" 참고.
# 기본값 16(2048px)은 방 전체가 몇 덩어리라 램프·무드 광원이 전부 한 청크에 몰렸다. 3 = 384px.
const QUADRANT := 3

var theme := ""
var heights: Array = []
var rows := 0
var cells := {}                 # Vector2i → true (방 안)


## 프로필만으로 기하를 계산한다 (노드 없이). RoomData 가 폭·천장을 구할 때 쓴다.
static func layout(hs: Array) -> Dictionary:
	var r := 0
	for h in hs:
		r = maxi(r, int(h))
	var origin := Vector2(0, RoomData.FLOOR_Y - FLOOR_BAND - CELL * (r - 1))
	return {
		"rows": r,
		"origin": origin,
		"width": hs.size() * CELL,
		"ceiling_y": origin.y,                       # 가장 높은 천장 (방 사각형 상단)
		"bottom_y": origin.y + CELL * r,             # 바닥 행 타일 하단
	}


## 열 x(월드 px) 위 천장 타일 상단 y. 방 밖이면 가장 높은 천장.
static func ceiling_at(hs: Array, x: float) -> float:
	var lay := layout(hs)
	var col := clampi(int(floor(x / CELL)), 0, hs.size() - 1)
	return lay["origin"].y + CELL * (lay["rows"] - int(hs[col]))


## 열 폭·높이 구간 [[폭 셀, 높이 셀], ...] → 열별 높이 배열
static func expand(segments: Array) -> Array:
	var hs: Array = []
	for seg in segments:
		for i in range(int(seg[0])):
			hs.append(int(seg[1]))
	return hs


static func cells_of(hs: Array) -> Dictionary:
	var r: int = layout(hs)["rows"]
	var out := {}
	for x in range(hs.size()):
		for y in range(r - int(hs[x]), r):
			out[Vector2i(x, y)] = true
	return out


## 맞는 프레임 조각이 없는 셀 목록 (비어 있어야 정상)
static func invalid_cells(hs: Array) -> Array:
	var cs := cells_of(hs)
	var bad: Array = []
	for c in cs.keys():
		if _piece(cs, c) == "":
			bad.append(c)
	return bad


func build(theme_id: String, hs: Array, seed_text: String) -> void:
	theme = theme_id
	heights = hs.duplicate()
	var lay := layout(hs)
	rows = lay["rows"]
	position = lay["origin"]
	cells = cells_of(hs)
	var ts := RoomTheme.tileset(theme_id)

	var bg := TileMapLayer.new()
	bg.name = "Background"
	bg.tile_set = ts
	bg.rendering_quadrant_size = QUADRANT
	var fr := TileMapLayer.new()
	fr.name = "Frame"
	fr.tile_set = ts
	fr.rendering_quadrant_size = QUADRANT
	# The six background cells are one 3x2 architectural macro panel.
	# Keep their phase locked; random selection turns vents and seams into
	# 32 px wallpaper and breaks features that cross tile boundaries.
	var phase_x := posmod(hash(seed_text), 3)
	var phase_y := posmod(hash(seed_text + "_bg_phase"), 2)
	for c in cells.keys():
		var i := posmod(c.x + phase_x, 3) + posmod(c.y + phase_y, 2) * 3
		bg.set_cell(c, RoomTheme.SRC_BG, Vector2i(i % 3, i / 3))
		var piece := _piece(cells, c)
		if piece == "":
			continue
		if RoomTheme.BEND.has(piece):
			fr.set_cell(c, RoomTheme.SRC_BEND, RoomTheme.BEND[piece])
		else:
			fr.set_cell(c, RoomTheme.SRC_FRAME, RoomTheme.FRAME[piece])
	add_child(bg)
	add_child(fr)


## 게임 라이팅 머티리얼을 두 레이어에 입힌다 (배경 타일: 실루엣 림 없음)
func apply_lit_material() -> void:
	for child in get_children():
		if child is TileMapLayer:
			var m := Lighting.lit_material()
			m.set_shader_parameter("rim_ambient_strength", 0.0)
			m.set_meta("rim_ambient_fixed", true)
			child.material = m


## 월드 점이 타일이 찍힌 셀 안인가 (벽·천장·바닥 포함 — 탄착 판정용)
func is_wall_at(world_point: Vector2) -> bool:
	var local := world_point - position
	var c := Vector2i(int(floor(local.x / CELL)), int(floor(local.y / CELL)))
	return cells.has(c)


## 찍힌 셀 전체를 감싸는 사각형(월드 px)
func used_rect() -> Rect2:
	return Rect2(position, Vector2(heights.size() * CELL, rows * CELL))


static func _piece(cs: Dictionary, c: Vector2i) -> String:
	var t := not cs.has(c + Vector2i.UP)
	var b := not cs.has(c + Vector2i.DOWN)
	var l := not cs.has(c + Vector2i.LEFT)
	var r := not cs.has(c + Vector2i.RIGHT)
	if (t and b) or (l and r):
		return ""                                  # 아트에 없는 형태
	if t and l: return "top_left"
	if t and r: return "top_right"
	if b and l: return "bottom_left"
	if b and r: return "bottom_right"
	if t: return "top"
	if b: return "bottom"
	if l: return "left"
	if r: return "right"
	# 4방이 모두 방 안 — 대각이 비면 오목 코너. 비는 대각 쪽 사각형에만 띠가 남는 L-벤드
	if not cs.has(c + Vector2i(-1, -1)): return "bend_top_left"
	if not cs.has(c + Vector2i(1, -1)): return "bend_top_right"
	if not cs.has(c + Vector2i(-1, 1)): return "bend_bottom_left"
	if not cs.has(c + Vector2i(1, 1)): return "bend_bottom_right"
	return "inner"


## 콘솔 확인용 문자 지도: ┌┐└┘ 모서리, ─│ 변, 오목 코너는 꺾이는 방향의 ┘└┐┌, · 내부, ? 조각 없음
static func ascii_map(hs: Array) -> String:
	const GLYPH := {
		"top_left": "┌", "top_right": "┐", "bottom_left": "└", "bottom_right": "┘",
		"top": "─", "bottom": "─", "left": "│", "right": "│", "inner": "·",
		"bend_top_left": "┘", "bend_top_right": "└", "bend_bottom_left": "┐", "bend_bottom_right": "┌", "": "?",
	}
	var cs := cells_of(hs)
	var r: int = layout(hs)["rows"]
	var lines := PackedStringArray()
	for y in range(r):
		var line := ""
		for x in range(hs.size()):
			var c := Vector2i(x, y)
			line += GLYPH[_piece(cs, c)] if cs.has(c) else " "
		lines.append(line)
	return "\n".join(lines)
