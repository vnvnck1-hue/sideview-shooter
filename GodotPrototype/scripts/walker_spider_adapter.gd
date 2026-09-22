extends RefCounted
## In-game adapter: saved image landmarks -> the shared spatial spider solver.
## The legacy art faces right and has its own image origin. Only this adapter mirrors
## and scales source points; projected solver endpoints are never projected twice.
const IK = preload("res://scripts/spider_leg_ik.gd")
const Anatomy = preload("res://scripts/walker_anatomy.gd")
const Authoring = preload("res://scripts/walker_authoring_data.gd")
const GaitSettings = preload("res://scripts/walker_gait_settings.gd")
const IDS := ["FR", "FF", "NR", "NF"] # Stable legacy far/back, far/front, near/back, near/front order.
const PARTS := ["mount", "hip", "knee", "ankle", "toe"]
const STANDING_HEIGHT := 182.0
## 딛고 있는 발이 남겨야 할 여유. 이 아래로는 다리가 몸을 붙잡아 걸음이 끌린다.
const TRAVEL_RESERVE := 6.0
## 스텝을 아무리 당겨도 이보다 짧게는 만들지 않는다 (발이 보이지 않게 떨린다).
const MIN_STEP_TIME := 0.05
## 잰 범위 중 걸음이 실제로 쓸 수 있는 몫. 나머지는 착지 예측(lead)과 달릴 때의 몸 기울기가 먹는다.
## 실측으로 맞춘 값이다. 이 몫이면 달릴 때 접지 여유가 10px 이상 남고 설정한 최고 속도가 그대로 나온다
## (0.45 는 여유 1px 에 붙어 다리가 몸을 붙잡았고 최고 속도가 765 에서 678 로 깎였다).
const TRAVEL_SHARE := 0.35

var points: Dictionary = {}
var definitions: Dictionary = {}
var loaded_path := ""
var standing_height := STANDING_HEIGHT
var _front_depth := 0.0
var _group := 0
var _wait := 0.0
var _crawl_index := 0
var _last_hold := 0.015
var _defaults: Dictionary = GaitSettings.defaults()
var _travel := 0.0                # 한 발이 붙어 있는 동안 몸이 지날 수 있는 거리 (px). 다리 범위에서 직접 잰다.
var _travel_key := ""             # 그 값을 잰 조건. 설정이 바뀌면 다시 잰다.


func configure(path: String) -> void:
	var document := Authoring.new()
	if FileAccess.file_exists(path) and document.load_file(path) == OK:
		loaded_path = path
	points = document.points.duplicate(true)
	definitions.clear()
	_front_depth = 0.0
	for id in IDS:
		var definition := {"id": id, "far": id.begins_with("F")}
		for part in PARTS:
			definition["ref_" + part] = source_to_rig(points[id + "." + part])
		# Every corrected toe is its own stance hint. Only the untouched, lifted source FR
		# uses its explicit default ground hint; never add that offset to an edited foot.
		definition["rest_toe"] = definition["ref_toe"]
		for source in Anatomy.LEGS:
			if source["id"] != id or not source.has("ground_toe"):
				continue
			var unchanged := true
			for part in PARTS:
				unchanged = unchanged and (points[id + "." + part] as Vector2).is_equal_approx(source[part])
			if unchanged:
				definition["rest_toe"] = source_to_rig(source["ground_toe"])
		definitions[id] = IK.build(definition, STANDING_HEIGHT)
		_front_depth = maxf(_front_depth, float(definitions[id]["depth"]))
	standing_height = STANDING_HEIGHT + _front_depth


static func source_to_rig(raw: Vector2) -> Vector2:
	var point := Anatomy.local_point(raw) * (STANDING_HEIGHT / Anatomy.ground_level())
	return Vector2(-point.x, point.y)


func reset(walker: Node2D) -> void:
	_group = 0
	_wait = 0.0
	_crawl_index = 0
	_last_hold = _value(walker, "hold")
	walker._legs.clear()
	for id in IDS:
		var state: Dictionary = definitions[id]
		var stance: Vector2 = state["stance"]
		var far: bool = id.begins_with("F")
		var leg := {"id": id, "name": id, "near": not far, "far": far,
			"group": 0 if id in ["FF", "NR"] else 1, "side": .5 if far else -.5,
			"hip": source_to_rig(points[id + ".hip"]), "rest": stance.x,
			"foot": Vector2.ZERO, "from": Vector2.ZERO, "to": Vector2.ZERO,
			"t": 1.0, "dur": .16, "stepping": false, "lift": 0.0, "roll": 0.0, "settling": false,
			"recovering": false, "pending_land": false,
			"state": state, "pose": {}, "ground_depth": float(state["depth"]) - _front_depth}
		leg["foot"] = desired(walker, leg, 0.0)
		walker._legs.append(leg)
	solve(walker)


