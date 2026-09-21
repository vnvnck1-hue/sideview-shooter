extends Node2D
## 사족보행 랩 (2026-09-21). 절차적 보행(ProcWalker)을 **손으로 움직여 보는** 그레이박스 실험실.
##
## 방·자산 없이 기복 있는 지면만 깔아 두고 로봇을 직접 끌고 다닌다. 평지·경사·턱·울퉁불퉁·낭떠러지를
## 한 줄에 몰아 놓은 이유는 하나다 — 절차적 보행이 값어치를 하는 자리가 전부 "지면이 평평하지 않을 때" 라서다.
## 평지에서만 보면 미리 그린 걷기 애니와 구분이 안 간다.
##
## 그림은 **원화를 자른 파츠 리그**(walker_rig.gd)가 기본이고, F4 로 그레이박스와 번갈아 본다.
## 조각은 assets/quadruped/ 에 있고 Tools/ImageProcessing/cut_quadruped_rig_parts.py 가 만든다
## (원화 quadruped_side_transparent_v1.png → 0.34 배). 리그 규격과 proc_walker.gd 의 몸통·다리
## 수치는 그 배율로 **같이** 맞춰져 있다 — 한쪽만 고치면 그림이 관절에서 어긋난다.
##
## 조작
##   마우스            **조준** — 몸통 위 기관총이 포인터를 기계식 선회 속도로 따라간다.
##                    포탑 한계(±75°) 밖을 겨누면 **몸이 돌아선다** — 좌우를 뒤집는 게 아니라
##                    0.26초 동안 실제로 돌아간다(yaw). 조준 각을 따라 몸통도 젖혀진다.
##   좌클릭 · J        **사격** (누르고 있으면 연사). 반동으로 몸이 밀리고 다리가 그걸 받아낸다
##   A D · ← →        걷기      Shift 달리기      Space 점프 (뜬 동안 다리를 접었다가 착지 자리로 뻗는다)
##                    (본편 플레이어와 같은 액션·키다 — main.gd _add_action 표와 맞춰 두었다)
##   우클릭 드래그     몸체를 직접 잡아끈다 — 위로 들면 다리가 펴지고, 한계를 넘으면 발이 따라 떨어진다
##   F4               그림 — **원화 파츠 리그**(기본) ↔ 그레이박스. 둘을 번갈아 보며 자리를 맞춘다
##   F3               **사선(3/4) 시점 켬/끔** — 컨셉 원화처럼 비스듬히 본다.
##                    그림만 바뀐다 (걸음 계산은 두 상태에서 완전히 같다)
##   G/H K/L -/= 9/0  시점 수치 — 깊이 x · 깊이 y · 원근(먼 쪽이 가늘어짐) · 팔다리 두께
##   F2               디버그 — 발(파랑=딛음/노랑=뜸) · 목표 자리(초록 눈금) · 무릎이 갈 수 있는 원 · 고관절~발 선
##   1 2 3 4 5        걸음새 프리셋 (서로 확연히 다르다)
##                    1 살금살금 · 2 정찰(발을 높이) · 3 순찰(표준 대각보) · 4 돌격(현재 디폴트)
##                    5 버티기(사격 자세) · 6 **거미** (한 발씩 사각사각 — 이 로봇의 지향점)
##   수치 조정 (윗줄 올림 / 아랫줄 내림 — WASD 는 조작에 쓰므로 비워 두었다)
##     Q/Z 최고 속도   E/C 다리 벌림   R/V 몸 높이   T/B 보폭   Y/N 발 드는 높이
##     U/M 스텝 시간   I/, 예측        O/. 접지 유지  P// 동시에 뜨는 발(1=거미·2=트롯)
##     [/] 몸 기울기   ;/' 조준 젖힘
##   F5               수치·자세 초기화          F9  현재 수치를 콘솔에 출력 (proc_walker.gd DEFAULTS 에 적는다)
##   F1               로비

const BASE_Y := 620.0

