class_name WeaponProjectile
extends Node2D
## 새 무기 탄 — 불독(산탄) · 코일랜스(관통 레일) · 아크위버(전기 구체, 버그봇).
##
## ## 맞는 규칙은 기존 소총과 같다
## 탄은 **조준점(마우스)까지** 날아가 **그 자리에 있는 것**을 맞힌다 (Room.hit_at). 가는 길에 탄을 가로채는 것은
## 싸움이 벌어지는 평면에 있는 것뿐이다 — 몬스터(몸통과 선분 교차)와 밟고 서는 장애물(Room.clip_shot).
## 뒷벽에 붙은 배경 프랍 · 램프 · 유리 · 비상등은 **조준점에 있을 때만** 맞는다.
##
## 예전 구현은 비행 경로를 10px 간격으로 hit_at 해서 **처음 겹치는 사물**에 탄을 세웠다. 이 게임은 옆에서 보는
## 화면이라 플레이어 뒤에 늘 사물함·단말기가 있고, 그래서 탄이 총구 바로 앞 가장 가까운 사물에 박혔다.
##
## ## 속도감
## 궤적과 탄착 연출은 기존 소총 Bullet(탄속 20800px/s)을 색만 바꿔 쓴다 — 탄이 "보이게 느리게" 날아가지 않는다.
## 불독 · 코일은 쏘는 순간 판정한다(기존 소총과 같다). 아크 구체만 실제로 날아가며(2900px/s) 도착해서 터진다.

const ARC_RADIUS := 26.0             # 아크 구체 판정 반경 (몸통 선분 교차에 더하는 여유)

var weapon := "bulldog"
var room: Node2D
var camera: Node
var host_node: Node
var total_hits := 0                  # 이번 한 발이 몬스터에 들어간 횟수 (Main 이 히트스톱 판단에 쓴다)
var kills := 0
var lights: WeaponLightPool
var rays: Array = []                 # 아크 구체 비행 상태 [{pos, origin, end, dir, alive}] (검사 도구 호환 이름)
var age := 0.0
var _orb_tex: Texture2D
var _tail_t := 0.0


static func fire(host: Node, world_room: Node2D, id: String, from: Vector2, toward: Vector2, view_camera: Node = null) -> WeaponProjectile:
	var p := WeaponProjectile.new()
	p.weapon = id
	p.room = world_room
	p.camera = view_camera
	p.host_node = host
	host.add_child(p)
	match id:
		WeaponCatalog.COIL:
			p._fire_coil(from, toward)
		WeaponCatalog.ARC:
			p._launch_arc(from, toward)
		_:
			p._fire_bulldog(from, toward)
	return p


func _ready() -> void:
	z_index = 11
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	lights = WeaponLightPool.get_pool(room)


# ── 공용 판정 ─────────────────────────────────────────────────────────────

## 선분 a→b 와 교차하는 몬스터를 가까운 순으로 [{node, t, point}]. 픽셀 판정(ray_hit_t)이 있으면 그걸 쓴다.
static func sweep_monsters(world_room: Node2D, a: Vector2, b: Vector2, pad := 0.0) -> Array:
	var hits: Array = []
	for m in world_room.monsters:
		if not is_instance_valid(m) or m.is_queued_for_deletion() or m.is_dead():
			continue
		var t := -1.0
		if pad <= 0.0 and m.has_method("ray_hit_t"):
			t = m.ray_hit_t(a, b)
		else:
			t = _rect_t(a, b, m.hit_rect().grow(pad))
		if t >= 0.0:
			hits.append({"node": m, "t": t, "point": a.lerp(b, t)})
	hits.sort_custom(func(x, y): return x.t < y.t)
	return hits


## 조준점의 환경 판정. 고인 물 위 바닥은 착수로 바꾼다 (Main._spawn_shot 과 같다)
static func env_hit(world_room: Node2D, point: Vector2) -> Dictionary:
	var hit: Dictionary = world_room.hit_at(point)
	var water = world_room.get("water")
	if (hit.get("kind", "none") == "wall" or hit.get("kind", "none") == "none") and water != null and water.contains(point):
		hit = {"kind": "water", "node": water}
	return hit


