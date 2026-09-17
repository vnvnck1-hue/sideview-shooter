class_name PowerRelayPart
extends RigidBody2D
## Power Relay 캐비닛에서 떨어져 나온 명시적 파츠.
## 셀을 잘라내는 HitProp과 달리, 문·코어·캡·베이스처럼 기능 단위로 분리되고
## 실제 RigidBody2D 물리로 튕긴 뒤 룸 바닥에 안착한다.

const LIFE := 6.0
const FLOOR_BOUNCE := 0.18

var _floor_y := 0.0
var _life := 0.0
var _sprite: Sprite2D


func setup(tex: Texture2D, world_pos: Vector2, velocity: Vector2, floor_y: float, scale_factor := 1.0) -> void:
	_floor_y = floor_y
	position = world_pos
	mass = 0.35
	gravity_scale = 1.0
	linear_velocity = velocity
	angular_velocity = randf_range(-9.0, 9.0)
	contact_monitor = true
	max_contacts_reported = 2

	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2.ONE * scale_factor
	var material := Lighting.lit_material()
	material.set_shader_parameter("rim_ambient_strength", 0.45)
	_sprite.material = material
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(maxf(float(tex.get_width()) * scale_factor * 0.72, 8.0), maxf(float(tex.get_height()) * scale_factor * 0.72, 8.0))
	shape.shape = box
	add_child(shape)


func _ready() -> void:
	add_to_group("power_relay_parts")


func _physics_process(delta: float) -> void:
	_life += delta
	if _sprite == null:
		return
	# 룸에는 플레이어용 바닥 충돌체가 없을 수 있으므로, 시각 파츠에도 안전한 바닥 한계를 둔다.
	var half_h := _sprite.texture.get_height() * 0.5 * absf(_sprite.scale.y)
	if position.y + half_h > _floor_y and linear_velocity.y > 0.0:
		position.y = _floor_y - half_h
		linear_velocity.y = -linear_velocity.y * FLOOR_BOUNCE
		linear_velocity.x *= 0.62
		angular_velocity *= 0.55
		if absf(linear_velocity.y) < 42.0:
			linear_velocity.y = 0.0
			angular_velocity = 0.0
	if _life > LIFE:
		queue_free()
