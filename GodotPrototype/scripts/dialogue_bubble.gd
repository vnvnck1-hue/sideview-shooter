class_name DialogueBubble
extends Control
## 대사 표시 — **한 자씩 찍는 타자 엔진 하나**에 **표시 방식(STYLES) 다섯 가지**를 얹는다.
##
## 어느 방식이 이 게임에 맞는지 비교하려고 만들었다. 실행 중 전환할 수 있고
## (대화 랩 scenes/DialogueLab.tscn · 게임 안에서는 F7), 고른 값은 static 이라 씬을 다시 로드해도 남는다.
## GameCamera.PRESETS · CrtPreset.PRESETS · DepthPreset.PRESETS 와 같은 방식이다.
##
## ── 공통: 글자 연출 (모든 방식이 같이 쓴다) ────────────────────────────────
##   1. 한 자씩 찍히고, 찍히는 순간 아래에서 짧게 올라오며 밝아진다 (POP)
##   2. **찍힌 글자는 가만히 있는다.** 상시 떨림은 읽기를 방해해서 쓰지 않는다 —
##      움직이는 글자는 [shake] · [wave] 로 **직접 지정한 구간뿐**이고, 그래서 그 구간이 눈에 띈다
##   3. 문장부호 뒤에는 저절로 쉰다. 태그로 더 쉬거나 속도를 바꿀 수 있다
##   4. 강조는 색 · 흔들림 · 물결 세 가지뿐. 굵게/기울임은 쓰지 않는다
##   5. 상자는 글 전체 크기로 먼저 잡고 열린다 (글이 늘어나며 커지지 않는다)
##   6. 확인 키를 미리 누르면 남은 글자가 한꺼번에 앉는다
##
## 대사 태그 (npc_data.gd 가 쓴다):
##   [shake]…[/shake]   떤다 — 한 대화에 한두 번만
##   [wave]…[/wave]     물결친다 — 비꼼 · 힘 빠짐
##   [c=#rrggbb]…[/c]   글자색 — 사람 이름, 결정적인 낱말
##   [p=0.4]            그 자리에서 0.4초 쉰다
##   [s=0.7]…[/s]       그 구간 타자 속도 배율 (작을수록 느리다)
##
## 좌표는 **창 좌표(AppFlow.VIEW_SIZE)** 다. 월드에 선 인물의 머리 좌표는 Main.world_to_screen 이 넘겨준다.

signal line_completed()                 # 한 줄이 다 찍혔다 (선택지를 띄울 시점)
signal advanced()                       # 다 찍힌 줄에서 확인 키 — 다음 줄로
signal choice_picked(index: int)

enum Fx {NONE, SHAKE, WAVE}

## 표시 방식. 실제 게임들이 쓰는 갈래를 하나씩 가져왔다.
##   place     head(말하는 사람 머리 위) · bottom(화면 하단 가운데) · side(오른쪽 아래)
##   panel     hud(각진 어두운 판) · band(하단 전폭 띠) · none(상자 없음) · retro(흰 테두리 상자) · log(왼쪽 강조 막대)
##   tail      꼬리를 달아 말하는 사람을 가리키는가 (place=head 에서만 뜻이 있다)
##   name_mode plate(패널에 꽂힌 이름표) · inline(대사 앞에 이름을 붙여 같이 찍는다) · none
##   choices   rows(캐럿 + 강조 막대) · numbered(1. 2. 3. 번호 — 이 방식에서만 숫자 키로 바로 고를 수 있다)
##   log       위에 남겨 두는 지난 줄 수 (0 이면 안 남긴다)
##   mono      고정폭 글꼴
##   width     글 상자 안쪽 최대 폭. fixed 면 글이 짧아도 이 폭을 유지한다
##   lines     최소 줄 수 (하단 띠가 한 줄짜리 대사에서 납작해지지 않게)
const STYLES := [
	{
		"id": "katana", "name": "카타나 제로",
		"desc": "말하는 사람 머리 위 HUD 패널 + 꼬리. 화면을 안 가리고 누가 말하는지가 위치로 읽힌다",
		"place": "head", "panel": "hud", "tail": true, "name_mode": "plate",
		"choices": "rows", "log": 0, "mono": false, "width": 700.0, "fixed": false, "lines": 0,
	},
	{
		"id": "vn", "name": "비주얼 노벨",
		"desc": "화면 하단 전폭 띠 + 이름표. 대사가 길어도 자리가 넉넉하지만 화면 아래를 계속 덮는다",
		"place": "bottom", "panel": "band", "tail": false, "name_mode": "plate",
		"choices": "rows", "log": 0, "mono": false, "width": 1820.0, "fixed": true, "lines": 2,
	},
	{
		"id": "subtitle", "name": "자막",
		"desc": "상자 없이 하단 자막. 이름은 대사 앞에 색으로만. 화면을 가장 적게 가린다",
		"place": "bottom", "panel": "none", "tail": false, "name_mode": "inline",
		"choices": "rows", "log": 0, "mono": false, "width": 1200.0, "fixed": false, "lines": 0,
	},
	{
		"id": "log", "name": "누적 로그",
		"desc": "오른쪽에 지난 줄이 쌓인다. 흐름을 놓치지 않지만 시선이 인물에서 떠난다",
		"place": "side", "panel": "log", "tail": false, "name_mode": "inline",
		"choices": "numbered", "log": 4, "mono": false, "width": 620.0, "fixed": true, "lines": 0,
	},
	{
		"id": "retro", "name": "레트로 박스",
		"desc": "가운데 아래 흰 테두리 상자 + 고정폭 글꼴(한글 고정폭이 없는 PC 는 기본 글꼴로 떨어진다). 고전 RPG 의 결",
		"place": "bottom", "panel": "retro", "tail": false, "name_mode": "inline",
		"choices": "rows", "log": 0, "mono": true, "width": 980.0, "fixed": true, "lines": 2,
	},
]
## 지금 방식. static 이라 씬을 다시 로드해도 남는다. 환경 변수 DIALOGUE_STYLE 로 시작값 고정 가능.
static var style_index := 0

