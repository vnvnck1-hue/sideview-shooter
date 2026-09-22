extends SceneTree
## Capture the complete reference lab, including its real explanations and controls.
## Run without --headless:
## godot --path GodotPrototype --rendering-method gl_compatibility --script res://tools/capture_reference_walker.gd
## Hidden window + SubViewport. Produces six stills and 90 PNG frames (15 fps / 6 s).

const Lab := preload("res://scripts/reference_walker_lab.gd")
const OUT := "res://tools/artifacts/reference_walker/"
const STEP := 1.0 / 60.0
const LAST_FRAME := 420
const FIRST_MOVIE_FRAME := 64
const FRAME_INTERVAL := 4
const STILLS := {
	30: "01_source_reference", 60: "02_bones_neutral",
	120: "03_walk_left", 210: "04_walk_right",
	265: "05_jump", 420: "06_settle",
}

var _viewport: SubViewport
var _lab: Node2D
var _walker: Node2D
var _frame := 0
var _ready_frames := 0
var _movie_frames := 0
var _samples: Array[Dictionary] = []


func _initialize() -> void:
	seed(73021)
	root.hide()
	root.size = Vector2i(1280, 720)
	_viewport = SubViewport.new()
	_viewport.name = "ReferenceWalkerCapture"
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.transparent_bg = false
	root.add_child(_viewport)
	_lab = Lab.new()
	if _lab == null:
		push_error("Reference capture: lab script did not instantiate")
		quit(1)
		return
	_lab.set("auto_drive", true)
	_lab.set("auto_dir", 0.0)
	_lab.set("auto_run", false)
	_lab.set("auto_aim", null)
	_viewport.add_child(_lab)
	DirAccess.make_dir_recursive_absolute(OUT + "frames/")
	var ignore := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()


func _process(_delta: float) -> bool:
	if _lab == null:
		return true
	if _walker == null:
		_ready_frames += 1
		if _lab.is_node_ready():
			_walker = _lab.get("_walker") as Node2D
		if _walker == null:
			if _ready_frames > 60:
				push_error("Reference capture: lab did not initialize its walker")
				quit(1)
				return true
			return false
		_prepare()
		return false

	# Read back the previous submitted frame, before applying the next simulation step.
	# This keeps the stored pose metadata and visible image on the same frame.
	if _frame > 0 and (STILLS.has(_frame) or _is_movie_frame()):
		if not _save():
			quit(1)
			return true
	if _frame >= LAST_FRAME:
		if not _save_metadata():
			quit(1)
			return true
		print("Reference walker capture: %s (%d movie frames at 15 fps)" % [ProjectSettings.globalize_path(OUT), _movie_frames])
		quit(0)
		return true

	_frame += 1
	_direct()
	_lab.call("_physics_process", STEP)
	var view := _lab.get("_view") as Node2D
	if view != null:
		view.call("_process", STEP)
	var camera := _lab.get("_cam") as Camera2D
	if camera != null:
		camera.force_update_scroll()
	RenderingServer.force_draw(false, STEP)
	return false


func _prepare() -> void:
	_lab.set_physics_process(false)
	var view := _lab.get("_view") as Node2D
	if view != null:
		view.set_process(false)
	var camera := _lab.get("_cam") as Camera2D
	if camera != null:
		camera.position_smoothing_enabled = false
	_lab.call("set_reference_mode", true)
	# No UI layers are hidden or replaced: every image shows the actual reference lab.


func _direct() -> void:
	_lab.set("auto_dir", 0.0)
	_lab.set("auto_run", false)
	_lab.set("auto_aim", null)
	if _frame == 31:
		_lab.call("set_reference_mode", false)
	if _frame > 60 and _frame <= 150:
		_lab.set("auto_dir", -1.0)
	elif _frame > 150 and _frame <= 240:
		_lab.set("auto_dir", 1.0)
	elif _frame == 241:
		_walker.call("jump")
	elif _frame > 300 and _frame <= 360:
		_lab.set("auto_dir", -1.0)
		_lab.set("auto_run", true)


func _is_movie_frame() -> bool:
	return _frame >= FIRST_MOVIE_FRAME and _frame <= LAST_FRAME and _frame % FRAME_INTERVAL == 0


func _phase() -> String:
	if _frame <= 30:
		return "source_reference"
	if _frame <= 60:
		return "bones_neutral"
	if _frame <= 150:
		return "walk_left"
	if _frame <= 240:
		return "walk_right"
	if _frame <= 300:
		return "jump_and_land"
	if _frame <= 360:
		return "run_left"
	return "settle"


func _save() -> bool:
	var picture := _viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("Reference capture: empty texture; run with a renderer, without --headless")
		return false
	if STILLS.has(_frame):
		var name := String(STILLS[_frame]) + ".png"
		if picture.save_png(OUT + name) != OK:
			push_error("Reference capture: cannot save " + name)
			return false
		print("  " + name)
	if _is_movie_frame():
		var filename := "frames/frame_%04d.png" % _movie_frames
		if picture.save_png(OUT + filename) != OK:
			push_error("Reference capture: cannot save " + filename)
			return false
		_movie_frames += 1
	_samples.append(_sample_pose())
	return true


func _sample_pose() -> Dictionary:
	var legs: Array = _walker.call("pose_legs")
	var captured_legs: Array[Dictionary] = []
	for leg in legs:
		var captured := {
			"id": leg["id"], "far": leg.get("far", false), "inferred": leg.get("inferred", false),
			"upper_length": leg["upper_length"], "lower_length": leg["lower_length"], "foot_length": leg["foot_length"],
			"planted": leg.get("planted", false), "progress": leg.get("progress", 0.0),
		}
		for key in ["mount", "hip", "knee", "ankle", "toe", "target"]:
			if leg.has(key):
				var point: Vector2 = leg[key]
				captured[key] = [point.x, point.y]
		captured_legs.append(captured)
	var body: Dictionary = _walker.call("pose_body")
	var captured_body := {}
	for key in body.keys():
		if body[key] is Vector2:
			var point: Vector2 = body[key]
			captured_body[key] = [point.x, point.y]
	var position: Vector2 = _walker.get("body_pos")
	return {
		"frame": _frame, "phase": _phase(), "speed": _walker.get("speed"),
		"airborne": _walker.get("airborne"), "source_rest": _walker.get("source_rest"),
		"body_pos": [position.x, position.y], "body": captured_body, "legs": captured_legs,
	}


func _save_metadata() -> bool:
	var output := FileAccess.open(OUT + "capture_metadata.json", FileAccess.WRITE)
	if output == null:
		push_error("Reference capture: cannot save metadata")
		return false
	var sources := {}
	for path in ["res://scripts/reference_walker.gd", "res://scripts/reference_walker_view.gd",
			"res://scripts/reference_walker_lab.gd", "res://scripts/walker_anatomy.gd"]:
		sources[path] = FileAccess.get_sha256(path)
	output.store_string(JSON.stringify({
		"description": "Complete actual reference-walker lab capture; includes its real UI and structure legend.",
		"simulation_hz": 60, "movie_fps": 15, "movie_frames": _movie_frames,
		"movie_duration_seconds": float(_movie_frames) / 15.0,
		"viewport": [1280, 720], "source_sha256": sources, "samples": _samples,
	}, "\t"))
	output.close()
	return true
