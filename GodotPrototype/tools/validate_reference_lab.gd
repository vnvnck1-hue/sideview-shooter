extends SceneTree
## Exercise the actual routed scene and its keyboard controls, not a standalone solver.

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load(AppFlow.WALKER_AUTHORING_LAB_SCENE)
	var lab: Node2D = scene.instantiate()
	lab.authoring_enabled = false
	root.add_child(lab)
	current_scene = lab
	await process_frame
	_check(lab.get_script().resource_path == "res://scripts/reference_walker_lab.gd", "lobby route opens reference lab")
	_check(lab._walker.skeleton.get_bone_count() == 20, "actual lab has 20 skeleton bones")
	var start: Vector2 = lab._walker.body_pos
	_key(KEY_D, true)
	for i in range(60):
		await physics_frame
	_key(KEY_D, false)
	_check(lab._walker.body_pos.x > start.x + 100.0, "D drives the actual lab walker")
	await _tap(KEY_TAB)
	_check(lab.reference_mode and lab._art.visible, "Tab opens source overlay")
	_check(lab._walker.source_rest, "overlay uses original reference pose")
	var reference: Vector2 = lab._walker.body_pos
	_key(KEY_D, true)
	for i in range(12):
		await physics_frame
	_key(KEY_D, false)
	_check(lab._walker.body_pos.is_equal_approx(reference), "source overlay stays on the original landmarks")
	await _tap(KEY_O)
	_check(is_equal_approx(lab._art.modulate.a, 1.0), "O shows full original image")
	await _tap(KEY_L)
	_check(not lab._view.show_labels, "L toggles bone labels")
	await _tap(KEY_H)
	_check(lab._view.show_targets, "H toggles ground targets")
	await _tap(KEY_TAB)
	_check(not lab.reference_mode and not lab._art.visible, "Tab returns to walking")
	await _tap(KEY_SPACE)
	_check(lab._walker.airborne, "Space jumps in the actual scene")
	await _tap(KEY_R)
	_check(not lab._walker.airborne and absf(lab._walker.body_pos.x) < 0.1, "R resets the scene")
	await _tap(KEY_P)
	var stopped: Vector2 = lab._walker.body_pos
	_key(KEY_D, true)
	for i in range(12):
		await physics_frame
	_key(KEY_D, false)
	_check(lab._walker.body_pos.is_equal_approx(stopped), "P freezes the walker")
	await _tap(KEY_F1)
	_check(current_scene != lab and current_scene.get_script().resource_path.ends_with("/lobby.gd"), "F1 returns to lobby")
	if _failures.is_empty():
		print("PASS: reference lab routing, movement, overlay, labels, targets, jump, reset, pause, lobby")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _tap(code: Key) -> void:
	_key(code, true)
	await process_frame
	await process_frame
	_key(code, false)
	await process_frame


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _check(ok: bool, context: String) -> void:
	if not ok:
		_failures.append(context)
