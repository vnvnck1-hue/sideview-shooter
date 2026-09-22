class_name WalkerTuningPanel
extends Control
## 보행 튜닝 UI. 설정과 게임 동작은 command로 요청하며 이 패널은 저장하지 않는다.

signal command(action: String, value: Variant)

const TEXT := Color("e6eef7")
const MUTED := Color("8fa8bd")
const CYAN := Color("75dce8")
const GOLD := Color("f4c66a")

var _definitions: Array = []
var _state: Dictionary = {}
var _built := false
var _syncing := false
var _committing_input := false
var _pending_spin: SpinBox
var _dragging_key := ""
var _groups: Array[String] = []
var _spins: Dictionary = {}
var _sliders: Dictionary = {}
var _rows: Dictionary = {}
var _preview_buttons: Dictionary = {}
var _top: PanelContainer
var _side: PanelContainer
var _bottom: PanelContainer
var _dirty: Label
var _tabs: TabBar
var _scroll: ScrollContainer
var _fields: VBoxContainer
var _status: Label
var _telemetry: Label
var _save: Button
var _load: Button
var _reset: Button
var _run: Button
var _bones: Button
var _pause: Button
var _terrain: OptionButton


func setup(definitions: Array) -> void:
	commit_input()
	_definitions = definitions.duplicate(true)
	if _built:
		_build_fields()
		refresh(_state)


func commit_input() -> void:
	var pending := _pending_spin
	_pending_spin = null
	if not is_instance_valid(pending) or _committing_input:
		return
	_committing_input = true
	pending.apply()
	_committing_input = false


func _track_input(spin: SpinBox) -> void:
	if _committing_input or _syncing:
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
	_build_fields()
	resized.connect(_layout)
	_layout()
	refresh(_state)


func refresh(state: Dictionary) -> void:
	_state = state
	if not _built:
		return
	_syncing = true
	var values: Dictionary = state.get("values", {})
	for definition in _definitions:
		var key := String(definition["key"])
		if not _spins.has(key): continue
		var value := float(values.get(key, definition.get("default", 0.0)))
		var spin: SpinBox = _spins[key]
		if spin != _pending_spin and not spin.get_line_edit().has_focus():
			spin.set_value_no_signal(value)
		if _dragging_key != key:
			(_sliders[key] as HSlider).set_value_no_signal(value)
	var dirty := bool(state.get("dirty", false))
	var loaded := bool(state.get("loaded", false))
	_dirty.text = "● 저장 필요" if dirty else ("● 저장된 설정" if loaded else "● 기본 설정")
	_dirty.add_theme_color_override("font_color", GOLD if dirty else (Color("8dd2b7") if loaded else MUTED))
	for direction in _preview_buttons:
		(_preview_buttons[direction] as Button).set_pressed_no_signal(int(state.get("preview", 0)) == int(direction))
	_run.set_pressed_no_signal(bool(state.get("running", false)))
	_bones.set_pressed_no_signal(bool(state.get("bones", false)))
	_pause.set_pressed_no_signal(bool(state.get("paused", false)))
	_pause.text = "▶ 계속" if bool(state.get("paused", false)) else "Ⅱ 일시정지"
	for index in _terrain.item_count:
		if int(_terrain.get_item_metadata(index)) == int(state.get("terrain", 0)):
			_terrain.select(index)
	var status := String(state.get("status", ""))
	_status.text = status if not status.is_empty() else "값을 바꾸면 바로 보행에 반영됩니다.\n마음에 드는 설정은 저장해 두세요."
	_status.tooltip_text = _status.text
	_status.add_theme_color_override("font_color", Color("f2a293") if status.contains("실패") or status.contains("오류") else MUTED)
	_telemetry.text = _telemetry_text(state.get("telemetry", ""))
	_syncing = false


func _telemetry_text(value: Variant) -> String:
	if value is String: return value
	if not value is Dictionary: return ""
	if value.has("text"): return String(value["text"])
	var parts: PackedStringArray = []
	if value.has("speed"): parts.append("속도 %.0f" % absf(float(value["speed"])))
	if value.has("planted"): parts.append("지지발 %d" % int(value["planted"]))
	if value.has("stepping"): parts.append("움직이는 발 %d" % int(value["stepping"]))
	if value.has("height"): parts.append("몸 높이 %.0f" % float(value["height"]))
	if bool(value.get("airborne", false)): parts.append("점프 중")
	return "   ·   ".join(parts)


