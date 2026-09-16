class_name WaterLeak
extends Node2D
## 새는 수도관. 균열에서 물줄기가 압력으로 뿜어져 포물선으로 떨어지고, 바닥에 닿으면 사방으로 튄다.
## 바닥에는 물웅덩이(퍼들 셰이더)가 서서히 넓어지며 물방울마다 파문 고리가 퍼진다.
## 물방울은 한 노드가 _draw 로 그린다. 위치는 월드 좌표(방 로컬 = 월드).

const GRAVITY := 1500.0
const RATE := 75.0                # 초당 물방울
const MIST_RATE := 60.0           # 균열 주변 미세 분무
const PUDDLE_GROW := 45.0         # 웅덩이가 다 커지는 시간(초)
const PUDDLE_W := 300.0
const PUDDLE_H := 16.0
const MAX_RIPPLES := 6

var dir := Vector2(0.35, 1.0)     # 분사 방향
var pressure := 1.0
var floor_y := 486.0
var _drops: Array = []            # {p, v, life, age, size, splash}
var _acc := 0.0
var _mist_acc := 0.0
var _puddle: Polygon2D
var _puddle_mat: ShaderMaterial
var _puddle_x := 0.0
var _fill := 0.0
var _ripples := PackedVector4Array()
var _t := 0.0


## props_layer: 웅덩이를 올릴 레이어(캐릭터 뒤·프랍 앞). 분사 방향으로 착지점을 미리 계산해 웅덩이 위치를 잡는다.
func setup(props_layer: Node2D, spray_dir: Vector2, floor_line: float, strength := 1.0) -> void:
	dir = spray_dir.normalized()
	pressure = strength
	floor_y = floor_line
	_puddle_x = _predict_landing_x()

	_puddle = Polygon2D.new()
	_puddle.name = "Puddle"
	var hw := PUDDLE_W * 0.5
	var hh := PUDDLE_H * 0.5
	_puddle.polygon = PackedVector2Array([
		Vector2(_puddle_x - hw, floor_y - hh + 2), Vector2(_puddle_x + hw, floor_y - hh + 2),
		Vector2(_puddle_x + hw, floor_y + hh + 2), Vector2(_puddle_x - hw, floor_y + hh + 2),
	])
	_puddle.texture = Lighting.white_texture()
	_puddle.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_puddle_mat = Lighting.shader_material("puddle")
	_puddle_mat.set_shader_parameter("water_tint", Lighting.WATER)
	_puddle_mat.set_shader_parameter("seed", randf() * 10.0)
	_puddle_mat.set_shader_parameter("fill", 0.0)
	_puddle.material = _puddle_mat
	_puddle.modulate = Color(2.2, 2.2, 2.2, 1.0)      # 어두운 방에서도 물결이 살짝 빛난다
	props_layer.add_child(_puddle)


func _predict_landing_x() -> float:
	var p := global_position
	var v := dir * 480.0 * pressure
	var dt := 1.0 / 120.0
	for i in range(600):
		v.y += GRAVITY * dt
		p += v * dt
		if p.y >= floor_y:
			return p.x
	return p.x


## 먼지 레이어용 — 물은 광원이 아니므로 비활성 (인터페이스 통일용)
func light_info() -> Dictionary:
	return {}


func _process(delta: float) -> void:
	_t += delta
	_fill = minf(_fill + delta / PUDDLE_GROW, 1.0)
	_puddle_mat.set_shader_parameter("fill", 0.25 + 0.75 * _fill)

	# 물줄기: 압력 맥동 (살짝 세졌다 약해짐)
	var pulse := 0.85 + 0.15 * sin(_t * 3.1) + 0.08 * sin(_t * 11.7)
	_acc += RATE * pressure * pulse * delta
	while _acc >= 1.0:
		_acc -= 1.0
		var v := dir.rotated(randf_range(-0.16, 0.16)) * randf_range(400.0, 560.0) * pressure * pulse
		_drops.append({"p": global_position + Vector2(randf_range(-2, 2), randf_range(-2, 2)), "v": v,
			"life": 3.0, "age": 0.0, "size": randf_range(2.5, 4.5), "splash": false})
	# 균열 미세 분무 (짧고 빠른 안개 알갱이, 사방)
	_mist_acc += MIST_RATE * delta
	while _mist_acc >= 1.0:
		_mist_acc -= 1.0
		var v := dir.rotated(randf_range(-1.3, 1.3)) * randf_range(60.0, 220.0)
		_drops.append({"p": global_position, "v": v, "life": randf_range(0.12, 0.3), "age": 0.0,
			"size": 1.5, "splash": true})

	var i := 0
	while i < _drops.size():
		var d: Dictionary = _drops[i]
		d["age"] += delta
		var v: Vector2 = d["v"]
		v.y += GRAVITY * delta
		var p: Vector2 = d["p"] + v * delta
		var dead: bool = d["age"] >= d["life"]
		if p.y >= floor_y and v.y > 0.0:
			if d["splash"]:
				# 튄 물방울은 한 번 더 살짝 튕기고 사라진다
				p.y = floor_y
				v.y = -v.y * 0.25
				v.x *= 0.6
				if absf(v.y) < 50.0:
					dead = true
			else:
				# 본 물줄기 착지 → 사방으로 튐 + 파문
				dead = true
				var n := randi_range(3, 6)
				for k in range(n):
					var sv := Vector2(randf_range(-260.0, 260.0), -randf_range(120.0, 360.0))
					_drops.append({"p": Vector2(p.x, floor_y), "v": sv, "life": randf_range(0.25, 0.5),
						"age": 0.0, "size": randf_range(1.5, 3.0), "splash": true})
				_add_ripple(p.x)
		d["v"] = v
		d["p"] = p
		if dead:
			_drops.remove_at(i)
		else:
			i += 1

	# 파문 갱신
	for r in range(_ripples.size()):
		var rp := _ripples[r]
		rp.z += delta
		_ripples[r] = rp
	while _ripples.size() > 0 and _ripples[0].z > 0.9:
		_ripples.remove_at(0)
	_puddle_mat.set_shader_parameter("ripple_count", _ripples.size())
	if _ripples.size() > 0:
		_puddle_mat.set_shader_parameter("ripples", _ripples)
	queue_redraw()


func _add_ripple(x: float) -> void:
	var u := clampf((x - (_puddle_x - PUDDLE_W * 0.5)) / PUDDLE_W, 0.0, 1.0)
	_ripples.append(Vector4(u, 0.5, 0.0, randf_range(0.5, 1.0)))
	while _ripples.size() > MAX_RIPPLES:
		_ripples.remove_at(0)


func _draw() -> void:
	# 균열 (파이프 위 어두운 틈 + 젖은 얼룩)
	draw_rect(Rect2(-5, -3, 10, 6), Color(0.05, 0.06, 0.08))
	draw_rect(Rect2(-3, -1, 6, 3), Color(0.35, 0.5, 0.7))
	var base := Lighting.WATER
	var org := global_position                      # 물방울은 월드 좌표 → 로컬로
	for d in _drops:
		var p: Vector2 = d["p"] - org
		var v: Vector2 = d["v"]
		var sz: float = d["size"]
		var k: float = d["age"] / d["life"]
		var bright := 1.9 if not d["splash"] else 1.5
		var col := Color(base.r * bright, base.g * bright, base.b * bright, (0.85 if not d["splash"] else 0.7) * (1.0 - k * 0.5))
		var len := minf(v.length() * 0.02, 14.0)
		if len > sz:
			draw_line(p - v.normalized() * len, p, col, sz)
		else:
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
