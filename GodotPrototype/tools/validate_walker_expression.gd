extends SceneTree
## 조준 / 보행 분리와 탄성 자세의 결정론적 회귀 검사.
## godot --headless --path GodotPrototype --script res://tools/validate_walker_expression.gd
## 시간 상수 자체 대신 발 고정, 탄도/그림 일치, 착지 회복과 본편 입력 경로를 검사한다.

const RATES := [30, 60, 120]
const ANGLES := [-PI, -PI * 0.75, -PI * 0.5, -PI * 0.25, 0.0, PI * 0.25, PI * 0.5, PI * 0.75]

var _fails: Array[String] = []
var _checks := 0
var _shots := 0
var _worst_aim := 0.0
var _largest_foot_drift := 0.0
var _largest_pivot_step := 0.0
var _largest_pivot_delta := 0.0
var _ingame_shots := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok and not _fails.has(label) and _fails.size() < 24:
		_fails.append(label)


func _run() -> void:
	seed(73021)
	for hz in RATES:
		var dt := 1.0 / float(hz)
		for side in [-1, 1]:
			_stationary_aim(dt, side)
			_moving_aim(dt, side)
		_reverse_while_aiming(dt)
		_angle_seams(dt)
		_jump_recovery(dt)
		print("  %d Hz: 정지 조준 / 양방향 이동 사격 / 회전 경계 / 점프 회복 검사 완료" % hz)
	_torso_pivot_continuity()
	_ingame_control()
	_check(_shots > 40, "이동 / 회전 중 실제 fired 시그널이 충분히 발생한다")
	_check(_ingame_shots > 8, "본편 WalkerUnit 입력 경로로 양방향 사격이 발생한다")
	print("=== 사족보행 표현 / 독립 조준 검사 ===")
	print("  검사 %d · ProcWalker 발사 %d · 본편 발사 %d" % [_checks, _shots, _ingame_shots])
	print("  추적 최대 오차 %.2f도 · 정지 조준 발 이동 최대 %.3fpx" % [rad_to_deg(_worst_aim), _largest_foot_drift])
	print("  120 Hz 상체 180도 선회: 포가 최대 이동 %.3fpx / 이동량의 프레임 변화 %.3fpx" % [_largest_pivot_step, _largest_pivot_delta])
	for failure in _fails:
		print("  실패: " + failure)
	print("  통과" if _fails.is_empty() else "  실패 %d건" % _fails.size())
	quit(0 if _fails.is_empty() else 1)


func _new_walker(side: int = 1) -> ProcWalker:
	var walker := ProcWalker.new()
	walker.draw_greybox = false
	walker.body_pos = Vector2(0.0, -float(walker.tune["ride"]))
	root.add_child(walker)
	walker.face(side)
	for i in range(120):
		walker.tick(1.0 / 60.0)
	walker.fired.connect(func(origin: Vector2, direction: Vector2): _shot_pose(walker, origin, direction))
	return walker


func _pose_valid(walker: ProcWalker, label: String) -> void:
	_check(walker.body_pos.is_finite() and is_finite(walker.rotation) and is_finite(walker.speed), label + ": 몸 자세가 유한하다")
	_check(absf(walker.rotation) < 0.65, label + ": 몸 기울기가 발산하지 않는다")
	_check(walker.aim_dir().is_finite() and walker.muzzle().is_finite(), label + ": 조준 / 총구가 유한하다")
	_check(absf(walker.aim_dir().length() - 1.0) < 0.001, label + ": 조준 방향이 단위 벡터다")
	var shape := walker.presentation_scale()
	_check(shape.is_finite() and shape.x > 0.65 and shape.x < 1.4 and shape.y > 0.65 and shape.y < 1.4,
		label + ": 스쿼시 / 스트레치가 유한하고 과도하지 않다")
	_check(is_finite(walker.motion_amount()) and walker.motion_amount() >= 0.0 and walker.motion_amount() < 2.0,
		label + ": 보행 블렌드가 유한한 범위에 있다")
	_check(walker.body_project(100.0, -100.0, 0.5).is_finite(), label + ": 독립 상체 투영이 유한하다")
	for leg in walker.legs():
		var foot: Vector2 = leg["foot"]
		var hip := walker.hip_world(leg)
		_check(foot.is_finite() and hip.is_finite(), label + ": 다리 좌표가 유한하다")
		_check(walker.strut_for(hip, foot, walker.phi0(leg)) <= ProcWalker.THIGH_MAX + 1.0,
			label + ": 다리가 도달 한계 안에 있다")
		if not walker.airborne and not leg["stepping"]:
			_check(absf(foot.y) <= 2.0, label + ": 지지 발이 지면을 딛는다")


