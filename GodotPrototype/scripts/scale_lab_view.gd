class_name ScaleLabView
extends Node2D
## 규격 비교 테스트 씬의 그레이박스 그리기. 데이터는 ScaleLabData, 판정은 scale_lab.gd.
##
## 층 (Room 의 자식으로 붙는다 — z 는 Room 기준)
##   Backdrop   z0  타일 위를 덮는 무지 배경 + 32/128 격자 + 바닥 눈금  (B 로 끄면 뒤의 실제 타일이 보인다)
##   Solids     z2  충돌 지형 · 통과 배경 · 상호작용 자리 · 기존 아트 스프라이트  (캐릭터 뒤)
##   Front      z7  전경 가림막  (캐릭터 앞)
##   Labels     z9  치수 · 판정 결과 · 기준선  (H 로 전체 / 간단 / 끄기)
##   JudgeBox   z9  플레이어의 지금 판정 상자 (매 프레임)

const COLORS := {
	"back": Color(0.10, 0.11, 0.13),
	"grid32": Color(0.125, 0.135, 0.155),
	"grid128": Color(0.16, 0.17, 0.195),
	"floor": Color(0.06, 0.065, 0.075),
	"floor_line": Color(0.72, 0.76, 0.82),
	"solid": Color(0.23, 0.245, 0.27),
	"solid_edge": Color(0.52, 0.55, 0.60),
	"hatch": Color(0.18, 0.19, 0.215),
	"backdrop": Color(0.14, 0.26, 0.48, 0.55),
	"backdrop_edge": Color(0.52, 0.72, 1.0, 0.9),
	"interact": Color(0.55, 0.32, 0.10, 0.60),
	"interact_edge": Color(1.0, 0.76, 0.40, 0.95),
	"occluder": Color(0.26, 0.16, 0.40, 0.90),
	"occluder_edge": Color(0.74, 0.58, 1.0, 1.0),
	"ghost": Color(0.95, 0.95, 0.98, 0.75),
	"text": Color(0.93, 0.94, 0.96),
	"dim": Color(0.64, 0.67, 0.73),
	"stand": Color(0.46, 0.92, 0.52),
	"roll": Color(1.0, 0.80, 0.30),
	"none": Color(1.0, 0.42, 0.36),
	"muzzle": Color(1.0, 0.55, 0.30, 0.8),
	"line_stand": Color(0.46, 0.92, 0.52, 0.55),
	"line_crouch": Color(0.55, 0.80, 1.0, 0.55),
	"line_roll": Color(1.0, 0.80, 0.30, 0.55),
	"art_box": Color(0.4, 1.0, 0.9, 0.9),
}
const FONT_SIZE := 26
const FONT_SMALL := 21

var rule: Dictionary = ScaleLabData.RULES[ScaleLabData.RULE_DEFAULT]
var step_max: float = ScaleLabData.STEP_RULES[ScaleLabData.STEP_DEFAULT]
var label_mode := 0                   # 0 전체 · 1 간단 · 2 끄기
var player: Node2D
var judge := {"h": 0.0, "g": 0.0, "state": "", "blocked": false, "forced": false}

var font: SystemFont
var _backdrop: Node2D
var _solids: Node2D
var _front: Node2D
var _labels: Node2D
var _judge: Node2D
var _art_boxes: Array = []           # [{rect(불투명 영역, 월드), label}]


func setup(room: Room) -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	_backdrop = _layer(room, "GreyboxBackdrop", 0, _draw_backdrop)
	# 타일(자식 0) 바로 위 — 다른 모든 방 층보다 먼저 그려진다
	room.move_child(_backdrop, 1)
	_solids = _layer(room, "GreyboxSolids", 2, _draw_solids)
	_front = _layer(room, "GreyboxFront", DepthLayers.Z_FOREGROUND, _draw_front)
	_labels = _layer(room, "GreyboxLabels", DepthLayers.Z_FOREGROUND + 2, _draw_labels)
	_judge = _layer(room, "GreyboxJudge", DepthLayers.Z_FOREGROUND + 2, _draw_judge)
	_build_art()


func _layer(room: Node, n: String, z: int, fn: Callable) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.z_index = z
	l.draw.connect(fn.bind(l))
	room.add_child(l)
	return l


func set_rules(r: Dictionary, s: float) -> void:
	rule = r
	step_max = s
	_labels.queue_redraw()


func set_label_mode(m: int) -> void:
	label_mode = m
	_labels.visible = m < 2
	_labels.queue_redraw()


