class_name ReferenceWalker
extends Node2D
## 원화 피벗을 기준으로 공간에서 푸는 거미형 사족 골격.
## pose_* 좌표는 이 노드의 부모 공간이다. 노드 자체는 body_pos만큼만 이동한다.

const Anatomy = preload("res://scripts/walker_anatomy.gd")
const SpiderIK = preload("res://scripts/spider_leg_ik.gd")
const WALK_SPEED := 140.0
const RUN_SPEED := 240.0
const ACCELERATION := 680.0
const GRAVITY := 1000.0
const JUMP_SPEED := 360.0
const REACH_EPS := 0.05
const AUTHORED_LENGTH_EPS := 0.025
const LEG_POINT_KEYS := ["mount", "hip", "knee", "ankle", "toe"]
const BODY_POINT_KEYS := {"chassis": "body.chassis", "pivot": "body.pivot", "upper_center": "body.upper",
	"gun": "body.gun", "barrel": "body.barrel", "muzzle": "body.muzzle"}

signal fired(muzzle: Vector2, direction: Vector2)

var ground_at: Callable = func(_x: float) -> float: return 640.0
var input_dir := 0.0
var running := false
var drag_to = null
var aim_target = null
var firing := false
var source_rest := false
## 원화/키프레임은 2D 기준 자세, 보행은 깊이가 있는 고정 길이 관절이다.
var spider_gait := true
var body_pos := Vector2.ZERO
var speed := 0.0
var airborne := false
var body_angle := 0.0
var motion := 0.0

var skeleton: Skeleton2D
var _chassis: Bone2D
var _upper_assembly: Bone2D
var _gun: Bone2D
var _barrel: Bone2D
var _leg_bones: Dictionary = {}
var _legs: Array = []
var _body_pose: Dictionary = {}
var _height := 160.0
var _vertical_velocity := 0.0
var _suspension_velocity := 0.0
var _pitch_velocity := 0.0
var _gun_angle := 0.0
var _time := 0.0
var _step_wait := 0.0
var _fire_wait := 0.0
var _initialized := false
var _was_source_rest := false
var _anatomy_points: Dictionary = {} # 원화 raw 좌표 override. 로컬 원점은 Anatomy.ORIGIN을 유지한다.
var _source_points: Dictionary = {}
var _next_pair := 0


func _init(points: Dictionary = {}) -> void:
	if _valid_anatomy(points):
		_anatomy_points = points.duplicate(true)


func _default_points() -> Dictionary:
	if not _source_points.is_empty():
		return _source_points
	var points := {"body.chassis": Anatomy.BODY_ROOT, "body.pivot": Anatomy.TORSO_PIVOT,
		"body.upper": Anatomy.UPPER_CENTER, "body.gun": Anatomy.GUN_PIVOT,
		"body.barrel": Anatomy.BARREL_ANCHOR, "body.muzzle": Anatomy.MUZZLE}
	for definition in Anatomy.LEGS:
		for key in LEG_POINT_KEYS:
			points[String(definition["id"]) + "." + key] = definition.get(key, definition["hip"])
	_source_points = points
	return _source_points


func _valid_anatomy(points: Dictionary) -> bool:
	var merged := _default_points().duplicate()
	for key in points:
		if not merged.has(key) or not points[key] is Vector2 or not (points[key] as Vector2).is_finite():
			return false
		merged[key] = points[key]
	var segments := [["body.chassis", "body.pivot"], ["body.pivot", "body.upper"],
		["body.gun", "body.barrel"], ["body.barrel", "body.muzzle"]]
	for definition in Anatomy.LEGS:
		var prefix := String(definition["id"]) + "."
		for i in range(4):
			segments.append([prefix + LEG_POINT_KEYS[i], prefix + LEG_POINT_KEYS[i + 1]])
	for segment in segments:
		# Bone2D's 0.1 local-unit minimum must not silently change a user bone's length.
		var length: float = (merged[segment[0]] as Vector2).distance_to(merged[segment[1]]) * Anatomy.SCALE
		if not is_finite(length) or length < 0.1:
			return false
	return true


func _point(key: String) -> Vector2:
	var defaults := _default_points()
	return Anatomy.local_point(_anatomy_points.get(key, defaults[key]))


func _ground_toe(definition: Dictionary) -> Vector2:
	var original_toe: Vector2 = definition["toe"]
	var edited_toe: Vector2 = _anatomy_points.get(String(definition["id"]) + ".toe", original_toe)
	# 직접 지정한 발을 과거의 가려진 FR 추정 접지점으로 또 밀어내지 않는다.
	if not edited_toe.is_equal_approx(original_toe):
		return edited_toe
	return (definition.get("ground_toe", original_toe) as Vector2) + edited_toe - original_toe


## Replace raw pivot overrides and rebuild the 20-bone hierarchy and its bind pose.
## Missing keys use the original artwork; {} restores the original pivots.
## Invalid data leaves the existing skeleton untouched. The actor/art origin stays fixed.
func apply_anatomy(points: Dictionary) -> bool:
	if not _valid_anatomy(points):
		return false
	_anatomy_points = points.duplicate(true)
	if is_instance_valid(skeleton):
		remove_child(skeleton)
		skeleton.free()
	skeleton = null
	_leg_bones.clear()
	_legs.clear()
	_body_pose.clear()
	_initialized = false
	body_angle = 0.0
	_initialize()
	reset_pose(false)
	return true


