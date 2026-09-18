class_name PowerRelayCable
extends Node2D
## 생성된 Power Relay 케이블 텍스처를 실제 처짐·충격 반응 체인에 입히는 전선.
## 끝점 하나는 천장 앵커에 고정되고, 끝점은 자유롭게 흔들리며 총알·플레이어에 반응한다.

const ROOT := "res://assets/power_relay_room/Cables/"
const SEGMENTS := 12
const GRAVITY := 1250.0
const DAMPING := 0.986
const ITERATIONS := 6

var cable_length := 260.0
var floor_y := 992.0
var _seg_length := 0.0
var _points := PackedVector2Array()
var _previous := PackedVector2Array()
var _line: Line2D
var _t := 0.0
var _phase := 0.0


func setup(length: float, floor_line: float, variant := "power_relay_cable_straight.png") -> void:
	cable_length = length
	floor_y = floor_line
	_phase = randf() * TAU
	_seg_length = cable_length / SEGMENTS
	_points.resize(SEGMENTS + 1)
	_previous.resize(SEGMENTS + 1)
	for i in range(SEGMENTS + 1):
		var p := Vector2(sin(_phase) * 18.0 * float(i) / SEGMENTS, _seg_length * float(i))
		_points[i] = p
		_previous[i] = p

	_line = Line2D.new()
	_line.width = 42.0
	_line.texture = load(ROOT + variant)
	_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.default_color = Color.WHITE
	add_child(_line)


## DustLayer 광원 계약 — 케이블은 빛을 내지 않으므로 빈 사전(건너뜀)
func light_info() -> Dictionary:
	return {}


func tip() -> Vector2:
	return global_position + _points[SEGMENTS]


func apply_shot(from: Vector2, to: Vector2) -> void:
	var shot := (to - from).normalized()
	for i in range(1, SEGMENTS + 1):
		var d := _distance_to_segment(global_position + _points[i], from, to)
		if d < 34.0:
			_previous[i] -= shot * randf_range(280.0, 520.0) / 60.0 * (1.0 - d / 34.0)
		var away := (global_position + _points[i] - to)
		if away.length() < 220.0:
			_previous[i] -= away.normalized() * 220.0 / 60.0


func apply_body(pos: Vector2, velocity_x: float) -> void:
	if absf(velocity_x) < 40.0:
		return
	for i in range(1, SEGMENTS + 1):
		var p := global_position + _points[i]
		if absf(p.x - pos.x) < 44.0 and p.y < pos.y + 10.0:
			_previous[i].x -= velocity_x * 0.75 / 60.0


func _physics_process(delta: float) -> void:
	if _line == null:
		return
	_t += delta
	var wind := sin(_t * 0.8 + _phase) * 18.0 + sin(_t * 2.1 + _phase * 1.4) * 7.0
	for i in range(1, SEGMENTS + 1):
		var p := _points[i]
		var velocity := (_points[i] - _previous[i]) * DAMPING
		_previous[i] = p
		_points[i] = p + velocity + Vector2(wind * float(i) / SEGMENTS, GRAVITY) * delta * delta
	for _k in range(ITERATIONS):
		_points[0] = Vector2.ZERO
		for i in range(SEGMENTS):
			var a := _points[i]
			var b := _points[i + 1]
			var delta_p := b - a
			var distance := maxf(delta_p.length(), 0.001)
			var correction := (distance - _seg_length) / distance
			if i == 0:
				_points[i + 1] = b - delta_p * correction
			else:
				_points[i] = a + delta_p * correction * 0.5
				_points[i + 1] = b - delta_p * correction * 0.5
		for i in range(1, SEGMENTS + 1):
			var world_y := global_position.y + _points[i].y
			if world_y > floor_y - 4.0:
				_points[i].y = floor_y - global_position.y - 4.0
	_line.points = _points


static func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
	return p.distance_to(a + ab * t)
