extends SceneTree
## Shared settings -> preview ProcWalker and real WalkerUnit input integration.
## Only these disposable user:// files are written; production documents are read-only.
const Walker = preload("res://scripts/proc_walker.gd")
const Unit = preload("res://scripts/walker_unit.gd")
const Settings = preload("res://scripts/walker_gait_settings.gd")
const PATH := "user://walker_tuning_runtime_validation.json"
const MISSING := "user://walker_tuning_runtime_missing.json"
const CORRUPT := "user://walker_tuning_runtime_corrupt.json"
const SOURCE := "res://authoring/walker_motion.json"
const POINTS := ["mount", "hip", "knee", "ankle", "toe"]
const DT := 1.0 / 60.0

var checks := 0
var failures: Array[String] = []
var worst_pose := 0.0
var worst_length := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for action in ["move_left", "move_right", "run", "shoot", "roll"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var source_hash := FileAccess.get_sha256(SOURCE)
	var production_exists := FileAccess.file_exists(Settings.DEFAULT_PATH)
	var production_hash := FileAccess.get_sha256(Settings.DEFAULT_PATH) if production_exists else ""
	_cleanup()
	var document := Settings.new()
	var defaults: Dictionary = document.values.duplicate(true)
	var default_walker := _preview(MISSING)
	_check(default_walker.tuning_path == MISSING, "injected settings path is retained")
	_check(not FileAccess.file_exists(MISSING), "missing settings never create a production or default file")
	for key in defaults:
		_check(default_walker.tune[key] == defaults[key], "missing file uses default " + key)
	_check(default_walker.spider_gait and default_walker._spider != null, "initialization selects shared spider solver")
	_check(default_walker._spider.loaded_path == SOURCE, "saved anatomy remains independently loaded")
	_default_equivalence(default_walker, defaults)
	default_walker.free()

	var values := defaults.duplicate(true)
	values.merge({"speed": 290.0, "ride": 206.0, "stride": 0.975, "lift": 34.0,
		"step_time": 0.21, "run_step_time": 0.16, "hold": 0.025, "lead": 0.17,
		"coxa_yaw_bias": 9.0, "coxa_pitch_bias": 3.0, "knee_swivel": 12.0}, true)
	document.values = values.duplicate(true)
	_check(document.save(PATH) == OK, "custom settings save into disposable test path")
	var preview := _preview(PATH)
	var unit := _unit(PATH)
	for key in values:
		_check(preview.tune[key] == values[key], "preview loads saved " + key)
		_check(unit._tune[key] == values[key], "real unit loads saved " + key)
	_check(unit._walker.tune.ride == Unit.SLEEP_RIDE, "unit initially crouches independently of saved standing ride")
	_check(unit._tune.ride == values.ride, "standing ride remains saved while asleep")
	_ready_unit(unit, values)
	preview.body_pos = unit._walker.body_pos
	preview.reset_stance()
	var shots: Array = []
	unit.shoot_fired.connect(func(muzzle, target): shots.append([muzzle, target]))
	var start_x: float = unit.position.x
	var forward_x := 0.0
	var peak_heat := 0.0
	for frame in 540:
		var direction := 1.0 if frame < 240 else (-1.0 if frame < 420 else 0.0)
		var run_now := frame >= 120 and frame < 240
		var shoot_now := frame >= 300 and frame < 390
		_input(direction, run_now, shoot_now)
		unit.aim_target = Vector2(unit.position.x + 520.0, unit.floor_y - 150.0)
		preview.input_dir = direction
		preview.running = run_now
		preview.firing = shoot_now and not unit.overheated
		preview.aim_target = unit._scaler.global_transform.affine_inverse() * unit.aim_target
		unit._process(DT)
		peak_heat = maxf(peak_heat, unit.heat)
		preview.tick(DT)
		_compare(unit._walker, preview, "saved input frame %d" % frame)
		_check(is_equal_approx(unit._walker.tune.ride, values.ride), "power animation preserves saved standing target")
		if frame == 239:
			forward_x = unit.position.x
	_check(forward_x > start_x + 100, "actual controlled unit walks and runs forward")
	_check(unit.position.x < forward_x - 100, "actual controlled unit backpedals while aiming forward")
	_check(shots.size() >= 5 and peak_heat > 0.0, "real input fires signals and heats barrel")
	for shot in shots:
		_check((shot[0] as Vector2).is_finite() and (shot[1] as Vector2).is_finite(), "shot positions remain finite")
	_input(0.0, false, false)
	_live_atomic(preview, unit, values)
	_power_cycle(unit)
	preview.free()
	unit.free()
	_body_parameters()

	document.values["speed"] = 325.0
	document.values["ride"] = 214.0
	_check(document.save(PATH) == OK, "second save updates shared file")
	var reloaded := _unit(PATH)
	_check(reloaded._tune.speed == 325.0 and reloaded._tune.ride == 214.0, "new real unit reloads latest saved values")
	_check(reloaded.tuning_path == PATH and reloaded.tuning_load_error == OK, "unit exposes configured path and successful load status")
	reloaded.free()

	var bad_file := FileAccess.open(CORRUPT, FileAccess.WRITE)
	bad_file.store_string("{broken-json")
	bad_file.close()
	var broken := Walker.new()
	_check(broken.initialize_spider_tuning(CORRUPT) != OK, "corrupt settings report load error")
	_check(not broken.tuning_error.is_empty(), "corrupt settings expose useful load error")
	for key in defaults:
		_check(broken.tune[key] == defaults[key], "corrupt file safely falls back to default " + key)
	broken.free()
	var legacy := Walker.new()
	_check(not legacy.spider_gait and legacy._spider == null and legacy.tune == Walker.DEFAULTS, "legacy presets remain opt-in and unchanged")
	legacy.free()
	_check(FileAccess.get_sha256(SOURCE) == source_hash, "saved original anatomy remains byte-for-byte unchanged")
	_check(FileAccess.file_exists(Settings.DEFAULT_PATH) == production_exists, "production settings existence remains unchanged")
	if production_exists:
		_check(FileAccess.get_sha256(Settings.DEFAULT_PATH) == production_hash, "production settings remain byte-for-byte unchanged")
	_cleanup()
	print("Walker tuning runtime: %d checks, pose mismatch max %.6f px, fixed-length error max %.6f px, failures %d" % [checks, worst_pose, worst_length, failures.size()])
	for message in failures.slice(0, 30):
		push_error(message)
	quit(0 if failures.is_empty() else 1)


func _preview(path: String) -> Node2D:
	var walker := Walker.new()
	walker.draw_greybox = false
	walker.ground_at = func(_x): return 640.0
	_check(walker.initialize_spider_tuning(path) == OK, "preview initialization " + path)
	walker.body_pos = Vector2(1000.0, 640.0 - float(walker.tune.ride))
	root.add_child(walker)
	return walker


func _unit(path: String) -> Node2D:
	var unit := Unit.new()
	unit.tuning_path = path
	unit.setup(500.0, 320.0, null)
	unit.set_process(false)
	root.add_child(unit)
	return unit


func _ready_unit(unit: Node2D, values: Dictionary) -> void:
	unit.state = Unit.State.READY
	unit._power = 1.0
	unit.set_controlled(true)
	unit._tick_power(0.0)
	unit._walker.body_pos = Vector2(1000.0, 640.0 - float(values.ride))
	unit._walker.reset_stance()
	unit._sync_node()


func _default_equivalence(loaded: Node2D, values: Dictionary) -> void:
	var explicit := Walker.new()
	explicit.spider_gait = true
	explicit.draw_greybox = false
	explicit.ground_at = loaded.ground_at
	explicit.tune.merge(values, true)
	explicit.body_pos = loaded.body_pos
	root.add_child(explicit)
	for frame in 180:
		for walker in [loaded, explicit]:
			walker.input_dir = 1.0 if frame < 120 else -1.0
			walker.running = frame >= 60 and frame < 120
			walker.aim_target = walker.body_pos + Vector2(-400, -70)
			walker.tick(DT)
		_compare(loaded, explicit, "default initialization frame %d" % frame)
	explicit.free()


func _compare(a: Node2D, b: Node2D, label: String) -> void:
	worst_pose = maxf(worst_pose, a.body_pos.distance_to(b.body_pos))
	_check(a.body_pos.distance_to(b.body_pos) < .002, label + " body trajectory")
	_check(absf(a._turret - b._turret) < .00001, label + " aim trajectory")
	for i in 4:
		var left: Dictionary = a.legs()[i]
		var right: Dictionary = b.legs()[i]
		_check(left.id == right.id and left.stepping == right.stepping, label + " step schedule " + left.id)
		for part in POINTS:
			var distance: float = (left.pose[part] as Vector2).distance_to(right.pose[part])
			worst_pose = maxf(worst_pose, distance)
			_check(distance < .003, label + " joint " + left.id + "." + part)
		for segment in 4:
			var error: float = absf((left.pose.spatial_points[segment] as Vector3).distance_to(left.pose.spatial_points[segment + 1]) - float(left.state.lengths[segment]))
			worst_length = maxf(worst_length, error)
			_check(error < .003, label + " fixed bone length " + left.id)


func _live_atomic(walker: Node2D, unit: Node2D, values: Dictionary) -> void:
	var before: Dictionary = walker.tune.duplicate(true)
	for invalid in [{}, {"speed": 200.0}, {"not-a-setting": 4.0}]:
		_check(not walker.apply_spider_tuning(invalid), "incomplete or unknown settings rejected")
		_check(walker.tune == before, "rejected settings do not partially mutate runtime")
	for key_value in [["speed", NAN], ["ride", 500.0], ["legs_up", 1.5]]:
		var invalid := values.duplicate(true)
		invalid[key_value[0]] = key_value[1]
		_check(not walker.apply_spider_tuning(invalid), "invalid value rejected " + key_value[0])
		_check(walker.tune == before, "invalid value remains atomic " + key_value[0])
	walker.input_dir = 1.0
	for frame in 12:
		walker.tick(DT)
	var adapter_id: int = walker._spider.get_instance_id()
	var body: Vector2 = walker.body_pos
	var saved := []
	for leg in walker.legs():
		saved.append({"foot": leg.foot, "t": leg.t, "stepping": leg.stepping, "lengths": leg.state.lengths.duplicate()})
	var next := values.duplicate(true)
	next.merge({"ride": 210.0, "speed": 300.0, "lift": 39.0, "step_time": 0.25,
		"coxa_yaw_bias": 14.0, "coxa_pitch_bias": 4.0, "knee_swivel": 18.0}, true)
	_check(walker.apply_spider_tuning(next), "valid live settings apply")
	_check(walker.body_pos == body and walker._spider.get_instance_id() == adapter_id, "live apply preserves body and adapter instance")
	for i in 4:
		var leg: Dictionary = walker.legs()[i]
		_check(leg.foot == saved[i].foot and leg.t == saved[i].t and leg.stepping == saved[i].stepping, "live apply preserves contact and step progress " + leg.id)
		_check(leg.state.lengths == saved[i].lengths, "live apply preserves source bone lengths " + leg.id)
		_check(leg.state.config.knee_swivel == 18.0 and leg.state.config.coxa_yaw_bias == 14.0, "paused pose immediately receives joint settings " + leg.id)
	walker.tick(DT)
	for leg in walker.legs():
		_check(leg.state.config.knee_swivel == 18.0 and leg.state.config.coxa_yaw_bias == 14.0, "joint solver receives live tuning " + leg.id)
	_check(unit.apply_spider_tuning(next), "real unit accepts live settings")
	_check(unit._tune.ride == 210.0, "real unit saves live standing target")
	unit._tick_power(DT)
	_check(unit._walker.tune.ride == 210.0, "real unit power tick does not restore stale ride")


func _power_cycle(unit: Node2D) -> void:
	var target: float = unit._tune.ride
	unit.set_controlled(false)
	unit.state = Unit.State.SLEEPING
	for frame in 100:
		unit._process(DT)
	_check(unit.state == Unit.State.DORMANT and unit._walker.tune.ride == Unit.SLEEP_RIDE, "real unit sleeps normally")
	_check(unit._tune.ride == target, "sleep preserves configured standing height")
	unit.activate()
	for frame in 100:
		unit._process(DT)
	_check(unit.state == Unit.State.READY and unit.controlled, "real unit wakes and restores control")
	_check(unit._tune.ride == target and unit._walker.tune.ride == target, "wake restores the configured standing height")


func _input(direction: float, run_now: bool, shoot_now: bool) -> void:
	for action in ["move_left", "move_right", "run", "shoot"]:
		Input.action_release(action)
	if direction > 0.0:
		Input.action_press("move_right")
	elif direction < 0.0:
		Input.action_press("move_left")
	if run_now:
		Input.action_press("run")
	if shoot_now:
		Input.action_press("shoot")


func _body_parameters() -> void:
	for parameter in ["speed", "ride", "tilt", "bob", "aim_lean"]:
		var base: Dictionary = Settings.defaults()
		base.merge({"speed": 240.0, "ride": 205.0, "bob": 0.0, "aim_lean": 0.0}, true)
		var changed := base.duplicate(true)
		changed[parameter] = {"speed": 110.0, "ride": 215.0, "tilt": 0.8, "bob": 12.0, "aim_lean": 0.7}[parameter]
		var a := _preview(MISSING)
		var b := _preview(MISSING)
		for walker in [a, b]:
			walker.apply_spider_tuning(base if walker == a else changed)
			if parameter == "tilt":
				walker.ground_at = func(x): return 640.0 + (x - 1000.0) * 0.06
			walker.body_pos = Vector2(1000.0, 435.0)
			walker.reset_stance()
		var response := 0.0
		for frame in 240:
			for walker in [a, b]:
				walker.input_dir = 1.0 if parameter in ["speed", "bob"] else 0.0
				walker.aim_target = walker.body_pos + Vector2(400, -350)
				walker.tick(DT)
			if parameter == "speed":
				response = maxf(response, absf(a.body_pos.x - b.body_pos.x))
			elif parameter in ["ride", "bob"]:
				response = maxf(response, absf(a.body_pos.y - b.body_pos.y))
			else:
				response = maxf(response, absf(a._angle - b._angle))
		_check(response > (1.0 if parameter == "speed" else (0.01 if parameter in ["ride", "bob"] else 0.0001)), "body parameter has measurable physical effect: " + parameter)
		print("Body tuning %s response %.6f" % [parameter, response])
		a.free()
		b.free()


func _cleanup() -> void:
	for path in [PATH, PATH + ".bak", MISSING, CORRUPT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value and not failures.has(message):
		failures.append(message)
