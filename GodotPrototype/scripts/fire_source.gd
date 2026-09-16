class_name FireSource
extends Node2D
## 바닥에서 타오르는 불. 절차 불꽃 셰이더(포스터라이즈) + 흔들리는 주황 라이트(노멀 반응) + 떠오르는 불티
## + 구 노멀맵을 단 연기 파티클(주변 광원에 부피감 있게 반응) + 뒤 벽 그을음.
## 원점 = 불의 바닥 중심(바닥선).

var size := Vector2(170.0, 210.0)
var _flame: Polygon2D
var _flame_mat: ShaderMaterial
var _light: PointLight2D
var _core_light: PointLight2D
var _smoke: GPUParticles2D
var _embers: Array = []          # {p, v, life, age, size}
var _ember_acc := 0.0
var _t := 0.0
var _seed := 0.0
var _energy := 1.3
var _noise := FastNoiseLite.new()


## air_layer: 불꽃·연기를 올릴 공기층. wall_layer: 그을음을 올릴 벽 레이어(타일 위).
func setup(air_layer: Node2D, wall_layer: Node2D, fire_size := Vector2(170.0, 210.0)) -> void:
	size = fire_size
	_seed = randf() * 10.0
	_noise.seed = randi()
	_noise.frequency = 1.0

	# 불꽃 사각형 (바닥 중심 기준)
	_flame = Polygon2D.new()
	_flame.name = "Flame"
	var hw := size.x * 0.5
	_flame.polygon = PackedVector2Array([Vector2(-hw, -size.y), Vector2(hw, -size.y), Vector2(hw, 6), Vector2(-hw, 6)])
	_flame.texture = Lighting.white_texture()
	_flame.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_flame_mat = Lighting.shader_material("fire")
	_flame_mat.set_shader_parameter("size_px", Vector2(size.x, size.y + 6))
	_flame_mat.set_shader_parameter("seed", _seed)
	_flame.material = _flame_mat
	_flame.modulate = Color(2.4, 2.4, 2.4, 1.0)       # CanvasModulate 를 이겨 심이 글로우에 닿는다
	_flame.position = global_position
	air_layer.add_child(_flame)

	# 큰 주황 라이트 (노멀맵이 일렁이게 height)
	_light = PointLight2D.new()
	_light.name = "FireLight"
	_light.texture = Lighting.radial_texture()
	_light.texture_scale = Lighting.scale_for_radius(600.0)
	_light.color = Lighting.FIRE_LIGHT
	_light.energy = _energy
	_light.height = 110.0
	_light.position = Vector2(0, -size.y * 0.35)
	add_child(_light)
	# 밝은 심 라이트 (작고 강함)
	_core_light = PointLight2D.new()
	_core_light.texture = Lighting.radial_texture()
	_core_light.texture_scale = Lighting.scale_for_radius(220.0)
	_core_light.color = Color(1.0, 0.75, 0.4)
	_core_light.energy = 0.9
	_core_light.height = 60.0
	_core_light.position = Vector2(0, -size.y * 0.2)
	add_child(_core_light)

	# 그을음 (벽 레이어, 곱셈)
	var soot := Polygon2D.new()
	soot.name = "Soot"
	var sw := size.x * 1.3
	var sh := size.y * 2.0
	soot.polygon = PackedVector2Array([Vector2(-sw, -sh), Vector2(sw, -sh), Vector2(sw, 4), Vector2(-sw, 4)])
	soot.texture = Lighting.white_texture()
	soot.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var sm := Lighting.shader_material("soot")
	sm.set_shader_parameter("seed", _seed)
	soot.material = sm
	soot.position = global_position
	wall_layer.add_child(soot)

	# 연기 파티클
	_smoke = GPUParticles2D.new()
	_smoke.name = "Smoke"
	_smoke.amount = 64
	_smoke.lifetime = 6.4
	_smoke.preprocess = 4.0
	_smoke.randomness = 0.4
	_smoke.texture = Lighting.smoke_canvas_texture()
	_smoke.material = Lighting.shader_material("smoke")
	_smoke.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size.x * 0.32
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = 80.0
	pm.initial_velocity_max = 135.0
	pm.gravity = Vector3(0, 0, 0)
	pm.damping_min = 15.0
	pm.damping_max = 24.0
	pm.angular_velocity_min = -18.0
	pm.angular_velocity_max = 18.0
	pm.scale_min = 2.0
	pm.scale_max = 3.4
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.45))
	sc.add_point(Vector2(0.35, 1.0))
	sc.add_point(Vector2(1.0, 1.35))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))          # 끝점 먼저 (add_point 뒤엔 인덱스가 밀린다)
	grad.add_point(0.12, Color(1, 1, 1, 0.62))
	grad.add_point(0.55, Color(1, 1, 1, 0.5))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	# 주의: ParticleProcessMaterial 의 turbulence 는 2D 픽셀 스케일에서 속도를 거의 0 으로 만들어 파티클이
	# 제자리에 멈춘다(4.7.2 확인). 대신 접선 가속으로 좌우로 느릿하게 흐르게 한다.
	pm.tangential_accel_min = -16.0
	pm.tangential_accel_max = 16.0
	_smoke.process_material = pm
	_smoke.position = global_position + Vector2(0, -size.y * 0.72)
	_smoke.z_index = 1                         # 불꽃 위에
	air_layer.add_child(_smoke)


