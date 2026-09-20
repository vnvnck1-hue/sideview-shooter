class_name StationMap
extends Control
## 스테이션 개략도 — 단말기 화면(TerminalScreen) 안에 그리는 벡터 선화 지도.
## 컨셉과 판독 규칙은 Docs/STATION_MAP.md.
##
## **레이아웃은 손으로 찍지 않는다.** RoomData.ROOMS 의 측벽문(left/right_door)을 따라가면
## 구역마다 가로 사슬이 나오고, 정면문(front_doors)이 그 사슬들을 세로로 잇는다 —
## room_data.gd 머리말의 지도 그림이 곧 이 파일의 출력이다. 그래서 맵을 고쳐도 지도는 따라온다.
##
## 방 칸은 네모가 아니라 그 방의 **열 프로필(shape)** 을 축소한 실루엣으로 그린다.
## 대형 홀은 가운데가 솟고 복도는 납작하다 — 지도가 "방 목록"이 아니라 스테이션 단면도로 읽힌다.
## 가로/세로 배율은 일부러 다르다(uy <= ux). 실제 셀은 정사각이지만 27개 방을 한 화면에 넣으려면
## 가로를 더 눌러야 한다 — 절대 크기는 버리고 **모양의 상대 비율만** 지킨다.
##
## 두 가지로 쓴다.
##   survey 모드   구역 현황 단말기의 지도 모듈. 커서가 **방** 위를 돈다 (판독 정보 열람).
##   grid 모드     보안 관제 단말기의 방어 그리드. 커서가 **포탑** 위를 돈다 (ENTER 로 원격 접속).
##
## 판독 등급 (Reveal)
##   LIVE   단말기 관할 구역(TerminalData 의 grid) — 실시간. 개체 밀도까지 읽힌다.
##   KNOWN  플레이어가 직접 다녀온 방(AppFlow.visited) — 형상·이름은 알지만 판독은 과거 것.
##   DARK   둘 다 아닌 방 — 윤곽선만. 이름도 내용도 뜨지 않는다.

enum Reveal { DARK, KNOWN, LIVE }

## 지도의 줄 순서. room_data.gd 머리말의 그림과 같게 둔다 (정비 → 승무원 → 전력 → 수경재배 → 연구).
const ZONE_ROWS := [RoomData.ZONE_WORKSHOP, RoomData.ZONE_CREW, RoomData.ZONE_POWER, RoomData.ZONE_HYDRO,
	RoomData.ZONE_RESEARCH]

const MIN_W := 4                    # 지도에서의 방 최소 폭(셀)
const MAX_W := 13                   # 최대 폭 — 격납고(32셀)가 에어록(7셀)을 짓누르지 않게 누른다
const MAX_H := 9
const GAP := 2                      # 방 사이 빈 셀 (측벽문 연결선이 지나간다)
const LABEL_W := 124.0              # 왼쪽 구역 이름 자리 ("수경재배 구역" 이 잘리지 않을 만큼)
const PAD := 14.0
const INFO_H := 86.0                # 아래 판독 정보 두 줄
const BLINK := 0.45

# CRT 프리셋이 채도를 죽이고 단색 형광을 입히므로 여기서는 거의 무채색으로만 그린다.
const C_DARK := Color(0.28, 0.31, 0.28)
const C_LINE := Color(0.60, 0.64, 0.60)
const C_LIVE := Color(0.88, 0.91, 0.88)
const C_FILL_KNOWN := Color(0.09, 0.12, 0.10, 0.85)
const C_FILL_LIVE := Color(0.17, 0.22, 0.18, 0.90)
const C_TEXT := Color(0.72, 0.76, 0.72)
const C_DIM := Color(0.42, 0.46, 0.42)
const C_BRIGHT := Color(1.0, 1.0, 1.0)

var mode := "survey"                # survey | grid
var here := ""                      # 플레이어의 몸이 실제로 있는 방
var live: Dictionary = {}           # 실시간 판독 방 id → true
var entries: Array = []             # grid 모드: TerminalData.grid_entries() 결과
var sel := 0                        # _targets 안의 커서

