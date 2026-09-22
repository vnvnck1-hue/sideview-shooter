class_name WalkerAuthoringPanel
extends Control
## 작성 도구의 UI. 저장·피벗·키프레임 데이터는 소유하지 않고 command로만 요청한다.

signal command(action: String, value: Variant)

const Timeline := preload("res://scripts/walker_timeline.gd")
const TEXT := Color("e6eef7")
const MUTED := Color("8fa8bd")
const CYAN := Color("75dce8")
const GOLD := Color("f4c66a")

var _points: Array = []
var _bones: Array = []
var _state: Dictionary = {}
var _mode := "pivot"
var _filter := "all"
var _built := false
var _clip_signature := ""
var _opacity_dragging := false
var _mode_buttons: Dictionary = {}
var _selected_id := ""
var _pending_spin: SpinBox
var _committing_input := false

var _top: PanelContainer
var _side: PanelContainer
var _bottom: PanelContainer
var _dirty: Label
var _undo: Button
var _redo: Button
var _side_title: Label
var _side_help: Label
var _filters: OptionButton
var _list: ItemList
var _selection_label: Label
var _coordinates: HBoxContainer
var _coordinate_caption: Label
var _x: SpinBox
var _y: SpinBox
var _angle_row: HBoxContainer
var _angle: SpinBox
var _opacity: HSlider
var _zoom: Label
var _status: Label
var _clips: OptionButton
var _new_clip: LineEdit
var _add_clip: Button
var _duration: SpinBox
var _loop: CheckButton
var _ease: OptionButton
var _time_label: Label
var _timeline: Control
var _play: Button
var _record: Button
var _delete_key: Button
var _prev: Button
var _next: Button
var _timeline_help: Label


func setup(points: Array, bones: Array) -> void:
	_points = points.duplicate(true)
	_bones = bones.duplicate(true)
	if _built:
		_rebuild_list()


## 선택 대상 / 클립 / 시간이 바뀌기 전에 이전 대상의 입력을 동기적으로 확정한다.
## apply()가 value_changed → command를 발생시키므로 참조를 먼저 비워 재진입을 막는다.
func commit_input() -> void:
	var pending := _pending_spin
	_pending_spin = null
	if not is_instance_valid(pending) or _committing_input:
		return
	_committing_input = true
	pending.apply()
	_committing_input = false


func _track_input(spin: SpinBox) -> void:
	if _committing_input:
		return
	if _pending_spin != spin:
		commit_input()
	_pending_spin = spin


func _send_command(action: String, value: Variant = null) -> void:
	commit_input()
	command.emit(action, value)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_theme()
	_build_top()
	_build_side()
	_build_bottom()
	_built = true
	resized.connect(_layout)
	_layout()
	_rebuild_list()
	refresh(_state)


