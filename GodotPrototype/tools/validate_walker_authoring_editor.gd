extends SceneTree
## Integration test: routed scene, real viewport input, authoring UI, and actual bones.
## Uses only a unique user:// test document; never writes the production document.
const Anatomy = preload("res://scripts/walker_anatomy.gd")
const PRODUCTION := "res://authoring/walker_motion.json"
const BODY_MAP := {"chassis": "body.chassis", "pivot": "body.pivot", "upper_center": "body.upper", "gun": "body.gun", "barrel": "body.barrel", "muzzle": "body.muzzle"}

var lab: Node2D
var editor: Node2D
var _path := ""
var _production_hash := ""
var _failures: Array[String] = []
var _checks := 0
var _max_endpoint_error := 0.0
var _max_length_error := 0.0
var _mouse := Vector2.ZERO


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_path = "user://walker_editor_validation_%d.json" % Time.get_ticks_usec()
	_production_hash = FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "absent"
	await _open_lab()
	_check(editor != null and editor.mode == "pivot", "actual lab starts in pivot editor")
	_check(editor.storage_path == _path, "test storage is isolated")
	_check(editor.panel._list.item_count == 26, "pivot list contains all 26 landmarks")
	_check(lab._walker.skeleton.get_bone_count() == 20, "editor displays 20 real Bone2D bones")
	_check_pose("initial")

	var original: Vector2 = editor.data.points["NF.knee"]
	var moved := original + Vector2(24, -18)
	var before_undo: int = editor.data._undo.size()
	await _drag_raw(original, moved)
	_check(editor.selected == "NF.knee", "real viewport drag selects the closest pivot")
	_near(editor.data.points["NF.knee"], moved, .005, "real drag changes raw coordinates")
	_check(editor.data._undo.size() == before_undo + 1, "one drag produces one undo action")
	_check(not editor._dragging and editor.data._edit_depth == 0, "mouse release closes drag history")
	_check_pose("dragged pivot")
	await _tap(KEY_Z, true)
	_near(editor.data.points["NF.knee"], original, .005, "Ctrl+Z undoes the entire drag")
	await _tap(KEY_Y, true)
	_near(editor.data.points["NF.knee"], moved, .005, "Ctrl+Y reapplies the entire drag")
	await _tap(KEY_S, true)
	_check(FileAccess.file_exists(_path) and not editor.data.dirty, "Ctrl+S saves the isolated document")
	await _close_lab()
	await _open_lab()
	_near(editor.data.points["NF.knee"], moved, .005, "scene reload restores the edited pivot")
	_check(not editor.data.dirty, "reloaded document is clean")
	_check_pose("reloaded pivot")
	# The very first unfinished drag must become dirty before F1 decides to leave.
	await _begin_drag_raw(moved, moved + Vector2(4, -3))
	_check(editor._dragging, "F1 regression begins with a live pivot drag")
	await _tap(KEY_F1)
	_check(current_scene == lab and editor._exit_dialog.visible, "F1 during first drag opens save confirmation instead of leaving")
	_check(not editor._dragging and editor.data.dirty and editor.data._edit_depth == 0, "F1 commits the active drag transaction")
	editor._exit_dialog.hide()
	_mouse_button(_mouse, false)
	_cmd("undo")
	_near(editor.data.points["NF.knee"], moved, .005, "F1-interrupted drag remains undoable")
	before_undo = editor.data._undo.size()
	var outside_start: Vector2 = lab.get_viewport().get_canvas_transform() * editor.world_point(moved)
	var over_panel: Vector2 = editor.panel._side.global_position + Vector2(100, 90)
	await _drag_screen(outside_start, over_panel)
	_check(not editor._dragging and editor.data._edit_depth == 0, "release over a GUI panel closes a canvas drag")
	_check(editor.data._undo.size() == before_undo + 1, "outside release still creates one history action")
	_cmd("undo")
	_near(editor.data.points["NF.knee"], moved, .005, "outside-panel drag can be undone as one action")
	root.gui_release_focus()

	# Filtering must update the real ItemList, selectable canvas handles, and renderer.
	_filter("NF")
	_check(editor.panel._list.item_count == 5, "NF filter shows five pivot rows")
	_check(editor._handles().size() == 5 and lab._view.leg_filter == "NF", "NF filter restricts handles and drawing")
	for id in editor._handles():
		_check(str(id).begins_with("NF."), "filtered handle belongs to NF: " + str(id))
	_filter("body")
	_check(editor.panel._list.item_count == 6 and editor._handles().size() == 6, "body filter shows six landmarks")
	_filter("FR")
	_check(str(editor.selected).begins_with("FR."), "changing leg filter selects a visible FR pivot")
	_filter("all")

	await _tap(KEY_2)
	_check(editor.mode == "keys" and editor.panel._list.item_count == 21, "2 enters keyframe mode with root and 20 bones")
	_cmd("seek", .8)
	_cmd("duration", .2)
	_check(absf(editor.time - .2) < .00001, "shortening a clip clamps the current time to its new duration")
	_cmd("duration", .8)
	_cmd("seek", .4)
	_cmd("select", "NF.upper")
	_cmd("angle", 25.0)
	_check(_key_at(.4), "numeric angle edit automatically records a key")
	_check(absf(editor._pose.angles["NF.upper"] - deg_to_rad(25)) < .00001, "angle is stored in radians")
	_check_pose("angle key")
	_cmd("seek", .2)
	_check(absf(editor._pose.angles["NF.upper"]) > .01 and absf(editor._pose.angles["NF.upper"]) < deg_to_rad(25), "seek interpolates between keys")
	_check_pose("interpolated seek")
	_cmd("seek", .6)
	_filter("NF")
	var pose_before: Dictionary = editor.data.evaluate_pose(editor._pose)
	var pivot: Vector2 = pose_before["NF.knee"]
	var endpoint: Vector2 = pose_before["NF.ankle"]
	var rotated := pivot + (endpoint - pivot).rotated(deg_to_rad(18))
	before_undo = editor.data._undo.size()
	await _drag_raw(endpoint, rotated)
	_check(editor.selected == "NF.lower", "FK drag selects the lower bone endpoint")
	_check(_key_at(.6), "FK drag automatically records a key")
	_check(editor.data._undo.size() == before_undo + 1, "FK drag remains one undo action")
	_check(absf(editor._pose.angles["NF.lower"] - deg_to_rad(18)) < .002, "FK drag rotates around its parent joint")
	_check_pose("FK drag")
	_filter("all")
	# Exercise the actual timeline diamond's input path, not only its signal contract.
	await process_frame
	var timeline: Control = editor.panel._timeline
	var track_y: float = (timeline.size.y + 10.0) * .5
	var timeline_start: Vector2 = timeline.global_position + Vector2(timeline._time_to_x(.4), track_y)
	var timeline_end: Vector2 = timeline.global_position + Vector2(timeline._time_to_x(.45), track_y)
	before_undo = editor.data._undo.size()
	await _drag_screen(timeline_start, timeline_end)
	_check(_key_at(.45) and not _key_at(.4), "dragging a timeline diamond retimes its key")
	_check(editor.data._undo.size() == before_undo + 1, "retiming one key creates one undo action")
	_cmd("undo")
	_check(_key_at(.4) and not _key_at(.45), "retime undo restores the original timestamp")
	_cmd("redo")
	_check(_key_at(.45) and not _key_at(.4), "retime redo restores the changed timestamp")
	_cmd("move_key", {"from": .45, "to": .6})
	_check(_key_at(.45) and _key_at(.6), "retime refuses to overwrite an occupied timestamp")
	root.gui_release_focus()

	# Deterministic playback uses the same step() called by the scene each physics tick.
	lab.set_physics_process(false)
	_cmd("seek", .79)
	_cmd("play", true)
	editor.step(.1)
	_check(editor.playing and absf(editor.time - .09) < .00001, "looping playback wraps into the clip")
	for i in range(180):
		editor.step(1.0 / 60.0)
		_check_pose("playback %d" % i)
	_cmd("loop", false)
	_cmd("seek", .79)
	_cmd("play", true)
	editor.step(.1)
	_check(not editor.playing and is_equal_approx(editor.time, .8), "non-looping playback stops at the end")
	_cmd("loop", true)
	lab.set_physics_process(true)
	# A key exactly at loop duration has its own pose; entering the editor is not playback wrapping.
	_cmd("seek", .8)
	_cmd("select", "torso")
	_cmd("angle", -31.0)
	_cmd("select", "NF.upper")
	_cmd("angle", 44.0)
	_cmd("select", "root")
	_cmd("point_x", 17.0)
	_cmd("point_y", -9.0)
	_cmd("ease", "hold")
	var end_pose: Dictionary = editor._pose.duplicate(true)
	for cycle in range(3):
		_cmd("mode", "pivot")
		_cmd("mode", "keys")
		_check(_equivalent(editor._pose, end_pose), "duration-end multi-joint pose survives mode roundtrip %d" % cycle)
		_check(editor._ease == "hold", "duration-end hold ease survives mode roundtrip %d" % cycle)
		_check_pose("duration endpoint roundtrip %d" % cycle)
	_cmd("select", "gun")
	_cmd("angle", 12.0)
	_cmd("undo")
	_check(_equivalent(editor._pose, end_pose) and editor._ease == "hold", "undo at loop duration restores the explicit endpoint pose and hold ease")
	_check_pose("undo at loop endpoint")
	_cmd("seek", .32)
	_filter("NF")
	var unfinished: Dictionary = editor.data.evaluate_pose(editor._pose)
	var unfinished_pivot: Vector2 = unfinished["NF.knee"]
	var unfinished_end: Vector2 = unfinished["NF.ankle"]
	await _begin_drag_raw(unfinished_end, unfinished_pivot + (unfinished_end - unfinished_pivot).rotated(.2))
	_check(editor._dragging, "Space regression begins with a live FK drag")
	await _tap(KEY_SPACE)
	_check(editor.playing and not editor._dragging and editor.data._edit_depth == 0, "Space finalizes the FK drag before starting playback")
	_check(_key_at(.32), "Space during drag records the new key without losing the pose")
	_mouse_button(_mouse, false)
	_cmd("play", false)
	_cmd("undo")
	_check(not _key_at(.32), "Space-interrupted FK drag is one undo action")
	_filter("all")

	# Text entry must consume authoring shortcuts before the scene's unhandled input.
	_cmd("seek", .3)
	var keys_before: int = editor.data.clips[editor.clip_id].keys.size()
	var name_field: LineEdit = editor.panel._new_clip
	name_field.grab_focus()
	name_field.clear()
	await _type_text("123k f")
	_check(editor.mode == "keys", "typing 1/2/3 in clip name does not switch mode")
	_check(not editor.playing, "typing space in clip name does not start playback")
	_check(editor.data.clips[editor.clip_id].keys.size() == keys_before, "typing K in clip name does not insert a key")
	_check(name_field.text == "123k f", "shortcut characters are entered into the text field")
	name_field.release_focus()
	_cmd("mode", "pivot")
	_cmd("select", "NF.knee")
	var coordinate: LineEdit = editor.panel._x.get_line_edit()
	coordinate.grab_focus()
	coordinate.select_all()
	await _type_text("812")
	await _tap(KEY_ENTER)
	_check(editor.mode == "pivot", "numeric text entry does not switch mode")
	_check(absf(editor.data.points["NF.knee"].x - 812) < .001, "coordinate field commits typed input")
	coordinate.release_focus()
	_check_pose("coordinate entry")
	coordinate.grab_focus()
	coordinate.select_all()
	await _type_text("827")
	await _tap(KEY_S, true)
	_check(absf(editor.data.points["NF.knee"].x - 827) < .001 and not editor.data.dirty, "Ctrl+S commits an unfinished SpinBox edit before saving: actual=%s dirty=%s field=%s status=%s" % [editor.data.points["NF.knee"].x, editor.data.dirty, coordinate.text, editor._status])
	var saved_unfinished: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path))
	_check(absf(float(saved_unfinished.points["NF.knee"][0]) - 827) < .001, "Ctrl+S document includes unfinished typed coordinate, saved x=" + str(saved_unfinished.points["NF.knee"][0]))
	coordinate.release_focus()
	coordinate.grab_focus()
	coordinate.select_all()
	await _type_text("836")
	var keys_button: Button = editor.panel._mode_buttons["keys"]
	await _drag_screen(keys_button.get_global_rect().get_center(), keys_button.get_global_rect().get_center())
	_check(editor.mode == "keys" and absf(editor.data.points["NF.knee"].x - 836) < .001, "mode button commits typed coordinate to the original pivot")
	_cmd("mode", "pivot")
	_cmd("select", "NF.knee")
	coordinate.grab_focus()
	coordinate.select_all()
	await _type_text("842")
	var save_button: Button
	for candidate in editor.panel.find_children("*", "Button", true, false):
		if candidate.text.begins_with("저장"):
			save_button = candidate
			break
	_check(save_button != null, "visible save button exists")
	if save_button != null:
		var save_at := save_button.get_global_rect().get_center()
		_mouse_motion(save_at, false)
		await process_frame
		# Down/up in one frame reproduces focus-exit ordering without a frame to commit.
		_mouse_button(save_at, true)
		_mouse_button(save_at, false)
		await process_frame
		await process_frame
		var button_document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_path))
		_check(absf(editor.data.points["NF.knee"].x - 842) < .001 and not editor.data.dirty, "save button commits unfinished coordinate: actual=%s dirty=%s" % [editor.data.points["NF.knee"].x, editor.data.dirty])
		_check(absf(float(button_document.points["NF.knee"][0]) - 842) < .001, "save button document includes unfinished coordinate, saved=" + str(button_document.points["NF.knee"][0]))
	var point_list: ItemList = editor.panel._list
	var next_id: String = point_list.get_item_metadata(0)
	var next_before: Vector2 = editor.data.points[next_id]
	point_list.get_v_scroll_bar().value = 0.0
	await process_frame
	coordinate.grab_focus()
	coordinate.select_all()
	await _type_text("838")
	var item_center: Vector2 = point_list.global_position + point_list.get_item_rect(0).get_center()
	await _drag_screen(item_center, item_center)
	_check(editor.selected == next_id, "real ItemList click selects another pivot: expected " + next_id + " actual " + editor.selected)
	_check(absf(editor.data.points["NF.knee"].x - 838) < .001, "selecting another pivot commits pending input to the old pivot: actual=" + str(editor.data.points["NF.knee"].x))
	_near(editor.data.points[next_id], next_before, .0001, "pending coordinate does not contaminate the new selection")
	root.gui_release_focus()

	var stable_points: Dictionary = editor.data.points.duplicate(true)
	for iteration in range(25):
		_cmd("mode", "keys")
		_cmd("seek", .013 * iteration)
		_cmd("mode", "pivot")
		for id in stable_points:
			_near(editor.data.points[id], stable_points[id], .0001, "no pivot drift after pose read: " + str(id))
	for id in stable_points:
		_near(editor.raw_point(editor.world_point(stable_points[id])), stable_points[id], .0002, "raw/world conversion: " + str(id))
	await _tap(KEY_3)
	_check(editor.mode == "walk" and not lab.reference_mode, "3 enables procedural walk with edited anatomy")
	var walk_start: Vector2 = lab._walker.body_pos
	_key(KEY_D, true)
	for i in range(60):
		await physics_frame
		_check_lengths("edited procedural walk %d" % i)
	_key(KEY_D, false)
	_check(lab._walker.body_pos.x > walk_start.x + 30, "actual D input moves edited skeleton")
	await _tap(KEY_1)
	_check(editor.mode == "pivot", "1 returns to pivot mode")
	for id in stable_points:
		_near(editor.data.points[id], stable_points[id], .0001, "walk does not rewrite source point: " + str(id))
	_check_pose("return from walk")
	_cmd("save")
	var saved_points: Dictionary = editor.data.points.duplicate(true)
	var saved_clip: Dictionary = editor.data.clips["walk"].duplicate(true)
	await _close_lab()
	await _open_lab()
	for id in saved_points:
		_near(editor.data.points[id], saved_points[id], .0001, "final reload raw pivot: " + str(id))
	_check(_equivalent(editor.data.clips["walk"], saved_clip), "final reload retains authored keys and clip settings")
	_check_pose("final reload")
	await _close_lab()
	var final_hash := FileAccess.get_sha256(PRODUCTION) if FileAccess.file_exists(PRODUCTION) else "absent"
	_check(final_hash == _production_hash, "production authoring document remains untouched")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path + ".bak"))
	print("Authoring editor: %d checks, endpoint max %.6f px, length max %.6f px, %d failures" % [_checks, _max_endpoint_error, _max_length_error, _failures.size()])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)