var _targets: Array = []            # 커서가 설 수 있는 대상 [{"room", "row", "cx", "entry"}]
var _geom: Dictionary = {}          # 방 id → {"x0", "w", "floor", "top"} (마지막 _draw 기준 픽셀)
var _font: Font
var _blink_t := 0.0
var _blink_on := true


# ─────────────────────────────────────────────────────────── 레이아웃 (정적)

static var _cache: Dictionary = {}

## 지도 골격 — {"nodes": {방 id: 노드}, "rows": [[방 id, ...], ...], "front": [[a, b], ...], "cols": 총 가로 셀}
## 노드: {"id", "zone", "row", "col", "cells", "shape", "marks"}
static func layout() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var nodes := {}
	var rows: Array = []
	for r in ZONE_ROWS.size():
		var chain := _chain(str(ZONE_ROWS[r]))
		rows.append(chain)
		var col := 0
		for raw_id in chain:
			var id := str(raw_id)
			var cells := clampi(_total_cells(id), MIN_W, MAX_W)
			nodes[id] = {
				"id": id, "zone": str(ZONE_ROWS[r]), "row": r, "col": col, "cells": cells,
				"shape": RoomData.ROOMS[id]["shape"], "marks": _marks(id),
			}
			col += cells + GAP

	# 정면문 — 양쪽이 서로를 가리키므로 id 쌍으로 한 번만 담는다
	var front: Array = []
	var seen := {}
	for raw_room in RoomData.ROOMS:
		var room_id := str(raw_room)
		for fd in RoomData.ROOMS[room_id].get("front_doors", []):
			var target := str(fd.get("target", ""))
			if not nodes.has(room_id) or not nodes.has(target):
				continue
			var key := room_id + "|" + target
			if target < room_id:
				key = target + "|" + room_id
			if seen.has(key):
				continue
			seen[key] = true
			front.append([room_id, target])

	# 줄 밀기 — 먼저 놓인 줄과 정면문으로 이어진 방이 세로로 가깝게 오도록 줄 전체를 옮긴다.
	# (머리말 그림에서 [작업실] 아래에 [숙소 복도]가 오는 그 정렬을 자동으로 만든다)
	var placed := {}
	for id0 in rows[0]:
		placed[str(id0)] = true
	for r2 in range(1, rows.size()):
		var cands: Array = [0]
		for link in front:
			var pairs := [[str(link[0]), str(link[1])], [str(link[1]), str(link[0])]]
			for pair in pairs:
				if int(nodes[pair[0]]["row"]) == r2 and placed.has(pair[1]):
					cands.append(int(round(_center(nodes[pair[1]]) - _center(nodes[pair[0]]))))
		var best_off := 0
		var best_cost := INF
		for off in cands:
			var cost := 0.0
			for link2 in front:
				var pairs2 := [[str(link2[0]), str(link2[1])], [str(link2[1]), str(link2[0])]]
				for pair2 in pairs2:
					if int(nodes[pair2[0]]["row"]) == r2 and placed.has(pair2[1]):
						cost += absf(_center(nodes[pair2[1]]) - (_center(nodes[pair2[0]]) + float(off)))
			if cost < best_cost:
				best_cost = cost
				best_off = int(off)
		for raw_id2 in rows[r2]:
			var id2 := str(raw_id2)
			nodes[id2]["col"] = int(nodes[id2]["col"]) + best_off
			placed[id2] = true

	# 왼쪽 끝을 0 으로 정규화
	var min_col := 0
	for id3 in nodes:
		min_col = mini(min_col, int(nodes[id3]["col"]))
	var cols := 1
	for id4 in nodes:
		nodes[id4]["col"] = int(nodes[id4]["col"]) - min_col
		cols = maxi(cols, int(nodes[id4]["col"]) + int(nodes[id4]["cells"]))
	_cache = {"nodes": nodes, "front": front, "cols": cols, "rows": rows}
	return _cache


## 맵 데이터를 고친 뒤 다시 짜게 한다 (도구·테스트용)
static func invalidate() -> void:
	_cache = {}