func desired(walker: Node2D, leg: Dictionary, lead: float) -> Vector2:
	# 사격 반동으로 밀린 몸통은 빼고 잡는다. 발 목표가 반동을 따라 움직이면 총을 쏘는 동안
	# 네 발이 계속 새 자리를 좇아 종종거린다 — 발은 버티고 몸통만 밀려야 한다.
	var x: float = walker.body_pos.x - walker.recoil_shift() + float(leg["rest"]) * _value(walker, "stride") + lead
	return Vector2(x, float(walker.ground_at.call(x)) + float(leg["ground_depth"]))


func plant(walker: Node2D) -> void:
	for leg in walker._legs:
		leg["foot"] = reachable_target(walker, leg, desired(walker, leg, 0.0), 0.0)
		leg["from"] = leg["foot"]
		leg["to"] = leg["foot"]
		leg["stepping"] = false
		leg["t"] = 1.0
	_wait = .03


## draw 가 false 면 그림용 관절 풀이를 건너뛴다. 걸음 판정은 발 위치로만 하므로 결과가 같고,
## 한 프레임에 여러 서브스텝을 도는 동안 같은 IK 를 반복해서 푸는 비용만 사라진다
## (달리기에서 이 반복이 틱당 3.6ms 를 먹었다 — 그 지연이 다시 걸음을 망가뜨렸다).
func tick(walker: Node2D, delta: float, previous_body: Vector2, previous_angle: float, draw := true) -> void:
	_sync_config(walker)
	_measure_travel(walker)
	var hold := _value(walker, "hold")
	_wait = maxf(_wait + hold - _last_hold, 0.0)
	_last_hold = hold
	_wait = maxf(_wait - delta, 0.0)
	if walker.airborne:
		for leg in walker._legs:
			var target := desired(walker, leg, float(walker.speed) * .10)
			if walker._air_v < 0:
				target.y = minf(target.y, walker.body_pos.y + float(walker.tune["ride"]) * .64)
			leg["foot"] = (leg["foot"] as Vector2).lerp(target, 1.0 - exp(-delta * 14.0))
			leg["stepping"] = false
			leg["t"] = 1.0
		solve(walker)
		return
	var active := 0
	for leg in walker._legs:
		if not leg["stepping"]:
			continue
		if not bool(leg.get("recovering", false)):
			leg["dur"] = _duration(walker)
		leg["lift"] = minf(_value(walker, "lift"), 12.0) if bool(leg.get("settling", false)) or bool(leg.get("recovering", false)) else _value(walker, "lift")
		leg["t"] = minf(float(leg["t"]) + delta / float(leg["dur"]), 1.0)
		var progress: float = leg["t"]
		var eased: float = IK.swing_ease(progress)
		var toe: Vector2 = (leg["from"] as Vector2).lerp(leg["to"], eased)
		toe.y -= sin(progress * PI) * float(leg["lift"])
		leg["foot"] = toe
		if progress >= 1.0:
			# 몸의 지지 제약을 반영한 뒤 실제 위치에서 착지 가능 여부를 확인한다.
			leg["pending_land"] = true
		active += 1
	# A spatial leg has a finite envelope. Keep support contacts fixed instead of dragging them.
	if _supports(walker, previous_body, previous_angle) and not _supports(walker, walker.body_pos, walker._angle):
		# 6회면 한 서브스텝 이동량의 1/64 — 달릴 때도 0.1px 안쪽이다. 12회는 IK 를 그만큼 더 돌 뿐
		# 눈에 보이지도 않는 자릿수를 더 맞추는 비용이었다 (달리기 부하의 가장 큰 몫이었다).
		var lower := 0.0
		var upper := 1.0
		for iteration in 6:
			var fraction := (lower + upper) * .5
			if _supports(walker, previous_body.lerp(walker.body_pos, fraction), lerpf(previous_angle, walker._angle, fraction)):
				lower = fraction
			else:
				upper = fraction
		walker.body_pos = previous_body.lerp(walker.body_pos, lower)
		walker._angle = lerpf(previous_angle, walker._angle, lower)
		walker.speed = (walker.body_pos.x - previous_body.x) / maxf(delta, .0001)
	for leg in walker._legs:
		if not bool(leg.get("pending_land", false)):
			continue
		leg["pending_land"] = false
		if IK.margin(leg["state"], walker.body_pos, walker._angle, leg["to"]) >= 1.0:
			leg["stepping"] = false
			leg["recovering"] = false
			leg["foot"] = leg["to"]
			_wait = hold
			active -= 1
		else:
			# 예측보다 몸이 덜 전진한 긴 스텝은 도달하지 못한 발을 접지로 간주하지 않는다.
			# 마지막으로 보인 발끝에서 짧은 보정 스텝을 이어가므로 발을 순간이동시키지 않는다.
			var visible_toe: Vector2 = leg["pose"].get("toe", leg["foot"])
			leg["from"] = visible_toe
			leg["foot"] = visible_toe
			leg["to"] = reachable_target(walker, leg, leg["to"], 0.0)
			leg["dur"] = clampf(visible_toe.distance_to(leg["to"]) / 240.0, .10, .35)
			leg["t"] = 0.0
			leg["recovering"] = true
	if active == 0 and _wait <= 0.0:
		var moving: bool = absf(walker.input_dir) > .01 or absf(walker.speed) > 5.0
		var trigger := _value(walker, "trigger")
		var needs_step := moving and trigger <= 0.0
		var urgent_leg: Dictionary = {}
		var least_margin := INF
		for leg in walker._legs:
			var offset: float = desired(walker, leg, 0.0).x - (leg["foot"] as Vector2).x
			var direction := signf(float(walker.speed)) if absf(walker.speed) > 1.0 else signf(float(walker.input_dir))
			var error := offset * direction if moving else (leg["foot"] as Vector2).distance_to(desired(walker, leg, 0.0))
			if error > (trigger if moving else 12.0):
				needs_step = true
			var margin: float = IK.margin(leg["state"], walker.body_pos + Vector2(walker.speed * _duration(walker), 0), walker._angle, leg["foot"])
			if margin < least_margin:
				least_margin = margin
				urgent_leg = leg
		if moving and least_margin < 4.0:
			needs_step = true
		if needs_step:
			var one_leg := _value(walker, "legs_up") < 1.5
			var chosen_id := ""
			if one_leg:
				var sequence := ["FF", "NR", "FR", "NF"]
				chosen_id = sequence[_crawl_index]
				if moving and least_margin < 4.0:
					chosen_id = String(urgent_leg["id"])
				_crawl_index = (sequence.find(chosen_id) + 1) % sequence.size()
			elif moving and trigger > 0.0 and least_margin < 4.0:
				_group = int(urgent_leg["group"])
			for leg in walker._legs:
				if (one_leg and leg["id"] != chosen_id) or (not one_leg and int(leg["group"]) != _group):
					continue
				var duration := _duration(walker)
				var lead_seconds := _value(walker, "lead")
				if walker.running:
					lead_seconds *= duration / maxf(_value(walker, "step_time"), 0.001)
				var lead: float = walker.speed * lead_seconds
				leg["from"] = leg["foot"]
				leg["to"] = reachable_target(walker, leg, desired(walker, leg, lead), walker.speed * duration)
				leg["dur"] = duration
				leg["t"] = 0.0
				leg["stepping"] = true
				leg["settling"] = not moving
				leg["recovering"] = false
				leg["lift"] = _value(walker, "lift") if moving else minf(_value(walker, "lift"), 12.0)
				walker.steps_normal += 1
			_group = 1 - _group
	if draw:
		solve(walker)


