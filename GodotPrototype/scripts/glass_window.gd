class_name GlassWindow
extends Sprite2D
## 타일 속 창문 유리. 타일 텍스처의 창 영역을 아틀라스로 잘라 같은 자리에 올리고,
## 유리 셰이더로 사선 하이라이트를 흘린다. 총에 맞으면 탄착점에서 균열이 퍼진다(누적).

var rect := Rect2()               # 월드 좌표
var _mat: ShaderMaterial
var _crack := 0.0
var _hits := 0


func setup(tile_tex: Texture2D, tile_origin: Vector2, region_local: Rect2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = tile_tex
	atlas.region = region_local
	texture = atlas
	centered = false
	position = tile_origin + region_local.position
	rect = Rect2(position, region_local.size)
	_mat = Lighting.shader_material("glass_window")
	_mat.set_shader_parameter("crack_seed", randf_range(1.0, 50.0))
	material = _mat


func is_hit(point: Vector2) -> bool:
	return rect.has_point(point)


func crack(point: Vector2) -> void:
	_hits += 1
	if _hits == 1:
		var uv := (point - rect.position) / rect.size
		_mat.set_shader_parameter("crack_uv", uv)
	# 첫 발에 크게, 이후는 조금씩 더 퍼진다
	var target := clampf(0.55 + 0.15 * float(_hits), 0.0, 1.0)
	var tw := create_tween()
	tw.tween_method(_set_crack, _crack, target, 0.07)


func _set_crack(v: float) -> void:
	_crack = v
	_mat.set_shader_parameter("crack", v)