func refresh(state: Dictionary) -> void:
	_state = state
	if not _built:
		return
	var next_mode := String(state.get("mode", "pivot"))
	var changed_mode := next_mode != _mode
	var next_filter := String(state.get("filter", _filter))
	var changed_filter := next_filter != _filter
	_mode = next_mode
	_filter = next_filter
	if changed_mode or changed_filter:
		_rebuild_list()
	_select_option(_filters, _filter)
	for key in _mode_buttons.keys():
		(_mode_buttons[key] as Button).set_pressed_no_signal(String(key) == _mode)
	var dirty := bool(state.get("dirty", false))
	var has_file := bool(state.get("has_file", false))
	_dirty.text = "● 저장 필요" if dirty else ("● 저장됨" if has_file else "● 기본 뼈대")
	_dirty.add_theme_color_override("font_color", GOLD if dirty else (Color("8dd2b7") if has_file else MUTED))
	_undo.disabled = not bool(state.get("can_undo", false))
	_redo.disabled = not bool(state.get("can_redo", false))
	var selected := String(state.get("selected", ""))
	_select_list_id(selected)
	var root_selected := selected == "root"
	var is_keys := _mode == "keys"
	var is_pivot := _mode == "pivot"
	_side_title.text = "원화 피벗" if is_pivot else ("포즈와 관절" if is_keys else "보행 미리보기")
	_side_help.text = "점 선택 → 드래그 또는 원본 좌표 입력" if is_pivot else ("관절 끝점을 드래그해 자세를 만드세요" if is_keys else "교정한 피벗으로 실제 보행을 확인하세요")
	_selection_label.text = _selected_label(selected)
	_coordinate_caption.text = "원본 이미지 좌표 · px" if is_pivot else "전체 위치 이동 · 원화 px"
	_coordinates.visible = is_pivot or (is_keys and root_selected)
	_coordinate_caption.visible = _coordinates.visible
	_angle_row.visible = is_keys and not root_selected
	_set_spin(_x, float(state.get("x", 0.0)))
	_set_spin(_y, float(state.get("y", 0.0)))
	_set_spin(_angle, float(state.get("angle", 0.0)))
	_x.editable = is_pivot or (is_keys and root_selected)
	_y.editable = _x.editable
	_angle.editable = is_keys and not root_selected
	_zoom.text = "확대 %.0f%%" % (float(state.get("zoom", 1.0)) * 100.0)
	if state.has("opacity") and not _opacity_dragging:
		_opacity.set_value_no_signal(float(state["opacity"]))
	var status := String(state.get("status", ""))
	_status.text = status if not status.is_empty() else "원화 좌표와 키프레임은 저장 버튼으로 함께 저장됩니다."
	_status.tooltip_text = _status.text
	_status.add_theme_color_override("font_color", Color("f2a293") if status.contains("실패") or status.contains("오류") else MUTED)
	_refresh_clips(state)
	_set_spin(_duration, float(state.get("duration", 1.0)))
	_loop.set_pressed_no_signal(bool(state.get("loop", true)))
	_select_option(_ease, String(state.get("ease", "smooth")))
	_time_label.text = "%.2f / %.2f 초" % [float(state.get("time", 0.0)), float(state.get("duration", 1.0))]
	_play.text = "Ⅱ 정지" if bool(state.get("playing", false)) else "▶ 재생"
	_timeline.call("refresh", state)
	_timeline.mouse_filter = Control.MOUSE_FILTER_STOP if is_keys else Control.MOUSE_FILTER_IGNORE
	_timeline.modulate = Color.WHITE if is_keys else Color(1.0, 1.0, 1.0, 0.55)
	for button in [_play, _record, _delete_key, _prev, _next, _add_clip, _clips, _loop, _ease]:
		(button as BaseButton).disabled = not is_keys
	_duration.editable = is_keys
	_new_clip.editable = is_keys
	_timeline_help.text = "자세를 바꾸면 현재 시간에 자동 기록 · ◆ 드래그로 시간 조절 · K 기록 · Space 재생" if is_keys else "키프레임 모드에서 클립을 선택하고 포즈를 기록하세요"


func _build_theme() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI"])
	var skin := Theme.new()
	skin.default_font = font
	skin.default_font_size = 13
	skin.set_color("font_color", "Label", TEXT)
	skin.set_color("font_color", "Button", TEXT)
	skin.set_color("font_hover_color", "Button", Color.WHITE)
	skin.set_color("font_pressed_color", "Button", CYAN)
	skin.set_color("font_disabled_color", "Button", Color("52697d"))
	for type in ["Button", "OptionButton"]:
		skin.set_stylebox("normal", type, _style(Color("1d2c3d"), Color("34495d"), 6, 9, 5))
		skin.set_stylebox("hover", type, _style(Color("273c50"), Color("62869e"), 6, 9, 5))
		skin.set_stylebox("pressed", type, _style(Color("184352"), Color("62bfcd"), 6, 9, 5))
		skin.set_stylebox("disabled", type, _style(Color("142131"), Color("25384b"), 6, 9, 5))
		skin.set_stylebox("focus", type, _style(Color(0, 0, 0, 0), CYAN, 6, 0, 0))
	skin.set_stylebox("normal", "LineEdit", _style(Color("0d1927"), Color("354c61"), 5, 8, 5))
	skin.set_stylebox("focus", "LineEdit", _style(Color(0, 0, 0, 0), CYAN, 5, 0, 0))
	skin.set_color("font_color", "LineEdit", TEXT)
	skin.set_color("font_placeholder_color", "LineEdit", Color("667f94"))
	skin.set_stylebox("panel", "ItemList", _style(Color("0d1927"), Color("2b4054"), 6, 7, 6))
	skin.set_stylebox("selected", "ItemList", _style(Color("214c5c"), Color("63b7c5"), 4, 3, 3))
	skin.set_stylebox("selected_focus", "ItemList", _style(Color("214c5c"), CYAN, 4, 3, 3))
	skin.set_color("font_color", "ItemList", Color("c8d8e7"))
	skin.set_color("font_selected_color", "ItemList", Color.WHITE)
	skin.set_constant("v_separation", "ItemList", 5)
	theme = skin