## 그 자세에서 딛고 있는 발이 몸을 버티는가. 사격 반동을 얼마나 얹을 수 있는지도 이걸로 잰다.
func supports_at(walker: Node2D, body: Vector2, angle: float) -> bool:
	return _supports(walker, body, angle)


func _supports(walker: Node2D, body: Vector2, angle: float) -> bool:
	for leg in walker._legs:
		if not leg["stepping"] and IK.margin(leg["state"], body, angle, leg["foot"]) < 1.0:
			return false
	return true


func reachable_target(walker: Node2D, leg: Dictionary, target: Vector2, prediction: float) -> Vector2:
	var body: Vector2 = walker.body_pos + Vector2(prediction, 0)
	var rest := desired(walker, leg, prediction)
	var best := target
	var margin: float = IK.margin(leg["state"], body, walker._angle, target)
	if margin >= 4.0:
		return target
	# 발 벌림이 너무 넓으면 배율 없는 원본 발 위치까지 탐색한다. 바인드는 바꾸지 않는다.
	var original_x: float = body.x + (leg["state"]["stance"] as Vector2).x
	var original := Vector2(original_x, float(walker.ground_at.call(original_x)) + float(leg["ground_depth"]))
	for anchor in [rest, original]:
		for i in range(1, 21):
			var candidate := target.lerp(anchor, i / 20.0)
			candidate.y = float(walker.ground_at.call(candidate.x)) + float(leg["ground_depth"])
			var candidate_margin: float = IK.margin(leg["state"], body, walker._angle, candidate)
			if candidate_margin > margin:
				margin = candidate_margin
				best = candidate
			if margin >= 4.0:
				return best
	return best


