extends Node2D
## 원화 피벗/고정 길이 키프레임 편집. 작업 데이터는 별도 JSON으로 보관한다.
const Data = preload("res://scripts/walker_authoring_data.gd")
const EditorPanel = preload("res://scripts/walker_authoring_panel.gd")
const Anatomy = preload("res://scripts/walker_anatomy.gd")
const PARTS := ["mount", "hip", "knee", "ankle", "toe"]
const BODY_KEYS := {"chassis": "chassis", "pivot": "pivot", "upper": "upper_center", "gun": "gun", "barrel": "barrel", "muzzle": "muzzle"}
const POINT_LABELS := {"body.chassis": "C0 · 몸체 중심", "body.pivot": "T0 · 상부 회전축", "body.upper": "U0 · 상부 끝", "body.gun": "G0 · 포가 축", "body.barrel": "B0 · 포신 뿌리", "body.muzzle": "M0 · 총구"}
const PART_LABELS := {"mount": "0 · 몸체 연결", "hip": "1 · 고관절", "knee": "2 · 무릎", "ankle": "3 · 발목", "toe": "4 · 발끝"}

var lab: Node2D
var data: RefCounted
var panel: Control
var mode := "pivot"
var selected := "body.chassis"
var clip_id := "walk"
var time := 0.0
var playing := false
var filter := "all"
var storage_path := "res://authoring/walker_motion.json"
var _pose: Dictionary
var _raw: Dictionary = {}
var _anchor := Vector2.ZERO
var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false
var _panning := false
var _drag_mouse := Vector2.ZERO
var _drag_point := Vector2.ZERO
var _drag_pose: Dictionary
var _ease := "smooth"
var _status := "관절을 드래그해 원화에 맞추세요. Ctrl+S 저장"
var _font: Font
var _exit_dialog: ConfirmationDialog
var _last_mode := "pivot"
var _has_file := false
var _destination := "lobby"


func _ready() -> void:
	data = Data.new()
	var load_message := ""
	if FileAccess.file_exists(storage_path):
		var err: int = data.load_file(storage_path)
		_has_file = err == OK
		load_message = "저장한 피벗과 키프레임을 불러왔습니다." if err == OK else "불러오기 실패: " + str(data.last_error)
	_pose = data.neutral_pose()
	_anchor = Vector2(0, lab.BASE_Y - Anatomy.ground_level())
	lab._hud.hide()
	_font = lab._font
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	panel = EditorPanel.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var choices: Array = []
	for id in data.points:
		choices.append({"id": id, "label": _point_label(id)})
	var bones: Array = [{"id": "root", "label": "전체 위치"}]
	for bone in data.bone_definitions():
		bones.append({"id": bone["id"], "label": bone.get("label", bone["id"])})
	panel.setup(choices, bones)
	panel.command.connect(_command)
	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.title = "편집 내용 저장"
	_exit_dialog.dialog_text = "수정한 피벗과 키프레임을 저장하고 로비로 돌아갈까요?"
	_exit_dialog.ok_button_text = "저장하고 나가기"
	_exit_dialog.cancel_button_text = "계속 편집"
	_exit_dialog.add_button("저장 안 함", true, "discard")
	_exit_dialog.confirmed.connect(func():
		if save_document() == OK:
			_navigate())
	_exit_dialog.custom_action.connect(func(action: String):
		if action == "discard":
			_navigate())
	panel.add_child(_exit_dialog)
	_apply_anatomy()
	set_mode("pivot")
	if not load_message.is_empty():
		_status = load_message
		_refresh()


func _point_label(id: String) -> String:
	if POINT_LABELS.has(id):
		return POINT_LABELS[id]
	var parts := id.split(".")
	return parts[0] + " · " + str(PART_LABELS.get(parts[-1], parts[-1]))


func world_point(raw: Vector2) -> Vector2:
	return _anchor + Anatomy.local_point(raw)


func raw_point(world: Vector2) -> Vector2:
	return (world - _anchor) / Anatomy.SCALE + Anatomy.ORIGIN


