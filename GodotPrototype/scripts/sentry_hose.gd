class_name SentryHose
extends Node2D
## 센트리건 급탄 호스 — 양 끝이 고정된 Verlet 체인.
##
## 원본 그림에서는 호스가 머리에 그려져 있어서 포신을 조금만 들어도 호스가 몸체 위로 넘어가 깨졌다.
## (그래서 부앙각을 ±26° 로 묶어 둬야 했다.) 그림에서 호스를 떼어내고(Tools/build_sentry_turret_parts.py)
## 여기서 물리 체인으로 다시 그리면, 포신을 +75° 까지 들어올려도 호스가 늘어나는 것처럼 읽힌다.
##
## 좌표는 부모(_flip) 로컬 — 좌우 반전도 부모를 따라간다. 양 끝(머리 물림쇠 · 받침 스터브)은
## SentryTurret 이 매 프레임 넣어 주고, 가운데 마디만 중력·감쇠로 늘어진다.
## 그림은 원본 호스에서 뽑은 색으로: 검은 외곽 → 몸통 → 한 마디 걸러 놋쇠 링.

const SEGMENTS := 12
const ITERATIONS := 8
const GRAVITY := 1500.0            # 로컬 px/s² (부모 스케일 안)
const DAMPING := 0.90
const SLACK := 1.8                 # 양 끝 직선 거리 대비 호스 길이 배율 (늘어짐)
const MIN_REST := 11.0             # 마디 최소 길이 (× SEGMENTS = 정지 자세 호스 길이)

## 색은 원본 호스 픽셀에서 뽑되 LIT_MUL 을 곱해 둔다 — 주변 스프라이트는 조명 셰이더로 어두워지는데
## 이 선은 직접 그리는 것이라 원본 값 그대로 쓰면 혼자 밝게 뜬다.
const LIT_MUL := 0.55
const OUTLINE := Color(0.07, 0.07, 0.10)
const BODY := Color(0.35, 0.30, 0.28) * LIT_MUL
const BRASS := Color(0.63, 0.51, 0.36) * LIT_MUL
const WIDTH := 24.0                # 외곽 포함 두께 (로컬 px — 원본 호스와 같은 굵기)

var _pts := PackedVector2Array()
var _prev := PackedVector2Array()
var _rest := 20.0


func _ready() -> void:
	_pts.resize(SEGMENTS + 1)
	_prev.resize(SEGMENTS + 1)


## 양 끝 사이를 늘어진 곡선으로 초기화 (전개 직후 튀지 않게)
func reset(head: Vector2, base: Vector2) -> void:
	var sag := head.distance_to(base) * 0.55 + 40.0
	for i in range(SEGMENTS + 1):
		var t := float(i) / float(SEGMENTS)
		var p := head.lerp(base, t)
		p.y += sin(t * PI) * sag                      # 아래로 처진 고리
		p.x -= sin(t * PI) * sag * 0.35               # 살짝 바깥(총 반대쪽)으로
		_pts[i] = p
		_prev[i] = p
	_update_rest(head, base)
	queue_redraw()


func _update_rest(head: Vector2, base: Vector2) -> void:
	_rest = maxf(head.distance_to(base) * SLACK, MIN_REST * SEGMENTS) / float(SEGMENTS)


## 매 프레임 SentryTurret 이 호출한다. head/base 는 이 노드의 로컬 좌표.
func update_chain(head: Vector2, base: Vector2, delta: float) -> void:
	if delta <= 0.0 or _pts.size() != SEGMENTS + 1:
		return
	_update_rest(head, base)
	for i in range(SEGMENTS + 1):
		var p := _pts[i]
		var v := (p - _prev[i]) * DAMPING
		_prev[i] = p
		_pts[i] = p + v + Vector2(0.0, GRAVITY) * delta * delta
	for _k in range(ITERATIONS):
		_pts[0] = head
		_pts[SEGMENTS] = base
		for i in range(SEGMENTS):
			var a := _pts[i]
			var b := _pts[i + 1]
			var d := b - a
			var dist := maxf(d.length(), 0.001)
			var corr := (dist - _rest) / dist
			if i == 0:
				_pts[i + 1] = b - d * corr
			elif i == SEGMENTS - 1:
				_pts[i] = a + d * corr
			else:
				_pts[i] = a + d * corr * 0.5
				_pts[i + 1] = b - d * corr * 0.5
	_pts[0] = head
	_pts[SEGMENTS] = base
	queue_redraw()


## 발사 반동 — 호스가 한 번 출렁인다
func kick(impulse: Vector2) -> void:
	for i in range(1, SEGMENTS):
		var w := sin(float(i) / float(SEGMENTS) * PI)     # 가운데가 가장 크게
		_prev[i] -= impulse * w


func _draw() -> void:
	if _pts.size() != SEGMENTS + 1:
		return
	var pts := _pts
	# 검은 외곽 → 몸통 (한 줄로 이어 그린다)
	draw_polyline(pts, OUTLINE, WIDTH, false)
	draw_polyline(pts, BODY, WIDTH - 7.0, false)
	# 마디마다 놋쇠 링 — 원본의 주름진 호스 느낌
	for i in range(SEGMENTS):
		var a := pts[i]
		var b := pts[i + 1]
		var mid := (a + b) * 0.5
		var n := (b - a).normalized().orthogonal() * (WIDTH - 9.0) * 0.5
		draw_line(mid - n, mid + n, BRASS, 5.0)
