class_name DustLayer
extends Polygon2D
## 방 전체를 덮는 부유 먼지(엠비언트) 레이어. 어둠 속에서도 희미하게 떠다니고, 광원 근처에서 그 색으로 드러난다.
## 광원: 램프(아래 원뿔) + light_info() 를 제공하는 노드(비상등·불·전선 아크 — 전방향, 색 있음).

const MAX_LIGHTS := 16

var _lamps: Array = []
var _sources: Array = []          # light_info() 를 가진 노드들
var _mat: ShaderMaterial


## room_rect: 방 세로 범위 포함(층고가 높은 방은 천장 y 가 음수)
func setup(room_rect: Rect2, lamps: Array, sources: Array = []) -> void:
	_lamps = lamps
	_sources = sources
	var tl := room_rect.position
	var br := room_rect.end
	polygon = PackedVector2Array([tl, Vector2(br.x, tl.y), br, Vector2(tl.x, br.y)])
	texture = Lighting.white_texture()
	uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_mat = Lighting.shader_material("dust")
	material = _mat
	_upload()


func _process(_delta: float) -> void:
	_upload()


func _upload() -> void:
	var pos := PackedVector2Array()
	var col := PackedColorArray()
	var rad := PackedFloat32Array()
	for lamp in _lamps:
		if pos.size() >= MAX_LIGHTS:
			break
		var c: Color = lamp.COLOR * lamp.energy_ratio
		pos.append(lamp.position)
		col.append(Color(c.r, c.g, c.b, 1.0))          # a=1: 램프 원뿔
		rad.append(420.0)
	for src in _sources:
		if pos.size() >= MAX_LIGHTS:
			break
		if not is_instance_valid(src):
			continue
		var info: Dictionary = src.light_info()
		if info.is_empty():
			continue
		var c: Color = info["color"]
		pos.append(info["pos"])
		col.append(Color(c.r, c.g, c.b, 0.0))          # a=0: 전방향
		rad.append(info["radius"])
	var n := pos.size()
	for i in range(n, MAX_LIGHTS):
		pos.append(Vector2(-99999, -99999))
		col.append(Color(0, 0, 0, 0))
		rad.append(1.0)
	_mat.set_shader_parameter("light_count", n)
	_mat.set_shader_parameter("lights", pos)
	_mat.set_shader_parameter("light_color", col)
	_mat.set_shader_parameter("light_radius", rad)