func canvas_rect() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(24, 86, maxf(size.x - 350.0, 320.0), maxf(size.y - 280.0, 240.0))


func update_camera() -> void:
	var viewport_size := get_viewport_rect().size
	var area := canvas_rect()
	var fit := minf(area.size.x / (Anatomy.SOURCE_SIZE.x * Anatomy.SCALE), area.size.y / (Anatomy.SOURCE_SIZE.y * Anatomy.SCALE))
	var zoom := fit * _zoom
	lab._cam.zoom = Vector2.ONE * zoom
	var focus := world_point(Anatomy.SOURCE_SIZE * 0.5) + _pan
	if mode == "walk":
		focus = lab._walker.body_pos + Vector2(-20, -35)
	lab._cam.position = focus + (viewport_size * 0.5 - area.get_center()) / zoom
	lab._cam.force_update_scroll()


func set_mode(next: String) -> void:
	if next not in ["pivot", "keys", "walk"]:
		return
	_commit_numeric_input()
	_finish_drag()
	playing = false
	_last_mode = mode
	mode = next
	lab.paused = false
	lab._shots.clear()
	lab._mouse_aim = false
	lab.reference_mode = mode != "walk"
	lab._art.visible = mode != "walk"
	lab._view.show_labels = false
	lab._view.leg_filter = filter
	if mode == "walk":
		_apply_anatomy()
		lab._walker.source_rest = false
		lab._walker.body_pos.x = 0
		lab._walker.reset_pose()
		_status = "거미형 공간 관절 · 대각선 두 발씩 교대\nA/D 이동 · Shift 달리기 · Space 점프"
	elif mode == "pivot":
		if not data.points.has(selected):
			selected = "body.chassis"
		_pose = data.neutral_pose()
		_status = "관절 드래그 / 화살표 1px 이동 · 피벗은 원화 좌표로 저장됩니다."
		_show_pose()
	else:
		if not _has_bone(selected) and selected != "root":
			selected = "chassis"
		seek(time)
		_status = "뼈 끝을 드래그하면 길이를 유지하며 회전 · 현재 시간에 자동 기록"
	update_camera()
	_refresh()
	queue_redraw()


func step(delta: float) -> void:
	if mode == "keys" and playing:
		var clip: Dictionary = data.clips[clip_id]
		time += delta
		if time > float(clip["duration"]):
			if clip["loop"]:
				time = fposmod(time, float(clip["duration"]))
			else:
				time = float(clip["duration"])
				playing = false
		_pose = data.sample(clip_id, time)
		_show_pose()
	update_camera()
	_refresh()
	queue_redraw()


func _apply_anatomy() -> bool:
	var ok: bool = lab._walker.apply_anatomy(data.points)
	if not ok:
		_status = "겹친 관절을 분리해 주세요. 뼈 길이는 0보다 커야 합니다."
	return ok


func _show_pose() -> void:
	_raw = data.evaluate_pose(data.neutral_pose() if mode == "pivot" else _pose)
	var legs: Array = []
	for id in ["FF", "FR", "NF", "NR"]:
		var leg := {"id": id}
		for part in PARTS:
			leg[part] = world_point(_raw[id + "." + part])
		legs.append(leg)
	var body := {}
	for key in BODY_KEYS:
		body[BODY_KEYS[key]] = world_point(_raw["body." + key])
	body["body_angle"] = float(_pose.get("angles", {}).get("chassis", 0.0)) if mode == "keys" else 0.0
	body["torso_angle"] = body["body_angle"] + float(_pose.get("angles", {}).get("torso", 0.0)) if mode == "keys" else 0.0
	body["gun_angle"] = ((body["muzzle"] as Vector2) - (body["barrel"] as Vector2)).angle()
	lab._walker.body_pos = _anchor
	lab._walker.apply_authored_pose({"legs": legs, "body": body})
	lab._view.queue_redraw()