func _aim_matches(walker: ProcWalker, label: String, tolerance: float = 0.065) -> void:
	var desired := ((walker.aim_target as Vector2) - walker.turret_pivot()).normalized()
	var error := absf(walker.aim_dir().angle_to(desired))
	_worst_aim = maxf(_worst_aim, error)
	_check(error < tolerance, label + ": 조준점과 실제 총구 방향이 일치한다")


func _shot_pose(walker: ProcWalker, origin: Vector2, direction: Vector2) -> void:
	_shots += 1
	# 시그널 수신자는 바로 예광 / 화염을 만든다. 발사 순간에 노드 변환도 이미 최신이어야 한다.
	var rendered_pivot := walker.transform * walker.turret_local(0.0)
	var rendered_tip := walker.transform * walker.turret_local(ProcWalker.BARREL_LEN)
	var rendered_direction := (rendered_tip - rendered_pivot).normalized()
	_check(origin.distance_to(walker.muzzle()) < 0.01, "fired: 시그널 출발점과 현재 총구가 같다")
	_check(rendered_pivot.distance_to(walker.turret_pivot()) < 0.01, "fired: 시그널 전에 그림의 몸 변환이 갱신된다")
	_check(direction.dot(rendered_direction) > 0.99999, "fired: 시그널 방향과 그려진 포신이 같다")
	_check(absf((origin - rendered_pivot).cross(direction)) < 0.05, "fired: 탄이 포신의 축 위에서 출발한다")
	_check((origin - rendered_pivot).dot(direction) > ProcWalker.BARREL_LEN * 0.5,
		"fired: 탄이 약실 / 몸통 안에서 출발하지 않는다")


func _stationary_aim(dt: float, side: int) -> void:
	var walker := _new_walker(side)
	var label := "정지 %dHz / 하체 %d" % [roundi(1.0 / dt), side]
	var yaw_start := walker.yaw
	var x_start := walker.body_pos.x
	var feet: Array[Vector2] = []
	for leg in walker.legs():
		feet.append(leg["foot"])
	for angle in ANGLES:
		walker.aim_target = walker.turret_pivot() + Vector2.RIGHT.rotated(angle) * 1800.0
		for i in range(ceili(0.85 / dt)):
			walker.tick(dt)
			_pose_valid(walker, label)
			_check(absf(walker.yaw - yaw_start) < 0.001, label + ": 조준만으로 하체가 돌아가지 않는다")
			_check(absf(walker.body_pos.x - x_start) < 0.1, label + ": 조준만으로 기체가 이동하지 않는다")
			for j in range(feet.size()):
				var drift := feet[j].distance_to(walker.legs()[j]["foot"])
				_largest_foot_drift = maxf(_largest_foot_drift, drift)
				_check(drift < 0.5, label + ": 상체 선회 중 네 발은 고정된다")
		_aim_matches(walker, label)
	walker.free()


func _moving_aim(dt: float, side: int) -> void:
	for angle in ANGLES:
		var walker := _new_walker(side)
		var label := "이동 %dHz / 이동 %d / 조준 %.0f도" % [roundi(1.0 / dt), side, rad_to_deg(angle)]
		walker.input_dir = float(side)
		walker.aim_target = walker.turret_pivot() + Vector2.RIGHT.rotated(angle) * 5000.0
		var x_start := walker.body_pos.x
		var yaw_start := walker.yaw
		var shape_motion := 0.0
		for i in range(ceili(1.8 / dt)):
			walker.firing = float(i) * dt > 0.8
			walker.tick(dt)
			_pose_valid(walker, label)
			shape_motion = maxf(shape_motion, walker.presentation_scale().distance_to(Vector2.ONE))
			_check(absf(walker.yaw - yaw_start) < 0.001, label + ": 사격이 진행 방향의 하체를 돌리지 않는다")
			if float(i) * dt > 0.8:
				_aim_matches(walker, label)
		_check((walker.body_pos.x - x_start) * side > 200.0, label + ": 목표가 어느 쪽이어도 입력 방향으로 이동한다")
		_check(walker.steps_normal > 2, label + ": 실제 걸음이 발생한다")
		_check(shape_motion > 0.002, label + ": 이동 / 사격 중 탄성 자세가 반응한다")
		walker.free()