## 지면 폴리라인 (x, BASE_Y + y). x 는 오름차순. 턱은 x 를 2px 만 벌려 만든다.
const TERRAIN := [
	Vector2(-4000.0, 0.0), Vector2(200.0, 0.0),
	Vector2(900.0, -110.0), Vector2(1400.0, -110.0),          # 완만한 오르막 → 평지
	Vector2(1402.0, -250.0), Vector2(1850.0, -250.0),         # 한 단 올라선 턱
	Vector2(1852.0, -60.0), Vector2(2200.0, -60.0),           # 내려선 단
	Vector2(2450.0, 60.0), Vector2(2700.0, -30.0),            # 울퉁불퉁 구간
	Vector2(2950.0, 80.0), Vector2(3200.0, -10.0),
	Vector2(3600.0, 0.0), Vector2(4100.0, -330.0),            # 급한 오르막
	Vector2(4700.0, -330.0), Vector2(4702.0, -20.0),          # 뚝 떨어지는 낭떠러지
	Vector2(9000.0, -20.0),
]

const BG := Color(0.259, 0.247, 0.384)                        # 레퍼런스 배경색
const GROUND := Color(0.176, 0.169, 0.271)
const GROUND_EDGE := Color(0.62, 0.60, 0.78, 0.55)
const GRID := Color(1.0, 1.0, 1.0, 0.055)

## 걸음새 프리셋. 서로 **확연히 다르게** 잡았다 — 속도 70~430 · 몸 높이 112~195 ·
## 다리 벌림 1.02~1.55 · 발 드는 높이 40~220 · 한 발씩 ↔ 대각 두 발씩.
## 다섯 개 모두 "여유 예산" 을 지키도록 맞춰 두었다 (tools/validate_walker.gd -- preset=N 으로 하나씩 검증했다).
## lead(예측)는 전부 **주기의 절반**(= hold + step_time)으로 뒀다 — 발이 오가는 구간이 rest 에
## 가운데로 맞아 여유가 가장 크다. 절반이 아니면 구간이 한쪽으로 쏠려 그만큼 여유를 잃는다.
## 4 번이 현재 DEFAULTS 와 같다 (프리셋을 만져 본 뒤 4 를 누르면 디폴트로 돌아온다).
##
## 2026-09-22: 원화 파츠를 붙이면서 몸 높이(ride)·다리 벌림(stride)을 **일괄로 다시 재었다.**
## 정강이가 150 → 50 으로 짧아지고 유압판이 수직으로 내려오는 구조가 되면서 선 자세가 달라졌다
## (ride ×1.57 · stride ×0.695). 서로의 차이(살금살금은 낮게, 순찰은 높게)는 그대로 유지했다.
## 옛 값을 그냥 두면 유압판이 옆으로 누워 다리가 게처럼 벌어진다 — 원화와 전혀 다른 실루엣이다.
const PRESETS := {
	# 한 발씩 조용히 옮긴다. 몸이 거의 흔들리지 않고 발도 낮게 끈다 — 잠입·접근
	KEY_1: {"name": "살금살금 (한 발씩 · 낮게)", "speed": 90.0, "ride": 204.0, "stride": 0.83,
		"trigger": 20.0, "lift": 55.0, "step_time": 0.40, "hold": 0.34, "lead": 0.74,
		"tilt": 0.50, "bob": 6.0, "aim_lean": 0.0, "legs_up": 1.0},
	# 몸을 최대한 낮추고 발만 아주 높이 든다 (220px — 몸통보다 높다). 잔해·배관을 넘는 걸음.
	# 주기가 길어(0.94초) 한 발씩으로 돌리면 한 걸음에 만회할 거리가 다리 길이를 넘는다 — 대각 트롯으로 둔다
	KEY_2: {"name": "정찰 (발을 높이 드는 걸음)", "speed": 150.0, "ride": 176.0, "stride": 0.71,
		"trigger": 20.0, "lift": 220.0, "step_time": 0.52, "hold": 0.42, "lead": 0.94,
		"tilt": 0.0, "bob": 22.0, "aim_lean": 0.0, "legs_up": 2.0},
	# 표준 대각보. 몸을 세우고 경사를 따라 눕는다 — 평상시 순찰.
	# 일괄 환산값(283)은 험지에서 스트럿 한계를 넘겼다 — 유압이 다 늘어나도 발이 땅에 닿지 않는
	# 높이다. 몸을 경사에 눕히는 프리셋(tilt 0.60)이라 같은 높이에서도 다리가 더 멀리 뻗는다.
	# 236 으로 낮춰 통과시켰다 (선 자세 다리 196 = 도달 한계 350 의 0.56)
	KEY_3: {"name": "순찰 (표준 대각보)", "speed": 260.0, "ride": 236.0, "stride": 0.90,
		"trigger": 30.0, "lift": 95.0, "step_time": 0.26, "hold": 0.16, "lead": 0.42,
		"tilt": 0.60, "bob": 14.0, "aim_lean": 0.08, "legs_up": 2.0},
	# 대각 두 발이 완전히 붙어 뛴다. 접지 유지가 거의 없어 늘 몸이 떠 있는 느낌 — **현재 DEFAULTS 와 같다**
	KEY_4: {"name": "돌격 (빠른 대각 트롯 · 현재 디폴트)", "speed": 430.0, "ride": 212.0, "stride": 0.82,
		"trigger": 40.0, "lift": 80.0, "step_time": 0.15, "hold": 0.05, "lead": 0.20,
		"tilt": 0.0, "bob": 26.0, "aim_lean": 0.12, "legs_up": 2.0},
	# **거미.** 한 발씩만 띄운다 — 늘 세 발이 땅에 붙어 있다. 아주 짧고 잦게 딛는다(스텝 0.08초).
	# 한 발씩이면 한 주기가 두 배(4번 나눠 딛는다)라 같은 속도에서 발이 두 배 밀린다 —
	# 그래서 속도를 430 → 340 으로 낮췄다 (달리기 ×1.7 까지 예산 안에 들도록).
	# 몸은 낮게 깔고 거의 흔들지 않으며(진동 4) 발도 낮게 끈다 — 트롯처럼 통통 뛰지 않고 사각사각 기어간다.
	KEY_6: {"name": "거미 (한 발씩 사각사각)", "speed": 340.0, "ride": 188.0, "stride": 0.90,
		"trigger": 30.0, "lift": 45.0, "step_time": 0.08, "hold": 0.03, "lead": 0.22,
		"tilt": 0.20, "bob": 4.0, "aim_lean": 0.05, "legs_up": 1.0},
	# 다리를 넓게 벌리고 낮게 앉아 거의 움직이지 않는다. 몸 흔들림 최소 — 사격 발판
	KEY_5: {"name": "버티기 (사격 자세·넓게)", "speed": 70.0, "ride": 228.0, "stride": 1.08,
		"trigger": 20.0, "lift": 40.0, "step_time": 0.30, "hold": 0.55, "lead": 0.85,
		"tilt": 0.25, "bob": 3.0, "aim_lean": 0.0, "legs_up": 1.0},
}

