extends SceneTree
const Walker = preload("res://scripts/proc_walker.gd")
const Rig = preload("res://scripts/walker_rig.gd")
const Adapter = preload("res://scripts/walker_spider_adapter.gd")
const IK = preload("res://scripts/spider_leg_ik.gd")
const SOURCE := "res://authoring/walker_motion.json"
const POINTS := ["mount", "hip", "knee", "ankle", "toe"]

var failures: Array[String] = []
var checks := 0
var worst_length := 0.0
var worst_stance := 0.0
var worst_draw := 0.0
var min_support := 4


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var source_hash := FileAccess.get_sha256(SOURCE)
	for source in [SOURCE, "res://authoring/does_not_exist_spider_validation.json"]:
		for hz in [30, 60, 120]:
			await _case(source, hz)
	await _performance()
	_check(FileAccess.get_sha256(SOURCE) == source_hash, "saved anatomy remains unchanged")
	var legacy := Walker.new()
	legacy.body_pos = Vector2(0, -212)
	root.add_child(legacy)
	_check(not legacy.spider_gait and legacy._spider == null, "legacy non-spider presets retain their original solver")
	legacy.input_dir = 1
	for i in 60:
		legacy.tick(1.0 / 60)
	_check(legacy.body_pos.x > 100, "legacy preset still walks")
	legacy.queue_free()
	print("Spider runtime: %d checks, fixed 3D length max %.6f, stance slip max %.6f, renderer endpoint max %.6f, minimum support %d, failures %d" % [checks, worst_length, worst_stance, worst_draw, min_support, failures.size()])
	for message in failures:
		push_error(message)
	quit(0 if failures.is_empty() else 1)


func _case(path: String, hz: int) -> void:
	var scope := ("saved" if path == SOURCE else "default") + "/" + str(hz)
	var container := Node2D.new()
	container.position = Vector2(150, -70)
	container.rotation = .12
	container.scale = Vector2(.65, .65)
	root.add_child(container)
	var walker := Walker.new()
	walker.spider_gait = true
	walker.anatomy_path = path
	walker.draw_greybox = false
	walker.ground_at = func(_x: float): return 640.0
	walker.tune = Walker.GAIT_SPIDER.duplicate()
	walker.tune["ride"] = walker.spider_ride_height()
	walker.body_pos = Vector2(0, 640.0 - float(walker.tune["ride"]))
	container.add_child(walker)
	var rig := Rig.new()
	rig.walker = walker
	walker.add_child(rig)
	await process_frame
	var dt := 1.0 / float(hz)
	var previous := {}
	var last_airborne := false
	var checkpoints := {}
	var coxa_min := INF
	var coxa_max := -INF
	var projected_min := INF
	var projected_max := -INF
	var total := int(9.0 * hz)
	for i in total:
		var time := i * dt
		walker.input_dir = 0.0 if time < .5 or (time >= 6.5 and time < 7.5) else (-1.0 if time >= 4.5 else 1.0)
		walker.running = time >= 2.5 and time < 4.5
		walker.aim_target = walker.body_pos + Vector2(-500, -80)
		walker.firing = time >= 3 and time < 3.5
		if i == int(7.5 * hz):
			walker.jump()
		walker.tick(dt)
		rig._process(0.0)
		var supports := 0
		for leg in walker.legs():
			var pose: Dictionary = leg.pose
			var spatial: Array = pose.spatial_points
			for j in 4:
				var length_error: float = absf((spatial[j] as Vector3).distance_to(spatial[j + 1]) - float(pose.spatial_lengths[j]))
				worst_length = maxf(worst_length, length_error)
				_check(length_error < .003, scope + " 3D bone length " + leg.id)
			for j in 5:
				_check((IK.project(spatial[j]) as Vector2).distance_to(pose[POINTS[j]]) < .003, scope + " projection " + leg.id)
			if not walker.airborne and not leg.stepping and pose.reachable and (pose.toe as Vector2).distance_to(leg.foot) < .01:
				supports += 1
			if not walker.airborne and not last_airborne and not leg.stepping and previous.has(leg.id) and not previous[leg.id].stepping:
				var slip: float = (pose.toe as Vector2).distance_to(previous[leg.id].toe)
				worst_stance = maxf(worst_stance, slip)
				_check(slip < .003, scope + " planted toe stays fixed " + leg.id)
			previous[leg.id] = {"toe": pose.toe, "stepping": leg.stepping}
			if leg.id == "NF":
				coxa_min = minf(coxa_min, pose.coxa_yaw)
				coxa_max = maxf(coxa_max, pose.coxa_yaw)
				projected_min = minf(projected_min, (pose.hip as Vector2).distance_to(pose.knee))
				projected_max = maxf(projected_max, (pose.hip as Vector2).distance_to(pose.knee))
		if not walker.airborne and not last_airborne and time < 7.5:
			min_support = mini(min_support, supports)
			_check(supports >= 2, scope + " has at least two supporting legs")
		last_airborne = walker.airborne
		if i % maxi(hz / 6, 1) == 0:
			_check_drawing(walker, rig, scope)
		if i == int(2.5 * hz) - 1:
			checkpoints["walk"] = walker.body_pos.x
		if i == int(4.5 * hz) - 1:
			checkpoints["run"] = walker.body_pos.x
		if i == int(6.5 * hz) - 1:
			checkpoints["reverse"] = walker.body_pos.x
	_check(checkpoints.walk > 100, scope + " forward walk makes progress " + str(checkpoints.walk))
	_check(checkpoints.run > checkpoints.walk + 100, scope + " run makes progress")
	_check(checkpoints.reverse < checkpoints.run - 100, scope + " backpedal makes progress")
	_check(coxa_max - coxa_min > .05, scope + " coxa actually rotates in depth")
	_check(projected_max - projected_min > 1.0, scope + " projection foreshortens a fixed spatial link")
	if path == SOURCE:
		_check(walker._spider.loaded_path == SOURCE, scope + " reads saved authoring document")
		for leg in walker.legs():
			var expected: Vector2 = Adapter.source_to_rig(walker._spider.points[leg.id + ".mount"])
			_check(IK.project(leg.state.rest3d[0]).distance_to(expected) < .001, scope + " edited source mount is registered " + leg.id)
	print("%s positions %s coxa sweep %.3f projected sweep %.3f" % [scope, checkpoints, coxa_max - coxa_min, projected_max - projected_min])
	container.queue_free()
	await process_frame