## 한 구역의 방을 측벽문을 따라 왼쪽 끝부터 줄 세운다
static func _chain(zone: String) -> Array:
	var members: Array = []
	for raw_id in RoomData.ROOMS:
		var id := str(raw_id)
		if str(RoomData.ROOMS[id].get("zone", "")) == zone:
			members.append(id)
	if members.is_empty():
		return []
	var head := ""
	for raw_head in members:
		var id2 := str(raw_head)
		var d: Dictionary = RoomData.ROOMS[id2]["left_door"]
		if not d.get("open", false) or not members.has(str(d.get("target", ""))):
			head = id2
			break
	if head == "":
		head = str(members[0])
	var order: Array = []
	var cur := head
	while cur != "":
		order.append(cur)
		var rd: Dictionary = RoomData.ROOMS[cur]["right_door"]
		var nxt := str(rd.get("target", ""))
		cur = ""
		if rd.get("open", false) and members.has(nxt) and not order.has(nxt):
			cur = nxt
	for raw_rest in members:             # 사슬에서 떨어진 방이 생기면 뒤에 붙인다 (지도에서 사라지지 않게)
		var id3 := str(raw_rest)
		if not order.has(id3):
			order.append(id3)
	return order


static func _total_cells(id: String) -> int:
	var n := 0
	for s in RoomData.ROOMS[id]["shape"]:
		n += int(s[0])
	return n


static func _center(node: Dictionary) -> float:
	return float(node["col"]) + float(node["cells"]) * 0.5


## 방 안에 표시할 것 — 배치는 RoomData.props 가 단일 출처다
static func _marks(id: String) -> Dictionary:
	var sentries: Array = []
	var terminals: Array = []
	var npcs := 0
	var data: Dictionary = RoomData.ROOMS[id]
	var width := maxf(float(RoomData.room_width(id)), 1.0)
	for p in data.get("props", []):
		var kind := str(p.get("type", ""))
		if kind != "sentry" and kind != "terminal" and kind != "npc":
			continue
		var ratio := clampf(float(p.get("x", width * 0.5)) / width, 0.06, 0.94)
		match kind:
			"sentry":
				sentries.append({"id": str(p.get("id", "")), "ratio": ratio})
			"terminal":
				terminals.append({"id": str(p.get("id", "")), "ratio": ratio})
			"npc":
				npcs += 1
	return {"sentries": sentries, "terminals": terminals, "npcs": npcs}


## 방 제목에서 괄호 영문을 떼어 낸 짧은 이름
static func short_title(id: String) -> String:
	var t := str(RoomData.ROOMS[id].get("title", id))
	var i := t.find(" (")
	return t.substr(0, i) if i > 0 else t


# ─────────────────────────────────────────────────────────── 설정

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "D2Coding", "NanumGothicCoding", "Malgun Gothic", "맑은 고딕"])
	_font = f


## 구역 현황 단말기의 지도 — 커서가 모든 방 위를 돈다.
## 미판독 방도 커서는 간다 ("저기에 방이 하나 더 있다" 까지는 개략도에 남는다).
func setup_survey(grid: Array, here_room: String) -> void:
	mode = "survey"
	here = here_room
	entries = []
	_set_live(grid)
	_targets = []
	var lay := layout()
	for r in lay["rows"].size():
		for raw_id in lay["rows"][r]:
			var id := str(raw_id)
			_targets.append({"room": id, "row": r, "cx": _center(lay["nodes"][id]), "entry": -1})
	sel = 0
	for i in _targets.size():
		if str(_targets[i]["room"]) == here_room:
			sel = i
			break
	queue_redraw()


