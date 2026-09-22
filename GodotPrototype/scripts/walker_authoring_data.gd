class_name WalkerAuthoringData
extends RefCounted
## 원화 피벗과 본별 rest 대비 회전 키를 보관한다. 원화 좌표는 끝까지 raw pixel 단위다.

const Anatomy = preload("res://scripts/walker_anatomy.gd")
const DEFAULT_PATH := "res://authoring/walker_motion.json"
const FORMAT := "walker-authoring"
const VERSION := 1
const KEY_TOLERANCE := 1.0 / 120.0
const HISTORY_LIMIT := 100
const MAX_FILE_BYTES := 16 * 1024 * 1024
const BODY_KEYS := ["body.chassis", "body.pivot", "body.upper", "body.gun", "body.barrel", "body.muzzle"]
const LEG_IDS := ["FF", "FR", "NF", "NR"]
const JOINT_IDS := ["mount", "hip", "knee", "ankle", "toe"]

signal changed
signal history_changed

var points: Dictionary = {}
var clips: Dictionary = {}
var last_error := ""
var dirty := false
var _undo: Array = []
var _redo: Array = []
var _edit_depth := 0
var _edit_before: Dictionary = {}
var _saved: Dictionary = {}


func _init() -> void:
	var body := [Anatomy.BODY_ROOT, Anatomy.TORSO_PIVOT, Anatomy.UPPER_CENTER,
		Anatomy.GUN_PIVOT, Anatomy.BARREL_ANCHOR, Anatomy.MUZZLE]
	for i in BODY_KEYS.size():
		points[BODY_KEYS[i]] = body[i]
	for leg in Anatomy.LEGS:
		for joint in JOINT_IDS:
			points[String(leg["id"]) + "." + joint] = leg[joint]
	var defaults := [
		["idle", "대기", 1.5, true], ["walk", "걷기", 0.8, true],
		["run", "달리기", 0.55, true], ["jump", "점프", 1.0, false],
		["fire", "사격", 0.3, false],
	]
	for row in defaults:
		clips[row[0]] = {"name": row[1], "duration": row[2], "loop": row[3],
			"keys": [{"time": 0.0, "pose": neutral_pose(), "ease": "smooth"}]}
	_saved = snapshot()


func bone_definitions() -> Array:
	var bones: Array = [
		{"id": "chassis", "parent": "", "start": "body.chassis", "end": "body.pivot", "label": "하체 중심"},
		{"id": "torso", "parent": "chassis", "start": "body.pivot", "end": "body.upper", "label": "상체"},
		{"id": "gun", "parent": "torso", "start": "body.gun", "end": "body.barrel", "label": "포가"},
		{"id": "barrel", "parent": "gun", "start": "body.barrel", "end": "body.muzzle", "label": "총열"},
	]
	for leg_id in LEG_IDS:
		var prefix: String = leg_id + "."
		bones.append({"id": prefix + "mount", "parent": "chassis", "start": prefix + "mount", "end": prefix + "hip", "label": leg_id + " 골반 암"})
		bones.append({"id": prefix + "upper", "parent": prefix + "mount", "start": prefix + "hip", "end": prefix + "knee", "label": leg_id + " 위 마디"})
		bones.append({"id": prefix + "lower", "parent": prefix + "upper", "start": prefix + "knee", "end": prefix + "ankle", "label": leg_id + " 아래 마디"})
		bones.append({"id": prefix + "foot", "parent": prefix + "lower", "start": prefix + "ankle", "end": prefix + "toe", "label": leg_id + " 발"})
	return bones


func neutral_pose() -> Dictionary:
	var angles := {}
	for bone in bone_definitions():
		angles[bone["id"]] = 0.0
	return {"offset": Vector2.ZERO, "angles": angles}


func evaluate_pose(pose: Dictionary) -> Dictionary:
	var result := points.duplicate(true)
	var totals := {}
	var starts := {}
	var angles: Dictionary = pose.get("angles", {})
	var offset: Vector2 = pose.get("offset", Vector2.ZERO)
	for bone in bone_definitions():
		var id: String = bone["id"]
		var parent: String = bone["parent"]
		var start_key: String = bone["start"]
		var end_key: String = bone["end"]
		var parent_rotation: float = totals.get(parent, 0.0)
		var start: Vector2
		if parent.is_empty():
			start = (points[start_key] as Vector2) + offset
		else:
			var parent_start: String = starts[parent]
			start = (result[parent_start] as Vector2) + ((points[start_key] as Vector2) - (points[parent_start] as Vector2)).rotated(parent_rotation)
		var rotation := parent_rotation + float(angles.get(id, 0.0))
		result[start_key] = start
		result[end_key] = start + ((points[end_key] as Vector2) - (points[start_key] as Vector2)).rotated(rotation)
		totals[id] = rotation
		starts[id] = start_key
	return result