## Apply a complete FK pose once. The caller owns playback/edit mode and skips tick().
## All points use this node's parent space, matching pose_legs()/pose_body().
## This does not solve IK, move contact targets to terrain, or replace the edited bind.
func apply_authored_pose(pose: Dictionary) -> bool:
	if not pose.get("legs") is Array or not pose.get("body") is Dictionary:
		return false
	var authored_legs: Array = pose["legs"]
	var authored_body: Dictionary = pose["body"]
	if authored_legs.size() != Anatomy.LEGS.size():
		return false
	for key in BODY_POINT_KEYS:
		if not authored_body.get(key) is Vector2 or not (authored_body[key] as Vector2).is_finite():
			return false
	for key in ["body_angle", "torso_angle", "gun_angle"]:
		var value = authored_body.get(key)
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return false
		if not is_finite(float(value)):
			return false
	var by_id: Dictionary = {}
	for entry in authored_legs:
		if not entry is Dictionary:
			return false
		var id: String = str(entry.get("id", ""))
		if by_id.has(id) or not _default_points().has(id + ".mount"):
			return false
		for key in LEG_POINT_KEYS:
			if not entry.get(key) is Vector2 or not (entry[key] as Vector2).is_finite():
				return false
		for i in range(4):
			var start: String = LEG_POINT_KEYS[i]
			var end: String = LEG_POINT_KEYS[i + 1]
			var length: float = (entry[start] as Vector2).distance_to(entry[end])
			if absf(length - _point(id + "." + start).distance_to(_point(id + "." + end))) > AUTHORED_LENGTH_EPS:
				return false
		by_id[id] = entry
	for segment in [["chassis", "pivot"], ["pivot", "upper_center"], ["gun", "barrel"], ["barrel", "muzzle"]]:
		var length: float = (authored_body[segment[0]] as Vector2).distance_to(authored_body[segment[1]])
		var expected := _point(BODY_POINT_KEYS[segment[0]]).distance_to(_point(BODY_POINT_KEYS[segment[1]]))
		if absf(length - expected) > AUTHORED_LENGTH_EPS:
			return false
	_initialize()
	for leg in _legs:
		var entry: Dictionary = by_id[leg["id"]]
		for key in LEG_POINT_KEYS:
			leg[key] = entry[key]
		leg["contact"] = leg["toe"]
		leg["from"] = leg["toe"]
		leg["target"] = leg["toe"]
		leg["progress"] = 1.0
		leg["stepping"] = false
		leg["planted"] = false
	_body_pose = authored_body.duplicate(true)
	body_angle = float(authored_body["body_angle"])
	# The actual barrel endpoints remain the authoritative direction for Bone2D and firing.
	_gun_angle = ((_body_pose["muzzle"] as Vector2) - (_body_pose["barrel"] as Vector2)).angle()
	_body_pose["gun_angle"] = _gun_angle
	_update_bones()
	return true


func _ready() -> void:
	_initialize()
	reset_pose()


func _initialize() -> void:
	if _initialized:
		return
	_initialized = true
	skeleton = Skeleton2D.new()
	skeleton.name = "ReferenceSkeleton"
	add_child(skeleton)
	_chassis = _bone("Chassis", skeleton, _point("body.chassis").distance_to(_point("body.pivot")))
	_upper_assembly = _bone("UpperAssembly", _chassis, _point("body.pivot").distance_to(_point("body.upper")))
	_gun = _bone("GunPivot", _upper_assembly, _point("body.gun").distance_to(_point("body.barrel")))
	_barrel = _bone("Barrel", _gun, _point("body.barrel").distance_to(_point("body.muzzle")))
	var max_toe := -INF
	for definition in Anatomy.LEGS:
		max_toe = maxf(max_toe, _ground_toe(definition).y)
	_height = (max_toe - Anatomy.ORIGIN.y) * Anatomy.SCALE
	for definition in Anatomy.LEGS:
		var leg_id := String(definition["id"])
		var hip := _point(leg_id + ".hip")
		var knee := _point(leg_id + ".knee")
		var ankle := _point(leg_id + ".ankle")
		var toe := _point(leg_id + ".toe")
		var mount := _point(leg_id + ".mount")
		var ground_toe: Vector2 = Anatomy.local_point(_ground_toe(definition))
		var is_rear := leg_id.to_lower().ends_with("r") or leg_id.to_lower().contains("rear")
		var bend := signf((knee - hip).cross(ankle - knee))
		if is_zero_approx(bend):
			bend = float(definition.get("pole", 1.0))
		var leg := {
			"id": String(definition["id"]), "label": String(definition["label"]),
			"far": bool(definition["far"]), "inferred": bool(definition.get("inferred", false)),
			"uncertain": definition.get("uncertain", []),
			"ref_mount": mount, "ref_hip": hip, "ref_knee": knee, "ref_ankle": ankle, "ref_toe": toe,
			"rest_toe": ground_toe, "mount_length": mount.distance_to(hip),
			"gait_group": int(definition.get("group", int(bool(definition["far"]) != is_rear))),
			"upper_length": hip.distance_to(knee), "lower_length": knee.distance_to(ankle),
			"foot_length": ankle.distance_to(toe), "foot_angle": (toe - ankle).angle(), "bend": bend,
			"depth": ground_toe.y - _height,
			"mount": mount, "hip": hip, "knee": knee, "ankle": ankle, "toe": toe,
			"contact": toe, "from": toe, "target": toe, "progress": 1.0,
			"duration": 0.22, "lift": 25.0, "stepping": false, "planted": true,
		}
		_legs.append(leg)
		var mount_bone := _bone(String(definition["id"]) + "_Mount", _chassis, leg["mount_length"])
		var upper := _bone("Upper", mount_bone, leg["upper_length"])
		var lower := _bone("Lower", upper, leg["lower_length"])
		var foot := _bone("Foot", lower, leg["foot_length"])
		_leg_bones[leg["id"]] = [mount_bone, upper, lower, foot]
	# 접혀 있던 가려진 다리도 길이를 늘이지 않고 설 수 있도록 공통 몸 높이를 제한한다.
	for leg in _legs:
		if spider_gait:
			continue
		var foot_vector: Vector2 = (leg["ref_toe"] as Vector2) - (leg["ref_ankle"] as Vector2)
		var ankle: Vector2 = (leg["rest_toe"] as Vector2) - foot_vector
		var hip: Vector2 = leg["ref_hip"]
		var reach: float = (float(leg["upper_length"]) + float(leg["lower_length"])) * 0.96
		var horizontal := minf(absf(ankle.x - hip.x) + 25.0, reach * 0.95)
		var vertical := sqrt(maxf(reach * reach - horizontal * horizontal, 0.0))
		_height = minf(_height, hip.y - float(leg["depth"]) + foot_vector.y + vertical)
	if spider_gait:
		var front_depth := 0.0
		for leg in _legs:
			leg["spatial"] = SpiderIK.build(leg, _height)
			leg["rest_toe"] = leg["spatial"]["stance"]
			leg["depth"] = leg["spatial"]["depth"]
			front_depth = maxf(front_depth, float(leg["depth"]))
		# 화면의 바닥선은 가까운 발의 접지선이다. 먼 발만 그보다 위로 투영한다.
		_height += front_depth
		for leg in _legs:
			leg["depth"] = float(leg["depth"]) - front_depth
	_gun_angle = (_point("body.muzzle") - _point("body.barrel")).angle()
	# bind/rest는 원화에서 한 번만 저장한다. runtime reset은 이 원본 바인드를 바꾸지 않는다.
	var was_reference := source_rest
	source_rest = true
	_restore_reference()
	_update_body_pose(0.0)
	_update_bones()
	for bone in skeleton.get_children():
		_capture_rest(bone)
	source_rest = was_reference


