class_name WalkerGaitSettings
extends RefCounted
## 테스트 장면과 인게임이 공유하는 보행 수치. 기체/원화 피벗 데이터와 독립적이다.

const DEFAULT_PATH := "res://authoring/walker_gait.json"
const FORMAT := "walker-gait"
const VERSION := 1
const MAX_FILE_BYTES := 65536

var values: Dictionary = defaults()
var last_error := ""
var _saved: Dictionary = defaults()
var dirty: bool:
	get:
		return values != _saved


static func definitions() -> Array:
	return [
		{"key":"speed", "label":"이동 속도", "group":"이동과 자세", "min":80.0, "max":500.0, "step":10.0, "default":340.0, "unit":"px/s", "hint":"걷기 최고 속도입니다. 실제 속도는 지지 다리의 도달 범위에 맞춰 제한됩니다."},
		{"key":"ride", "label":"몸 높이", "group":"이동과 자세", "min":140.0, "max":240.0, "step":0.01, "default":211.25, "unit":"px", "hint":"몸 중심과 가까운 쪽 바닥 사이의 높이입니다. 뼈 길이는 바뀌지 않습니다."},
		{"key":"stride", "label":"발 벌림", "group":"이동과 자세", "min":0.6, "max":1.35, "step":0.01, "default":1.0, "unit":"배", "hint":"원래 발 위치의 앞뒤 간격을 배율로 조절합니다. 넓힐수록 다리의 이동 여유가 줄어듭니다."},
		{"key":"trigger", "label":"스텝 시작 오차", "group":"발 디딤", "min":0.0, "max":45.0, "step":1.0, "default":0.0, "unit":"px", "hint":"발이 기준 위치보다 이만큼 뒤처지면 다음 스텝을 시작합니다. 도달 한계가 가까우면 먼저 옮깁니다."},
		{"key":"lift", "label":"발 들기 높이", "group":"발 디딤", "min":4.0, "max":65.0, "step":1.0, "default":27.0, "unit":"px", "hint":"이동 스텝의 발 궤적 높이입니다. 정지 중 발 정렬에는 더 낮은 높이를 사용합니다."},
		{"key":"step_time", "label":"걷기 스텝 시간", "group":"발 디딤", "min":0.10, "max":0.40, "step":0.01, "default":0.18, "unit":"초", "hint":"발을 들고 내려놓는 시간입니다. 이미 시작한 스텝의 진행률은 유지됩니다."},
		{"key":"run_step_time", "label":"달리기 스텝 시간", "group":"발 디딤", "min":0.08, "max":0.32, "step":0.01, "default":0.14, "unit":"초", "hint":"달리는 동안의 발 스윙 시간입니다."},
		{"key":"hold", "label":"모든 발 접지 대기", "group":"발 디딤", "min":0.0, "max":0.18, "step":0.001, "default":0.015, "unit":"초", "hint":"스텝 사이에 모든 발을 바닥에 두는 시간입니다."},
		{"key":"lead", "label":"착지 위치 선행", "group":"발 디딤", "min":0.05, "max":0.35, "step":0.001, "default":0.189, "unit":"초", "hint":"속도 × 이 시간만큼 앞에 발을 놓습니다. 달리기는 스텝 시간 비율을 함께 적용합니다."},
		{"key":"legs_up", "label":"동시에 드는 발", "group":"발 디딤", "min":1.0, "max":2.0, "step":1.0, "default":2.0, "unit":"개", "hint":"1개는 세 발 지지 순차 보행, 2개는 대각선 쌍 교대 보행입니다."},
		{"key":"tilt", "label":"지형 기울기 추종", "min":0.0, "max":1.0, "step":0.01, "default":0.0, "group":"몸 움직임", "unit":"배", "hint":"경사진 바닥에 몸을 얼마나 기울일지 정합니다."},
		{"key":"bob", "label":"상하 리듬", "group":"몸 움직임", "min":0.0, "max":14.0, "step":0.1, "default":4.0, "unit":"px", "hint":"걸음에 맞춘 몸통의 상하 움직임입니다."},
		{"key":"aim_lean", "label":"조준 몸 기울기", "group":"몸 움직임", "min":0.0, "max":0.8, "step":0.01, "default":0.5, "unit":"배", "hint":"위아래 조준에 몸이 반응하는 양입니다. 포탑의 독립 조준은 유지됩니다."},
		{"key":"coxa_yaw_bias", "label":"골반 앞뒤 각도", "group":"관절 각도", "min":-30.0, "max":30.0, "step":1.0, "default":0.0, "unit":"°", "hint":"몸통에 붙은 첫 마디의 수평 회전 기준을 조절합니다."},
		{"key":"coxa_pitch_bias", "label":"골반 위아래 각도", "group":"관절 각도", "min":-20.0, "max":20.0, "step":1.0, "default":0.0, "unit":"°", "hint":"첫 마디의 위아래 회전 기준을 조절합니다. 발 접지는 IK가 유지합니다."},
		{"key":"knee_swivel", "label":"무릎 벌림 각도", "group":"관절 각도", "min":-65.0, "max":65.0, "step":1.0, "default":0.0, "unit":"°", "hint":"고관절과 발목을 잇는 축 주위로 무릎을 돌립니다. 뼈 길이와 접점은 그대로입니다."},
		{"key":"yaw_limit", "label":"골반 수평 회전 범위", "group":"관절 범위", "min":20.0, "max":85.0, "step":1.0, "default":65.0, "unit":"°", "hint":"원래 골반 방향에서 좌우로 허용하는 회전 범위입니다."},
		{"key":"pitch_limit", "label":"골반 수직 회전 범위", "group":"관절 범위", "min":5.0, "max":35.0, "step":1.0, "default":20.0, "unit":"°", "hint":"원래 골반 방향에서 위아래로 허용하는 회전 범위입니다."},
	]


