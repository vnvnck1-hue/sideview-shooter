extends SceneTree
## Real viewport input + tuning UI + the actual in-game WalkerUnit contract.
## Only a unique user:// settings document is written; production files are hashed.

const Settings = preload("res://scripts/walker_gait_settings.gd")
const Unit = preload("res://scripts/walker_unit.gd")
const STEP := 1.0 / 60.0
const PROTECTED := ["res://authoring/walker_motion.json", Settings.DEFAULT_PATH, "res://assets/reference/walker_original.png"]
var _lab: Node2D
var _panel: Control
var _path := ""
var _before: Dictionary = {}
var _failures: Array[String] = []
var _checks := 0
var _mouse := Vector2.ZERO
var _shots := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_before = _hashes()
	_path = "user://walker_tuning_validation_%d.json" % Time.get_ticks_usec()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	var scene := load(AppFlow.WALKER_LAB_SCENE) as PackedScene
	if scene == null:
		push_error("Tuning lab cannot instantiate")
		quit(1)
		return
	_lab = scene.instantiate()
	_lab.settings_path = _path
	_lab.auto_drive = true
	root.add_child(_lab)
	await process_frame
	await process_frame
	_lab.set_physics_process(false)
	_lab._rig.set_process(false)
	_panel = _lab._panel
	_lab._walker.fired.connect(func(_at: Vector2, _direction: Vector2): _shots += 1)
	_check(_lab._walker.get_script().resource_path == "res://scripts/proc_walker.gd", "lab uses the game's ProcWalker")
	_check(_lab._rig.get_script().resource_path == "res://scripts/walker_rig.gd" and _lab._rig.walker == _lab._walker, "lab uses the actual game art rig")
	_check(_panel._spins.size() == Settings.definitions().size(), "every schema field has a numeric control")
	_check(_panel._sliders.size() == Settings.definitions().size(), "every schema field has a slider")
	_check(_panel._tabs.tab_count == 5, "all five parameter groups are present")
	_check(not FileAccess.file_exists(_path), "opening the lab does not create a settings file")
	_check(_panel._dirty.text.contains("기본"), "absent document is shown as defaults")
	for definition in Settings.definitions():
		var key := String(definition["key"])
		_check(absf(_panel._spins[key].value - float(_lab._settings.values[key])) < .0001,
			"numeric field shows exact current value: " + key)
		_check(absf(_panel._sliders[key].value - float(_lab._settings.values[key])) < .0001,
			"slider shows exact current value: " + key)
	_bounds("1280")

	# A real pointer drag must reach settings and simulation without firing a gun.
	var slider: HSlider = _panel._sliders["speed"]
	var old_speed: float = _lab._settings.values["speed"]
	var at := slider.get_global_rect().get_center()
	await _move(at, false)
	_button(at, true)
	await process_frame
	await _move(slider.global_position + Vector2(slider.size.x * .75, slider.size.y * .5), true)
	_lab.auto_drive = false
	_lab._physics_process(STEP)
	_lab.auto_drive = true
	_button(_mouse, false)
	await process_frame
	_check(not is_equal_approx(float(_lab._settings.values["speed"]), old_speed), "actual slider drag changes speed")
	_check(is_equal_approx(float(_lab._settings.values["speed"]), float(_lab._walker.tune["speed"])), "slider change applies to live gait")
	_check(_shots == 0 and not _lab._walker.firing, "editing a slider does not shoot")

	# Pending text must survive refresh, a button save, Ctrl+S, and a group switch.
	await _type_spin(_panel._spins["speed"], "370")
	_lab.step(STEP)
	_check((_panel._spins["speed"] as SpinBox).get_line_edit().text == "370", "refresh preserves pending numeric text")
	await _click(_panel._save)
	var saved := Settings.new()
	_check(saved.load_file(_path) == OK and is_equal_approx(float(saved.values["speed"]), 370.0), "save button commits pending numeric text before writing")
	await _type_spin(_panel._spins["speed"], "390")
	await _tap(KEY_S, true)
	_check(saved.load_file(_path) == OK and is_equal_approx(float(saved.values["speed"]), 390.0), "Ctrl+S commits focused SpinBox text")
	await _type_spin(_panel._spins["speed"], "360")
	await _click_tab(1)
	_check(is_equal_approx(float(_lab._settings.values["speed"]), 360.0), "group switch commits the old numeric field")
	_check(_lab._settings.dirty, "an unsaved tuning change is marked dirty")
	_check(_shots == 0, "clicking group tabs does not fire")
	await _click_tab(0)
	await _type_spin(_panel._spins["speed"], "380")
	await _click_at(_lab.canvas_rect().get_center())
	_check(is_equal_approx(float(_lab._settings.values["speed"]), 380.0) and not _lab._typing(),
		"canvas click commits pending value and releases typing focus")
	_key(KEY_A, true)
	await process_frame
	_lab.auto_drive = false
	_lab._physics_process(STEP)
	_check(_lab._keyboard_dir < -.9 and _lab._walker.input_dir < -.9, "A/D movement resumes after leaving numeric input")
	_key(KEY_A, false)
	_lab.auto_drive = true
	_lab._keyboard_dir = 0.0

	# Every field's signal must target its own key, including hidden tab pages.
	for definition in Settings.definitions():
		var key := String(definition["key"])
		var spin: SpinBox = _panel._spins[key]
		var value := clampf(float(definition["default"]) + float(definition["step"]), float(definition["min"]), float(definition["max"]))
		spin.value = value
		_check(is_equal_approx(float(_lab._settings.values[key]), spin.value), "numeric control targets schema key: " + key)
		_check(is_equal_approx(float(_lab._walker.tune[key]), spin.value), "runtime shares edited value: " + key)
	await _click(_panel._save)
	_check(not _lab._settings.dirty, "successful save clears dirty state")
	var saved_values: Dictionary = _lab._settings.values.duplicate(true)
	var file_hash := FileAccess.get_sha256(_path)
	await _click(_panel._reset)
	_check(_lab._settings.values == Settings.defaults(), "defaults button restores all schema values")
	_check(FileAccess.get_sha256(_path) == file_hash, "defaults button does not overwrite the saved document")
	await _click(_panel._load)
	_check(_same_values(_lab._settings.values, saved_values) and not _lab._settings.dirty, "load restores the saved settings")

	# Preview controls use the same rig continuously, without taking over the UI.
	await _click(_panel._preview_buttons[-1])
	var initial_x: float = _lab._walker.body_pos.x
	for _i in 90: _lab.step(STEP)
	_check(_lab._walker.body_pos.x < initial_x - 25.0, "left preview walks left")
	await _click(_panel._preview_buttons[1])
	initial_x = _lab._walker.body_pos.x
	for _i in 120: _lab.step(STEP)
	_check(_lab._walker.body_pos.x > initial_x + 25.0, "right preview reverses and walks right")
	await _click(_panel._run)
	_check(_lab.running, "run toggle reaches the controller")
	await _click(_panel._pause)
	var paused_at: Vector2 = _lab._walker.body_pos
	for _i in 30: _lab.step(STEP)
	_check(_lab.paused and _lab._walker.body_pos.is_equal_approx(paused_at), "pause freezes the pose")
	await _click(_panel._pause)
	await _click(_panel._bones)
	_check(_lab.bones and _lab._rig.visible, "bone overlay preserves the textured rig")
	await _click(_panel._preview_buttons[0])
	for _i in 90: _lab.step(STEP)
	_lab._command("jump")
	var airborne := false
	for _i in 90:
		_lab.step(STEP)
		airborne = airborne or _lab._walker.airborne
	_check(airborne, "jump control launches the actual walker")
	_lab._command("reset_pose")
	_check(absf(_lab._walker.body_pos.x) < .01, "pose reset restores preview position")
	_panel._terrain.select(1)
	_panel._terrain.item_selected.emit(1)
	_check(_lab.ground_y(100.0) < _lab.ground_y(0.0), "uphill control changes actual ground")
	_panel._terrain.select(2)
	_panel._terrain.item_selected.emit(2)
	_check(_lab.ground_y(100.0) > _lab.ground_y(0.0), "downhill control changes actual ground")
	_panel._terrain.select(0)
	_panel._terrain.item_selected.emit(0)

	await _game_unit(saved_values)
	root.size = Vector2i(2240, 900)
	root.content_scale_size = root.size
	await process_frame
	await process_frame
	_lab.step(STEP)
	_bounds("2240")
	_check(_hashes() == _before, "production gait document, pivot document, and artwork are unchanged")
	print("WALKER TUNING LAB: %d checks; %d failures; protected files unchanged=%s" % [_checks, _failures.size(), _hashes() == _before])
	for failure in _failures: print("FAIL ", failure)
	_lab.free()
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(_path + suffix): DirAccess.remove_absolute(_path + suffix)
	quit(0 if _failures.is_empty() else 1)