func _bone(bone_name: String, parent: Node, length: float) -> Bone2D:
	var bone := Bone2D.new()
	bone.name = bone_name
	bone.set_autocalculate_length_and_angle(false)
	bone.length = maxf(length, 0.1)
	bone.bone_angle = 0.0
	parent.add_child(bone)
	return bone


func reset_pose(reposition_body := true) -> void:
	_initialize()
	speed = 0.0
	motion = 0.0
	airborne = false
	body_angle = 0.0
	_vertical_velocity = 0.0
	_suspension_velocity = 0.0
	_pitch_velocity = 0.0
	_step_wait = 0.08
	_next_pair = 0
	_fire_wait = 0.0
	if not source_rest and reposition_body:
		body_pos.y = float(ground_at.call(body_pos.x)) - _height
	for leg in _legs:
		var toe: Vector2 = body_pos + (leg["rest_toe"] as Vector2)
		if not source_rest:
			toe.y = float(ground_at.call(toe.x)) + float(leg["depth"])
		leg["contact"] = toe
		leg["from"] = toe
		leg["target"] = toe
		leg["stepping"] = false
		leg["progress"] = 1.0
		leg["planted"] = true
	_gun_angle = (_point("body.muzzle") - _point("body.barrel")).angle()
	_was_source_rest = source_rest
	if source_rest:
		_restore_reference()
	else:
		_solve_pose()
	_update_body_pose(0.0)
	_update_bones()


func _capture_rest(node: Node) -> void:
	if node is Bone2D:
		(node as Bone2D).rest = (node as Bone2D).transform
	for child in node.get_children():
		_capture_rest(child)


func jump() -> void:
	if source_rest or airborne:
		return
	airborne = true
	_vertical_velocity = -JUMP_SPEED
	for leg in _legs:
		leg["stepping"] = false
		leg["planted"] = false


