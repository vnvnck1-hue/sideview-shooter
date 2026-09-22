extends SceneTree
## Actual textured-game-walker tuning lab at 1280x720 and 2240x900.
## Never saves a document. Run with a renderer, without --headless.

const OUT := "res://tools/artifacts/walker_tuning/"
const DEMO_PATH := OUT + "nonexistent.json"
const STEP := 1.0 / 60.0
const STILLS := {40: "01_game_walker_1280", 110: "02_walking_1280", 150: "03_bones_overlay_1280",
	180: "04_step_parameters_1280", 210: "05_joint_parameters_1280", 240: "06_wide_2240"}
## 넓은 발 벌림과 긴 스텝의 접지 보정을 눈으로 확인하는 선택 모드입니다. 기본 캡처는 그대로 둡니다.
const STRIDE_STILLS := {40: "11_wide_stride_stand_1280", 110: "12_wide_stride_walk_1280",
	150: "13_wide_stride_bones_1280", 180: "14_wide_stride_walk_late_1280",
	210: "15_wide_stride_bones_late_1280", 240: "16_wide_stride_run_2240"}
const STRIDE_VALUES := {"stride": 1.35, "step_time": 0.40, "run_step_time": 0.32, "lead": 0.35}
## 사격 반동 확인 모드. 저장된 설정 그대로 제자리에서 연사시키고 **연속 프레임**을 찍는다 —
## 몸통이 한 발마다 앞뒤로 튀는지는 한 장으로는 볼 수 없다.
## 20: 쏘기 직전, 30~60: 밀림이 쌓이는 동안, 100~102: 충분히 쌓인 뒤 연속 프레임.
const RECOIL_STILLS := {20: "21_recoil_before", 40: "22_recoil_early", 70: "23_recoil_mid",
	100: "24_recoil_full", 101: "25_recoil_full_next", 102: "26_recoil_full_next2"}
const PROTECTED := ["res://authoring/walker_motion.json", "res://authoring/walker_gait.json", "res://assets/reference/walker_original.png"]

var _viewport: SubViewport
var _lab: Node2D
var _frame := 0
var _waiting := 0
var _prepared := false
var _metadata: Array[Dictionary] = []
var _before: Dictionary = {}
var _stride := OS.get_cmdline_user_args().has("wide_stride")
var _recoil := OS.get_cmdline_user_args().has("recoil")
var _stills: Dictionary = {}


func _initialize() -> void:
	if FileAccess.file_exists(DEMO_PATH):
		push_error("Tuning capture requires its demo document path to be absent")
		quit(1)
		return
	_stills = RECOIL_STILLS if _recoil else (STRIDE_STILLS if _stride else STILLS)
	_before = _hashes()
	root.hide()
	root.size = Vector2i(1280, 720)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(_viewport)
	var scene := load(AppFlow.WALKER_LAB_SCENE) as PackedScene
	if scene == null:
		push_error("Tuning lab is not ready to capture")
		quit(1)
		return
	_lab = scene.instantiate()
	_lab.set("settings_path", DEMO_PATH)
	_lab.set("auto_drive", true)
	_viewport.add_child(_lab)
	DirAccess.make_dir_recursive_absolute(OUT)
	var ignore := FileAccess.open(OUT + ".gdignore", FileAccess.WRITE)
	if ignore != null: ignore.close()