## 환경 탄착 반응 — 기존 소총과 같은 표. 반환값은 Bullet.Impact (탄착 연출 종류)
static func react(world_room: Node2D, hit: Dictionary, point: Vector2, from: Vector2, power: float, view_camera: Node) -> int:
	var dir := signf(point.x - from.x)
	var shake := 0.0
	var impact: int = Bullet.Impact.WALL
	var node = hit.get("node")
	match hit.get("kind", "none"):
		"water":
			node.bullet_splash(point.x, dir)
			impact = Bullet.Impact.WATER
			shake = 1.0
		"lamp":
			var broke: bool = node.hit_lamp(point, dir)
			impact = Bullet.Impact.GLASS
			shake = 3.0 if broke else 1.4
		"beacon":
			node.break_light()
			impact = Bullet.Impact.GLASS
			shake = 2.5
		"glass":
			node.crack(point)
			impact = Bullet.Impact.GLASS
			shake = 1.5
		"prop":
			if node is Object and is_instance_valid(node):
				node.hit(dir, point.y, point, power)
			impact = node.impact_kind() if node is Object and is_instance_valid(node) and node.has_method("impact_kind") else Bullet.Impact.PROP
			shake = 0.8 * maxf(power - 1.0, 0.0)
		"monster":
			impact = Bullet.Impact.FLESH
	if shake > 0.0 and is_instance_valid(view_camera):
		view_camera.add_shake(shake)
	return impact


## 탄흔 — 벽·뒷벽·프랍(뚫고 들어간 앞면)에만. Main._leave_mark 와 같은 규칙
static func leave_mark(world_room: Node2D, hit: Dictionary, point: Vector2, dir: Vector2, power: float) -> void:
	var mark_host = null
	match hit.get("kind", "none"):
		"wall", "none":
			if world_room.has_method("stain_props"):
				for sp in world_room.stain_props():
					if is_instance_valid(sp) and sp.is_solid_at(point):
						mark_host = sp
						break
		"prop":
			var pr = hit.get("node")
			if pr is Object and is_instance_valid(pr) and pr.has_method("is_solid_at") and pr.is_solid_at(point):
				mark_host = pr
		_:
			return
	if not world_room.has_method("add_stain"):
		return          # 검사용 가짜 방
	var on_floor: bool = point.y >= float(world_room.floor_y) - BulletMark.CELL * 2.0
	BulletMark.spawn(world_room, point, dir, mark_host, power, on_floor)


## 몬스터 한 대에 한 방. 몬스터만 잠깐 멎는 경직(weapon_hitstop_left)과 흔들림까지.
func _hit_monster(m: Node, point: Vector2, dir: Vector2, power: float, damage: int, freeze: float) -> void:
	if not is_instance_valid(m) or m.is_dead():
		return
	m.hit(point, signf(dir.x) if dir.x != 0.0 else 1.0, power, damage)
	if freeze > 0.0 and m.get("weapon_hitstop_left") != null:
		m.weapon_hitstop_left = maxf(float(m.weapon_hitstop_left), freeze)
	total_hits += 1
	if m.is_dead():
		kills += 1


func _tracer(from: Vector2, to: Vector2, impact: int, power: float, width: float, tint: Color, light := true, sound := true) -> Bullet:
	var b := Bullet.new()
	b.power = power
	b.width_scale = width
	b.tint = tint
	b.light_enabled = light
	b.impact_sound = sound
	b.setup(from, to)
	b.floor_y = float(room.floor_y) + 2.0
	b.impact_kind = impact
	host_node.add_child(b)
	return b


func _shake(amount: float) -> void:
	if is_instance_valid(camera):
		camera.add_shake(amount)


# ── 불독: 산탄 7발 ───────────────────────────────────────────────────────────

