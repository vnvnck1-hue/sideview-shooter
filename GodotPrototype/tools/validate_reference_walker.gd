extends SceneTree
## Legacy flat 2D contract checks. Spatial gait is tested by validate_spider_gait.gd.
## godot --headless --path GodotPrototype --script res://tools/validate_reference_walker.gd
const Walker = preload("res://scripts/reference_walker.gd")
const Anatomy = preload("res://scripts/walker_anatomy.gd")
const Lab = preload("res://scripts/reference_walker_lab.gd")
const EPS := 0.015
const RAW := {
	"FF": [Vector2(617,586),Vector2(506,632),Vector2(365,700),Vector2(245,848),Vector2(246,921)],
	"FR": [Vector2(780,582),Vector2(671,590),Vector2(528,642),Vector2(460,756),Vector2(479,806)],
	"NF": [Vector2(746,594),Vector2(583,752),Vector2(739,632),Vector2(738,877),Vector2(735,936)],
	"NR": [Vector2(1044,578),Vector2(1073,774),Vector2(1193,710),Vector2(1294,856),Vector2(1290,921)],
}
const POINTS := ["mount", "hip", "knee", "ankle", "toe"]
var _failures: Dictionary = {}
var _checks := 0
var _case := "setup"
var _step := 0
var _max_length_error := 0.0
var _max_bone_error := 0.0
var _max_stance_slip := 0.0
var _minimum_support := 4
var _container: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_reference()
	for hz in [30, 60, 120]:
		if "diagnose-course" in OS.get_cmdline_user_args():
			_real_course(hz)
			continue
		if "diagnose-flat120" in OS.get_cmdline_user_args():
			if hz == 120:
				_motion(hz, "flat", func(_x: float) -> float: return 640.0)
			continue
		_motion(hz, "flat", func(_x: float) -> float: return 640.0)
		_motion(hz, "slope", func(x: float) -> float: return 640.0 - clampf(x, -1000.0, 1500.0) * 0.07)
		_motion(hz, "step", func(x: float) -> float: return 628.0 if x >= 80.0 else 640.0)
		_jump(hz)
		_aim(hz)
		_aim_motion(hz)
		_real_course(hz)
	print("REFERENCE WALKER: %d checks; length max %.5f; bone endpoint max %.5f; stance slip max %.5f; minimum support %d" % [
		_checks, _max_length_error, _max_bone_error, _max_stance_slip, _minimum_support])
	for key in _failures:
		print("FAIL ", key, ": ", _failures[key])
	print("PASS" if _failures.is_empty() else "FAILED: %d distinct case/contracts" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _new_walker(ground: Callable, reference := false):
	_container = Node2D.new()
	# Nonidentity ancestors catch confusing parent-space and global bone coordinates.
	_container.position = Vector2(33, -48)
	_container.scale = Vector2(0.7, 0.7)
	_container.rotation = 0.13
	root.add_child(_container)
	var walker = Walker.new()
	walker.spider_gait = false
	walker.source_rest = reference
	walker.body_pos = Vector2(-350, 315)
	walker.ground_at = ground
	_container.add_child(walker)
	return walker


func _dispose() -> void:
	_container.free()


func _require(ok: bool, contract: String, detail: String) -> void:
	_checks += 1
	var key := _case + "/" + contract
	if not ok and not _failures.has(key):
		_failures[key] = "tick %d: %s" % [_step, detail]


func _reference() -> void:
	_case = "source_rest"
	_step = 0
	var walker = _new_walker(func(_x: float) -> float: return 640.0, true)
	walker.input_dir = 1.0
	walker.aim_target = Vector2(900, -100)
	walker.tick(1.0 / 60.0)
	for leg in walker.pose_legs():
		var expected: Array = RAW[leg["id"]]
		for i in POINTS.size():
			var wanted: Vector2 = walker.body_pos + Anatomy.local_point(expected[i])
			var error: float = (leg[POINTS[i]] as Vector2).distance_to(wanted)
			_require(error < EPS, "raw_" + leg["id"] + "_" + POINTS[i], "raw source mismatch %.6f" % error)
	var body: Dictionary = walker.pose_body()
	for pair in [["chassis", Anatomy.BODY_ROOT], ["pivot", Anatomy.TORSO_PIVOT], ["gun", Anatomy.GUN_PIVOT],
		["barrel", Anatomy.BARREL_ANCHOR], ["muzzle", Anatomy.MUZZLE], ["upper_center", Anatomy.UPPER_CENTER]]:
		var wanted: Vector2 = walker.body_pos + Anatomy.local_point(pair[1])
		_require((body[pair[0]] as Vector2).distance_to(wanted) < EPS, "raw_" + pair[0], "body landmark differs from original")
	_require(walker.speed == 0.0 and not walker.airborne, "frozen_reference", "source pose reacted to input")
	var fr: Dictionary = Anatomy.LEGS[1]
	_require(fr["ground_toe"] == Vector2(665,908), "folded_leg_contact", "FR contact must be separate from original lifted toe")
	var bones: Array = []
	_collect_bones(walker.skeleton, bones)
	var bind_poses: Array = []
	for bone in bones:
		bind_poses.append(bone.rest)
	_require(bones.size() == 20, "bone_count", "expected 20 actual Bone2D nodes, found %d" % bones.size())
	for id in RAW:
		var path: String = "Chassis/" + id + "_Mount/Upper/Lower/Foot"
		_require(walker.skeleton.get_node_or_null(path) is Bone2D, "hierarchy_" + id, "missing continuous Bone2D chain " + path)
	_require(walker.skeleton.get_node_or_null("Chassis/UpperAssembly/GunPivot/Barrel") is Bone2D, "gun_hierarchy", "missing upper assembly / gun / barrel chain")
	_pose(walker)
	_bones(walker)
	walker.source_rest = false
	walker.tick(1.0 / 60.0)
	walker.reset_pose()
	_pose(walker)
	_bones(walker)
	for i in bones.size():
		_require(bones[i].rest == bind_poses[i], "rest_runtime_" + str(i), "runtime reset changed source bind pose " + str(bones[i].get_path()))
	walker.source_rest = true
	walker.tick(1.0 / 60.0)
	for i in bones.size():
		_require(bones[i].rest == bind_poses[i], "rest_toggle_" + str(i), "reference toggle changed source bind pose " + str(bones[i].get_path()))
	for leg in walker.pose_legs():
		_require((leg["toe"] as Vector2).distance_to(walker.body_pos + Anatomy.local_point(RAW[leg["id"]][4])) < EPS,
			"return_reference_" + leg["id"], "toggle failed to restore raw toe")
	_dispose()


func _collect_bones(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Bone2D:
			out.append(child)
		_collect_bones(child, out)


func _pose(walker) -> void:
	for leg in walker.pose_legs():
		var raw: Array = RAW[leg["id"]]
		for i in range(4):
			var a: Vector2 = leg[POINTS[i]]
			var b: Vector2 = leg[POINTS[i + 1]]
			var expected: float = (raw[i] as Vector2).distance_to(raw[i + 1]) * Anatomy.SCALE
			var error := absf(a.distance_to(b) - expected)
			_max_length_error = maxf(_max_length_error, error)
			_require(a.is_finite() and b.is_finite() and error < EPS, "length_" + leg["id"] + "_" + POINTS[i],
				"%.6f actual vs %.6f fixed (error %.6f)" % [a.distance_to(b), expected, error])
	var body: Dictionary = walker.pose_body()
	var length: float = (body["barrel"] as Vector2).distance_to(body["muzzle"])
	var expected := Anatomy.BARREL_ANCHOR.distance_to(Anatomy.MUZZLE) * Anatomy.SCALE
	_require(absf(length - expected) < EPS, "barrel_length", "length %.6f vs %.6f" % [length, expected])


func _bones(walker) -> void:
	for leg in walker.pose_legs():
		var bone: Bone2D = walker.skeleton.get_node("Chassis/" + leg["id"] + "_Mount")
		for i in range(4):
			var start: Vector2 = _container.to_global(leg[POINTS[i]])
			var end: Vector2 = _container.to_global(leg[POINTS[i + 1]])
			var error := maxf(bone.global_position.distance_to(start), bone.to_global(Vector2(bone.length, 0)).distance_to(end))
			_max_bone_error = maxf(_max_bone_error, error)
			_require(error < EPS, "bone_" + leg["id"] + "_" + POINTS[i], "global bone endpoint error %.6f" % error)
			if i < 3:
				bone = bone.get_node(["Upper", "Lower", "Foot"][i])
	var body: Dictionary = walker.pose_body()
	for pair in [["Chassis", "chassis"], ["Chassis/UpperAssembly", "pivot"],
		["Chassis/UpperAssembly/GunPivot", "gun"], ["Chassis/UpperAssembly/GunPivot/Barrel", "barrel"]]:
		var bone: Bone2D = walker.skeleton.get_node(pair[0])
		var error := bone.global_position.distance_to(_container.to_global(body[pair[1]]))
		_require(error < EPS, "bone_" + pair[1], "global body bone origin error %.6f" % error)
	var barrel: Bone2D = walker.skeleton.get_node("Chassis/UpperAssembly/GunPivot/Barrel")
	_require(barrel.to_global(Vector2(barrel.length, 0)).distance_to(_container.to_global(walker.muzzle())) < EPS,
		"bone_muzzle", "barrel endpoint differs from actual muzzle")
	for pair in [["Chassis", "pivot"], ["Chassis/UpperAssembly", "upper_center"], ["Chassis/UpperAssembly/GunPivot", "barrel"]]:
		var bone: Bone2D = walker.skeleton.get_node(pair[0])
		var error := bone.to_global(Vector2.RIGHT.rotated(bone.bone_angle) * bone.length).distance_to(_container.to_global(body[pair[1]]))
		_require(error < EPS, "bone_end_" + pair[1], "body Bone2D endpoint error %.6f" % error)


func _snapshot(walker) -> Dictionary:
	var result := {}
	for leg in walker.pose_legs():
		result[leg["id"]] = {"toe": leg["toe"], "contact": leg["contact"], "hip": leg["hip"], "planted": leg["planted"], "stepping": leg["stepping"]}
	return result


func _contacts(walker, before: Dictionary, was_air: bool) -> void:
	if walker.airborne:
		return
	var planted := 0
	var swinging := 0
	var groups := {}
	for leg in walker.pose_legs():
		var toe: Vector2 = leg["toe"]
		var ground: float = walker.ground_at.call(toe.x) + float(leg["depth"])
		if leg["planted"]:
			planted += 1
			_require(absf(toe.y - ground) < 0.55, "ground_" + leg["id"], "planted toe differs from plane by %.6f" % (toe.y - ground))
		if leg["stepping"]:
			swinging += 1
			groups[leg["gait_group"]] = true
		var old: Dictionary = before[leg["id"]]
		if not was_air and old["planted"] and not old["stepping"] and not leg["stepping"]:
			var slip: float = toe.distance_to(old["toe"])
			_max_stance_slip = maxf(_max_stance_slip, slip)
			var wanted_ankle: Vector2 = (leg["contact"] as Vector2) - (toe - (leg["ankle"] as Vector2))
			var wanted_distance: float = (leg["hip"] as Vector2).distance_to(wanted_ankle)
			_require(slip < EPS, "stance_" + leg["id"],
				"toe moved %.6f without lifting (planted=%s); oldToe=%s toe=%s oldContact=%s contact=%s hip=%s oldHip=%s mount=%s wantedAnkle=%s wantedDistance=%.6f inner=%.6f outer=%.6f toeContactError=%.6f" % [
					slip, str(leg["planted"]), str(old["toe"]), str(toe), str(old["contact"]), str(leg["contact"]), str(leg["hip"]), str(old["hip"]), str(leg["mount"]), str(wanted_ankle),
					wanted_distance, absf(float(leg["upper_length"]) - float(leg["lower_length"])) + Walker.REACH_EPS,
					float(leg["upper_length"]) + float(leg["lower_length"]) - Walker.REACH_EPS, toe.distance_to(leg["contact"])])
		_require(toe.y <= ground + 0.75, "penetration_" + leg["id"], "toe %.4f below terrain %.4f" % [toe.y, ground])
	_minimum_support = mini(_minimum_support, planted)
	_require(planted >= 2, "support", "only %d planted, %d swinging; body=(%.2f,%.2f)" % [planted, swinging, walker.body_pos.x, walker.body_pos.y])
	_require(swinging <= 2 and groups.size() <= 1, "gait_pairs", "swinging=%d groups=%s" % [swinging, str(groups.keys())])


func _tick(walker, hz: int) -> void:
	_step += 1
	var before := _snapshot(walker)
	var was_air: bool = walker.airborne
	walker.tick(1.0 / float(hz))
	_pose(walker)
	_bones(walker)
	_contacts(walker, before, was_air)


func _motion(hz: int, terrain: String, ground: Callable) -> void:
	var walker = _new_walker(ground)
	var sequence := [["walk",1.0,false,3.0], ["run",1.0,true,2.0], ["reverse",-1.0,false,3.0],
		["reverse_run",-1.0,true,2.0], ["stop",0.0,false,2.0]]
	for segment in sequence:
		_case = "%s/%dHz/%s" % [terrain,hz,segment[0]]
		_step = 0
		walker.input_dir = segment[1]
		walker.running = segment[2]
		var start_x: float = walker.body_pos.x
		for _i in int(float(segment[3]) * hz):
			_tick(walker, hz)
		if segment[1] != 0.0:
			_require((walker.body_pos.x - start_x) * float(segment[1]) > 100.0, "travel", "did not move substantially in input direction")
		else:
			_require(absf(walker.speed) < 0.01, "stopped", "speed did not settle")
	print("  checked ", terrain, " @ ", hz, " Hz")
	_dispose()


func _jump(hz: int) -> void:
	_case = "jump/%dHz" % hz
	_step = 0
	var walker = _new_walker(func(_x: float) -> float: return 640.0)
	for _i in hz:
		_tick(walker, hz)
	var launch_y: float = walker.body_pos.y
	walker.jump()
	_require(walker.airborne, "launch", "jump did not enter airborne state")
	var top := launch_y
	for _i in int(1.8 * hz):
		_tick(walker, hz)
		top = minf(top, walker.body_pos.y)
	_require(launch_y - top > 35.0, "apex", "jump height %.4f" % (launch_y - top))
	_require(not walker.airborne, "landed", "still airborne after 1.8 seconds")
	var planted := 0
	for leg in walker.pose_legs():
		planted += int(leg["planted"])
	_require(planted == 4, "settled", "landing settled with %d/4 contacts" % planted)
	_dispose()


func _aim(hz: int) -> void:
	_case = "aim/%dHz" % hz
	_step = 0
	var walker = _new_walker(func(_x: float) -> float: return 640.0)
	for _i in hz:
		_tick(walker, hz)
	var resting := _snapshot(walker)
	var hits: Array = []
	walker.fired.connect(func(m: Vector2,d: Vector2):
		hits.append([m,d])
		_require(m.distance_to(walker.muzzle()) < EPS and d.distance_to(walker.aim_dir()) < EPS,
			"shot_pose", "shot signal disagrees with rendered muzzle or direction"))
	for index in range(8):
		var direction := Vector2.RIGHT.rotated(float(index) * TAU / 8.0)
		walker.aim_target = walker.body_pos + direction * 900.0
		walker.firing = false
		for _i in int(0.8 * hz):
			_tick(walker, hz)
		var desired: Vector2 = (walker.aim_target as Vector2) - walker.muzzle()
		var error := absf(walker.aim_dir().angle_to(desired))
		_require(error < 0.01, "direction_%d" % index, "aim error %.5f rad" % error)
		walker.firing = true
		_tick(walker, hz)
		for leg in walker.pose_legs():
			_require((leg["toe"] as Vector2).distance_to(resting[leg["id"]]["toe"]) < EPS,
				"aim_contact_" + leg["id"], "aim moved stationary foot")
	_require(hits.size() >= 8, "fired", "expected directional shots, got %d" % hits.size())
	for hit in hits:
		_require((hit[0] as Vector2).is_finite() and absf((hit[1] as Vector2).length() - 1.0) < EPS,
			"shot_contract", "fired signal emitted invalid muzzle/direction")
	_dispose()


func _aim_motion(hz: int) -> void:
	var walker = _new_walker(func(_x: float) -> float: return 640.0)
	for move_direction in [1.0, -1.0]:
		_case = "moving_aim/%dHz/%+.0f" % [hz, move_direction]
		_step = 0
		walker.input_dir = move_direction
		walker.firing = true
		for index in 2 * hz:
			walker.aim_target = walker.body_pos + Vector2(-move_direction * 900.0, -140.0)
			_tick(walker, hz)
			if index >= hz:
				var ray: Vector2 = (walker.aim_target as Vector2) - walker.muzzle()
				_require(absf(walker.aim_dir().angle_to(ray)) < 0.03, "tracking", "moving target aim error exceeds 1.72 degrees")
		_require(walker.speed * move_direction > 100.0, "move_independent", "aim prevented desired movement")
		_require(walker.aim_dir().x * move_direction < -0.9, "opposite_aim", "gun cannot point opposite movement")
	_dispose()


func _real_course(hz: int) -> void:
	# Reuse the live lab's ground function, so changing its course changes this test too.
	var lab = Lab.new()
	var walker = _new_walker(lab.ground_y)
	walker.body_pos.x = 0.0
	walker.reset_pose()
	walker.running = true
	for direction in [1.0, -1.0]:
		_case = "lab_course/%dHz/%+.0f" % [hz, direction]
		_step = 0
		walker.input_dir = direction
		var start_x: float = walker.body_pos.x
		var stopped := 0.0
		var longest_stop := 0.0
		var elapsed := 0.0
		# Cover the entire real course; 18 seconds is a diagnostic sample, not a speed contract.
		for index in 45 * hz:
			var previous_x: float = walker.body_pos.x
			_tick(walker, hz)
			elapsed = float(index + 1) / hz
			var actual_speed: float = absf(walker.body_pos.x - previous_x) * hz
			stopped = stopped + 1.0 / hz if actual_speed < 2.0 else 0.0
			longest_stop = maxf(longest_stop, stopped)
			if index + 1 == 18 * hz:
				print("  live lab 18s @ %d Hz dir %+.0f: net=%.2f avg=%.2f px/s longest_stop=%.3fs x=%.2f" % [
					hz, direction, (walker.body_pos.x - start_x) * direction,
					(walker.body_pos.x - start_x) * direction / 18.0, longest_stop, walker.body_pos.x])
			if elapsed >= 18.0 and ((direction > 0.0 and walker.body_pos.x >= 3100.0) or (direction < 0.0 and walker.body_pos.x <= 0.0)):
				break
		if direction > 0.0:
			_require(walker.body_pos.x >= 3100.0, "course_progress", "did not traverse full lab course in 45s: x=%.3f" % walker.body_pos.x)
		else:
			_require(walker.body_pos.x <= 0.0, "course_return", "did not return over course in 45s: x=%.3f" % walker.body_pos.x)
		print("  checked live lab @ %d Hz direction %+.0f, x=%.2f elapsed=%.3fs longest_stop=%.3fs" % [hz, direction, walker.body_pos.x, elapsed, longest_stop])
	_dispose()
	lab.free()