func _process(_delta: float) -> bool:
	if _lab == null: return true
	if not _prepared:
		_waiting += 1
		if not _lab.is_node_ready() or _lab.get("_panel") == null:
			if _waiting > 90:
				push_error("Tuning lab did not initialize")
				quit(1)
				return true
			return false
		_lab.set_physics_process(false)
		(_lab.get("_rig") as Node2D).set_process(false)
		if _stride:
			for key in STRIDE_VALUES:
				_lab.call("_command", "param", {"key": key, "value": STRIDE_VALUES[key]})
		_prepared = true
		return false
	if _stills.has(_frame):
		if not _save(String(_stills[_frame]) + ".png"):
			quit(1)
			return true
	if _frame >= (102 if _recoil else 240):
		var unchanged := _before == _hashes()
		var name := "capture_metadata.json"
		if _recoil: name = "capture_metadata_recoil.json"
		elif _stride: name = "capture_metadata_wide_stride.json"
		var file := FileAccess.open(OUT + name, FileAccess.WRITE)
		if file == null:
			quit(1)
			return true
		file.store_string(JSON.stringify({"description": "Actual textured game-walker tuning lab; isolated absent settings path; all edits in memory.",
			"applied_values": STRIDE_VALUES if _stride else {},
			"protected_sha256_before": _before, "protected_sha256_after": _hashes(),
			"protected_files_unchanged": unchanged, "demo_document_created": FileAccess.file_exists(DEMO_PATH),
			"captures": _metadata}, "\t"))
		file.close()
		print("TUNING CAPTURE: protected unchanged=%s; demo document exists=%s" % [unchanged, FileAccess.file_exists(DEMO_PATH)])
		quit(0 if unchanged and not FileAccess.file_exists(DEMO_PATH) else 1)
		return true
	_frame += 1
	if _recoil:
		# 조준·발사는 랩의 입력 경로 대신 여기서 직접 넣는다 (헤드리스 입력이 없다).
		_lab.get("_walker").set("aim_target", (_lab.get("_walker").get("body_pos") as Vector2) + Vector2(900.0, -60.0))
		_lab.get("_walker").set("firing", _frame > 12)
		_lab.call("step", STEP)
		(_lab.get("_rig") as Node2D).call("_process", STEP)
		RenderingServer.force_draw(false, STEP)
		return false
	if _frame == 41: _lab.call("_command", "preview", -1)
	if _frame == 111: _lab.call("_command", "bones", true)
	if _frame == 151:
		_lab.call("_command", "preview", 0)
		_lab.call("_command", "bones", _stride)
		(_lab.get("_panel") as Control).get("_tabs").current_tab = 1
	if _frame == 181:
		(_lab.get("_panel") as Control).get("_tabs").current_tab = 3
	if _frame == 211:
		_viewport.size = Vector2i(2240, 900)
		(_lab.get("_panel") as Control).get("_tabs").current_tab = 4
		_lab.call("_command", "preview", 1)
		_lab.call("_command", "run", true)
		_lab.call("_command", "bones", _stride)
	_lab.call("step", STEP)
	(_lab.get("_rig") as Node2D).call("_process", STEP)
	RenderingServer.force_draw(false, STEP)
	return false


func _save(filename: String) -> bool:
	var picture := _viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("Tuning capture requires an active renderer")
		return false
	if picture.save_png(OUT + filename) != OK: return false
	var panel := _lab.get("_panel") as Control
	var bounds: Dictionary = {}
	var outside: Array[String] = []
	for key in ["_top", "_side", "_bottom"]:
		var control := panel.get(key) as Control
		var rect := control.get_global_rect()
		bounds[key] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		if not Rect2(Vector2.ZERO, Vector2(_viewport.size)).encloses(rect): outside.append(key)
	var rig := _lab.get("_rig") as Node2D
	var points: Array[Vector2] = []
	_sprite_corners(rig, points)
	var robot := Rect2()
	if not points.is_empty():
		robot = Rect2(points[0], Vector2.ZERO)
		for point in points: robot = robot.expand(point)
	_metadata.append({"file": filename, "viewport": [_viewport.size.x, _viewport.size.y],
		"panel_bounds": bounds, "outside_viewport": outside,
		"robot_screen_bounds": [robot.position.x, robot.position.y, robot.size.x, robot.size.y],
		"textured_sprite_count": points.size() / 4})
	print("  %s; robot height %.1fpx; outside=%s" % [filename, robot.size.y, str(outside)])
	return true


func _sprite_corners(node: Node, points: Array[Vector2]) -> void:
	if node is Sprite2D and node.is_visible_in_tree() and node.texture != null:
		var sprite := node as Sprite2D
		var rect := sprite.get_rect()
		var transform := sprite.get_global_transform_with_canvas()
		for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			points.append(transform * point)
	for child in node.get_children(): _sprite_corners(child, points)


func _hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in PROTECTED:
		result[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	return result
