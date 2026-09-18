class_name ForegroundLab
extends Node2D
## 근경 랩 — 실제 방·조명 위에서 근경 실루엣(ForegroundLayer.items)을 마우스로 옮기고 늘리고 추가·삭제해 저장하는 편집 오버레이.
## ForegroundLayer 의 자식으로 붙어 같은 로컬 좌표(패럴랙스 포함)를 쓴다. Main 이 AppFlow.lab_mode 일 때 만든다.
##
##  마우스 왼쪽 드래그      : 항목 이동 (4px 격자). 오른쪽 아래 모서리 근처(HANDLE)를 잡으면 크기 조절
##  Shift + 드래그          : 복제해서 이동
##  1~8                     : 마우스 위치에 새 항목 — 1 pipe · 2 pillar · 3 crate · 4 tray · 5 dark · 6 cable · 7 pipe_bracket · 8 utility_housing (그림)
##  Delete / Backspace      : 선택 삭제          Ctrl+D : 복제         Tab : 선택 항목 종류 순환
##  방향키                  : 선택 항목 4px 이동 (Shift 32px)        Q / E : 선택 항목을 뒤로 / 앞으로 (그리기 순서)
##  A / D                   : 플레이어(카메라) 좌우 이동             H : 윤곽선 표시 토글
##  S                       : foreground/<방 id>.json 저장            R : 절차 생성으로 초기화 (저장 전까지만)
##  F2                      : 이전/이후 프리셋 A/B 는 그대로 동작    F1 : 로비
##  Esc                     : 선택 해제

signal status_changed(text: String)

const HANDLE := 18.0                               # 크기 조절 손잡이 반경 (로컬 px)
const OUTLINE := Color(0.45, 0.75, 1.0, 0.55)
const SELECTED := Color(1.0, 0.85, 0.3, 1.0)
const HOVER := Color(1.0, 1.0, 1.0, 0.8)
const KIND_COLORS := {
	"pipe": Color(0.6, 0.8, 1.0), "pillar": Color(0.8, 0.7, 1.0), "crate": Color(1.0, 0.8, 0.5),
	"tray": Color(0.6, 1.0, 0.7), "dark": Color(0.7, 0.7, 0.7), "cable": Color(1.0, 0.6, 0.6),
	"pipe_bracket": Color(1.0, 0.9, 0.7), "utility_housing": Color(1.0, 0.9, 0.7),
}
const WALK_SPEED := 700.0

var layer: ForegroundLayer
var player: Node2D
var show_outlines := true
var selected := -1
var hover := -1
var dirty := false
var _drag := false
var _resize := false
var _drag_offset := Vector2.ZERO                  # 마우스 - 항목 pos
var _drag_start_size := Vector2.ZERO
var _last_saved := ""


func setup(fg: ForegroundLayer, p: Node2D) -> void:
	layer = fg
	player = p
	z_index = 30
	_emit()


func _process(delta: float) -> void:
	# 카메라 좌우 이동: 플레이어를 직접 옮긴다 (입력은 꺼져 있다)
	var dx := 0.0
	if Input.is_key_pressed(KEY_A):
		dx -= 1.0
	if Input.is_key_pressed(KEY_D):
		dx += 1.0
	if dx != 0.0 and player:
		player.position.x = clampf(player.position.x + dx * WALK_SPEED * delta, 40.0, layer.room_width - 40.0)
	var m := get_local_mouse_position()
	var h := layer.hit_item(m)
	if h != hover:
		hover = h
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion and _drag:
		_mouse_drag()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _mouse_button(e: InputEventMouseButton) -> void:
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	var m := get_local_mouse_position()
	if e.pressed:
		var i := layer.hit_item(m)
		if i < 0:
			selected = -1
			_emit()
			return
		if e.shift_pressed:
			i = _duplicate(i)
		selected = i
		var r := layer.item_rect(i)
		_resize = m.distance_to(r.end) <= HANDLE
		_drag = true
		_drag_offset = m - r.position
		_drag_start_size = r.size
		_emit()
	else:
		_drag = false
		_resize = false


func _mouse_drag() -> void:
	if selected < 0:
		return
	var m := get_local_mouse_position()
	var it: Dictionary = layer.items[selected]
	if _resize:
		var origin: Vector2 = it["pos"]
		var s: Vector2 = (m - origin).snapped(Vector2(ForegroundLayer.GRID, ForegroundLayer.GRID))
		it["size"] = Vector2(maxf(s.x, ForegroundLayer.GRID * 2.0), maxf(s.y, ForegroundLayer.GRID * 2.0))
	else:
		it["pos"] = (m - _drag_offset).snapped(Vector2(ForegroundLayer.GRID, ForegroundLayer.GRID))
	dirty = true
	layer.rebuild_visuals()
	_emit()