func set_backdrop(on: bool) -> void:
	_backdrop.visible = on


func backdrop_on() -> bool:
	return _backdrop.visible


func update_judge(j: Dictionary) -> void:
	judge = j
	_judge.queue_redraw()


# ── 기존 아트 ────────────────────────────────────────────────────────────────

func _build_art() -> void:
	for it in ScaleLabData.items():
		if it["kind"] != "art":
			continue
		var tex := load(it["path"]) as Texture2D
		if tex == null:
			continue
		var used := Rect2i(Vector2i.ZERO, Vector2i(tex.get_width(), tex.get_height()))
		var img := tex.get_image()
		if img != null:
			used = img.get_used_rect()
		var s := Sprite2D.new()
		s.centered = false
		s.texture = tex
		var r: Rect2 = it["rect"]
		var top := ScaleLabData.FLOOR - float(used.end.y)                  # 불투명 하단 = 바닥
		if it["place"] == "front":
			top = ScaleLabData.FLOOR - Room.FRONT_DOOR_LIFT
		s.position = Vector2(r.position.x, top)
		_solids.add_child(s)
		var box := Rect2(s.position + Vector2(used.position), Vector2(used.size))
		it["used"] = box
		_art_boxes.append({"rect": box, "label": it["label"],
			"canvas": Vector2i(tex.get_width(), tex.get_height())})


# ── 그리기 ──────────────────────────────────────────────────────────────────

func _draw_backdrop(c: CanvasItem) -> void:
	var x1 := ScaleLabData.greybox_end()
	var top := ScaleLabData.CEIL_TOP
	var bottom := ScaleLabData.FLOOR + 50.0
	c.draw_rect(Rect2(0, top, x1, ScaleLabData.FLOOR - top), COLORS["back"])
	var x := 0.0
	while x <= x1:
		var major := int(x) % ScaleLabData.CELL == 0
		c.draw_line(Vector2(x, top), Vector2(x, ScaleLabData.FLOOR), COLORS["grid128"] if major else COLORS["grid32"], 2.0 if major else 1.0)
		x += ScaleLabData.SUB
	var y := ScaleLabData.FLOOR
	while y >= top:
		var major := int(ScaleLabData.FLOOR - y) % ScaleLabData.CELL == 0
		c.draw_line(Vector2(0, y), Vector2(x1, y), COLORS["grid128"] if major else COLORS["grid32"], 2.0 if major else 1.0)
		y -= ScaleLabData.SUB
	# 바닥 — 밟는 선과 그 아래 띠, 눈금 (32 짧게 · 128 길게 · 1024 마다 x 표시)
	c.draw_rect(Rect2(0, ScaleLabData.FLOOR, x1, bottom - ScaleLabData.FLOOR), COLORS["floor"])
	x = 0.0
	while x <= x1:
		var big := int(x) % ScaleLabData.CELL == 0
		c.draw_line(Vector2(x, ScaleLabData.FLOOR), Vector2(x, ScaleLabData.FLOOR + (16.0 if big else 7.0)), COLORS["dim"], 2.0 if big else 1.0)
		if int(x) % 1024 == 0:
			c.draw_string(font, Vector2(x + 4, ScaleLabData.FLOOR + 40), "x %d" % int(x), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SMALL, COLORS["dim"])
		x += ScaleLabData.SUB
	c.draw_line(Vector2(0, ScaleLabData.FLOOR), Vector2(x1, ScaleLabData.FLOOR), COLORS["floor_line"], 3.0)


func _draw_solids(c: CanvasItem) -> void:
	for it in ScaleLabData.items():
		var r: Rect2 = it["rect"]
		match it["kind"]:
			"ground", "overhead":
				c.draw_rect(r, COLORS["solid"])
				if it["kind"] == "overhead":
					_hatch(c, r)
				c.draw_rect(r, COLORS["solid_edge"], false, 3.0)
			"backdrop":
				c.draw_rect(r, COLORS["backdrop"])
				c.draw_rect(r, COLORS["backdrop_edge"], false, 2.0)
			"interact":
				c.draw_rect(r, COLORS["interact"])
				c.draw_rect(r, COLORS["interact_edge"], false, 2.0)
			"pole":
				c.draw_rect(r, COLORS["solid_edge"])


