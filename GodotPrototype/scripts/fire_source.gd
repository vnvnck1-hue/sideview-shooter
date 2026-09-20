class_name FireSource
extends Node2D
## 바닥에서 타오르는 불. 절차 불꽃 셰이더 + 흔들리는 주황 라이트(노멀 반응) + 떠오르는 불티
## + 구 노멀맵을 단 연기 파티클(주변 광원에 부피감 있게 반응) + 뒤 벽 그을음.
## 원점 = 불의 바닥 중심(바닥선).
##
## 스타일 3종은 STYLES 에 정의 (V 키로 순환, Main.set_fire_style). 모든 스타일에서
## 불꽃 채도는 배경 팔레트에 맞춰 낮게 잡고, 연기는 불의 붉은기를 받아 불그스름하게 시작해 검게 변한다.

## 스타일 값 단위: 색은 sRGB Color, 속도는 px/s, 시간은 초.
##   shader      : fire.gdshader 유니폼 (style 0 포스터 / 1 부드러운 / 2 잉걸)
##   modulate    : 불꽃 폴리곤 modulate 배율 (CanvasModulate 를 이겨 심이 글로우에 닿는 정도)
##   light_color / energy_base / energy_swing / gust : 주 라이트 색·평균 광량·일렁임 진폭·돌발 세기
##   ember_rate / ember_speed / ember_life : 불티 초당 개수·상승 속도 범위·수명 범위
##   smoke       : 연기 파티클 (amount, lifetime, vel, scale, alpha, radius, 색 c0→c1→c2 와 시점 t1/t2)
const STYLES := [
	{
		"id": "poster", "name": "픽셀 포스터",
		"desc": "4단 포스터라이즈 청키 불길, 채도를 낮춘 주황. 연기는 붉게 시작해 회갈색을 거쳐 검게",
		"shader": {"style": 0, "pixel_step": 4.0, "speed": 1.6, "height_k": 0.85, "width_base": 0.95, "width_top": 0.15, "gap": 0.0, "boost": 0.15,
			"col_core": Color(0.98, 0.86, 0.62), "col_mid": Color(0.90, 0.52, 0.22), "col_red": Color(0.62, 0.20, 0.10), "col_edge": Color(0.22, 0.07, 0.05)},
		"modulate": 1.3, "light_color": Color(1.0, 0.58, 0.30), "energy_base": 2.0, "energy_swing": 1.4, "gust": 1.0,
		"core_color": Color(1.0, 0.72, 0.42),
		"ember_rate": 14.0, "ember_speed": Vector2(90, 220), "ember_life": Vector2(0.9, 2.2),
		"smoke": {"amount": 64, "lifetime": 6.4, "vel": Vector2(80, 135), "scale": Vector2(2.0, 3.4), "alpha": 0.7, "radius": 0.32,
			"c0": Color(0.62, 0.18, 0.10), "c1": Color(0.20, 0.14, 0.13), "c2": Color(0.04, 0.04, 0.04), "t1": 0.3, "t2": 0.65},
	},
	{
		"id": "smooth", "name": "부드러운 유화",
		"desc": "양자화 없이 길고 부드럽게 흐르는 불꽃, 진홍→호박색 그라데이션. 연기는 크고 느리고 옅다",
		"shader": {"style": 1, "pixel_step": 1.0, "speed": 1.1, "height_k": 0.68, "width_base": 0.85, "width_top": 0.05, "gap": 0.0, "boost": 0.12,
			"col_core": Color(1.0, 0.90, 0.70), "col_mid": Color(0.92, 0.55, 0.22), "col_red": Color(0.68, 0.18, 0.08), "col_edge": Color(0.30, 0.06, 0.04)},
		"modulate": 1.2, "light_color": Color(1.0, 0.66, 0.40), "energy_base": 1.9, "energy_swing": 0.8, "gust": 0.5,
		"core_color": Color(1.0, 0.80, 0.55),
		"ember_rate": 6.0, "ember_speed": Vector2(60, 150), "ember_life": Vector2(1.4, 3.0),
		"smoke": {"amount": 48, "lifetime": 8.0, "vel": Vector2(55, 90), "scale": Vector2(2.8, 4.4), "alpha": 0.5, "radius": 0.36,
			"c0": Color(0.55, 0.20, 0.14), "c1": Color(0.16, 0.13, 0.13), "c2": Color(0.03, 0.03, 0.03), "t1": 0.35, "t2": 0.75},
	},
	{
		"id": "smolder", "name": "잉걸·검은 연기",
		"desc": "낮고 끊어지는 어두운 불길에 불티가 많이 튀고, 짙은 검은 연기가 빠르게 솟는다",
		"shader": {"style": 2, "pixel_step": 3.0, "speed": 2.2, "height_k": 1.35, "width_base": 0.9, "width_top": 0.2, "gap": 0.8, "boost": 0.1,
			"col_core": Color(0.95, 0.70, 0.40), "col_mid": Color(0.80, 0.36, 0.12), "col_red": Color(0.50, 0.12, 0.06), "col_edge": Color(0.18, 0.05, 0.04)},
		"modulate": 1.3, "light_color": Color(1.0, 0.42, 0.18), "energy_base": 1.5, "energy_swing": 1.7, "gust": 1.4,
		"core_color": Color(1.0, 0.55, 0.30),
		"ember_rate": 36.0, "ember_speed": Vector2(120, 320), "ember_life": Vector2(0.8, 2.6),
		"smoke": {"amount": 96, "lifetime": 5.5, "vel": Vector2(110, 175), "scale": Vector2(2.4, 3.8), "alpha": 0.85, "radius": 0.4,
			"c0": Color(0.55, 0.14, 0.08), "c1": Color(0.07, 0.05, 0.05), "c2": Color(0.02, 0.02, 0.02), "t1": 0.22, "t2": 0.6},
	},
]
static var style_index := 2          # 전역 현재 스타일 (새로 만들어지는 불에 적용). 기본 = 잉걸·검은 연기 (확정)