func _refresh() -> void:
	var clips: Array = []
	for id in data.clips:
		clips.append({"id": id, "name": data.clips[id]["name"]})
	var clip: Dictionary = data.clips[clip_id]
	var keys: Array = []
	for key in clip["keys"]:
		keys.append(float(key["time"]))
	var value := Vector2.ZERO
	if mode == "pivot":
		value = data.points.get(selected, Vector2.ZERO)
	elif selected == "root":
		value = _pose.get("offset", Vector2.ZERO)
	panel.refresh({"mode": mode, "selected": selected, "x": value.x, "y": value.y,
		"angle": rad_to_deg(float(_pose.get("angles", {}).get(selected, 0.0))),
		"clips": clips, "clip_id": clip_id, "time": time, "duration": clip["duration"],
		"loop": clip["loop"], "ease": _ease, "keys": keys, "playing": playing,
		"dirty": data.dirty, "can_undo": data.can_undo(), "can_redo": data.can_redo(),
		"status": _status, "zoom": _zoom, "filter": filter, "opacity": lab._art.modulate.a, "has_file": _has_file})


func _command(action: String, value = null) -> void:
	if action not in ["point_x", "point_y", "angle", "duration", "opacity"]:
		_commit_numeric_input()
	_finish_drag()
	match action:
		"tuning": _request_navigation("tuning")
		"mode": set_mode(str(value))
		"select":
			selected = str(value)
			queue_redraw()
		"save": save_document()
		"undo", "redo":
			playing = false
			_finish_drag()
			var changed: bool = data.undo() if action == "undo" else data.redo()
			if changed:
				if not data.clips.has(clip_id):
					clip_id = str(data.clips.keys()[0])
				time = minf(time, float(data.clips[clip_id]["duration"]))
				_apply_anatomy()
				seek(time)
				if mode == "pivot":
					_show_pose()
				_status = "실행 취소" if action == "undo" else "다시 실행"
		"point_x", "point_y":
			if mode == "pivot" or (mode == "keys" and selected == "root"):
				playing = false
				data.begin_edit()
				if mode == "pivot":
					var point: Vector2 = data.points[selected]
					point.x = float(value) if action == "point_x" else point.x
					point.y = float(value) if action == "point_y" else point.y
					_replace_point(selected, point)
				else:
					var offset: Vector2 = _pose.get("offset", Vector2.ZERO)
					offset.x = float(value) if action == "point_x" else offset.x
					offset.y = float(value) if action == "point_y" else offset.y
					_pose["offset"] = offset
					_record()
				data.end_edit()
				_show_pose()
		"angle":
			if mode == "keys" and _has_bone(selected):
				playing = false
				data.begin_edit()
				_pose["angles"][selected] = deg_to_rad(float(value))
				_record()
				data.end_edit()
				_show_pose()
		"clip":
			if data.clips.has(str(value)):
				clip_id = str(value)
				time = 0.0
				set_mode("keys")
		"add_clip":
			if str(value).strip_edges().is_empty():
				return
			data.begin_edit()
			clip_id = data.add_clip(str(value))
			data.end_edit()
			time = 0.0
			set_mode("keys")
		"duration":
			var last_key := 0.0
			for key in data.clips[clip_id]["keys"]:
				last_key = maxf(last_key, float(key["time"]))
			if float(value) < last_key:
				_status = "마지막 키보다 짧게 만들 수 없습니다. 끝의 키를 먼저 옮기거나 삭제하세요."
			else:
				data.begin_edit()
				data.clips[clip_id]["duration"] = clampf(float(value), 0.1, 60.0)
				data.end_edit()
				seek(time)
		"loop":
			data.begin_edit()
			data.clips[clip_id]["loop"] = bool(value)
			data.end_edit()
			seek(time)
		"ease":
			_ease = str(value)
			data.begin_edit()
			for key in data.clips[clip_id]["keys"]:
				if absf(float(key["time"]) - time) < 1.0 / 120.0:
					key["ease"] = _ease
			data.end_edit()
		"seek": seek(float(value))
		"record":
			if mode == "keys":
				playing = false
				data.begin_edit()
				_record()
				data.end_edit()
		"delete_key":
			data.begin_edit()
			data.delete_key(clip_id, time)
			data.end_edit()
			seek(time)
		"move_key":
			var from: float = value["from"]
			var to := clampf(float(value["to"]), 0.0, float(data.clips[clip_id]["duration"]))
			var source: Dictionary = {}
			for key in data.clips[clip_id]["keys"]:
				if absf(float(key["time"]) - from) < 0.001:
					source = key
				elif absf(float(key["time"]) - to) < 1.0 / 120.0:
					_status = "그 시간에는 이미 키가 있습니다. 빈 시간으로 옮겨 주세요."
					return
			if not source.is_empty():
				data.begin_edit()
				source["time"] = to
				data.clips[clip_id]["keys"].sort_custom(func(a, b): return a["time"] < b["time"])
				data.end_edit()
				seek(to)
				_status = "키 타이밍 이동 · %.2f → %.2f초" % [from, to]
		"play":
			if mode != "keys":
				set_mode("keys")
			playing = bool(value)
			if playing and time >= float(data.clips[clip_id]["duration"]):
				time = 0.0
		"prev_key", "next_key": _jump_key(action == "next_key")
		"neutral":
			if mode == "keys":
				playing = false
				data.begin_edit()
				_pose = data.neutral_pose()
				_record()
				data.end_edit()
				_show_pose()
		"capture": _capture_walk()
		"opacity":
			lab._art.modulate.a = clampf(float(value), 0.0, 1.0)
		"filter":
			filter = str(value)
			if not _visible(selected):
				var choices: Array = data.points.keys() if mode == "pivot" else ["root"]
				if mode != "pivot":
					for bone in data.bone_definitions():
						choices.append(bone["id"])
				for id in choices:
					if _visible(id):
						selected = id
						break
			lab._view.leg_filter = filter
			lab._view.queue_redraw()
		"fit":
			_zoom = 1.0
			_pan = Vector2.ZERO
	_refresh()
	queue_redraw()


