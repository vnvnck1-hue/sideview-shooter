extends RefCounted
## 사격 반동을 실제 마우스 포인터에 준다 (Viewport.warp_mouse).
##  - 한 발마다 포인터가 사방 랜덤 방향으로 튄다 (위쪽 편향 없음). 연속 두 발이 같은 쪽으로 몰리지 않게 직전 방향에서 최소 60° 벌린다.
##  - 연사할수록 heat 가 쌓여 튀는 거리가 커진다 (heat 는 쏘지 않으면 빠르게 식는다).
##  - 튄 양의 일부(RECOVER_FRACTION)는 짧은 시간에 되돌아오고, 나머지는 남아 플레이어가 직접 끌어내려야 한다.
##  - 포인터 자체에 잔떨림은 주지 않는다: warp 는 정수 픽셀로 반올림되어 왕복 오프셋이 상쇄되지 않고 옆으로 흐른다.
##    잔떨림은 카메라 흔들림(GameCamera.add_shake)·조준점 벌어짐(Crosshair.kick)이 맡는다.
## (class_name 없이 preload 로 쓴다)

const KICK_PX := 21.0              # 한 발 기본 거리 (화면 px, 1600x900 기준) — 14 에서 50% 강화
const KICK_JITTER := 0.35          # 거리 랜덤 폭 (±비율)
const KICK_GROWTH := 0.45          # heat 1.0 당 거리 배율 증가
const MIN_TURN := PI / 3.0         # 직전 방향과 최소 각도 차 — 사방으로 퍼지게
const HEAT_PER_SHOT := 0.25
const HEAT_MAX := 3.0
const HEAT_DECAY := 1.8            # 초당 식는 양
const RECOVER_FRACTION := 0.55     # 튄 양 중 자동으로 되돌아오는 비율
const RECOVER_SPEED := 14.0        # 복귀 보간 속도 (클수록 빨리 돌아옴)

var heat := 0.0
var _pending := Vector2.ZERO       # 이번 프레임에 적용할 즉시 이동
var _recover := Vector2.ZERO       # 아직 되돌아올 남은 양
var _last_angle := NAN


## 한 발 발사. 방향은 사방 랜덤 (직전 방향과 MIN_TURN 이상 떨어지게), 거리는 heat 에 비례
func kick(_side_bias: float = 0.0) -> void:
	var ang := randf() * TAU
	if not is_nan(_last_angle):
		var diff := absf(angle_difference(_last_angle, ang))
		if diff < MIN_TURN:
			ang = _last_angle + signf(angle_difference(_last_angle, ang) + 1e-4) * randf_range(MIN_TURN, PI)
	_last_angle = ang
	var dist := KICK_PX * (1.0 + heat * KICK_GROWTH) * randf_range(1.0 - KICK_JITTER, 1.0 + KICK_JITTER)
	var d := Vector2.from_angle(ang) * dist
	_pending += d
	_recover -= d * RECOVER_FRACTION
	heat = minf(heat + HEAT_PER_SHOT, HEAT_MAX)


## 매 프레임. 포인터를 실제로 옮긴다 (뷰포트 좌표, 화면 밖으로는 안 나가게 클램프)
func tick(vp: Viewport, delta: float) -> void:
	heat = maxf(heat - HEAT_DECAY * delta, 0.0)
	var move := _pending
	_pending = Vector2.ZERO
	# 복귀: 남은 양을 지수적으로 소진
	if _recover.length_squared() > 0.01:
		var step := _recover * minf(1.0, RECOVER_SPEED * delta)
		_recover -= step
		move += step
	else:
		_recover = Vector2.ZERO

	if move.length_squared() < 0.01:
		return
	var rect := vp.get_visible_rect()
	var target := vp.get_mouse_position() + move
	target.x = clampf(target.x, rect.position.x + 2.0, rect.end.x - 2.0)
	target.y = clampf(target.y, rect.position.y + 2.0, rect.end.y - 2.0)
	vp.warp_mouse(target)