const FONT_SIZE := 26
const CHOICE_FONT_SIZE := 23
const NAME_FONT_SIZE := 17
const LINE_H := 38.0
const CHOICE_H := 36.0
const PAD := Vector2(26.0, 20.0)
const CHAMFER := 12.0                   # 모서리를 깎는 폭 (각진 픽셀 UI 느낌)
const BORDER := 3.0
const TAIL_W := 40.0
const TAIL_H := 26.0
const HEAD_GAP := 30.0                  # 머리 꼭대기와 꼬리 끝 사이
const MARGIN := 28.0                    # 화면 가장자리 여유
const BOTTOM_MARGIN := 54.0             # 하단 방식이 바닥에서 띄우는 거리
const OPEN_TIME := 0.11
const CLOSE_TIME := 0.08

## 게임 HUD 와 같은 결: 거의 검은 청회색 판 + 밝은 회백색 글자.
const BG := Color(0.055, 0.065, 0.085, 0.96)
const BG_TOP := Color(0.10, 0.115, 0.145, 0.96)   # 위쪽이 아주 살짝 밝다 (평평한 판이 아니게)
const BG_BAND := Color(0.04, 0.048, 0.062, 0.90)  # 하단 띠 — 화면을 넓게 덮으므로 더 어둡고 투명하게
const BG_RETRO := Color(0.02, 0.02, 0.025, 0.98)
const BG_LOG := Color(0.03, 0.036, 0.048, 0.80)
const EDGE_DARK := Color(0.015, 0.018, 0.025, 0.95)
const RETRO_EDGE := Color(0.92, 0.93, 0.90)
const INK := Color(0.87, 0.88, 0.85)
const INK_DIM := Color(0.52, 0.55, 0.58)
const INK_LOG := Color(0.42, 0.45, 0.50)          # 지나간 줄
const SHADOW := Color(0.0, 0.0, 0.0, 0.5)
const TEXT_SHADOW := Color(0.0, 0.0, 0.0, 0.85)   # 상자 없는 방식의 글자 그림자

## 한 자 찍는 데 걸리는 기본 시간. 인물마다 말투가 다르다 (CAST.voice)
const VOICES := {
	"slow":    {"cps": 27.0},
	"soft":    {"cps": 31.0},
	"clipped": {"cps": 39.0},
	"quick":   {"cps": 44.0},
	"machine": {"cps": 34.0},
}
const PUNCT_PAUSE := {".": 0.20, "!": 0.24, "?": 0.24, ",": 0.11, "…": 0.28, "—": 0.16, "·": 0.10}

