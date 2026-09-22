extends SceneTree
## Shared gait persistence, live adapter parameters and fixed-length IK contracts.
const Settings = preload("res://scripts/walker_gait_settings.gd")
const Adapter = preload("res://scripts/walker_spider_adapter.gd")
const IK = preload("res://scripts/spider_leg_ik.gd")
const Walker = preload("res://scripts/proc_walker.gd")
const MOTION := "res://authoring/walker_motion.json"

class TestWalker extends Node2D:
	var tune: Dictionary = {}
	var body_pos := Vector2(0, 428.75)
	var speed := 80.0
	var input_dir := 1.0
	var running := false
	var airborne := false
	var _angle := 0.0
	var _air_v := 0.0
	var _legs: Array = []
	var steps_normal := 0
	var ground_at: Callable = func(_x: float) -> float: return 640.0
	# 걸음 계산은 언제나 사격 반동을 걷어낸 몸통으로 돈다 (ProcWalker._strip_recoil).
	func recoil_shift() -> float:
		return 0.0

var checks := 0
var failures: Array[String] = []
var fixtures: Array[String] = []
var folder := ""


func _initialize() -> void:
	_run.call_deferred()


func _require(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)


func _run() -> void:
	var protected_motion := FileAccess.get_sha256(MOTION)
	var gait_existed := FileAccess.file_exists(Settings.DEFAULT_PATH)
	var protected_gait := FileAccess.get_sha256(Settings.DEFAULT_PATH) if gait_existed else ""
	folder = "res://.godot/gait-settings-validation-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_persistence()
	_adapter_parameters()
	_ik_parameters()
	if "extremes" in OS.get_cmdline_user_args():
		_range_audit()
	_require(protected_motion == FileAccess.get_sha256(MOTION), "user motion document unchanged")
	_require(gait_existed == FileAccess.file_exists(Settings.DEFAULT_PATH), "default gait file not created")
	if gait_existed:
		_require(protected_gait == FileAccess.get_sha256(Settings.DEFAULT_PATH), "user gait document unchanged")
	for path in fixtures:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	for failure in failures:
		print("FAIL ", failure)
	print("WALKER GAIT SETTINGS: ", checks, " checks; ", "PASS" if failures.is_empty() else str(failures.size()) + " failures")
	quit(0 if failures.is_empty() else 1)


func _persistence() -> void:
	var data := Settings.new()
	_require(Settings.definitions().size() == 18 and Settings.validate_values(data.values), "complete 18-setting defaults")
	_require(not data.dirty, "new defaults clean")
	for definition in Settings.definitions():
		var key: String = definition["key"]
		var grid: float = (float(definition["default"]) - float(definition["min"])) / float(definition["step"])
		_require(absf(grid - roundf(grid)) < .00001, "default lies on UI step grid " + key)
		_require(data.set_value(key, definition["min"]), "accept minimum " + key)
		_require(data.set_value(key, definition["max"]), "accept maximum " + key)
		_require(not data.set_value(key, float(definition["max"]) + 1.0), "reject above maximum " + key)
		_require(not data.set_value(key, NAN), "reject NaN " + key)
	_require(not data.set_value("unknown", 1.0), "reject unknown key")
	_require(not data.set_value("legs_up", 1.5), "reject fractional support count")
	data.reset_defaults()
	_require(not data.dirty, "reset returns initial clean values")
	data.set_value("speed", 350.0)
	_require(data.dirty, "valid setting marks dirty")
	var path := folder + "/roundtrip.json"
	fixtures.append(path)
	_require(data.save(path) == OK, "first atomic save: " + data.last_error)
	_require(not data.dirty, "save marks clean")
	var first_hash := FileAccess.get_sha256(path)
	data.set_value("knee_swivel", 15.0)
	_require(data.save(path) == OK, "replace atomic save")
	_require(FileAccess.get_sha256(path + ".bak") == first_hash, "backup contains previous complete save")
	var loaded := Settings.new()
	_require(loaded.load_file(path) == OK and loaded.values == data.values and not loaded.dirty, "round trip all values")
	loaded.values["speed"] = 360.0
	_require(loaded.dirty, "direct dictionary mutation marks dirty")
	var before := loaded.values.duplicate(true)
	_require(loaded.load_file(folder + "/absent.json") == ERR_FILE_NOT_FOUND and loaded.values == before, "missing load retains edits")
	var document := {"format":Settings.FORMAT, "version":Settings.VERSION, "values":Settings.defaults()}
	var bad_documents: Array = ["{truncated", JSON.stringify({"format":"other", "version":1, "values":Settings.defaults()})]
	var unknown: Dictionary = document.duplicate(true)
	unknown["values"]["unrecognized"] = 1
	bad_documents.append(JSON.stringify(unknown))
	var missing: Dictionary = document.duplicate(true)
	missing["values"].erase("lift")
	bad_documents.append(JSON.stringify(missing))
	var outside: Dictionary = document.duplicate(true)
	outside["values"]["speed"] = 501.0
	bad_documents.append(JSON.stringify(outside))
	var nonfinite := JSON.stringify(document).replace('"speed":340.0', '"speed":1e309').replace('"speed":340', '"speed":1e309')
	bad_documents.append(nonfinite)
	for i in range(bad_documents.size()):
		var corrupt := folder + "/corrupt-" + str(i) + ".json"
		fixtures.append(corrupt)
		var file := FileAccess.open(corrupt, FileAccess.WRITE)
		file.store_string(bad_documents[i])
		file.close()
		var hash_before := FileAccess.get_sha256(corrupt)
		_require(loaded.load_file(corrupt) == ERR_FILE_CORRUPT and loaded.values == before, "corrupt load atomic " + str(i))
		_require(loaded.save(corrupt) == ERR_FILE_CORRUPT and FileAccess.get_sha256(corrupt) == hash_before, "corrupt overwrite blocked " + str(i))
	loaded.values["extra"] = 3
	_require(loaded.save(folder + "/invalid.json") == ERR_INVALID_DATA, "direct invalid dictionary cannot save")


