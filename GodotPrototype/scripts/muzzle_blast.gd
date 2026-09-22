class_name MuzzleBlast
extends Node2D
## 중화기 총구 화염. 한 노드가 화염·심·충격 링을 _draw 로 그리고, 연기 파티클과 라이트를 자식으로 둔다.
## 로컬 +x 가 포신 방향 — 포신에 붙여 두고 fire() 만 부르면 그 순간의 형태가 매번 다시 뽑힌다.
##
## 구성 (앞 → 뒤):
##   섬광 별   : 총구에서 십자로 뻗는 얇고 긴 빛살 (한두 프레임)
##   화염 원뿔 : 붉은 화염 본체 + 좌우로 터지는 잎 3~4장
##   흰 심     : 원뿔 안쪽의 흰 열 — 글로우 임계(0.85)를 넘겨 번진다
##   연기      : 총구 앞으로 밀려 나갔다가 천천히 떠오르는 회색 뭉치 (월드 좌표)
##   불꽃      : 화약 알갱이 (SparkBurst, 중력·바닥 튕김)
##   라이트    : 짧은 PointLight2D — 주변 벽·인물을 한 프레임 물들인다

const LIFE := 0.075              # 화염이 보이는 시간 (초)
const STAR_LIFE := 0.045         # 십자 빛살은 더 짧게
const SMOKE_EVERY := 0.22        # 연속 사격 중 연기가 다시 피는 최소 간격

var length := 200.0              # 화염 길이 (월드 px — 카메라 zoom 0.625 라 화면에서는 5/8)
var width := 104.0               # 화염 최대 폭
var spark_count := 5
var fx_parent: Node2D            # 불꽃을 담을 월드 층 (변환이 없는 노드 — 없으면 불꽃 생략)
var energy_scale := 1.0          # 총구 라이트 세기 배율 (화염 크기와 따로 줄이고 싶을 때)

var _t := 999.0
var _smoke_cd := 0.0
var _petals: Array = []          # {ang, len, w}
var _len := 0.0
var _w := 0.0
var _light: PointLight2D
var _smoke: CPUParticles2D
var _floor_y := 100000.0


## size = 화염 크기 배율, floor_line = 불꽃이 튕기는 바닥
func setup(size := 1.0, floor_line := 100000.0) -> void:
	length *= size
	width *= size
	_floor_y = floor_line
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_light = PointLight2D.new()
	_light.name = "BlastLight"
	_light.texture = Lighting.radial_texture()
	_light.texture_scale = Lighting.scale_for_radius(LightTuning.value("muzzle", "radius", 420.0) * size)
	_light.color = Lighting.GUN_LIGHT
	_light.height = LightTuning.value("muzzle", "height", Lighting.FLASH_HEIGHT)
	_light.position = Vector2(length * 0.4, 0)
	_light.enabled = false
	add_child(_light)
	Lighting.register_dynamic(_light, 1.6, "shot")

	_smoke = CPUParticles2D.new()
	_smoke.name = "Smoke"
	_smoke.emitting = false
	_smoke.one_shot = true
	_smoke.explosiveness = 0.7
	_smoke.amount = 7
	_smoke.lifetime = 0.9
	_smoke.local_coords = false                    # 총구가 움직여도 연기는 뱉어진 자리에 남는다
	_smoke.texture = Lighting.smoke_canvas_texture()
	_smoke.direction = Vector2.RIGHT
	_smoke.spread = 16.0
	_smoke.initial_velocity_min = 160.0 * size
	_smoke.initial_velocity_max = 420.0 * size
	_smoke.gravity = Vector2(0, -70.0)
	_smoke.damping_min = 260.0
	_smoke.damping_max = 420.0
	_smoke.scale_amount_min = 0.5 * size
	_smoke.scale_amount_max = 1.1 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1.0, 1.5))
	_smoke.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.80, 0.74, 0.55))
	grad.set_color(1, Color(0.42, 0.43, 0.48, 0.0))
	_smoke.color_ramp = grad
	_smoke.position = Vector2(length * 0.5, 0)
	add_child(_smoke)


