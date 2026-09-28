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
const MARGIN_MEMO_MAX := 192     # 다리 하나가 기억하는 margin 질문 수. 넘치면 통째로 비운다 (최근 몇 프레임 분량)


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


## ## 할당 없는 탐색 (2026-09-28 최적화)
## margin() 한 번이 피치 후보 최대 28개 × 요 후보 ~12개를 평가한다. 예전에는 후보마다 Dictionary 를 만들고
## (hip 벡터·비용·여유) 배열 리터럴을 돌았는데, 보행 판정이 서브스텝마다 margin 을 수십 번 불러
## 버그봇 한 대가 프레임당 ~5ms 를 썼다 (버그봇 전투 렉의 65%). 지금은 같은 식을 **같은 순서**로 계산하되
## 최선 후보를 스칼라로만 들고 다니고, hip 벡터는 마지막에 한 번만 만든다. 결과는 비트 단위로 같다
## (tools/trace_determinism.gd 로 전후 궤적을 비교).
static var _c_margin := 0.0
static var _h_yaw := 0.0
static var _h_margin := 0.0
static var _b_yaw := 0.0
static var _b_pitch := 0.0
static var _b_margin := 0.0
static var _b_cost := 0.0
static var _yaw_buf := _make_yaw_buf()     # 요 후보 버퍼 (최대 4 + 4×2 = 12)


static func _make_yaw_buf() -> PackedFloat64Array:
	var b := PackedFloat64Array()
	b.resize(12)
	return b


## 한 후보의 비용. 여유(clearance)는 _c_margin 으로 돌려준다.
## d* = ankle - mount (float32 Vector3 성분 그대로), base = |d|² + length².
static func _cost(dx: float, dy: float, dz: float, base: float, length: float, yaw: float,
		sin_p: float, cos_p: float, preferred_yaw: float, pitch_cost: float, upper: float, lower: float,
		reserve: float) -> float:
	# Godot Vector3는 float32다. 거의 같은 후보의 비용은 float64 스칼라로 비교해야
	# 완전 신전 부근의 반올림 오차가 후보 순서를 뒤집지 않는다.
	var dot := dy * sin_p + cos_p * (dx * cos(yaw) + dz * sin(yaw))
	var distance := sqrt(maxf(base - 2.0 * length * dot, 0.0))
	var clearance := _signed_margin(distance, upper, lower)
	var angular_cost := pow(wrapf(yaw - preferred_yaw, -PI, PI), 2.0) + pitch_cost
	_c_margin = clearance
	# 닿는 해를 우선하고 그 안에서 원래 관절 방향에 가장 가까운 해를 선택한다.
	# 여유가 있을 때 완전 신전/접힘에 붙지 않아 무릎의 sqrt 특이점을 예방한다.
	return angular_cost + pow(maxf(-clearance, 0.0), 2.0) * 100.0 + pow(maxf(reserve - clearance, 0.0), 2.0) * COMFORT_WEIGHT