func _build_top() -> void:
	_top = _panel(12)
	add_child(_top)
	var row := _row(8)
	_top.add_child(row)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 1)
	brand.custom_minimum_size.x = 202
	row.add_child(brand)
	brand.add_child(_label("사족보행 작성 도구", 20, TEXT))
	_dirty = _label("● 기본 뼈대", 11, MUTED)
	brand.add_child(_dirty)
	for item in [["pivot", "피벗 편집"], ["keys", "키프레임"], ["walk", "보행 확인"]]:
		var mode := String(item[0])
		var button := _button(String(item[1]), "mode", mode, "모드 전환")
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(86, 34)
		row.add_child(button)
		_mode_buttons[mode] = button
	row.add_child(_spacer())
	row.add_child(_button("보행 튜닝", "tuning", null, "인게임 기체의 관절 각도·보폭을 조절하는 창으로 이동"))
	_undo = _button("↶", "undo", null, "실행 취소 · Ctrl+Z")
	_redo = _button("↷", "redo", null, "다시 실행 · Ctrl+Shift+Z / Ctrl+Y")
	_undo.custom_minimum_size.x = 35
	_redo.custom_minimum_size.x = 35
	row.add_child(_undo)
	row.add_child(_redo)
	row.add_child(_button("기준 자세", "neutral", null, "원화 기준 자세로 되돌리기"))
	row.add_child(_button("맞춤", "fit", null, "원화와 뼈대를 화면에 맞추기"))
	row.add_child(_button("캡처", "capture", null, "현재 화면 저장"))
	var save := _button("저장  Ctrl+S", "save", null, "피벗과 기록된 클립을 함께 저장")
	save.add_theme_color_override("font_color", CYAN)
	save.custom_minimum_size.x = 104
	row.add_child(save)


