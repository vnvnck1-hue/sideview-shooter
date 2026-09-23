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


## 시작 프리셋: 환경 변수 > **고정 기본값**.
##
## 예전엔 저장 파일(user://crt.cfg)이 기본값을 이겼다. 그래서 F4 로 한 번 바꾸면 그 뒤로 모든 씬이
## 그 화면으로 시작했고, 사람마다 보는 그림이 달라 연출을 맞출 기준이 없었다 (기체 접속 연출이
## 프리셋을 한 단 떨어뜨리는데, 출발점이 제각각이면 그 "한 단" 이 의미를 잃는다).
## 이제 **늘 CrtPreset.DEFAULT 로 시작한다.** F4 는 개발용 비교 전환으로 남고, 저장하지 않는다.
## CRT_PRESET 환경 변수만 예외다 — 스크린샷 도구가 특정 화면을 강제할 때 쓴다.
func _initial_index() -> int:
	var env := OS.get_environment("CRT_PRESET")
	if env != "":
		var i := CrtPreset.find(env)
		if i >= 0:
			return i
		push_warning("CRT_PRESET=%s 을(를) 모릅니다 — 기본값 사용" % env)
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
##
## power 는 **세기**다 (1.0 = 예전 그대로). 접속 연출처럼 여러 번 이어 칠 때 뒤로 갈수록 낮춰
## "접촉 불량이 잦아들다 제대로 붙는" 느낌을 만든다 — walker_link.gd 의 SETTLE 참고.
func channel_glitch(on_switch: Callable = Callable(), time := GLITCH_TIME, power := 1.0) -> void:
	var tw := _fresh_fx_tween()
	var base_noise := float(CrtPreset.params(index)["noise"])
	var k := clampf(power, 0.0, 1.0)
	var peak_noise: float = lerpf(base_noise, 0.22, k)
	_fx(tw, "desync", 0.0, k, time * 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	_fx(tw, "desync", k, 0.0, time * 0.45, Tween.TRANS_SINE, Tween.EASE_IN_OUT, time * 0.55)
	_fx(tw, "flash", 0.0, 0.35 * k, time * 0.12, Tween.TRANS_SINE, Tween.EASE_OUT)
	_fx(tw, "flash", 0.35 * k, 0.0, time * 0.3, Tween.TRANS_SINE, Tween.EASE_IN, time * 0.12)
	tw.tween_method(func(v: float): _mat.set_shader_parameter("noise", v), base_noise, peak_noise, time * 0.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): _mat.set_shader_parameter("noise", v), peak_noise, base_noise, time * 0.45) \
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


## **더 이상 저장하지 않는다** (2026-09-23). 프리셋은 CrtPreset.DEFAULT 로 고정이고 F4 는
## 개발용 비교 전환이다 — 저장하면 그 비교가 다음 실행의 기준을 바꿔 버린다 (_initial_index 주석 참고).
## 예전에 저장해 둔 파일이 있으면 지운다 — 남겨 두면 나중에 되살릴 때 옛 값이 튀어나온다.
func _save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _add_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