const POP_TIME := 0.11                  # 한 글자가 제자리에 앉기까지
const POP_RISE := 5.0                   # 튀어 오르는 높이 (px). 얕게 — 글줄이 출렁이면 읽기 힘들다
const SHAKE_HZ := 22.0                  # [shake] 구간만 이 빈도로 끊어 흔든다
const SHAKE_AMP := 2.6
const WAVE_AMP := 3.0

var open := false

var _font: Font
var _mono: Font
var _glyphs: Array = []                 # [{ch, pos(상자 안쪽 기준), line, adv, color, fx, t}]
var _text_size := Vector2.ZERO
var _box := Rect2()
var _anchor := Vector2.ZERO             # 꼬리가 가리키는 점 (말하는 사람 머리 꼭대기, 창 좌표)
var _accent := Color(1, 1, 1)
var _name := ""
var _raw := ""                          # 태그가 살아 있는 원문 (방식을 바꿀 때 다시 레이아웃한다)
var _voice: Dictionary = VOICES["slow"]
var _elapsed := 0.0
var _total := 0.0                       # 마지막 글자가 찍히는 시각
var _typing := false
var _grow := 0.0                        # 상자 열림 0→1
var _time := 0.0
var _has_motion := false                # 이 줄에 [shake]/[wave] 가 하나라도 있나
var _noise: Array = []                  # 결정적인 떨림 표 (매 프레임 randf 를 부르지 않기 위해)
var _log: Array = []                    # 지나간 줄 [{text(평문), color}] — "누적 로그" 방식만 쓴다

var _choices: Array = []                # [{text, w}]
var _choice_index := 0
var _choices_shown := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	visible = false
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Segoe UI"])
	f.allow_system_fallback = true
	_font = f
	# 고정폭: **한글이 있는 것부터** 고른다. Consolas 를 앞에 두면 한글이 통째로 빈다 —
	# SystemFont 는 목록에서 먼저 설치된 한 벌을 고르지 글자마다 갈아타지 않는다.
	var m := SystemFont.new()
	m.font_names = PackedStringArray(["D2Coding", "NanumGothicCoding", "Noto Sans Mono CJK KR", "Malgun Gothic", "맑은 고딕"])
	m.allow_system_fallback = true
	_mono = m
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EED
	for i in 256:
		_noise.append(Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)))
	var env := OS.get_environment("DIALOGUE_STYLE")
	if env != "" and env.is_valid_int():
		style_index = wrapi(int(env), 0, STYLES.size())


# ── 표시 방식 ───────────────────────────────────────────────────────────────

static func style_of(i: int) -> Dictionary:
	return STYLES[wrapi(i, 0, STYLES.size())]


func style() -> Dictionary:
	return style_of(style_index)


## 방식을 바꾼다. 보고 있던 줄은 **처음부터 다시 찍는다** — 비교할 때는 타자 연출까지 봐야 하므로.
func set_style(i: int) -> void:
	style_index = wrapi(i, 0, STYLES.size())
	_log.clear()
	if open and _raw != "":
		# 선택지는 줄이 다시 다 찍힌 뒤 런타임이 다시 띄워 준다 (line_completed)
		_choices_shown = false
		_restart_line()
	queue_redraw()


func cycle_style(step := 1) -> void:
	set_style(style_index + step)


# ── 바깥에서 부르는 것들 ────────────────────────────────────────────────────

## 한 줄을 띄운다. anchor 는 말하는 사람 머리 꼭대기의 창 좌표.
func show_line(cast: Dictionary, text: String, anchor: Vector2) -> void:
	var keep := int(style().get("log", 0))
	if keep > 0 and _raw != "":
		_log.append({"text": _plain(_name, _raw), "color": _accent})
		while _log.size() > keep:
			_log.pop_front()
	_accent = cast.get("accent", Color(1, 1, 1))
	_name = str(cast.get("name", ""))
	_voice = VOICES.get(str(cast.get("voice", "slow")), VOICES["slow"])
	_anchor = anchor
	_raw = text
	_choices.clear()
	_choices_shown = false
	_choice_index = 0
	_restart_line()
	if not open:
		_grow = 0.0
		open = true
		visible = true
	queue_redraw()


## 말하는 사람이 움직이거나 카메라가 밀려 들어가는 동안 꼬리가 계속 머리를 가리키게 한다
func move_anchor(anchor: Vector2) -> void:
	if not open or _anchor.is_equal_approx(anchor):
		return
	_anchor = anchor
	if str(style()["place"]) == "head":       # 다른 방식은 화면에 고정이라 다시 잡을 게 없다
		_place_box()
		queue_redraw()