func seek(next_time: float) -> void:
	_finish_drag()
	playing = false
	time = clampf(next_time, 0.0, float(data.clips[clip_id]["duration"]))
	_pose = data.sample(clip_id, time)
	for key in data.clips[clip_id]["keys"]:
		if absf(float(key["time"]) - time) < 1.0 / 120.0:
			_ease = str(key["ease"])
			_pose = key["pose"].duplicate(true)
	if mode == "keys":
		_show_pose()


func _record() -> void:
	data.set_key(clip_id, time, _pose, _ease)
	_status = "%s · %.2f초 자세 기록됨 · Ctrl+S 파일 저장" % [data.clips[clip_id]["name"], time]


func _jump_key(forward: bool) -> void:
	var times: Array = []
	for key in data.clips[clip_id]["keys"]:
		times.append(float(key["time"]))
	times.sort()
	if times.is_empty():
		return
	if not forward:
		times.reverse()
	for at in times:
		if (forward and at > time + 0.001) or (not forward and at < time - 0.001):
			seek(at)
			return
	seek(times[0])


func _capture_walk() -> void:
	if mode != "walk":
		_status = "보행 시험에서 원하는 순간에 '자세 가져오기'를 누르세요."
		return
	var raw := {}
	var current: Vector2 = lab._walker.body_pos
	for leg in lab._walker.pose_legs():
		for part in PARTS:
			raw[leg["id"] + "." + part] = (leg[part] - current) / Anatomy.SCALE + Anatomy.ORIGIN
	var body: Dictionary = lab._walker.pose_body()
	for key in BODY_KEYS:
		raw["body." + key] = (body[BODY_KEYS[key]] - current) / Anatomy.SCALE + Anatomy.ORIGIN
	var captured: Dictionary = data.pose_from_points(raw)
	set_mode("keys")
	_pose = captured
	data.begin_edit()
	_record()
	data.end_edit()
	_show_pose()


