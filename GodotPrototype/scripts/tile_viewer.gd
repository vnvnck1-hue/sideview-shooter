extends Node2D
## 타일 씬 뷰어: 로비에서 고른 방의 scenes/rooms/<id>.tscn 을 게임 없이 띄워 확인한다.
## 편집은 Godot 에디터(TileMap 패널 Terrains 탭)에서 하고, 저장한 뒤 여기서 R 로 다시 읽으면 바로 반영된다.
##   휠 줌 · 휠클릭 드래그 / WASD / 방향키 이동 · G 격자 · L 옛 스트립 타일 반투명 참고 표시 · R 디스크에서 다시 읽기
##   F1 / Esc 로비

const ZOOM_STEPS := [0.2, 0.25, 0.35, 0.5, 0.7, 1.0, 1.5, 2.0]
const PAN_SPEED := 1400.0
const CELL := 128

var room_id := ""
var _tiles: Node2D            # RoomTiles 인스턴스 (없으면 null)
var _legacy: Node2D           # 옛 스트립 타일 참고용
var _camera: Camera2D
var _zoom_i := 3
var _pan_drag := false
var show_grid := true
var show_legacy := true
var _info: Label
var _status: Label
var _status_t := 0.0
var _font: Font


func _ready() -> void:
	room_id = AppFlow.start_room
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])

	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.zoom = Vector2.ONE * ZOOM_STEPS[_zoom_i]
	add_child(_camera)
	_camera.make_current()

	_legacy = Node2D.new()
	_legacy.name = "LegacyStrip"
	_legacy.modulate = Color(1, 1, 1, 0.35)
	_legacy.z_index = -1
	add_child(_legacy)
	_build_legacy()

	_build_ui()
	_load_tiles()
	_frame_camera()


# ----------------------------------------------------------------------------- 로드

func _load_tiles() -> void:
	if _tiles:
		_tiles.queue_free()
		_tiles = null
	var path := RoomTiles.scene_path(room_id)
	if ResourceLoader.exists(path):
		# 캐시를 무시하고 디스크에서 다시 읽는다 (에디터에서 저장한 직후 반영)
		var packed: PackedScene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		_tiles = packed.instantiate()
		add_child(_tiles)
		_set_status("읽음: %s" % ProjectSettings.globalize_path(path))
	else:
		_set_status("타일 씬 없음: %s — Godot 에디터에서 scenes/rooms/workshop.tscn 을 복제해 만드세요" % ProjectSettings.globalize_path(path))
	_update_info()


## 옛 560px 가로 스트립을 반투명으로 깔아 방 폭·바닥선 기준을 보여준다
func _build_legacy() -> void:
	var x := 0
	for tile_name in RoomData.get_room(room_id)["tiles"]:
		var s := Sprite2D.new()
		s.centered = false
		s.texture = load(RoomData.TILE_DIR + tile_name + ".png")
		s.position = Vector2(x, 0)
		_legacy.add_child(s)
		x += RoomData.tile_width(tile_name)


func _frame_camera() -> void:
	_camera.position = RoomData.room_rect(room_id).get_center()


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
				return          # 씬이 바뀌므로 이 노드의 뷰포트를 더 만지지 않는다
			KEY_R:
				_load_tiles()
			KEY_G:
				show_grid = not show_grid
			KEY_L:
				show_legacy = not show_legacy
				_legacy.visible = show_legacy
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
	queue_redraw()


# ----------------------------------------------------------------------------- 오버레이

func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size / _camera.zoom
	var view := Rect2(_camera.get_screen_center_position() - vp * 0.5, vp).grow(CELL)
	var px := 1.0 / _camera.zoom.x
	# 방 영역(RoomData 기준)과 바닥선
	draw_rect(RoomData.room_rect(room_id), Color(0.3, 0.8, 1.0, 0.45), false, 2.0 * px)
	draw_line(Vector2(view.position.x, RoomData.FLOOR_Y), Vector2(view.end.x, RoomData.FLOOR_Y), Color(1.0, 0.85, 0.3, 0.7), 2.0 * px)
	if not show_grid:
		return
	var o := _tiles.position if _tiles else Vector2(0, 24)
	var gc := Color(1, 1, 1, 0.12)
	var x := floorf((view.position.x - o.x) / CELL) * CELL + o.x
	while x <= view.end.x:
		draw_line(Vector2(x, view.position.y), Vector2(x, view.end.y), gc, px)
		x += CELL
	var y := floorf((view.position.y - o.y) / CELL) * CELL + o.y
	while y <= view.end.y:
		draw_line(Vector2(view.position.x, y), Vector2(view.end.x, y), gc, px)
		y += CELL
	draw_circle(o, 5.0 * px, Color(1.0, 0.5, 0.2, 0.9))
	# 찍힌 셀 범위
	if _tiles:
		var used: Rect2i
		var first := true
		for child in _tiles.get_children():
			if child is TileMapLayer:
				var r: Rect2i = child.get_used_rect()
				if r.size == Vector2i.ZERO:
					continue
				used = r if first else used.merge(r)
				first = false
		if not first:
			draw_rect(Rect2(o + Vector2(used.position) * CELL, Vector2(used.size) * CELL), Color(0.5, 1.0, 0.6, 0.6), false, 2.0 * px)


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
	help.text = ("편집은 Godot 에디터에서: scenes/rooms/<방 id>.tscn 열기 → Background/Frame 레이어 선택 → TileMap 패널 [Terrains] 탭으로 찍기 → 저장 → 여기서 R\n"
		+ "휠 줌 · 휠클릭 드래그 / WASD / 방향키 이동 · G 격자 · L 옛 스트립 참고 표시 · R 다시 읽기 · F1/Esc 로비")
	layer.add_child(help)


func _label(color: Color, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _update_info() -> void:
	var title: String = RoomData.get_room(room_id)["title"]
	var cells := 0
	var origin := Vector2(0, 24)
	if _tiles:
		origin = _tiles.position
		for child in _tiles.get_children():
			if child is TileMapLayer:
				cells += child.get_used_cells().size()
	_info.text = "타일 씬 보기   방: %s (%s)   파일: %s   격자 원점 (%d, %d)   찍힌 셀 %d개 (두 레이어 합)" % [
		title, room_id, RoomTiles.scene_path(room_id), int(origin.x), int(origin.y), cells]


func _set_status(msg: String) -> void:
	_status.text = msg
	_status_t = 6.0
