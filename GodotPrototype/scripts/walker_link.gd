class_name WalkerLink
extends Control
## 사족보행 기체 **접속 연출** (2026-09-23). 기체를 타고 내릴 때 잠깐 끼어드는 화면.
##
## "기계에 올라탄다" 가 아니라 **기계의 소프트웨어에 접속한다**로 읽히게 만든 연출이다 —
## 핸드셰이크·자이로 교정·유압 압력을 차례로 확인하고 링크가 서면 그때 조종이 넘어간다.
## 그래서 조종 주체가 플레이어에서 기체로 바뀌는 순간(카메라·입력)이 **연출 한가운데 숨는다.**
## 그냥 바꾸면 화면이 툭 튀고, 플레이어가 "내가 지금 누구를 움직이는가" 를 한 박자 놓친다.
##
## ## 여기는 연출만 한다
## 무엇을 바꿀지는 전혀 모른다 — 한가운데에서 부를 `on_switch` 콜백 하나만 받는다.
## 카메라 주체 교체·입력 이양은 전부 Main 이 그 콜백 안에서 한다. 연출을 통째로 들어내도
## 게임은 (연출 없이) 그대로 돈다.
##
## CRT 채널 글리치(CrtFx)는 단말기 원격 접속이 쓰는 것과 **같은 것**을 쓴다 — 이 세계에서
## "다른 기계의 눈으로 갈아탄다" 는 늘 같은 소리를 내야 하기 때문이다.

## 한 줄이 뜨고 다음 줄이 뜨기까지 (초)
const LINE_STEP := 0.10
## 마지막 줄이 뜬 뒤 링크가 서기까지 — 이 끝에서 on_switch 를 부른다
const SETTLE := 0.16
## 접속 끊기 연출 길이
const OUT_TIME := 0.42

## ## 접속이 "붙는" 소리 — 한 번이 아니라 **세 번, 점점 약하게** (2026-09-23)
## 예전엔 글리치를 한 번만 쳤다. 그러면 화면이 한 번 튀고 끝이라 **접속했다는 사실이 잘 안 남았다.**
## 지금은 3초에 걸쳐 세 번 친다 — 세기와 길이가 함께 줄어 "접촉이 한두 번 튀다가 제대로 붙는다"로 읽힌다.
## [연출 시작으로부터의 시각(초), 세기, 길이] · **첫 번째의 가운데에서 주체가 갈린다.**
const SETTLE_GLITCHES := [
	[0.00, 1.00, 0.57],
	[1.15, 0.62, 0.42],
	[2.35, 0.34, 0.34],
]
## 위 표가 다 끝나는 시각 (2.35 + 0.34 에 여유). 이만큼은 연출이 화면을 붙들고 있어야 한다
const SETTLE_SPAN := 3.0

## CRT 전원 인가 길이. 가운데 가로 한 줄에서 세로로 펼쳐지며 한 번 번쩍인다 —
## "모니터가 켜졌다" 는 이 동작 하나로 설명된다. 기체의 눈이 막 들어온 순간이다.
const POWER_ON := 0.42

const PANEL_SIZE := Vector2(760, 250)
const C_PANEL := Color(0.031, 0.055, 0.047, 0.90)
const C_EDGE := Color(0.25, 0.92, 0.62, 0.85)
const C_TEXT := Color(0.62, 0.98, 0.76)
const C_DIM := Color(0.62, 0.98, 0.76, 0.45)
const C_WASH := Color(0.02, 0.05, 0.04)          # 화면 전체를 덮는 어둠

## 접속할 때 차례로 뜨는 줄. 마지막 줄이 링크 확립이다.
const BOOT_LINES := [
	"원격 진단 포트 개방",
	"핸드셰이크 — 기체 펌웨어 응답",
	"자이로 · 보행 솔버 교정",
	"유압 압력 정상 · 포열 냉각 정상",
]

signal finished

var _wash: ColorRect
var _panel: Panel
var _title: Label
var _body: Label
var _hint: Label
var _tw: Tween
var _busy := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_wash = ColorRect.new()
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.color = C_WASH
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wash)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "D2Coding", "맑은 고딕", "Malgun Gothic", "Segoe UI"])

	_panel = Panel.new()
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_color = C_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 34.0
	sb.content_margin_top = 26.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_title = _label(font, 30, C_EDGE, Vector2(34, 22))
	_body = _label(font, 24, C_TEXT, Vector2(34, 74))
	_hint = _label(font, 22, C_DIM, Vector2(34, PANEL_SIZE.y - 50.0))
	for l in [_title, _body, _hint]:
		_panel.add_child(l)


func _label(font: Font, size: int, col: Color, at: Vector2) -> Label:
	var l := Label.new()
	l.position = at
	l.size = Vector2(PANEL_SIZE.x - 68.0, PANEL_SIZE.y)
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func busy() -> bool:
	return _busy