## 줄이 다 찍힌 뒤 선택지를 띄운다 (상자가 그만큼 커진다)
func show_choices(texts: Array) -> void:
	_choices.clear()
	for t in texts:
		_choices.append({"text": str(t), "w": _measure(str(t), CHOICE_FONT_SIZE)})
	_choice_index = 0
	_choices_shown = true
	_place_box()
	queue_redraw()


func close() -> void:
	if not open:
		return
	open = false
	_typing = false
	_raw = ""
	_log.clear()
	_choices.clear()
	_choices_shown = false
	var tw := create_tween()
	tw.tween_method(func(v: float): _grow = v; queue_redraw(), _grow, 0.0, CLOSE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): visible = false)


func is_typing() -> bool:
	return _typing


func has_choices() -> bool:
	return _choices_shown and not _choices.is_empty()


## 다 찍기 전에 확인 키를 누르면 남은 글자가 한꺼번에 앉는다
func skip_typing() -> void:
	if not _typing:
		return
	_elapsed = _total
	_typing = false
	line_completed.emit()
	queue_redraw()


# ── 입력 ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not open or _grow <= 0.0:
		return
	if has_choices():
		# 숫자 키 단축키는 **번호가 화면에 보이는 방식에서만** 산다. 안 보이는 방식에서까지 먹으면
		# 1~5 를 쓰는 바깥(대화 UI 랩의 방식 전환)과 말없이 충돌한다.
		var num := _number_key(event) if str(style()["choices"]) == "numbered" else -1
		if num >= 0 and num < _choices.size():
			_choice_index = num
			choice_picked.emit(num)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("dlg_prev"):
			_move_choice(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("dlg_next"):
			_move_choice(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("dlg_advance"):
			choice_picked.emit(_choice_index)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dlg_advance"):
		if _typing:
			skip_typing()
		else:
			advanced.emit()
		get_viewport().set_input_as_handled()


## 1~9 키 → 0-기준 번호. 해당 없으면 -1.
static func _number_key(event: InputEvent) -> int:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return -1
	if k.keycode >= KEY_1 and k.keycode <= KEY_9:
		return k.keycode - KEY_1
	if k.keycode >= KEY_KP_1 and k.keycode <= KEY_KP_9:
		return k.keycode - KEY_KP_1
	return -1


func _move_choice(step: int) -> void:
	_choice_index = wrapi(_choice_index + step, 0, _choices.size())
	queue_redraw()


# ── 타자 ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var dirty := false
	if _grow < 1.0 and open:
		_grow = minf(_grow + delta / OPEN_TIME, 1.0)
		dirty = true
	if _typing:
		_elapsed += delta
		if _elapsed >= _total:
			_elapsed = _total
			_typing = false
			line_completed.emit()
		dirty = true
	# 다 찍힌 뒤에는 움직일 것이 있을 때만 다시 그린다 —
	# 글자가 가만히 있는 줄에서 매 프레임 다시 그리는 것은 낭비이고, 미세한 떨림도 생기지 않게 한다
	if dirty or _has_motion:
		queue_redraw()


# ── 배치 ────────────────────────────────────────────────────────────────────

func _cur_font() -> Font:
	return _mono if bool(style().get("mono", false)) else _font


## 이 방식에서 쓸 수 있는 글 폭
func _wrap_width() -> float:
	var vp := get_viewport_rect().size
	return minf(float(style()["width"]), vp.x - (MARGIN + PAD.x) * 2.0)


## 이름을 대사 앞에 붙이는 방식(inline)이면 붙여서 같이 찍는다
func _display_text() -> String:
	if str(style()["name_mode"]) != "inline" or _name == "":
		return _raw
	return "[c=#%s]%s[/c]   %s" % [_accent.to_html(false), _name, _raw]


func _restart_line() -> void:
	_layout(_display_text())
	_elapsed = 0.0
	_typing = true


## 태그를 풀어 글자마다 위치·색·연출·찍히는 시각을 정한다
func _layout(raw: String) -> void:
	_glyphs.clear()
	_has_motion = false
	var font := _cur_font()
	var max_w := _wrap_width()
	var cps := float(_voice["cps"])
	var color := INK
	var fx := Fx.NONE
	var speed := 1.0
	var t := 0.0
	var x := 0.0
	var line := 0
	var line_start := 0                 # 이번 줄의 첫 글자 인덱스
	var last_break := -1                # 줄을 넘길 수 있는 자리 (이 인덱스부터 다음 줄로 내린다)
	var max_line_w := 0.0

	var i := 0
	while i < raw.length():
		var ch := raw[i]
		if ch == "[":
			var close_at := raw.find("]", i)
			if close_at > i:
				var tag := raw.substr(i + 1, close_at - i - 1)
				match tag:
					"shake":
						fx = Fx.SHAKE
						_has_motion = true
					"wave":
						fx = Fx.WAVE
						_has_motion = true
					"/shake", "/wave": fx = Fx.NONE
					"/c": color = INK
					"/s": speed = 1.0
					_:
						if tag.begins_with("c="):
							color = Color.html(tag.substr(2))
						elif tag.begins_with("p="):
							t += maxf(tag.substr(2).to_float(), 0.0)
						elif tag.begins_with("s="):
							speed = maxf(tag.substr(2).to_float(), 0.05)
				i = close_at + 1
				continue
		if ch == "\n":
			max_line_w = maxf(max_line_w, x)
			line += 1
			x = 0.0
			line_start = _glyphs.size()
			last_break = -1
			i += 1
			continue

		var w := font.get_char_size(ch.unicode_at(0), FONT_SIZE).x
		if x + w > max_w and _glyphs.size() > line_start:
			# 줄바꿈: 띄어쓰기/한글 경계로 되돌려 넘긴다 (자리가 없으면 지금 자리에서 자른다)
			var cut: int = last_break if last_break > line_start else _glyphs.size()
			max_line_w = maxf(max_line_w, float(_glyphs[cut]["pos"].x) if cut < _glyphs.size() else x)
			line += 1
			var nx := 0.0
			for j in range(cut, _glyphs.size()):
				var g: Dictionary = _glyphs[j]
				g["line"] = line
				g["pos"] = Vector2(nx, 0.0)
				nx += float(g["adv"])
			x = nx
			line_start = cut
			last_break = -1

		if ch != " " or _glyphs.size() > line_start:
			_glyphs.append({
				"ch": ch, "pos": Vector2(x, 0.0), "line": line, "adv": w,
				"color": color, "fx": fx, "t": t,
			})
			x += w
		# 다음 글자가 새 줄을 시작해도 되는 자리인가 — 띄어쓰기 뒤, 또는 한글·CJK 앞
		if ch == " " or _is_wrappable(ch):
			last_break = _glyphs.size()

		if ch != " ":
			t += 1.0 / (cps * speed)
			t += float(PUNCT_PAUSE.get(ch, 0.0))
		else:
			t += 0.5 / (cps * speed)
		i += 1

	max_line_w = maxf(max_line_w, x)
	var rows := maxi(line + 1, int(style().get("lines", 0)))
	_text_size = Vector2(max_line_w, rows * LINE_H)
	_total = t + POP_TIME
	_place_box()


## 한글·한자·가나는 글자마다 줄을 넘길 수 있다 (라틴 단어는 띄어쓰기에서만)
static func _is_wrappable(ch: String) -> bool:
	var c := ch.unicode_at(0)
	return (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x3040 and c <= 0x30FF) or (c >= 0x4E00 and c <= 0x9FFF)


## 태그를 떼어 낸 평문 (로그에 남길 때)
static func _plain(who: String, raw: String) -> String:
	var out := ""
	var i := 0
	while i < raw.length():
		if raw[i] == "[":
			var close_at := raw.find("]", i)
			if close_at > i:
				i = close_at + 1
				continue
		out += raw[i]
		i += 1
	return ("%s   %s" % [who, out]) if who != "" else out


func _measure(s: String, size: int) -> float:
	var font := _cur_font()
	var w := 0.0
	for i in s.length():
		w += font.get_char_size(s.unicode_at(i), size).x
	return w


func _place_box() -> void:
	var st := style()
	var vp := get_viewport_rect().size
	var inner := _text_size
	if bool(st.get("fixed", false)):
		inner.x = _wrap_width()
	if _choices_shown:
		var cw := 0.0
		for c in _choices:
			cw = maxf(cw, float(c["w"]) + 48.0)
		inner.x = maxf(inner.x, cw)
		inner.y += 12.0 + _choices.size() * CHOICE_H
	if str(st["name_mode"]) == "plate":            # 이름표가 글보다 넓으면 상자도 그만큼
		inner.x = maxf(inner.x, _measure(_name, NAME_FONT_SIZE) + 34.0)
	var size := inner + PAD * 2.0
	var pos := Vector2.ZERO
	match str(st["place"]):
		"bottom":
			pos = Vector2((vp.x - size.x) * 0.5, vp.y - BOTTOM_MARGIN - size.y)
		"side":
			pos = Vector2(vp.x - MARGIN - size.x, vp.y - BOTTOM_MARGIN - size.y)
		_:                                     # head
			pos = Vector2(_anchor.x - size.x * 0.5, _anchor.y - HEAD_GAP - TAIL_H - size.y)
			pos.x = clampf(pos.x, MARGIN, maxf(MARGIN, vp.x - MARGIN - size.x))
			pos.y = clampf(pos.y, MARGIN + 24.0, maxf(MARGIN, vp.y - MARGIN - size.y))
	_box = Rect2(pos.round(), size.round())


# ── 그리기 ──────────────────────────────────────────────────────────────────

## 모서리를 깎은 팔각형 — 둥근 모서리 대신 각진 사선으로 픽셀 UI 결을 맞춘다
static func _panel(r: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r.position.x + c, r.position.y), Vector2(r.end.x - c, r.position.y),
		Vector2(r.end.x, r.position.y + c), Vector2(r.end.x, r.end.y - c),
		Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y),
		Vector2(r.position.x, r.end.y - c), Vector2(r.position.x, r.position.y + c),
	])