## 보안 관제 단말기의 방어 그리드 — 커서가 **관할 포탑** 위만 돈다.
## 관할 밖 포탑은 어둡게 그려지되 커서가 서지 않는다 ("있는 건 보이는데 여기선 못 잡는다").
func setup_grid(grid_entries: Array, grid: Array, here_room: String) -> void:
	mode = "grid"
	here = here_room
	entries = grid_entries
	_set_live(grid)
	_targets = []
	var lay := layout()
	for i in entries.size():
		var e: Dictionary = entries[i]
		if not e.get("authorized", false):
			continue
		var id := str(e["room"])
		if not lay["nodes"].has(id):
			continue
		_targets.append({"room": id, "row": int(lay["nodes"][id]["row"]), "cx": _center(lay["nodes"][id]), "entry": i})
	sel = 0
	for i2 in _targets.size():           # 이 방의 포탑이 있으면 거기서 시작한다
		if str(_targets[i2]["room"]) == here_room:
			sel = i2
			break
	queue_redraw()


func _set_live(grid: Array) -> void:
	live = {}
	for raw_id in RoomData.ROOMS:
		var id := str(raw_id)
		if grid.has(id) or grid.has(str(RoomData.ROOMS[id].get("zone", ""))):
			live[id] = true


## 특정 포탑으로 커서를 옮긴다 (원격에서 돌아왔을 때 방금 잡았던 포탑 위에 서 있게)
func select_sentry(sentry_id: String) -> void:
	for i in _targets.size():
		var idx := int(_targets[i]["entry"])
		if idx >= 0 and str(entries[idx]["id"]) == sentry_id:
			sel = i
			queue_redraw()
			return


func has_targets() -> bool:
	return not _targets.is_empty()


## 지금 커서가 잡은 것 — {"room", "row", "cx", "entry"}. entry 는 grid 모드의 entries 인덱스(survey 는 -1).
func selected() -> Dictionary:
	if _targets.is_empty():
		return {}
	return _targets[sel]


func selected_entry() -> int:
	var t := selected()
	return -1 if t.is_empty() else int(t.get("entry", -1))


## 커서 이동. 좌우는 같은 줄 안에서, 상하는 가장 가까운 열의 다른 줄로 건너뛴다.
func move(dir: Vector2i) -> bool:
	if _targets.size() <= 1:
		return false
	var cur: Dictionary = _targets[sel]
	var best := -1
	if dir.x != 0:
		var bd := INF
		for i in _targets.size():
			var t: Dictionary = _targets[i]
			if int(t["row"]) != int(cur["row"]):
				continue
			var dx := float(t["cx"]) - float(cur["cx"])
			if dx * float(dir.x) <= 0.0:
				continue
			if absf(dx) < bd:
				bd = absf(dx)
				best = i
	else:
		for step in range(1, ZONE_ROWS.size()):
			var rr := wrapi(int(cur["row"]) + dir.y * step, 0, ZONE_ROWS.size())
			var bd2 := INF
			for i2 in _targets.size():
				var t2: Dictionary = _targets[i2]
				if int(t2["row"]) != rr:
					continue
				var dx2 := absf(float(t2["cx"]) - float(cur["cx"]))
				if dx2 < bd2:
					bd2 = dx2
					best = i2
			if best >= 0:
				break
	if best < 0 or best == sel:
		return false
	sel = best
	queue_redraw()
	return true


func reveal_of(id: String) -> int:
	if live.has(id):
		return Reveal.LIVE
	if AppFlow.visited.has(id):
		return Reveal.KNOWN
	return Reveal.DARK


func _process(delta: float) -> void:
	if not visible:
		return
	_blink_t += delta
	if _blink_t >= BLINK:
		_blink_t -= BLINK
		_blink_on = not _blink_on
		queue_redraw()


# ─────────────────────────────────────────────────────────── 그리기

func _draw() -> void:
	var lay := layout()
	var nodes: Dictionary = lay["nodes"]
	var cols := maxi(int(lay["cols"]), 1)
	var ux := (size.x - PAD * 2.0 - LABEL_W) / float(cols)
	var band := (size.y - INFO_H) / float(ZONE_ROWS.size())
	var uy := minf(ux, (band - 30.0) / float(MAX_H))
	_geom = {}
	for raw_id in nodes:
		var id := str(raw_id)
		var n: Dictionary = nodes[id]
		var fy := band * float(n["row"]) + band - 26.0
		_geom[id] = {
			"x0": PAD + LABEL_W + float(n["col"]) * ux,
			"w": float(n["cells"]) * ux,
			"floor": fy,
			"top": fy - float(_tall(n)) * uy,
		}

	_draw_links(lay, band)
	for r in ZONE_ROWS.size():
		_draw_zone_label(r, band)
		for raw_id2 in lay["rows"][r]:
			_draw_room(nodes[str(raw_id2)], uy)
	_draw_cursor()
	_draw_info()