func pose_from_points(raw_points: Dictionary) -> Dictionary:
	var pose := neutral_pose()
	pose["offset"] = (raw_points.get("body.chassis", points["body.chassis"]) as Vector2) - (points["body.chassis"] as Vector2)
	var totals := {}
	for bone in bone_definitions():
		var start: String = bone["start"]
		var end: String = bone["end"]
		var rest: Vector2 = (points[end] as Vector2) - (points[start] as Vector2)
		var direction: Vector2 = (raw_points.get(end, points[end]) as Vector2) - (raw_points.get(start, points[start]) as Vector2)
		var parent_total: float = totals.get(bone["parent"], 0.0)
		var total := wrapf(direction.angle() - rest.angle(), -PI, PI) if direction.length_squared() > 0.000001 else parent_total
		pose["angles"][bone["id"]] = wrapf(total - parent_total, -PI, PI)
		totals[bone["id"]] = total
	return pose


func sample(clip_id: String, time: float) -> Dictionary:
	if not clips.has(clip_id):
		return neutral_pose()
	var clip: Dictionary = clips[clip_id]
	var keys: Array = (clip.get("keys", []) as Array).duplicate()
	if keys.is_empty():
		return neutral_pose()
	keys.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	if keys.size() == 1:
		return _complete_pose(keys[0]["pose"])
	var duration := maxf(float(clip["duration"]), 0.0001)
	var looping := bool(clip["loop"])
	var at := fposmod(time, duration) if looping else clampf(time, 0.0, duration)
	if not looping:
		if at <= float(keys[0]["time"]):
			return _complete_pose(keys[0]["pose"])
		if at >= float(keys[-1]["time"]):
			return _complete_pose(keys[-1]["pose"])
	var left: Dictionary = keys[-1]
	var right: Dictionary = keys[0]
	var left_time := float(left["time"])
	var right_time := float(right["time"]) + duration
	if at < float(keys[0]["time"]):
		left_time -= duration
		right_time -= duration
	else:
		for i in range(keys.size() - 1):
			if at >= float(keys[i]["time"]) and at < float(keys[i + 1]["time"]):
				left = keys[i]
				right = keys[i + 1]
				left_time = float(left["time"])
				right_time = float(right["time"])
				break
	var weight := clampf((at - left_time) / maxf(right_time - left_time, 0.000001), 0.0, 1.0)
	match String(left.get("ease", "smooth")):
		"hold": weight = 0.0
		"smooth": weight = weight * weight * (3.0 - 2.0 * weight)
	var a := _complete_pose(left["pose"])
	var b := _complete_pose(right["pose"])
	var result := neutral_pose()
	result["offset"] = (a["offset"] as Vector2).lerp(b["offset"], weight)
	for id in result["angles"]:
		result["angles"][id] = lerp_angle(float(a["angles"][id]), float(b["angles"][id]), weight)
	return result


func _complete_pose(pose: Dictionary) -> Dictionary:
	var result := neutral_pose()
	result["offset"] = pose.get("offset", Vector2.ZERO)
	var angles: Dictionary = pose.get("angles", {})
	for id in result["angles"]:
		result["angles"][id] = float(angles.get(id, 0.0))
	return result


func set_key(clip_id: String, time: float, pose: Dictionary, ease: String = "smooth") -> bool:
	if not clips.has(clip_id) or not is_finite(time) or ease not in ["smooth", "linear", "hold"] or not _valid_pose(pose):
		last_error = "키의 동작, 시간, 포즈 또는 보간 방식이 올바르지 않습니다."
		return false
	begin_edit()
	var clip: Dictionary = clips[clip_id]
	var at := clampf(time, 0.0, float(clip["duration"]))
	var keys: Array = clip["keys"]
	var key := {"time": at, "pose": _complete_pose(pose), "ease": ease}
	var index := _key_index(keys, at)
	if index >= 0:
		keys[index] = key
	else:
		keys.append(key)
	keys.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	end_edit()
	last_error = ""
	return true


func delete_key(clip_id: String, time: float) -> bool:
	if not clips.has(clip_id):
		return false
	var keys: Array = clips[clip_id]["keys"]
	var index := _key_index(keys, time)
	if index < 0:
		return false
	begin_edit()
	keys.remove_at(index)
	end_edit()
	return true


func _key_index(keys: Array, time: float) -> int:
	var result := -1
	var distance := KEY_TOLERANCE + 0.000001
	for i in keys.size():
		var error := absf(float(keys[i]["time"]) - time)
		if error < distance:
			distance = error
			result = i
	return result