## 키 → [튜닝 키, 한 번에 바뀌는 양, 최소, 최대, 표시 이름]
## **WASD·Shift·Space·J 는 조작에 쓰므로 비워 둔다.** 윗줄(QERTYUIOP)이 올리고, 아랫줄(ZCVBNM,./)이 내린다.
const TUNE_KEYS := {
	KEY_Q: ["speed", 10.0, 40.0, 700.0, "최고 속도"], KEY_Z: ["speed", -10.0, 40.0, 700.0, "최고 속도"],
	KEY_E: ["stride", 0.03, 0.4, 1.8, "다리 벌림"], KEY_C: ["stride", -0.03, 0.4, 1.8, "다리 벌림"],
	KEY_R: ["ride", 6.0, 90.0, 340.0, "몸 높이"], KEY_V: ["ride", -6.0, 90.0, 340.0, "몸 높이"],
	KEY_T: ["trigger", 5.0, 20.0, 220.0, "보폭"], KEY_B: ["trigger", -5.0, 20.0, 220.0, "보폭"],
	KEY_Y: ["lift", 5.0, 0.0, 240.0, "발 드는 높이"], KEY_N: ["lift", -5.0, 0.0, 240.0, "발 드는 높이"],
	KEY_U: ["step_time", 0.02, 0.06, 0.6, "스텝 시간"], KEY_M: ["step_time", -0.02, 0.06, 0.6, "스텝 시간"],
	KEY_I: ["lead", 0.02, 0.0, 1.2, "예측"], KEY_COMMA: ["lead", -0.02, 0.0, 1.2, "예측"],
	KEY_O: ["hold", 0.02, 0.0, 0.8, "접지 유지"], KEY_PERIOD: ["hold", -0.02, 0.0, 0.8, "접지 유지"],
	KEY_P: ["legs_up", 1.0, 1.0, 2.0, "동시에 뜨는 발"], KEY_SLASH: ["legs_up", -1.0, 1.0, 2.0, "동시에 뜨는 발"],
	KEY_BRACKETLEFT: ["tilt", -0.05, 0.0, 1.5, "몸 기울기"], KEY_BRACKETRIGHT: ["tilt", 0.05, 0.0, 1.5, "몸 기울기"],
	KEY_SEMICOLON: ["aim_lean", -0.02, 0.0, 0.5, "조준 젖힘"], KEY_APOSTROPHE: ["aim_lean", 0.02, 0.0, 0.5, "조준 젖힘"],
}

