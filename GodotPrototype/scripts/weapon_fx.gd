class_name WeaponFx
extends Node2D
## 새 무기 전용 섬광 · 광선 · 전기 연출. 전부 가산 발광(ADD) + 무조명이고, 좌표를 4px(아트 1픽셀) 격자에 붙여
## 기존 소총 잔상(Bullet)과 같은 픽셀 결로 그린다. 수명은 짧게(0.1~0.4초) — 길게 남으면 속도감이 죽는다.
##   muzzle     : 총구 화염 (불독 = 넓은 산탄 폭발 · 코일 = 십자 섬광 · 아크 = 턱 사이 방전)
##   beam       : 코일 레일 — 총구부터 벽까지 한 번에 그어지고 얇아지며 사라진다 (points[0] → points[1])
##   pierce     : 코일이 몸을 꿰뚫은 자리 (진행 방향으로 찢어지는 섬광)
##   impact     : 작은 탄착 (코일 벽 · 아크 공용)
##   arc_burst  : 아크 구체가 터지는 자리 (방사형 번개 + 각진 충격파)
##   chain      : 아크 연쇄 번개 (points 를 차례로 잇는다, 0.03초마다 모양이 바뀐다)
##   stun       : 감전된 몬스터 위의 잔류 전기
##   charge     : (쓰지 않음 — 충전은 Player 가 그린다)

const PX := 4.0
var kind := "impact"
var weapon := "bulldog"
var age := 0.0
var lifetime := 0.3
var direction := Vector2.RIGHT
var points := PackedVector2Array()
var sparks: Array = []
var strength := 1.0
var _seed := 0
static var _add_mat: CanvasItemMaterial


static func spawn(host: Node, id: String, type: String, at: Vector2, dir := Vector2.RIGHT, power := 1.0) -> WeaponFx:
	var fx := WeaponFx.new()
	fx.weapon = id
	fx.kind = type
	fx.position = at
	fx.direction = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	fx.strength = power
	host.add_child(fx)
	return fx


static func _material() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _add_mat


func _ready() -> void:
	z_index = 12
	material = _material()
	_seed = randi()
	match kind:
		"muzzle":
			lifetime = 0.1 if weapon == WeaponCatalog.BULLDOG else 0.12
		"beam":
			lifetime = 0.24
		"pierce":
			lifetime = 0.28
		"arc_burst":
			lifetime = 0.42
		"chain":
			lifetime = 0.34
		"stun":
			lifetime = 0.22
		_:
			lifetime = 0.26
	var count := 0
	var speed := Vector2(160, 520)
	match kind:
		"muzzle":
			count = 14 if weapon == WeaponCatalog.BULLDOG else 8
			speed = Vector2(500, 1300)
		"pierce":
			count = 14
			speed = Vector2(350, 1100)
		"arc_burst":
			count = 18
			speed = Vector2(220, 820)
		"impact":
			count = 10
	for i in range(count):
		var v: Vector2
		if kind == "muzzle":
			v = direction.rotated(randf_range(-0.42, 0.42)) * randf_range(speed.x, speed.y)
		elif kind == "pierce":
			v = direction.rotated(randf_range(-0.7, 0.7)) * randf_range(speed.x, speed.y)
		else:
			v = Vector2.from_angle(randf() * TAU) * randf_range(speed.x, speed.y)
		sparks.append({"v": v * strength, "size": PX * (1.0 if randf() < 0.7 else 1.5), "life": randf_range(0.10, 0.28)})


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
	else:
		queue_redraw()


func _snap(p: Vector2) -> Vector2:
	return (p / PX).round() * PX


## 두 점 사이 번개. seed 가 같으면 같은 모양 — 0.03초마다 seed 를 바꿔 깜빡이듯 모양이 튄다
func _bolt(a: Vector2, b: Vector2, jag: float, seed_v: int, segs := 7) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := PackedVector2Array([_snap(a)])
	var normal := (b - a).normalized().orthogonal()
	for j in range(1, segs):
		var t := float(j) / float(segs)
		pts.append(_snap(a.lerp(b, t) + normal * rng.randf_range(-jag, jag)))
	pts.append(_snap(b))
	return pts