## 7알이 조준점 거리에서 부채꼴로 퍼진다 (조준점 앞뒤 ±7%). 가까운 물체를 겨누면 그 물체에서 멈춘다.
## 한 몬스터에 여러 알이 박히면 **마지막 알에 위력을 몰아** 넉백·체액·육편이 박힌 알 수만큼 커진다 —
## 가까이서 쏠수록 크게 날아간다. 피해는 알당 1, 대상당 max_per_target 까지.
func _fire_bulldog(from: Vector2, toward: Vector2) -> void:
	var d := WeaponCatalog.data(WeaponCatalog.BULLDOG)
	var aim := toward - from
	var dir := aim.normalized() if aim.length() > 1.0 else Vector2.RIGHT
	var dist := maxf(aim.length(), 160.0)
	var count := int(d.pellets)
	var spread := float(d.spread)
	var tint := Color(1.0, 0.55, 0.2)
	var per_target := {}
	for i in range(count):
		var lane := (float(i) - (count - 1) * 0.5) / ((count - 1) * 0.5)
		var pd := dir.rotated(lane * spread + randf_range(-0.3, 0.3) * spread / 3.0)
		var end: Vector2 = room.clip_shot(from, from + pd * dist * randf_range(0.93, 1.1))
		var sweep := sweep_monsters(room, from, end, 6.0)
		var point := end
		var impact: int
		var hit: Dictionary
		if not sweep.is_empty():
			var m: Node = sweep[0].node
			point = sweep[0].point
			impact = Bullet.Impact.FLESH
			var key := m.get_instance_id()
			if not per_target.has(key):
				per_target[key] = {"node": m, "count": 0, "point": point, "dir": pd}
			per_target[key].count += 1
		else:
			hit = env_hit(room, end)
			if hit.get("kind") == "monster":
				var m2: Node = hit.node
				impact = Bullet.Impact.FLESH
				var key2 := m2.get_instance_id()
				if not per_target.has(key2):
					per_target[key2] = {"node": m2, "count": 0, "point": point, "dir": pd}
				per_target[key2].count += 1
			else:
				impact = react(room, hit, point, from, 0.9, camera)
				leave_mark(room, hit, point, pd, 0.8)
		_tracer(from, point, impact, 0.85, 1.3, tint, i % 3 == 1, i == 3 or (impact != Bullet.Impact.FLESH and i % 3 == 0))
		room.notify_shot(from, point)
	var cap := int(d.max_per_target)
	for entry in per_target.values():
		var m: Node = entry.node
		var n: int = entry.count
		var shots := mini(n, cap)
		for s in range(shots):
			var last := s == shots - 1
			_hit_monster(m, entry.point, entry.dir, 0.9 + (0.42 * n if last else 0.0), int(d.damage), 0.07 if last else 0.0)
		_shake(1.2 + 0.7 * n)
		lights.pulse(get_instance_id() + 991, entry.point, tint, 280.0, 3.0, 0.14)


# ── 코일랜스: 관통 레일 ──────────────────────────────────────────────────────

