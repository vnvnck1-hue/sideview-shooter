extends CanvasLayer
## 전역 CRT 모니터 오버레이 (autoload "CrtFx"). 루트 뷰포트 맨 위 층(100)에 풀스크린 ColorRect 를 두고 shaders/crt.gdshader 를 걸어
## 로비·게임·맵 뷰어·근경 랩 화면 전체(월드 + HUD)에 적용한다. 프리셋 표는 scripts/crt_preset.gd.
##   F4 다음 프리셋 · Shift+F4 이전 프리셋 → 화면 위쪽 토스트로 이름·설명을 잠깐 보여준다.
##   선택은 user://crt.cfg 에 저장. 환경 변수 CRT_PRESET=<번호|id> 가 있으면 저장값 대신 그것으로 시작한다.
##
## 단말기 접속(scripts/terminal_screen.gd)은 여기에 프리셋을 **밀어 넣었다가**(push_preset) 끊을 때 되돌린다(pop_preset).
## 밀어 넣은 동안은 F4 로 바꿀 수 없고 user://crt.cfg 에도 저장하지 않는다 — 플레이어가 고른 프리셋은 그대로 남는다.
## 전환 연출(collapse·flash·desync)은 프리셋 표 밖의 값이라 power_on/power_off/channel_glitch 가 직접 넣는다.

signal preset_changed(index: int)

const SAVE_PATH := "user://crt.cfg"
const TOAST_TIME := 2.6

## 전환 연출 기본 길이 (초) — Docs/TERMINAL_SYSTEM_CONCEPT.md §2 의 표와 같은 값
const POWER_ON_TIME := 0.34
const POWER_OFF_TIME := 0.26
const GLITCH_TIME := 0.57

var index := CrtPreset.DEFAULT
var _rect: ColorRect
var _mat: ShaderMaterial
var _toast: Label
var _toast_t := 0.0
var _stack: Array[int] = []       # push_preset 으로 밀어 둔 이전 인덱스들 (비어 있지 않으면 F4·저장 잠금)
var _fx_tween: Tween


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
	_toast.size = Vector2(AppFlow.VIEW_SIZE.x, 90)
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
	if _stack.is_empty():
		_save()                            # 단말기가 밀어 넣은 임시 프리셋은 저장하지 않는다
	preset_changed.emit(index)


func current() -> Dictionary:
	return CrtPreset.get_preset(index)


## 단말기 접속처럼 **잠깐만** 다른 프리셋을 쓰고 싶을 때. key 는 id("green") 또는 번호 문자열.
## 되돌릴 인덱스를 스택에 쌓아 두므로 중첩(단말기 → 원격 조종)해도 안전하다.
func push_preset(key: String) -> void:
	var i := CrtPreset.find(key)
	if i < 0:
		push_warning("CRT 프리셋 '%s' 을(를) 모릅니다 — 그대로 둡니다" % key)
		i = index
	_stack.append(index)
	set_preset(i, false)


func pop_preset() -> void:
	if _stack.is_empty():
		return
	set_preset(_stack.pop_back(), false)


func overridden() -> bool:
	return not _stack.is_empty()


## 전환 연출 값 (프리셋 표 밖). 평소엔 전부 0 이라 기존 프리셋에 영향이 없다.
func set_fx(collapse := 0.0, flash := 0.0, desync := 0.0) -> void:
	_mat.set_shader_parameter("collapse", collapse)
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("desync", desync)


func _fresh_fx_tween() -> Tween:
	if _fx_tween != null and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween()
	_fx_tween.set_parallel(true)
	return _fx_tween


func _fx(tw: Tween, param: String, from: float, to: float, time: float, trans: Tween.TransitionType, ease: Tween.EaseType, delay := 0.0) -> void:
	_mat.set_shader_parameter(param, from)
	tw.tween_method(func(v: float): _mat.set_shader_parameter(param, v), from, to, time) \
		.set_trans(trans).set_ease(ease).set_delay(delay)


## 전원 인가: 가운데 가로 한 줄에서 세로로 펼쳐지며 한 번 하얗게 번쩍인다.
func power_on(time := POWER_ON_TIME) -> void:
	var tw := _fresh_fx_tween()
	set_fx(1.0, 0.0, 0.0)
	_fx(tw, "flash", 0.9, 0.0, time * 0.5, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_fx(tw, "collapse", 1.0, 0.0, time, Tween.TRANS_CUBIC, Tween.EASE_OUT)


## 전원 차단: 가로 한 줄로 빨려 들어가고 마지막에 잔광이 튄다.
func power_off(time := POWER_OFF_TIME) -> void:
	var tw := _fresh_fx_tween()
	_fx(tw, "collapse", 0.0, 1.0, time, Tween.TRANS_CUBIC, Tween.EASE_IN)
	_fx(tw, "flash", 0.0, 0.55, time * 0.25, Tween.TRANS_SINE, Tween.EASE_OUT, time * 0.78)
	tw.chain().tween_callback(func(): set_fx(0.0, 0.0, 0.0))


## 채널 전환: 행이 찢기고 잡음이 치솟았다가 가라앉는다. 가운데(hold 시점)에서 월드를 바꾸면 이음매가 보이지 않는다.
## on_switch 는 가장 어지러운 순간에 한 번 불린다.
func channel_glitch(on_switch: Callable = Callable(), time := GLITCH_TIME) -> void:
	var tw := _fresh_fx_tween()
	var base_noise := float(CrtPreset.params(index)["noise"])
	_fx(tw, "desync", 0.0, 1.0, time * 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_fx(tw, "desync", 1.0, 0.0, time * 0.45, Tween.TRANS_SINE, Tween.EASE_IN_OUT, time * 0.55)
	_fx(tw, "flash", 0.0, 0.35, time * 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	_fx(tw, "flash", 0.35, 0.0, time * 0.3, Tween.TRANS_SINE, Tween.EASE_IN, time * 0.12)
	tw.tween_method(func(v: float): _mat.set_shader_parameter("noise", v), base_noise, 0.22, time * 0.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): _mat.set_shader_parameter("noise", v), 0.22, base_noise, time * 0.45) \
		.set_delay(time * 0.55)
	tw.chain().tween_callback(func(): set_fx(0.0, 0.0, 0.0))
	if on_switch.is_valid():
		# 화면이 가장 어지러운 순간(찢김이 최대로 오른 직후)에 월드를 바꾼다 — 이음매가 글리치에 묻힌다
		get_tree().create_timer(time * 0.33).timeout.connect(on_switch)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("crt_cycle") and not overridden():
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