func tick(delta: float) -> void:
	_initialize()
	if delta <= 0.0:
		return
	_time += delta
	if source_rest:
		speed = 0.0
		motion = 0.0
		airborne = false
		body_angle = 0.0
		_restore_reference()
		_update_body_pose(0.0)
		_update_bones()
		_was_source_rest = true
		return
	if _was_source_rest:
		reset_pose()
	var previous_body := body_pos
	var previous_pitch := body_angle
	var previous_speed := speed
	if drag_to != null:
		var previous_x := body_pos.x
		body_pos = body_pos.lerp(drag_to as Vector2, 1.0 - exp(-delta * 15.0))
		speed = clampf((body_pos.x - previous_x) / delta, -RUN_SPEED, RUN_SPEED)
		airborne = false
		_vertical_velocity = 0.0
	else:
		var target_speed := clampf(input_dir, -1.0, 1.0) * (RUN_SPEED if running else WALK_SPEED)
		speed = move_toward(speed, target_speed, ACCELERATION * delta)
		body_pos.x += speed * delta
	motion = lerpf(motion, clampf(absf(speed) / RUN_SPEED, 0.0, 1.0), 1.0 - exp(-delta * 9.0))
	var terrain_height: float = ground_at.call(body_pos.x)
	if not airborne and drag_to == null and terrain_height - body_pos.y > _height + 55.0:
		airborne = true
		_vertical_velocity = 0.0
	if airborne:
		_vertical_velocity += GRAVITY * delta
		body_pos.y += _vertical_velocity * delta
		if _vertical_velocity >= 0.0 and body_pos.y >= terrain_height - _height:
			body_pos.y = terrain_height - _height
			_suspension_velocity = minf(_vertical_velocity * 0.14, 70.0)
			_vertical_velocity = 0.0
			airborne = false
			for leg in _legs:
				leg["contact"] = _rest_contact(leg, speed * 0.07)
				leg["stepping"] = false
			_step_wait = 0.08
	if not airborne and drag_to == null:
		var support := 0.0
		var support_count := 0
		for leg in _legs:
			if not leg["stepping"] and bool(leg["planted"]):
				support += (leg["contact"] as Vector2).y - float(leg["depth"])
				support_count += 1
		var ground_level := support / float(support_count) if support_count > 0 else terrain_height
		var height_target := ground_level - _height + sin(_time * 1.7) * 0.45 * (1.0 - motion)
		var suspension := _spring(body_pos.y, _suspension_velocity, height_target, 19.0, delta)
		body_pos.y = suspension.x
		_suspension_velocity = suspension.y
	var acceleration := clampf((speed - previous_speed) / (delta * ACCELERATION), -1.0, 1.0)
	var pitch := _spring(body_angle, _pitch_velocity, -acceleration * 0.019 + speed / RUN_SPEED * 0.015, 16.0, delta)
	body_angle = pitch.x
	_pitch_velocity = pitch.y
	_tick_contacts(delta)
	if not airborne:
		_limit_body_to_support(previous_body, previous_pitch, delta)
	_solve_pose()
	_update_body_pose(delta)
	_update_bones()
	_fire_wait = maxf(_fire_wait - delta, 0.0)
	if firing and _fire_wait <= 0.0:
		_fire_wait = 0.19
		fired.emit(_body_pose["muzzle"], Vector2.RIGHT.rotated(_gun_angle))


func _restore_reference() -> void:
	for leg in _legs:
		for key in ["mount", "hip", "knee", "ankle", "toe"]:
			leg[key] = body_pos + (leg["ref_" + key] as Vector2)
		leg["contact"] = leg["toe"]
		leg["stepping"] = false
		leg["planted"] = true
		leg["progress"] = 1.0


func _rest_contact(leg: Dictionary, lead: float = 0.0) -> Vector2:
	var x: float = body_pos.x + (leg["rest_toe"] as Vector2).x + lead
	return Vector2(x, float(ground_at.call(x)) + float(leg["depth"]))


func _reachable_contact(leg: Dictionary, wanted: Vector2, prediction: float) -> Vector2:
	if spider_gait:
		var predicted := body_pos + Vector2(prediction, 0)
		var target := wanted
		target.y = float(ground_at.call(target.x)) + float(leg["depth"])
		if bool(SpiderIK.solve(leg["spatial"], predicted, body_angle, target)["reachable"]):
			return target
		var base := Vector2(predicted.x + (leg["rest_toe"] as Vector2).x, target.y)
		base.y = float(ground_at.call(base.x)) + float(leg["depth"])
		var allowed := 0.0
		var blocked := 1.0
		for _pass in range(10):
			var fraction := (allowed + blocked) * 0.5
			var candidate := base.lerp(target, fraction)
			candidate.y = float(ground_at.call(candidate.x)) + float(leg["depth"])
			if bool(SpiderIK.solve(leg["spatial"], predicted, body_angle, candidate)["reachable"]):
				allowed = fraction
			else:
				blocked = fraction
		var result := base.lerp(target, allowed)
		result.y = float(ground_at.call(result.x)) + float(leg["depth"])
		return result
	# 발을 내려놓을 시점의 고관절 기준으로 닿는 지면을 선택한다.
	# 경사가 바뀌면 x 수정이 y도 바꾸므로 몇 차례 재평가한다. 불가능한 지형은 IK가 정직하게 뜬 발로 표시한다.
	var hip: Vector2 = body_pos + (leg["ref_hip"] as Vector2).rotated(body_angle) + Vector2(prediction, 0.0)
	var foot_vector := Vector2.RIGHT.rotated(float(leg["foot_angle"])) * float(leg["foot_length"])
	var reach: float = float(leg["upper_length"]) + float(leg["lower_length"]) - 2.0
	var target := wanted
	for _pass in range(4):
		target.y = float(ground_at.call(target.x)) + float(leg["depth"])
		var vertical := target.y - foot_vector.y - hip.y
		if absf(vertical) >= reach:
			break
		var span := sqrt(maxf(reach * reach - vertical * vertical, 0.0))
		target.x = clampf(target.x - foot_vector.x, hip.x - span, hip.x + span) + foot_vector.x
	target.y = float(ground_at.call(target.x)) + float(leg["depth"])
	return target


func _reach_margin(leg: Dictionary, prediction: float = 0.0) -> float:
	if spider_gait:
		return SpiderIK.margin(leg["spatial"], body_pos + Vector2(prediction, 0), body_angle, leg["contact"])
	var mount: Vector2 = body_pos + (leg["ref_mount"] as Vector2).rotated(body_angle) + Vector2(prediction, 0.0)
	var foot_vector := Vector2.RIGHT.rotated(float(leg["foot_angle"])) * float(leg["foot_length"])
	var ankle: Vector2 = (leg["contact"] as Vector2) - foot_vector
	var maximum: float = float(leg["mount_length"]) + float(leg["upper_length"]) + float(leg["lower_length"])
	return maximum - mount.distance_to(ankle)