## 총구에서 벽(또는 장애물)까지 **한 번에** 긋는다. 선 위의 몬스터를 가까운 순으로 pierce 마리까지 꿰뚫고,
## 조준점에 램프·유리·프랍이 있으면 그것도 맞힌 채 지나간다. 끝에서 벽을 맞고 탄흔을 남긴다.
func _fire_coil(from: Vector2, toward: Vector2) -> void:
	var d := WeaponCatalog.data(WeaponCatalog.COIL)
	var c: Color = d.color
	var aim := toward - from
	var dir := aim.normalized() if aim.length() > 1.0 else Vector2.RIGHT
	var end: Vector2 = room.clip_shot(from, from + dir * 4200.0)
	var pierce := int(d.pierce)
	var sweep := sweep_monsters(room, from, end, 10.0)
	for i in range(mini(sweep.size(), pierce)):
		var m: Node = sweep[i].node
		var p: Vector2 = sweep[i].point
		_hit_monster(m, p, dir, float(d.power), int(d.damage), 0.09)
		WeaponFx.spawn(host_node, WeaponCatalog.COIL, "pierce", p, dir, 1.2)
		lights.pulse(get_instance_id() + 991 + i, p, c, 320.0, 3.6, 0.16)
		_shake(2.2)
	# 조준점의 배경 표적 (지나가는 길에 맞힌다)
	if from.distance_to(toward) + 8.0 < from.distance_to(end):
		var aimed := env_hit(room, toward)
		if aimed.get("kind") in ["lamp", "beacon", "glass", "prop"]:
			var ai := react(room, aimed, toward, from, float(d.power), camera)
			_tracer(toward - dir * 2.0, toward, ai, 1.3, 0.1, c, false, true)
	var hit := env_hit(room, end)
	var impact: int = Bullet.Impact.FLESH if hit.get("kind") == "monster" else react(room, hit, end, from, 1.6, camera)
	if hit.get("kind") == "monster":
		_hit_monster(hit.node, end, dir, float(d.power), int(d.damage), 0.09)
	else:
		leave_mark(room, hit, end, dir, 1.4)
	_tracer(from, end, impact, 1.8, 2.4, c, true, true)
	var beam := WeaponFx.spawn(host_node, WeaponCatalog.COIL, "beam", from, dir)
	beam.points = PackedVector2Array([from, end])
	WeaponFx.spawn(host_node, WeaponCatalog.COIL, "impact", end, dir, 1.3)
	lights.pulse(get_instance_id(), from.lerp(end, 0.5), c, 520.0, 2.6, 0.12)
	room.notify_shot(from, end)


# ── 아크위버: 날아가는 전기 구체 ─────────────────────────────────────────────

func _launch_arc(from: Vector2, toward: Vector2) -> void:
	var aim := toward - from
	var dir := aim.normalized() if aim.length() > 1.0 else Vector2.RIGHT
	var end: Vector2 = room.clip_shot(from, toward if aim.length() > 60.0 else from + dir * 60.0)
	rays.append({"pos": from, "origin": from, "end": end, "dir": dir, "alive": true, "trail": from})
	_orb_tex = load("res://assets/weapons/arc_orb.png")
	WeaponFx.spawn(host_node, WeaponCatalog.ARC, "muzzle", from, dir, 1.1)
	lights.pulse(get_instance_id(), from, WeaponCatalog.data(WeaponCatalog.ARC).color, 300.0, 3.2, 0.12)


func _process(delta: float) -> void:
	age += delta
	if weapon != WeaponCatalog.ARC:
		if age > 0.05:
			queue_free()
		return
	if not is_instance_valid(room):
		queue_free()
		return
	var alive := false
	var speed := float(WeaponCatalog.data(WeaponCatalog.ARC).speed)
	for ray in rays:
		if not ray.alive:
			continue
		var old: Vector2 = ray.pos
		var next: Vector2 = old.move_toward(ray.end, speed * delta)
		ray.trail = old
		var sweep := sweep_monsters(room, old, next, ARC_RADIUS)
		if not sweep.is_empty():
			ray.pos = sweep[0].point
			_arc_burst(ray, sweep[0].node)
			continue
		ray.pos = next
		if next.distance_to(ray.end) < 1.0:
			_arc_burst(ray, null)
			continue
		alive = true
		lights.pulse(get_instance_id(), next, WeaponCatalog.data(WeaponCatalog.ARC).color, 260.0, 2.8, 0.08)
	if not alive:
		_tail_t += delta
		if _tail_t > 0.08:
			queue_free()
	queue_redraw()


