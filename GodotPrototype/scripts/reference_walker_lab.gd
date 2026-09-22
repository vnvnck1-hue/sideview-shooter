extends Node2D
## 원화 피벗 편집과 거미형 공간 관절 보행을 검토하는 테스트.

const Walker = preload("res://scripts/reference_walker.gd")
const BoneView = preload("res://scripts/reference_walker_view.gd")
const Anatomy = preload("res://scripts/walker_anatomy.gd")
const AuthoringEditor = preload("res://scripts/walker_authoring_editor.gd")
const BASE_Y := 520.0
const TERRAIN := [Vector2(-5000, 0), Vector2(550, 0), Vector2(1000, -35),
	Vector2(1450, -35), Vector2(1452, -53), Vector2(1900, -53),
	Vector2(2300, 0), Vector2(2750, 0), Vector2(2752, 85), Vector2(7000, 85)]

var auto_drive := false
var authoring_enabled := true
var authoring_path := "res://authoring/walker_motion.json"
var _authoring: Node2D
var auto_dir := 0.0
var auto_run := false
var auto_aim = null
var reference_mode := false
var paused := false
var _walker: Node2D
var _view: Node2D
var _cam: Camera2D
var _art: Sprite2D
var _font: Font
var _mode: Label
var _status: Label
var _legend: PanelContainer
var _hud: Control
var _mouse_aim := false
var _art_alpha := 0.6
var _shots: Array = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -100
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.color = Color("101a28")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)
	_walker = Walker.new()
	_walker.ground_at = ground_y
	_walker.body_pos = Vector2(0, BASE_Y - Anatomy.ground_level())
	add_child(_walker)
	_art = Sprite2D.new()
	_art.texture = load(Anatomy.SOURCE_PATH)
	_art.centered = false
	_art.position = Anatomy.local_point(Vector2.ZERO)
	_art.scale = Vector2.ONE * Anatomy.SCALE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.modulate.a = _art_alpha
	_art.hide()
	_walker.add_child(_art)
	_view = BoneView.new()
	_view.walker = _walker
	_walker.add_child(_view)
	_walker.fired.connect(func(at: Vector2, direction: Vector2):
		_shots.append({"a": at, "b": at + direction * 1000.0, "life": 0.09}))
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_build_hud()
	if authoring_enabled and not auto_drive:
		_authoring = AuthoringEditor.new()
		_authoring.lab = self
		_authoring.storage_path = authoring_path
		add_child(_authoring)
	_update_camera()
	_update_hud()
	queue_redraw()


func ground_y(x: float) -> float:
	for i in range(1, TERRAIN.size()):
		if x <= TERRAIN[i].x:
			var a: Vector2 = TERRAIN[i - 1]
			var b: Vector2 = TERRAIN[i]
			return BASE_Y + lerpf(a.y, b.y, clampf((x - a.x) / (b.x - a.x), 0.0, 1.0))
	return BASE_Y + TERRAIN[-1].y


func set_reference_mode(enabled: bool) -> void:
	reference_mode = enabled
	_walker.source_rest = enabled
	_walker.aim_target = null
	_walker.drag_to = null
	_walker.firing = false
	_walker.body_pos = Vector2(0, BASE_Y - Anatomy.ground_level())
	_walker.reset_pose()
	_art.visible = enabled
	_mouse_aim = false
	_shots.clear()
	_update_camera()
	_update_hud()
	_view.queue_redraw()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _authoring != null and _authoring.mode != "walk":
		_authoring.step(delta)
		queue_redraw()
		return
	if not paused:
		_walker.input_dir = auto_dir if auto_drive else float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		_walker.running = auto_run if auto_drive else Input.is_physical_key_pressed(KEY_SHIFT)
		if not auto_drive:
			_walker.aim_target = get_global_mouse_position() if _mouse_aim and not reference_mode else null
			_walker.firing = not reference_mode and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_J))
		else:
			_walker.aim_target = auto_aim
		_walker.tick(delta)
		for shot in _shots:
			shot["life"] -= delta
		_shots = _shots.filter(func(shot): return shot["life"] > 0.0)
	_update_camera()
	_update_hud()
	if _authoring != null:
		_authoring.step(delta)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _authoring != null and _authoring.capture_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _authoring != null and _authoring.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_mouse_aim = true
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_TAB: set_reference_mode(not reference_mode)
		KEY_SPACE:
			if not paused and not reference_mode:
				_walker.jump()
		KEY_O:
			_art_alpha = 0.0 if _art_alpha > 0.9 else (1.0 if _art_alpha > 0.0 else 0.6)
			_art.modulate.a = _art_alpha
		KEY_L: _view.show_labels = not _view.show_labels
		KEY_H: _view.show_targets = not _view.show_targets
		KEY_P: paused = not paused
		KEY_R:
			set_reference_mode(reference_mode)
			paused = false
		KEY_F1: AppFlow.go_lobby(get_tree())