func _tall(n: Dictionary) -> int:
	var h := 1
	for s in n["shape"]:
		h = maxi(h, int(s[1]))
	return clampi(h, 1, MAX_H)


func _draw_zone_label(r: int, band: float) -> void:
	var y := band * float(r) + band - 34.0
	draw_string(_font, Vector2(PAD, y), str(ZONE_ROWS[r]), HORIZONTAL_ALIGNMENT_LEFT, LABEL_W - 12.0, 15, C_DIM)


## 연결선 — 측벽문은 바닥선을 잇는 가로 실선, 정면문은 줄과 줄을 잇는 세로 점선.
## 같은 줄 안에서 이어지는 정면문(숙소 복도 ↔ 식당)은 줄 위로 넘어가는 호로 그린다 — 지름길로 읽힌다.
func _draw_links(lay: Dictionary, band: float) -> void:
	var nodes: Dictionary = lay["nodes"]
	for r in lay["rows"].size():
		var chain: Array = lay["rows"][r]
		for i in range(chain.size() - 1):
			var a := str(chain[i])
			var b := str(chain[i + 1])
			if not RoomData.ROOMS[a]["right_door"].get("open", false):
				continue
			var ga: Dictionary = _geom[a]
			var gb: Dictionary = _geom[b]
			var col := C_DARK
			if reveal_of(a) != Reveal.DARK or reveal_of(b) != Reveal.DARK:
				col = C_LINE
			draw_line(Vector2(float(ga["x0"]) + float(ga["w"]), float(ga["floor"])),
				Vector2(float(gb["x0"]), float(gb["floor"])), col, 1.0)

	for link in lay["front"]:
		var a2 := str(link[0])
		var b2 := str(link[1])
		var up := a2
		var down := b2
		if int(nodes[b2]["row"]) < int(nodes[a2]["row"]):
			up = b2
			down = a2
		var gu: Dictionary = _geom[up]
		var gd: Dictionary = _geom[down]
		var xu := float(gu["x0"]) + float(gu["w"]) * _front_ratio(up, down)
		var xd := float(gd["x0"]) + float(gd["w"]) * _front_ratio(down, up)
		var col2 := C_DARK
		if reveal_of(up) != Reveal.DARK or reveal_of(down) != Reveal.DARK:
			col2 = C_LINE
		if int(nodes[up]["row"]) == int(nodes[down]["row"]):
			var over := band * float(nodes[up]["row"]) + 5.0
			_dash(Vector2(xu, float(gu["top"]) - 5.0), Vector2(xu, over), col2)
			_dash(Vector2(xu, over), Vector2(xd, over), col2)
			_dash(Vector2(xd, over), Vector2(xd, float(gd["top"]) - 5.0), col2)
			continue
		var y0 := float(gu["floor"]) + 5.0
		var y1 := float(gd["top"]) - 5.0
		var mid := (y0 + y1) * 0.5
		_dash(Vector2(xu, y0), Vector2(xu, mid), col2)
		_dash(Vector2(xu, mid), Vector2(xd, mid), col2)
		_dash(Vector2(xd, mid), Vector2(xd, y1), col2)


## 방 안에서 그 정면문이 있는 가로 위치 비율
func _front_ratio(id: String, target: String) -> float:
	var w := maxf(float(RoomData.room_width(id)), 1.0)
	for fd in RoomData.ROOMS[id].get("front_doors", []):
		if str(fd.get("target", "")) == target:
			return clampf((float(fd["x"]) + RoomData.FRONT_DOOR_W * 0.5) / w, 0.06, 0.94)
	return 0.5