## 구체가 터진다: 첫 대상 + 반경 안 몇 마리에 연쇄. 전부 감전 경직(stun) + 감속(slow). 벽 너머로는 잇지 않는다.
func _arc_burst(ray: Dictionary, first: Node) -> void:
	ray.alive = false
	var d := WeaponCatalog.data(WeaponCatalog.ARC)
	var c: Color = d.color
	var point: Vector2 = ray.pos
	var dir: Vector2 = ray.dir
	var linked: Array = []
	if first == null:
		var hit := env_hit(room, point)
		if hit.get("kind") == "monster":
			first = hit.node
		else:
			react(room, hit, point, ray.origin, 1.2, camera)
			leave_mark(room, hit, point, dir, 0.9)
	if is_instance_valid(first):
		_hit_monster(first, point, dir, float(d.power), int(d.damage), float(d.stun))
		first.apply_arc_slow(float(d.slow))
		linked.append(first)
	var chain := PackedVector2Array([point])
	var source := point
	for i in range(int(d.chain_count)):
		var best: Node = null
		var best_d := float(d.chain_range)
		for m in room.monsters:
			if not is_instance_valid(m) or m.is_dead() or m in linked:
				continue
			var center: Vector2 = m.hit_center()
			var dd := source.distance_to(center)
			if dd < best_d and room.clip_shot(source, center).distance_to(center) < 5.0:
				best = m
				best_d = dd
		if best == null:
			break
		var target: Vector2 = best.hit_center()
		chain.append(target)
		linked.append(best)
		_hit_monster(best, target, (target - source).normalized(), float(d.power) * 0.7, int(d.chain_damage), float(d.stun))
		best.apply_arc_slow(float(d.slow))
		WeaponFx.spawn(host_node, WeaponCatalog.ARC, "impact", target, Vector2.UP, 0.9)
		source = target
	WeaponFx.spawn(host_node, WeaponCatalog.ARC, "arc_burst", point, dir, 1.0 if linked.is_empty() else 1.25)
	if chain.size() > 1:
		var fx := WeaponFx.spawn(host_node, WeaponCatalog.ARC, "chain", point)
		fx.points = chain
		lights.pulse(get_instance_id() + 1991, source, c, 300.0, 3.0, 0.3)
	lights.pulse(get_instance_id() + 991, point, c, 420.0, 4.2, 0.26)
	_shake(3.5 if not linked.is_empty() else 1.6)
	WeaponAudio.play(host_node, point, "arc_hit", -4.0)
	if room.has_method("notify_shot"):
		room.notify_shot(ray.origin, point)


static func _rect_t(a: Vector2, b: Vector2, box: Rect2) -> float:
	var d := b - a
	var lo := 0.0
	var hi := 1.0
	for axis in range(2):
		if absf(d[axis]) < 0.00001:
			if a[axis] < box.position[axis] or a[axis] > box.end[axis]:
				return -1.0
		else:
			var t0 := (box.position[axis] - a[axis]) / d[axis]
			var t1 := (box.end[axis] - a[axis]) / d[axis]
			lo = maxf(lo, minf(t0, t1))
			hi = minf(hi, maxf(t0, t1))
			if lo > hi:
				return -1.0
	return lo


func _draw() -> void:
	if weapon != WeaponCatalog.ARC:
		return
	var c: Color = WeaponCatalog.data(WeaponCatalog.ARC).color
	for ray in rays:
		var p: Vector2 = ray.pos
		var d: Vector2 = ray.dir
		var alpha := 1.0 if ray.alive else maxf(0.0, 1.0 - _tail_t / 0.08)
		if alpha <= 0.0:
			continue
		# 궤적 — 총구에서 구체까지 얇게 남는 전하 줄기 (가까울수록 진하다)
		var tail: Vector2 = p - d * minf(220.0, p.distance_to(ray.origin))
		draw_line(tail, p, Color(c, alpha * 0.25), 22.0)
		draw_line(tail, p, Color(c, alpha * 0.9), 6.0)
		for i in range(3):
			var a := age * 26.0 + i * TAU / 3.0
			var r := Vector2.from_angle(a)
			var pts := PackedVector2Array([p + r * 20, p + r.rotated(0.35) * 34, p + r.rotated(0.6) * 26, p + r.rotated(0.9) * 40])
			for j in range(pts.size()):
				pts[j] = (pts[j] / 4.0).round() * 4.0
			draw_polyline(pts, Color(c, alpha), 4.0)
		draw_set_transform(p, age * 9.0, Vector2.ONE * (1.0 + 0.12 * sin(age * 60.0)))
		draw_texture_rect(_orb_tex, Rect2(-34, -41, 68, 82), false, Color(1.4, 1.4, 1.4, alpha))
		draw_set_transform(Vector2.ZERO)