## 한 피치에서 가장 좋은 요를 찾는다. 반환값 = 비용, 요·여유는 _h_yaw · _h_margin.
## 후보 평가 순서(선호 요 → 하한 → 상한 → 목표 → 구면 교점 → 연속 최솟값)와 엄격한 < 비교는 예전 그대로다.
static func _hip_at_pitch_cost(dx: float, dy: float, dz: float, base: float, horizontal: float,
		target_yaw: float, length: float, pitch: float, rest_yaw: float, preferred_yaw: float,
		rest_pitch: float, upper: float, lower: float, yaw_limit: float) -> float:
	var yaw_min := rest_yaw - yaw_limit
	var yaw_max := rest_yaw + yaw_limit
	var sin_p := sin(pitch)
	var cos_p := cos(pitch)
	var pitch_cost := pow(pitch - rest_pitch, 2.0) * 1.5
	var reserve := minf(COMFORT_MARGIN, minf(upper, lower) * 0.5)
	var radius := length * cos_p
	var vertical := dy - length * sin_p
	# 요 후보를 평가 순서대로 모은다: 선호 요 → 하한 → 상한 → 목표 → 구면 교점.
	# (배열은 정적 버퍼를 다시 쓴다 — 후보마다 배열·사전을 만들지 않는다)
	_yaw_buf[0] = preferred_yaw
	_yaw_buf[1] = yaw_min
	_yaw_buf[2] = yaw_max
	_yaw_buf[3] = clampf(target_yaw, yaw_min, yaw_max)
	var n := 4
	if horizontal * radius > EPS:
		# 두 마디의 최소/최대 도달 구면과 coxa 원의 교점. 0.02 여유로 특이점을 피한다.
		for ri in 4:
			var reach: float
			match ri:
				0: reach = absf(upper - lower) + 0.02
				1: reach = upper + lower - 0.02
				2: reach = absf(upper - lower) + reserve + EPS
				_: reach = upper + lower - reserve - EPS
			var cosine: float = (horizontal * horizontal + radius * radius + vertical * vertical - reach * reach) / (2.0 * horizontal * radius)
			if cosine < -1.0 or cosine > 1.0:
				continue
			var spread := acos(clampf(cosine, -1.0, 1.0))
			_yaw_buf[n] = clampf(rest_yaw + wrapf(target_yaw + spread * -1.0 - rest_yaw, -PI, PI), yaw_min, yaw_max)
			_yaw_buf[n + 1] = clampf(rest_yaw + wrapf(target_yaw + spread * 1.0 - rest_yaw, -PI, PI), yaw_min, yaw_max)
			n += 2
	var best_cost := INF
	var best_yaw := 0.0
	var best_margin := 0.0
	var two_length := 2.0 * length
	for i in n:
		var yaw: float = _yaw_buf[i]
		# ── 후보 비용 (예전 _candidate 와 같은 식, 같은 순서) ──
		# Godot Vector3는 float32다. 거의 같은 후보의 비용은 float64 스칼라로 비교해야
		# 완전 신전 부근의 반올림 오차가 후보 순서를 뒤집지 않는다.
		var dot := dy * sin_p + cos_p * (dx * cos(yaw) + dz * sin(yaw))
		var distance := sqrt(maxf(base - two_length * dot, 0.0))
		var clearance := minf(distance - absf(upper - lower) - EPS, upper + lower - EPS - distance)
		# 닿는 해를 우선하고 그 안에서 원래 관절 방향에 가장 가까운 해를 선택한다.
		# 여유가 있을 때 완전 신전/접힘에 붙지 않아 무릎의 sqrt 특이점을 예방한다.
		var cost := pow(wrapf(yaw - preferred_yaw, -PI, PI), 2.0) + pitch_cost + pow(maxf(-clearance, 0.0), 2.0) * 100.0 + pow(maxf(reserve - clearance, 0.0), 2.0) * COMFORT_WEIGHT
		# i == 0 은 예전의 "best 초기값" 이다 (그다음부터 엄격한 < 로만 바뀐다)
		if i == 0 or cost < best_cost:
			best_cost = cost
			best_yaw = yaw
			best_margin = clearance
	# 구면 교점과 선호 방향 사이에도 더 좋은 해가 있다. 이 연속 최솟값을 놓치면
	# 도달 경계에서 두 이산 후보가 교대하며 coxa가 작은 입력에도 갑자기 뛴다.
	var low := minf(best_yaw, preferred_yaw)
	var high := maxf(best_yaw, preferred_yaw)
	if high - low > 0.00001:
		var minimum := absf(upper - lower) + EPS
		var maximum := upper + lower - EPS
		var product := horizontal * radius
		var constant := horizontal * horizontal + radius * radius + vertical * vertical
		if _yaw_derivative(low, preferred_yaw, target_yaw, product, constant, minimum, maximum) <= 0.0 and _yaw_derivative(high, preferred_yaw, target_yaw, product, constant, minimum, maximum) >= 0.0:
			# _yaw_derivative 를 풀어 쓴 이분 탐색 (식·순서 동일)
			var two_product := 2.0 * product
			var d_reserve := minf(COMFORT_MARGIN, (maximum - minimum) * 0.25)
			var comfort_lo := minimum + d_reserve
			var comfort_hi := maximum - d_reserve
			for _iteration in range(14):
				var middle := (low + high) * 0.5
				var dd := sqrt(maxf(constant - two_product * cos(middle - target_yaw), EPS * EPS))
				var outside := dd - clampf(dd, minimum, maximum)
				var comfort := dd - clampf(dd, comfort_lo, comfort_hi)
				if 2.0 * (middle - preferred_yaw) + (200.0 * outside + 2.0 * COMFORT_WEIGHT * comfort) * product * sin(middle - target_yaw) / dd < 0.0:
					low = middle
				else:
					high = middle
			var mid_yaw := (low + high) * 0.5
			var c := _cost(dx, dy, dz, base, length, mid_yaw, sin_p, cos_p, preferred_yaw, pitch_cost, upper, lower, reserve)
			if c < best_cost:
				best_cost = c
				best_yaw = mid_yaw
				best_margin = _c_margin
	_h_yaw = best_yaw
	_h_margin = best_margin
	return best_cost


