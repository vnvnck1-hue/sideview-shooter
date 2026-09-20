extends Control
## 로비: 시작 씬(project.godot run/main_scene). 마우스 버튼으로 고른다.
##   [메인 게임]   에어록에서 시작해 전체 맵(방 21개, 구역 4개)을 탐색한다 (scenes/MainGame.tscn)
##   [테스트]      저수조실에서 바로 시작 — 원버튼 (scenes/Main.tscn)
##   [센트리건]    가장 큰 방(격납고)의 센트리건 옆에서 바로 시작 — 전개·조종·과열 사격 확인
##   [맵 뷰어]     방을 게임 없이 조립해 자유 카메라로 본다. [ ] 로 방 전환 (scenes/MapViewer.tscn)
##   [대화 UI 랩]  대사 표시 방식 5종을 실제 화면에서 1~5 로 바꿔 가며 비교한다 (scenes/DialogueLab.tscn)
##   [CRT 모니터]  전역 CRT 후처리 프리셋 드롭다운 (scripts/crt_preset.gd · autoload CrtFx). 게임 안에서는 F4 / Shift+F4
##   [종료]
## 게임·뷰어 안에서는 F1 로 이 로비로 돌아온다.

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
	plate.texture = load(RoomTheme.sheet("workshop", "bg"))
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
	var zones := {}
	for id in RoomData.ROOMS.keys():
		zones[RoomData.ROOMS[id]["zone"]] = true
	var sub := _label("방 %d개 · 구역 %d개 — 들어갈 모드를 클릭하세요" % [RoomData.ROOMS.size(), zones.size()], 22, Color(0.7, 0.72, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(_spacer(16))

	var play := _button("▶   메인 게임", "에어록에서 시작. 측벽문·정면문으로 전체 맵을 탐색한다. F1 로비")
	play.pressed.connect(func(): AppFlow.start_main_game(get_tree()))
	box.add_child(play)

	var test := _button("⚙   테스트 — 저수조실(물)에서 시작", "물이 고인 저수조실에서 바로 플레이 (액체 셰이더 확인). F1 로비")
	test.pressed.connect(func(): AppFlow.start_test(get_tree()))
	box.add_child(test)

	var sentry := _button("⌖   센트리건 테스트 — 격납고(가장 큰 방)에서 시작", "맵에서 가장 큰 방(격납고 4096px·몬스터 12) 의 센트리건 해치 옆에서 시작한다. W/↑ 전개·조종, 마우스 조준, 좌클릭 연사(총열 과열). F1 로비")
	sentry.pressed.connect(func(): AppFlow.start_test(get_tree(), RoomData.SENTRY_TEST_ROOM, RoomData.SENTRY_TEST_X - SentryTurret.INTERACT_RANGE * 0.7, 1))
	box.add_child(sentry)

	var view := _button("▦   맵 뷰어", "방을 게임 없이 조립해 자유 카메라로 본다. [ ] 방 전환 · 휠 줌 · WASD 이동 · F1 로비")
	view.pressed.connect(func(): AppFlow.start_map_viewer(get_tree()))
	box.add_child(view)

	var lab := _button("✎   근경 랩 — 근경 실루엣 배치 편집", "실제 방·조명 위에서 근경(배관·기둥·상자·케이블)을 마우스로 옮기고 늘려 S 로 저장. [ ] 방 전환 · F1 로비")
	lab.pressed.connect(func(): AppFlow.start_foreground_lab(get_tree(), "workshop"))
	box.add_child(lab)

	var amb := _button("♪   앰비언스 랩 — 방별 환경음 듣고 수치 조정", "에어록에서 시작해 실제로 걸어 다니며 방마다 어떤 앰비언스가 울리는지 보고 그 자리에서 음량·파일을 바꿔 Ctrl+S 로 저장한다. Tab 대상 · -/= 음량 · ,/. 파일 · F1 로비")
	amb.pressed.connect(func(): AppFlow.start_ambience_lab(get_tree()))
	box.add_child(amb)

	var dlg := _button("✎   대화 UI 랩 — 대사 표시 방식 비교", "실제 방·인물 위에서 대사 표시 방식 5종(카타나 제로 · 비주얼 노벨 · 자막 · 누적 로그 · 레트로 박스)을 1~5 로 바꿔 가며 본다. [ ] 상대 바꾸기 · R 다시 · F1 로비")
	dlg.pressed.connect(func(): AppFlow.start_dialogue_lab(get_tree()))
	box.add_child(dlg)

	var shadow := _button("☀   조명·그림자 랩 — 마우스가 광원", "그레이박스 상자·공·기둥 위에서 마우스 포인터가 곧 광원이 된다. 빛과 물체의 각도로 그림자가 어떻게 만들어지는지 보면서 그 자리에서 수치를 고친다. H 기하 디버그 · F6·F8 프리셋 · F1 로비")
	shadow.pressed.connect(func(): AppFlow.start_shadow_lab(get_tree()))
	box.add_child(shadow)

	box.add_child(_spacer(6))
	box.add_child(_crt_row())

	box.add_child(_spacer(10))
	var quit := _button("✕   종료", "")
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)

	var foot := _label("맵 데이터: scripts/room_data.gd — 방 모양(열 프로필)·문·프랍·조명·몬스터. 검사: godot --headless --script res://tools/validate_map.gd", 16, Color(0.5, 0.52, 0.6))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -44
	foot.offset_left = 24
	foot.offset_right = -24
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)

	play.grab_focus()


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


## "CRT 모니터  [드롭다운]" 한 줄. 바꾸면 즉시 전역 오버레이(CrtFx)에 적용되고 저장된다.
func _crt_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := _label("▣   CRT 모니터", 24, Color(0.85, 0.83, 0.78))
	l.custom_minimum_size = Vector2(230, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 50)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_override("font", _font)
	opt.add_theme_font_size_override("font_size", 22)
	opt.get_popup().add_theme_font_override("font", _font)
	opt.get_popup().add_theme_font_size_override("font_size", 22)
	for i in CrtPreset.count():
		var p: Dictionary = CrtPreset.get_preset(i)
		opt.add_item("%d  %s" % [i + 1, p["name"]], i)
		opt.set_item_tooltip(i, p["desc"])
	opt.select(CrtFx.index)
	opt.tooltip_text = CrtFx.current()["desc"]
	opt.item_selected.connect(func(i: int):
		CrtFx.set_preset(i, false)
		opt.tooltip_text = CrtFx.current()["desc"])
	var follow := func(i: int): opt.select(i)                     # F4 로 바꿔도 드롭다운이 따라온다
	CrtFx.preset_changed.connect(follow)
	opt.tree_exiting.connect(func(): CrtFx.preset_changed.disconnect(follow))   # 로비가 사라지면 끊는다 (autoload 는 남으므로)
	row.add_child(opt)
	return row


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
