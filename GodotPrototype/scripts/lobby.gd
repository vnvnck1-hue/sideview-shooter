extends Control
## 로비: 시작 씬(project.godot run/main_scene). 마우스 버튼으로 고른다.
##   [메인 게임]   에어록에서 시작해 전체 맵(방 21개, 구역 4개)을 탐색한다 (scenes/MainGame.tscn)
##   [맵 뷰어]     방을 게임 없이 조립해 자유 카메라로 본다. [ ] 로 방 전환 (scenes/MapViewer.tscn)
##   [대화 UI 랩]  대사 표시 방식 5종을 실제 화면에서 1~5 로 바꿔 가며 비교한다 (scenes/DialogueLab.tscn)
##   [사족보행 랩] 인게임 기체의 보행·관절 수치를 조정한다. 원화 피벗 편집기도 여기서 연다.
##   [공간 테스트] 기본 타일로 만든 20,000px 한 줄에서 넓이·길이·트랜지션 없는 방 연결을 본다 (scenes/SpaceLab.tscn)
##   [규격 테스트] 그레이박스로 문·통로·턱·상자·층고·프랍 후보 치수를 캐릭터와 비교한다 (scenes/ScaleLab.tscn)
##   [공간감 테스트] 성격이 다른 다섯 공간을 이은 그레이박스에서 패럴렉스·명도·깊이별 조명·점프/사다리 동선·카메라 워킹을 본다 (scenes/DepthLab.tscn)
##   [갤러리 타일 테스트] 기존 Main 씬에서 서비스 갤러리 타일과 플레이어·몬스터를 함께 시험한다.
##   [조명·면 랩]  실제 게임 그대로 플레이하면서 방 안의 광원 수치와 프랍 면 맵을 고치고 저장한다 (scenes/FaceLab.tscn)
##   [화면 모드]   창 모드(최대화) / 전체화면. 고른 값은 저장돼 다음 실행에도 유지된다 (autoload ViewFit). 게임 안에서는 F11
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

	var view := _button("▦   맵 뷰어", "방을 게임 없이 조립해 자유 카메라로 본다. [ ] 방 전환 · 휠 줌 · WASD 이동 · F1 로비")
	view.pressed.connect(func(): AppFlow.start_map_viewer(get_tree()))
	box.add_child(view)

	var dlg := _button("✎   대화 UI 랩 — 대사 표시 방식 비교", "실제 방·인물 위에서 대사 표시 방식 5종(카타나 제로 · 비주얼 노벨 · 자막 · 누적 로그 · 레트로 박스)을 1~5 로 바꿔 가며 본다. [ ] 상대 바꾸기 · R 다시 · F1 로비")
	dlg.pressed.connect(func(): AppFlow.start_dialogue_lab(get_tree()))
	box.add_child(dlg)

	var walker := _button("⮟   사족보행 랩 — 인게임 보행 튜닝", "인게임 기체의 관절 각도·보폭·발 높이·스텝 시간을 실시간 조정합니다. Ctrl+S 저장하면 인게임에도 적용. 상단 피벗·키프레임 버튼으로 원화 편집기를 엽니다.")
	walker.pressed.connect(func(): AppFlow.start_walker_lab(get_tree()))
	box.add_child(walker)

	var face := _button("◧   조명·면 랩 — 실제 플레이 위에서 조명과 면을 고친다", "본편과 똑같이 플레이(이동·조준·사격)하면서, 방 안의 광원을 우클릭으로 고르고 세기·반경·높이를 슬라이더로 맞춘다. 저장하면 lighting/tuning.json 에 쓰여 본편에 그대로 적용된다. 총구·탄착처럼 클릭할 수 없는 광원은 G 로 순환. 프랍 면 맵(기울기·디테일·번짐)도 같은 패널에서. F5 패널 · Tab 광원 · N 면↔자동 · F1 로비")
	face.pressed.connect(func(): AppFlow.start_face_lab(get_tree()))
	box.add_child(face)

	var space := _button("◻   공간 테스트 — 이어진 대공간 %d px" % SpaceLabData.total_width(), "기본 배경 타일(workshop)로 세운 방 5개를 낮은 연결 통로로 이어 붙인 한 줄. 끝에서 끝까지 걸어도 페이드가 없다 — 문틀을 지나면 바로 옆방이다. 몬스터·센트리건·보행 기체·프랍·조명이 모두 들어 있다. [ ] 구획 건너뛰기 · F3 줌 · F1 로비")
	space.pressed.connect(func(): AppFlow.start_space_lab(get_tree()))
	box.add_child(space)

	var scale_btn := _button("▤   규격 테스트 — 그레이박스 치수 비교", "문 높이 · 낮은 통로 · 턱과 계단 · 엄폐 상자 · 층고 · 배경 프랍 · 기존 아트 · 타일 연결부를 캐릭터로 직접 걸어 보며 비교한다. 후보마다 치수와 판정(서서 통과·구르기로만·불가)이 붙는다. [ ] 구역 · , . 후보 · G 세로 판정 · T 턱 한계 · N 충돌 끄기 · H 라벨 · F1 로비")
	scale_btn.pressed.connect(func(): AppFlow.start_scale_lab(get_tree()))
	box.add_child(scale_btn)
	# 기존 run.bat → Lobby 흐름에서 바로 열 수 있게 고정 버튼으로 둔다.
	# 긴 랩 목록의 하단은 작은 창에서 잘릴 수 있으므로 버튼을 별도 진입점으로 둔다.
	var gallery := _button("▦   서비스 갤러리 타일 테스트", "기존 게임 씬에서 앞·뒤·반복 타일, 플레이어 이동·사격, 크롤러 AI를 시험한다. F1 로비")
	gallery.anchor_left = 1.0                  # 우상단 고정 (캔버스가 창 비율로 늘어난다)
	gallery.anchor_right = 1.0
	gallery.offset_left = -730.0
	gallery.offset_top = 30.0
	gallery.offset_right = -30.0
	gallery.offset_bottom = 92.0
	gallery.pressed.connect(func(): AppFlow.start_service_gallery_test(get_tree()))
	add_child(gallery)
	# 공간감 테스트도 같은 우상단 줄에 둔다 (가운데 목록은 900 높이 창에서 이미 꽉 찬다)
	var depth_btn := _button("▥   공간감 테스트 — 이어진 다섯 공간", "도킹 관측 회랑(우주) · 다층 격납고 · 환풍 덕트 · 수직 샤프트 · 전력 홀 캣워크를 한 줄로 이은 그레이박스. 패럴렉스 레이어 · 깊이별 조명 · 점프/사다리 동선 · 크롤러·센트리건·버그봇 · 카메라 워킹 7종(C). [ ] 구역 · 1 2 3 속도 · L 레이어 · V 명도만 · F1 로비")
	depth_btn.anchor_left = 1.0
	depth_btn.anchor_right = 1.0
	depth_btn.offset_left = -730.0
	depth_btn.offset_top = 104.0
	depth_btn.offset_right = -30.0
	depth_btn.offset_bottom = 166.0
	depth_btn.pressed.connect(func(): AppFlow.start_depth_lab(get_tree()))
	add_child(depth_btn)

	box.add_child(_spacer(6))
	box.add_child(_display_row())
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


