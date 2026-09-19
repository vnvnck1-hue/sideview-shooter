extends Node2D
## 맵 뷰어 (scenes/MapViewer.tscn): 방을 게임 없이 Room.build 로 통째로 조립해 자유 카메라로 확인한다.
## 타일 실루엣·프랍 접지·문 위치·조명을 플레이 없이 빠르게 훑는 용도. 몬스터는 배치되지만 플레이어가 없어 움직이지 않는다.
##   [ / ]  이전 / 다음 방        휠 줌 · 휠클릭 드래그 / WASD / 방향키 이동
##   G      셀 격자·문 표시       L   전체 밝게(앰비언트 해제) ↔ 게임 조명
##   R      방 다시 조립          F   방 전체가 보이게 카메라 맞춤
##   F1 / Esc 로비               F11 전체화면
## tools/map_shots.gd 가 이 씬으로 방마다 스크린샷을 찍는다.

const ZOOM_STEPS := [0.15, 0.2, 0.25, 0.35, 0.5, 0.7, 1.0, 1.5, 2.0]
const PAN_SPEED := 1400.0
const CELL := RoomTheme.CELL

var room_id := ""
var room: Room
var bright := false
var show_grid := true
var _camera: Camera2D
var _zoom_i := 4
var _pan_drag := false
var _info: Label
var _status: Label
var _status_t := 0.0
var _font: Font


func _ready() -> void:
	room_id = AppFlow.start_room if RoomData.ROOMS.has(AppFlow.start_room) else RoomData.START_ROOM
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	DepthPreset.activate()
	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.make_current()
	_build_ui()
	load_room(room_id)


# ----------------------------------------------------------------------------- 로드

func load_room(id: String) -> void:
	if room:
		room.queue_free()
		room = null
	room_id = id
	HeatSurface.clear_all()
	room = Room.new()
	room.name = "Room_" + id
	room.build(id)
	add_child(room)
	move_child(room, 0)
	set_bright(bright)
	frame_room()
	_update_info()
	_set_status("조립: %s" % id)


## 앰비언트를 풀고 방 전체를 밝게 (모양·접지 확인용)
func set_bright(v: bool) -> void:
	bright = v
	if room and room._ambient:
		room._ambient.color = Color.WHITE if bright else Lighting.AMBIENT
	if room and room.wall_shadow:
		room.wall_shadow.visible = not bright        # 모양 확인 중에는 벽 바깥 어둠도 걷는다


## 방 전체가 화면에 들어오게 줌·위치를 맞춘다
func frame_room() -> void:
	var r := RoomData.room_rect(room_id).grow(160.0)
	var vp := get_viewport().get_visible_rect().size
	var z := minf(vp.x / r.size.x, vp.y / r.size.y)
	_zoom_i = 0
	for i in range(ZOOM_STEPS.size()):
		if ZOOM_STEPS[i] <= z:
			_zoom_i = i
	_camera.zoom = Vector2.ONE * ZOOM_STEPS[_zoom_i]
	_camera.position = r.get_center()


func _step_room(dir: int) -> void:
	var ids: Array = RoomData.ids()
	var i := ids.find(room_id)
	load_room(ids[wrapi(i + dir, 0, ids.size())])