## 시점(사선) 조정 키. 걸음 수치(TUNE_KEYS)와 **따로** 둔다 — 시점은 그림에만 들어가고
## 걸음 계산·여유 예산에는 전혀 섞이지 않는다 (proc_walker.gd 의 "사선(3/4) 시점" 주석 참고).
const VIEW_KEYS := {
	KEY_G: ["dx", -6.0, -220.0, 220.0, "깊이 x"], KEY_H: ["dx", 6.0, -220.0, 220.0, "깊이 x"],
	KEY_K: ["dy", -4.0, -200.0, 60.0, "깊이 y"], KEY_L: ["dy", 4.0, -200.0, 60.0, "깊이 y"],
	KEY_MINUS: ["shrink", -0.02, 0.0, 0.6, "원근(가늘어짐)"],
	KEY_EQUAL: ["shrink", 0.02, 0.0, 0.6, "원근(가늘어짐)"],
	KEY_9: ["thick", -0.04, 0.0, 1.0, "팔다리 두께"], KEY_0: ["thick", 0.04, 0.0, 1.0, "팔다리 두께"],
}

var _walker: ProcWalker
var _cam: Camera2D
var _debug: Node2D
var _terrain: Node2D
var _info: Label
var _show_debug := true
var _drag_off = null
var _mouse_firing := false
var _msg := "2  기본 (대각보)"
var _msg_t := 2.5

var _rig: WalkerRig
var _use_rig := true              # F4. 기본은 파츠 리그 — 이게 본편에서 쓰는 그림이다
var _blast: MuzzleBlast
var _casing: GDScript = null      # shell_casing.gd (런타임 로드 — 위 _on_fired 주석 참고)
var _shake := 0.0                 # 카메라 흔들림 (사격 반동)
var _fx: Node2D
var _tracers: Array = []          # {a, b, t} — 예광. 총구에서 탄착점까지 한 줄로 긋고 사라진다
var _sparks: Array = []           # {p, t} — 탄착 불꽃
var _aim := Vector2.ZERO

## 자동 스크린샷용 — tools/walker_shot.gd 가 켜고 방향을 넣는다 (shadow_lab.gd 의 SWEEP 과 같은 자리).
## 켜져 있으면 키보드·마우스 대신 auto_dir 로 걷는다. 틱·카메라·HUD 는 평소 경로 그대로 돌기 때문에
## 스크린샷이 실제 플레이 화면과 같은 그림이 된다.
var auto_drive := false
var auto_dir := 0.0
## 자동 촬영에서 드래그 경로를 그대로 타 보려고 쓴다. Vector2 를 넣으면 그 자리로 끌려간다.
var auto_drag = null
## 자동 촬영에서 조준점을 넣는다 (Vector2). null 이면 조준하지 않는다.
var auto_aim = null