func _fixture(changes: Dictionary = {}, running := false) -> Dictionary:
	var walker := TestWalker.new()
	walker.tune = Settings.defaults()
	walker.tune.merge(changes, true)
	walker.running = running
	var adapter := Adapter.new()
	adapter.configure(MOTION)
	adapter.reset(walker)
	return {"walker":walker, "adapter":adapter}


func _tick(fixture: Dictionary, delta: float) -> void:
	var walker: TestWalker = fixture["walker"]
	fixture["adapter"].tick(walker, delta, walker.body_pos, walker._angle)


func _active(fixture: Dictionary) -> int:
	var count := 0
	for leg in fixture["walker"]._legs:
		count += int(bool(leg["stepping"]))
	return count


func _release(fixture: Dictionary) -> void:
	fixture["walker"].free()


func _adapter_parameters() -> void:
	var base := _fixture()
	var wide := _fixture({"stride":1.2})
	_require((base.walker._legs[0].foot as Vector2).distance_to(wide.walker._legs[0].foot) > 1.0, "stride changes stance placement")
	_release(base)
	_release(wide)
	var immediate := _fixture()
	var delayed := _fixture({"trigger":45.0})
	_tick(immediate, .001)
	_tick(delayed, .001)
	_require(_active(immediate) == 2 and _active(delayed) == 0, "trigger delays step until error threshold")
	_release(immediate)
	_release(delayed)
	for pair in [["step_time",.30,false], ["run_step_time",.25,true]]:
		var fixture := _fixture({pair[0]:pair[1]}, pair[2])
		_tick(fixture,.001)
		for leg in fixture.walker._legs:
			if leg.stepping:
				_require(is_equal_approx(leg.dur,pair[1]), "duration setting " + pair[0])
		_release(fixture)
	var low := _fixture({"lift":10.0})
	var high := _fixture({"lift":45.0})
	for fixture in [low,high]:
		_tick(fixture,.001)
		_tick(fixture,.09)
	var lift_difference := 0.0
	for i in range(4):
		lift_difference = maxf(lift_difference, absf(low.walker._legs[i].foot.y - high.walker._legs[i].foot.y))
	_require(lift_difference > 30.0, "lift changes swing apex")
	_release(low)
	_release(high)
	var near := _fixture({"lead":.05})
	var far := _fixture({"lead":.30})
	_tick(near,.001)
	_tick(far,.001)
	var placement_difference := 0.0
	for i in range(4):
		placement_difference = maxf(placement_difference,(near.walker._legs[i].to as Vector2).distance_to(far.walker._legs[i].to))
	_require(placement_difference > 5.0,"lead changes landing placement")
	_release(near)
	_release(far)
	var no_hold := _fixture({"hold":0.0})
	var hold := _fixture({"hold":.15})
	for fixture in [no_hold,hold]:
		_tick(fixture,.001)
		_tick(fixture,.18)
	_require(no_hold.walker.steps_normal > hold.walker.steps_normal, "hold delays next pair")
	_release(no_hold)
	_release(hold)
	var crawl := _fixture({"legs_up":1.0})
	var seen := {}
	for i in range(90):
		_tick(crawl,1.0/60.0)
		_require(_active(crawl) <= 1,"single-leg mode keeps three support legs")
		for leg in crawl.walker._legs:
			if leg.stepping:
				seen[leg.id]=true
	_require(seen.size() == 4,"single-leg mode visits all four legs")
	_release(crawl)
	var live := _fixture()
	var lengths: Array = live.walker._legs[0].state.lengths.duplicate()
	var rest: Array = live.walker._legs[0].state.rest3d.duplicate()
	var foot: Vector2 = live.walker._legs[0].foot
	var knee: Vector2 = live.walker._legs[0].pose.knee
	live.walker.tune["knee_swivel"]=30.0
	live.adapter.solve(live.walker)
	_require((live.walker._legs[0].pose.knee as Vector2).distance_to(knee)>1.0,"live knee swivel updates without reset")
	_require(live.walker._legs[0].foot == foot and live.walker._legs[0].state.lengths == lengths and live.walker._legs[0].state.rest3d == rest,"live tuning preserves contacts and rigid bind")
	_tick(live,.001)
	_tick(live,.03)
	for leg in live.walker._legs:
		if leg.stepping:
			var progress: float=leg.t
			live.walker.tune["step_time"] = .30
			_tick(live,.01)
			_require(leg.t>progress and leg.t<progress+.1 and is_equal_approx(leg.dur,.30),"live duration preserves swing progress")
			break
	_release(live)


