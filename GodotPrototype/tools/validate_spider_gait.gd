extends SceneTree
## Runtime contracts for the spatial gait, using default AND saved user anatomy.
## Does not write the source art or authoring document.
## godot --headless --path GodotPrototype --script res://tools/validate_spider_gait.gd

const Walker = preload("res://scripts/reference_walker.gd")
const Data = preload("res://scripts/walker_authoring_data.gd")
const Anatomy = preload("res://scripts/walker_anatomy.gd")
const Lab = preload("res://scripts/reference_walker_lab.gd")
const DOCUMENT := "res://authoring/walker_motion.json"
const OUT := "res://tools/artifacts/spider_gait/validation.json"
const POINTS := ["mount", "hip", "knee", "ankle", "toe"]
const EPS := 0.025

var _failures: Dictionary = {}
var _checks := 0
var _case := "setup"
var _step := 0
var _container: Node2D
var _lengths: Dictionary = {}
var _last_pair := -1
var _pair_starts := 0
var _maximum_length_error := 0.0
var _maximum_bone_error := 0.0
var _maximum_stance_slip := 0.0
var _maximum_joint_speed := 0.0
var _maximum_joint_sample: Dictionary = {}
var _maximum_joint_speed_by_case: Dictionary = {}
var _maximum_landing_step := 0.0
var _maximum_landing_sample: Dictionary = {}
var _minimum_support := 4
var _travel: Array[Dictionary] = []
var _protected: Dictionary = {}
var _source_sha256: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_protected = _protected_hashes()
	_source_sha256 = _source_hashes()
	var saved := Data.new()
	_require(saved.load_file(DOCUMENT) == OK, "saved_document", saved.last_error)
	if not _failures.is_empty():
		_finish()
		return
	var defaults := Data.new()
	if "step60" in OS.get_cmdline_user_args():
		_motion("default", defaults.points, 60, "step", func(x: float) -> float: return 628.0 if x >= 80.0 else 640.0)
		_finish()
		return
	if "course60" in OS.get_cmdline_user_args():
		_real_course("default", defaults.points)
		_real_course("saved", saved.points)
		_finish()
		return
	for config in [["default", defaults.points], ["saved", saved.points]]:
		_source_pose(String(config[0]), config[1])
		for hz in [30, 60, 120]:
			if "quick" in OS.get_cmdline_user_args() and hz != 60:
				continue
			if "diagnose120" in OS.get_cmdline_user_args() and hz != 120:
				continue
			_stationary(String(config[0]), config[1], hz)
			_motion(String(config[0]), config[1], hz, "flat", func(_x: float) -> float: return 640.0)
			if not "quick" in OS.get_cmdline_user_args():
				_motion(String(config[0]), config[1], hz, "slope", func(x: float) -> float: return 640.0 - clampf(x, -1000.0, 1500.0) * 0.07)
				_motion(String(config[0]), config[1], hz, "step", func(x: float) -> float: return 628.0 if x >= 80.0 else 640.0)
			_jump(String(config[0]), config[1], hz)
			_aim(String(config[0]), config[1], hz)
		if not "quick" in OS.get_cmdline_user_args() and not "diagnose120" in OS.get_cmdline_user_args():
			_real_course(String(config[0]), config[1])
	_case = "protected_files"
	_require(_protected == _protected_hashes(), "unchanged", "artwork or saved authoring document changed during validation")
	_finish()