func _ready() -> void:
	_add_actions()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -100
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# ColorRect 는 기본이 MOUSE_FILTER_STOP 이라, 그냥 두면 이 배경이 클릭을 전부 삼켜
	# _unhandled_input 까지 오지 않는다 (좌클릭 사격이 먹지 않던 원인).
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)

	_terrain = Node2D.new()
	_terrain.draw.connect(_draw_terrain)
	add_child(_terrain)

	_walker = ProcWalker.new()
	_walker.ground_at = ground_at
	var ride0: float = _walker.tune["ride"]
	_walker.body_pos = Vector2(0.0, ground_at(0.0) - ride0)
	add_child(_walker)

	_walker.fired.connect(_on_fired)

	# 원화 파츠 리그. 워커의 자식이라 몸통 트랜스폼(위치·기울기)을 그대로 물려받는다 —
	# 리그 안의 좌표는 ProcWalker.project() 가 내놓는 "몸통 원점 기준" 값과 같은 계다
	_rig = WalkerRig.new()
	_rig.walker = _walker
	_walker.add_child(_rig)
	_apply_view_mode()

	_fx = Node2D.new()
	_fx.z_index = 40
	_fx.draw.connect(_draw_fx)
	add_child(_fx)

	# 총구 화염 — 센트리건과 같은 MuzzleBlast (화염·심·연기·불꽃·라이트).
	# 이 로봇은 센트리보다 굵은 단발이라 크기를 키우고 연사는 늦췄다 (ProcWalker.FIRE_COOLDOWN)
	_blast = MuzzleBlast.new()
	_blast.fx_parent = _fx
	_blast.setup(1.25, BASE_Y)
	_blast.z_index = 45
	add_child(_blast)
	if Engine.has_singleton("Audio") or get_node_or_null("/root/Audio") != null:
		_casing = load("res://scripts/shell_casing.gd") as GDScript

	_debug = Node2D.new()
	_debug.z_index = 50
	_debug.draw.connect(_draw_debug)
	add_child(_debug)

	_cam = Camera2D.new()
	_cam.zoom = Vector2(0.74, 0.74)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 6.0
	_cam.position = _walker.body_pos
	add_child(_cam)
	_cam.make_current()

	_build_hud()
	_terrain.queue_redraw()


## 조작은 **본편 플레이어와 같은 액션 이름·키**를 쓴다 (main.gd _add_action 과 같은 표).
## 랩에서 익힌 손이 게임에서 그대로 통해야 하고, 나중에 이 로봇을 플레이어가 조종하게 되면
## 여기 이름이 그대로 쓰인다.
const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"shoot": [KEY_J],
	"to_lobby": [KEY_F1],
}