func _build_top() -> void:
	_top = _panel(12)
	_top.name = "TopBar"
	add_child(_top)
	var row := _row(8)
	_top.add_child(row)
	var brand := VBoxContainer.new()
	brand.custom_minimum_size.x = 206
	brand.add_theme_constant_override("separation", 2)
	row.add_child(brand)
	brand.add_child(_label("사족보행 테스트", 20, TEXT))
	_dirty = _label("● 기본 설정", 11, MUTED)
	brand.add_child(_dirty)
	row.add_child(_button("로비", "lobby", null, "로비로 돌아가기"))
	row.add_child(_button("피벗 · 키프레임", "authoring", null, "피벗과 키프레임 작성 도구 열기"))
	row.add_child(_spacer())
	_reset = _button("기본값", "reset", null, "모든 보행 값을 기본값으로 되돌리기")
	_load = _button("불러오기", "load", null, "마지막으로 저장한 보행 설정 불러오기")
	_save = _button("저장  Ctrl+S", "save", null, "현재 보행 설정 저장")
	_save.name = "Save"
	_save.add_theme_color_override("font_color", CYAN)
	row.add_child(_reset)
	row.add_child(_load)
	row.add_child(_save)


func _build_side() -> void:
	_side = _panel(14)
	_side.name = "Parameters"
	add_child(_side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_side.add_child(column)
	column.add_child(_label("보행 조정", 19, TEXT))
	column.add_child(_label("슬라이더를 움직이거나 숫자를 입력하세요", 11, MUTED))
	_tabs = TabBar.new()
	_tabs.name = "Groups"
	_tabs.clip_tabs = true
	_tabs.scrolling_enabled = true
	_tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	_tabs.custom_minimum_size.y = 32
	_tabs.tab_changed.connect(_show_group)
	column.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.name = "ParameterScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_fields = VBoxContainer.new()
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields.add_theme_constant_override("separation", 17)
	_scroll.add_child(_fields)
	var divider := HSeparator.new()
	column.add_child(divider)
	_status = _label("", 11, MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 54)
	_status.max_lines_visible = 3
	column.add_child(_status)


func _build_fields() -> void:
	commit_input()
	_pending_spin = null
	_dragging_key = ""
	_spins.clear()
	_sliders.clear()
	_rows.clear()
	_groups.clear()
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	_tabs.clear_tabs()
	for definition in _definitions:
		var group := String(definition.get("group", "보행"))
		if group not in _groups:
			_groups.append(group)
			var short_names := {"이동과 자세": "자세", "발 디딤": "걸음", "몸 움직임": "몸", "관절 각도": "각도", "관절 범위": "범위"}
			_tabs.add_tab(String(short_names.get(group, group)))
			_tabs.set_tab_tooltip(_tabs.tab_count - 1, group)
		var key := String(definition["key"])
		var row := VBoxContainer.new()
		row.name = key.validate_node_name()
		row.set_meta("group", group)
		row.add_theme_constant_override("separation", 6)
		row.tooltip_text = String(definition.get("hint", ""))
		_fields.add_child(row)
		_rows[key] = row
		var caption := _row(4)
		row.add_child(caption)
		caption.add_child(_label(String(definition.get("label", key)), 13, TEXT))
		caption.add_child(_spacer())
		var unit := String(definition.get("unit", ""))
		caption.add_child(_label(unit, 10, MUTED))
		var input := _row(9)
		row.add_child(input)
		var slider := HSlider.new()
		slider.name = "Slider"
		slider.min_value = float(definition.get("min", 0.0))
		slider.max_value = float(definition.get("max", 100.0))
		slider.step = float(definition.get("step", 1.0))
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(100, 32)
		slider.tooltip_text = row.tooltip_text
		input.add_child(slider)
		_sliders[key] = slider
		var spin := SpinBox.new()
		spin.name = "Value"
		spin.min_value = slider.min_value
		spin.max_value = slider.max_value
		# Decimal display precision and arrow increments are separate: .25 needs
		# two displayed decimals, while its arrows should still move by .25.
		var increment_text := String.num(slider.step, 6).trim_suffix(".0")
		var decimal_part := increment_text.get_slice(".", 1).rstrip("0")
		spin.step = pow(10.0, -decimal_part.length())
		spin.custom_arrow_step = slider.step
		spin.custom_minimum_size = Vector2(92, 32)
		spin.tooltip_text = row.tooltip_text
		var edit := spin.get_line_edit()
		edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		edit.focus_entered.connect(func(): _track_input(spin))
		edit.text_changed.connect(func(_text: String): _track_input(spin))
		input.add_child(spin)
		_spins[key] = spin
		slider.drag_started.connect(func():
			commit_input()
			_dragging_key = key)
		slider.drag_ended.connect(func(_changed: bool): _dragging_key = "")
		slider.value_changed.connect(func(value: float): _slider_changed(key, value))
		spin.value_changed.connect(func(value: float): _spin_changed(key, value))
	if not _groups.is_empty():
		_tabs.current_tab = 0
		_show_group(0)


func _show_group(index: int) -> void:
	commit_input()
	if index < 0 or index >= _groups.size(): return
	for row in _rows.values():
		(row as Control).visible = String(row.get_meta("group")) == _groups[index]
	_scroll.scroll_vertical = 0


func _slider_changed(key: String, value: float) -> void:
	if _syncing: return
	commit_input()
	(_spins[key] as SpinBox).set_value_no_signal(value)
	command.emit("param", {"key": key, "value": value})


func _spin_changed(key: String, value: float) -> void:
	if _syncing: return
	(_sliders[key] as HSlider).set_value_no_signal(value)
	command.emit("param", {"key": key, "value": value})


func _build_bottom() -> void:
	_bottom = _panel(12)
	_bottom.name = "PreviewControls"
	add_child(_bottom)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	_bottom.add_child(column)
	var row := _row(6)
	column.add_child(row)
	for item in [[0, "정지"], [-1, "← 걷기"], [1, "걷기 →"]]:
		var direction := int(item[0])
		var button := _button(String(item[1]), "preview", direction, "자동 보행 미리보기")
		button.toggle_mode = true
		_preview_buttons[direction] = button
		row.add_child(button)
	_run = _toggle("달리기", "run", "자동 보행 속도를 달리기로 바꾸기")
	row.add_child(_run)
	row.add_child(_button("점프", "jump", null, "점프 미리보기 · Space"))
	row.add_child(_button("포즈 초기화", "reset_pose", null, "보행 자세와 위치를 처음으로 되돌리기"))
	_bones = _toggle("본 겹쳐보기", "bones", "로봇 위에 관절과 뼈대를 겹쳐 표시")
	row.add_child(_bones)
	row.add_child(_spacer())
	_pause = _toggle("Ⅱ 일시정지", "pause", "현재 움직임을 멈추거나 계속하기")
	row.add_child(_pause)
	var info := _row(8)
	column.add_child(info)
	info.add_child(_label("지형", 11, MUTED))
	_terrain = OptionButton.new()
	_terrain.custom_minimum_size = Vector2(96, 28)
	_terrain.tooltip_text = "경사에서 자세와 발 디딤을 확인하세요"
	for item in [[0, "평지"], [1, "오르막"], [-1, "내리막"]]:
		_terrain.add_item(String(item[1]))
		_terrain.set_item_metadata(_terrain.item_count - 1, int(item[0]))
	_terrain.item_selected.connect(func(index: int): _send_command("terrain", int(_terrain.get_item_metadata(index))))
	info.add_child(_terrain)
	info.add_child(_spacer())
	_telemetry = _label("", 12, CYAN)
	_telemetry.custom_minimum_size.y = 18
	info.add_child(_telemetry)
	var hints := _label("Q·Z 속도   E·C 벌림   R·V 몸 높이   T·B 보폭   Y·N 발 높이   U·M 걸음 시간\nI·, 예측   O·. 접지   P·/ 다리 수   [·] 기울기   ;·' 조준   A/D 이동 · Space 점프", 11, MUTED)
	# Explicit two lines avoid a huge initial wrapped minimum height while the
	# parent container is still at width zero.
	hints.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(hints)


func _layout() -> void:
	if not _built: return
	_top.position = Vector2(16, 12)
	_top.size = Vector2(maxf(size.x - 32, 800), 64)
	_side.position = Vector2(size.x - 356, 86)
	_side.size = Vector2(340, maxf(size.y - 102, 420))
	_bottom.position = Vector2(16, size.y - 160)
	_bottom.size = Vector2(maxf(size.x - 388, 700), 144)


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
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color("1d2c3d")
		var border := Color("34495d")
		if state == "hover":
			fill = Color("273c50")
			border = Color("62869e")
		elif state == "pressed":
			fill = Color("184352")
			border = Color("62bfcd")
		elif state == "disabled": fill = Color("142131")
		skin.set_stylebox(state, "Button", _style(fill, border, 6, 9, 5))
	skin.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), CYAN, 6, 0, 0))
	skin.set_stylebox("normal", "LineEdit", _style(Color("0d1927"), Color("354c61"), 5, 8, 5))
	skin.set_stylebox("focus", "LineEdit", _style(Color(0, 0, 0, 0), CYAN, 5, 0, 0))
	skin.set_color("font_color", "LineEdit", TEXT)
	skin.set_stylebox("tab_selected", "TabBar", _style(Color("21404c"), Color("5bb6c4"), 5, 12, 6))
	skin.set_stylebox("tab_unselected", "TabBar", _style(Color("142131"), Color("2e4358"), 5, 12, 6))
	skin.set_color("font_selected_color", "TabBar", CYAN)
	skin.set_color("font_unselected_color", "TabBar", MUTED)
	skin.set_font_size("font_size", "TabBar", 12)
	theme = skin


func _button(text: String, action: String, value: Variant = null, hint := "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size.y = 34
	button.pressed.connect(func(): _send_command(action, value))
	return button


func _toggle(text: String, action: String, hint: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.toggle_mode = true
	button.custom_minimum_size.y = 34
	button.toggled.connect(func(pressed: bool): _send_command(action, pressed))
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