func _tick_contacts(delta: float) -> void:
	if spider_gait:
		_tick_spider_contacts(delta)
		return
	_step_wait = maxf(_step_wait - delta, 0.0)
	var stepping_count := 0
	for leg in _legs:
		if airborne:
			var tucked: Vector2 = body_pos + (leg["ref_toe"] as Vector2).rotated(body_angle)
			tucked.y -= 21.0 if _vertical_velocity < 0.0 else 4.0
			leg["contact"] = (leg["contact"] as Vector2).lerp(tucked, 1.0 - exp(-delta * 12.0))
			leg["planted"] = false
			continue
		if not leg["stepping"]:
			continue
		leg["progress"] = minf(float(leg["progress"]) + delta / float(leg["duration"]), 1.0)
		var t: float = leg["progress"]
		var phase := _ease(t)
		var contact: Vector2 = (leg["from"] as Vector2).lerp(leg["target"], phase)
		var lift_phase := t / 0.4 if t < 0.4 else (1.0 - t) / 0.6
		contact.y -= _ease(clampf(lift_phase, 0.0, 1.0)) * float(leg["lift"])
		contact.y = minf(contact.y, float(ground_at.call(contact.x)) + float(leg["depth"]))
		if t >= 1.0:
			# 보행 속도가 지지 예산 때문에 줄어들면 예측한 몸 위치와 실제 착지 위치가 달라진다.
			# 아직 스윙인 마지막 순간에 실제 골격으로 닿는 지면을 정한 뒤 그 점을 잠근다.
			contact = _reachable_contact(leg, contact, 0.0)
			leg["target"] = contact
		leg["contact"] = contact
		if t >= 1.0:
			leg["stepping"] = false
			_step_wait = 0.025
			_suspension_velocity += 3.0
		else:
			stepping_count += 1
	if airborne or stepping_count >= 2 or _step_wait > 0.0:
		return
	# 가장 뒤처진 다리를 먼저 옮긴다. 한 번에 두 발까지, 대각선 반대쪽만 함께 허용한다.
	var candidates: Array = []
	for leg in _legs:
		if leg["stepping"]:
			continue
		var offset := _rest_contact(leg).x - (leg["contact"] as Vector2).x
		# 앞으로 내려놓은 발은 체중이 지나갈 때까지 기다린다. 절댓값으로 검사하면
		# 선행 발자리가 착지 즉시 다음 스텝을 부르는 제자리 허둥거림이 된다.
		var error := absf(offset) if absf(speed) < 8.0 else offset * signf(speed)
		var needs_reach := not bool(leg["planted"])
		var threshold := 8.0 if absf(speed) < 8.0 else 25.0
		# 원화 FF는 몸 옆으로 길게 벌어진 다리라 남은 도달 여유가 다른 다리보다 작다.
		# 다른 대각 쌍이 스윙을 끝낼 때까지 버틸 수 없으면 이 쌍의 차례를 먼저 준다.
		var margin := _reach_margin(leg, speed * lerpf(0.25, 0.18, motion))
		var urgent := margin < 12.0 and absf(speed) > 8.0
		if error > threshold or needs_reach or urgent:
			candidates.append({"leg": leg, "priority": error + maxf(0.0, 35.0 - margin) * 12.0 + (1000.0 if needs_reach else 0.0)})
	candidates.sort_custom(func(a, b): return a["priority"] > b["priority"])
	for item in candidates:
		if stepping_count >= 2:
			break
		var leg: Dictionary = item["leg"]
		var compatible := true
		for other in _legs:
			if other["stepping"] and int(other["gait_group"]) != int(leg["gait_group"]):
				compatible = false
		if not compatible:
			continue
		leg["from"] = leg["toe"]
		leg["contact"] = leg["toe"]
		leg["duration"] = lerpf(0.25, 0.18, motion)
		var lead: float = speed * (float(leg["duration"]) * 1.55 + 0.025)
		leg["target"] = _reachable_contact(leg, _rest_contact(leg, lead), speed * float(leg["duration"]))
		leg["lift"] = lerpf(20.0, 34.0, motion)
		if absf(speed) < 8.0:
			leg["lift"] = 12.0
		leg["progress"] = 0.0
		leg["stepping"] = true
		leg["planted"] = false
		stepping_count += 1


