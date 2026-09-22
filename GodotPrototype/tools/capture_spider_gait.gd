extends SceneTree
## Reproducible full-UI gait capture using the user's SAVED pivots, read-only.
## godot --path GodotPrototype --rendering-method gl_compatibility --script res://tools/capture_spider_gait.gd -- baseline
## Optional output label: baseline / current. Never sends a document save command.

const Lab = preload("res://scripts/reference_walker_lab.gd")
const DOCUMENT := "res://authoring/walker_motion.json"
const ART := "res://assets/reference/walker_original.png"
const STEP := 1.0 / 60.0
const LAST_FRAME := 480
const STILLS := {60: "01_neutral", 150: "02_left", 270: "03_right", 345: "04_run", 383: "05_jump", 480: "06_settle"}
const SOURCES := ["res://scripts/reference_walker.gd", "res://scripts/spider_leg_ik.gd",
	"res://scripts/reference_walker_view.gd", "res://scripts/walker_anatomy.gd",
	"res://scripts/reference_walker_lab.gd", "res://scripts/walker_authoring_editor.gd"]

var _viewport: SubViewport
var _lab: Node2D
var _editor: Node2D
var _walker: Node2D
var _frame := 0
var _waiting := 0
var _movie_frames := 0
var _legacy := false
var _out := "res://tools/artifacts/spider_gait/current/"
var _hashes: Dictionary = {}
var _sources: Dictionary = {}
var _samples: Array[Dictionary] = []


