class_name RopeChain
extends RefCounted
## 한쪽 끝이 고정된 줄의 절차적 물리 (버렛 체인). 2026-09-22.
##
## 원래 끊긴 전선(BrokenWire)에만 있던 코드를 꺼내 공용으로 만든 것이다. 지금은
##   · BrokenWire  — 천장에서 늘어져 빠지직거리는 전선
##   · LampLight   — 천장 램프를 매단 전선 (쏘면 크게 흔들린다)
## 이 둘이 같은 물리를 쓴다.
##
## 적분은 버렛이다: 위치 두 개(현재·직전)만 들고 속도는 그 차이로 암시한다. 그래서 "밀기"는
## **_prev 를 반대로 옮기는** 방식이다 (kick·apply_shot). 길이 제약은 반복해서 당겨 수렴시킨다.
##
## 좌표는 전부 **월드**다. 노드에 붙지 않으므로 anchor 를 매 프레임 넣어 주면 고정점이 따라 움직인다.

const DEFAULT_GRAVITY := 1900.0
const DEFAULT_DAMPING := 0.986
const DEFAULT_ITERATIONS := 5

var segments := 12
var length := 200.0
var floor_y := 486.0
var gravity := DEFAULT_GRAVITY
var damping := DEFAULT_DAMPING
var iterations := DEFAULT_ITERATIONS
## 미풍. 끝으로 갈수록 크게 먹는다 — 이것 때문에 줄이 가만히 있지 않는다.
var wind_amp := 26.0
var wind_amp2 := 9.0
## 바깥에서 들어오는 충격(스친 총알·몸·방전)에 얼마나 민감한가. 무거운 물건일수록 낮춘다.
## 램프처럼 무게가 있는 것에 전선과 같은 값을 주면 총알이 지나갈 때마다 요란하게 출렁인다.
var impulse_scale := 1.0

var anchor := Vector2.ZERO
var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _seg := 0.0
var _t := 0.0
var _phase := 0.0


## tilt / slack 은 **시작 자세**다.
##   전선처럼 늘어져 흔들리는 것은 비스듬히(tilt) 조금 짧게(slack<1) 시작해 바로 살아 움직이게 하고,
##   램프처럼 매달린 것은 tilt 0 · slack 1 로 **완전히 정지한 평형 상태**에서 시작한다.
##   (슬랙을 주면 첫 프레임에 길이 제약이 확 당기면서 방에 들어서자마자 출렁인다 — 램프에서는 그게 버그로 보인다.)
func setup(anchor_pos: Vector2, rope_length: float, seg_count: int, floor_line: float,
		tilt := 6.0, slack := 0.97) -> void:
	anchor = anchor_pos
	length = rope_length
	segments = maxi(seg_count, 1)
	floor_y = floor_line
	_seg = length / float(segments)
	_phase = randf() * TAU
	_pts.resize(segments + 1)
	_prev.resize(segments + 1)
	for i in range(segments + 1):
		var p := anchor + Vector2(i * tilt * signf(sin(_phase)), i * _seg * slack)
		_pts[i] = p
		_prev[i] = p          # prev == pts 라 시작 속도는 0


func points() -> PackedVector2Array:
	return _pts


func tip() -> Vector2:
	return _pts[segments]


## 끝 마디가 향하는 각도 (똑바로 아래가 0, 오른쪽으로 기울면 +). Node2D.rotation 에 그대로 넣으면 된다
## — 2D 는 y 가 아래라 시계 방향이 +이고, 오른쪽으로 벌어진 줄의 회전도 시계 방향이다.
func tip_angle() -> float:
	var d := _pts[segments] - _pts[maxi(segments - 1, 0)]
	if d.length_squared() < 0.0001:
		return 0.0
	return atan2(d.x, d.y)


## 줄 전체를 한 방향으로 민다 (끝일수록 세게). 총에 맞았을 때처럼 크게 흔들 때.
func kick(impulse: Vector2) -> void:
	for i in range(1, segments + 1):
		_prev[i] -= impulse * (float(i) / segments) / 60.0


## 끝점 하나만 민다 (방전 반동처럼 작은 충격). impulse 방향으로 움직인다.
func nudge_tip(impulse: Vector2) -> void:
	_prev[segments] -= impulse * impulse_scale / 60.0


## 총알 궤적(from→to)이 스치면 그 방향으로 튀고, 탄착점 충격파가 가까우면 밀린다
func apply_shot(from: Vector2, to: Vector2, graze := 30.0, blast := 240.0) -> void:
	var dirv := (to - from).normalized()
	for i in range(1, segments + 1):
		var p := _pts[i]
		var d := _dist_to_segment(p, from, to)
		if d < graze:
			_prev[i] -= dirv * randf_range(380.0, 620.0) * impulse_scale * (1.0 - d / graze) / 60.0
		var dd := p.distance_to(to)
		if dd < blast:
			var away := (p - to).normalized()
			_prev[i] -= away * 320.0 * impulse_scale * (1.0 - dd / blast) / 60.0


## 몸이 지나가며 밀친다. pos: 발 위치, vel_x: 이동 속도
func apply_body(pos: Vector2, vel_x: float) -> void:
	if absf(vel_x) < 40.0:
		return
	for i in range(1, segments + 1):
		var p := _pts[i]
		if absf(p.x - pos.x) < 40.0 and p.y > pos.y - 330.0 and p.y < pos.y + 4.0:
			_prev[i].x -= vel_x * 0.9 * impulse_scale / 60.0
			_prev[i].y += 60.0 * impulse_scale / 60.0


## 한 스텝. clamp_floor 가 false 면 바닥을 통과할 수 있다 (천장 램프처럼 바닥에 닿을 일이 없는 줄).
func step(delta: float, clamp_floor := true) -> void:
	# 버렛은 속도를 (현재-직전) 으로만 들고 있어서 dt 가 갑자기 커지면 그만큼 에너지가 들어온다.
	# 방을 조립하는 프레임처럼 한 번 끊길 때 줄이 튀는 것을 막는다.
	delta = minf(delta, 1.0 / 30.0)
	_t += delta
	var wind := sin(_t * 0.7 + _phase) * wind_amp + sin(_t * 2.3 + _phase * 1.7) * wind_amp2
	for i in range(1, segments + 1):
		var p := _pts[i]
		var v := (p - _prev[i]) * damping
		var w := wind * float(i) / segments
		_prev[i] = p
		_pts[i] = p + v + Vector2(w, gravity) * delta * delta
	for _k in range(iterations):
		_pts[0] = anchor
		for i in range(segments):
			var a := _pts[i]
			var b := _pts[i + 1]
			var d := b - a
			var dist := maxf(d.length(), 0.001)
			var diff := (dist - _seg) / dist
			if i == 0:
				_pts[i + 1] = b - d * diff
			else:
				_pts[i] = a + d * diff * 0.5
				_pts[i + 1] = b - d * diff * 0.5
		if clamp_floor:
			for i in range(1, segments + 1):
				if _pts[i].y > floor_y - 2.0:
					_pts[i].y = floor_y - 2.0


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1.0), 0.0, 1.0)
	return p.distance_to(a + ab * t)