## 두 대각 쌍이 번갈아 지지한다. 먼저 착지한 발이 즉시 다시 들리는 탐욕적 선택을 피한다.
func _tick_spider_contacts(delta: float) -> void:
	_step_wait = maxf(_step_wait - delta, 0.0)
	var swinging := false
	for leg in _legs:
		if airborne:
			var tucked: Vector2 = body_pos + (leg["rest_toe"] as Vector2).rotated(body_angle) - Vector2(0, 24)
			var wanted := tucked
			var clearance := maxf(float(ground_at.call(body_pos.x)) - _height - body_pos.y, 0.0)
			if _vertical_velocity >= 0.0:
				# 내려오는 동안 발을 실제 착지점으로 편다. 지면에 닿는 한 프레임에
				# 네 발을 새 위치로 보내면 무릎이 수십 px 튀므로 마지막 60px에서 준비한다.
				var landing := _rest_contact(leg, speed * 0.07)
				wanted = tucked.lerp(landing, _ease(1.0 - clampf(clearance / 60.0, 0.0, 1.0)))
			var contact: Vector2 = (leg["contact"] as Vector2).lerp(wanted, 1.0 - exp(-delta * 12.0))
			if _vertical_velocity >= 0.0:
				contact = contact.lerp(_rest_contact(leg, speed * 0.07), _ease(1.0 - clampf(clearance / 18.0, 0.0, 1.0)))
			leg["contact"] = contact
			leg["planted"] = false
			continue
		if not leg["stepping"]:
			continue
		if bool(leg.get("prelift", false)):
			# 높은 턱 앞에서는 먼저 발을 든다. 수평 이동 후 지면 높이로 clamp하면
			# 수직 벽을 지나는 순간 관절이 위로 튄다.
			var raised: Vector2 = leg["contact"]
			raised.y = move_toward(raised.y, float(leg["prelift_y"]), 320.0 * delta)
			leg["contact"] = raised
			leg["from"] = raised
			if absf(raised.y - float(leg["prelift_y"])) < 0.01:
				leg["prelift"] = false
			swinging = true
			continue
		leg["progress"] = minf(float(leg["progress"]) + delta / float(leg["duration"]), 1.0)
		var t: float = leg["progress"]
		# 짧은 스윙의 가운데에 속도가 몰리지 않게, 출발/도착만 완화하고 고르게 옮긴다.
		var contact: Vector2 = (leg["from"] as Vector2).lerp(leg["target"], SpiderIK.swing_ease(t))
		# 이륙은 빠르게, 착지는 천천히. 지지 중인 발은 이 보간에 들어오지 않는다.
		var lift_phase := t / 0.38 if t < 0.38 else (1.0 - t) / 0.62
		contact.y -= _ease(clampf(lift_phase, 0.0, 1.0)) * float(leg["lift"])
		contact.y = minf(contact.y, float(ground_at.call(contact.x)) + float(leg["depth"]))
		if t >= 1.0:
			contact = _reachable_contact(leg, contact, 0.0)
			leg["target"] = contact
		# 절벽의 바닥 clamp가 풀리는 순간에도 발이 한 프레임에 낙하하지 않는다.
		# 아래로 딛는 스텝은 시간표가 끝나도 실제 발이 지면에 닿을 때까지 스윙으로 남는다.
		var destination := contact
		contact.y = minf(contact.y, (leg["contact"] as Vector2).y + 280.0 * delta)
		if t >= 1.0 and contact.distance_to(destination) < 0.01:
			leg["stepping"] = false
			_step_wait = 0.035
			_suspension_velocity += 2.0
		else:
			swinging = true
		leg["contact"] = contact
	if airborne or swinging or _step_wait > 0.0:
		return
	var requested_speed := clampf(input_dir, -1.0, 1.0) * (RUN_SPEED if running else WALK_SPEED)
	var pace := maxf(absf(speed), absf(requested_speed))
	var duration := lerpf(0.22, 0.16, clampf(pace / RUN_SPEED, 0.0, 1.0))
	var moving := absf(speed) > 8.0 or absf(requested_speed) > 8.0
	var direction := signf(speed) if absf(speed) > 8.0 else signf(requested_speed)
	var needs_step := false
	var pair := _next_pair
	# 지지 한계에서 실제 속도가 0이 되더라도 이동 명령의 다음 한 걸음을 준비한다.
	# 실제 속도만 보면 '움직이지 않으니 발을 안 듦'과 '발이 고정되어 못 움직임'이 교착된다.
	if moving:
		var prediction := direction * pace * (duration + 0.04)
		for leg in _legs:
			if _reach_margin(leg, prediction) < 0.0:
				needs_step = true
	# 정지 후에는 필요한 발만 내려놓고 정지한다. 정지 자세를 계속 재스텝하지 않는다.
	for pass_index in range(2):
		for leg in _legs:
			if int(leg["gait_group"]) != pair:
				continue
			var error := _rest_contact(leg).x - (leg["contact"] as Vector2).x
			var behind := error * direction if moving else absf(error)
			if behind > (7.0 if moving else 12.0) or not bool(leg["planted"]):
				needs_step = true
		if needs_step or moving:
			break
		pair = 1 - pair
	if not needs_step:
		return
	for leg in _legs:
		if int(leg["gait_group"]) != pair:
			continue
		if not moving and bool(leg["planted"]) and absf(_rest_contact(leg).x - (leg["contact"] as Vector2).x) <= 12.0:
			continue
		leg["from"] = leg["toe"]
		leg["contact"] = leg["toe"]
		leg["duration"] = duration if moving else 0.22
		# 착지 시 몸 위치보다 다음 지지 기간의 절반만큼 앞에 발을 내려놓는다.
		var lead := speed * (duration * 1.45 + 0.025)
		leg["target"] = _reachable_contact(leg, _rest_contact(leg, lead), speed * duration)
		leg["lift"] = lerpf(17.0, 28.0, motion) if moving else 10.0
		leg["prelift"] = (leg["target"] as Vector2).y < (leg["from"] as Vector2).y - 6.0
		leg["prelift_y"] = (leg["target"] as Vector2).y - 6.0
		leg["progress"] = 0.0
		leg["stepping"] = true
		leg["planted"] = false
	_next_pair = 1 - pair