func _game_unit(expected: Dictionary) -> void:
	for action in ["move_left", "move_right", "run", "shoot", "roll"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var world := Node2D.new()
	root.add_child(world)
	var unit = Unit.new()
	unit.tuning_path = _path
	world.add_child(unit)
	unit.setup(0.0, 620.0, world)
	unit.set_process(false)
	unit._rig.set_process(false)
	unit._rig._process(0.0)
	_check(unit.tuning_load_error == OK, "actual WalkerUnit loads the isolated saved settings")
	for key in expected:
		_check(is_equal_approx(float(unit._tune[key]), float(expected[key])), "in-game standing target matches lab: " + key)
	var game_textures: Array[String] = []
	var lab_textures: Array[String] = []
	_textures(unit._rig, game_textures)
	_textures(_lab._rig, lab_textures)
	game_textures.sort()
	lab_textures.sort()
	_check(game_textures.size() >= 12 and game_textures == lab_textures,
		"lab renders the exact same texture parts as the game unit: game=%d lab=%d" % [game_textures.size(), lab_textures.size()])
	unit.activate()
	unit.aim_target = Vector2(650, 400)
	for _i in 100: unit._process(STEP)
	_check(unit.state == Unit.State.READY, "actual game unit wakes with tuned gait")
	for key in expected:
		_check(is_equal_approx(float(unit._walker.tune[key]), float(expected[key])), "waking preserves shared gait value: " + key)
	world.free()


func _textures(node: Node, result: Array[String]) -> void:
	if node is Sprite2D and node.texture != null: result.append(node.texture.resource_path)
	for child in node.get_children(): _textures(child, result)


func _same_values(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size(): return false
	for key in a:
		if not b.has(key) or not is_equal_approx(float(a[key]), float(b[key])): return false
	return true


func _bounds(context: String) -> void:
	var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
	for key in ["_top", "_side", "_bottom"]:
		_check(viewport.encloses((_panel.get(key) as Control).get_global_rect()), context + " panel fits viewport: " + key)
	_check(not _panel._side.get_global_rect().intersects(_panel._bottom.get_global_rect()), context + " controls do not overlap")
	for index in _panel._tabs.tab_count:
		_check(_panel._tabs.get_tab_rect(index).end.x <= _panel._tabs.size.x + .5, context + " all group tabs fit: " + str(index))


func _type_spin(spin: SpinBox, text: String) -> void:
	var edit := spin.get_line_edit()
	await _click(edit)
	await _tap(KEY_A, true)
	for index in text.length():
		await _tap(text.substr(index, 1).to_upper().unicode_at(0) as Key, false, text.unicode_at(index))


func _click_tab(index: int) -> void:
	var rect: Rect2 = _panel._tabs.get_tab_rect(index)
	await _click_at(_panel._tabs.global_position + rect.get_center())


func _click(control: Control) -> void:
	await _click_at(control.get_global_rect().get_center())


func _click_at(at: Vector2) -> void:
	await _move(at, false)
	_button(at, true)
	await process_frame
	_button(at, false)
	await process_frame


func _move(at: Vector2, down: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - _mouse
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_mouse = at
	Input.parse_input_event(event)
	await process_frame


func _button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)


func _tap(key: Key, ctrl := false, unicode := 0) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.unicode = unicode
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok and message not in _failures: _failures.append(message)


func _hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in PROTECTED:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result
