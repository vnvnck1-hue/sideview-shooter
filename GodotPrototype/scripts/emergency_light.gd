class_name EmergencyLight
extends Node2D
## 벽에 붙은 회전 비상등. 붉은 돔이 빙빙 돌며 좌우 두 줄기 광선(PointLight2D + 볼류메트릭 팬)을 사방에 뿌린다.
## 광선 라이트는 height 를 가져 벽·프랍 노멀맵이 스치듯 반응한다. 총에 맞으면 스파크를 뿌리며 꺼진다.

const ROT_SPEED := 2.4            # rad/s
const BEAM_RADIUS := 720.0
const GLOW_RADIUS := 260.0
const HIT_RADIUS := 34.0
const HOUSING := Rect2(-16, -8, 32, 16)
const DOME := Rect2(-9, -18, 18, 11)

var broken := false
var _beam: PointLight2D
var _glow: PointLight2D
var _sweep: Polygon2D
var _sweep_mat: ShaderMaterial
var _dome: ColorRect
var _angle := 0.0
var _phase := 0.0
var _break_t := -1.0
var _floor_y := 486.0


func setup(air_layer: Node2D, room_rect: Rect2, floor_line: float) -> void:
	_floor_y = floor_line
	_phase = randf() * TAU
	_angle = _phase

	# 회전 광선 라이트 (양방향)
	_beam = PointLight2D.new()
	_beam.name = "Beam"
	_beam.texture = Lighting.beam_texture()
	_beam.texture_scale = LightTuning.value("beacon_beam", "radius", BEAM_RADIUS) * 2.0 / 256.0 * Lighting.light_range_mul()
	_beam.color = Lighting.EMERGENCY_RED
	_beam.energy = _beam_energy()
	_beam.height = LightTuning.value("beacon_beam", "height", 110.0)
	_beam.shadow_enabled = false
	add_child(_beam)
	Lighting.split_by_depth(_beam)                 # 벽을 훑는 광선은 배경 정면, 인물은 55%
	Lighting.register_dynamic(_beam, 1.1, "ambient")          # 회전하는 광선을 따라 프랍 그림자가 돈다

	# 돔 주변 은은한 붉은 글로우 (회전 방향과 무관하게 맥동)
	_glow = PointLight2D.new()
	_glow.name = "Glow"
	_glow.texture = Lighting.radial_texture()
	_glow.texture_scale = Lighting.scale_for_radius(LightTuning.value("beacon_glow", "radius", GLOW_RADIUS))
	_glow.color = Lighting.EMERGENCY_RED
	_glow.energy = _glow_energy()
	_glow.height = LightTuning.value("beacon_glow", "height", 60.0)
	LightTuning.register(self, "beacon_beam")
	add_child(_glow)
	Lighting.split_by_depth(_glow)

	# 발광 돔 (글로우에 잡히도록 발광 배율)
	_dome = ColorRect.new()
	_dome.name = "Dome"
	_dome.position = DOME.position + Vector2(2, 2)
	_dome.size = DOME.size - Vector2(4, 3)
	_dome.color = Color(1.0, 0.35, 0.28)
	_dome.modulate = Lighting.RED_EMISSIVE
	_dome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dome)

	# 볼류메트릭 회전 팬 — 공기층(Air)에 올려 프랍 앞·캐릭터 뒤에서 보인다
	_sweep = Polygon2D.new()
	_sweep.name = "BeaconSweep"
	var L := BEAM_RADIUS
	_sweep.polygon = PackedVector2Array([Vector2(-L, -L), Vector2(L, -L), Vector2(L, L), Vector2(-L, L)])
	_sweep.texture = Lighting.white_texture()
	_sweep.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_sweep.position = global_position
	_sweep_mat = Lighting.shader_material("beacon_sweep")
	_sweep_mat.set_shader_parameter("tint", Lighting.EMERGENCY_RED)
	_sweep_mat.set_shader_parameter("length_px", L)
	_sweep_mat.set_shader_parameter("room_rect", Vector4(room_rect.position.x, room_rect.position.y, room_rect.size.x, room_rect.size.y))
	_sweep_mat.set_shader_parameter("seed", randf() * 10.0)
	_sweep.material = _sweep_mat
	air_layer.add_child(_sweep)


func is_hit(point: Vector2) -> bool:
	return not broken and global_position.distance_to(point) <= HIT_RADIUS