## 꼬리 — 삼각형. 패널이 화면 가장자리에 밀려 꼬리 뿌리가 머리 바로 위에 못 올 때만
## 그만큼 끝이 머리 쪽으로 기운다 (평소에는 좌우 대칭).
static func _tail(tx: float, y: float, dir: float) -> PackedVector2Array:
	var lean := clampf(dir / 70.0, -1.0, 1.0)
	return PackedVector2Array([
		Vector2(tx - TAIL_W * 0.5, y),
		Vector2(tx + TAIL_W * 0.5, y),
		Vector2(tx + lean * TAIL_W * 0.55, y + TAIL_H),
	])


func _draw() -> void:
	if _grow <= 0.001:
		return
	var k := clampf(_grow, 0.0, 1.0)
	var open_k := k * k * (3.0 - 2.0 * k)
	var st := style()
	var panel_kind := str(st["panel"])
	# HUD 판만 아래에서 위로 펼쳐진다. 나머지는 살짝 떠오르며 밝아진다 (띠·자막에 펼침은 안 어울린다).
	var rise := (1.0 - open_k) * 10.0
	var b := _box
	if panel_kind == "hud":
		b.size.y = maxf(b.size.y * (0.34 + 0.66 * open_k), 6.0)
		b.position.y = _box.end.y - b.size.y
	else:
		b.position.y += rise

	_draw_panel(panel_kind, b, open_k, bool(st.get("tail", false)))

	if panel_kind == "hud" and open_k < 0.72:      # 판이 다 펼쳐지기 전에는 글자를 그리지 않는다
		return
	var fade := open_k if panel_kind != "hud" else (open_k - 0.72) / 0.28
	fade = clampf(fade, 0.0, 1.0)
	var org := _box.position
	if panel_kind != "hud":
		org.y += rise

	if int(st.get("log", 0)) > 0:
		_draw_log(org, fade)
	if str(st["name_mode"]) == "plate":
		_draw_name_plate(org, fade)

	var origin := org + PAD + Vector2(0.0, FONT_SIZE * 0.80)
	var shadowed := panel_kind == "none"
	for i in _glyphs.size():
		var g: Dictionary = _glyphs[i]
		var age := _elapsed - float(g["t"])
		if age < 0.0:
			continue
		var pos: Vector2 = origin + Vector2(g["pos"].x, float(g["line"]) * LINE_H)
		var alpha := fade
		if age < POP_TIME:
			# 찍히는 순간만 아래에서 짧게 올라온다. 흩어지지는 않는다 — 글줄이 출렁이면 읽기 힘들다.
			var p := age / POP_TIME
			pos.y += POP_RISE * (1.0 - p) * (1.0 - p)
			alpha *= minf(p * 2.4, 1.0)
		var fx := int(g["fx"])
		if fx != Fx.NONE:
			pos += _motion(i, fx)
		var col: Color = g["color"]
		if shadowed:
			_draw_text(str(g["ch"]), pos + Vector2(2.0, 2.0), FONT_SIZE, Color(TEXT_SHADOW.r, TEXT_SHADOW.g, TEXT_SHADOW.b, TEXT_SHADOW.a * alpha))
		_draw_text(str(g["ch"]), pos, FONT_SIZE, Color(col.r, col.g, col.b, col.a * alpha))

	if _choices_shown:
		_draw_choices(org, fade, str(st["choices"]), shadowed)