func _draw() -> void:
	var c: Color = WeaponCatalog.data(weapon).color
	var k := maxf(0.0, 1.0 - age / lifetime)
	var flick := int(age / 0.03)
	match kind:
		"muzzle":
			_draw_muzzle(c, k)
		"beam":
			_draw_beam(c, k)
		"pierce":
			_draw_pierce(c, k)
		"arc_burst":
			_draw_arc_burst(c, k, flick)
		"chain":
			_draw_chain(c, k, flick)
		"stun":
			var path := PackedVector2Array()
			for i in range(7):
				path.append(_snap(Vector2((i - 3) * 10, sin(i * 7 + age * 40.0) * 16)))
			draw_polyline(path, Color(c, k), PX)
			draw_polyline(path, Color(0.8, 1, 1, k), 2.0)
		_:
			var radius := (14.0 + age * 190.0) * strength
			_draw_square_ring(radius, Color(c, k * k), PX)
			var pulse := maxf(0.0, 1.0 - age / 0.07)
			if pulse > 0.0:
				draw_rect(Rect2(_snap(Vector2(-10, -10) * strength), Vector2(20, 20) * strength), Color(1, 1, 0.9, pulse))
	_draw_sparks(c)


func _draw_sparks(c: Color) -> void:
	for s in sparks:
		if age > s.life:
			continue
		var p: Vector2 = _snap(s.v * age * (1.0 - age * 1.6) + Vector2(0, 600 * age * age))
		var alpha: float = maxf(0.0, 1.0 - age / s.life)
		var tail: Vector2 = s.v.normalized() * 14.0 * alpha
		draw_line(p - tail, p, Color(c.lightened(0.4), alpha), s.size)


func _draw_square_ring(r: float, col: Color, w: float) -> void:
	var h := roundf(r / PX) * PX
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), col, false, w)


func _draw_muzzle(c: Color, k: float) -> void:
	var d := direction
	var n := d.orthogonal()
	# 3단계로 뚝뚝 줄어든다 (픽셀 애니 3장처럼) — 부드럽게 줄면 화염이 "흐른다"
	var step := 1.0 if age < lifetime * 0.34 else (0.62 if age < lifetime * 0.67 else 0.3)
	var s := strength * step
	if weapon == WeaponCatalog.BULLDOG:
		var length := 190.0 * s
		var width := 62.0 * s
		var body := PackedVector2Array([
			Vector2.ZERO, d * length * 0.22 + n * width * 0.7, d * length * 0.5 + n * width * 0.45,
			d * length * 0.72 + n * width * 0.8, d * length, d * length * 0.72 - n * width * 0.8,
			d * length * 0.5 - n * width * 0.45, d * length * 0.22 - n * width * 0.7])
		for i in range(body.size()):
			body[i] = _snap(body[i])
		draw_colored_polygon(body, Color(c, 0.9 * k + 0.1))
		var core := PackedVector2Array([Vector2.ZERO, _snap(d * length * 0.3 + n * width * 0.32),
			_snap(d * length * 0.62), _snap(d * length * 0.3 - n * width * 0.32)])
		draw_colored_polygon(core, Color(1.0, 0.92, 0.6, 1.0))
		# 산탄 부채 — 알갱이가 흩어지는 방향으로 짧은 불줄기
		for i in range(5):
			var a := (float(i) - 2.0) * 0.16
			var r := d.rotated(a)
			draw_line(_snap(r * length * 0.4), _snap(r * length * (1.25 + 0.1 * absf(float(i) - 2.0))), Color(1, 0.75, 0.35, k), PX * 1.5)
		# 옆으로 새는 가스
		for side in [-1.0, 1.0]:
			draw_line(_snap(d * 12.0), _snap(d * 40.0 * s + n * side * 58.0 * s), Color(c, k), PX * 2.0)
	elif weapon == WeaponCatalog.COIL:
		var length := 230.0 * s
		draw_line(_snap(-d * 24.0 * s), _snap(d * length), Color(c, 0.8), PX * 3.0 * s + 2.0)
		draw_line(_snap(-d * 16.0 * s), _snap(d * length * 0.8), Color(0.85, 1, 1, 1), PX)
		draw_line(_snap(-n * 70.0 * s + d * 20.0), _snap(n * 70.0 * s + d * 20.0), Color(c, k), PX)
		_draw_square_ring(26.0 + age * 260.0, Color(c, k), PX)
		draw_rect(Rect2(_snap(Vector2(-14, -14) * s), Vector2(28, 28) * s), Color(0.9, 1, 1, 1))
	else:
		for i in range(4):
			var tip := d.rotated(randf_range(-0.5, 0.5)) * randf_range(60.0, 130.0) * s
			draw_polyline(_bolt(Vector2.ZERO, tip, 14.0, _seed + i + int(age / 0.03) * 13, 4), Color(c, k), PX)
		_draw_square_ring(18.0 + age * 220.0, Color(c, k), PX)
		draw_rect(Rect2(_snap(Vector2(-12, -12) * s), Vector2(24, 24) * s), Color(0.85, 1, 0.95, 1))


