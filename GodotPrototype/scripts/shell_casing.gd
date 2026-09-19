class_name ShellCasing
extends Node2D
## 탄피. 사격 시 총 배출구에서 위·뒤로 튀어 올라 회전하며 떨어지고, 바닥에서 몇 번 튕긴 뒤 사라진다.

const GRAVITY := 3200.0
const BOUNCE := 0.42
const FRICTION := 0.75
const LIFE := 1.6
const FADE := 0.35
const SIZE := Vector2(18, 7)

var vel := Vector2.ZERO
var spin := 0.0
var floor_y := 0.0
var _t := 0.0
var _wet := false                 # 고인 물에 한 번 첨벙
var _rect: ColorRect
var _shine: ColorRect


func setup(pos: Vector2, dir: int, floor_line: float) -> void:
	position = pos
	floor_y = floor_line
	# 바라보는 반대쪽(뒤)·위로 튄다
	vel = Vector2(-dir * randf_range(260.0, 560.0), -randf_range(800.0, 1150.0))
	spin = -dir * randf_range(14.0, 26.0)
	rotation = randf_range(0.0, TAU)


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.color = Color(0.86, 0.66, 0.24)
	_rect.size = SIZE
	_rect.position = -SIZE * 0.5
	add_child(_rect)
	_shine = ColorRect.new()
	_shine.color = Color(1.0, 0.9, 0.55)
	_shine.size = Vector2(5, SIZE.y)
	_shine.position = Vector2(SIZE.x * 0.5 - 5, -SIZE.y * 0.5)
	add_child(_shine)


func _process(delta: float) -> void:
	_t += delta
	vel.y += GRAVITY * delta
	var prev_y := position.y
	position += vel * delta
	rotation += spin * delta
	if not _wet and WaterPool.active != null and WaterPool.active.crossed(position.x, prev_y, position.y):
		_wet = true
		WaterPool.active.splash(position.x, 0.35)
		vel *= 0.35                       # 물이 받아준다
		spin *= 0.3

	# 좌우 벽·천장 (바닥은 아래에서 따로)
	var hit := RoomSolid.bounce_walls(position, vel, BOUNCE)
	position = hit[0]
	vel = hit[1]

	if position.y >= floor_y:
		position.y = floor_y
		if absf(vel.y) > 90.0:
			vel.y = -vel.y * BOUNCE
			vel.x *= FRICTION
			spin *= 0.5
		else:
			vel = Vector2.ZERO
			spin = 0.0
			rotation = 0.0     # 바닥에 눕는다

	if _t > LIFE - FADE:
		modulate.a = clampf((LIFE - _t) / FADE, 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
