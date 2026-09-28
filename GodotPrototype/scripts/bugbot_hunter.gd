extends "res://scripts/walker_unit.gd"
## 임시 전투 연출용 AI. 보행/선회/탄착/과열은 실제 조종 기체와 공유한다.
const MAX_ARMOR := 100.0
const REPAIR_TIME := 7.0
const FIRE_RANGE := 1150.0
var director: Node
var slot := 0
var target: Node2D
var armor := MAX_ARMOR
var repair_left := 0.0
var velocity_x := 0.0
var _think := 0.0
var _burst_clock := 0.0
var _hit_lock := 0.0


func _process(delta: float) -> void:
	_think -= delta
	_hit_lock = maxf(0.0, _hit_lock - delta)
	_burst_clock += delta
	if repair_left > 0.0:
		repair_left = maxf(0.0, repair_left - delta)
		if repair_left == 0.0:
			armor = MAX_ARMOR
			state = State.WAKING
	elif _hit_lock == 0.0:
		armor = minf(MAX_ARMOR, armor + delta * 1.5)
	var old_x := position.x
	super(delta)
	velocity_x = (position.x - old_x) / maxf(delta, 0.0001)
	queue_redraw()


func available() -> bool:
	return repair_left <= 0.0 and armor > 0.0


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-90, -175), Vector2(180, 155))


func receive_monster_hit(point: Vector2, _direction: float, damage := 14.0) -> void:
	if not available() or _hit_lock > 0.0:
		return
	_hit_lock = 0.45
	armor = maxf(0.0, armor - damage)
	var sparks := SparkBurst.spawn(_room, floor_y)
	sparks.burst(point, 7, Vector2.UP, 1.0, Vector2(90, 270),
		Color(0.6, 0.9, 1.0), Color(0.9, 0.4, 0.1), Vector2(0.15, 0.4), 1500.0, 3.0, false)
	if armor <= 0.0:
		repair_left = REPAIR_TIME
		state = State.SLEEPING
		target = null


func _tick_input() -> void:
	_walker.input_dir = 0.0
	_walker.running = false
	_walker.firing = false
	_walker.aim_target = null
	if not available() or state != State.READY or not is_instance_valid(director):
		return
	var sec: Vector2 = _room.section_of(position.x)
	set_span(sec.x + 90.0, sec.y - 90.0)
	if _think <= 0.0 or not is_instance_valid(target) or target.is_dead():
		_think = 0.22 + slot * 0.035
		target = director.pick_target(self)
	var desired_x: float = director.anchor_x() + (slot - 1) * 210.0
	if is_instance_valid(target) and not target.is_dead():
		aim_target = target.hit_center()
		var dx := aim_target.x - position.x
		var stand_off := 470.0 + slot * 85.0
		desired_x = aim_target.x - (1.0 if dx >= 0.0 else -1.0) * stand_off
		var muzzle_pos := _scaler.global_transform * _walker.muzzle()
		var to_target := aim_target - muzzle_pos
		var barrel := _scaler.global_transform.basis_xform(_walker.aim_dir()).normalized()
		var clear: bool = _room.clip_shot(muzzle_pos, aim_target).distance_to(aim_target) < 8.0
		# 표적 획득과 선회가 끝난 다음에만 0.8초 점사 / 0.65초 휴지.
		_walker.firing = clear and to_target.length() < FIRE_RANGE and barrel.dot(to_target.normalized()) > 0.992 \
			and fmod(_burst_clock + slot * 0.47, 1.45) < 0.8 and not overheated
		_walker.aim_target = _scaler.global_transform.affine_inverse() * aim_target
		if not clear:
			desired_x = aim_target.x
	# 같은 표적을 쏘더라도 기체끼리 포개지지 않도록 옆으로 퍼진다.
	var separation := 0.0
	for ally in director.bots:
		if ally == self or not is_instance_valid(ally):
			continue
		var gap: float = position.x - ally.position.x
		if absf(gap) < 190.0:
			separation += (1.0 if gap > 0.0 else -1.0) * (190.0 - absf(gap))
	desired_x = clampf(desired_x + separation, _span.x, _span.y)
	if absf(desired_x - position.x) > 65.0:
		_walker.input_dir = signf(desired_x - position.x)
		_walker.running = absf(desired_x - position.x) > 750.0


func _draw() -> void:
	var ratio := armor / MAX_ARMOR if available() else 1.0 - repair_left / REPAIR_TIME
	draw_rect(Rect2(-54, -212, 108, 7), Color(0.07, 0.1, 0.13, 0.9))
	draw_rect(Rect2(-54, -212, 108 * ratio, 7), Color(0.25, 0.9, 0.85) if available() else Color(1.0, 0.65, 0.18))