const LIGHT_RADIUS := 950.0        # 주 라이트 반경

var size := Vector2(170.0, 210.0)
var style: Dictionary = STYLES[0]
var _flame: Polygon2D
var _flame_mat: ShaderMaterial
var _light: PointLight2D
var _core_light: PointLight2D
var _smoke: GPUParticles2D
var _smoke_mat: ShaderMaterial
var _embers: Array = []          # {p, v, life, age, size, ph}
var _ember_acc := 0.0
var _t := 0.0
var _seed := 0.0
var _energy := 2.0
var _noise := FastNoiseLite.new()

# 광량 일렁임: 부드러운 노이즈 위에 "확 타오르고 훅 꺼지는" 불규칙 랜덤 돌발을 겹친다.
var _gust := 0.0                   # 현재 돌발 세기 (-1 ~ +1)
var _gust_target := 0.0
var _gust_timer := 0.0
var _gust_rate := 12.0             # 목표로 따라가는 속도 (클수록 급격)


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
	_flame.position = global_position
	air_layer.add_child(_flame)

	# 큰 주황 라이트 (노멀맵이 일렁이게 height)
	_light = PointLight2D.new()
	_light.name = "FireLight"
	_light.texture = Lighting.radial_texture()
	_light.texture_scale = Lighting.scale_for_radius(LIGHT_RADIUS)
	_light.height = 130.0
	_light.position = Vector2(0, -size.y * 0.35)
	add_child(_light)
	# 밝은 심 라이트 (작고 강함)
	_core_light = PointLight2D.new()
	_core_light.texture = Lighting.radial_texture()
	_core_light.texture_scale = Lighting.scale_for_radius(320.0)
	_core_light.energy = 1.6
	_core_light.height = 70.0
	_core_light.position = Vector2(0, -size.y * 0.2)
	add_child(_core_light)
	Lighting.register_dynamic(_light, 1.0, "ambient")           # 불꽃이 흔들리는 대로 그림자도 흔들린다
	Lighting.register_dynamic(_core_light, 0.7, "ambient")

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

	# 연기 파티클 (색은 파티클 램프 — 스타일이 정한다)
	_smoke = GPUParticles2D.new()
	_smoke.name = "Smoke"
	_smoke.preprocess = 4.0
	_smoke.randomness = 0.4
	_smoke.texture = Lighting.smoke_canvas_texture()
	_smoke_mat = Lighting.shader_material("smoke")
	_smoke_mat.set_shader_parameter("use_particle_color", true)
	_smoke.material = _smoke_mat
	_smoke.local_coords = false
	_smoke.position = global_position + Vector2(0, -size.y * 0.72)
	_smoke.z_index = 1                         # 불꽃 위에
	air_layer.add_child(_smoke)

	apply_style(style_index)