## "화면 모드  [창 모드 / 전체화면]" 한 줄. 바꾸면 즉시 적용되고 user://display.cfg 에 저장된다 (ViewFit).
func _display_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := _label("▭   화면 모드", 24, Color(0.85, 0.83, 0.78))
	l.custom_minimum_size = Vector2(230, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var opt := _option()
	opt.add_item("창 모드 (최대화)", 0)
	opt.set_item_tooltip(0, "작업 표시줄이 보이는 최대화된 창. 창 테두리로 크기를 바꿀 수 있다")
	opt.add_item("전체화면", 1)
	opt.set_item_tooltip(1, "모니터 전체를 쓴다. 게임 안에서는 F11 로도 바꾼다")
	opt.select(1 if ViewFit.fullscreen else 0)
	opt.item_selected.connect(func(i: int): ViewFit.set_fullscreen(i == 1))
	var follow := func(on: bool): opt.select(1 if on else 0)    # F11 로 바꿔도 드롭다운이 따라온다
	ViewFit.mode_changed.connect(follow)
	opt.tree_exiting.connect(func(): ViewFit.mode_changed.disconnect(follow))
	row.add_child(opt)
	return row


func _option() -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 50)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_override("font", _font)
	opt.add_theme_font_size_override("font_size", 22)
	opt.get_popup().add_theme_font_override("font", _font)
	opt.get_popup().add_theme_font_size_override("font_size", 22)
	return opt


## "CRT 모니터  [드롭다운]" 한 줄. 바꾸면 즉시 전역 오버레이(CrtFx)에 적용되고 저장된다.
func _crt_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := _label("▣   CRT 모니터", 24, Color(0.85, 0.83, 0.78))
	l.custom_minimum_size = Vector2(230, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var opt := _option()
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