## 한 발. power 1.0 = 기본 크기, world_dir 을 주면 불꽃이 그 방향으로 흩어진다
## (좌우 반전된 층 안에서는 global_rotation 을 믿을 수 없어 방향을 직접 받는다)
func fire(power := 1.0, world_dir := Vector2.ZERO) -> void:
	_t = 0.0
	_len = length * randf_range(0.82, 1.2) * power
	_w = width * randf_range(0.8, 1.25) * power
	_petals.clear()
	for i in range(randi_range(3, 4)):
		_petals.append({
			"ang": randf_range(-0.85, 0.85),
			"len": _len * randf_range(0.35, 0.78),
			"w": _w * randf_range(0.2, 0.4),
		})
	_light.enabled = true
	_light.energy = LightTuning.value("muzzle", "energy", 2.6) * power * energy_scale
	if _smoke_cd <= 0.0:
		_smoke_cd = SMOKE_EVERY
		_smoke.restart()
	# 화약 알갱이 — 총구 앞으로 흩어져 바닥으로 떨어진다 (월드 층에 뿌린다)
	if spark_count > 0 and fx_parent != null:
		var dir := world_dir.normalized() if world_dir.length_squared() > 0.0 else Vector2.RIGHT.rotated(global_rotation)
		var sb := SparkBurst.spawn(fx_parent, _floor_y)
		sb.burst(global_position + dir * _len * 0.5, spark_count,
			dir, 0.5, Vector2(220, 760),
			Color(1.0, 0.92, 0.72), Color(1.0, 0.34, 0.10), Vector2(0.18, 0.5), 2400.0, 3.0, false)
	queue_redraw()


func _process(delta: float) -> void:
	_smoke_cd = maxf(_smoke_cd - delta, 0.0)
	if _t <= LIFE:
		_t += delta
		queue_redraw()
	if _light.enabled:
		_light.energy = maxf(_light.energy - delta * 26.0, 0.0)
		if _light.energy <= 0.05:
			_light.enabled = false


func _draw() -> void:
	if _t > LIFE:
		return
	var k := 1.0 - _t / LIFE                       # 1 → 0
	var shape := sqrt(k)                           # 크기는 늦게 줄고 밝기만 먼저 빠진다
	var l := _len * (0.72 + 0.28 * shape)
	var w := _w * shape
	var body := Color(1.0, 0.36, 0.14, 1.0) * (0.55 + 0.45 * k)
	var core := Color(1.0, 0.88, 0.66, 1.0) * (0.5 + 0.5 * k)

	# 십자 빛살 — 총구에서 짧게 번쩍인다
	if _t <= STAR_LIFE:
		var sk := 1.0 - _t / STAR_LIFE
		var spike := Color(1.0, 0.72, 0.45, 1.0) * sk
		var sl := _len * 1.5 * sk
		var st := maxf(_w * 0.09, 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-sl * 0.35, -st), Vector2(sl, -st * 0.35), Vector2(sl, st * 0.35), Vector2(-sl * 0.35, st),
		]), spike)
		var sv := sl * 0.55
		draw_colored_polygon(PackedVector2Array([
			Vector2(-st, -sv), Vector2(st * 0.4, -sv), Vector2(st * 0.4, sv), Vector2(-st, sv),
		]), spike * 0.8)

	# 좌우로 터지는 잎
	for p in _petals:
		var a: float = p["ang"]
		var pl: float = p["len"] * (0.55 + 0.45 * shape)
		var pw: float = p["w"] * shape
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -pw * 0.6),
			Vector2(pl * 0.55, -pw).rotated(a),
			Vector2(pl * 1.2, 0).rotated(a),
			Vector2(pl * 0.55, pw).rotated(a),
			Vector2(0, pw * 0.6),
		]), body * 0.8)

	# 화염 본체 (뭉툭한 원뿔)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -w * 0.42),
		Vector2(l * 0.3, -w * 0.5), Vector2(l * 0.62, -w * 0.42), Vector2(l * 0.9, -w * 0.18),
		Vector2(l * 1.06, 0),
		Vector2(l * 0.9, w * 0.18), Vector2(l * 0.62, w * 0.42), Vector2(l * 0.3, w * 0.5),
		Vector2(0, w * 0.42),
	]), body)

	# 흰 심 — 총구 바로 앞의 뜨거운 덩어리 (글로우가 여기서 번진다)
	var cl := l * 0.55
	var cw := w * 0.26
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -cw), Vector2(cl * 0.55, -cw * 0.85), Vector2(cl, 0), Vector2(cl * 0.55, cw * 0.85), Vector2(0, cw),
	]), core)