func _open_lab() -> void:
	var scene: PackedScene = load(AppFlow.WALKER_AUTHORING_LAB_SCENE)
	lab = scene.instantiate()
	lab.authoring_path = _path
	root.add_child(lab)
	current_scene = lab
	await process_frame
	await process_frame
	editor = lab._authoring


func _close_lab() -> void:
	current_scene = null
	lab.queue_free()
	await process_frame
	await process_frame


func _cmd(action: String, value = null) -> void:
	editor.panel.command.emit(action, value)


func _filter(id: String) -> void:
	var options: OptionButton = editor.panel._filters
	for i in options.item_count:
		if str(options.get_item_metadata(i)) == id:
			options.select(i)
			options.item_selected.emit(i)
			return
	_check(false, "filter option exists: " + id)


func _key_at(at: float) -> bool:
	for key in editor.data.clips[editor.clip_id].keys:
		if absf(key.time - at) < .0001:
			return true
	return false


func _drag_raw(start: Vector2, finish: Vector2) -> void:
	var start_screen: Vector2 = lab.get_viewport().get_canvas_transform() * editor.world_point(start)
	var end_screen: Vector2 = lab.get_viewport().get_canvas_transform() * editor.world_point(finish)
	_check(editor.canvas_rect().has_point(start_screen), "drag begins inside canvas")
	await _drag_screen(start_screen, end_screen)