## 접속. 줄이 하나씩 뜨고 마지막에 링크가 서면서 on_switch 를 부른다.
## machine_name 은 단말기 그리드에 쓰는 것과 같은 이름 (예: "격납고 보행 기체").
func link_in(machine_name: String, on_switch: Callable) -> void:
	if _busy:
		if on_switch.is_valid():
			on_switch.call()          # 연출이 겹치면 연출만 건너뛴다 — 게임은 절대 막지 않는다
		return
	_busy = true
	_center()
	_sfx("walker_link")                  # 링크가 붙는 소리 — 연출 길이(약 1.6초)와 맞춰 둔 파일이다
	_title.text = "▸ 원격 조종 링크   %s" % machine_name.to_upper()
	_body.text = ""
	_hint.text = ""
	visible = true
	_wash.color = Color(C_WASH, 0.0)
	_panel.modulate = Color(1, 1, 1, 0)

	_tw = create_tween()
	_tw.tween_property(_wash, "color:a", 0.55, 0.12)
	_tw.parallel().tween_property(_panel, "modulate:a", 1.0, 0.10)
	var shown := ""
	for line in BOOT_LINES:
		shown += ("" if shown == "" else "\n") + "  " + line
		_tw.tween_callback(_show_lines.bind(shown))
		_tw.tween_interval(LINE_STEP)
	# 화면이 한 번 튀는 그 순간에 주체를 갈아 끼운다 (단말기 원격 접속과 같은 소리)
	_tw.tween_callback(_establish.bind(on_switch))
	_tw.tween_interval(SETTLE)
	_tw.tween_property(_panel, "modulate:a", 0.0, 0.16)
	_tw.parallel().tween_property(_wash, "color:a", 0.0, 0.20)
	# 패널이 걷힌 뒤에도 **지지직이 잦아들 때까지** 연출을 붙들고 있는다 —
	# 여기서 끝내 버리면 아직 튀는 화면 위로 안내 문구·HUD 가 도로 올라온다.
	_tw.tween_interval(maxf(SETTLE_SPAN - SETTLE - 0.36, 0.0))
	_tw.tween_callback(_done)


## 접속 해제. 전원이 꺼지듯 짧게 닫고 on_switch 에서 주체를 플레이어로 되돌린다.
func link_out(on_switch: Callable) -> void:
	if _busy:
		if on_switch.is_valid():
			on_switch.call()
		return
	_busy = true
	_center()
	_title.text = "▸ 링크 해제"
	_body.text = "\n  제어권 반환 — 기체 대기 모드"
	_hint.text = ""
	visible = true
	_wash.color = Color(C_WASH, 0.0)
	_panel.modulate = Color(1, 1, 1, 0)

	_tw = create_tween()
	_tw.tween_property(_wash, "color:a", 0.5, 0.10)
	_tw.parallel().tween_property(_panel, "modulate:a", 1.0, 0.10)
	_tw.tween_callback(_glitch.bind(on_switch))
	_tw.tween_interval(OUT_TIME * 0.4)
	_tw.tween_property(_panel, "modulate:a", 0.0, 0.14)
	_tw.parallel().tween_property(_wash, "color:a", 0.0, 0.18)
	_tw.tween_callback(_done)


## 부팅 줄을 여기까지 보여 준다 (tween_callback 이 부른다)
func _show_lines(text: String) -> void:
	_body.text = text


## 링크가 서는 순간. 셋이 겹친다.
##   1) **CRT 전원 인가** — 기체의 눈이 막 들어온다 (가운데 한 줄에서 세로로 펼쳐지며 번쩍)
##   2) 그 위로 세 번의 지지직이 3초에 걸쳐 잦아든다 (SETTLE_GLITCHES)
##   3) 첫 지지직의 한가운데에서 주체가 갈린다 — 이음매가 거기 묻힌다
func _establish(on_switch: Callable) -> void:
	_hint.text = "링크 확립 — 이 기체가 당신입니다.   S / Ctrl / ↓ 로 접속 해제"
	var crt := _crt()
	if crt == null:
		if on_switch.is_valid():
			on_switch.call()
		return
	crt.power_on(POWER_ON)
	for i in SETTLE_GLITCHES.size():
		var g: Array = SETTLE_GLITCHES[i]
		var cb: Callable = on_switch if i == 0 else Callable()
		_after(float(g[0]) + POWER_ON * 0.5, _fire_glitch.bind(cb, float(g[2]), float(g[1])))


## 예약된 시각에 지지직 한 번. 오버레이가 없으면(랩·헤드리스) 건너뛰되
## **주체 교체 콜백만은 반드시 부른다** — 연출 사정으로 조종이 안 넘어가면 그게 훨씬 큰 문제다.
func _fire_glitch(on_switch: Callable, time: float, power: float) -> void:
	var crt := _crt()
	if crt != null:
		crt.channel_glitch(on_switch, time, power)
	elif on_switch.is_valid():
		on_switch.call()


func _after(delay: float, cb: Callable) -> void:
	if delay <= 0.0:
		cb.call()
		return
	get_tree().create_timer(delay).timeout.connect(cb)


## 화면 한가운데로. 방마다 뷰포트가 같으므로 열 때 한 번만 맞추면 된다.
func _center() -> void:
	var vp := get_viewport_rect().size
	_panel.position = ((vp - PANEL_SIZE) * 0.5).round()


## 효과음 한 발. 오디오 오토로드가 없는 환경(랩·헤드리스)에서는 조용히 넘어간다 —
## 소리가 없다고 연출이나 조종이 막히면 안 된다.
func _sfx(key: String) -> void:
	var a := get_node_or_null("/root/Audio")
	if a != null and a.has_method("play"):
		a.play(key)


## 전역 CRT 오버레이. 랩·헤드리스처럼 오토로드가 없는 환경에서는 null 이다.
func _crt() -> Node:
	var n := get_node_or_null("/root/CrtFx")
	return n if n != null and n.has_method("channel_glitch") else null


## 채널 글리치 한 번 (접속 해제가 쓴다)
func _glitch(on_switch: Callable) -> void:
	_fire_glitch(on_switch, 0.5, 1.0)


func _done() -> void:
	visible = false
	_busy = false
	finished.emit()
