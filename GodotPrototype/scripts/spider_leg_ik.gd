class_name SpiderLegIK
extends RefCounted
## 화면에서 짧아진 길이와 실제 뼈 길이를 분리하는 거미형 3D 다리 솔버.
## 3D 축: x=이동, y=아래, z=먼 쪽. body_pos는 사영 후 화면 평행이동이다.

const DEPTH_X := 0.55
const DEPTH_Y := -0.18
const YAW_LIMIT := PI * 65.0 / 180.0
const PITCH_LIMIT := PI * 20.0 / 180.0
const EPS := 0.001
const COMFORT_MARGIN := 6.0
const COMFORT_WEIGHT := 0.04
const POINT_NAMES := ["mount", "hip", "knee", "ankle", "toe"]


static func swing_ease(t: float) -> float:
	# 짧은 가속/감속 구간과 일정한 중간 속도. 경계의 위치와 속도가 모두 연속이다.
	const ACCEL_PHASE := 0.18
	var at := clampf(t, 0.0, 1.0)
	if at < ACCEL_PHASE:
		return at * at / (2.0 * ACCEL_PHASE * (1.0 - ACCEL_PHASE))
	if at > 1.0 - ACCEL_PHASE:
		return 1.0 - (1.0 - at) * (1.0 - at) / (2.0 * ACCEL_PHASE * (1.0 - ACCEL_PHASE))
	return (at - ACCEL_PHASE * 0.5) / (1.0 - ACCEL_PHASE)


static func project(point: Vector3) -> Vector2:
	return Vector2(point.x + DEPTH_X * point.z, point.y + DEPTH_Y * point.z)


static func inverse(point: Vector2, z: float = 0.0) -> Vector3:
	return Vector3(point.x - DEPTH_X * z, point.y - DEPTH_Y * z, z)


static func build(leg: Dictionary, height: float) -> Dictionary:
	var side := 1.0 if bool(leg.get("far", false)) else -1.0
	var size := maxf(absf(height) / 140.0, 0.1)
	var depths := [30.0, 85.0, 145.0, 125.0, 125.0]
	var points: Array[Vector3] = []
	for i in range(POINT_NAMES.size()):
		var key: String = "ref_" + POINT_NAMES[i]
		if not leg.get(key) is Vector2 or not (leg[key] as Vector2).is_finite():
			return {"valid": false}
		points.append(inverse(leg[key], side * float(depths[i]) * size))
	# 원화에서 들려 있던 발의 보행 목표는 외부에서 정한다. 모든 발의 물리 바닥은 같다.
	var ground_toe: Vector2 = leg.get("rest_toe", leg["ref_toe"])
	var grounded_toe := Vector3(ground_toe.x - DEPTH_X * points[4].z, height, points[4].z)
	var lengths: Array[float] = []
	for i in range(4):
		var length := points[i].distance_to(points[i + 1])
		if not is_finite(length) or length <= EPS:
			return {"valid": false}
		lengths.append(length)
	# 접지 목표가 원본 바인드의 발뼈 길이를 변경해서는 안 된다.
	var stance := project(grounded_toe)
	var upper := points[2] - points[1]
	var span := points[3] - points[1]
	var normal := span.cross(upper)
	if normal.length_squared() < EPS * EPS:
		normal = Vector3(0.0, 0.0, side)
	return {"valid": true, "id": leg.get("id", ""), "rest3d": points,
		"lengths": lengths, "depth": stance.y - height, "stance": stance,
		"rest_z": points[4].z, "height": height, "side": side,
		"foot_vector": points[4] - points[3], "pole_normal": normal.normalized(),
		"pole_vector": upper.normalized()}


static func _pitch(point: Vector3, angle: float) -> Vector3:
	var planar := Vector2(point.x, point.y).rotated(angle)
	return Vector3(planar.x, planar.y, point.z)


static func _yaw(point: Vector3, angle: float) -> Vector3:
	var planar := Vector2(point.x, point.z).rotated(angle)
	return Vector3(planar.x, point.y, planar.y)


static func _spherical(length: float, yaw: float, pitch: float) -> Vector3:
	var horizontal := cos(pitch) * length
	return Vector3(cos(yaw) * horizontal, sin(pitch) * length, sin(yaw) * horizontal)