func break_light() -> void:
	if broken:
		return
	broken = true
	_break_t = 0.0
	var sb := SparkBurst.spawn(get_parent(), _floor_y)
	sb.burst(global_position + Vector2(0, -12), 26, Vector2(0, 1), 1.2, Vector2(160, 620),
		Color(1.0, 0.85, 0.75), Color(1.0, 0.2, 0.1), Vector2(0.4, 1.1))
	sb.burst(global_position + Vector2(0, -12), 8, Vector2(0, -1), 0.9, Vector2(120, 380),
		Color(1.0, 0.95, 0.9), Color(1.0, 0.3, 0.15), Vector2(0.3, 0.7), 2200.0, 2.5, false)


## 먼지 레이어용 광원 정보
func light_info() -> Dictionary:
	var e := _beam.energy if not broken else 0.0
	return {"pos": global_position, "color": Lighting.EMERGENCY_RED * (e * 0.7), "radius": 520.0, "lamp": false}


func _process(delta: float) -> void:
	if broken:
		_break_t += delta
		# 지직거리며 꺼짐
		var k := clampf(_break_t / 0.3, 0.0, 1.0)
		var n := 0.5 + 0.5 * sin(_break_t * 110.0 + _phase)
		var e := (1.0 - k) * lerpf(0.1, 1.5, n)
		_beam.energy = _beam_energy() * e
		_glow.energy = _glow_energy() * e
		_sweep_mat.set_shader_parameter("intensity", 0.9 * e)
		_dome.modulate = Lighting.RED_EMISSIVE * e + Color(0.25, 0.1, 0.1, 1.0) * (1.0 - e)
		if k >= 1.0:
			_beam.enabled = false
			_glow.enabled = false
			_sweep.visible = false
			_dome.color = Color(0.32, 0.12, 0.1)
			_dome.modulate = Color.WHITE
			set_process(false)
		return

	_angle += ROT_SPEED * delta
	_beam.rotation = _angle
	_sweep.rotation = _angle
	# 광선이 정면(화면 앞)을 스칠 때 돔이 가장 밝다 → 회전 리듬이 읽힌다
	var facing := 0.5 + 0.5 * cos(_angle * 2.0)
	_beam.energy = _beam_energy() * (0.853 + 0.265 * facing)     # 원래 1.45 + 0.45*facing (기준 1.7)
	_glow.energy = _glow_energy() * (0.764 + 0.545 * facing)     # 원래 0.42 + 0.30*facing (기준 0.55)
	_dome.modulate = Lighting.RED_EMISSIVE * (0.7 + 0.5 * facing)
	_sweep_mat.set_shader_parameter("intensity", 0.75 + 0.35 * facing)
	queue_redraw()


## 조명 랩이 고친 기준 세기. 깜빡임·회전 계수는 이 값에 곱해진다.
func _beam_energy() -> float:
	return LightTuning.value("beacon_beam", "energy", 1.7)


func _glow_energy() -> float:
	return LightTuning.value("beacon_glow", "energy", 0.55)


## 조명 랩이 수치를 바꿨을 때. 세기는 매 프레임 _beam_energy() 에서 다시 읽으므로 여기서는 반경·높이만.
func apply_tuning() -> void:
	if _beam:
		_beam.texture_scale = LightTuning.value("beacon_beam", "radius", BEAM_RADIUS) * 2.0 / 256.0 * Lighting.light_range_mul()
		_beam.height = LightTuning.value("beacon_beam", "height", 110.0)
	if _glow:
		_glow.texture_scale = Lighting.scale_for_radius(LightTuning.value("beacon_glow", "radius", GLOW_RADIUS))
		_glow.height = LightTuning.value("beacon_glow", "height", 60.0)


func _draw() -> void:
	# 하우징(어두운 금속 브래킷) + 돔 테두리 — 픽셀 사각 덩어리
	draw_rect(HOUSING, Color(0.16, 0.16, 0.19))
	draw_rect(Rect2(HOUSING.position + Vector2(2, 2), HOUSING.size - Vector2(4, 4)), Color(0.24, 0.24, 0.28))
	draw_rect(Rect2(-12, 6, 24, 3), Color(0.10, 0.10, 0.12))
	draw_rect(DOME, Color(0.42, 0.10, 0.08))
	# 케이지 세로 살 (돔 위)
	for i in range(3):
		draw_rect(Rect2(-7 + i * 6, -18, 2, 11), Color(0.14, 0.13, 0.15))