func _hatch(c: CanvasItem, r: Rect2) -> void:
	# 천장에서 내려온 지형은 사선을 넣어 바닥에 선 상자와 구별한다
	var step := 48.0
	var k := -r.size.y
	while k < r.size.x:
		var a := Vector2(r.position.x + maxf(k, 0.0), r.position.y + maxf(-k, 0.0))
		var t := minf(r.size.x - maxf(k, 0.0), r.size.y - maxf(-k, 0.0))
		if t > 0.0:
			c.draw_line(a, a + Vector2(t, t), COLORS["hatch"], 2.0)
		k += step


func _draw_front(c: CanvasItem) -> void:
	for it in ScaleLabData.items():
		if it["kind"] == "occluder":
			c.draw_rect(it["rect"], COLORS["occluder"])
			c.draw_rect(it["rect"], COLORS["occluder_edge"], false, 2.0)


func _draw_labels(c: CanvasItem) -> void:
	if label_mode >= 2:
		return
	var full := label_mode == 0
	var spans := ScaleLabData.zone_spans()
	# 구역 제목 — 구역 시작 위쪽
	for zi in range(spans.size()):
		var z: Dictionary = ScaleLabData.ZONES[zi]
		var zx := float(spans[zi][0]) + 40.0
		c.draw_string(font, Vector2(zx, ScaleLabData.FLOOR - 452.0), z["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, COLORS["text"])
		if full:
			c.draw_string(font, Vector2(zx, ScaleLabData.FLOOR - 418.0), z["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SMALL, COLORS["dim"])
		c.draw_line(Vector2(float(spans[zi][0]), ScaleLabData.FLOOR - 700.0), Vector2(float(spans[zi][0]), ScaleLabData.FLOOR), Color(1, 1, 1, 0.18), 2.0)
	# 문·통로 구역에 판정 높이 기준선
	for zi in [1, 2]:
		var x0 := float(spans[zi][0])
		var x1 := float(spans[zi][1])
		_hline(c, x0, x1, float(rule["stand"]), COLORS["line_stand"], "서기 %d" % int(rule["stand"]))
		_hline(c, x0, x1, float(rule["crouch"]), COLORS["line_crouch"], "웅크림 %d" % int(rule["crouch"]))
		_hline(c, x0, x1, float(rule["roll"]), COLORS["line_roll"], "구르기 %d" % int(rule["roll"]))
	# 엄폐 구역에 총구 높이
	var cz: Array = spans[4]
	_hline(c, float(cz[0]), float(cz[1]), ScaleLabData.MUZZLE_STAND, COLORS["muzzle"], "서서 총구 160")
	_hline(c, float(cz[0]), float(cz[1]), ScaleLabData.MUZZLE_CROUCH, COLORS["muzzle"], "웅크려 총구 94")

	for it in ScaleLabData.items():
		var r: Rect2 = it["rect"]
		var cx := r.get_center().x
		match it["kind"]:
			"overhead":
				if not it.has("stand_x"):
					continue
				var cl: float = it["clear"]
				var v := ScaleLabData.pass_verdict(cl, float(it["length"]), rule)
				_dim_v(c, r.position.x - 18.0, 0.0, cl, str(int(cl)))
				_text(c, Vector2(cx, r.end.y - 58.0), it["label"], FONT_SIZE, COLORS["text"])
				_text(c, Vector2(cx, r.end.y - 22.0), v["text"], FONT_SMALL, COLORS[v["verdict"]])
				if full:
					_text(c, Vector2(cx, r.end.y - 94.0), "키 대비 %.2f배" % (cl / ScaleLabData.STAND_H), FONT_SMALL, COLORS["dim"])
			"ground":
				if it.get("label", "") == "":
					continue
				var h: float = ScaleLabData.FLOOR - r.position.y
				var y := r.position.y - 16.0
				if it.has("cover"):
					var lines := ScaleLabData.cover_verdict(h).split("\n")
					_text(c, Vector2(cx, y - 110.0), it["label"], FONT_SIZE, COLORS["text"])
					_text(c, Vector2(cx, y - 76.0), lines[0], FONT_SMALL, COLORS["stand"] if ScaleLabData.MUZZLE_STAND > h else COLORS["none"])
					if full:
						_text(c, Vector2(cx, y - 46.0), lines[1], FONT_SMALL, COLORS["dim"])
					var sv := ScaleLabData.step_verdict(h, step_max)
					_text(c, Vector2(cx, y - 14.0), "이동 " + sv["text"], FONT_SMALL, COLORS[sv["verdict"]])
				else:
					var rise: float = it.get("step", h)
					var sv2 := ScaleLabData.step_verdict(rise, step_max)
					_text(c, Vector2(cx, y - 40.0), it["label"], FONT_SIZE, COLORS["text"])
					_text(c, Vector2(cx, y - 8.0), sv2["text"], FONT_SMALL, COLORS[sv2["verdict"]])
				_dim_v(c, r.end.x + 18.0, 0.0, h, str(int(h)))
			"room":
				var cl2: float = it["clear"]
				c.draw_rect(r, Color(1, 1, 1, 0.10), false, 2.0)
				_text(c, Vector2(cx, r.position.y + 44.0), it["label"], FONT_SIZE, COLORS["text"])
				if full:
					_text(c, Vector2(cx, r.position.y + 78.0), "키의 %.1f배 · 머리 위 %+d (아이들 상한 기준)" % [cl2 / ScaleLabData.STAND_H, int(cl2 - ScaleLabData.IDLE_MAX)], FONT_SMALL, COLORS["dim"])
					_text(c, Vector2(cx, r.position.y + 108.0), "카메라 세로 중심 y %d (%d행 방과 같게)" % [int(ScaleLabData.room_center_y(int(it["rows"]))), int(it["rows"])], FONT_SMALL, COLORS["dim"])
				_dim_v(c, r.position.x + 30.0, 0.0, cl2, str(int(cl2)))
			"tilecol":
				var cl3 := ScaleLabData.FLOOR - r.position.y
				_text(c, Vector2(cx, r.position.y + 44.0), it["label"], FONT_SMALL, COLORS["text"])
				_dim_v(c, r.position.x + 24.0, 0.0, cl3, str(int(cl3)))
				# 타일 위에 128 격자를 얇게 — 조각 맞물림을 격자와 대조한다
				var gx := r.position.x
				while gx <= r.end.x:
					c.draw_line(Vector2(gx, r.position.y - 48.0), Vector2(gx, ScaleLabData.FLOOR + 50.0), Color(0.4, 1.0, 0.9, 0.22), 1.0)
					gx += ScaleLabData.CELL
				var gy := ScaleLabData.FLOOR + 50.0
				while gy >= r.position.y - 48.0:
					c.draw_line(Vector2(r.position.x, gy), Vector2(r.end.x, gy), Color(0.4, 1.0, 0.9, 0.22), 1.0)
					gy -= ScaleLabData.CELL
			"backdrop", "interact", "occluder":
				var lines2: PackedStringArray = str(it["label"]).split("\n")
				_text(c, Vector2(cx, r.position.y - 44.0), lines2[0], FONT_SMALL, COLORS["text"])
				if full and lines2.size() > 1:
					_text(c, Vector2(cx, r.position.y - 16.0), lines2[1], FONT_SMALL, COLORS["dim"])
			"ghost":
				c.draw_rect(r, COLORS["ghost"], false, 2.0)
				var gl: PackedStringArray = str(it["label"]).split("\n")
				_text(c, Vector2(cx, r.position.y - 44.0), gl[0], FONT_SMALL, COLORS["text"])
				_text(c, Vector2(cx, r.position.y - 16.0), gl[1], FONT_SMALL, COLORS["dim"])
			"pole":
				_draw_pole(c, r)
			"start":
				c.draw_rect(r, COLORS["roll"])
				_text(c, Vector2(r.position.x, r.position.y - 12.0), it["label"], FONT_SMALL, COLORS["roll"])
			"distance":
				var i := _distance_index(it)
				var y2 := ScaleLabData.FLOOR - 70.0 - 34.0 * i
				c.draw_line(Vector2(r.position.x, y2), Vector2(r.end.x, y2), COLORS["roll"], 3.0)
				c.draw_line(Vector2(r.end.x, y2 - 10.0), Vector2(r.end.x, ScaleLabData.FLOOR), COLORS["roll"], 2.0)
				c.draw_string(font, Vector2(r.end.x + 8.0, y2 + 8.0), it["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SMALL, COLORS["roll"])

	for a in _art_boxes:
		var b: Rect2 = a["rect"]
		c.draw_rect(b, COLORS["art_box"], false, 2.0)
		var canvas: Vector2i = a["canvas"]
		_text(c, Vector2(b.get_center().x, b.position.y - 72.0), a["label"], FONT_SMALL, COLORS["text"])
		_text(c, Vector2(b.get_center().x, b.position.y - 44.0), "그림 %d × %d  (아트 %d × %d)" % [int(b.size.x), int(b.size.y), int(b.size.x / 4.0), int(b.size.y / 4.0)], FONT_SMALL, COLORS["art_box"])
		if full:
			_text(c, Vector2(b.get_center().x, b.position.y - 16.0), "캔버스 %d × %d · 키 대비 %.2f배" % [canvas.x, canvas.y, b.size.y / ScaleLabData.STAND_H], FONT_SMALL, COLORS["dim"])


func _distance_index(it: Dictionary) -> int:
	var n := 0
	for o in ScaleLabData.items():
		if o == it:
			return n
		if o["kind"] == "distance":
			n += 1
	return n


func _draw_pole(c: CanvasItem, r: Rect2) -> void:
	var x := r.end.x
	var h := 0.0
	while h <= r.size.y:
		var y := ScaleLabData.FLOOR - h
		var major := int(h) % 128 == 0
		c.draw_line(Vector2(x, y), Vector2(x + (40.0 if major else 16.0), y), COLORS["text"] if major else COLORS["dim"], 2.0 if major else 1.0)
		if major:
			c.draw_string(font, Vector2(x + 46.0, y + 8.0), str(int(h)), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SMALL, COLORS["text"])
		h += ScaleLabData.SUB
	var marks := [[ScaleLabData.ROLL_LOW, "구르기 179", "roll"], [ScaleLabData.CROUCH_H, "웅크림 207", "line_crouch"],
		[ScaleLabData.HIT_H, "피격 250", "dim"], [ScaleLabData.STAND_H, "서기 267", "stand"], [ScaleLabData.IDLE_MAX, "아이들 291", "stand"],
		[ScaleLabData.MUZZLE_STAND, "총구 160", "muzzle"], [ScaleLabData.MUZZLE_CROUCH, "총구 94", "muzzle"]]
	for m in marks:
		var y2 := ScaleLabData.FLOOR - float(m[0])
		var col: Color = COLORS[m[2]]
		c.draw_line(Vector2(r.position.x - 60.0, y2), Vector2(r.position.x, y2), col, 3.0)
		c.draw_string(font, Vector2(r.position.x - 240.0, y2 + 8.0), m[1], HORIZONTAL_ALIGNMENT_RIGHT, 170, FONT_SMALL, col)


## 바닥 위 높이 h 에 가로 기준선
func _hline(c: CanvasItem, x0: float, x1: float, h: float, col: Color, label: String) -> void:
	var y := ScaleLabData.FLOOR - h
	var x := x0
	while x < x1:
		c.draw_line(Vector2(x, y), Vector2(minf(x + 24.0, x1), y), col, 2.0)
		x += 40.0
	c.draw_string(font, Vector2(x0 + 12.0, y - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SMALL, col)


## 세로 치수선 — 바닥 위 h0 ~ h1
func _dim_v(c: CanvasItem, x: float, h0: float, h1: float, label: String) -> void:
	var a := Vector2(x, ScaleLabData.FLOOR - h0)
	var b := Vector2(x, ScaleLabData.FLOOR - h1)
	var col := Color(0.4, 1.0, 0.9, 0.85)
	c.draw_line(a, b, col, 2.0)
	c.draw_line(a + Vector2(-8, 0), a + Vector2(8, 0), col, 2.0)
	c.draw_line(b + Vector2(-8, 0), b + Vector2(8, 0), col, 2.0)
	var mid := (a + b) * 0.5
	c.draw_string(font, mid + Vector2(10, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SMALL, col)


func _text(c: CanvasItem, center: Vector2, s: String, size: int, col: Color) -> void:
	var w := 900.0
	# 어두운 받침을 깔아 어느 배경 위에서도 읽히게
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_rect(Rect2(center.x - tw * 0.5 - 6.0, center.y - size * 0.95, tw + 12.0, size * 1.25), Color(0, 0, 0, 0.45))
	c.draw_string(font, Vector2(center.x - w * 0.5, center.y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _draw_judge(c: CanvasItem) -> void:
	if player == null:
		return
	var h: float = judge.get("h", 0.0)
	var feet := player.position.y - 2.0
	var r := Rect2(player.position.x - ScaleLabData.HALF_W, feet - h, ScaleLabData.HALF_W * 2.0, h)
	var col: Color = COLORS["none"] if judge.get("forced", false) else (COLORS["roll"] if judge.get("blocked", false) else COLORS["stand"])
	c.draw_rect(r, Color(col, 0.9), false, 2.0)
	c.draw_line(Vector2(r.position.x - 10.0, feet), Vector2(r.end.x + 10.0, feet), col, 2.0)