func _draw_room(n: Dictionary, uy: float) -> void:
	var id := str(n["id"])
	var g: Dictionary = _geom[id]
	var rev := reveal_of(id)
	var pts := _room_points(n, float(g["x0"]), float(g["floor"]), float(g["w"]), uy)
	if rev != Reveal.DARK:
		draw_colored_polygon(pts, C_FILL_LIVE if rev == Reveal.LIVE else C_FILL_KNOWN)
	var line := C_DARK
	if rev == Reveal.LIVE:
		line = C_LIVE
	elif rev == Reveal.KNOWN:
		line = C_LINE
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, line, 1.0)

	# 방어 그리드는 센서 판독과 별개다 — 그리드에 등록된 포탑은 미판독 방에 있어도 잡힌다.
	# 그래서 grid 모드에서는 포탑이 있는 방을 어둡게라도 이름까지 보여 준다
	# ("저 방에 포탑이 있는데 여기선 못 잡는다" 가 다음 단말기를 찾게 만드는 동기다).
	var sentries: Array = n["marks"]["sentries"]
	var detected: bool = mode == "grid" and not sentries.is_empty()
	if rev != Reveal.DARK or detected:
		_draw_marks(n)
	var label := "· · ·"
	if rev != Reveal.DARK or detected:
		label = short_title(id)
	var name_col := C_TEXT if rev != Reveal.DARK else C_DARK
	draw_string(_font, Vector2(float(g["x0"]) - GAP * 5.0, float(g["floor"]) + 15.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, float(g["w"]) + GAP * 10.0, 12, name_col)

	if id == here:                       # 플레이어의 몸이 있는 자리 — 원격으로 보는 방과 구별된다
		var cx := float(g["x0"]) + float(g["w"]) * 0.5
		var ty := float(g["top"]) - 9.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 5.0, ty - 9.0), Vector2(cx + 5.0, ty - 9.0), Vector2(cx, ty)]), C_BRIGHT)


## 열 프로필(shape)을 그대로 축소한 실루엣. 셀 수는 눌렀어도 단 차이의 비율은 남는다.
func _room_points(n: Dictionary, x0: float, fy: float, w: float, uy: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var shape: Array = n["shape"]
	var total := 0
	for s in shape:
		total += int(s[0])
	total = maxi(total, 1)
	var x := x0
	pts.append(Vector2(x, fy))
	for s2 in shape:
		var sw := float(s2[0]) / float(total) * w
		var h := float(clampi(int(s2[1]), 1, MAX_H)) * uy
		pts.append(Vector2(x, fy - h))
		pts.append(Vector2(x + sw, fy - h))
		x += sw
	pts.append(Vector2(x, fy))
	return pts


## 방 안의 표시 — 포탑 ▲ · 단말기 ▫ · 생존자 ● · (실시간일 때만) 개체 밀도 막대
func _draw_marks(n: Dictionary) -> void:
	var id := str(n["id"])
	var g: Dictionary = _geom[id]
	var fy := float(g["floor"])
	var marks: Dictionary = n["marks"]
	if reveal_of(id) != Reveal.DARK:                # 단말기·생존자는 센서가 읽어야 보인다
		for t in marks["terminals"]:
			var x := float(g["x0"]) + float(g["w"]) * float(t["ratio"])
			draw_rect(Rect2(x - 2.0, fy - 7.0, 4.0, 5.0), C_TEXT, false, 1.0)
		if int(marks["npcs"]) > 0:
			var nx := float(g["x0"]) + 7.0
			for i in mini(int(marks["npcs"]), 3):
				draw_circle(Vector2(nx + float(i) * 6.0, fy - 4.0), 2.0, C_TEXT)
	for s in marks["sentries"]:
		var sx := float(g["x0"]) + float(g["w"]) * float(s["ratio"])
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx - 5.0, fy - 1.0), Vector2(sx + 5.0, fy - 1.0), Vector2(sx, fy - 11.0)]),
			_sentry_color(str(s["id"])))
	if reveal_of(id) == Reveal.LIVE:
		var d := RoomData.danger(id)
		var bars := 0
		if d == "적음":
			bars = 1
		elif d == "위험":
			bars = 3
		for b in bars:
			draw_rect(Rect2(float(g["x0"]) + float(g["w"]) - 6.0 - float(b) * 5.0, float(g["top"]) + 3.0, 3.0, 7.0), C_LIVE)