func _draw_panel(kind: String, b: Rect2, open_k: float, with_tail: bool) -> void:
	var edge := Color(_accent.r, _accent.g, _accent.b, 0.85 * open_k)
	match kind:
		"hud":
			var tail_x := clampf(_anchor.x, _box.position.x + 30.0, _box.end.x - 30.0)
			var tail := _tail(tail_x, b.end.y - 2.0, _anchor.x - tail_x)
			var panel := _panel(b, CHAMFER)
			draw_colored_polygon(_offset(panel, Vector2(5, 6)), SHADOW)
			if with_tail:
				draw_colored_polygon(_offset(tail, Vector2(5, 6)), SHADOW)
				draw_colored_polygon(tail, BG)
			draw_colored_polygon(panel, BG)
			# 위쪽 한 단을 밝게 — 평평한 검은 사각형이 아니라 조명을 받은 판으로 읽힌다
			var lip := Rect2(b.position + Vector2(CHAMFER, 0.0), Vector2(maxf(b.size.x - CHAMFER * 2.0, 1.0), minf(b.size.y * 0.22, 26.0)))
			draw_rect(lip, BG_TOP, true)
			draw_polyline(_closed(panel), EDGE_DARK, BORDER + 3.0)
			draw_polyline(_closed(panel), Color(_accent.r, _accent.g, _accent.b, 0.85), BORDER)
			if with_tail:
				draw_line(tail[0], tail[2], Color(_accent.r, _accent.g, _accent.b, 0.85), BORDER)
				draw_line(tail[2], tail[1], Color(_accent.r, _accent.g, _accent.b, 0.85), BORDER)
		"band":
			# 하단 전폭 띠 — 화면을 넓게 덮으므로 테두리는 위아래 가는 선 두 줄만
			var band := Rect2(b.position - Vector2(PAD.x * 0.5, 0.0), b.size + Vector2(PAD.x, 0.0))
			draw_rect(band, Color(BG_BAND.r, BG_BAND.g, BG_BAND.b, BG_BAND.a * open_k), true)
			draw_rect(Rect2(band.position, Vector2(band.size.x, 2.0)), edge, true)
			draw_rect(Rect2(Vector2(band.position.x, band.end.y - 2.0), Vector2(band.size.x, 2.0)), Color(edge.r, edge.g, edge.b, edge.a * 0.45), true)
		"retro":
			draw_rect(b, Color(BG_RETRO.r, BG_RETRO.g, BG_RETRO.b, BG_RETRO.a * open_k), true)
			draw_rect(b, Color(RETRO_EDGE.r, RETRO_EDGE.g, RETRO_EDGE.b, open_k), false, 5.0)
			draw_rect(b.grow(-9.0), Color(_accent.r, _accent.g, _accent.b, 0.35 * open_k), false, 2.0)
		"log":
			draw_rect(b, Color(BG_LOG.r, BG_LOG.g, BG_LOG.b, BG_LOG.a * open_k), true)
			draw_rect(Rect2(b.position, Vector2(5.0, b.size.y)), edge, true)
		_:
			pass                                   # none — 상자 없음, 글자 그림자로 읽힌다