func _update_camera() -> void:
	if _authoring != null:
		_authoring.update_camera()
		return
	var size := get_viewport_rect().size
	var zoom := minf((size.x - 320.0) / 620.0, (size.y - 230.0) / (430.0 if reference_mode else 320.0))
	zoom = clampf(zoom, 0.65, 2.0)
	_cam.zoom = Vector2.ONE * zoom
	_cam.position = _walker.body_pos + Vector2(125.0 / zoom, -35.0)
	_cam.force_update_scroll()
	_legend.position = Vector2(size.x - 282, 142)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	var title := _label("QUADRUPED / 원화 기반 본 테스트", 27, Color("edf2fa"))
	title.position = Vector2(30, 24)
	_hud.add_child(title)
	_mode = _label("", 17, Color("92b9d3"))
	_mode.position = Vector2(31, 65)
	_hud.add_child(_mode)
	var line := ColorRect.new()
	line.color = Color("334452")
	line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	line.offset_left = 30
	line.offset_right = -30
	line.offset_top = 107
	line.offset_bottom = 109
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(line)
	_legend = PanelContainer.new()
	_legend.custom_minimum_size = Vector2(252, 0)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192534")
	style.border_color = Color("334452")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_legend.add_theme_stylebox_override("panel", style)
	_hud.add_child(_legend)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_legend.add_child(box)
	box.add_child(_label("뼈대 색상", 19, Color("edf2fa")))
	for row in [["chassis", "몸체 · 고관절 연결"], ["torso", "상부 몸통"], ["gun", "포가 · 포신"], ["upper", "짧은 연결 암"], ["lower", "긴 장갑 다리"], ["foot", "발목 · 발"]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		box.add_child(h)
		var swatch := ColorRect.new()
		swatch.color = Anatomy.COLORS[row[0]]
		swatch.custom_minimum_size = Vector2(18, 18)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(swatch)
		h.add_child(_label(row[1], 16, Color("d2dce8")))
	box.add_child(HSeparator.new())
	box.add_child(_label("NF / NR  가까운 앞 / 뒤\nFF / FR  먼 앞 / 뒤\n\n점선: 가려진 연결 추정\n열린 관절 링: 가려진 축\nFR: 접혀 있는 다리 추정", 14, Color("a5b6c8")))
	_status = _label("", 14, Color("91d3bb"))
	box.add_child(_status)
	var controls := _label("A/D · ←/→  이동     Shift  달리기     Space  점프     마우스  조준     좌클릭  사격\nTab  원화 겹쳐 보기     O  원화 농도     L  이름표     H  접지 목표     P  정지     R  초기화     F1  로비", 16, Color("b4c4d5"))
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 30
	controls.offset_right = -30
	controls.offset_top = -75
	controls.offset_bottom = -20
	_hud.add_child(controls)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _update_hud() -> void:
	if _authoring != null:
		return
	if _mode == null:
		return
	_mode.text = "02 / 원화 대조 — 관절 기준 자세 · Tab으로 보행 복귀" if reference_mode else "01 / 보행 — 뼈 길이를 유지하는 네 다리 · Tab으로 원화와 대조"
	if paused:
		_mode.text += "  [일시 정지]"
	var planted := 0
	for leg in _walker.pose_legs():
		planted += int(leg["planted"])
	_status.text = "원화 기준 좌표 · 20 bones" if reference_mode else "접지 %d / 4   속도 %d\n%s" % [planted, roundi(_walker.speed), "공중" if _walker.airborne else "고정 길이 관절"]


func _draw() -> void:
	if _walker == null:
		return
	if not reference_mode:
		var surface := PackedVector2Array()
		for point in TERRAIN:
			surface.append(point + Vector2(0, BASE_Y))
		var fill := surface.duplicate()
		fill.append(Vector2(7000, 2500))
		fill.append(Vector2(-5000, 2500))
		draw_colored_polygon(fill, Color("1c2a37"))
		if _walker.spider_gait:
			# 하나의 바닥을 사선으로 보여 준다. 먼 발의 투영 높이를 공중으로 오해하지 않도록 한다.
			var back_depth := 0.0
			for leg in _walker.pose_legs():
				back_depth = minf(back_depth, float(leg["depth"]))
			var back := PackedVector2Array()
			var plane := surface.duplicate()
			for point in surface:
				back.append(point + Vector2(0, back_depth))
			for i in range(back.size() - 1, -1, -1):
				plane.append(back[i])
			draw_colored_polygon(plane, Color("172733"))
			draw_polyline(back, Color("354b59"), 1.0, true)
			var from_x := floori((_walker.body_pos.x - 900) / 100.0) * 100
			var depth_shift := -back_depth * 0.55 / 0.18
			for x in range(from_x, from_x + 1800, 100):
				draw_line(Vector2(x, ground_y(x)), Vector2(x + depth_shift, ground_y(x + depth_shift) + back_depth), Color("293d4b"), 1.0, true)
		draw_polyline(surface, Color("667b8b"), 2.0, true)
		var left := floori((_walker.body_pos.x - 900) / 100.0) * 100
		for x in range(left, left + 1800, 100):
			var y := ground_y(x)
			draw_line(Vector2(x, y + 8), Vector2(x, y + 65), Color("2a3b4b"), 1.0)
			draw_string(_font, Vector2(x + 5, y + 35), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("697e91"))
		for leg in _walker.pose_legs():
			var toe: Vector2 = leg["toe"]
			var floor_point := Vector2(toe.x, ground_y(toe.x) + float(leg["depth"]))
			var contact_color := Color("81baa6") if bool(leg["planted"]) else Color("536b7a")
			draw_line(floor_point - Vector2(10, 0), floor_point + Vector2(10, 0), contact_color, 2.0)
	for shot in _shots:
		draw_line(shot["a"], shot["b"], Color(0.5, 0.9, 1.0, float(shot["life"]) / 0.09), 2.0, true)
