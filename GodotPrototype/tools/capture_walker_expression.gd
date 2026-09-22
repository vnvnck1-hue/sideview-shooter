extends SceneTree
## Deterministic visual review of the production lab and its actual rig.
## Run with a renderer (not --headless):
## godot --path GodotPrototype --rendering-method gl_compatibility --script res://tools/capture_walker_expression.gd -- frames
## The root window stays hidden; an always-updating SubViewport renders the lab.
## Stills, optional 15 fps PNG frames and motion metadata go to res://tools/artifacts/walker_expression/.

const Lab := preload("res://scripts/walker_lab.gd")
const OUT := "res://tools/artifacts/walker_expression/"
const STEP := 1.0 / 60.0
const LAST_FRAME := 660
const EVERY := 4
const STILLS := {
	75: "01_idle", 145: "02_forward_fire", 225: "03_backpedal_fire",
	315: "04_reverse_aim", 405: "05_aim_sweep", 475: "06_jump",
	525: "07_landing", 645: "08_settle",
}

var _viewport: SubViewport
var _lab: Node2D
var _walker: ProcWalker
var _caption: Label
var _detail: Label
var _frame := 0
var _ready_frames := 0
var _frames := false
var _notes: Array[Dictionary] = []
var _shots := 0


func _initialize() -> void:
	seed(2086)
	_frames = "frames" in OS.get_cmdline_user_args()
	root.hide()
	root.size = Vector2i(1280, 720)
	_viewport = SubViewport.new()
	_viewport.name = "WalkerCapture"
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.transparent_bg = false
	root.add_child(_viewport)
	_lab = Lab.new()
	_lab.auto_drive = true
	_lab.auto_dir = 0.0
	_viewport.add_child(_lab)
	DirAccess.make_dir_recursive_absolute(OUT)
	# Captures are review artifacts, not game textures; keep Godot from importing every frame.
	var ignore := FileAccess.open("res://tools/artifacts/.gdignore", FileAccess.WRITE)
	if ignore != null:
		ignore.close()
	if _frames:
		DirAccess.make_dir_recursive_absolute(OUT + "frames/")


func _process(_delta: float) -> bool:
	if _walker == null:
		_ready_frames += 1
		if not _lab.is_node_ready():
			return false
		_walker = _lab._walker
		if _walker == null:
			if _ready_frames > 10:
				push_error("WalkerCapture: lab did not initialize")
				quit(1)
				return true
			return false
		_prepare()
		return false

	# Read on the next process iteration, after CanvasItem redraws were submitted.
	# Reading immediately after tick() captures the previous image with new metadata.
	if _frame > 0 and (STILLS.has(_frame) or (_frames and _frame % EVERY == 0)):
		if not _save():
			quit(1)
			return true
	if _frame >= LAST_FRAME:
		var metadata := FileAccess.open(OUT + "motion.json", FileAccess.WRITE)
		metadata.store_string(JSON.stringify({
			"simulation_fps": 60, "capture_fps": 15, "frames": LAST_FRAME,
			"fired": _shots, "samples": _notes,
		}, "\t"))
		metadata.close()
		print("Walker expression capture: %s (%d shots)" % [ProjectSettings.globalize_path(OUT), _shots])
		quit(0)
		return true
	_frame += 1
	_direct()
	_lab._physics_process(STEP)
	# Camera and rig use the same solved pose on this exact simulation frame.
	_lab._cam.position = _walker.body_pos + Vector2(0.0, -24.0)
	_lab._cam.force_update_scroll()
	_lab._rig._process(STEP)
	_lab._blast._process(STEP)
	_detail.text = "MOVE %+.0f px/s    AIM %+.0f°    LOWER BODY %s    FRAME %03d" % [
		_walker.speed, rad_to_deg(_walker.aim_dir().angle()),
		"RIGHT" if _walker.facing > 0 else "LEFT", _frame,
	]
	# Hidden OS windows skip their own draw; the SubViewport is rendered explicitly.
	RenderingServer.force_draw(false, STEP)
	return false


func _prepare() -> void:
	_lab.set_physics_process(false)
	_lab._rig.set_process(false)
	_lab._blast.set_process(false)
	_lab._show_debug = false
	_lab._debug.hide()
	for child in _lab.get_children():
		if child is CanvasLayer and child.layer >= 0:
			child.hide()
	_lab._cam.position_smoothing_enabled = false
	_lab._cam.zoom = Vector2(1.30, 1.30)
	_walker.body_pos.x = -2200.0
	_walker.reset_stance()
	_walker.fired.connect(func(_m: Vector2, _d: Vector2): _shots += 1)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	_lab.add_child(overlay)
	var backing := ColorRect.new()
	backing.position = Vector2(24, 22)
	backing.size = Vector2(1232, 92)
	backing.color = Color(0.08, 0.08, 0.14, 0.88)
	overlay.add_child(backing)
	_caption = Label.new()
	_caption.position = Vector2(42, 33)
	_caption.add_theme_font_size_override("font_size", 25)
	_caption.add_theme_color_override("font_color", Color(0.91, 0.91, 1.0))
	overlay.add_child(_caption)
	_detail = Label.new()
	_detail.position = Vector2(42, 74)
	_detail.add_theme_font_size_override("font_size", 17)
	_detail.add_theme_color_override("font_color", Color(0.71, 0.75, 0.87))
	overlay.add_child(_detail)


func _direct() -> void:
	_lab.auto_dir = 0.0
	_walker.firing = false
	var direction := Vector2(1.0, -0.18).normalized()
	if _frame < 90:
		_caption.text = "01 / IDLE — soft breathing and balanced weight"
	elif _frame < 180:
		_caption.text = "02 / FORWARD — acceleration, planted feet and recoil"
		_lab.auto_dir = 1.0
		_walker.firing = _frame >= 120
	elif _frame < 270:
		_caption.text = "03 / BACKPEDAL — move left while firing right"
		_lab.auto_dir = -1.0
		_walker.firing = true
	elif _frame < 360:
		_caption.text = "04 / REVERSE AIM — move right while firing left"
		_lab.auto_dir = 1.0
		direction = Vector2(-1.0, -0.12).normalized()
		_walker.firing = true
	elif _frame < 450:
		_caption.text = "05 / FREE AIM — upper body rotates above planted legs"
		var phase := float(_frame - 360) / 90.0
		direction = Vector2.LEFT.rotated(TAU * phase)
	elif _frame < 570:
		_caption.text = "06 / JUMP & LAND — preparation, stretch and soft recovery"
		if _frame == 450:
			_walker.jump()
	else:
		_caption.text = "07 / SETTLE — overlapping motion returns to rest"
	_lab.auto_aim = _walker.body_pos + direction * 900.0


func _save() -> bool:
	var picture := _viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("WalkerCapture: renderer returned no image; run without --headless")
		return false
	if STILLS.has(_frame):
		var filename := String(STILLS[_frame]) + ".png"
		if picture.save_png(OUT + filename) != OK:
			push_error("WalkerCapture: failed to write " + filename)
			return false
		print("  " + filename)
	if _frames and _frame % EVERY == 0:
		picture.save_png(OUT + "frames/frame_%04d.png" % (_frame / EVERY - 1))
	_notes.append({
		"frame": _frame, "speed": _walker.speed, "facing": _walker.facing,
		"yaw": _walker.yaw, "aim_degrees": rad_to_deg(_walker.aim_dir().angle()),
		"airborne": _walker.airborne, "body": [_walker.body_pos.x, _walker.body_pos.y],
	})
	return true
