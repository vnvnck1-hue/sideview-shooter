extends Node2D
## The same ProcWalker + art rig used by WalkerUnit, with live, shared gait settings.
const Walker = preload("res://scripts/proc_walker.gd")
const Rig = preload("res://scripts/walker_rig.gd")
const Settings = preload("res://scripts/walker_gait_settings.gd")
const TuningPanel = preload("res://scripts/walker_tuning_panel.gd")
const BASE_Y := 620.0
const HOTKEYS := {
	KEY_Q: ["speed", 10.0], KEY_Z: ["speed", -10.0],
	KEY_E: ["stride", .03], KEY_C: ["stride", -.03],
	KEY_R: ["ride", 6.0], KEY_V: ["ride", -6.0],
	KEY_T: ["trigger", 5.0], KEY_B: ["trigger", -5.0],
	KEY_Y: ["lift", 5.0], KEY_N: ["lift", -5.0],
	KEY_U: ["step_time", .02], KEY_M: ["step_time", -.02],
	KEY_I: ["lead", .02], KEY_COMMA: ["lead", -.02],
	KEY_O: ["hold", .02], KEY_PERIOD: ["hold", -.02],
	KEY_P: ["legs_up", 1.0], KEY_SLASH: ["legs_up", -1.0],
	KEY_BRACKETLEFT: ["tilt", -.05], KEY_BRACKETRIGHT: ["tilt", .05],
	KEY_SEMICOLON: ["aim_lean", -.05], KEY_APOSTROPHE: ["aim_lean", .05],
}

var settings_path := Settings.DEFAULT_PATH
var _settings: RefCounted
var _walker: Node2D
var _rig: Node2D
var _panel: Control
var _cam: Camera2D
var _overlay: Node2D
var preview := 0
var running := false
var paused := false
var bones := false
var terrain := 0
var auto_drive := false
var auto_aim = null
var _status := "인게임과 같은 거미형 보행 · 값을 바꾸면 바로 적용됩니다."
var _loaded := false
var _aim_offset := Vector2(650, -55)
var _keyboard_dir := 0.0
var _keyboard_run := false
var _shots: Array = []
var _history: Array = []
var _exit_dialog: ConfirmationDialog
var _destination := "lobby"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var backdrop := CanvasLayer.new()
	backdrop.layer = -100
	add_child(backdrop)
	var background := ColorRect.new()
	background.color = Color("101b28")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(background)
	_settings = Settings.new()
	if FileAccess.file_exists(settings_path):
		_loaded = _settings.load_file(settings_path) == OK
		_status = "저장한 보행 설정을 불러왔습니다." if _loaded else "불러오기 실패 · " + str(_settings.last_error)
	_walker = Walker.new()
	_walker.initialize_spider_tuning(settings_path)
	_walker.apply_spider_tuning(_settings.values)
	_walker.ground_at = ground_y
	_walker.draw_greybox = false
	_walker.body_pos = Vector2(0, BASE_Y - float(_settings.values["ride"]))
	add_child(_walker)
	_rig = Rig.new()
	_rig.walker = _walker
	_walker.add_child(_rig)
	_walker.fired.connect(func(at: Vector2, direction: Vector2):
		_shots.append({"a": at, "b": at + direction * 1100.0, "life": .07}))
	_overlay = Node2D.new()
	_overlay.z_index = 200
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	var ui := CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	_panel = TuningPanel.new()
	_panel.setup(Settings.definitions())
	ui.add_child(_panel)
	_panel.command.connect(_command)
	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.title = "보행 설정 저장"
	_exit_dialog.dialog_text = "수정한 보행 설정을 저장하고 이동할까요?"
	_exit_dialog.ok_button_text = "저장하고 이동"
	_exit_dialog.cancel_button_text = "계속 조정"
	_exit_dialog.add_button("저장 안 함", true, "discard")
	_exit_dialog.confirmed.connect(func():
		if save_settings() == OK:
			_navigate())
	_exit_dialog.custom_action.connect(func(action: String):
		if action == "discard":
			_navigate())
	_panel.add_child(_exit_dialog)
	_update_camera()
	_refresh()
	queue_redraw()


func ground_y(x: float) -> float:
	return BASE_Y - float(terrain) * x * .10


