extends CanvasLayer
## 전역 CRT 모니터 오버레이 (autoload "CrtFx"). 루트 뷰포트 맨 위 층(100)에 풀스크린 ColorRect 를 두고 shaders/crt.gdshader 를 걸어
## 로비·게임·맵 뷰어·근경 랩 화면 전체(월드 + HUD)에 적용한다. 프리셋 표는 scripts/crt_preset.gd.
##   F4 다음 프리셋 · Shift+F4 이전 프리셋 → 화면 위쪽 토스트로 이름·설명을 잠깐 보여준다.
##   선택은 user://crt.cfg 에 저장. 환경 변수 CRT_PRESET=<번호|id> 가 있으면 저장값 대신 그것으로 시작한다.

signal preset_changed(index: int)

const SAVE_PATH := "user://crt.cfg"
const TOAST_TIME := 2.6

var index := CrtPreset.DEFAULT
var _rect: ColorRect
var _mat: ShaderMaterial
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/crt.gdshader")
	_rect = ColorRect.new()
	_rect.name = "CrtRect"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	_toast = Label.new()
	_toast.name = "CrtToast"
	_toast.position = Vector2(0, 150)
	_toast.size = Vector2(1600, 90)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_override("font", font)
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("shadow_offset_x", 2)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_toast.visible = false
	add_child(_toast)                      # 오버레이 위에 그려져 CRT 효과를 받지 않는다 (읽기 쉽게)

	_add_action("crt_cycle", KEY_F4)
	set_preset(_initial_index(), false)


## 시작 프리셋: 환경 변수 > 저장 파일 > 기본값
func _initial_index() -> int:
	var env := OS.get_environment("CRT_PRESET")
	if env != "":
		var i := CrtPreset.find(env)
		if i >= 0:
			return i
		push_warning("CRT_PRESET=%s 을(를) 모릅니다 — 저장값/기본값 사용" % env)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved := CrtPreset.find(str(cfg.get_value("crt", "preset", "")))
		if saved >= 0:
			return saved
	return CrtPreset.DEFAULT


func set_preset(i: int, show_toast := true) -> void:
	index = wrapi(i, 0, CrtPreset.count())
	CrtPreset.apply(_mat, index)
	_rect.visible = index != 0            # "끄기"는 셰이더 자체를 그리지 않는다 (백버퍼 복사 비용 0)
	if show_toast:
		var p := CrtPreset.get_preset(index)
		_toast.text = "CRT 모니터 (F4 다음 · Shift+F4 이전)   %s\n%s" % [CrtPreset.hud_line(index), p["desc"]]
		_toast.visible = true
		_toast_t = TOAST_TIME
	_save()
	preset_changed.emit(index)


func current() -> Dictionary:
	return CrtPreset.get_preset(index)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("crt_cycle"):
		set_preset(index - 1 if Input.is_key_pressed(KEY_SHIFT) else index + 1)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast.visible = false


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("crt", "preset", CrtPreset.get_preset(index)["id"])
	cfg.save(SAVE_PATH)


func _add_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