func _drag_screen(start_screen: Vector2, end_screen: Vector2) -> void:
	_mouse_motion(start_screen, false)
	await process_frame
	_mouse_button(start_screen, true)
	await process_frame
	for i in range(1, 5):
		_mouse_motion(start_screen.lerp(end_screen, i / 4.0), true)
		await process_frame
	_mouse_button(end_screen, false)
	await process_frame


func _begin_drag_raw(start: Vector2, finish: Vector2) -> void:
	var transform: Transform2D = lab.get_viewport().get_canvas_transform()
	var start_screen: Vector2 = transform * editor.world_point(start)
	var end_screen: Vector2 = transform * editor.world_point(finish)
	_mouse_motion(start_screen, false)
	await process_frame
	_mouse_button(start_screen, true)
	await process_frame
	_mouse_motion(end_screen, true)
	await process_frame


func _mouse_motion(at: Vector2, down: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - _mouse
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_mouse = at
	Input.parse_input_event(event)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)


func _tap(code: Key, control := false, unicode := 0) -> void:
	_key(code, true, control, unicode)
	await process_frame
	_key(code, false, control, unicode)
	await process_frame


func _key(code: Key, pressed: bool, control := false, unicode := 0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.ctrl_pressed = control
	event.unicode = unicode
	Input.parse_input_event(event)


func _type_text(value: String) -> void:
	for i in value.length():
		await _tap(value.substr(i, 1).to_upper().unicode_at(0) as Key, false, value.unicode_at(i))


func _raw_from_walker() -> Dictionary:
	var raw := {}
	for leg in lab._walker.pose_legs():
		for part in ["mount", "hip", "knee", "ankle", "toe"]:
			raw[leg.id + "." + part] = leg[part]
	var body: Dictionary = lab._walker.pose_body()
	for key in BODY_MAP:
		raw[BODY_MAP[key]] = body[key]
	return raw


func _bones() -> Dictionary:
	var result := {"chassis": lab._walker._chassis, "torso": lab._walker._upper_assembly, "gun": lab._walker._gun, "barrel": lab._walker._barrel}
	for leg in lab._walker._legs:
		var chain: Array = lab._walker._leg_bones[leg.id]
		for i in 4:
			result[leg.id + "." + ["mount", "upper", "lower", "foot"][i]] = chain[i]
	return result


func _check_pose(context: String) -> void:
	var expected: Dictionary = editor.data.evaluate_pose(editor.data.neutral_pose() if editor.mode == "pivot" else editor._pose)
	var actual := _raw_from_walker()
	for id in expected:
		_near(actual[id], editor.world_point(expected[id]), .002, context + " pose " + str(id))
	var bones := _bones()
	for definition in editor.data.bone_definitions():
		var bone: Bone2D = bones[definition.id]
		var start: Vector2 = lab.to_local(bone.to_global(Vector2.ZERO))
		var finish: Vector2 = lab.to_local(bone.to_global(Vector2.RIGHT * bone.length))
		var error := maxf(start.distance_to(actual[definition.start]), finish.distance_to(actual[definition.end]))
		_max_endpoint_error = maxf(_max_endpoint_error, error)
		_check(error < .002, context + " actual bone endpoint " + definition.id + " error " + str(error))
	_check_lengths(context)


func _check_lengths(context: String) -> void:
	var actual := _raw_from_walker()
	var spatial_walk: bool = editor.mode == "walk" and lab._walker.spider_gait
	if spatial_walk:
		for leg in lab._walker.pose_legs():
			var points: Array = leg.get("spatial_points", [])
			var lengths: Array = leg.get("spatial_lengths", [])
			_check(points.size() == 5 and lengths.size() == 4, context + " spatial chain " + String(leg.id))
			if points.size() != 5 or lengths.size() != 4:
				continue
			var chain: Array = lab._walker._leg_bones[leg.id]
			var names := ["mount", "hip", "knee", "ankle", "toe"]
			for i in 4:
				var a: Vector3 = points[i]
				var b: Vector3 = points[i + 1]
				var error := absf(a.distance_to(b) - float(lengths[i]))
				_max_length_error = maxf(_max_length_error, error)
				_check(a.is_finite() and b.is_finite() and error < .002,
					context + " spatial length " + String(leg.id) + "." + names[i] + " error " + str(error))
				var bone: Bone2D = chain[i]
				var start: Vector2 = lab.to_local(bone.to_global(Vector2.ZERO))
				var finish: Vector2 = lab.to_local(bone.to_global(Vector2.RIGHT * bone.length))
				var endpoint_error := maxf(start.distance_to(leg[names[i]]), finish.distance_to(leg[names[i + 1]]))
				_max_endpoint_error = maxf(_max_endpoint_error, endpoint_error)
				_check(endpoint_error < .002,
					context + " projected bone " + String(leg.id) + "." + names[i] + " error " + str(endpoint_error))
	for definition in editor.data.bone_definitions():
		if spatial_walk and String(definition.id).contains("."):
			continue # A spatial leg's screen length changes as it moves in depth.
		var rest: float = (editor.data.points[definition.start] as Vector2).distance_to(editor.data.points[definition.end]) * Anatomy.SCALE
		var error: float = absf((actual[definition.start] as Vector2).distance_to(actual[definition.end]) - rest)
		_max_length_error = maxf(_max_length_error, error)
		_check(error < .002, context + " length " + definition.id + " error " + str(error))


func _near(actual: Vector2, expected: Vector2, tolerance: float, context: String) -> void:
	_check(actual.distance_to(expected) <= tolerance, context + " actual " + str(actual) + " expected " + str(expected))


func _equivalent(a, b) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < .000001
	if a is Vector2 and b is Vector2:
		return a.distance_to(b) < .0001
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _equivalent(a[key], b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _equivalent(a[i], b[i]):
				return false
		return true
	return a == b


func _check(ok: bool, context: String) -> void:
	_checks += 1
	if not ok and not _failures.has(context):
		_failures.append(context)