func canvas_rect() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(24, 90, maxf(size.x - 392, 300), maxf(size.y - 266, 240))


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _physics_process(delta: float) -> void:
	if not auto_drive:
		_keyboard_dir = 0.0
		_keyboard_run = false
		var interactive := not _typing() and not _exit_dialog.visible
		if interactive:
			_keyboard_dir = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			_keyboard_run = Input.is_physical_key_pressed(KEY_SHIFT)
		var in_canvas := canvas_rect().has_point(get_viewport().get_mouse_position())
		if in_canvas and interactive:
			_aim_offset = get_global_mouse_position() - _walker.body_pos
		_walker.firing = in_canvas and interactive and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_J))
	step(delta)


## Deterministic manual stepping also used by the lab capture/validation tools.
func step(delta: float) -> void:
	if not paused and not _exit_dialog.visible:
		_walker.input_dir = _keyboard_dir if absf(_keyboard_dir) > .01 else float(preview)
		_walker.running = running or _keyboard_run
		_walker.aim_target = auto_aim if auto_aim != null else _walker.body_pos + _aim_offset
		_walker.tick(delta)
		for shot in _shots:
			shot["life"] -= delta
		_shots = _shots.filter(func(shot): return shot["life"] > 0.0)
	_rig._process(0.0)
	_update_camera()
	_refresh()
	_overlay.queue_redraw()
	queue_redraw()


func _update_camera() -> void:
	var area := canvas_rect()
	var air_lift := maxf(ground_y(_walker.body_pos.x) - float(_settings.values["ride"]) - _walker.body_pos.y, 0.0) if _walker.airborne else 0.0
	var zoom := minf(area.size.x / 730.0, area.size.y / (430.0 + air_lift))
	_cam.zoom = Vector2.ONE * zoom
	var focus := Vector2(_walker.body_pos.x, ground_y(_walker.body_pos.x) - 180.0 - air_lift * .5)
	_cam.position = focus + (get_viewport_rect().size * .5 - area.get_center()) / zoom
	_cam.force_update_scroll()


func _refresh() -> void:
	var planted := 0
	for leg in _walker.legs():
		planted += int(not leg["stepping"] and not _walker.airborne)
	_panel.refresh({"values": _settings.values, "dirty": _settings.dirty,
		"loaded": _loaded, "status": _status, "preview": preview, "running": running,
		"paused": paused, "bones": bones, "terrain": terrain,
		"telemetry": "속도 %d  ·  접지 %d / 4  ·  %s" % [roundi(absf(_walker.speed)), planted, "공중" if _walker.airborne else "접지 유지"]})


func _remember() -> void:
	_history.append(_settings.values.duplicate(true))
	if _history.size() > 100:
		_history.pop_front()


func _command(action: String, value: Variant = null) -> void:
	if action != "param":
		_panel.commit_input()
	match action:
		"param":
			var previous: Dictionary = _settings.values.duplicate(true)
			if _settings.set_value(str(value["key"]), float(value["value"])):
				if _walker.apply_spider_tuning(_settings.values):
					if previous != _settings.values:
						_history.append(previous)
						if _history.size() > 100:
							_history.pop_front()
					_status = "미리보기에 적용됨 · Ctrl+S 저장하면 인게임에도 적용됩니다."
				else:
					_restore(previous)
					_status = "이 설정을 적용할 수 없습니다. 이전 값으로 복구했습니다."
			else:
				_status = str(_settings.last_error)
		"save": save_settings()
		"load": load_settings()
		"reset":
			_remember()
			_settings.reset_defaults()
			_walker.apply_spider_tuning(_settings.values)
			_status = "기본값으로 복구 · Ctrl+Z 취소 · 저장하기 전 파일은 유지됩니다."
		"undo":
			if not _history.is_empty():
				_restore(_history.pop_back())
				_status = "조정 취소 · 저장하려면 Ctrl+S"
		"preview": preview = clampi(int(value), -1, 1)
		"run": running = bool(value)
		"pause": paused = bool(value)
		"bones": bones = bool(value)
		"terrain":
			terrain = clampi(int(value), -1, 1)
			_command("reset_pose")
		"jump":
			if not paused:
				_walker.jump()
		"reset_pose":
			_walker.body_pos = Vector2(0, BASE_Y - float(_settings.values["ride"]))
			_walker.speed = 0.0
			_walker.airborne = false
			_walker._angle = 0.0
			_walker._air_v = 0.0
			_walker.reset_stance()
			_shots.clear()
		"lobby", "authoring":
			_destination = action
			if _settings.dirty:
				_exit_dialog.popup_centered()
			else:
				_navigate()
	_refresh()
	_overlay.queue_redraw()


