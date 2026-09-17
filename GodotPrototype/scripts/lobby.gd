extends Control
## 로비: 시작 씬(project.godot run/main_scene). 마우스 버튼으로 고른다.
##   방 드롭다운          아래 두 버튼이 쓰는 방. 타일맵 씬(scenes/rooms/<id>.tscn) 유무가 옆에 표시된다
##   [게임 시작]           고른 방에서 플레이
##   [타일 씬 보기]        고른 방의 타일 씬만 자유 카메라로 띄운다 (TileViewer). 에디터에서 저장 후 R 로 다시 읽기
##   [종료]
## 게임·뷰어 안에서는 F1 로 이 로비로 돌아온다. 타일맵(룰타일) 편집 자체는 Godot 에디터에서 한다.

var _room_pick: OptionButton
var _room_ids: Array = []
var _saved_label: Label
var _font: Font


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 배경에 모듈러 타일 시안을 어둡게 깔아 분위기만 준다
	var plate := TextureRect.new()
	plate.texture = load("res://assets/tiles/workshop_modular/workshop_modular_background_sheet_3x2.png")
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.stretch_mode = TextureRect.STRETCH_TILE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.modulate = Color(0.45, 0.5, 0.6, 0.35)
	add_child(plate)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := _label("Sideview Workshop Prototype", 44, Color(0.95, 0.92, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label("로비 — 들어갈 모드를 클릭하세요", 22, Color(0.7, 0.72, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_spacer(16))

	# 방 선택 (게임 시작·타일 씬 보기 공용)
	var room_row := HBoxContainer.new()
	room_row.add_theme_constant_override("separation", 12)
	box.add_child(room_row)
	var room_lbl := _label("방", 22, Color(0.85, 0.85, 0.9))
	room_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_lbl.custom_minimum_size = Vector2(48, 0)
	room_row.add_child(room_lbl)
	_room_pick = OptionButton.new()
	_room_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_pick.custom_minimum_size = Vector2(0, 48)
	_room_pick.add_theme_font_override("font", _font)
	_room_pick.add_theme_font_size_override("font_size", 20)
	for id in RoomData.ROOMS.keys():
		_room_ids.append(id)
		_room_pick.add_item(RoomData.ROOMS[id]["title"])
	_room_pick.selected = 0
	_room_pick.item_selected.connect(func(_i): _update_saved_label())
	room_row.add_child(_room_pick)
	_saved_label = _label("", 17, Color(0.62, 0.80, 0.86))
	_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_saved_label)
	_update_saved_label()
	box.add_child(_spacer(6))

	var play := _button("▶   게임 시작", "고른 방에서 플레이 시작. F1 로비")
	play.pressed.connect(_start_game)
	box.add_child(play)

	var view := _button("▦   타일 씬 보기", "고른 방의 scenes/rooms/<id>.tscn 만 자유 카메라로 띄운다. Godot 에디터에서 저장 후 R 로 다시 읽기. F1 로비")
	view.pressed.connect(_start_viewer)
	box.add_child(view)

	box.add_child(_spacer(10))
	var quit := _button("✕   종료", "")
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)

	var foot := _label("룰타일 편집: Godot 에디터 → scenes/rooms/<방 id>.tscn → TileMap 패널 [Terrains] 탭", 16, Color(0.5, 0.52, 0.6))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -44
	foot.offset_left = 24
	foot.offset_right = -24
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)

	play.grab_focus()


func _start_game() -> void:
	AppFlow.start_game(get_tree(), _room_ids[_room_pick.selected])


func _start_viewer() -> void:
	AppFlow.start_tile_viewer(get_tree(), _room_ids[_room_pick.selected])


func _update_saved_label() -> void:
	var id: String = _room_ids[_room_pick.selected]
	if RoomTiles.exists(id):
		_saved_label.text = "타일맵 씬 있음: scenes/rooms/%s.tscn" % id
	else:
		_saved_label.text = "타일맵 씬 없음 — Godot 에디터에서 scenes/rooms/workshop.tscn 을 복제해 %s.tscn 으로 저장" % id


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, tooltip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(0, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.15, 0.92)
	sb.border_color = Color(0.35, 0.37, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 22
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = Color(0.16, 0.18, 0.24, 0.95)
	sbh.border_color = Color(1.0, 0.85, 0.3)
	sbh.set_border_width_all(2)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	return b


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