func _ik_parameters() -> void:
	var fixture := _fixture()
	for key in ["coxa_yaw_bias","coxa_pitch_bias","knee_swivel","yaw_limit","pitch_limit"]:
		var largest := 0.0
		for leg in fixture.walker._legs:
			var state: Dictionary = leg.state.duplicate(true)
			for dx in [-100.0,0.0,100.0]:
				for dy in [-70.0,0.0,70.0]:
					var body: Vector2 = fixture.walker.body_pos + Vector2(dx,dy)
					state["config"] = Settings.defaults()
					var first := IK.solve(state,body,0,leg.foot)
					state["config"][key] = {"coxa_yaw_bias":20.0,"coxa_pitch_bias":15.0,"knee_swivel":30.0,"yaw_limit":20.0,"pitch_limit":5.0}[key]
					var second := IK.solve(state,body,0,leg.foot)
					largest = maxf(largest,(first.hip as Vector2).distance_to(second.hip))
					largest = maxf(largest,(first.knee as Vector2).distance_to(second.knee))
					for i in range(4):
						_require(absf((second.spatial_points[i] as Vector3).distance_to(second.spatial_points[i+1])-state.lengths[i]) < .002,"rigid spatial length after "+key)
					if key == "knee_swivel":
						_require((first.hip as Vector2).distance_to(second.hip)<.001 and (first.toe as Vector2).distance_to(second.toe)<.001,"swivel keeps hip and foot fixed")
		_require(largest > .1,key+" changes solved joint position")
	_release(fixture)