func _add_actions() -> void:
	for name in ACTIONS.keys():
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		for k in ACTIONS[name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			if not InputMap.action_has_event(name, ev):
				InputMap.action_add_event(name, ev)


## 지면 높이 — 폴리라인을 선형 보간한다. 본편에서는 RoomSolid 의 열별 바닥선이 이 자리에 들어간다.
func ground_at(x: float) -> float:
	if x <= TERRAIN[0].x:
		return BASE_Y + TERRAIN[0].y
	for i in range(TERRAIN.size() - 1):
		var a: Vector2 = TERRAIN[i]
		var b: Vector2 = TERRAIN[i + 1]
		if x <= b.x:
			var t := (x - a.x) / maxf(b.x - a.x, 0.001)
			return BASE_Y + lerpf(a.y, b.y, clampf(t, 0.0, 1.0))
	return BASE_Y + TERRAIN[TERRAIN.size() - 1].y


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("to_lobby"):
		AppFlow.go_lobby(get_tree())
		return

	# 마우스가 곧 조준점 — 포탑이 기계식 선회로 늦게 따라간다.
	# 자동 촬영(auto_drive/auto_drag)에서는 실제 마우스가 없으므로 auto_aim 을 넣지 않는 한 조준하지 않는다
	# (안 그러면 화면 구석의 마우스 좌표를 겨누느라 로봇이 계속 돌아선다).
	if auto_aim != null:
		_aim = auto_aim
		_walker.aim_target = _aim
	elif not auto_drive and auto_drag == null:
		_aim = get_global_mouse_position()
		_walker.aim_target = _aim
	else:
		_walker.aim_target = null          # 자동 촬영 중에는 조준을 **비운다**.
		                                   # 비우지 않으면 첫 프레임에 읽힌 엉뚱한 마우스 좌표가 계속 남는다

	if auto_drag != null:
		_walker.drag_to = auto_drag
		_walker.input_dir = 0.0
	elif auto_drive:
		_walker.drag_to = null
		_walker.input_dir = auto_dir
		_walker.running = false
	elif _drag_off != null:
		_walker.drag_to = get_global_mouse_position() + (_drag_off as Vector2)
		_walker.input_dir = 0.0
	else:
		_walker.drag_to = null
		_walker.input_dir = Input.get_axis("move_left", "move_right")
		_walker.running = Input.is_action_pressed("run")
		# 사격은 좌클릭 또는 J (플레이어의 shoot 키와 같다)
		if Input.is_action_pressed("shoot"):
			_walker.firing = true
		elif not _mouse_firing:
			_walker.firing = false

	_walker.tick(delta)
	_tick_fx(delta)
	_shake = maxf(_shake - delta * 26.0, 0.0)
	var jolt := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	_cam.position = _walker.body_pos + Vector2(_walker.speed * 0.18, -40.0) + jolt
	if _msg_t > 0.0:
		_msg_t -= delta
	_fx.queue_redraw()
	_debug.queue_redraw()
	_update_info()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_mouse_firing = mb.pressed               # 누르고 있으면 연사
			_walker.firing = mb.pressed
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			# 몸체 끌기는 우클릭으로 옮겼다 — 좌클릭은 이제 사격이다
			_drag_off = _walker.body_pos - get_global_mouse_position() if mb.pressed else null
			return
		return

	if event.is_action_pressed("jump"):
		_walker.jump()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = (event as InputEventKey).physical_keycode


	if key == KEY_F2:
		_show_debug = not _show_debug
		_flash("디버그 %s" % ("켬" if _show_debug else "끔"))
		return
	if key == KEY_F4:
		_use_rig = not _use_rig
		_apply_view_mode()
		_flash("그림 %s" % ("원화 파츠 리그" if _use_rig else "그레이박스"))
		return
	if key == KEY_F3:
		# 사선(3/4) 시점 켬/끔 — 원화처럼 비스듬히 볼 것인가, 예전처럼 완전 측면으로 볼 것인가.
		# 그림만 바뀐다. 걸음은 두 상태에서 완전히 같다
		_walker.view["oblique"] = 0.0 if _walker.oblique() else 1.0
		_flash("사선 시점 %s" % ("켬" if _walker.oblique() else "끔 (완전 측면)"))
		return
	if key == KEY_F5:
		_walker.tune = ProcWalker.DEFAULTS.duplicate()
		_walker.view = ProcWalker.VIEW_DEFAULTS.duplicate()
		var ride: float = _walker.tune["ride"]
		_walker.body_pos = Vector2(_walker.body_pos.x, ground_at(_walker.body_pos.x) - ride)
		_walker.reset_stance()
		_flash("초기화")
		return
	if key == KEY_F9:
		print("[walker] ", _walker.tune_text())
		print("  DEFAULTS := ", _walker.tune)
		print("[walker] ", _walker.view_text())
		print("  VIEW_DEFAULTS := ", _walker.view)
		_flash("콘솔에 출력")
		return
	if PRESETS.has(key):
		var p: Dictionary = PRESETS[key]
		for k in p.keys():
			if k != "name":
				_walker.tune[k] = p[k]
		_flash("%s  %s" % [char(key), p["name"]])
		return
	if TUNE_KEYS.has(key):
		var t: Array = TUNE_KEYS[key]
		var name: String = t[0]
		var cur: float = _walker.tune[name]
		_walker.tune[name] = clampf(cur + (t[1] as float), t[2] as float, t[3] as float)
		_flash("%s  %.2f" % [t[4], _walker.tune[name]])
		return
	if VIEW_KEYS.has(key):
		var v: Array = VIEW_KEYS[key]
		var vname: String = v[0]
		var vcur: float = _walker.view[vname]
		_walker.view[vname] = clampf(vcur + (v[1] as float), v[2] as float, v[3] as float)
		if not _walker.oblique():
			_walker.view["oblique"] = 1.0          # 시점 수치를 만지면 사선을 켠 것으로 본다
		_flash("%s  %.2f" % [v[4], _walker.view[vname]])


## 그림을 리그와 그레이박스 중 하나로 — **둘을 동시에 그리지 않는다.**
## 겹쳐 그리면 어느 쪽이 틀렸는지 알 수 없다 (자리맞춤은 F4 로 번갈아 보며 맞춘다)
func _apply_view_mode() -> void:
	_walker.draw_greybox = not _use_rig
	if _rig != null:
		_rig.visible = _use_rig
	_walker.queue_redraw()


func _flash(text: String) -> void:
	_msg = text
	_msg_t = 1.6


# ── 사격 연출 ────────────────────────────────────────────────────────────────

const TRACER_LIFE := 0.075
const SPARK_LIFE := 0.22
const RANGE := 3200.0

## 포탑이 쐈다. 연출은 **센트리건과 같은 구성**이다 — MuzzleBlast(화염·심·연기·불꽃·라이트) +
## 탄피 + 예광 + 카메라 흔들림. 다른 점은 연사력뿐이다 (센트리 0.055초 → 이 로봇 0.16초).
## 탄도는 지면에 닿을 때까지 한 줄로 밀어 보고 탄착 불꽃을 남긴다.
## (본편에서는 이 자리에 Main 의 사격 경로 — Bullet · RoomSolid.clip_ray 가 들어간다)
func _on_fired(muzzle: Vector2, dir: Vector2) -> void:
	var hit := muzzle
	var travelled := 0.0
	while travelled < RANGE:
		hit += dir * 14.0
		travelled += 14.0
		if hit.y >= ground_at(hit.x):
			_sparks.append({"p": hit, "t": SPARK_LIFE})
			break
	_tracers.append({"a": muzzle, "b": hit, "t": TRACER_LIFE})

	# 총구 화염 — 총구에 옮겨 붙이고 포신 방향으로 돌린다 (로컬 +x 가 포신 방향인 노드다)
	if _blast != null:
		_blast.global_position = muzzle
		_blast.rotation = dir.angle()
		_blast.fire(randf_range(0.95, 1.2), dir)

	# 탄피 — 센트리건과 같은 두 배 크기. 포신 **옆**으로 튀어나온다.
	# **런타임에 불러온다.** shell_casing.gd 는 Audio 오토로드를 쓰는데, 검증·촬영 도구는
	# `--script` 로 도니 오토로드가 없다. 클래스 이름으로 쓰면 그 자리에서 랩 전체가 컴파일에 실패한다.
	if _casing != null:
		var sc: Node2D = _casing.new()
		var side := Vector2(-dir.y, dir.x) * 26.0
		sc.setup(muzzle - dir * 90.0 + side, 1 if dir.x < 0.0 else -1, ground_at(muzzle.x),
			SentryTurret.SHELL_SCALE)
		_fx.add_child(sc)

	_shake = minf(_shake + 3.2, 9.0)


func _tick_fx(delta: float) -> void:
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i]["t"] = (_tracers[i]["t"] as float) - delta
		if _tracers[i]["t"] <= 0.0:
			_tracers.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		_sparks[i]["t"] = (_sparks[i]["t"] as float) - delta
		if _sparks[i]["t"] <= 0.0:
			_sparks.remove_at(i)