func _key(e: InputEventKey) -> void:
	var step := 32.0 if e.shift_pressed else ForegroundLayer.GRID
	match e.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			if e.keycode - KEY_1 >= ForegroundLayer.KINDS.size():
				return
			var kind: String = ForegroundLayer.KINDS[e.keycode - KEY_1]
			selected = layer.add_item(kind, get_local_mouse_position())
			dirty = true
		KEY_DELETE, KEY_BACKSPACE:
			if selected >= 0:
				layer.remove_item(selected)
				selected = -1
				dirty = true
		KEY_D:
			if e.ctrl_pressed and selected >= 0:
				selected = _duplicate(selected)
		KEY_TAB:
			if selected >= 0:
				var it: Dictionary = layer.items[selected]
				var k := ForegroundLayer.KINDS.find(it["kind"])
				it["kind"] = ForegroundLayer.KINDS[(k + 1) % ForegroundLayer.KINDS.size()]
				layer.rebuild_visuals()
				dirty = true
		KEY_LEFT:
			_nudge(Vector2(-step, 0))
		KEY_RIGHT:
			_nudge(Vector2(step, 0))
		KEY_UP:
			_nudge(Vector2(0, -step))
		KEY_DOWN:
			_nudge(Vector2(0, step))
		KEY_Q:
			_reorder(-1)
		KEY_E:
			_reorder(1)
		KEY_H:
			show_outlines = not show_outlines
		KEY_S:
			_last_saved = layer.save_items()
			dirty = false
			print("근경 배치 저장: ", _last_saved)
		KEY_R:
			layer.generate(_avoid_x())
			layer.rebuild_visuals()
			selected = -1
			dirty = true
		KEY_ESCAPE:
			selected = -1
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			# 방 전환 — 저장 안 한 변경은 사라진다
			var ids: Array = RoomData.ROOMS.keys()
			var k := ids.find(layer.room_id)
			var next: String = ids[(k + (1 if e.keycode == KEY_BRACKETRIGHT else -1) + ids.size()) % ids.size()]
			AppFlow.start_foreground_lab(get_tree(), next)
			return
		_:
			return
	_emit()


func _nudge(d: Vector2) -> void:
	if selected < 0:
		return
	var it: Dictionary = layer.items[selected]
	var p: Vector2 = it["pos"]
	it["pos"] = p + d
	dirty = true
	layer.rebuild_visuals()


func _reorder(dir: int) -> void:
	if selected < 0:
		return
	var j := selected + dir
	if j < 0 or j >= layer.items.size():
		return
	var tmp = layer.items[selected]
	layer.items[selected] = layer.items[j]
	layer.items[j] = tmp
	selected = j
	dirty = true
	layer.rebuild_visuals()


func _duplicate(i: int) -> int:
	var src: Dictionary = layer.items[i]
	var p: Vector2 = src["pos"]
	layer.items.append({"kind": src["kind"], "pos": p + Vector2(ForegroundLayer.GRID * 4.0, ForegroundLayer.GRID * 4.0), "size": src["size"]})
	layer.rebuild_visuals()
	dirty = true
	return layer.items.size() - 1


## 절차 생성용 회피 목록 (램프·정면문) — Room 에서 다시 가져온다
func _avoid_x() -> Array:
	var room := layer.get_parent()
	var avoid: Array = []
	if room and "lamps" in room:
		for lamp in room.lamps:
			avoid.append(lamp.position.x)
	if room and "front_doors" in room:
		for fd in room.front_doors:
			avoid.append(fd["center"].x)
	return avoid


func _emit() -> void:
	var lines := PackedStringArray()
	lines.append("근경 랩 — %s  ·  항목 %d개  ·  %s%s" % [
		layer.room_id, layer.items.size(),
		"저장 파일" if layer.from_file else "절차 생성",
		"  ·  변경됨(S 저장)" if dirty else ""])
	if selected >= 0 and selected < layer.items.size():
		var it: Dictionary = layer.items[selected]
		lines.append("선택 #%d %s  pos (%d, %d)  size (%d × %d)" % [selected, it["kind"], it["pos"].x, it["pos"].y, it["size"].x, it["size"].y])
	else:
		lines.append("클릭: 선택·이동   우하단 모서리 드래그: 크기   1~8 추가(pipe·pillar·crate·tray·dark·cable·pipe_bracket·utility_housing)   Del 삭제   Tab 종류   Q/E 순서")
	lines.append("A/D 카메라   방향키 4px(Shift 32)   Ctrl+D·Shift드래그 복제   H 윤곽선   R 절차 생성 초기화   S 저장 → foreground/<방>.json   [ ] 방 전환   F2 A/B   F1 로비")
	if _last_saved != "":
		lines.append("저장됨: " + _last_saved)
	status_changed.emit("\n".join(lines))


func _draw() -> void:
	var g := ForegroundLayer.GRID
	for i in range(layer.items.size()):
		var it: Dictionary = layer.items[i]
		var r := layer.item_rect(i)
		var is_sel := i == selected
		if not show_outlines and not is_sel and i != hover:
			continue
		var col: Color = KIND_COLORS.get(it["kind"], OUTLINE)
		col.a = 0.9 if is_sel else (0.7 if i == hover else 0.35)
		if is_sel:
			col = SELECTED
		draw_rect(r, col, false, 2.0 if is_sel else 1.0)
		if it["kind"] == "cable":
			# 케이블은 걸린 구간·처짐을 점선 곡선으로 안내
			var a: Vector2 = it["pos"]
			var b: Vector2 = a + Vector2(it["size"].x, 0)
			var prev := a
			for k in range(1, 11):
				var t := float(k) / 10.0
				var p := a.lerp(b, t) + Vector2(0, it["size"].y * 4.0 * t * (1.0 - t))
				draw_line(prev, p, col, 1.0)
				prev = p
		if is_sel or i == hover:
			draw_rect(Rect2(r.end - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE)), col, is_sel)
			draw_string(ThemeDB.fallback_font, r.position + Vector2(0, -6), "%s %d×%d" % [it["kind"], int(r.size.x), int(r.size.y)],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
	# 방 경계 (천장~바닥선, 폭)
	draw_rect(Rect2(0, layer.ceiling_y, layer.room_width, layer.floor_y - layer.ceiling_y), Color(1, 1, 1, 0.12), false, 1.0)
	draw_line(Vector2(-4000, layer.floor_y), Vector2(layer.room_width + 4000, layer.floor_y), Color(1, 1, 1, 0.12), 1.0)
	# 마우스 격자 점
	var m := get_local_mouse_position().snapped(Vector2(g, g))
	draw_rect(Rect2(m - Vector2(2, 2), Vector2(4, 4)), HOVER)