func _build_side() -> void:
	_side = _panel(14)
	add_child(_side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	_side.add_child(column)
	_side_title = _label("원화 피벗", 18, TEXT)
	column.add_child(_side_title)
	_side_help = _label("", 11, MUTED)
	_side_help.hide()
	column.add_child(_side_help)
	_filters = OptionButton.new()
	for item in [["all", "전체 관절"], ["body", "몸통 · 포신"], ["NF", "NF · 가까운 앞"], ["NR", "NR · 가까운 뒤"], ["FF", "FF · 먼 앞"], ["FR", "FR · 먼 뒤"]]:
		_filters.add_item(String(item[1]))
		_filters.set_item_metadata(_filters.item_count - 1, String(item[0]))
	_filters.item_selected.connect(func(index: int):
		commit_input()
		_filter = String(_filters.get_item_metadata(index))
		_rebuild_list()
		command.emit("filter", _filter))
	column.add_child(_filters)
	_list = ItemList.new()
	_list.custom_minimum_size.y = 102
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(index: int): _send_command("select", String(_list.get_item_metadata(index))))
	column.add_child(_list)
	_selection_label = _label("관절을 선택하세요", 13, CYAN)
	_selection_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_selection_label)
	_coordinate_caption = _label("원본 이미지 좌표 · px", 11, MUTED)
	column.add_child(_coordinate_caption)
	_coordinates = _row(8)
	column.add_child(_coordinates)
	_x = _coordinate_input(_coordinates, "X", "point_x")
	_y = _coordinate_input(_coordinates, "Y", "point_y")
	_angle_row = _row(8)
	_angle_row.add_child(_label("관절 각도", 12, MUTED))
	_angle = _spin(-360.0, 360.0, 0.1)
	_angle.suffix = "°"
	_angle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_angle.value_changed.connect(func(value: float): command.emit("angle", value))
	_angle_row.add_child(_angle)
	column.add_child(_angle_row)
	column.add_child(HSeparator.new())
	var art_row := _row(8)
	art_row.add_child(_label("원화 농도", 11, MUTED))
	_opacity = HSlider.new()
	_opacity.min_value = 0.0
	_opacity.max_value = 1.0
	_opacity.step = 0.05
	_opacity.value = 0.6
	_opacity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opacity.drag_started.connect(func(): _opacity_dragging = true)
	_opacity.drag_ended.connect(func(_changed: bool): _opacity_dragging = false)
	_opacity.value_changed.connect(func(value: float): _send_command("opacity", value))
	art_row.add_child(_opacity)
	_zoom = _label("확대 100%", 11, MUTED)
	_zoom.custom_minimum_size.x = 67
	_zoom.tooltip_text = "편집 화면 확대 비율 · 마우스 휠로 조절"
	art_row.add_child(_zoom)
	column.add_child(art_row)
	_status = _label("", 11, MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 2
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.custom_minimum_size.y = 31
	column.add_child(_status)


func _build_bottom() -> void:
	_bottom = _panel(12)
	add_child(_bottom)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	_bottom.add_child(column)
	var clip_row := _row(8)
	column.add_child(clip_row)
	clip_row.add_child(_label("동작", 12, MUTED))
	_clips = OptionButton.new()
	_clips.custom_minimum_size.x = 168
	_clips.clip_text = true
	_clips.item_selected.connect(func(index: int): _send_command("clip", String(_clips.get_item_metadata(index))))
	clip_row.add_child(_clips)
	_new_clip = LineEdit.new()
	_new_clip.placeholder_text = "새 클립 이름"
	_new_clip.custom_minimum_size.x = 130
	_new_clip.max_length = 32
	_new_clip.text_submitted.connect(func(_text: String): _request_new_clip())
	clip_row.add_child(_new_clip)
	_add_clip = Button.new()
	_add_clip.text = "+"
	_add_clip.tooltip_text = "새 동작 클립 만들기"
	_add_clip.pressed.connect(_request_new_clip)
	clip_row.add_child(_add_clip)
	clip_row.add_child(_label("길이", 12, MUTED))
	_duration = _spin(0.1, 60.0, 0.1)
	_duration.custom_minimum_size.x = 82
	_duration.suffix = "초"
	_duration.value_changed.connect(func(value: float): command.emit("duration", value))
	clip_row.add_child(_duration)
	_loop = CheckButton.new()
	_loop.text = "반복"
	_loop.toggled.connect(func(value: bool): _send_command("loop", value))
	clip_row.add_child(_loop)
	_ease = OptionButton.new()
	for item in [["smooth", "부드럽게"], ["linear", "선형"], ["hold", "유지"]]:
		_ease.add_item(String(item[1]))
		_ease.set_item_metadata(_ease.item_count - 1, String(item[0]))
	_ease.item_selected.connect(func(index: int): _send_command("ease", String(_ease.get_item_metadata(index))))
	clip_row.add_child(_ease)
	clip_row.add_child(_spacer())
	_time_label = _label("0.00 / 1.00 초", 13, CYAN)
	_time_label.custom_minimum_size.x = 108
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clip_row.add_child(_time_label)
	var transport := _row(8)
	transport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(transport)
	_prev = _button("|‹", "prev_key", null, "이전 키프레임")
	_play = Button.new()
	_play.text = "▶ 재생"
	_play.custom_minimum_size.x = 74
	_play.pressed.connect(func(): _send_command("play", not bool(_state.get("playing", false))))
	_next = _button("›|", "next_key", null, "다음 키프레임")
	for button in [_prev, _play, _next]:
		(button as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		transport.add_child(button)
	_timeline = Timeline.new()
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline.connect("seek_requested", func(value: float): _send_command("seek", value))
	_timeline.connect("key_moved", func(from: float, to: float): _send_command("move_key", {"from": from, "to": to}))
	transport.add_child(_timeline)
	var key_column := VBoxContainer.new()
	key_column.custom_minimum_size.x = 119
	key_column.add_theme_constant_override("separation", 5)
	key_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	transport.add_child(key_column)
	_record = _button("◆ 키 기록  K", "record", null, "현재 포즈를 현재 시간에 기록")
	_record.add_theme_color_override("font_color", GOLD)
	_delete_key = _button("키 삭제", "delete_key", null, "현재 시간의 키프레임 삭제")
	key_column.add_child(_record)
	key_column.add_child(_delete_key)
	var footer := _row(10)
	column.add_child(footer)
	_timeline_help = _label("", 11, MUTED)
	footer.add_child(_timeline_help)
	footer.add_child(_spacer())
	footer.add_child(_label("Ctrl+S 저장  ·  Ctrl+Z 취소  ·  휠 확대  ·  중클릭 이동", 11, MUTED))


func _layout() -> void:
	if not _built:
		return
	_top.position = Vector2(16, 12)
	_top.size = Vector2(maxf(size.x - 32, 900), 56)
	_side.position = Vector2(size.x - 316, 82)
	_side.size = Vector2(300, maxf(size.y - 270, 380))
	_bottom.position = Vector2(16, size.y - 172)
	_bottom.size = Vector2(maxf(size.x - 32, 900), 156)


func _rebuild_list() -> void:
	if _list == null:
		return
	_list.clear()
	var source: Array = _points if _mode == "pivot" else _bones
	for entry in source:
		var id := String(entry.get("id", ""))
		if not _matches_filter(id):
			continue
		var index := _list.add_item(String(entry.get("label", id)))
		_list.set_item_metadata(index, id)
		_list.set_item_tooltip(index, id)
		if id.to_upper().begins_with("FR"):
			_list.set_item_custom_fg_color(index, Color("c8b895"))
	_selected_id = ""
	_select_list_id(String(_state.get("selected", "")))


func _matches_filter(id: String) -> bool:
	if _filter == "all":
		return true
	var upper := id.to_upper()
	if _filter == "body":
		for prefix in ["FF", "FR", "NF", "NR"]:
			if upper.begins_with(prefix):
				return false
		return true
	return upper.begins_with(_filter)


func _select_list_id(id: String) -> void:
	if id == _selected_id:
		return
	_selected_id = id
	_list.deselect_all()
	for index in range(_list.item_count):
		if String(_list.get_item_metadata(index)) == id:
			_list.select(index)
			_list.ensure_current_is_visible()
			return


func _selected_label(id: String) -> String:
	var source: Array = _points if _mode == "pivot" else _bones
	for entry in source:
		if String(entry.get("id", "")) == id:
			return String(entry.get("label", id))
	return "관절을 선택하세요" if id.is_empty() else id


func _refresh_clips(state: Dictionary) -> void:
	var clips: Array = state.get("clips", [])
	var signature := JSON.stringify(clips)
	if signature != _clip_signature:
		_clip_signature = signature
		_clips.clear()
		for clip in clips:
			_clips.add_item(String(clip.get("name", clip.get("id", ""))))
			_clips.set_item_metadata(_clips.item_count - 1, String(clip.get("id", "")))
	_select_option(_clips, String(state.get("clip_id", "")))


func _select_option(option: OptionButton, id: String) -> void:
	for index in range(option.item_count):
		if String(option.get_item_metadata(index)) == id:
			if option.selected != index:
				option.select(index)
			return


func _request_new_clip() -> void:
	var name := _new_clip.text.strip_edges()
	if name.is_empty():
		_new_clip.grab_focus()
		return
	_send_command("add_clip", name)
	_new_clip.clear()


func _coordinate_input(row: HBoxContainer, axis: String, action: String) -> SpinBox:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	row.add_child(column)
	column.add_child(_label(axis, 11, MUTED))
	var spin := _spin(-4096.0, 4096.0, 0.5)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(value: float): command.emit(action, value))
	column.add_child(spin)
	return spin


func _spin(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.custom_minimum_size.y = 29
	var edit := spin.get_line_edit()
	edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	edit.focus_entered.connect(func(): _track_input(spin))
	edit.text_changed.connect(func(_text: String): _track_input(spin))
	return spin


func _set_spin(spin: SpinBox, value: float) -> void:
	if spin != _pending_spin and not spin.get_line_edit().has_focus() and not is_equal_approx(spin.value, value):
		spin.set_value_no_signal(value)


func _button(text: String, action: String, value: Variant = null, hint: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size.y = 30
	button.pressed.connect(func(): _send_command(action, value))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _row(gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	return row


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _panel(padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(Color("142131"), Color("2e4358"), 9, padding, 10))
	return panel


func _style(fill: Color, border: Color, radius: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style