func _restore(values: Dictionary) -> void:
	for key in values:
		_settings.set_value(key, float(values[key]))
	_walker.apply_spider_tuning(_settings.values)


func save_settings() -> Error:
	_panel.commit_input()
	get_viewport().gui_release_focus()
	var error: Error = _settings.save(settings_path)
	if error == OK:
		_loaded = true
	_status = "저장 완료 · 인게임 로봇을 새로 시작하면 적용됩니다." if error == OK else "저장 실패 · " + str(_settings.last_error)
	_refresh()
	return error


func load_settings() -> Error:
	_panel.commit_input()
	var previous: Dictionary = _settings.values.duplicate(true)
	var error: Error = _settings.load_file(settings_path)
	if error == OK:
		_history.append(previous)
		_loaded = true
		_walker.apply_spider_tuning(_settings.values)
		_status = "저장값 불러옴 · Ctrl+Z로 불러오기 전 조정을 복원할 수 있습니다."
	else:
		_status = "불러오기 실패 · " + str(_settings.last_error)
	_refresh()
	return error


func _navigate() -> void:
	if _destination == "authoring":
		AppFlow.start_walker_authoring_lab(get_tree())
	else:
		AppFlow.go_lobby(get_tree())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.physical_keycode == KEY_S:
			_command("save")
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.physical_keycode == KEY_Z and not _typing():
			_command("undo")
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F1:
			_command("lobby")
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Clicking the preview commits a numeric edit and returns keyboard control to the robot.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and canvas_rect().has_point(event.position) and not _exit_dialog.visible:
		_panel.commit_input()
		get_viewport().gui_release_focus()
		return
	if not event is InputEventKey or not event.pressed or event.echo or _typing() or _exit_dialog.visible:
		return
	match event.physical_keycode:
		KEY_SPACE: _command("jump")
		KEY_F2: _command("bones", not bones)
		KEY_F5: _command("reset")
		KEY_F9: print(JSON.stringify(_settings.values, "\t"))
		_:
			if HOTKEYS.has(event.physical_keycode):
				var change: Array = HOTKEYS[event.physical_keycode]
				for definition in Settings.definitions():
					if definition["key"] == change[0]:
						_command("param", {"key": change[0], "value": clampf(float(_settings.values[change[0]]) + float(change[1]), definition["min"], definition["max"])})


func _draw() -> void:
	if _walker == null:
		return
	var left := floorf((_walker.body_pos.x - 2500.0) / 80.0) * 80.0
	var a := Vector2(left, ground_y(left))
	var b := Vector2(left + 5000, ground_y(left + 5000))
	var depth := Vector2(50, ground_y(left + 50.0) - ground_y(left) - 58.5)
	draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 2000), a + Vector2(0, 2000)]), Color("1b2e3a"))
	draw_colored_polygon(PackedVector2Array([a + depth, b + depth, b, a]), Color("253c48"))
	draw_line(a + depth, b + depth, Color("354d59"), 1)
	draw_line(a, b, Color("617c87"), 2)
	for i in 64:
		var x := left + i * 80.0
		var point := Vector2(x, ground_y(x))
		draw_line(point + depth, point, Color("3a505b"), 1)
		draw_line(point, point + Vector2(150, 1500), Color("263d49"), 1)


func _draw_overlay() -> void:
	for shot in _shots:
		_overlay.draw_line(shot["a"], shot["b"], Color(1, .85, .45, float(shot["life"]) / .07), 2.0)
	if not bones:
		return
	for leg in _walker.legs():
		var pose: Dictionary = leg.get("pose", {})
		if pose.is_empty():
			continue
		var color := Color("f6cf77") if leg["stepping"] else (Color("70dae5") if leg["near"] else Color("a596ef"))
		var chain := PackedVector2Array()
		for key in ["mount", "hip", "knee", "ankle", "toe"]:
			chain.append(pose[key])
		_overlay.draw_polyline(chain, color, 2.0, true)
		for point in chain:
			_overlay.draw_circle(point, 3.0, color)