## 스타일 적용 (런타임 전환 가능). 연기는 새 램프로 다시 시작한다.
func apply_style(index: int) -> void:
	style = STYLES[wrapi(index, 0, STYLES.size())]
	var sh: Dictionary = style["shader"]
	for k in sh.keys():
		_flame_mat.set_shader_parameter(k, sh[k])
	# 양자화 픽셀 (풀해상도 렌더라 배율 없음). 1.0(양자화 없음)은 그대로.
	var step: float = sh.get("pixel_step", 1.0)
	if step > 1.0:
		_flame_mat.set_shader_parameter("pixel_step", step)
	var m: float = style["modulate"]
	_flame.modulate = Color(m, m, m, 1.0)
	_light.color = style["light_color"]
	_core_light.color = style["core_color"]
	_energy = style["energy_base"]
	_smoke.process_material = _build_smoke_material(style["smoke"])
	_smoke.amount = int(style["smoke"]["amount"])
	_smoke.lifetime = float(style["smoke"]["lifetime"])
	_smoke.restart()
	_embers.clear()


func _build_smoke_material(sk: Dictionary) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = size.x * float(sk["radius"])
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 30.0
	pm.initial_velocity_min = sk["vel"].x
	pm.initial_velocity_max = sk["vel"].y
	pm.gravity = Vector3(0, 0, 0)
	pm.damping_min = 15.0
	pm.damping_max = 24.0
	pm.angular_velocity_min = -18.0
	pm.angular_velocity_max = 18.0
	pm.scale_min = sk["scale"].x
	pm.scale_max = sk["scale"].y
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.45))
	sc.add_point(Vector2(0.35, 1.0))
	sc.add_point(Vector2(1.0, 1.35))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	# 색 램프: 불의 붉은기(c0) → 회갈색(c1) → 검정(c2). 알파는 빠르게 올라 서서히 빠진다.
	var a: float = sk["alpha"]
	var c0: Color = sk["c0"]
	var c1: Color = sk["c1"]
	var c2: Color = sk["c2"]
	var grad := Gradient.new()
	grad.set_color(0, Color(c0, 0.0))
	grad.set_color(1, Color(c2, 0.0))          # 끝점 먼저 (add_point 뒤엔 인덱스가 밀린다)
	grad.add_point(0.1, Color(c0, a))
	grad.add_point(float(sk["t1"]), Color(c1, a * 0.9))
	grad.add_point(float(sk["t2"]), Color(c2, a * 0.7))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	# 주의: ParticleProcessMaterial 의 turbulence 는 2D 픽셀 스케일에서 속도를 거의 0 으로 만들어 파티클이
	# 제자리에 멈춘다(4.7.2 확인). 대신 접선 가속으로 좌우로 느릿하게 흐르게 한다.
	pm.tangential_accel_min = -16.0
	pm.tangential_accel_max = 16.0
	return pm


## 먼지 레이어용 광원 정보
func light_info() -> Dictionary:
	return {"pos": global_position + Vector2(0, -size.y * 0.4), "color": _light.color * (_energy * 0.8), "radius": LIGHT_RADIUS * 0.9, "lamp": false}