func _range_audit() -> void:
	var configurations: Array = [{"key":"defaults", "value":0.0}]
	for definition in Settings.definitions():
		if "recheck" in OS.get_cmdline_user_args() and definition["key"] not in ["stride","step_time","run_step_time"]:
			continue
		for value in [definition["min"],definition["max"]]:
			configurations.append({"key":definition["key"],"value":value})
	for configuration in configurations:
		var key: String = configuration["key"]
		var walker := Walker.new()
		walker.draw_greybox = false
		walker.anatomy_path = MOTION
		walker.initialize_spider_tuning(folder + "/not-created.json")
		var values: Dictionary = Settings.defaults()
		if key != "defaults":
			values[key] = configuration["value"]
		_require(walker.apply_spider_tuning(values),"range settings accepted " + key)
		walker.ground_at = func(x: float): return 640.0 - clampf(x - 180.0,0.0,600.0) * .10
		walker.body_pos = Vector2(0,640.0-values["ride"])
		root.add_child(walker)
		var previous := {}
		var previous_airborne := false
		var minimum_support := 4
		var idle_support := 4
		var ground_error := 0.0
		var idle_error := 0.0
		var stance_slip := 0.0
		var joint_step := 0.0
		var unreachable_frames := 0
		var max_length_error := 0.0
		var first_unreachable := {}
		var right_x := 0.0
		var left_x := 0.0
		for frame in range(390):
			walker.input_dir = 0.0 if frame < 60 or frame >= 300 else (1.0 if frame < 180 else -1.0)
			walker.running = frame >= 120 and frame < 180
			walker.aim_target = walker.body_pos + Vector2(400,-250)
			if frame == 300:
				walker.jump()
			walker.tick(1.0/60.0)
			if frame == 179:
				right_x = walker.body_pos.x
			if frame == 299:
				left_x = walker.body_pos.x
			_require(walker.body_pos.is_finite() and is_finite(walker._angle),"finite body " + key)
			var supports := 0
			var unreachable := false
			for leg in walker.legs():
				var pose: Dictionary = leg["pose"]
				var points: Array = pose["spatial_points"]
				for i in range(5):
					_require((points[i] as Vector3).is_finite(),"finite joint " + key)
					if i < 4:
						max_length_error = maxf(max_length_error,absf((points[i] as Vector3).distance_to(points[i+1])-float(pose["spatial_lengths"][i])))
				var error: float = (pose["toe"] as Vector2).distance_to(leg["foot"])
				if not walker.airborne and not leg["stepping"]:
					ground_error = maxf(ground_error,error)
					if bool(pose["reachable"]) and error < .01:
						supports += 1
					else:
						unreachable = true
						if first_unreachable.is_empty():
							first_unreachable = {"frame":frame,"leg":leg["id"],"margin":pose["margin"],"body":str(walker.body_pos),"error":error,"was_airborne":previous_airborne,"recovering":leg.get("recovering",false)}
					if frame >= 45 and frame < 60:
						idle_error = maxf(idle_error,error)
				if previous.has(leg["id"]):
					var last: Dictionary = previous[leg["id"]]
					joint_step = maxf(joint_step,(pose["knee"] as Vector2).distance_to(last["knee"]))
					if not walker.airborne and not previous_airborne and not leg["stepping"] and not last["stepping"] and pose["reachable"] and last["reachable"]:
						stance_slip = maxf(stance_slip,(pose["toe"] as Vector2).distance_to(last["toe"]))
				previous[leg["id"]] = {"toe":pose["toe"],"knee":pose["knee"],"stepping":leg["stepping"],"reachable":pose["reachable"]}
			if not walker.airborne and not previous_airborne:
				minimum_support = mini(minimum_support,supports)
				if frame >= 45 and frame < 60:
					idle_support = mini(idle_support,supports)
				if unreachable:
					unreachable_frames += 1
			previous_airborne = walker.airborne
		_require(max_length_error < .003,"range rigid lengths " + key)
		_require(stance_slip < .01,"range reachable planted toe remains fixed " + key)
		_require(ground_error < .01,"range landing target is reachable " + key)
		_require(minimum_support >= (3 if float(values["legs_up"]) < 1.5 else 2),"range maintains required supports " + key)
		print("RANGE ",JSON.stringify({"key":key,"value":configuration["value"],"idle_support":idle_support,"support_min":minimum_support,"idle_error":idle_error,"contact_error_max":ground_error,"unreachable_frames":unreachable_frames,"joint_frame_max":joint_step,"stance_slip":stance_slip,"length_error":max_length_error,"end_x":walker.body_pos.x,"right_x":right_x,"left_x":left_x,"first_unreachable":first_unreachable}))
		walker.free()