func _finish() -> void:
	print("SPIDER GAIT: %d checks; 3D length max %.5f; Bone2D endpoint max %.5f; stance slip max %.5f; minimum support %d; joint speed max %.1f px/s" % [
		_checks, _maximum_length_error, _maximum_bone_error, _maximum_stance_slip, _minimum_support, _maximum_joint_speed])
	for key in _failures:
		print("FAIL ", key, ": ", _failures[key])
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": _checks, "passed": _failures.is_empty(), "failures": _failures,
			"maximum_spatial_length_error": _maximum_length_error, "maximum_bone_endpoint_error": _maximum_bone_error,
			"maximum_stance_slip": _maximum_stance_slip, "minimum_ground_support": _minimum_support,
			"maximum_joint_speed": _maximum_joint_speed, "travel": _travel,
			"maximum_joint_sample": _maximum_joint_sample,
			"maximum_joint_speed_by_case": _maximum_joint_speed_by_case,
			"maximum_landing_step": _maximum_landing_step, "maximum_landing_sample": _maximum_landing_sample,
			"protected_sha256_before": _protected, "protected_sha256_after": _protected_hashes(),
			"source_sha256_before": _source_sha256, "source_sha256_after": _source_hashes()}, "\t"))
		file.close()
	print("PASS" if _failures.is_empty() else "FAILED: %d distinct case/contracts" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _protected_hashes() -> Dictionary:
	return {DOCUMENT: FileAccess.get_sha256(DOCUMENT), Anatomy.SOURCE_PATH: FileAccess.get_sha256(Anatomy.SOURCE_PATH)}


func _source_hashes() -> Dictionary:
	return {"res://scripts/reference_walker.gd": FileAccess.get_sha256("res://scripts/reference_walker.gd"),
		"res://scripts/spider_leg_ik.gd": FileAccess.get_sha256("res://scripts/spider_leg_ik.gd")}


func _require(ok: bool, contract: String, detail: String) -> void:
	_checks += 1
	var key := _case + "/" + contract
	if not ok and not _failures.has(key):
		_failures[key] = "tick %d: %s" % [_step, detail]


func _new_walker(points: Dictionary, ground: Callable, source := false):
	_container = Node2D.new()
	_container.position = Vector2(33, -48)
	_container.scale = Vector2(0.7, 0.7)
	_container.rotation = 0.13
	root.add_child(_container)
	var walker = Walker.new(points)
	walker.spider_gait = true
	walker.source_rest = source
	walker.body_pos = Vector2(-180, 315)
	walker.ground_at = ground
	_container.add_child(walker)
	_lengths.clear()
	_last_pair = -1
	_pair_starts = 0
	for leg in walker.pose_legs():
		if leg.has("spatial_lengths"):
			_lengths[leg["id"]] = (leg["spatial_lengths"] as Array).duplicate()
	return walker


func _source_pose(label: String, points: Dictionary) -> void:
	_case = label + "/source_rest"
	_step = 0
	var walker = _new_walker(points, func(_x: float) -> float: return 640.0, true)
	walker.input_dir = 1.0
	walker.aim_target = Vector2(900, -100)
	walker.tick(1.0 / 60.0)
	for leg in walker.pose_legs():
		for key: String in POINTS:
			var wanted: Vector2 = walker.body_pos + Anatomy.local_point(points[String(leg["id"]) + "." + key])
			_require((leg[key] as Vector2).distance_to(wanted) < EPS, "point_" + String(leg["id"]) + "_" + key, "source mode altered raw pivot")
	_require(walker.speed == 0.0 and not walker.airborne, "source_frozen", "source mode reacted to locomotion")
	_bones(walker)
	_container.free()


func _snapshot(walker) -> Dictionary:
	var result: Dictionary = {}
	for leg in walker.pose_legs():
		result[leg["id"]] = leg.duplicate(true)
	return result


func _pose(walker) -> void:
	for leg in walker.pose_legs():
		var id := String(leg["id"])
		_require(leg.has("spatial_points") and leg.has("spatial_lengths"), "spatial_api_" + id, "missing 3D points/lengths")
		if not leg.has("spatial_points") or not leg.has("spatial_lengths"):
			continue
		var points: Array = leg["spatial_points"]
		var lengths: Array = leg["spatial_lengths"]
		_require(points.size() == 5 and lengths.size() == 4, "spatial_count_" + id, "expected five joints/four rigid segments")
		if points.size() != 5 or lengths.size() != 4:
			continue
		# The ankle and toe share a depth plane. Placing the stance on a common
		# floor must not stretch the user's authored foot bone during setup.
		var authored_foot: float = (leg["ref_ankle"] as Vector2).distance_to(leg["ref_toe"])
		_require(absf(float(lengths[3]) - authored_foot) < EPS, "authored_foot_" + id,
			"spatial foot %.6f differs from authored %.6f" % [float(lengths[3]), authored_foot])
		if not _lengths.has(id): _lengths[id] = lengths.duplicate()
		for i in range(4):
			var a: Vector3 = points[i]
			var b: Vector3 = points[i + 1]
			var expected := float(_lengths[id][i])
			var error := absf(a.distance_to(b) - expected)
			_maximum_length_error = maxf(_maximum_length_error, error)
			_require(a.is_finite() and b.is_finite() and expected > 0.0 and error < EPS,
				"spatial_length_" + id + "_" + str(i), "3D length error %.6f (actual %.6f, fixed %.6f)" % [error, a.distance_to(b), expected])
			_require(absf(float(lengths[i]) - expected) < 0.0001, "length_metadata_" + id + "_" + str(i), "runtime changed rigid length")
		for key: String in POINTS:
			_require((leg[key] as Vector2).is_finite(), "finite_" + id + "_" + key, "nonfinite projected joint")
		if bool(leg["planted"]):
			_require(bool(leg.get("space_reachable", false)), "reachable_" + id, "planted contact exceeds spatial limb reach")


func _bones(walker) -> void:
	for leg in walker.pose_legs():
		var bone: Bone2D = walker.skeleton.get_node("Chassis/" + String(leg["id"]) + "_Mount")
		for i in range(4):
			var start: Vector2 = _container.to_global(leg[POINTS[i]])
			var end: Vector2 = _container.to_global(leg[POINTS[i + 1]])
			var error := maxf(bone.global_position.distance_to(start), bone.to_global(Vector2(bone.length, 0)).distance_to(end))
			_maximum_bone_error = maxf(_maximum_bone_error, error)
			_require(error < EPS, "bone_" + String(leg["id"]) + "_" + str(i), "rendered Bone2D endpoint differs from projected joint by %.6f" % error)
			if i < 3: bone = bone.get_node(["Upper", "Lower", "Foot"][i])
	var barrel: Bone2D = walker.skeleton.get_node("Chassis/UpperAssembly/GunPivot/Barrel")
	_require(barrel.to_global(Vector2(barrel.length, 0)).distance_to(_container.to_global(walker.muzzle())) < EPS,
		"barrel_endpoint", "actual barrel endpoint differs from muzzle")


func _tick(walker, hz: int) -> void:
	_step += 1
	var before := _snapshot(walker)
	var was_air: bool = walker.airborne
	var previous_body: Vector2 = walker.body_pos
	var previous_angle: float = walker.body_angle
	walker.tick(1.0 / float(hz))
	_pose(walker)
	_bones(walker)
	var support := 0
	var groups: Dictionary = {}
	var starts: Dictionary = {}
	var swinging: Array[String] = []
	for leg in walker.pose_legs():
		var id := String(leg["id"])
		var old: Dictionary = before[id]
		var toe: Vector2 = leg["toe"]
		for key: String in POINTS:
			var joint_speed: float = (leg[key] as Vector2).distance_to(old[key]) * hz
			_maximum_joint_speed_by_case[_case] = maxf(float(_maximum_joint_speed_by_case.get(_case, 0.0)), joint_speed)
			if joint_speed > _maximum_joint_speed:
				_maximum_joint_speed = joint_speed
				var previous: Vector2 = old[key]
				var current: Vector2 = leg[key]
				_maximum_joint_sample = {"case": _case, "tick": _step, "hz": hz, "joint": id + "." + key,
					"previous": [previous.x, previous.y], "current": [current.x, current.y],
					"was_airborne": was_air, "airborne": walker.airborne,
					"was_stepping": old["stepping"], "stepping": leg["stepping"],
					"before_input": _json_value({"body_pos": previous_body, "body_angle": previous_angle,
						"contact": old["contact"], "progress": old["progress"], "stepping": old["stepping"]}),
					"after_input": _json_value({"body_pos": walker.body_pos, "body_angle": walker.body_angle,
						"contact": leg["contact"], "progress": leg["progress"], "stepping": leg["stepping"]}),
					"spatial_state": _json_value(leg.get("spatial", {}))}
			if was_air and not walker.airborne and joint_speed / hz > _maximum_landing_step:
				_maximum_landing_step = joint_speed / hz
				_maximum_landing_sample = {"case": _case, "tick": _step, "hz": hz, "joint": id + "." + key}
		var ground: float = walker.ground_at.call(toe.x) + float(leg["depth"])
		if walker.airborne: continue
		if leg["planted"]:
			support += 1
			_require(absf(toe.y - ground) < 0.55, "contact_" + id, "planted foot %.6f from ground" % (toe.y - ground))
			_require(toe.distance_to(leg["contact"]) < 0.3, "target_" + id, "support foot misses contact")
		if leg["stepping"]:
			swinging.append(id)
			groups[leg["gait_group"]] = true
			if not old["stepping"]: starts[leg["gait_group"]] = true
		if not was_air and old["planted"] and not old["stepping"] and not leg["stepping"]:
			var slip := toe.distance_to(old["toe"])
			_maximum_stance_slip = maxf(_maximum_stance_slip, slip)
			_require(slip < EPS, "stance_" + id, "support foot slid %.6f pixels" % slip)
		if toe.y > ground + 0.75:
			_require(false, "penetration_" + id, "foot penetrated ground by %.6f pixels; %s" % [toe.y - ground,
				JSON.stringify(_json_value({"body_pos": walker.body_pos, "body_angle": walker.body_angle,
					"toe": toe, "contact": leg["contact"], "target": leg["target"], "from": leg["from"],
					"progress": leg["progress"], "planted": leg["planted"], "stepping": leg["stepping"],
					"space_reachable": leg.get("space_reachable", false), "ground": ground}))])
		else:
			_require(true, "penetration_" + id, "")
	if not walker.airborne:
		_minimum_support = mini(_minimum_support, support)
		_require(support >= 2, "support", "only %d support feet" % support)
		_require(groups.size() <= 1, "diagonal_group", "both diagonal pairs lifted together")
		if swinging.size() == 2:
			swinging.sort()
			_require(swinging == ["FF", "NR"] or swinging == ["FR", "NF"],
				"opposite_corners", "swinging legs are not a physical diagonal: " + str(swinging))
		if not starts.is_empty() and not was_air:
			var next := int(starts.keys()[0])
			if absf(walker.input_dir) > 0.1:
				_require(_last_pair < 0 or _last_pair != next, "pair_alternation", "same diagonal pair started twice consecutively")
			_last_pair = next
			_pair_starts += 1


func _json_value(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Vector3: return [value.x, value.y, value.z]
	if value is Array:
		var result: Array = []
		for item in value: result.append(_json_value(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _json_value(value[key])
		return result
	return value


func _stationary(label: String, points: Dictionary, hz: int) -> void:
	_case = "%s/%dHz/idle" % [label, hz]
	_step = 0
	var walker = _new_walker(points, func(_x: float) -> float: return 640.0)
	for _i in 2 * hz: _tick(walker, hz)
	var before := _snapshot(walker)
	var origin: Vector2 = walker.body_pos
	var envelope := 0.0
	for _i in 3 * hz:
		_tick(walker, hz)
		envelope = maxf(envelope, walker.body_pos.distance_to(origin))
	# A small breathing cycle is intentional; persistent translation is not.
	_require(envelope < 1.0, "body_settled", "stationary body left its 1px envelope: %.6f" % envelope)
	for leg in walker.pose_legs():
		_require(leg["planted"] and not leg["stepping"], "four_planted_" + String(leg["id"]), "stationary leg still swinging or unplanted")
		_require((leg["toe"] as Vector2).distance_to(before[leg["id"]]["toe"]) < EPS, "idle_lock_" + String(leg["id"]), "stationary toe drift")
	_container.free()


func _motion(label: String, points: Dictionary, hz: int, terrain: String, ground: Callable) -> void:
	var walker = _new_walker(points, ground)
	for phase in [["walk_right",1.0,false,3.0], ["run_right",1.0,true,2.0], ["reverse_left",-1.0,false,3.0], ["run_left",-1.0,true,2.0], ["stop",0.0,false,2.0]]:
		_case = "%s/%dHz/%s/%s" % [label,hz,terrain,phase[0]]
		_step = 0
		walker.input_dir = phase[1]
		walker.running = phase[2]
		var start: Vector2 = walker.body_pos
		var pair_start := _pair_starts
		var still_seconds := 0.0
		var longest_stall := 0.0
		for _i in int(float(phase[3]) * hz):
			var x: float = walker.body_pos.x
			_tick(walker, hz)
			still_seconds = still_seconds + 1.0 / hz if absf(walker.body_pos.x - x) * hz < 2.0 else 0.0
			longest_stall = maxf(longest_stall, still_seconds)
		var distance: float = (walker.body_pos.x - start.x) * float(phase[1])
		_travel.append({"case": _case, "distance": distance, "seconds": phase[3], "longest_stall": longest_stall})
		if float(phase[1]) != 0.0:
			_require(distance > 100.0, "progress", "only %.3f pixels in %.1f seconds" % [distance, phase[3]])
			_require(longest_stall < 0.8, "not_stuck", "no forward progress for %.3f seconds" % longest_stall)
			_require(_pair_starts - pair_start >= 3, "cycling", "too few leg cycles while translating")
		else:
			_require(absf(walker.speed) < 0.01, "stop_speed", "speed did not settle")
			for leg in walker.pose_legs():
				_require(leg["planted"] and not leg["stepping"], "stop_" + String(leg["id"]), "foot did not settle")
	print("  checked %s / %s @ %d Hz" % [label, terrain, hz])
	_container.free()


func _jump(label: String, points: Dictionary, hz: int) -> void:
	_case = "%s/%dHz/jump" % [label,hz]
	_step = 0
	var walker = _new_walker(points, func(_x: float) -> float: return 640.0)
	for _i in hz: _tick(walker, hz)
	var launch: float = walker.body_pos.y
	walker.jump()
	_require(walker.airborne, "launch", "jump did not enter airborne state")
	var apex := launch
	for _i in 2 * hz:
		_tick(walker, hz)
		apex = minf(apex, walker.body_pos.y)
	_require(launch - apex > 35.0, "height", "jump apex only %.3f pixels" % (launch - apex))
	_require(not walker.airborne, "land", "jump did not land")
	for leg in walker.pose_legs():
		_require(leg["planted"], "landing_" + String(leg["id"]), "foot did not settle after landing")
	_container.free()


func _aim(label: String, points: Dictionary, hz: int) -> void:
	_case = "%s/%dHz/moving_aim" % [label,hz]
	_step = 0
	var walker = _new_walker(points, func(_x: float) -> float: return 640.0)
	var shots: Array = []
	walker.fired.connect(func(muzzle: Vector2, direction: Vector2):
		shots.append([muzzle, direction])
		_require(muzzle.distance_to(walker.muzzle()) < EPS and direction.distance_to(walker.aim_dir()) < EPS,
			"signal", "fired signal and rendered muzzle differ"))
	for direction in [1.0, -1.0]:
		walker.input_dir = direction
		walker.firing = true
		var start_x: float = walker.body_pos.x
		for i in 2 * hz:
			walker.aim_target = walker.body_pos + Vector2(-direction * 900.0, -140.0)
			_tick(walker, hz)
			if i > hz:
				var ray: Vector2 = walker.aim_target - walker.muzzle()
				_require(absf(walker.aim_dir().angle_to(ray)) < 0.03, "direction", "aiming does not track opposite movement")
		_require((walker.body_pos.x - start_x) * direction > 100.0, "aim_progress", "aiming prevented locomotion")
	_require(shots.size() > 4, "shots", "firing did not emit shots")
	_container.free()


func _real_course(label: String, points: Dictionary) -> void:
	# Exercise the actual scene's 18px ledge and 85px drop, not a surrogate plane.
	# This lab is never added to the tree: its ground query is pure and cannot
	# create an editor or save a document.
	var lab = Lab.new()
	var walker = _new_walker(points, lab.ground_y)
	walker.body_pos.x = 0.0
	walker.reset_pose()
	walker.running = true
	for direction in [1.0, -1.0]:
		_case = "%s/60Hz/actual_course/%+.0f" % [label, direction]
		_step = 0
		walker.input_dir = direction
		var start_x: float = walker.body_pos.x
		var elapsed := 0.0
		var still_seconds := 0.0
		var longest_stall := 0.0
		for i in 45 * 60:
			var previous_x: float = walker.body_pos.x
			_tick(walker, 60)
			elapsed = float(i + 1) / 60.0
			still_seconds = still_seconds + 1.0 / 60.0 if absf(walker.body_pos.x - previous_x) * 60.0 < 2.0 else 0.0
			longest_stall = maxf(longest_stall, still_seconds)
			if (direction > 0.0 and walker.body_pos.x >= 3100.0) or (direction < 0.0 and walker.body_pos.x <= 0.0):
				break
		var arrived: bool = walker.body_pos.x >= 3100.0 if direction > 0.0 else walker.body_pos.x <= 0.0
		_require(arrived, "course_progress", "did not traverse actual scene in 45s: x=%.3f" % walker.body_pos.x)
		_travel.append({"case": _case, "distance": (walker.body_pos.x - start_x) * direction,
			"seconds": elapsed, "longest_stall": longest_stall})
		print("  checked %s actual course dir %+.0f: x=%.2f after %.3fs, longest stall %.3fs" % [label, direction, walker.body_pos.x, elapsed, longest_stall])
	_container.free()
	lab.free()