func _initialize() -> void:
	if not FileAccess.file_exists(DOCUMENT):
		push_error("Spider capture requires the saved pivot document: " + DOCUMENT)
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	_legacy = "legacy" in args
	if not args.is_empty():
		var label := String(args[0]).validate_filename()
		if label.is_empty() or label.begins_with("."):
			push_error("Spider capture: invalid output label")
			quit(1)
			return
		_out = "res://tools/artifacts/spider_gait/" + label + "/"
	_hashes = _protected_hashes()
	_sources = _source_hashes()
	seed(73121)
	root.hide()
	root.size = Vector2i(1280, 720)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(_viewport)
	_lab = Lab.new()
	# auto_drive must start FALSE: otherwise the real lab skips the authoring
	# controller entirely and silently uses default rather than saved anatomy.
	_lab.set("auto_drive", false)
	_lab.set("authoring_enabled", true)
	_lab.set("authoring_path", DOCUMENT)
	_viewport.add_child(_lab)
	DirAccess.make_dir_recursive_absolute(_out + "frames/")
	var ignore := FileAccess.open(_out + ".gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()


func _process(_delta: float) -> bool:
	if _lab == null:
		return true
	if _editor == null:
		_waiting += 1
		if _lab.is_node_ready():
			_editor = _lab.get("_authoring") as Node2D
		if _editor == null or not _editor.is_node_ready():
			_editor = null
			if _waiting > 120:
				push_error("Spider capture: saved-document editor did not initialize")
				quit(1)
				return true
			return false
		if not bool(_editor.get("_has_file")):
			push_error("Spider capture: saved document was not loaded successfully")
			quit(1)
			return true
		_lab.set_physics_process(false)
		_walker = _lab.get("_walker") as Node2D
		_walker.set("spider_gait", not _legacy)
		_editor.call("set_mode", "walk")
		_lab.set("auto_drive", true)
		var view := _lab.get("_view") as Node2D
		view.set_process(false)
		var camera := _lab.get("_cam") as Camera2D
		camera.position_smoothing_enabled = false
		return false
	# Read the previous submitted frame before changing its pose.
	if _frame > 0 and (STILLS.has(_frame) or _is_movie_frame()):
		if not _save():
			quit(1)
			return true
	if _frame >= LAST_FRAME:
		var unchanged := _hashes == _protected_hashes()
		var file := FileAccess.open(_out + "capture_metadata.json", FileAccess.WRITE)
		if file == null:
			quit(1)
			return true
		file.store_string(JSON.stringify({
			"description": "Actual complete lab UI, actual saved user pivots loaded read-only, deterministic walk left/right/run/jump/settle.",
			"document": DOCUMENT, "spider_gait": not _legacy, "protected_files_unchanged": unchanged,
			"protected_sha256_before": _hashes, "protected_sha256_after": _protected_hashes(),
			"source_sha256_before": _sources, "source_sha256_after": _source_hashes(),
			"simulation_hz": 60, "movie_fps": 15, "movie_frames": _movie_frames,
			"movie_seconds": float(_movie_frames) / 15.0, "viewport": [1280, 720], "samples": _samples,
		}, "\t"))
		file.close()
		print("SPIDER CAPTURE: %s; %d frames; protected files unchanged=%s" % [ProjectSettings.globalize_path(_out), _movie_frames, unchanged])
		quit(0 if unchanged else 1)
		return true
	_frame += 1
	_lab.set("auto_dir", -1.0 if _frame > 60 and _frame <= 180 else (1.0 if _frame > 180 and _frame <= 360 else 0.0))
	_lab.set("auto_run", _frame > 300 and _frame <= 360)
	_lab.set("auto_aim", null)
	if _frame == 361:
		_walker.call("jump")
	_lab.call("_physics_process", STEP)
	(_lab.get("_view") as Node2D).call("_process", STEP)
	(_lab.get("_cam") as Camera2D).force_update_scroll()
	RenderingServer.force_draw(false, STEP)
	return false


func _is_movie_frame() -> bool:
	return _frame > 60 and _frame % 4 == 0


func _phase() -> String:
	if _frame <= 60: return "neutral"
	if _frame <= 180: return "left"
	if _frame <= 300: return "right"
	if _frame <= 360: return "run_right"
	if _frame <= 420: return "jump"
	return "settle"


func _save() -> bool:
	var picture := _viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("Spider capture needs a renderer; do not use --headless")
		return false
	if STILLS.has(_frame):
		var filename := String(STILLS[_frame]) + ".png"
		if picture.save_png(_out + filename) != OK:
			return false
		print("  " + filename)
	if _is_movie_frame():
		if picture.save_png(_out + "frames/frame_%04d.png" % _movie_frames) != OK:
			return false
		_movie_frames += 1
	var leg_samples: Array = []
	for leg in _walker.call("pose_legs"):
		var sample: Dictionary = {}
		for key in ["id", "planted", "stepping", "progress", "gait_group", "depth", "space_reachable"]:
			if leg.has(key): sample[key] = leg[key]
		for key in ["mount", "hip", "knee", "ankle", "toe", "contact", "target"]:
			if leg.has(key):
				var point: Vector2 = leg[key]
				sample[key] = [point.x, point.y]
		if leg.has("spatial_points"):
			sample["spatial_points"] = []
			for point: Vector3 in leg["spatial_points"]:
				sample["spatial_points"].append([point.x, point.y, point.z])
			sample["spatial_lengths"] = leg["spatial_lengths"]
		leg_samples.append(sample)
	var pos: Vector2 = _walker.get("body_pos")
	_samples.append({"frame": _frame, "phase": _phase(), "body_pos": [pos.x, pos.y],
		"speed": _walker.get("speed"), "airborne": _walker.get("airborne"), "legs": leg_samples,
		"outside_work_area": _outside_work_area()})
	return true


func _outside_work_area() -> Array[String]:
	var outside: Array[String] = []
	var area: Rect2 = _editor.call("canvas_rect")
	var canvas := _viewport.get_canvas_transform()
	for leg in _walker.call("pose_legs"):
		for key: String in ["mount", "hip", "knee", "ankle", "toe"]:
			if not area.has_point(canvas * _lab.to_global(leg[key])):
				outside.append(String(leg["id"]) + "." + key)
	var body: Dictionary = _walker.call("pose_body")
	for key: String in ["chassis", "pivot", "gun", "barrel", "muzzle", "upper_center"]:
		if body.has(key) and not area.has_point(canvas * _lab.to_global(body[key])):
			outside.append("body." + key)
	return outside


func _protected_hashes() -> Dictionary:
	return {DOCUMENT: FileAccess.get_sha256(DOCUMENT), ART: FileAccess.get_sha256(ART)}


func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCES:
		if FileAccess.file_exists(path): result[path] = FileAccess.get_sha256(path)
	return result