## 지나간 줄을 상자 위에 흐리게 쌓는다 ("누적 로그" 방식)
func _draw_log(org: Vector2, fade: float) -> void:
	var y := org.y - 14.0
	var w := _box.size.x - PAD.x * 2.0
	for i in range(_log.size() - 1, -1, -1):
		var entry: Dictionary = _log[i]
		var rows := _wrap_plain(str(entry["text"]), w, CHOICE_FONT_SIZE)
		var dim := 0.75 - 0.16 * float(_log.size() - 1 - i)     # 오래된 줄일수록 더 흐리다
		y -= rows.size() * (LINE_H - 6.0)
		var ty := y
		for row in rows:
			_draw_text(row, Vector2(org.x + PAD.x, ty + CHOICE_FONT_SIZE * 0.8), CHOICE_FONT_SIZE,
				Color(INK_LOG.r, INK_LOG.g, INK_LOG.b, maxf(dim, 0.15) * fade))
			ty += LINE_H - 6.0
		y -= 8.0


## 평문을 폭에 맞춰 줄로 자른다 (로그 전용 — 타자 연출 없이 바로 그린다)
func _wrap_plain(s: String, max_w: float, size: int) -> PackedStringArray:
	var font := _cur_font()
	var out := PackedStringArray()
	var cur := ""
	var x := 0.0
	for i in s.length():
		var c := s[i]
		var w := font.get_char_size(c.unicode_at(0), size).x
		if x + w > max_w and cur != "":
			out.append(cur)
			cur = ""
			x = 0.0
		cur += c
		x += w
	if cur != "":
		out.append(cur)
	return out