# ----------------------------------------------------------------------------- 입력

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: _set_zoom(_zoom_i + 1, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: _set_zoom(_zoom_i - 1, event.position)
			MOUSE_BUTTON_MIDDLE:
				_pan_drag = event.pressed
	elif event is InputEventMouseMotion and _pan_drag:
		_camera.position -= event.relative / _camera.zoom
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_F1:
				AppFlow.go_lobby(get_tree())
				return
			KEY_BRACKETLEFT:
				_step_room(-1)
			KEY_BRACKETRIGHT:
				_step_room(1)
			KEY_R:
				load_room(room_id)
			KEY_F:
				frame_room()
			KEY_G:
				show_grid = not show_grid
			KEY_L:
				set_bright(not bright)
			KEY_F11:
				var w := get_window()
				w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
			_:
				return
	get_viewport().set_input_as_handled()


func _set_zoom(i: int, screen_pos: Vector2) -> void:
	i = clampi(i, 0, ZOOM_STEPS.size() - 1)
	if i == _zoom_i:
		return
	var before := get_global_mouse_position()
	_zoom_i = i
	_camera.zoom = Vector2.ONE * ZOOM_STEPS[i]
	var vp := get_viewport().get_visible_rect().size
	var after := _camera.position + (screen_pos - vp * 0.5) / _camera.zoom
	_camera.position += before - after


func _process(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if v != Vector2.ZERO:
		_camera.position += v.normalized() * PAN_SPEED * delta / _camera.zoom.x
	_status_t = maxf(_status_t - delta, 0.0)
	if _status_t <= 0.0 and _status.text != "":
		_status.text = ""
	HeatSurface.tick_all(delta)
	queue_redraw()


# ----------------------------------------------------------------------------- 오버레이

func _draw() -> void:
	if not show_grid or room == null:
		return
	var px := 1.0 / _camera.zoom.x
	var rect := RoomData.room_rect(room_id)
	draw_rect(rect, Color(0.3, 0.8, 1.0, 0.45), false, 2.0 * px)
	draw_line(Vector2(rect.position.x - 200, RoomData.FLOOR_Y), Vector2(rect.end.x + 200, RoomData.FLOOR_Y), Color(1.0, 0.85, 0.3, 0.7), 2.0 * px)
	# 셀 격자 (타일맵 원점 기준)
	var o := room.room_tiles.position
	var gc := Color(1, 1, 1, 0.10)
	for i in range(room.heights.size() + 1):
		var x := o.x + i * CELL
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), gc, px)
	for j in range(room.room_tiles.rows + 1):
		var y := o.y + j * CELL
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), gc, px)
	# 문: 측벽문(초록 열림 / 주황 닫힘), 정면문(노랑) 과 목적지
	var data := RoomData.get_room(room_id)
	for side in ["left_door", "right_door"]:
		var d: Dictionary = data[side]
		var x := 0.0 if side == "left_door" else float(room.width)
		var c := Color(0.4, 1.0, 0.5, 0.9) if d.get("open", false) else Color(1.0, 0.55, 0.2, 0.9)
		draw_line(Vector2(x, RoomData.FLOOR_Y), Vector2(x, RoomData.FLOOR_Y - 420), c, 4.0 * px)
		if d.get("open", false):
			_text(Vector2(x + (12 if side == "left_door" else -12), RoomData.FLOOR_Y - 430), "⇄ " + String(d["target"]), c, side == "right_door")
	for i in range(room.front_doors.size()):
		var fd: Dictionary = room.front_doors[i]
		var c := Vector2(fd["center"])
		draw_rect(Rect2(c.x - RoomData.FRONT_DOOR_W * 0.5, RoomData.FLOOR_Y - Room.FRONT_DOOR_LIFT, RoomData.FRONT_DOOR_W, Room.FRONT_DOOR_LIFT), Color(1.0, 0.9, 0.3, 0.8), false, 2.0 * px)
		_text(Vector2(c.x - RoomData.FRONT_DOOR_W * 0.5, RoomData.FLOOR_Y - Room.FRONT_DOOR_LIFT - 10), "↕ %d → %s #%d" % [i, fd["target"], fd["target_door"]], Color(1.0, 0.9, 0.3, 0.9), false)


func _text(pos: Vector2, s: String, color: Color, right_align: bool) -> void:
	var px := 1.0 / _camera.zoom.x
	var size := 18.0 * px
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x
	draw_string(_font, pos - (Vector2(w, 0) if right_align else Vector2.ZERO), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size), color)


# ----------------------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.55)
	top.size = Vector2(1600, 104)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	_info = _label(Color(0.95, 0.92, 0.85), 22)
	_info.position = Vector2(24, 12)
	_info.size = Vector2(1552, 60)
	layer.add_child(_info)
	_status = _label(Color(1.0, 0.85, 0.4), 18)
	_status.position = Vector2(24, 72)
	_status.size = Vector2(1552, 28)
	layer.add_child(_status)
	var help := _label(Color(0.72, 0.74, 0.82), 17)
	help.position = Vector2(24, 900 - 24 - 50)
	help.size = Vector2(1552, 50)
	help.text = ("[ ] 이전/다음 방 · 휠 줌 · 휠클릭 드래그 / WASD 이동 · F 방 전체 보기 · G 격자·문 표시 · L 전체 밝게 · R 다시 조립 · F1/Esc 로비\n"
		+ "맵 데이터는 scripts/room_data.gd — 방 모양(열 프로필 [[폭 셀, 높이 셀], ...])·문·프랍·조명·몬스터")
	layer.add_child(help)


func _label(color: Color, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _update_info() -> void:
	var data := RoomData.get_room(room_id)
	var lay := RoomData.layout(room_id)
	var ids: Array = RoomData.ids()
	_info.text = "맵 뷰어  %d/%d   %s › %s  (%s · %s)   %d×%d셀 = %d×%d px   천장 y %d   몬스터 %s (시작 %d · 최대 %d)" % [
		ids.find(room_id) + 1, ids.size(), data["zone"], data["title"], room_id, RoomTheme.title(data["theme"]),
		room.heights.size(), lay["rows"], lay["width"], int(lay["bottom_y"] - lay["ceiling_y"]), int(lay["ceiling_y"]),
		RoomData.danger(room_id), data.get("monsters", []).size(), int(data.get("spawn", {}).get("max", 0))]


func _set_status(msg: String) -> void:
	_status.text = msg
	_status_t = 6.0
