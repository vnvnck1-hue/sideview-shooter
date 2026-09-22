class_name BrokenWire
extends Node2D
## 천장에서 늘어진 끊긴 전선. 절차적 물리(버렛 체인)로 흔들리고, 총알이 스치거나 탄착 충격·플레이어가
## 지나가면 튕긴다. 끝의 드러난 구리선에서 파란 전기가 빠지직 튀며(아크 번개 + 스파크 + 라이트) 아래로 흩어진다.

const SEGMENTS := 12
const WIRE_COLOR := Color(0.10, 0.10, 0.12)
const WIRE_HILITE := Color(0.22, 0.22, 0.26)
const COPPER := Color(0.95, 0.55, 0.25)

var length := 200.0
var floor_y := 486.0
var _rope := RopeChain.new()           # 줄의 물리는 공용 (scripts/rope_chain.gd — 천장 램프도 같은 것을 쓴다)
var _line: Line2D
var _hilite: Line2D
var _copper: Line2D
var _arc: Line2D
var _light: PointLight2D
var _sparks: SparkBurst
var _t := 0.0
var _next_crackle := 0.6
var _crackle_left := 0.0
var _arc_target := Vector2.ZERO
var _arc_refresh := 0.0
var _wind_phase := randf() * TAU
var _energy := 0.0


func setup(wire_length: float, floor_line: float) -> void:
	length = wire_length
	floor_y = floor_line
	_rope.setup(global_position, length, SEGMENTS, floor_y)

	_line = Line2D.new()
	_line.width = 7.0
	_line.default_color = WIRE_COLOR
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.top_level = true
	add_child(_line)
	_hilite = Line2D.new()
	_hilite.width = 2.0
	_hilite.default_color = WIRE_HILITE
	_hilite.top_level = true
	add_child(_hilite)
	_copper = Line2D.new()
	_copper.width = 3.0
	_copper.default_color = COPPER
	_copper.modulate = Color(1.6, 1.6, 1.6, 1.0)
	_copper.top_level = true
	add_child(_copper)

	_arc = Line2D.new()
	_arc.width = 2.5
	_arc.default_color = Lighting.ARC_BLUE
	_arc.modulate = Lighting.EMISSIVE
	_arc.visible = false
	_arc.top_level = true
	add_child(_arc)

	_light = PointLight2D.new()
	_light.texture = Lighting.radial_texture()
	_light.texture_scale = Lighting.scale_for_radius(LightTuning.value("wire", "radius", 260.0))
	_light.color = Lighting.ARC_BLUE
	_light.height = LightTuning.value("wire", "height", 80.0)
	LightTuning.register(self, "wire")
	_light.energy = 0.0
	_light.enabled = false
	_light.top_level = true
	add_child(_light)
	Lighting.register_dynamic(_light, 1.3, "ambient")           # 흔들리는 전선 끝을 따라 그림자가 춤춘다

	_sparks = SparkBurst.spawn(self, floor_y, true)
	_sparks.top_level = true
	_next_crackle = randf_range(0.3, 1.2)


func tip() -> Vector2:
	return _rope.tip()


## 먼지 레이어용 광원 정보 (아크가 튈 때만 켜진다)
func light_info() -> Dictionary:
	return {"pos": tip(), "color": Lighting.ARC_BLUE * (_energy * 0.6), "radius": 260.0, "lamp": false}


## 총알 궤적(from→to)이 스치면 그 방향으로 튀고, 탄착점 충격파가 가까우면 밀린다
func apply_shot(from: Vector2, to: Vector2) -> void:
	_rope.apply_shot(from, to)


## 플레이어 몸이 지나가며 밀친다. pos: 발 위치, vel_x: 이동 속도
func apply_body(pos: Vector2, vel_x: float) -> void:
	_rope.apply_body(pos, vel_x)


func _physics_process(delta: float) -> void:
	_t += delta
	_rope.anchor = global_position
	_rope.step(delta)
	var pts := _rope.points()
	_line.points = pts
	_hilite.points = pts
	_copper.points = PackedVector2Array([pts[SEGMENTS - 1].lerp(pts[SEGMENTS], 0.45), pts[SEGMENTS]])

	_update_crackle(delta)


func _update_crackle(delta: float) -> void:
	if _crackle_left > 0.0:
		_crackle_left -= delta
		_arc_refresh -= delta
		# 몇 프레임마다 번개 모양 갈아끼움
		if _arc_refresh <= 0.0:
			_arc_refresh = randf_range(0.02, 0.05)
			_build_arc()
		var n := randf_range(0.5, 1.0)
		_energy = 2.4 * n
		_light.energy = _energy
		_light.position = tip()
		_light.enabled = true
		_arc.visible = true
		# 스파크가 연속으로 조금씩 튄다
		if randf() < 0.55:
			_sparks.burst(tip(), randi_range(1, 3), Vector2(0, 1), 1.4, Vector2(120, 420),
				Color(0.9, 0.95, 1.0), Color(0.45, 0.6, 1.0), Vector2(0.2, 0.6), 2400.0, 2.2, false)
		if _crackle_left <= 0.0:
			_arc.visible = false
			_light.enabled = false
			_energy = 0.0
			_next_crackle = randf_range(0.35, 1.9)
		return
	_next_crackle -= delta
	if _next_crackle <= 0.0:
		_crackle_left = randf_range(0.05, 0.16)
		_arc_refresh = 0.0
		# 아크 목표: 아래·옆 30~90px 지점 (공기 중 방전) — 바닥에 가까우면 바닥으로
		var t := tip()
		var ang := randf_range(0.3, PI - 0.3)         # 아래 반원
		var dist := randf_range(30.0, 90.0)
		_arc_target = t + Vector2(cos(ang), sin(ang)) * dist
		if _arc_target.y > floor_y:
			_arc_target.y = floor_y
		# 방전 반동: 끝이 살짝 튄다
		_rope.nudge_tip(-(_arc_target - t).normalized() * randf_range(60.0, 160.0))
		# 큰 스파크 뭉치
		_sparks.burst(t, randi_range(5, 12), Vector2(0, 1), 1.6, Vector2(200, 640),
			Color(0.95, 0.98, 1.0), Color(0.4, 0.55, 1.0), Vector2(0.3, 0.8), 2400.0, 2.5, false)


func _build_arc() -> void:
	var a := tip()
	var b := _arc_target
	var pts := PackedVector2Array()
	var n := 7
	for i in range(n + 1):
		var k := float(i) / n
		var p := a.lerp(b, k)
		if i > 0 and i < n:
			var perp := (b - a).orthogonal().normalized()
			p += perp * randf_range(-12.0, 12.0) * sin(k * PI)
		pts.append(p)
	_arc.points = pts
	_arc.width = randf_range(1.5, 3.5)


func _draw() -> void:
	# 천장 브래킷 (끊긴 도관 끝)
	draw_rect(Rect2(-9, -6, 18, 10), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(-6, 2, 12, 5), Color(0.09, 0.09, 0.11))
