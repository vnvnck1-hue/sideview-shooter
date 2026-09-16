class_name ChunkDebris
extends Sprite2D
## 프랍에서 떨어져 나온 조각. 원본 프랍 텍스처(노멀맵 포함 CanvasTexture)의 셀 영역을 그대로 잘라
## 날아가며 회전하고, 바닥에서 튕겨 잔해로 잠시 남은 뒤 사라진다. lit_surface 라 라이트·림에 반응한다.

const GRAVITY := 2400.0
const LIFE := 3.2
const FADE := 0.6

var vel := Vector2.ZERO
var spin := 0.0
var floor_y := 0.0
var _t := 0.0
var _resting := false


func setup(source: Texture2D, region: Rect2, world_pos: Vector2, velocity: Vector2, floor_line: float) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	texture = atlas
	centered = true
	position = world_pos
	vel = velocity
	spin = randf_range(-16.0, 16.0)
	floor_y = floor_line
	material = Lighting.lit_material()
	material.set_shader_parameter("rim_ambient_strength", 0.6)


func _process(delta: float) -> void:
	_t += delta
	if not _resting:
		vel.y += GRAVITY * delta
		position += vel * delta
		rotation += spin * delta
		var half_h := texture.get_height() * 0.5
		if position.y + half_h >= floor_y and vel.y > 0.0:
			position.y = floor_y - half_h
			vel.y = -vel.y * 0.3
			vel.x *= 0.55
			spin *= 0.4
			if absf(vel.y) < 60.0:
				vel = Vector2.ZERO
				spin = 0.0
				_resting = true
				# 바닥에 눕는다: 가장 가까운 90° 로 스냅
				rotation = roundf(rotation / (PI * 0.5)) * PI * 0.5
	if _t > LIFE - FADE:
		modulate.a = clampf((LIFE - _t) / FADE, 0.0, 1.0)
	if _t >= LIFE:
		queue_free()