func _draw_fx() -> void:
	for tr in _tracers:
		var k: float = (tr["t"] as float) / TRACER_LIFE
		_fx.draw_line(tr["a"], tr["b"], Color(1.0, 0.95, 0.72, 0.85 * k), 3.0 + 3.0 * k)
	for sp in _sparks:
		var k: float = (sp["t"] as float) / SPARK_LIFE
		var p: Vector2 = sp["p"]
		_fx.draw_circle(p, 6.0 + 26.0 * (1.0 - k), Color(1.0, 0.86, 0.55, 0.5 * k))
		_fx.draw_circle(p, 5.0 * k, Color(1.0, 0.98, 0.9, 0.9 * k))
	# 조준선 — 포신이 실제로 겨누는 방향(기계식 선회라 포인터보다 늦다)과 포인터를 같이 보여 준다
	var m: Vector2 = _walker.muzzle()
	_fx.draw_line(m, m + _walker.aim_dir() * 260.0, Color(1.0, 0.45, 0.4, 0.35), 2.0)
	var c := _aim
	for v in [Vector2(18, 0), Vector2(-18, 0), Vector2(0, 18), Vector2(0, -18)]:
		_fx.draw_line(c + v * 0.45, c + v, Color(1.0, 0.9, 0.85, 0.8), 2.0)