static func _signed_margin(distance: float, upper: float, lower: float) -> float:
	return minf(distance - absf(upper - lower) - EPS, upper + lower - EPS - distance)


static func _candidate(mount: Vector3, ankle: Vector3, length: float, yaw: float,
		pitch: float, preferred_yaw: float, rest_pitch: float, upper: float, lower: float) -> Dictionary:
	var hip := mount + _spherical(length, yaw, pitch)
	# Godot Vector3는 float32다. 거의 같은 후보의 비용은 float64 스칼라로 비교해야
	# 완전 신전 부근의 반올림 오차가 후보 순서를 뒤집지 않는다.
	var offset := ankle - mount
	var dx: float = offset.x
	var dy: float = offset.y
	var dz: float = offset.z
	var dot := dy * sin(pitch) + cos(pitch) * (dx * cos(yaw) + dz * sin(yaw))
	var distance := sqrt(maxf(dx * dx + dy * dy + dz * dz + length * length - 2.0 * length * dot, 0.0))
	var clearance := _signed_margin(distance, upper, lower)
	var angular_cost := pow(wrapf(yaw - preferred_yaw, -PI, PI), 2.0) + pow(pitch - rest_pitch, 2.0) * 1.5
	# 닿는 해를 우선하고 그 안에서 원래 관절 방향에 가장 가까운 해를 선택한다.
	# 여유가 있을 때 완전 신전/접힘에 붙지 않아 무릎의 sqrt 특이점을 예방한다.
	var reserve := minf(COMFORT_MARGIN, minf(upper, lower) * 0.5)
	var cost := angular_cost + pow(maxf(-clearance, 0.0), 2.0) * 100.0 + pow(maxf(reserve - clearance, 0.0), 2.0) * COMFORT_WEIGHT
	return {"hip": hip, "yaw": yaw, "pitch": pitch, "margin": clearance, "cost": cost}


static func _hip_at_pitch(mount: Vector3, ankle: Vector3, length: float, pitch: float,
		rest_yaw: float, preferred_yaw: float, rest_pitch: float, upper: float, lower: float,
		yaw_limit: float = YAW_LIMIT) -> Dictionary:
	var yaw_min := rest_yaw - yaw_limit
	var yaw_max := rest_yaw + yaw_limit
	var best := _candidate(mount, ankle, length, preferred_yaw, pitch, preferred_yaw, rest_pitch, upper, lower)
	var offset := ankle - mount
	var target_yaw := rest_yaw + wrapf(atan2(offset.z, offset.x) - rest_yaw, -PI, PI)
	var horizontal := Vector2(offset.x, offset.z).length()
	var radius := length * cos(pitch)
	var vertical := offset.y - length * sin(pitch)
	var yaw_candidates := [yaw_min, yaw_max, clampf(target_yaw, yaw_min, yaw_max)]
	if horizontal * radius > EPS:
		# 두 마디의 최소/최대 도달 구면과 coxa 원의 교점. 0.02 여유로 특이점을 피한다.
		var reserve := minf(COMFORT_MARGIN, minf(upper, lower) * 0.5)
		for reach in [absf(upper - lower) + 0.02, upper + lower - 0.02,
			absf(upper - lower) + reserve + EPS, upper + lower - reserve - EPS]:
			var cosine: float = (horizontal * horizontal + radius * radius + vertical * vertical - reach * reach) / (2.0 * horizontal * radius)
			if cosine < -1.0 or cosine > 1.0:
				continue
			var spread := acos(clampf(cosine, -1.0, 1.0))
			for sign_value in [-1.0, 1.0]:
				var yaw := rest_yaw + wrapf(target_yaw + spread * sign_value - rest_yaw, -PI, PI)
				yaw_candidates.append(clampf(yaw, yaw_min, yaw_max))
	for yaw in yaw_candidates:
		var candidate := _candidate(mount, ankle, length, float(yaw), pitch, preferred_yaw, rest_pitch, upper, lower)
		if float(candidate["cost"]) < float(best["cost"]):
			best = candidate
	# 구면 교점과 선호 방향 사이에도 더 좋은 해가 있다. 이 연속 최솟값을 놓치면
	# 도달 경계에서 두 이산 후보가 교대하며 coxa가 작은 입력에도 갑자기 뛴다.
	var low := minf(float(best["yaw"]), preferred_yaw)
	var high := maxf(float(best["yaw"]), preferred_yaw)
	if high - low > 0.00001:
		var minimum := absf(upper - lower) + EPS
		var maximum := upper + lower - EPS
		var product := horizontal * radius
		var constant := horizontal * horizontal + radius * radius + vertical * vertical
		if _yaw_derivative(low, preferred_yaw, target_yaw, product, constant, minimum, maximum) <= 0.0 and _yaw_derivative(high, preferred_yaw, target_yaw, product, constant, minimum, maximum) >= 0.0:
			for _iteration in range(14):
				var middle := (low + high) * 0.5
				if _yaw_derivative(middle, preferred_yaw, target_yaw, product, constant, minimum, maximum) < 0.0:
					low = middle
				else:
					high = middle
			var candidate := _candidate(mount, ankle, length, (low + high) * 0.5, pitch, preferred_yaw, rest_pitch, upper, lower)
			if float(candidate["cost"]) < float(best["cost"]):
				best = candidate
	return best


