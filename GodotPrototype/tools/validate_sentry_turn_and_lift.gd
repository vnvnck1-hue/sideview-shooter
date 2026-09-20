extends SceneTree
## 실행: godot --headless --path GodotPrototype --script res://tools/validate_sentry_turn_and_lift.gd
## 실제 SentryTurret 노드로 좌우 선회와 하향 신축 받침대를 확인한다.

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		push_error("SENTRY VALIDATION: " + message)


func _run() -> void:
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
	var fx := Node2D.new()
	root.add_child(fx)
	var turret := SentryTurret.new()
	turret.setup(0.0, 0.0, fx)
	root.add_child(turret)
	var muzzle_world: Vector2 = (turret._muzzles[0].global_position + turret._muzzles[1].global_position) * 0.5
	turret.aim_target = muzzle_world + Vector2(800.0, 0.0)
	turret._set_ready()
	_check(turret._head_art == "sentry_head.png", "ready pose is not the original side view")

	# 왼쪽 수평 목표로 넘어갈 때 고도가 0°에서 크게 튀면 안 된다.
	turret.aim_target = muzzle_world + Vector2(-800.0, 0.0)
	var max_yaw_pitch := 0.0
	var max_yaw_lift := 0.0
	for i in range(60):
		turret._update_head(1.0 / 60.0)
		max_yaw_pitch = maxf(max_yaw_pitch, absf(turret._angle))
		max_yaw_lift = maxf(max_yaw_lift, turret._lift_height)
		if i == 14:
			_check(turret._head_art == "sentry_head_yaw_90.png", "front view missing at midpoint")
	_check(max_yaw_pitch < 0.02, "yaw turn changed pitch by %.3f rad" % max_yaw_pitch)
	_check(max_yaw_lift < 1.0, "riser extended during level yaw")
	_check(turret.facing == -1, "turret did not finish turning left")
	_check(turret._head_art == "sentry_head.png", "turn did not return to side view")

	# 깊은 하향 조준에서 머리와 받침대가 정확히 같은 높이만큼 상승한다.
	turret.aim_target = muzzle_world + Vector2(-300.0, 900.0)
	for i in range(180):
		turret._update_head(1.0 / 60.0)
	_check(absf(turret._angle - SentryTurret.ELEV_DOWN) < 0.02, "downward angle limit was not reached")
	_check(absf(turret._lift_height - SentryTurret.LIFT_HEIGHT) < 0.1, "riser did not fully extend")
	_check(turret._riser.visible, "extended riser is hidden")
	_check(turret._head_art == "sentry_head_elev_m40.png", "downward head pose missing")
	_check(turret._head_pivot.position.distance_to(turret._pivot + Vector2(0.0, -SentryTurret.LIFT_HEIGHT)) < 0.1,
		"raised head pivot does not match riser height")

	# 다시 상향 조준하면 접히고 상향 그림으로 돌아온다.
	turret.aim_target = muzzle_world + Vector2(-300.0, -900.0)
	for i in range(200):
		turret._update_head(1.0 / 60.0)
	_check(turret._lift_height < 0.1 and not turret._riser.visible, "riser did not retract")
	_check(turret._head_art == "sentry_head_elev_p60.png", "upward head pose missing")

	if _failed:
		print("SENTRY VALIDATION FAILED")
		quit(1)
	else:
		print("SENTRY VALIDATION PASSED: yaw, front view, down lift, retraction, elevation poses")
		quit(0)