# ── 그리기 ───────────────────────────────────────────────────────────────────

func _draw_terrain() -> void:
	var pts := PackedVector2Array()
	for p in TERRAIN:
		pts.append(Vector2(p.x, BASE_Y + p.y))
	# 마디마다 사각형으로 채운다 — 산 모양은 오목해서 draw_colored_polygon 에 한 번에 넘기면 깨진다
	var bottom := BASE_Y + 900.0
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		_terrain.draw_colored_polygon(PackedVector2Array([
			a, b, Vector2(b.x, bottom), Vector2(a.x, bottom),
		]), GROUND)
	_terrain.draw_polyline(pts, GROUND_EDGE, 3.0)
	# 200px 눈금 — 움직임의 크기를 눈으로 재는 자
	var x := -1000.0
	while x < 5600.0:
		var gy := ground_at(x)
		_terrain.draw_line(Vector2(x, gy), Vector2(x, gy + 26.0), GRID, 2.0)
		x += 200.0


func _draw_debug() -> void:
	if not _show_debug:
		return
	_walker.debug_draw(_debug)


# ── HUD ─────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	_info = Label.new()
	_info.position = Vector2(24, 20)
	_info.add_theme_font_override("font", font)
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_info.add_theme_constant_override("outline_size", 4)
	layer.add_child(_info)

	var keys := Label.new()
	keys.position = Vector2(24, AppFlow.VIEW_SIZE.y - 72)
	keys.size = Vector2(AppFlow.VIEW_SIZE.x - 48, 64)
	keys.add_theme_font_override("font", font)
	keys.add_theme_font_size_override("font_size", 18)
	keys.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82))
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.text = "마우스 조준 · 좌클릭/J 사격 · A D 걷기 · Shift 달리기 · Space 점프 · 우클릭 드래그로 몸체 잡아끌기   ·   F2 디버그   F3 사선 시점   F4 리그/그레이박스   ·   1~6 걸음새   ·   Q/Z 속도  E/C 다리 벌림  R/V 몸 높이  T/B 보폭  Y/N 발 드는 높이  U/M 스텝 시간  I/, 예측  O/. 접지 유지  P// 동시에 뜨는 발(1=거미·2=트롯)  [/] 기울기  ;/' 조준 젖힘   ·   시점: G/H 깊이 x  K/L 깊이 y  -/= 원근  9/0 두께   ·   F5 초기화  F9 수치 출력  ·  F1 로비"
	layer.add_child(keys)


func _update_info() -> void:
	var air := _walker.air_count()
	var state := "공중" if _walker.airborne else ("끌림" if _drag_off != null else "접지")
	var b := _walker.reach_budget()
	var over: bool = b["worst"] > b["limit"]
	var lines := [
		"사족보행 랩 — 속도 %5.0f px/s   방향 %s   %s   뜬 발 %d/4" % [
			_walker.speed, "▶" if _walker.facing > 0 else "◀", state, air,
		],
		_walker.tune_text(),
		_walker.view_text(),
		"허벅지 스트럿 한계 %.0f / 걸음 끝에서 최대 %.0f (%s)   %s" % [
			b["limit"], b["worst"], b["who"],
			"OK" if not over else "◀ %.0fpx 넘쳤다 — 걸음이 '긴급 스텝' 으로 나며 허둥댄다" % (b["worst"] - b["limit"]),
		],
		"발이 밀리는 거리 %.0f (= 속도 × 2×(접지유지+스텝시간))   권장 예측 %.2f" % [b["sweep"], b["best_lead"]],
	]
	if _msg_t > 0.0:
		lines.append("▸ " + _msg)
	_info.text = "\n".join(lines)