func _support_reachable(at: Vector2, angle: float) -> bool:
	for leg in _legs:
		var lifting_off := spider_gait and bool(leg["stepping"]) and float(leg["progress"]) <= 0.0
		# 스윙 시작 프레임에는 발이 아직 원래 접점에 있다. 몸만 먼저 도달범위 밖으로
		# 움직이면 IK가 발끝을 단차 안으로 밀어내므로, 실제로 들기 전까지 지지에 포함한다.
		if not lifting_off and (leg["stepping"] or not bool(leg["planted"])):
			continue
		if spider_gait:
			if not bool(SpiderIK.solve(leg["spatial"], at, angle, leg["contact"])["reachable"]):
				return false
			continue
		var mount: Vector2 = at + (leg["ref_mount"] as Vector2).rotated(angle)
		var foot_vector := Vector2.RIGHT.rotated(float(leg["foot_angle"])) * float(leg["foot_length"])
		var ankle: Vector2 = (leg["contact"] as Vector2) - foot_vector
		var first: float = leg["mount_length"]
		var second: float = leg["upper_length"]
		var third: float = leg["lower_length"]
		var reach := first + second + third
		var minimum := maxf(maxf(first, maxf(second, third)) * 2.0 - reach, 0.0)
		var distance := mount.distance_to(ankle)
		if distance > reach - 0.4 or distance < minimum + 0.1:
			return false
	return true


func _limit_body_to_support(previous: Vector2, previous_angle: float, delta: float) -> void:
	if _support_reachable(body_pos, body_angle) or not _support_reachable(previous, previous_angle):
		return
	# 지지 발을 잡아 끌지 않는다. 다른 대각 쌍이 착지할 때까지 몸이 실제 관절 여유
	# 안에서만 전진한다. 발을 옮기지 않고 무한히 빠르게 몸만 보낼 수는 없다.
	var allowed := 0.0
	var blocked := 1.0
	for _iteration in range(14):
		var fraction := (allowed + blocked) * 0.5
		if _support_reachable(previous.lerp(body_pos, fraction), lerpf(previous_angle, body_angle, fraction)):
			allowed = fraction
		else:
			blocked = fraction
	body_pos = previous.lerp(body_pos, allowed)
	body_angle = lerpf(previous_angle, body_angle, allowed)
	speed = (body_pos.x - previous.x) / maxf(delta, 0.001)
	_suspension_velocity *= allowed
	_pitch_velocity *= allowed


func _solve_pose() -> void:
	if spider_gait:
		for leg in _legs:
			var result: Dictionary = SpiderIK.solve(leg["spatial"], body_pos, body_angle, leg["contact"], float(leg["progress"]) if leg["stepping"] else 0.0)
			for key in LEG_POINT_KEYS:
				leg[key] = result[key]
			leg["spatial_points"] = result["spatial_points"]
			leg["spatial_lengths"] = result["spatial_lengths"]
			leg["space_reachable"] = result["reachable"]
			var ground_y := float(ground_at.call((leg["toe"] as Vector2).x)) + float(leg["depth"])
			leg["planted"] = not airborne and not bool(leg["stepping"]) and (leg["toe"] as Vector2).distance_to(leg["contact"]) < 0.3 and absf((leg["toe"] as Vector2).y - ground_y) < 0.5
		return
	for leg in _legs:
		var mount: Vector2 = body_pos + (leg["ref_mount"] as Vector2).rotated(body_angle)
		leg["mount"] = mount
		var rest_hip: Vector2 = body_pos + (leg["ref_hip"] as Vector2).rotated(body_angle)
		var foot_angle: float = leg["foot_angle"]
		if leg["stepping"]:
			foot_angle += sin(float(leg["progress"]) * TAU) * 0.09 * signf(speed)
		var foot_vector := Vector2.RIGHT.rotated(foot_angle) * float(leg["foot_length"])
		var wanted_ankle: Vector2 = (leg["contact"] as Vector2) - foot_vector
		var upper: float = leg["upper_length"]
		var lower: float = leg["lower_length"]
		# 골반 암 역시 회전하는 고정 길이 뼈다. 발이 고관절 아래를 지날 때 두 마디의
		# 최소 반경 안으로 파고들거나 몸 뒤로 처져 최대 반경을 넘으면 이 축이 먼저 접힌다.
		var hip := _solve_mount(mount, rest_hip, wanted_ankle, float(leg["mount_length"]), absf(upper - lower) + 8.0, (upper + lower) * 0.96)
		var delta := wanted_ankle - hip
		var distance := clampf(delta.length(), absf(upper - lower) + REACH_EPS, upper + lower - REACH_EPS)
		var direction := delta.normalized() if delta.length_squared() > 0.00001 else Vector2.DOWN
		var ankle := hip + direction * distance
		var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
		var perpendicular := sqrt(maxf(upper * upper - along * along, 0.0))
		# cross(upper, lower) has the opposite sign of the knee's perpendicular displacement.
		var knee := hip + direction * along - Vector2(-direction.y, direction.x) * perpendicular * float(leg["bend"])
		var toe := ankle + foot_vector
		leg["hip"] = hip
		leg["knee"] = knee
		leg["ankle"] = ankle
		leg["toe"] = toe
		var ground_y: float = float(ground_at.call(toe.x)) + float(leg["depth"])
		leg["planted"] = not airborne and not bool(leg["stepping"]) and toe.distance_to(leg["contact"]) < 0.3 and absf(toe.y - ground_y) < 0.5


static func _solve_mount(mount: Vector2, preferred_hip: Vector2, ankle: Vector2, length: float, minimum: float, maximum: float) -> Vector2:
	var radius := preferred_hip.distance_to(ankle)
	if length <= 0.001 or (radius >= minimum and radius <= maximum):
		return preferred_hip
	var target := ankle - mount
	var distance := target.length()
	if distance <= 0.001:
		return preferred_hip
	var desired_radius := clampf(radius, minimum, maximum)
	var cosine := clampf((distance * distance + length * length - desired_radius * desired_radius) / (2.0 * distance * length), -1.0, 1.0)
	var spread := acos(cosine)
	var base := target.angle()
	var preferred := (preferred_hip - mount).angle()
	var first := base + spread
	var second := base - spread
	var angle := first if absf(wrapf(first - preferred, -PI, PI)) <= absf(wrapf(second - preferred, -PI, PI)) else second
	return mount + Vector2.RIGHT.rotated(angle) * length