func _reverse_while_aiming(dt: float) -> void:
	var walker := _new_walker()
	var label := "이동 반전 중 조준 %dHz" % roundi(1.0 / dt)
	walker.aim_target = walker.turret_pivot() + Vector2(4500.0, -1400.0)
	for i in range(ceili(0.8 / dt)):
		walker.tick(dt)
	walker.firing = true
	for side in [1, -1, 1]:
		var start_x := walker.body_pos.x
		walker.input_dir = float(side)
		for i in range(ceili(1.6 / dt)):
			var before := walker.aim_dir()
			walker.tick(dt)
			_pose_valid(walker, label)
			_aim_matches(walker, label)
			_check(before.dot(walker.aim_dir()) > 0.99, label + ": 하체 선회 중 포신이 갑자기 뒤집히지 않는다")
		_check((walker.body_pos.x - start_x) * side > 100.0, label + ": 조준을 유지하며 이동을 반전한다")
	walker.free()


func _torso_pivot_continuity() -> void:
	# 몸통 그림의 최소 폭을 기하 좌표에 적용하면 선회 중 +폭 -> -폭 경계에서
	# 포가가 약 76px 순간 이동한다. 탄도 방향 일치만 확인하면 놓치는 회귀다.
	const DT := 1.0 / 120.0
	for side in [-1, 1]:
		var walker := _new_walker(side)
		var label := "상체 선회 연속성 / 하체 %d" % side
		for direction in [Vector2(-2000.0, -1000.0), Vector2(2000.0, -1000.0),
				Vector2(-2000.0, 1000.0), Vector2(2000.0, 1000.0)]:
			walker.aim_target = walker.turret_pivot() + direction
			var previous_step := Vector2.ZERO
			for i in range(90):
				var previous_pivot := walker.turret_pivot()
				walker.tick(DT)
				var pivot_step := walker.turret_pivot() - previous_pivot
				var pivot_delta := pivot_step.distance_to(previous_step)
				_largest_pivot_step = maxf(_largest_pivot_step, pivot_step.length())
				_largest_pivot_delta = maxf(_largest_pivot_delta, pivot_delta)
				_check(pivot_step.length() < 16.0, label + ": 180도 선회 중 포가가 순간 이동하지 않는다")
				_check(pivot_delta < 4.0, label + ": 포가 이동 속도가 연속적으로 바뀐다")
				previous_step = pivot_step
				_pose_valid(walker, label)
			_check(cos(walker.torso_yaw) * signf(direction.x) > 0.99,
				label + ": 조준 쪽으로 상체 선회를 완료한다")
			_aim_matches(walker, label)
		walker.free()


func _angle_seams(dt: float) -> void:
	var walker := _new_walker()
	var label := "회전 경계 %dHz" % roundi(1.0 / dt)
	# ±PI 래핑과 수직 조준 좌우에서 포신이 한 바퀴 돌아가거나 180도 뒤집히지 않는다.
	for pair in [[PI - 0.012, -PI + 0.012], [-PI + 0.012, PI - 0.012],
			[-PI * 0.5 - 0.012, -PI * 0.5 + 0.012], [PI * 0.5 - 0.012, PI * 0.5 + 0.012]]:
		walker.aim_target = walker.turret_pivot() + Vector2.RIGHT.rotated(pair[0]) * 3000.0
		for i in range(ceili(0.9 / dt)):
			walker.tick(dt)
		var before := walker.aim_dir()
		walker.aim_target = walker.turret_pivot() + Vector2.RIGHT.rotated(pair[1]) * 3000.0
		walker.firing = true
		for i in range(ceili(0.5 / dt)):
			walker.tick(dt)
			_check(before.dot(walker.aim_dir()) > 0.97, label + ": 작은 경계 횡단에 포신이 뒤집히지 않는다")
			before = walker.aim_dir()
			_pose_valid(walker, label)
		_aim_matches(walker, label)
		walker.firing = false
	# 마우스가 회전축에 겹쳐 방향이 정의되지 않는 순간도 NaN을 만들면 안 된다.
	walker.aim_target = walker.turret_pivot()
	walker.tick(dt)
	_pose_valid(walker, label + " / 회전축 위 커서")
	walker.free()