func solve(walker: Node2D) -> void:
	_sync_config(walker)
	for leg in walker._legs:
		leg["pose"] = IK.solve(leg["state"], walker.body_pos, walker._angle, leg["foot"], leg["t"] if leg["stepping"] else 0.0)


func _value(walker: Node2D, key: String) -> float:
	return float(walker.tune.get(key, _defaults[key]))


## 스텝 간격. 빠를 때는 설정값보다 **당긴다**.
## 한 발은 자기 차례가 돌아올 때까지 붙어 있으므로, 그동안 몸이 지나는 거리는
##   속도 × 스텝시간 × (4 / 동시에 드는 발)
## 이다. 이게 다리 범위를 넘으면 지지 판정이 매 프레임 몸을 붙잡아 걸음이 끌린다 —
## 이동 속도를 올린 뒤 달릴 때 접지 여유가 한계값(1px)에 붙어 버린 것이 그 증상이었다.
## 범위 안에 들어올 때까지만 당기므로 평소 속도에서는 설정한 걸음 그대로다.
func _duration(walker: Node2D) -> float:
	var base := _value(walker, "run_step_time" if walker.running else "step_time")
	var lifted := 1.0 if _value(walker, "legs_up") < 1.5 else 2.0
	var travel: float = absf(walker.speed) * float(IDS.size()) / lifted
	if travel < 1.0 or _travel <= 0.0:
		return base
	return clampf(_travel * TRAVEL_SHARE / travel, MIN_STEP_TIME, base)


## 발 하나를 제자리에 두고 몸을 앞뒤로 밀어 보며, 접지 여유가 남는 구간을 잰다.
## 설정(발 벌림·몸 높이·회전 범위)이 바뀔 때만 다시 잰다 — 매 프레임 돌 계산이 아니다.
func _measure_travel(walker: Node2D) -> void:
	if walker._legs.is_empty():
		return
	var key := "%.3f|%.2f|%.2f|%.2f" % [_value(walker, "stride"), _value(walker, "ride"),
		_value(walker, "yaw_limit"), _value(walker, "pitch_limit")]
	if key == _travel_key:
		return
	_travel_key = key
	var span := INF
	for leg in walker._legs:
		var foot := desired(walker, leg, 0.0)
		span = minf(span, _reach_span(walker, leg, foot, 1.0) + _reach_span(walker, leg, foot, -1.0))
	_travel = maxf(span, 40.0)


func _reach_span(walker: Node2D, leg: Dictionary, foot: Vector2, direction: float) -> float:
	var low := 0.0
	var high := 420.0
	for iteration in 9:
		var middle := (low + high) * .5
		if IK.margin(leg["state"], walker.body_pos + Vector2(direction * middle, 0.0), walker._angle, foot) >= TRAVEL_RESERVE:
			low = middle
		else:
			high = middle
	return low


func _sync_config(walker: Node2D) -> void:
	for leg in walker._legs:
		# 공유 사전 참조만 갱신한다. 라이브 각도 조정은 바인드/뼈 길이를 다시 만들지 않는다.
		leg["state"]["config"] = walker.tune