func _draw_beam(c: Color, k: float) -> void:
	if points.size() < 2:
		return
	var a := points[0] - global_position
	var b := points[1] - global_position
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var w := pow(k, 1.6)
	# 바깥 광휘 → 코어 → 흰 심. 뒤에서부터(총구 쪽) 먼저 꺼져 탄이 "지나간" 방향이 읽힌다
	var tail := a.lerp(b, clampf((age - 0.04) / (lifetime - 0.04), 0.0, 1.0) * 0.85)
	draw_line(_snap(tail), _snap(b), Color(c, 0.35 * w), 40.0 * w + 4.0)
	draw_line(_snap(tail), _snap(b), Color(c, 0.9 * w), 16.0 * w + 4.0)
	draw_line(_snap(tail), _snap(b), Color(0.9, 1, 1, w), 6.0 * w + 2.0)
	# 코일 나선 — 광선을 감싸고 돌며 흩어지는 점
	var length := a.distance_to(b)
	var count := int(length / 36.0)
	for i in range(count):
		var t := float(i) / maxf(float(count), 1.0)
		if a.lerp(b, t).distance_to(a) < tail.distance_to(a):
			continue
		var ph := t * length / 38.0 + age * 30.0
		var off := sin(ph) * (18.0 + age * 90.0)
		var p := a.lerp(b, t) + n * off + n * sin(t * 57.0 + _seed) * age * 60.0
		var alpha := k * (0.55 + 0.45 * cos(ph))
		draw_rect(Rect2(_snap(p) - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), Color(c.lightened(0.3), alpha))


func _draw_pierce(c: Color, k: float) -> void:
	var d := direction
	var n := d.orthogonal()
	var s := strength
	var pulse := maxf(0.0, 1.0 - age / 0.08)
	# 진행 방향으로 찢어지는 섬광: 뒤쪽 짧게, 앞쪽 길게
	draw_line(_snap(-d * 30.0 * s), _snap(d * (70.0 + age * 520.0) * s), Color(c, k), PX * 3.0 * k + PX)
	for side in [-1.0, 1.0]:
		draw_line(_snap(d * 10.0), _snap((d * 0.6 + n * side * 0.8).normalized() * (40.0 + age * 260.0) * s), Color(c, k * 0.9), PX)
	_draw_square_ring((18.0 + age * 200.0) * s, Color(c, k * k), PX)
	if pulse > 0.0:
		draw_rect(Rect2(_snap(Vector2(-16, -16) * s), Vector2(32, 32) * s), Color(1, 1, 1, pulse))


func _draw_arc_burst(c: Color, k: float, flick: int) -> void:
	var s := strength
	var r := (40.0 + age * 330.0) * s
	for i in range(8):
		var a := float(i) * TAU / 8.0 + float(_seed % 7)
		var tip := Vector2.from_angle(a) * r * randf_range(0.7, 1.0)
		draw_polyline(_bolt(Vector2.ZERO, tip, 16.0 * s, _seed + i * 31 + flick * 7, 5), Color(c, k), PX)
	# 각진 충격파 (톱니)
	var ring := PackedVector2Array()
	for i in range(17):
		ring.append(_snap(Vector2.from_angle(float(i) * TAU / 16.0) * r * (1.0 if i % 2 == 0 else 0.74)))
	draw_polyline(ring, Color(c, k * k), PX)
	var pulse := maxf(0.0, 1.0 - age / 0.09)
	if pulse > 0.0:
		draw_rect(Rect2(_snap(Vector2(-26, -26) * s), Vector2(52, 52) * s), Color(0.85, 1, 0.95, pulse))


func _draw_chain(c: Color, k: float, flick: int) -> void:
	for i in range(1, points.size()):
		var a := points[i - 1] - global_position
		var b := points[i] - global_position
		var seg := _bolt(a, b, 20.0, _seed + i * 17 + flick * 5, 9)
		draw_polyline(seg, Color(c, k * 0.35), 16.0)
		draw_polyline(seg, Color(c, k), PX * 1.5)
		draw_polyline(seg, Color(0.85, 1, 1, k), 2.0)
		var h := roundf((20.0 + age * 90.0) / PX) * PX
		draw_rect(Rect2(_snap(b) - Vector2(h, h), Vector2(h, h) * 2.0), Color(c, k * 0.6), false, PX)