static func _yaw_derivative(yaw: float, preferred: float, target: float, product: float,
		constant: float, minimum: float, maximum: float) -> float:
	var distance := sqrt(maxf(constant - 2.0 * product * cos(yaw - target), EPS * EPS))
	var outside := distance - clampf(distance, minimum, maximum)
	var reserve := minf(COMFORT_MARGIN, (maximum - minimum) * 0.25)
	var comfort := distance - clampf(distance, minimum + reserve, maximum - reserve)
	return 2.0 * (yaw - preferred) + (200.0 * outside + 2.0 * COMFORT_WEIGHT * comfort) * product * sin(yaw - target) / distance


## 최선의 coxa 자세를 스칼라로 찾는다 → _b_yaw · _b_pitch · _b_margin · _b_cost. 반환값 = rest_yaw.
static func _choose_hip_scalar(state: Dictionary, mount: Vector3, rest_hip: Vector3, ankle: Vector3) -> float:
	var lengths: Array = state["lengths"]
	var length: float = lengths[0]
	var upper: float = lengths[1]
	var lower: float = lengths[2]
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
	# 피치와 무관한 값은 한 번만 계산한다 — 예전엔 후보마다 다시 뺐지만 입력이 같아 값도 같다.
	var dx: float = toward.x
	var dy: float = toward.y
	var dz: float = toward.z
	var base := dx * dx + dy * dy + dz * dz + length * length
	var horizontal := Vector2(toward.x, toward.z).length()
	var hip_target_yaw := rest_yaw + wrapf(atan2(toward.z, toward.x) - rest_yaw, -PI, PI)
	var best_cost := _hip_at_pitch_cost(dx, dy, dz, base, horizontal, hip_target_yaw, length, preferred_pitch,
		rest_yaw, preferred_yaw, preferred_pitch, upper, lower, yaw_limit)
	var best_yaw := _h_yaw
	var best_pitch := preferred_pitch
	var best_margin := _h_margin
	if best_margin >= minf(COMFORT_MARGIN, minf(upper, lower) * 0.5) and absf(best_yaw - preferred_yaw) < 0.0001:
		_b_yaw = best_yaw
		_b_pitch = best_pitch
		_b_margin = best_margin
		_b_cost = best_cost
		return rest_yaw
	# 13 + 7 회면 최종 정밀도가 관절 범위의 1/1536 (60도 범위에서 0.04도) 이다.
	# 17 + 11 회는 그림에 드러나지도 않는 자릿수를 위해 IK 를 40회 가까이 돌렸다.
	# 가지치기: 한 피치의 어떤 후보도 비용이 그 피치 항(1.5·(pitch−rest)²)보다 작을 수 없다 — 나머지 항은 모두 0 이상이고
	# 0 이상끼리의 부동소수 덧셈은 줄어들지 않는다. 그 항만으로 이미 최선 이상이면 엄격한 < 비교를 절대 통과하지 못하므로
	# 그 피치는 풀지 않고 건너뛴다. (결과는 전부 풀었을 때와 같다)
	for i in range(13):
		var pitch := lerpf(pitch_min, pitch_max, float(i) / 12.0)
		if pow(pitch - preferred_pitch, 2.0) * 1.5 >= best_cost:
			continue
		var c := _hip_at_pitch_cost(dx, dy, dz, base, horizontal, hip_target_yaw, length, pitch,
			rest_yaw, preferred_yaw, preferred_pitch, upper, lower, yaw_limit)
		if c < best_cost:
			best_cost = c
			best_yaw = _h_yaw
			best_pitch = pitch
			best_margin = _h_margin
	# 피치 후보 사이를 더 잘게 탐색하여 후보 전환에 따른 각도 차이를 줄인다.
	var radius := (pitch_max - pitch_min) / 12.0
	for _pass in range(7):
		var center := best_pitch
		for di in 2:
			var pitch := clampf(center + radius * (-1.0 if di == 0 else 1.0), pitch_min, pitch_max)
			if pow(pitch - preferred_pitch, 2.0) * 1.5 >= best_cost:
				continue
			var c := _hip_at_pitch_cost(dx, dy, dz, base, horizontal, hip_target_yaw, length, pitch,
				rest_yaw, preferred_yaw, preferred_pitch, upper, lower, yaw_limit)
			if c < best_cost:
				best_cost = c
				best_yaw = _h_yaw
				best_pitch = pitch
				best_margin = _h_margin
		radius *= 0.5
	_b_yaw = best_yaw
	_b_pitch = best_pitch
	_b_margin = best_margin
	_b_cost = best_cost
	return rest_yaw


