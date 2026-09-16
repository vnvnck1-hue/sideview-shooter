class_name DustLayer
extends Polygon2D
## 방 전체를 덮는 부유 먼지 레이어. 램프 위치·밝기를 셰이더에 넘겨 불빛 속에서만 보이게 한다.

const MAX_LAMPS := 12

var _lamps: Array = []
var _mat: ShaderMaterial


func setup(room_w: float, room_h: float, lamps: Array) -> void:
	_lamps = lamps
	polygon = PackedVector2Array([Vector2(0, 0), Vector2(room_w, 0), Vector2(room_w, room_h), Vector2(0, room_h)])
	texture = Lighting.white_texture()
	uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_mat = Lighting.shader_material("dust")
	var pos := PackedVector2Array()
	var en := PackedFloat32Array()
	for i in range(MAX_LAMPS):
		if i < lamps.size():
			pos.append(lamps[i].position)
		else:
			pos.append(Vector2(-99999, -99999))
		en.append(0.0)
	_mat.set_shader_parameter("lamp_count", mini(lamps.size(), MAX_LAMPS))
	_mat.set_shader_parameter("lamps", pos)
	_mat.set_shader_parameter("lamp_energy", en)
	material = _mat


func _process(_delta: float) -> void:
	var en := PackedFloat32Array()
	for i in range(MAX_LAMPS):
		en.append(_lamps[i].energy_ratio if i < _lamps.size() else 0.0)
	_mat.set_shader_parameter("lamp_energy", en)
