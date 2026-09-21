extends SceneTree
## 사족보행 랩 연속 촬영. **실제 키 입력을 흘려 넣어** 걷게 하고 연속 프레임을 저장한다.
## 한 장짜리 스크린샷으로는 걸음이 이어지는지 알 수 없어서, 걸음 주기를 눈으로 보려고 만든 것이다.
## auto_drive 가 아니라 Input.parse_input_event 로 → 사용자가 실제로 쓰는 입력 경로까지 같이 검증된다.
##
## 실행: godot --path . --script res://tools/walker_film.gd [-- drag]
##       drag 를 주면 키 대신 마우스로 몸체를 끌고 다니는 경로를 찍는다
## 저장: user://shots/film/f_NN.png

const OUT := "user://shots/film/"
const Lab := preload("res://scripts/walker_lab.gd")
const EVERY := 4          # 몇 프레임마다 한 장 (60fps 기준 4 = 15fps)
const COUNT := 30         # 장수
const WARMUP := 24        # 걷기 시작 후 버리는 프레임 (가속 구간)

var _lab: Node2D
var _walker: ProcWalker
var _frame := 0
var _shots := 0
var _pending := -1
var _drag := false
var _gun := false
var _click := false
var _jump := false
var _shots_fired := 0
var _land_log: Array[String] = []
var _log: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "drag":
			_drag = true
		elif a == "gun":
			_gun = true
		elif a == "click":
			_click = true
		elif a == "jump":
			_jump = true
	_lab = Lab.new()
	root.add_child(_lab)
	# _ready 전에 켜 둔다 — 첫 물리 프레임에 읽힌 엉뚱한 마우스 좌표를 조준점으로 삼아
	# 로봇이 반대로 돌아선 채 촬영되는 일을 막는다
	if not _drag:
		_lab.auto_drive = true   # _ready 전에
		_lab.auto_dir = 0.0


func _process(_delta: float) -> bool:
	_frame += 1
	if _walker == null:
		for c in _lab.get_children():
			if c is ProcWalker:
				_walker = c
		if _walker == null:
			return _frame > 10
		DirAccess.make_dir_recursive_absolute(OUT)
		_walker.fired.connect(func(_m, _d): _shots_fired += 1)
		_walker.body_pos.x = -2000.0      # 평지 구간에서 찍는다 (경사가 섞이면 걸음 주기가 안 보인다)
		_walker.reset_stance()
		if not _drag and not _gun and not _click and not _jump:
			_lab.auto_drive = false      # 실제 키 경로로 돌아온다 (엉뚱한 조준만 걸러냈다)
			_key(KEY_D, true)                # **플레이어와 같은 D 키**를 누른 채로 둔다 (액션 배선까지 검증)
		return false

	if _click:
		# **실제 좌클릭을 흘려 넣는다** — 배경 Control 이 클릭을 삼키면 여기서 0 발로 잡힌다
		_lab.auto_aim = _walker.body_pos + Vector2(700.0, -200.0)
		if _frame == 30:
			_mouse(true)
		if _frame == 150:
			_mouse(false)
	elif _jump:
		# 점프 → 착지. 착지 전후로 몸·발·지면 높이를 남긴다
		_lab.auto_aim = null
		if _frame == 40:
			_walker.jump()
		if _frame >= 38 and _land_log.size() < 60:
			var lowest := -1e9
			for leg in _walker._legs:
				lowest = maxf(lowest, (leg["foot"] as Vector2).y)
			var g: float = _lab.ground_at(_walker.body_pos.x)
			_land_log.append("    f%03d %s 몸y=%7.1f 지면=%7.1f 몸-지면=%6.1f 가장낮은발=%7.1f 발-지면=%6.1f" % [
				_frame, "공중" if _walker.airborne else "접지",
				_walker.body_pos.y, g, g - _walker.body_pos.y, lowest, lowest - g,
			])
	elif _gun:
		# 조준점을 크게 휘둘러 본다 — 포탑 한계를 넘겨 몸이 돌아서는 순간까지 포함한다
		var g := float(_frame) * 0.016
		_lab.auto_aim = _walker.body_pos + Vector2(cos(g * 1.1) * 900.0, -260.0 + sin(g * 1.7) * 420.0)
		_walker.firing = true
		_lab.auto_drive = true
		_lab.auto_dir = 0.0
	elif _drag:
		# 마우스로 잡아끄는 경로 — 랩의 드래그 분기를 그대로 탄다.
		# 손목을 휘두르듯 좌우로 왕복시키고 위아래로도 흔든다 (속도 폭주·지면 뚫기 확인)
		var t := float(_frame) * 0.016
		_lab.auto_drag = Vector2(
			-2000.0 + sin(t * 1.7) * 700.0,
			_lab.ground_at(-2000.0 + sin(t * 1.7) * 700.0) - 250.0 + sin(t * 2.9) * 160.0,
		)

	if _pending == _frame:
		_save()
		_pending = -1
		if _shots >= COUNT:
			_finish()
			return true

	if _frame >= WARMUP and _pending < 0 and _shots < COUNT:
		_pending = _frame + EVERY

	if _frame > 2000:
		_finish()
		return true
	return false


func _mouse(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(1120, 450)
	Input.parse_input_event(ev)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _save() -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + "f_%02d.png" % _shots)
	var aim_deg := rad_to_deg(_walker.aim_dir().angle())
	var air := ""
	for leg in _walker._legs:
		air += "^" if leg["stepping"] else "_"
	_log.append("  f%02d  x=%7.1f  y=%6.1f  v=%6.1f  rot=%+.3f  발=%s  포신=%+6.1f°  ▶%d" % [
		_shots, _walker.body_pos.x, _walker.body_pos.y, _walker.speed, _walker.rotation, air,
		aim_deg, _walker.facing,
	])
	_shots += 1


func _finish() -> void:
	if not _drag and not _gun and not _click and not _jump:
		_key(KEY_D, false)
	var b := _walker.reach_budget()
	print("  도달 한계 %.0f / 걸음 끝 최대 %.0f (%s)  %s" % [
		b["limit"], b["worst"], b["who"], "OK" if b["worst"] <= b["limit"] else "넘침",
	])
	var mode := "사격" if _gun else ("드래그" if _drag else "방향키")
	print("--- 연속 촬영 %d 장 (%s) ---" % [_shots, mode])
	for l in _log:
		print(l)
	if _click:
		print("  **좌클릭 주입 결과: %d 발 발사됨** (0 이면 클릭이 UI 에 먹히고 있다)" % _shots_fired)
	if _jump:
		print("  점프·착지 기록:")
		for l in _land_log:
			print(l)
	print("  저장: ", ProjectSettings.globalize_path(OUT))
	quit()