func save_document() -> int:
	_commit_numeric_input()
	get_viewport().gui_release_focus()
	_finish_drag()
	var err: int = data.save(storage_path)
	if err == OK:
		_has_file = true
	_status = "저장 완료 · " + storage_path.trim_prefix("res://") if err == OK else "저장 실패 · " + str(data.last_error)
	_refresh()
	return err


func _request_navigation(destination: String) -> void:
	_commit_numeric_input()
	_finish_drag()
	_destination = destination
	if data.dirty:
		_exit_dialog.dialog_text = "수정한 피벗과 키프레임을 저장하고 이동할까요?"
		_exit_dialog.popup_centered()
	else:
		_navigate()


func _navigate() -> void:
	if _destination == "tuning":
		AppFlow.start_walker_lab(get_tree())
	else:
		AppFlow.go_lobby(get_tree())


func _commit_numeric_input() -> void:
	# focus_exit의 지연 value_changed보다 먼저 저장하면 화면의 새 숫자가 누락된다.
	if panel != null and panel.has_method("commit_input"):
		panel.commit_input()
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit and focus.get_parent() is SpinBox:
		(focus.get_parent() as SpinBox).apply()


func _has_bone(id: String) -> bool:
	for bone in data.bone_definitions():
		if bone["id"] == id:
			return true
	return false


func _bone(id: String) -> Dictionary:
	for bone in data.bone_definitions():
		if bone["id"] == id:
			return bone
	return {}


func _visible(id: String) -> bool:
	return filter == "all" or (filter == "body" and (id.begins_with("body.") or not id.contains("."))) or id.begins_with(filter + ".")


func _handles() -> Dictionary:
	var result := {}
	if mode == "pivot":
		for id in data.points:
			if _visible(id):
				result[id] = data.points[id]
	elif mode == "keys":
		result["root"] = _raw.get("body.chassis", data.points["body.chassis"])
		for bone in data.bone_definitions():
			if _visible(bone["id"]):
				result[bone["id"]] = _raw[bone["end"]]
	return result


func _replace_point(id: String, value: Vector2) -> bool:
	var next := value.clamp(Vector2.ZERO, Anatomy.SOURCE_SIZE)
	for bone in data.bone_definitions():
		if bone["start"] == id and next.distance_to(data.points[bone["end"]]) < 1.0:
			_status = "관절을 겹칠 수 없습니다. 인접한 뼈 끝과 1px 이상 벌려 주세요."
			return false
		if bone["end"] == id and next.distance_to(data.points[bone["start"]]) < 1.0:
			_status = "관절을 겹칠 수 없습니다. 인접한 뼈 끝과 1px 이상 벌려 주세요."
			return false
	var previous: Vector2 = data.points[id]
	data.points[id] = next
	if not _apply_anatomy():
		data.points[id] = previous
		return false
	return true


func capture_input(event: InputEvent) -> bool:
	# 드래그가 패널 위로 넘어가도 release를 받아 한 번의 undo로 끝낸다.
	if (_dragging or _panning) and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return handle_input(event)
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.physical_keycode == KEY_S:
		save_document()
		return true
	if event is InputEventKey and event.pressed and not event.echo and mode == "keys":
		var focus := get_viewport().gui_get_focus_owner()
		if not focus is LineEdit and not focus is TextEdit:
			if event.physical_keycode == KEY_SPACE:
				_command("play", not playing)
				return true
			if event.physical_keycode == KEY_K:
				_command("record")
				return true
	return false


