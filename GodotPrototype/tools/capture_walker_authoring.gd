extends SceneTree
## Actual authoring UI capture. Demo edits stay in memory; never writes the document JSON.
## Run without --headless using --rendering-method gl_compatibility.

const Lab := preload("res://scripts/reference_walker_lab.gd")
const OUT := "res://tools/artifacts/walker_authoring/"
const DEMO_PATH := OUT + "nonexistent.json"
const STEP := 1.0 / 60.0

var _viewport: SubViewport
var _lab: Node2D
var _editor: Node2D
var _frame := 0
var _waiting := 0
var _metadata: Array[Dictionary] = []


func _initialize() -> void:
	if FileAccess.file_exists(DEMO_PATH):
		push_error("Authoring capture requires its demo load path to be absent: " + DEMO_PATH)
		quit(1)
		return
	root.hide()
	root.size = Vector2i(1280, 720)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(_viewport)
	_lab = Lab.new()
	_lab.set("auto_drive", false)
	_lab.set("authoring_enabled", true)
	_lab.set("authoring_path", DEMO_PATH)
	_viewport.add_child(_lab)
	DirAccess.make_dir_recursive_absolute(OUT)


func _process(_delta: float) -> bool:
	if _lab == null:
		return true
	if _editor == null:
		_waiting += 1
		if _lab.is_node_ready():
			_editor = _lab.get("_authoring") as Node2D
		if _editor == null or not _editor.is_node_ready():
			_editor = null
			if _waiting > 60:
				push_error("Authoring capture: editor did not initialize")
				quit(1)
				return true
			return false
		_lab.set_physics_process(false)
		_editor.call("_command", "select", "NF.knee")
		_editor.set("_zoom", 1.2)
		return false
	if _frame == 30 or _frame == 60:
		if not _save("01_pivots.png" if _frame == 30 else "02_keyframes.png"):
			quit(1)
			return true
	if _frame >= 60:
		var timeline_probe := _probe_timeline_drag()
		var file := FileAccess.open(OUT + "capture_metadata.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({
			"description": "Actual 1280x720 WalkerAuthoringPanel. Keyframe demo modifies memory only; no document JSON saved.",
			"demo_document_created": FileAccess.file_exists(DEMO_PATH), "captures": _metadata,
			"timeline_drag_probe": timeline_probe,
		}, "\t"))
		file.close()
		print("Authoring UI capture complete; demo document exists: " + str(FileAccess.file_exists(DEMO_PATH)))
		quit(0 if bool(timeline_probe["passed"]) else 1)
		return true
	_frame += 1
	if _frame == 31:
		_editor.call("_command", "mode", "keys")
		_editor.call("_command", "seek", 0.2)
		_editor.call("_command", "select", "NF.upper")
		_editor.call("_command", "angle", 15.0)
	_editor.call("step", STEP)
	RenderingServer.force_draw(false, STEP)
	return false


func _save(filename: String) -> bool:
	var picture := _viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("Authoring capture: renderer returned an empty image")
		return false
	if picture.save_png(OUT + filename) != OK:
		return false
	var panel := _editor.get("panel") as Control
	var outside: Array[String] = []
	_check_bounds(panel, outside)
	var bounds := {}
	for key in ["_top", "_side", "_bottom"]:
		var control := panel.get(key) as Control
		var rect := control.get_global_rect()
		bounds[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	_metadata.append({
		"file": filename, "mode": _editor.get("mode"), "selected": _editor.get("selected"),
		"time": _editor.get("time"), "panel_bounds": bounds, "outside_viewport": outside,
	})
	print("  " + filename + " / outside controls: " + str(outside))
	return true


func _probe_timeline_drag() -> Dictionary:
	var panel := _editor.get("panel") as Control
	var timeline := panel.get("_timeline") as Control
	var moves: Array = []
	timeline.connect("key_moved", func(from: float, to: float): moves.append([from, to]))
	var point := Vector2(float(timeline.call("_time_to_x", 0.2)), (timeline.size.y + 10.0) * 0.5)
	var end := Vector2(float(timeline.call("_time_to_x", 0.33)), point.y)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	# A plain diamond click seeks but does not retime or create an undo transaction.
	timeline.call("_gui_input", press)
	timeline.call("_gui_input", release)
	var click_did_not_move := moves.is_empty()
	timeline.call("_gui_input", press)
	var motion := InputEventMouseMotion.new()
	motion.position = end
	motion.relative = end - point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	timeline.call("_gui_input", motion)
	var preview_did_not_commit := moves.is_empty()
	release.position = end
	timeline.call("_gui_input", release)
	var moved_once := moves.size() == 1
	var model = _editor.get("data")
	var clip_id := String(_editor.get("clip_id"))
	var after: Array = model.clips[clip_id]["keys"]
	var has_new := _has_key(after, 0.33)
	var removed_old := not _has_key(after, 0.2)
	_editor.call("_command", "undo", null)
	var restored: Array = model.clips[clip_id]["keys"]
	var undo_restored := _has_key(restored, 0.2) and not _has_key(restored, 0.33)
	var passed := click_did_not_move and preview_did_not_commit and moved_once and has_new and removed_old and undo_restored
	print("  Timeline key drag: click=%s preview=%s release_once=%s model_moved=%s undo=%s" % [
		click_did_not_move, preview_did_not_commit, moved_once, has_new and removed_old, undo_restored])
	return {"passed": passed, "click_only_seeks": click_did_not_move, "preview_does_not_commit": preview_did_not_commit,
		"release_emits_once": moved_once, "model_key_retimed": has_new and removed_old, "single_undo_restores": undo_restored}


func _has_key(keys: Array, time: float) -> bool:
	for key in keys:
		if absf(float(key["time"]) - time) < 0.001:
			return true
	return false


func _check_bounds(node: Node, outside: Array[String]) -> void:
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree():
			return
		var rect := control.get_global_rect()
		if rect.size.x > 0.0 and rect.size.y > 0.0 and (rect.position.x < -0.5 or rect.position.y < -0.5 or rect.end.x > 1280.5 or rect.end.y > 720.5):
			outside.append(str(node.get_path()) + " " + str(rect))
	for child in node.get_children():
		_check_bounds(child, outside)