func _check_drawing(walker: Node2D, rig: Node2D, scope: String) -> void:
	for row in rig._legs:
		var leg: Dictionary = walker.legs()[row.index]
		var pose: Dictionary = leg.pose
		for pair in [["mount_link", "mount", "hip", "rod"], ["rod", "hip", "knee", "rod"], ["sleeve", "knee", "ankle", "sleeve_far" if leg.far else "sleeve"], ["shin", "ankle", "toe", "shin_far" if leg.far else "shin"]]:
			var sprite: Sprite2D = row[pair[0]]
			var spec: Dictionary = rig._parts[pair[3]]
			var down: bool = spec.axis == "down"
			var axis := (Vector2.DOWN if down else Vector2.RIGHT).rotated(-float(spec.get("lean", 0.0)))
			var full: Vector2 = sprite.texture.get_size()
			var anchor: Vector2 = spec.anchor
			var source_length := (full.y - anchor.y) / axis.y if down else (full.x - anchor.x) / axis.x
			var actual_start: Vector2 = walker.get_parent().to_local(sprite.to_global(Vector2.ZERO))
			var actual_end: Vector2 = walker.get_parent().to_local(sprite.to_global(axis * source_length))
			var error := maxf(actual_start.distance_to(pose[pair[1]]), actual_end.distance_to(pose[pair[2]]))
			worst_draw = maxf(worst_draw, error)
			_check(error < .004, scope + " art endpoint follows the shared solver " + leg.id + "/" + pair[0])


func _performance() -> void:
	var walker := Walker.new()
	walker.spider_gait = true
	walker.draw_greybox = false
	walker.ground_at = func(_x: float): return 640.0
	walker.tune = Walker.GAIT_SPIDER.duplicate()
	walker.tune["ride"] = walker.spider_ride_height()
	walker.body_pos = Vector2(0, 640.0 - float(walker.tune["ride"]))
	root.add_child(walker)
	for condition in ["idle", "walk"]:
		walker.input_dir = 1.0 if condition == "walk" else 0.0
		for warmup in 60:
			walker.tick(1.0 / 60.0)
		var times: Array[float] = []
		var sum := 0.0
		for iteration in 1000:
			var start := Time.get_ticks_usec()
			walker.tick(1.0 / 60.0)
			var elapsed := (Time.get_ticks_usec() - start) / 1000.0
			times.append(elapsed)
			sum += elapsed
		times.sort()
		print("CPU %s / 60Hz / 1000 ticks: mean %.3f ms, p95 %.3f ms, max %.3f ms" % [condition, sum / 1000.0, times[949], times[-1]])
	walker.queue_free()
	await process_frame


func _check(value: bool, context: String) -> void:
	checks += 1
	if not value and not failures.has(context):
		failures.append(context)