func handle_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:
			match event.physical_keycode:
				KEY_S:
					save_document()
					return true
				KEY_Z:
					_command("redo" if event.shift_pressed else "undo")
					return true
				KEY_Y:
					_command("redo")
					return true
		match event.physical_keycode:
			KEY_F1:
				_request_navigation("lobby")
				return true
			KEY_1: set_mode("pivot")
			KEY_2: set_mode("keys")
			KEY_3: set_mode("walk")
			KEY_TAB: set_mode("keys" if mode == "pivot" else "pivot")
			KEY_K:
				_command("record")
			KEY_SPACE:
				if mode == "keys":
					_command("play", not playing)
					return true
			KEY_DELETE:
				if mode == "keys":
					_command("delete_key")
			KEY_F: _command("fit")
			KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
				if mode == "pivot":
					var delta := Vector2.ZERO
					delta.x = float(event.physical_keycode == KEY_RIGHT) - float(event.physical_keycode == KEY_LEFT)
					delta.y = float(event.physical_keycode == KEY_DOWN) - float(event.physical_keycode == KEY_UP)
					data.begin_edit()
					_replace_point(selected, data.points[selected] + delta * (10.0 if event.shift_pressed else 1.0))
					data.end_edit()
					_show_pose()
		return mode != "walk"
	if mode == "walk":
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_drag()
			return true
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
			return true
		if not canvas_rect().has_point(event.position):
			return false
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := get_global_mouse_position()
			_zoom = clampf(_zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.65, 5.0)
			update_camera()
			_pan += before - get_global_mouse_position()
			update_camera()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_commit_numeric_input()
			get_viewport().gui_release_focus()
			var closest := ""
			var distance: float = 17.0 / lab._cam.zoom.x
			var handles := _handles()
			for id in handles:
				var d: float = world_point(handles[id]).distance_to(get_global_mouse_position())
				if d < distance:
					closest = id
					distance = d
			if not closest.is_empty():
				selected = closest
				playing = false
				_dragging = true
				_drag_mouse = raw_point(get_global_mouse_position())
				_drag_point = data.points[selected] if mode == "pivot" else _pose.get("offset", Vector2.ZERO)
				_drag_pose = _pose.duplicate(true)
				data.begin_edit()
				_refresh()
				return true
	if event is InputEventMouseMotion:
		if _panning:
			_pan -= event.relative / lab._cam.zoom
			update_camera()
			return true
		if _dragging:
			var raw := raw_point(get_global_mouse_position())
			var gain := 0.2 if event.shift_pressed else 1.0
			if mode == "pivot":
				var target := _drag_point + (raw - _drag_mouse) * gain
				if event.ctrl_pressed:
					target = target.snapped(Vector2(5, 5))
				_replace_point(selected, target)
			elif selected == "root":
				_pose["offset"] = _drag_point + (raw - _drag_mouse) * gain
			else:
				var bone := _bone(selected)
				var original: Dictionary = data.evaluate_pose(_drag_pose)
				var start: Vector2 = original[bone["start"]]
				var end: Vector2 = original[bone["end"]]
				var angle := wrapf((raw - start).angle() - (end - start).angle(), -PI, PI)
				var value := float(_drag_pose["angles"][selected]) + angle * gain
				if event.ctrl_pressed:
					value = snappedf(value, deg_to_rad(15))
				_pose["angles"][selected] = value
			_show_pose()
			_refresh()
			queue_redraw()
			return true
	return false


func _finish_drag() -> void:
	if not _dragging:
		return
	if mode == "keys":
		_record()
	data.end_edit()
	_dragging = false
	_refresh()


func _draw() -> void:
	if panel == null or mode == "walk":
		return
	var zoom: float = lab._cam.zoom.x
	var handles := _handles()
	for id in handles:
		var at := world_point(handles[id])
		var active: bool = id == selected
		var radius := (8.0 if active else 5.0) / zoom
		var color := Color("fff2b5") if active else Color("e6eef9")
		draw_circle(at, radius + 2.0 / zoom, Color("101a28"))
		draw_arc(at, radius, 0, TAU, 24, color, 1.8 / zoom, true)
		draw_line(at - Vector2(radius + 3, 0), at + Vector2(radius + 3, 0), color, 1.0 / zoom, true)
		draw_line(at - Vector2(0, radius + 3), at + Vector2(0, radius + 3), color, 1.0 / zoom, true)
		if active:
			var label := _point_label(id) if mode == "pivot" else str(_bone(id).get("label", "전체 위치"))
			var where := at + Vector2(15, -18) / zoom
			draw_set_transform(where, 0, Vector2.ONE / zoom)
			draw_string_outline(_font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color("101a28"))
			draw_string(_font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
			draw_set_transform(Vector2.ZERO)