func add_clip(clip_name: String) -> String:
	begin_edit()
	var index := 1
	while clips.has("clip_%d" % index):
		index += 1
	var id := "clip_%d" % index
	var label := clip_name.strip_edges()
	clips[id] = {"name": label if not label.is_empty() else "새 동작", "duration": 1.0,
		"loop": true, "keys": [{"time": 0.0, "pose": neutral_pose(), "ease": "smooth"}]}
	end_edit()
	return id


func snapshot() -> Dictionary:
	return {"points": points.duplicate(true), "clips": clips.duplicate(true)}


func restore(state: Dictionary) -> bool:
	if not _valid_state(state):
		last_error = "복원할 편집 데이터가 올바르지 않습니다."
		return false
	begin_edit()
	_apply(state)
	end_edit()
	return true


func begin_edit() -> void:
	if _edit_depth == 0:
		_edit_before = snapshot()
	_edit_depth += 1


func end_edit() -> void:
	if _edit_depth <= 0:
		return
	_edit_depth -= 1
	if _edit_depth > 0:
		return
	if snapshot() != _edit_before:
		_undo.append(_edit_before)
		if _undo.size() > HISTORY_LIMIT:
			_undo.pop_front()
		_redo.clear()
		dirty = snapshot() != _saved
		changed.emit()
		history_changed.emit()
	_edit_before = {}


func can_undo() -> bool:
	return not _undo.is_empty() and _edit_depth == 0


func can_redo() -> bool:
	return not _redo.is_empty() and _edit_depth == 0


func undo() -> bool:
	if not can_undo():
		return false
	_redo.append(snapshot())
	_apply(_undo.pop_back())
	changed.emit()
	history_changed.emit()
	return true


func redo() -> bool:
	if not can_redo():
		return false
	_undo.append(snapshot())
	_apply(_redo.pop_back())
	changed.emit()
	history_changed.emit()
	return true


func _apply(state: Dictionary) -> void:
	points = (state["points"] as Dictionary).duplicate(true)
	clips = (state["clips"] as Dictionary).duplicate(true)
	dirty = snapshot() != _saved