## grid 모드에서 포탑의 상태색 — 관할 안은 밝게, 관할 밖은 어둡게 (있다는 것만 보인다)
func _sentry_color(sentry_id: String) -> Color:
	if mode != "grid":
		return C_TEXT
	for e in entries:
		if str(e["id"]) == sentry_id:
			return C_LIVE if e.get("authorized", false) else C_DARK
	return C_DARK


## 커서 — 선택한 방을 네 귀퉁이 꺾쇠로 감싸고 깜빡인다
func _draw_cursor() -> void:
	var t := selected()
	if t.is_empty():
		return
	var g: Dictionary = _geom.get(str(t["room"]), {})
	if g.is_empty():
		return
	var r := Rect2(float(g["x0"]) - 5.0, float(g["top"]) - 5.0,
		float(g["w"]) + 10.0, float(g["floor"]) - float(g["top"]) + 10.0)
	var col := C_BRIGHT if _blink_on else C_LINE
	var a := minf(14.0, r.size.x * 0.4)
	var corners := [
		[r.position, Vector2(1, 1)],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
		[Vector2(r.position.x, r.end.y), Vector2(1, -1)],
		[r.end, Vector2(-1, -1)],
	]
	for c in corners:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		draw_line(p, p + Vector2(a * d.x, 0.0), col, 1.0)
		draw_line(p, p + Vector2(0.0, a * d.y), col, 1.0)


func _draw_info() -> void:
	var y := size.y - INFO_H + 22.0
	draw_line(Vector2(PAD, y - 24.0), Vector2(size.x - PAD, y - 24.0), Color(0.35, 0.39, 0.35, 0.7), 1.0)
	var t := selected()
	if t.is_empty():
		draw_string(_font, Vector2(PAD, y), "잡을 수 있는 포탑이 없습니다 — 이 단말의 관할 밖입니다",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0, 18, C_DIM)
		return
	var id := str(t["room"])
	var head := ""
	var note := ""
	if mode == "grid":
		var e: Dictionary = entries[int(t["entry"])]
		head = "%s      %s  ·  %s" % [str(e["name"]), str(e["zone"]), str(e["room_title"])]
		var tail := "원격 접속 가능"
		if e.get("local", false):
			tail = "이 방 — 몸으로도 잡을 수 있습니다"
		note = "ENTER  채널 연결      상태: 무인 대기  ·  %s" % tail
	else:
		var rev := reveal_of(id)
		if rev == Reveal.DARK:
			head = "미판독 구역      센서 응답 없음"
			note = "직접 다녀오거나, 이 구역을 관할하는 현황 단말기에서 읽어야 합니다"
		else:
			var marks: Dictionary = layout()["nodes"][id]["marks"]
			head = "%s      %s" % [str(RoomData.ROOMS[id]["title"]), str(RoomData.ROOMS[id].get("zone", ""))]
			var stat := "실시간 판독"
			var density := RoomData.danger(id)
			if rev != Reveal.LIVE:
				stat = "최종 판독 — 관할 밖(과거 기록)"
				density = "판독 불가"
			note = "%s      개체 밀도: %s      단말 %d · 방어포 %d · 생존자 %d" % [
				stat, density, marks["terminals"].size(), marks["sentries"].size(), int(marks["npcs"])]
	draw_string(_font, Vector2(PAD, y), head, HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0, 19, C_BRIGHT)
	draw_string(_font, Vector2(PAD, y + 26.0), note, HORIZONTAL_ALIGNMENT_LEFT, size.x - PAD * 2.0, 17, C_DIM)


func _dash(a: Vector2, b: Vector2, col: Color, w := 1.0, dash := 5.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.5:
		return
	var n := d / l
	var t := 0.0
	while t < l:
		var e := minf(t + dash, l)
		draw_line(a + n * t, a + n * e, col, w)
		t = e + dash