func _update_body_pose(delta: float) -> void:
	var chassis: Vector2 = body_pos + _point("body.chassis").rotated(body_angle)
	var pivot: Vector2 = body_pos + _point("body.pivot").rotated(body_angle)
	var gun: Vector2 = body_pos + _point("body.gun").rotated(body_angle)
	var rest_vector := _point("body.muzzle") - _point("body.barrel")
	var mount_vector := _point("body.barrel") - _point("body.gun")
	var wanted_angle := rest_vector.angle() + body_angle
	if aim_target != null and not source_rest:
		var aim: Vector2 = (aim_target as Vector2) - gun
		if aim.length_squared() > 1.0:
			# 포가는 총열축 아래에 있다. 포가→목표 각만 쓰면 총열이 목표 위를 지나가므로
			# 회전하는 anchor의 수직 오프셋을 해석적으로 보정한다.
			var transverse := mount_vector.rotated(-rest_vector.angle()).y
			wanted_angle = aim.angle() - asin(clampf(transverse / aim.length(), -0.99, 0.99))
	if source_rest or delta <= 0.0:
		_gun_angle = wanted_angle
	else:
		_gun_angle = lerp_angle(_gun_angle, wanted_angle, 1.0 - exp(-delta * 18.0))
	var gun_rotation := _gun_angle - rest_vector.angle()
	var barrel := gun + mount_vector.rotated(gun_rotation)
	_body_pose = {"chassis": chassis, "pivot": pivot, "gun": gun, "barrel": barrel,
		"upper_center": body_pos + _point("body.upper").rotated(body_angle),
		"muzzle": barrel + Vector2.RIGHT.rotated(_gun_angle) * rest_vector.length(),
		"body_angle": body_angle, "torso_angle": body_angle, "gun_angle": _gun_angle}


func _update_bones() -> void:
	position = body_pos
	rotation = 0.0
	var chassis_angle := ((_body_pose["pivot"] as Vector2) - (_body_pose["chassis"] as Vector2)).angle()
	var assembly_angle := ((_body_pose["upper_center"] as Vector2) - (_body_pose["pivot"] as Vector2)).angle()
	_chassis.position = (_body_pose["chassis"] as Vector2) - body_pos
	_chassis.rotation = chassis_angle
	_upper_assembly.position = Vector2(_chassis.length, 0.0)
	_upper_assembly.rotation = assembly_angle - chassis_angle
	_gun.position = ((_body_pose["gun"] as Vector2) - (_body_pose["pivot"] as Vector2)).rotated(-assembly_angle)
	var pivot_angle := ((_body_pose["barrel"] as Vector2) - (_body_pose["gun"] as Vector2)).angle()
	_gun.rotation = pivot_angle - assembly_angle
	_barrel.position = Vector2(_gun.length, 0.0)
	_barrel.rotation = _gun_angle - pivot_angle
	for leg in _legs:
		var chain: Array = _leg_bones[leg["id"]]
		var mount_bone: Bone2D = chain[0]
		var upper: Bone2D = chain[1]
		var lower: Bone2D = chain[2]
		var foot: Bone2D = chain[3]
		var mount_angle := ((leg["hip"] as Vector2) - (leg["mount"] as Vector2)).angle()
		var upper_angle := ((leg["knee"] as Vector2) - (leg["hip"] as Vector2)).angle()
		var lower_angle := ((leg["ankle"] as Vector2) - (leg["knee"] as Vector2)).angle()
		# 물리 길이는 spatial_lengths에 고정되어 있다. Bone2D는 화면 투영 길이를 따른다.
		mount_bone.length = (leg["mount"] as Vector2).distance_to(leg["hip"])
		upper.length = (leg["hip"] as Vector2).distance_to(leg["knee"])
		lower.length = (leg["knee"] as Vector2).distance_to(leg["ankle"])
		foot.length = (leg["ankle"] as Vector2).distance_to(leg["toe"])
		mount_bone.position = ((leg["mount"] as Vector2) - (_body_pose["chassis"] as Vector2)).rotated(-chassis_angle)
		mount_bone.rotation = mount_angle - chassis_angle
		upper.position = Vector2(mount_bone.length, 0.0)
		upper.rotation = upper_angle - mount_angle
		lower.position = Vector2(upper.length, 0.0)
		lower.rotation = lower_angle - upper_angle
		foot.position = Vector2(lower.length, 0.0)
		foot.rotation = ((leg["toe"] as Vector2) - (leg["ankle"] as Vector2)).angle() - lower_angle


func pose_legs() -> Array:
	return _legs


func pose_body() -> Dictionary:
	return _body_pose


func muzzle() -> Vector2:
	return _body_pose.get("muzzle", body_pos)


func aim_dir() -> Vector2:
	return Vector2.RIGHT.rotated(_gun_angle)


static func _ease(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _spring(value: float, velocity: float, target: float, omega: float, delta: float) -> Vector2:
	var displacement := value - target
	var rate := velocity + omega * displacement
	var decay := exp(-omega * delta)
	return Vector2(target + (displacement + rate * delta) * decay, (velocity - omega * rate * delta) * decay)