func _jump_recovery(dt: float) -> void:
	var walker := _new_walker()
	var label := "점프 / 착지 %dHz" % roundi(1.0 / dt)
	var rest_y := walker.body_pos.y
	var top_y := rest_y
	var saw_air := false
	var landed := false
	var shape_motion := 0.0
	walker.jump()
	for i in range(ceili(4.0 / dt)):
		walker.tick(dt)
		_pose_valid(walker, label)
		top_y = minf(top_y, walker.body_pos.y)
		shape_motion = maxf(shape_motion, walker.presentation_scale().distance_to(Vector2.ONE))
		if walker.airborne:
			saw_air = true
		elif saw_air:
			landed = true
		_check(walker.body_pos.y < -ProcWalker.GROUND_CLEAR + 1.0, label + ": 착지 반동에도 몸이 바닥을 뚫지 않는다")
	_check(saw_air and landed and not walker.airborne, label + ": 뜬 뒤 다시 착지한다")
	_check(rest_y - top_y > 40.0, label + ": 실제 점프 높이가 난다")
	_check(shape_motion > 0.015, label + ": 점프 / 착지에서 스쿼시 / 스트레치가 반응한다")
	_check(absf(walker.body_pos.y - rest_y) < 8.0, label + ": 착지 뒤 기준 높이로 회복한다")
	_check(walker.presentation_scale().distance_to(Vector2.ONE) < 0.06, label + ": 착지 뒤 변형이 회복된다")
	_check(walker.air_count() == 0, label + ": 회복 뒤 네 발이 접지한다")
	walker.free()


func _ingame_control() -> void:
	# 본편의 SCALE / input -> WalkerUnit -> ProcWalker -> shoot_fired 변환까지 통과한다.
	for action in ["move_left", "move_right", "run", "shoot", "roll"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for side in [-1, 1]:
		var room := Node2D.new()
		root.add_child(room)
		var unit := WalkerUnit.new()
		unit.setup(1200.0, 600.0, room)
		room.add_child(unit)
		unit.set_process(false)
		unit._rig.set_process(false)
		unit.set_span(-10000.0, 10000.0)
		unit.activate()
		for i in range(100):
			unit._process(1.0 / 60.0)
		_check(unit.state == WalkerUnit.State.READY and unit.controlled, "본편: 기동하면 조종 상태로 들어온다")
		unit.shoot_fired.connect(func(origin: Vector2, target: Vector2): _ingame_shot(unit, origin, target))
		var start_x := unit.position.x
		var action := "move_right" if side > 0 else "move_left"
		Input.action_press(action)
		for pitch in [-0.55, 0.55]:
			# 진행 방향 반대쪽 위 / 아래를 겨누면서 이동한다.
			unit.aim_target = unit.global_position + Vector2(-float(side) * 1800.0, pitch * 1800.0)
			for i in range(105):
				if i == 55:
					Input.action_press("shoot")
				unit._process(1.0 / 60.0)
				unit._rig._process(0.0)
				var rendered_direction := unit._rig._barrel.global_transform.x.normalized()
				var shot_direction := unit._scaler.global_transform.basis_xform(unit._walker.aim_dir()).normalized()
				_check(rendered_direction.dot(shot_direction) > 0.999, "본편: 원화 포신과 사격 방향이 같다")
			Input.action_release("shoot")
		_check((unit.position.x - start_x) * side > 200.0, "본편: 반대쪽 사격 중에도 원하는 방향으로 이동한다")
		Input.action_release(action)
		unit.set_controlled(false)
		_check(not unit.controlled and not unit._walker.firing and unit._walker.aim_target == null,
			"본편: 하차하면 사격과 조준 입력을 해제한다")
		room.free()


func _ingame_shot(unit: WalkerUnit, origin: Vector2, target: Vector2) -> void:
	_ingame_shots += 1
	var expected := unit._scaler.global_transform * unit._walker.muzzle()
	# 프레임 렌더링 때 쓰는 리그 동기화를 실행한 뒤 실제 Sprite2D의 포신 끝을 재 본다.
	unit._rig._process(0.0)
	var drawn_muzzle := unit._rig._barrel.to_global(Vector2(ProcWalker.BARREL_LEN, 0.0))
	var desired := (unit.aim_target - origin).normalized()
	var shot := (target - origin).normalized()
	_check(origin.distance_to(expected) < 0.01, "본편: 발사 시그널의 총구가 실제 월드 총구와 같다")
	_check(origin.distance_to(drawn_muzzle) < 0.05, "본편: 반동 중 원화 포신 끝에서 실제 탄이 출발한다")
	_check(absf(shot.angle_to(desired)) < 0.08, "본편: 이동 중 반대쪽 조준점에 발사한다")
	_check(origin.is_finite() and target.is_finite(), "본편: 탄도 좌표가 유한하다")