static func _choose_hip(state: Dictionary, mount: Vector3, rest_hip: Vector3, ankle: Vector3) -> Dictionary:
	var rest_yaw := _choose_hip_scalar(state, mount, rest_hip, ankle)
	var length: float = (state["lengths"] as Array)[0]
	return {"hip": mount + _spherical(length, _b_yaw, _b_pitch), "yaw": _b_yaw, "pitch": _b_pitch,
		"margin": _b_margin, "cost": _b_cost, "yaw_delta": _b_yaw - rest_yaw}


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
	# 같은 입력의 질문이 한 프레임 안팎에서 자주 되풀이된다 (지지 판정의 "이전 몸" = 직전 서브스텝의 "지금 몸",
	# 반동 이분 탐색, 착지 확인 — 실측 호출의 ~40%). margin 은 입력만의 순수 함수이므로 입력 전부(관절 설정 각 포함)를
	# 키로 기억해 둔다. 값이 바뀔 여지가 없으니 결과는 그대로다.
	var config: Dictionary = state.get("config", {})
	var key := [body_pos, body_angle, contact, config.get("yaw_limit"), config.get("pitch_limit"),
		config.get("coxa_yaw_bias"), config.get("coxa_pitch_bias")]
	var memo: Dictionary = state.get("_margin_memo", {})
	if memo.is_empty():
		state["_margin_memo"] = memo
	var hit = memo.get(key)
	if hit != null:
		return hit
	if memo.size() >= MARGIN_MEMO_MAX:
		memo.clear()
	# _configuration(swing 0) 과 같은 입력으로 스칼라 탐색만 — 사전·hip 벡터를 만들지 않는다.
	var rest: Array = state["rest3d"]
	var translation := Vector3(body_pos.x, body_pos.y, 0.0)
	var mount := _pitch(rest[0], body_angle) + translation
	var rest_hip := _pitch(rest[1], body_angle) + translation
	var foot: Vector3 = state["foot_vector"]
	var ankle := inverse(contact, float(state["rest_z"])) - foot
	_choose_hip_scalar(state, mount, rest_hip, ankle)
	memo[key] = _b_margin
	return _b_margin


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
