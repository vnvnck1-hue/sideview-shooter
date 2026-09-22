extends SceneTree
## Headless authoring-model checks; all disk fixtures are temporary project-cache files.
const Model = preload("res://scripts/walker_authoring_data.gd")
var _checks := 0
var _failures: Array[String] = []
var _folder := ""


func _initialize() -> void:
	_run.call_deferred()


func _require(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _close(a: Vector2, b: Vector2, tolerance := 0.001) -> bool:
	return a.distance_to(b) < tolerance


func _run() -> void:
	_defaults_and_fk()
	_sampling()
	_history()
	_persistence()
	for failure in _failures:
		print("FAIL: ", failure)
	print("WALKER AUTHORING DATA: %d checks; %s" % [_checks, "PASS" if _failures.is_empty() else "%d failures" % _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _defaults_and_fk() -> void:
	var model := Model.new()
	_require(model.points.size() == 26, "default source has all 26 pivots")
	_require(model.bone_definitions().size() == 20, "default hierarchy has 20 bones")
	_require(model.clips.size() == 5 and model.clips.has("fire") and model.clips.has("jump"), "five motion clips initialized")
	_require(not model.dirty and not model.can_undo(), "new document is clean")
	var neutral := model.evaluate_pose(model.neutral_pose())
	for key in model.points:
		_require(_close(neutral[key], model.points[key]), "neutral source pivot " + key)
	var root: Vector2 = model.points["body.chassis"]
	var pose := model.neutral_pose()
	pose["offset"] = Vector2(12, -35)
	pose["angles"]["chassis"] = PI / 2.0
	var rotated := model.evaluate_pose(pose)
	for key in model.points:
		var expected := root + Vector2(12, -35) + ((model.points[key] as Vector2) - root).rotated(PI / 2.0)
		_require(_close(rotated[key], expected), "root rotation carries pivot/attachment " + key)
	pose["angles"]["torso"] = -0.35
	pose["angles"]["gun"] = 0.42
	pose["angles"]["barrel"] = -0.29
	pose["angles"]["FF.mount"] = 0.11
	pose["angles"]["FF.upper"] = -0.21
	pose["angles"]["FF.lower"] = 0.63
	pose["angles"]["FF.foot"] = -0.18
	var output := model.evaluate_pose(pose)
	for bone in model.bone_definitions():
		var rest_length: float = (model.points[bone["start"]] as Vector2).distance_to(model.points[bone["end"]])
		var animated: float = (output[bone["start"]] as Vector2).distance_to(output[bone["end"]])
		_require(absf(rest_length - animated) < 0.001, "FK fixed length " + bone["id"])
	var recovered := model.evaluate_pose(model.pose_from_points(output))
	for key in output:
		_require(_close(recovered[key], output[key]), "capture/FK round trip " + key)
	model.set_key("walk", 0.3, pose)
	var old_angles: Dictionary = model.clips["walk"]["keys"][1]["pose"]["angles"].duplicate(true)
	model.begin_edit()
	model.points["FF.knee"] += Vector2(23, -17)
	model.end_edit()
	_require(model.clips["walk"]["keys"][1]["pose"]["angles"] == old_angles, "editing pivot preserves animation deltas")
	var altered := model.evaluate_pose(pose)
	var expected_length: float = (model.points["FF.hip"] as Vector2).distance_to(model.points["FF.knee"])
	_require(absf((altered["FF.hip"] as Vector2).distance_to(altered["FF.knee"]) - expected_length) < 0.001, "edited anatomy defines new fixed length")
	# A gun attachment is offset from the torso pivot; it must follow the torso even though it is not its endpoint.
	var only_torso := model.neutral_pose()
	only_torso["angles"]["torso"] = 0.5
	var torso_result := model.evaluate_pose(only_torso)
	var expected_gun: Vector2 = model.points["body.pivot"] + ((model.points["body.gun"] as Vector2) - (model.points["body.pivot"] as Vector2)).rotated(0.5)
	_require(_close(torso_result["body.gun"], expected_gun), "offset gun mount follows torso")


func _sampling() -> void:
	var model := Model.new()
	model.clips["walk"]["duration"] = 1.0
	model.clips["walk"]["loop"] = false
	var a := model.neutral_pose()
	var b := model.neutral_pose()
	a["angles"]["gun"] = deg_to_rad(170.0)
	b["angles"]["gun"] = deg_to_rad(-170.0)
	b["offset"] = Vector2(100, 40)
	model.set_key("walk", 0.0, a, "linear")
	model.set_key("walk", 1.0, b, "smooth")
	var middle := model.sample("walk", 0.5)
	_require(absf(absf(wrapf(middle["angles"]["gun"], -PI, PI)) - PI) < 0.0001, "rotation interpolation takes shortest arc")
	_require(_close(middle["offset"], Vector2(50, 20)), "linear translation")
	_require(_close(model.sample("walk", -3)["offset"], Vector2.ZERO), "nonloop time before first key clamps")
	_require(_close(model.sample("walk", 4)["offset"], Vector2(100, 40)), "nonloop time after final key clamps")
	model.set_key("walk", 0.0, a, "smooth")
	_require(_close(model.sample("walk", 0.25)["offset"], Vector2(15.625, 6.25)), "smooth ease has known quarter-time value")
	model.set_key("walk", 0.0, a, "hold")
	_require(_close(model.sample("walk", 0.999)["offset"], Vector2.ZERO), "hold keeps previous pose")
	_require(_close(model.sample("walk", 1.0)["offset"], Vector2(100, 40)), "hold changes exactly at next key")
	model.clips["walk"]["loop"] = true
	model.clips["walk"]["keys"] = []
	model.set_key("walk", 0.25, a, "linear")
	model.set_key("walk", 0.75, b, "linear")
	_require(_close(model.sample("walk", 0.0)["offset"], Vector2(50, 20)), "loop interpolates across seam before first key")
	_require(_close(model.sample("walk", 1.0)["offset"], Vector2(50, 20)), "loop seam repeats")
	_require(_close(model.sample("walk", -0.125)["offset"], model.sample("walk", 0.875)["offset"]), "negative loop time wraps")
	_require(model.set_key("walk", 0.754, a), "nearby key replaces within tolerance")
	_require(model.clips["walk"]["keys"].size() == 2, "key replacement does not add duplicate")
	_require(model.delete_key("walk", 0.75), "key deletion uses same tolerance")
	_require(not model.delete_key("walk", 0.6), "delete outside tolerance is harmless")
	var empty_id := model.add_clip("새 테스트 동작")
	model.delete_key(empty_id, 0.0)
	_require(model.sample(empty_id, 0.5) == model.neutral_pose(), "empty clip samples neutral")
	_require(model.sample("missing", 0.5) == model.neutral_pose(), "missing clip samples neutral")
	var invalid := model.neutral_pose()
	invalid["angles"]["not_a_bone"] = 0.3
	_require(not model.set_key("walk", 0.5, invalid), "unknown bone key is rejected")
	_require(not model.set_key("walk", NAN, a), "nonfinite key time rejected")


func _history() -> void:
	var model := Model.new()
	var before := model.snapshot()
	model.begin_edit()
	for i in range(25):
		model.points["NF.hip"] += Vector2(0.5, -0.2)
	model.begin_edit()
	var pose := model.neutral_pose()
	pose["angles"]["torso"] = 0.45
	model.set_key("idle", 0.4, pose)
	model.end_edit()
	_require(not model.can_undo(), "open edit transaction cannot undo halfway")
	model.end_edit()
	var after := model.snapshot()
	_require(model.dirty and model.can_undo(), "drag transaction is dirty and undoable")
	_require(model.undo() and model.snapshot() == before, "one undo restores whole drag and nested key edit")
	_require(not model.dirty and not model.can_undo(), "undo back to initial saved state is clean")
	_require(model.redo() and model.snapshot() == after, "redo restores complete transaction")
	model.undo()
	model.add_clip("새 분기")
	_require(not model.can_redo(), "new edit after undo clears redo branch")
	var clone := model.snapshot()
	clone["points"]["NF.hip"] = Vector2.ZERO
	_require(model.points["NF.hip"] != Vector2.ZERO, "snapshot is deeply independent")
	var current := model.snapshot()
	_require(not model.restore({"points": {}, "clips": {}}) and model.snapshot() == current, "invalid restore preserves current document")
	model.begin_edit()
	model.end_edit()
	_require(model.snapshot() == current, "empty transaction does not change document")


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _persistence() -> void:
	_folder = "res://.godot/walker-authoring-test-" + str(Time.get_ticks_usec())
	var path := _folder + "/motion.json"
	var model := Model.new()
	var initial := model.snapshot()
	_require(model.load_file(path) == ERR_FILE_NOT_FOUND and model.snapshot() == initial, "missing load preserves defaults")
	_require(model.save(path) == OK, "first save creates directory and file")
	var original_text := FileAccess.get_file_as_string(path)
	var original_doc: Dictionary = JSON.parse_string(original_text)
	_require(original_doc["source"]["sha256"] == Model.Anatomy.SOURCE_SHA256, "saved JSON identifies original artwork hash")
	_require(original_doc["points"]["NF.hip"] is Array and original_doc["clips"]["idle"]["keys"][0]["pose"]["offset"] is Array, "vectors are JSON arrays")
	model.begin_edit()
	model.points["body.gun"] += Vector2(-13.25, 7.5)
	model.end_edit()
	var pose := model.neutral_pose()
	pose["offset"] = Vector2(8.125, -11.5)
	pose["angles"]["FR.lower"] = -0.314
	model.set_key("jump", 0.6, pose, "linear")
	var changed := model.snapshot()
	_require(model.save(path) == OK, "second save atomically replaces existing file")
	_require(FileAccess.get_file_as_string(path + ".bak") == original_text, "backup preserves immediately previous successful file")
	_require(not model.dirty, "successful save clears dirty flag")
	var loaded := Model.new()
	_require(loaded.load_file(path) == OK and loaded.snapshot() == changed, "JSON load reproduces all pivots and clip keys")
	_require(not loaded.can_undo() and not loaded.dirty, "load resets history and saved baseline")
	model.undo()
	_require(model.dirty, "undo away from saved state is dirty")
	model.redo()
	_require(not model.dirty, "redo to saved state is clean")
	var good_text := FileAccess.get_file_as_string(path)
	var malformed := "{\"format\": \"walker-authoring\", \"points\":"
	_write(path, malformed)
	var before := loaded.snapshot()
	_require(loaded.load_file(path) == ERR_FILE_CORRUPT and loaded.snapshot() == before, "truncated file never partially applies")
	_require(loaded.save(path) == ERR_FILE_CORRUPT and FileAccess.get_file_as_string(path) == malformed, "save refuses to overwrite corrupted existing file")
	var corruptions: Array = []
	var wrong_source: Dictionary = JSON.parse_string(good_text)
	wrong_source["source"]["sha256"] = "another-artwork"
	corruptions.append(wrong_source)
	var missing_pivot: Dictionary = JSON.parse_string(good_text)
	missing_pivot["points"].erase("FR.toe")
	corruptions.append(missing_pivot)
	var unknown_bone: Dictionary = JSON.parse_string(good_text)
	unknown_bone["clips"]["idle"]["keys"][0]["pose"]["angles"]["mystery"] = 0.2
	corruptions.append(unknown_bone)
	var duplicate: Dictionary = JSON.parse_string(good_text)
	duplicate["clips"]["idle"]["keys"].append(duplicate["clips"]["idle"]["keys"][0].duplicate(true))
	corruptions.append(duplicate)
	var bad_time: Dictionary = JSON.parse_string(good_text)
	bad_time["clips"]["jump"]["keys"][0]["time"] = -1.0
	corruptions.append(bad_time)
	var bad_vector: Dictionary = JSON.parse_string(good_text)
	bad_vector["points"]["NF.hip"] = ["x", 2]
	corruptions.append(bad_vector)
	for document in corruptions:
		_write(path, JSON.stringify(document))
		_require(loaded.load_file(path) == ERR_FILE_CORRUPT and loaded.snapshot() == before, "invalid source/schema/key rejects entire document")
	_write(path, good_text)
	loaded.points["FF.hip"] = Vector2(NAN, 0)
	_require(loaded.save(path) == ERR_INVALID_DATA and FileAccess.get_file_as_string(path) == good_text, "nonfinite in-memory pivot cannot replace valid file")
	# Remove only this run's known files inside its generated cache directory.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_folder))