static func _yaw_derivative(yaw: float, preferred: float, target: float, product: float,
		constant: float, minimum: float, maximum: float) -> float:
	var distance := sqrt(maxf(constant - 2.0 * product * cos(yaw - target), EPS * EPS))
	var outside := distance - clampf(distance, minimum, maximum)
	var reserve := minf(COMFORT_MARGIN, (maximum - minimum) * 0.25)
	var comfort := distance - clampf(distance, minimum + reserve, maximum - reserve)
	return 2.0 * (yaw - preferred) + (200.0 * outside + 2.0 * COMFORT_WEIGHT * comfort) * product * sin(yaw - target) / distance


static func _choose_hip(state: Dictionary, mount: Vector3, rest_hip: Vector3, ankle: Vector3) -> Dictionary:
	var lengths: Array = state["lengths"]
	var original := rest_hip - mount
	var rest_yaw := atan2(original.z, original.x)
	var rest_pitch := atan2(original.y, Vector2(original.x, original.z).length())
	var yaw_limit := _config_angle(state, "yaw_limit", rad_to_deg(YAW_LIMIT), 1.0, 89.0)
	var pitch_limit := _config_angle(state, "pitch_limit", rad_to_deg(PITCH_LIMIT), 1.0, 45.0)
	var yaw_bias := _config_angle(state, "coxa_yaw_bias", 0.0, -65.0, 65.0)
	var pitch_bias := _config_angle(state, "coxa_pitch_bias", 0.0, -40.0, 40.0)
	var pitch_min := maxf(rest_pitch - pitch_limit, -PI * 0.49)
	var pitch_max := minf(rest_pitch + pitch_limit, PI * 0.49)
	var preferred_pitch := clampf(rest_pitch + pitch_bias, pitch_min, pitch_max)
	var toward := ankle - mount
	var target_yaw := atan2(toward.z, toward.x)
	# Coxa가 보폭의 앞뒤 방향을 먼저 따라간다. 닿지 않을 때만 별도 후보가 이 방향을 보정한다.
	var preferred_yaw := rest_yaw + clampf(wrapf(target_yaw - rest_yaw, -PI, PI) * 0.72 + yaw_bias, -yaw_limit, yaw_limit)
	var best := _hip_at_pitch(mount, ankle, lengths[0], preferred_pitch, rest_yaw, preferred_yaw, preferred_pitch, lengths[1], lengths[2], yaw_limit)
	if float(best["margin"]) >= minf(COMFORT_MARGIN, minf(float(lengths[1]), float(lengths[2])) * 0.5) and absf(float(best["yaw"]) - preferred_yaw) < 0.0001:
		best["yaw_delta"] = float(best["yaw"]) - rest_yaw
		return best
	# 13 + 7 회면 최종 정밀도가 관절 범위의 1/1536 (60도 범위에서 0.04도) 이다.
	# 17 + 11 회는 그림에 드러나지도 않는 자릿수를 위해 IK 를 40회 가까이 돌렸다.
	for i in range(13):
		var pitch := lerpf(pitch_min, pitch_max, float(i) / 12.0)
		var candidate := _hip_at_pitch(mount, ankle, lengths[0], pitch, rest_yaw, preferred_yaw, preferred_pitch, lengths[1], lengths[2], yaw_limit)
		if float(candidate["cost"]) < float(best["cost"]):
			best = candidate
	# 피치 후보 사이를 더 잘게 탐색하여 후보 전환에 따른 각도 차이를 줄인다.
	var radius := (pitch_max - pitch_min) / 12.0
	for _pass in range(7):
		var center: float = best["pitch"]
		for direction in [-1.0, 1.0]:
			var pitch := clampf(center + radius * direction, pitch_min, pitch_max)
			var candidate := _hip_at_pitch(mount, ankle, lengths[0], pitch, rest_yaw, preferred_yaw, preferred_pitch, lengths[1], lengths[2], yaw_limit)
			if float(candidate["cost"]) < float(best["cost"]):
				best = candidate
		radius *= 0.5
	best["yaw_delta"] = float(best["yaw"]) - rest_yaw
	return best