func save(path: String = DEFAULT_PATH) -> Error:
	last_error = ""
	var state := snapshot()
	if not _valid_state(state):
		return _error(ERR_INVALID_DATA, "잘못된 피벗 또는 키프레임이 있어 저장하지 않았습니다.")
	if FileAccess.file_exists(path):
		var existing := _read_document(path)
		if existing.is_empty():
			return _error(ERR_FILE_CORRUPT, "기존 파일이 손상되었거나 다른 원화의 데이터입니다. 덮어쓰지 않았습니다: " + path)
	var absolute := ProjectSettings.globalize_path(path)
	var folder_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if folder_error != OK:
		return _error(folder_error, "저장 폴더를 만들 수 없습니다: " + path)
	var temporary := absolute + ".tmp-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _error(FileAccess.get_open_error(), "임시 저장 파일을 열 수 없습니다.")
	file.store_string(JSON.stringify(_encode(state), "\t", true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_document(temporary).is_empty():
		DirAccess.remove_absolute(temporary)
		return _error(ERR_FILE_CANT_WRITE, "임시 저장 검증에 실패하여 원본 파일을 유지했습니다.")
	if FileAccess.file_exists(absolute):
		var backup_error := DirAccess.copy_absolute(absolute, absolute + ".bak")
		if backup_error != OK:
			DirAccess.remove_absolute(temporary)
			return _error(backup_error, "백업을 만들 수 없어 원본 파일을 유지했습니다.")
	var rename_error := DirAccess.rename_absolute(temporary, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(temporary)
		return _error(rename_error, "저장 파일 교체에 실패했습니다. 기존 파일과 백업을 유지했습니다.")
	_saved = state
	dirty = false
	last_error = ""
	return OK


func load_file(path: String = DEFAULT_PATH) -> Error:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _error(ERR_FILE_NOT_FOUND, "저장 파일이 없습니다: " + path)
	var state := _read_document(path)
	if state.is_empty():
		return _error(ERR_FILE_CORRUPT, "저장 파일의 형식, 원화 또는 데이터가 올바르지 않습니다. 현재 편집 내용을 유지했습니다.")
	_apply(state)
	_saved = snapshot()
	dirty = false
	_undo.clear()
	_redo.clear()
	_edit_depth = 0
	_edit_before = {}
	changed.emit()
	history_changed.emit()
	return OK


func _error(code: Error, message: String) -> Error:
	last_error = message
	return code


func _encode(state: Dictionary) -> Dictionary:
	var encoded_points := {}
	for key in state["points"]:
		var point: Vector2 = state["points"][key]
		encoded_points[key] = [point.x, point.y]
	var encoded_clips := {}
	for id in state["clips"]:
		var clip: Dictionary = state["clips"][id]
		var keys: Array = []
		for key in clip["keys"]:
			var pose := _complete_pose(key["pose"])
			var offset: Vector2 = pose["offset"]
			keys.append({"time": key["time"], "pose": {"offset": [offset.x, offset.y], "angles": pose["angles"]}, "ease": key["ease"]})
		encoded_clips[id] = {"name": clip["name"], "duration": clip["duration"], "loop": clip["loop"], "keys": keys}
	return {"format": FORMAT, "version": VERSION,
		"source": {"path": Anatomy.SOURCE_PATH, "sha256": Anatomy.SOURCE_SHA256, "size": [Anatomy.SOURCE_SIZE.x, Anatomy.SOURCE_SIZE.y]},
		"points": encoded_points, "clips": encoded_clips}


func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {}
	var document: Dictionary = parser.data
	if document.get("format") != FORMAT or document.get("version") != VERSION:
		return {}
	var source = document.get("source")
	if not source is Dictionary or source.get("sha256") != Anatomy.SOURCE_SHA256:
		return {}
	var raw_points = document.get("points")
	var raw_clips = document.get("clips")
	if not raw_points is Dictionary or not raw_clips is Dictionary:
		return {}
	var decoded_points := {}
	for key in raw_points:
		if not _valid_pair(raw_points[key]):
			return {}
		decoded_points[key] = Vector2(float(raw_points[key][0]), float(raw_points[key][1]))
	var decoded_clips: Dictionary = raw_clips.duplicate(true)
	for id in decoded_clips:
		if not decoded_clips[id] is Dictionary or not decoded_clips[id].get("keys") is Array:
			return {}
		for key in decoded_clips[id]["keys"]:
			if not key is Dictionary or not key.get("pose") is Dictionary or not _valid_pair(key["pose"].get("offset")):
				return {}
			var pair: Array = key["pose"]["offset"]
			key["pose"]["offset"] = Vector2(float(pair[0]), float(pair[1]))
	var state := {"points": decoded_points, "clips": decoded_clips}
	return state if _valid_state(state) else {}


func _valid_pair(value) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])


func _number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) < 1000000.0


func _valid_pose(pose) -> bool:
	if not pose is Dictionary or not pose.get("offset") is Vector2 or not (pose["offset"] as Vector2).is_finite() or not pose.get("angles") is Dictionary:
		return false
	var allowed: Dictionary = neutral_pose()["angles"]
	for id in pose["angles"]:
		if not allowed.has(id) or not _number(pose["angles"][id]):
			return false
	return true


func _valid_state(state) -> bool:
	if not state is Dictionary or not state.get("points") is Dictionary or not state.get("clips") is Dictionary:
		return false
	var required: Array = BODY_KEYS.duplicate()
	for id in LEG_IDS:
		for joint in JOINT_IDS:
			required.append(id + "." + joint)
	var candidate: Dictionary = state["points"]
	if candidate.size() != required.size():
		return false
	for key in required:
		if not candidate.has(key) or not candidate[key] is Vector2 or not (candidate[key] as Vector2).is_finite():
			return false
		var point: Vector2 = candidate[key]
		if absf(point.x) >= 1000000.0 or absf(point.y) >= 1000000.0:
			return false
	for bone in bone_definitions():
		if (candidate[bone["start"]] as Vector2).distance_to(candidate[bone["end"]]) < 0.01:
			return false
	var candidates: Dictionary = state["clips"]
	if candidates.size() > 200:
		return false
	for id in candidates:
		var clip = candidates[id]
		if not id is String or id.is_empty() or not clip is Dictionary:
			return false
		if not clip.get("name") is String or not _number(clip.get("duration")) or float(clip["duration"]) <= 0.0 or float(clip["duration"]) > 600.0 or not clip.get("loop") is bool or not clip.get("keys") is Array:
			return false
		var keys: Array = clip["keys"]
		if keys.size() > 10000:
			return false
		var times: Array[float] = []
		for key in keys:
			if not key is Dictionary or not _number(key.get("time")) or not _valid_pose(key.get("pose")) or key.get("ease") not in ["smooth", "linear", "hold"]:
				return false
			var time := float(key["time"])
			if time < 0.0 or time > float(clip["duration"]):
				return false
			for previous in times:
				if absf(previous - time) < 0.000001:
					return false
			times.append(time)
	return true