## 이름표 — 상자 위쪽에 꽂힌 강조색 띠
func _draw_name_plate(org: Vector2, fade: float) -> void:
	if _name == "":
		return
	var nw := _measure(_name, NAME_FONT_SIZE) + 20.0
	var nr := Rect2(org + Vector2(CHAMFER + 2.0, -13.0), Vector2(nw, 24.0))
	draw_colored_polygon(_panel(nr, 5.0), Color(_accent.r, _accent.g, _accent.b, fade))
	_draw_text(_name, nr.position + Vector2(10.0, 17.0), NAME_FONT_SIZE, Color(0.05, 0.055, 0.07, fade))


func _draw_choices(org: Vector2, fade: float, kind: String, shadowed: bool) -> void:
	var left := org.x + PAD.x
	var top := org.y + PAD.y + _text_size.y + 12.0
	var w := _box.size.x - PAD.x * 2.0
	for i in _choices.size():
		var row := Rect2(Vector2(left - 8.0, top + i * CHOICE_H), Vector2(w + 16.0, CHOICE_H - 4.0))
		var picked := i == _choice_index
		if picked and not shadowed:
			draw_rect(row, Color(_accent.r, _accent.g, _accent.b, 0.13 * fade), true)
		var ink := INK if picked else INK_DIM
		var tx := row.position + Vector2(22.0, CHOICE_H * 0.5 + 4.0)
		if kind == "numbered":
			# 1. 2. 3. — 번호가 늘 보여서 숫자 키로 바로 고를 수 있다는 게 읽힌다
			var num := "%d." % (i + 1)
			_draw_text(num, Vector2(row.position.x + 6.0, tx.y), CHOICE_FONT_SIZE,
				Color(_accent.r, _accent.g, _accent.b, (1.0 if picked else 0.5) * fade))
			tx.x = row.position.x + 6.0 + _measure(num, CHOICE_FONT_SIZE) + 10.0
		elif picked:
			var nudge := 2.0 * sin(_time * 11.0)
			tx.x += nudge
			var c := row.position + Vector2(9.0 + nudge, CHOICE_H * 0.5 - 2.0)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-4.0, -6.0), c + Vector2(5.0, 0.0), c + Vector2(-4.0, 6.0),
			]), Color(_accent.r, _accent.g, _accent.b, fade))
		if picked and kind != "numbered" and not shadowed:
			draw_rect(Rect2(row.position, Vector2(4.0, row.size.y)), Color(_accent.r, _accent.g, _accent.b, fade), true)
		if shadowed:
			_draw_text(str(_choices[i]["text"]), tx + Vector2(2.0, 2.0), CHOICE_FONT_SIZE, Color(0, 0, 0, 0.85 * fade))
		_draw_text(str(_choices[i]["text"]), tx, CHOICE_FONT_SIZE, Color(ink.r, ink.g, ink.b, fade))


func _draw_text(s: String, pos: Vector2, size: int, color: Color) -> void:
	var font := _cur_font()
	var p := pos
	for i in s.length():
		var c := s.unicode_at(i)
		font.draw_char(get_canvas_item(), p, c, size, color)
		p.x += font.get_char_size(c, size).x


static func _offset(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array(pts)
	out.append(pts[0])
	return out


## 결정적인 난수 — 같은 (i, salt) 면 항상 같은 값. 매 프레임 randf 를 부르면 화면이 지글거린다.
func _rand(i: int, salt: int) -> Vector2:
	return _noise[(i * 31 + salt * 17) & 255]


## [shake] · [wave] 구간만 움직인다. 나머지 글자는 가만히 있는다.
func _motion(i: int, fx: int) -> Vector2:
	if fx == Fx.SHAKE:
		return _rand(i, int(_time * SHAKE_HZ)) * SHAKE_AMP
	return Vector2(0.0, sin(_time * 6.0 - float(i) * 0.55) * WAVE_AMP)