## 먼지 레이어용 광원 정보
func light_info() -> Dictionary:
	return {"pos": global_position + Vector2(0, -size.y * 0.4), "color": Lighting.FIRE_LIGHT * (_energy * 0.8), "radius": 560.0, "lamp": false}


func _process(delta: float) -> void:
	_t += delta
	# 일렁이는 밝기 (노이즈)
	var n := _noise.get_noise_1d(_t * 6.0) * 0.5 + 0.5
	var n2 := _noise.get_noise_1d(_t * 17.0 + 40.0) * 0.5 + 0.5
	_energy = 1.05 + 0.5 * n + 0.2 * n2
	_light.energy = _energy
	_light.position = Vector2((n - 0.5) * 14.0, -size.y * 0.35 + (n2 - 0.5) * 10.0)
	_core_light.energy = 0.7 + 0.5 * n2
	_flame_mat.set_shader_parameter("intensity", 0.92 + 0.16 * n)

	# 불티: 위로 떠오르며 흔들리고 식는다
	_ember_acc += 14.0 * delta
	while _ember_acc >= 1.0:
		_ember_acc -= 1.0
		_embers.append({"p": Vector2(randf_range(-size.x * 0.3, size.x * 0.3), -randf_range(size.y * 0.3, size.y * 0.8)),
			"v": Vector2(randf_range(-30, 30), -randf_range(90, 220)), "life": randf_range(0.9, 2.2), "age": 0.0,
			"size": randf_range(2.0, 4.0), "ph": randf() * TAU})
	var i := 0
	while i < _embers.size():
		var e: Dictionary = _embers[i]
		e["age"] += delta
		if e["age"] >= e["life"]:
			_embers.remove_at(i)
			continue
		var v: Vector2 = e["v"]
		v.x += sin(_t * 5.0 + e["ph"]) * 120.0 * delta
		v.y = minf(v.y + 20.0 * delta, -40.0)
		e["v"] = v
		e["p"] += v * delta
		i += 1
	queue_redraw()


func _draw() -> void:
	# 타고 있는 잔해 더미 (불의 근원) — 검게 탄 덩어리 + 붉게 달아오른 틈
	var hw := size.x * 0.42
	draw_rect(Rect2(-hw, -14, hw * 2.0, 16), Color(0.06, 0.05, 0.05))
	draw_rect(Rect2(-hw * 0.8, -26, hw * 1.6, 14), Color(0.09, 0.07, 0.07))
	draw_rect(Rect2(-hw * 0.45, -36, hw * 0.9, 12), Color(0.07, 0.06, 0.06))
	var glow := 0.5 + 0.5 * (_noise.get_noise_1d(_t * 9.0) * 0.5 + 0.5)
	var ember_col := Color(1.0 * (1.5 + glow), 0.35 * (1.5 + glow), 0.08, 1.0)
	draw_rect(Rect2(-hw * 0.6, -22, 10, 3), ember_col)
	draw_rect(Rect2(hw * 0.15, -30, 8, 3), ember_col)
	draw_rect(Rect2(-hw * 0.1, -12, 12, 3), ember_col)
	draw_rect(Rect2(hw * 0.45, -16, 7, 3), ember_col)
	for e in _embers:
		var k: float = e["age"] / e["life"]
		var col := Color(1.0, 0.85, 0.5).lerp(Color(1.0, 0.25, 0.05), smoothstep(0.0, 0.7, k))
		var bright := lerpf(4.0, 1.4, k)
		col = Color(col.r * bright, col.g * bright, col.b * bright, 1.0 - smoothstep(0.6, 1.0, k))
		var sz: float = e["size"] * (1.0 - k * 0.5)
		draw_rect(Rect2(e["p"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