func _process(delta: float) -> void:
	_t += delta
	var gust_k: float = style["gust"]
	# 일렁이는 밝기 = 느린 노이즈(전체 기세) + 빠른 노이즈(잔떨림) + 랜덤 돌발(확 타오름 / 훅 꺼짐)
	var n := _noise.get_noise_1d(_t * 6.0) * 0.5 + 0.5
	var n2 := _noise.get_noise_1d(_t * 17.0 + 40.0) * 0.5 + 0.5
	var n3 := _noise.get_noise_1d(_t * 41.0 + 90.0) * 0.5 + 0.5      # 아주 빠른 잔떨림
	# 돌발: 불규칙한 간격(0.06~0.35s)마다 새 목표를 뽑고, 매번 다른 속도로 따라간다.
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = randf_range(0.06, 0.35) / maxf(gust_k, 0.3)
		# 대체로 잔잔(-0.3~0.4), 가끔(약 20%) 크게 치솟거나 꺼진다
		if randf() < 0.2:
			_gust_target = randf_range(0.6, 1.0) if randf() < 0.65 else randf_range(-1.0, -0.6)
		else:
			_gust_target = randf_range(-0.3, 0.4)
		_gust_target *= gust_k
		_gust_rate = randf_range(6.0, 22.0)
	_gust = lerpf(_gust, _gust_target, clampf(_gust_rate * delta, 0.0, 1.0))
	var flicker := clampf(0.45 * (n - 0.5) * 2.0 + 0.2 * (n2 - 0.5) * 2.0 + 0.1 * (n3 - 0.5) * 2.0 + 0.45 * _gust, -1.0, 1.0)
	_energy = maxf(float(style["energy_base"]) + float(style["energy_swing"]) * flicker, 0.6)
	_light.energy = _energy
	# 밝을수록 빛의 중심이 살짝 위로 솟고 반경도 커진다 (불길이 치솟는 느낌)
	var swell := 1.0 + 0.12 * flicker
	_light.texture_scale = Lighting.scale_for_radius(LIGHT_RADIUS * swell)
	_light.position = Vector2((n - 0.5) * 18.0 + (n3 - 0.5) * 6.0, -size.y * (0.35 + 0.06 * flicker) + (n2 - 0.5) * 12.0)
	_core_light.energy = maxf(1.3 + 0.9 * (n2 - 0.5) * 2.0 + 0.6 * _gust, 0.4)
	_flame_mat.set_shader_parameter("intensity", 0.92 + 0.16 * n + 0.14 * _gust)

	# 불티: 위로 떠오르며 흔들리고 식는다
	var es: Vector2 = style["ember_speed"]
	var el: Vector2 = style["ember_life"]
	_ember_acc += float(style["ember_rate"]) * delta
	while _ember_acc >= 1.0:
		_ember_acc -= 1.0
		_embers.append({"p": Vector2(randf_range(-size.x * 0.3, size.x * 0.3), -randf_range(size.y * 0.3, size.y * 0.8)),
			"v": Vector2(randf_range(-30, 30), -randf_range(es.x, es.y)), "life": randf_range(el.x, el.y), "age": 0.0,
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
	var mid: Color = style["shader"]["col_mid"]
	var ember_col := Color(mid.r * (1.3 + glow), mid.g * (1.0 + glow * 0.6), mid.b * 0.6, 1.0)
	draw_rect(Rect2(-hw * 0.6, -22, 10, 3), ember_col)
	draw_rect(Rect2(hw * 0.15, -30, 8, 3), ember_col)
	draw_rect(Rect2(-hw * 0.1, -12, 12, 3), ember_col)
	draw_rect(Rect2(hw * 0.45, -16, 7, 3), ember_col)
	var core: Color = style["shader"]["col_core"]
	var red: Color = style["shader"]["col_red"]
	for e in _embers:
		var k: float = e["age"] / e["life"]
		var col := core.lerp(red, smoothstep(0.0, 0.7, k))
		var bright := lerpf(3.2, 1.3, k)
		col = Color(col.r * bright, col.g * bright, col.b * bright, 1.0 - smoothstep(0.6, 1.0, k))
		var sz: float = e["size"] * (1.0 - k * 0.5)
		draw_rect(Rect2(e["p"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
