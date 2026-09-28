extends SceneTree
## 공간감 테스트 씬 동선 검사 (창 모드 — 본편 루프가 렌더 뷰포트를 쓴다):
##   사다리 오르기 → 꼭대기에서 손 놓고 착지 · 턱 사이 점프 · S+W 내려서기 · 기어가는 구간 막힘/통과 ·
##   끊긴 캣워크 달려 뛰기 · 사격이 탄을 만든다. 하나라도 틀리면 종료 코드 1.
## 실행:  godot --path . --script res://tools/validate_depth_lab.gd

var lab
var _f := 0
var _step := 0
var _t := 0.0
var _fail := 0
var _steps: Array = []


func _initialize() -> void:
	change_scene_to_file("res://scenes/DepthLab.tscn")
	_steps = [
		# [이름, 시작 x, 시작 높이, 누를 행동들, 시간, 검사 함수]
		["사다리 A 오르기 → 턱 600 착지", 12470.0, 0.0, [["interact", 0.0, 0.1], ["interact", 0.2, 3.2], ["move_right", 3.3, 3.5]], 4.4,
			func(): return absf(lab.motion.g - 600.0) < 1.0 and not lab.player.is_airborne()],
		["턱 600 → 턱 760 점프", 13040.0, 600.0, [["move_right", 0.0, 0.9], ["interact", 0.05, 0.12]], 1.6,
			func(): return absf(lab.motion.g - 760.0) < 1.0],
		["S+W 로 갠트리(360) 아래로", 5900.0, 360.0, [["crouch", 0.0, 0.4], ["interact", 0.1, 0.16]], 1.6,
			func(): return lab.motion.g < 1.0],
		["서서는 기어가는 구간에 못 들어간다", 11420.0, 0.0, [["move_right", 0.0, 1.2]], 1.4,
			func(): return lab.player.position.x < 11520.0 - 20.0],
		["웅크리면 지나간다", 11420.0, 0.0, [["crouch", 0.0, 4.6], ["move_right", 0.3, 4.6]], 4.8,
			func(): return lab.player.position.x > 11904.0],
		["끊긴 캣워크 달려 뛰기 (2240)", 15420.0, 2240.0, [["run", 0.0, 1.4], ["move_right", 0.0, 1.4], ["interact", 0.3, 0.36]], 1.9,
			func(): return absf(lab.motion.g - 2240.0) < 1.0 and lab.player.position.x > 15900.0],
		["캣워크 끝 긴 사다리로 내려가기", 18380.0, 2240.0, [["crouch", 0.0, 9.5]], 9.8,
			func(): return lab.motion.total() < 2.0],
		["사격 — 탄이 생긴다", 3000.0, 144.0, [["shoot", 0.0, 0.4]], 0.45,
			func(): return lab.bullets.get_child_count() > 0],
	]


func _process(delta: float) -> bool:
	_f += 1
	if lab == null:
		lab = current_scene
		if lab == null or lab.get("motion") == null or lab.motion == null:
			lab = null
			return false
		_start()
		return false
	if _f < 20:
		return false
	var s: Array = _steps[_step]
	_t += delta
	for a in s[3]:
		var on: bool = _t >= float(a[1]) and _t < float(a[2])
		if on and not Input.is_action_pressed(a[0]):
			Input.action_press(a[0])
		elif not on and Input.is_action_pressed(a[0]):
			Input.action_release(a[0])
	if _t >= float(s[4]):
		for a in s[3]:
			Input.action_release(a[0])
		var ok: bool = s[5].call()
		print("%s  %s   (x %d · 발 높이 %d · %s)" % ["OK  " if ok else "FAIL", s[0], int(lab.player.position.x), int(lab.motion.total()),
			"사다리" if lab.player.is_climbing() else ("공중" if lab.player.is_airborne() else "지면")])
		if not ok:
			_fail += 1
		_step += 1
		if _step >= _steps.size():
			print("검사 %d 개 중 실패 %d" % [_steps.size(), _fail])
			quit(1 if _fail > 0 else 0)
			return true
		_start()
	return false


func _start() -> void:
	var s: Array = _steps[_step]
	_t = 0.0
	_f = 0
	lab.player.settle()
	lab.player.position.x = float(s[1])
	lab.player.velocity_x = 0.0
	lab.player.aim_target = lab.player.position + Vector2(600, -100)
	lab.motion.snap_to_ground(float(s[2]) + 1.0)
	lab.camera.snap()
	lab.current_room.disable_monsters()