static func defaults() -> Dictionary:
	var result := {}
	for definition in definitions():
		result[definition["key"]] = float(definition["default"])
	return result


func set_value(key: String, value: float) -> bool:
	for definition in definitions():
		if definition["key"] != key:
			continue
		if not _valid_value(definition, value):
			last_error = "%s 값이 허용 범위를 벗어났습니다." % definition["label"]
			return false
		values[key] = value
		last_error = ""
		return true
	last_error = "알 수 없는 보행 설정입니다: " + key
	return false


func reset_defaults() -> void:
	values = defaults()
	last_error = ""


static func _valid_value(definition: Dictionary, value) -> bool:
	if (not value is float and not value is int) or not is_finite(float(value)):
		return false
	if float(value) < float(definition["min"]) or float(value) > float(definition["max"]):
		return false
	return definition["key"] != "legs_up" or float(value) in [1.0, 2.0]


static func _valid_values(candidate) -> bool:
	if not candidate is Dictionary or candidate.size() != definitions().size():
		return false
	for definition in definitions():
		if not candidate.has(definition["key"]) or not _valid_value(definition, candidate[definition["key"]]):
			return false
	return true


static func validate_values(candidate) -> bool:
	return _valid_values(candidate)


func _read_document(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {}
	var document: Dictionary = parser.data
	if document.size() != 3 or document.get("format") != FORMAT or document.get("version") != VERSION or not _valid_values(document.get("values")):
		return {}
	var decoded := {}
	for key in document["values"]:
		decoded[key] = float(document["values"][key])
	return decoded


func load_file(path: String = DEFAULT_PATH) -> Error:
	if not FileAccess.file_exists(path):
		return _error(ERR_FILE_NOT_FOUND, "보행 설정 파일이 없습니다: " + path)
	var loaded := _read_document(path)
	if loaded.is_empty():
		return _error(ERR_FILE_CORRUPT, "보행 설정 파일이 손상되었거나 지원하지 않는 값이 있습니다. 현재 수치를 유지했습니다.")
	values = loaded
	_saved = values.duplicate(true)
	last_error = ""
	return OK


func save(path: String = DEFAULT_PATH) -> Error:
	if not _valid_values(values):
		return _error(ERR_INVALID_DATA, "지원하지 않는 보행 설정이 있어 저장하지 않았습니다.")
	if FileAccess.file_exists(path) and _read_document(path).is_empty():
		return _error(ERR_FILE_CORRUPT, "기존 보행 설정 파일을 읽을 수 없어 덮어쓰지 않았습니다: " + path)
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		return _error(error, "보행 설정 폴더를 만들 수 없습니다.")
	var temporary := absolute + ".tmp-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _error(FileAccess.get_open_error(), "보행 설정 임시 파일을 열 수 없습니다.")
	file.store_string(JSON.stringify({"format": FORMAT, "version": VERSION, "values": values}, "\t", true))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or _read_document(temporary).is_empty():
		DirAccess.remove_absolute(temporary)
		return _error(ERR_FILE_CANT_WRITE, "저장 검증에 실패하여 기존 파일을 유지했습니다.")
	if FileAccess.file_exists(absolute):
		error = DirAccess.copy_absolute(absolute, absolute + ".bak")
		if error != OK:
			DirAccess.remove_absolute(temporary)
			return _error(error, "보행 설정 백업을 만들 수 없어 기존 파일을 유지했습니다.")
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return _error(error, "보행 설정 파일을 교체하지 못했습니다. 기존 파일과 백업을 유지했습니다.")
	_saved = values.duplicate(true)
	last_error = ""
	return OK


func _error(code: Error, message: String) -> Error:
	last_error = message
	return code
