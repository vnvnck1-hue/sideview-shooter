extends Node2D
## 크롤러 피격 컬러 프리셋 4종을 한 화면에서 비교하는 개발용 쇼케이스.
## 실행: godot --path . res://scenes/HitFxShowcase.tscn
## 캡처: godot --path . res://scenes/HitFxShowcase.tscn -- --capture

const OUTPUT := "res://../Assets/Generated/HitFxPresets/monster_hit_fx_presets.png"
const TITLES := ["01  WHITE SNAP", "02  COMPLEMENT PULSE", "03  TOXIC NEGATIVE", "04  HEAT ECHO"]
const SUBTITLES := [
	"hard full-body white hit",
	"soft complementary colour shift",
	"acid-green / violet negative",
	"two-stage ignition and shock ring",
]
const CAPTURE_PHASES := [0.12, 0.16, 0.10, 0.16]
const PANEL_SIZE := Vector2(750.0, 325.0)
const PANEL_ORIGINS := [Vector2(35, 125), Vector2(815, 125), Vector2(35, 470), Vector2(815, 470)]

var _monsters: Array[Crawler] = []
var _capture_mode := false
var _cycle_t := 0.0
var _selected := -1
var _selection_label: Label


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_capture_mode = "capture" in args or "--capture" in args
	if _capture_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
	RenderingServer.set_default_clear_color(Color("07090f"))
	_build_background()
	for i in range(4):
		_build_card(i)
	if _capture_mode:
		for i in range(4):
			_apply_phase(i, CAPTURE_PHASES[i])
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_capture()
		for child in get_children():
			child.queue_free()
		_monsters.clear()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit()


func _process(delta: float) -> void:
	if _capture_mode:
		return
	_cycle_t = fmod(_cycle_t + delta, 1.25)
	for i in range(_monsters.size()):
		var duration: float = Crawler.HIT_FX_PRESETS[i]["duration"]
		var phase := clampf(_cycle_t / duration, 0.0, 1.0)
		_apply_phase(i, phase if _selected < 0 or _selected == i else 1.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if _capture_mode or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var code := key.physical_keycode
	if code >= KEY_1 and code <= KEY_4:
		_selected = code - KEY_1
		_cycle_t = 0.0
		_selection_label.text = "LIVE  %d / %s    [0: ALL]" % [_selected + 1, Crawler.HIT_FX_PRESETS[_selected]["name"]]
		get_viewport().set_input_as_handled()
	elif code == KEY_0:
		_selected = -1
		_cycle_t = 0.0
		_selection_label.text = "LIVE  ALL FOUR    [1~4: ISOLATE]"
		get_viewport().set_input_as_handled()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1600, 900)
	bg.color = Color("07090f")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := _label("MONSTER HIT COLOUR FEEDBACK  /  4 PRESETS", 34, Color("f5f1df"))
	title.position = Vector2(55, 42)
	add_child(title)
	var note := _label("Same source sprite and hit point.  1~4: isolate/retrigger preset  ·  0: compare all", 18, Color("8793a8"))
	note.position = Vector2(58, 91)
	add_child(note)
	_selection_label = _label("LIVE  ALL FOUR", 18, Color("8ee7ff"))
	_selection_label.position = Vector2(1190, 91)
	add_child(_selection_label)


func _build_card(i: int) -> void:
	var origin: Vector2 = PANEL_ORIGINS[i]
	var card := ColorRect.new()
	card.position = origin
	card.size = PANEL_SIZE
	card.color = Color("111722")
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)

	var rail := ColorRect.new()
	rail.position = origin
	rail.size = Vector2(8, PANEL_SIZE.y)
	rail.color = [Color("f3ead0"), Color("63c9db"), Color("adff3d"), Color("ff5a22")][i]
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rail)

	var title := _label(TITLES[i], 26, Color("f4f0df"))
	title.position = origin + Vector2(31, 22)
	add_child(title)
	var subtitle := _label(SUBTITLES[i], 17, Color("8e9bad"))
	subtitle.position = origin + Vector2(33, 58)
	add_child(subtitle)

	var baseline := _label("SOURCE", 14, Color("566276"))
	baseline.position = origin + Vector2(46, 275)
	add_child(baseline)
	var result := _label("ON HIT", 14, Color("a9b4c3"))
	result.position = origin + Vector2(423, 275)
	add_child(result)

	# 왼쪽은 무효과 원본, 오른쪽은 해당 프리셋. 둘 다 실제 Crawler 셰이더를 쓴다.
	var source := Crawler.new()
	source.process_mode = Node.PROCESS_MODE_DISABLED
	source.set_hit_fx_preset(i)
	source.position = origin + Vector2(185, 260)
	source.scale = Vector2.ONE * 0.96
	add_child(source)
	source._mat.set_shader_parameter("flash", 0.0)

	var hit := Crawler.new()
	hit.process_mode = Node.PROCESS_MODE_DISABLED
	hit.set_hit_fx_preset(i)
	hit.position = origin + Vector2(565, 260)
	hit.scale = Vector2.ONE * 0.96
	add_child(hit)
	_monsters.append(hit)

	# 탄착점 표식. 피격 색 변화와 겹치지 않게 바깥에만 짧은 십자선을 둔다.
	var marker := _label("+", 22, Color(1.0, 0.42, 0.20, 0.72))
	marker.position = origin + Vector2(586, 157)
	add_child(marker)


func _apply_phase(i: int, phase: float) -> void:
	if i >= _monsters.size():
		return
	var mon := _monsters[i]
	var profile: Dictionary = Crawler.HIT_FX_PRESETS[i]
	var strength := float(profile["peak"]) * (1.0 - clampf(phase, 0.0, 1.0))
	mon._mat.set_shader_parameter("hit_fx_preset", i + 1)
	mon._mat.set_shader_parameter("hit_fx_phase", phase)
	mon._mat.set_shader_parameter("flash", strength)
	mon._mat.set_shader_parameter("radius_px", Crawler.HIT_FLASH_RADIUS)
	mon._mat.set_shader_parameter("hit_uv", Vector2(0.61, 0.49))


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _save_capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var image := get_viewport().get_texture().get_image()
	# 본 프로젝트는 평소 최대화+expand 모드다. 캡처에서는 디자인 캔버스만 잘라 비교판을 꽉 채운다.
	if image.get_width() > 1600 or image.get_height() > 900:
		image = image.get_region(Rect2i(0, 0, mini(image.get_width(), 1600), mini(image.get_height(), 900)))
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
	var err := image.save_png(OUTPUT)
	if err == OK:
		print("HIT_FX_SHOWCASE %s" % ProjectSettings.globalize_path(OUTPUT))
	else:
		push_error("피격 프리셋 캡처 저장 실패: %s" % error_string(err))