static func _config_angle(state: Dictionary, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var config: Dictionary = state.get("config", {})
	var value = config.get(key, fallback)
	if (not value is float and not value is int) or not is_finite(float(value)):
		value = fallback
	return deg_to_rad(clampf(float(value), minimum, maximum))


static func _configuration(state: Dictionary, body_pos: Vector2, body_angle: float, contact: Vector2, swing: float) -> Dictionary:
	var rest: Array = state["rest3d"]
	var translation := Vector3(body_pos.x, body_pos.y, 0.0)
	var mount := _pitch(rest[0], body_angle) + translation
	var rest_hip := _pitch(rest[1], body_angle) + translation
	var foot: Vector3 = state["foot_vector"]
	if swing > 0.0 and swing < 1.0:
		foot = _pitch(foot, sin(swing * TAU) * 0.075)
	var toe := inverse(contact, float(state["rest_z"]))
	var ankle := toe - foot
	var chosen := _choose_hip(state, mount, rest_hip, ankle)
	chosen["mount"] = mount
	chosen["wanted_ankle"] = ankle
	chosen["foot_vector"] = foot
	return chosen


static func margin(state: Dictionary, body_pos: Vector2, body_angle: float, contact: Vector2) -> float:
	if not bool(state.get("valid", false)):
		return -INF
	return float(_configuration(state, body_pos, body_angle, contact, 0.0)["margin"])


static func solve(state: Dictionary, body_pos: Vector2, body_angle: float, contact: Vector2, swing: float = 0.0) -> Dictionary:
	if not bool(state.get("valid", false)):
		return {"reachable": false, "spatial_points": [], "spatial_lengths": []}
	var config := _configuration(state, body_pos, body_angle, contact, swing)
	var lengths: Array = state["lengths"]
	var hip: Vector3 = config["hip"]
	var wanted: Vector3 = config["wanted_ankle"]
	var span := wanted - hip
	var axis := span.normalized() if span.length_squared() > EPS * EPS else Vector3.DOWN
	var upper: float = lengths[1]
	var lower: float = lengths[2]
	var distance := clampf(span.length(), absf(upper - lower) + EPS, upper + lower - EPS)
	var ankle := hip + axis * distance
	var normal := _pitch(_yaw(state["pole_normal"], float(config["yaw_delta"])), body_angle)
	var pole := normal.cross(axis)
	if pole.length_squared() < EPS * EPS:
		var reference := _pitch(_yaw(state["pole_vector"], float(config["yaw_delta"])), body_angle)
		pole = reference - axis * reference.dot(axis)
	if pole.length_squared() < EPS * EPS:
		pole = axis.cross(Vector3.RIGHT if absf(axis.x) < 0.8 else Vector3.FORWARD)
	pole = pole.normalized()
	pole = pole.rotated(axis, _config_angle(state, "knee_swivel", 0.0, -90.0, 90.0))
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var bend := sqrt(maxf(upper * upper - along * along, 0.0))
	var knee := hip + axis * along + pole * bend
	var points: Array[Vector3] = [config["mount"], hip, knee, ankle, ankle + (config["foot_vector"] as Vector3)]
	var result := {"reachable": float(config["margin"]) >= -0.001,
		"spatial_points": points, "spatial_lengths": lengths.duplicate(), "margin": config["margin"],
		"coxa_yaw": config["yaw"], "coxa_pitch": config["pitch"]}
	for i in range(POINT_NAMES.size()):
		result[POINT_NAMES[i]] = project(points[i])
	return result
