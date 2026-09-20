extends SceneTree
## 걷기/달리기 · 사격 배타 규칙 검증 (헤드리스).
##   godot --headless --path . --script res://tools/validate_locomotion.gd
## 확인 항목:
##   1) Shift 없이 이동 → WALK 상태, WALK_SPEED 로 수렴
##   2) Shift + 이동 → RUN 상태, RUN_SPEED 로 수렴, run 클립 재생
##   3) 질주 중 사격 입력 → 발사가 잠깐 막히고 걷기로 감속한 뒤 발사 시작
##   4) 사격을 유지하면 Shift 를 눌러도 계속 걷기 (RUN_FIRE_LOCK)
##   5) 사격을 놓으면 RUN_FIRE_LOCK 뒤 다시 질주

const STEP := 1.0 / 60.0

var _player: Player
var _shots := 0
var _fails: Array[String] = []


var _ran := false


func _initialize() -> void:
	_setup_actions()
	_player = Player.new()
	_player.position = Vector2(2000, 600)
	root.add_child(_player)


## Player._ready 는 노드가 트리에 들어간 **다음** 프레임에 돈다 — 첫 프레임에 검사를 시작한다.
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run()
	return true


func _run() -> void:
	_player.set_process(false)        # 엔진 자동 틱을 끄고 고정 STEP 으로만 돌린다
	_player.set_bounds(0, 100000)
	_player.aim_target = _player.position + Vector2(600, -140)
	_player.shoot_fired.connect(func(_m, _t): _shots += 1)
	_settle()

	# 1) 걷기
	_hold(["move_right"], 1.0)
	_check("걷기 속도", absf(_player.velocity_x - Player.WALK_SPEED) < 1.0,
		"velocity_x=%.1f (기대 %.1f)" % [_player.velocity_x, Player.WALK_SPEED])
	_check("걷기 상태", _player.state == Player.State.WALK and _player.body.animation == "walk",
		"state=%d anim=%s" % [_player.state, _player.body.animation])

	# 2) 달리기
	_hold(["move_right", "run"], 1.0)
	_check("달리기 속도", absf(_player.velocity_x - Player.RUN_SPEED) < 1.0,
		"velocity_x=%.1f (기대 %.1f)" % [_player.velocity_x, Player.RUN_SPEED])
	_check("달리기 상태", _player.state == Player.State.RUN and _player.body.animation == "run",
		"state=%d anim=%s" % [_player.state, _player.body.animation])

	# 3) 질주 중 사격 → 첫 프레임엔 못 쏜다
	_shots = 0
	_hold(["move_right", "run", "shoot"], STEP)
	_check("질주 중 사격 불가", _shots == 0, "첫 프레임에 %d발 나감" % _shots)
	var brake := STEP
	while _shots == 0 and brake < 0.5:
		_hold(["move_right", "run", "shoot"], STEP)
		brake += STEP
	_check("감속 뒤 발사 시작", _shots > 0 and brake < 0.2, "%.3f초 만에 %d발" % [brake, _shots])

	# 4) 사격을 유지하는 동안은 Shift 를 눌러도 걷기
	_hold(["move_right", "run", "shoot"], 0.8)
	_check("사격 중 걷기 강제", _player.state == Player.State.WALK
			and absf(_player.velocity_x - Player.WALK_SPEED) < 1.0,
		"state=%d velocity_x=%.1f" % [_player.state, _player.velocity_x])

	# 5) 사격을 놓으면 잠금이 풀리고 다시 질주
	_hold(["move_right", "run"], 0.1)
	_check("놓은 직후엔 아직 걷기", _player.state == Player.State.WALK,
		"state=%d velocity_x=%.1f" % [_player.state, _player.velocity_x])
	_hold(["move_right", "run"], 0.9)
	_check("잠금 해제 후 재질주", _player.state == Player.State.RUN
			and absf(_player.velocity_x - Player.RUN_SPEED) < 1.0,
		"state=%d velocity_x=%.1f" % [_player.state, _player.velocity_x])

	if _fails.is_empty():
		print("\n[validate_locomotion] 통과 — 모든 항목 OK")
		quit(0)
	else:
		print("\n[validate_locomotion] 실패 %d건" % _fails.size())
		quit(1)


func _check(label: String, ok: bool, detail: String) -> void:
	print("  %s %s — %s" % ["[OK]  " if ok else "[FAIL]", label, detail])
	if not ok:
		_fails.append(label)


func _settle() -> void:
	for i in 3:
		_player._process(STEP)


func _hold(actions: Array, duration: float) -> void:
	for a in ["move_left", "move_right", "run", "shoot", "crouch"]:
		if a in actions:
			Input.action_press(a)
		else:
			Input.action_release(a)
	var t := 0.0
	while t < duration - 1e-6:
		_player._process(STEP)
		t += STEP


func _setup_actions() -> void:
	for spec in [["move_left", KEY_A], ["move_right", KEY_D], ["run", KEY_SHIFT],
			["crouch", KEY_CTRL], ["shoot", KEY_J], ["roll", KEY_SPACE],
			["reload", KEY_R], ["interact", KEY_W]]:
		if not InputMap.has_action(spec[0]):
			InputMap.add_action(spec[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = spec[1]
		InputMap.action_add_event(spec[0], ev)
