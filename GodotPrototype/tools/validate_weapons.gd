extends SceneTree
## 새 무기 검사 (불독 · 코일랜스 · 아크위버).
## 헤드리스: --headless --path GodotPrototype --fixed-fps 60 --script res://tools/validate_weapons.gd
## 핵심은 **탄이 경로 위 가장 가까운 배경 사물에 박히지 않는가** — 조준점에 있는 것만 맞아야 한다.
var failures := 0
var main: Node
const WP := "res://scripts/weapon_projectile.gd"


class Target extends Node2D:
	var hp := 10
	var slow := 0.0
	var hits := 0
	var weapon_hitstop_left := 0.0
	func hit_rect() -> Rect2: return Rect2(position - Vector2(15, 25), Vector2(30, 50))
	func hit_center() -> Vector2: return position
	func is_dead() -> bool: return hp <= 0
	func hit(_p: Vector2, _dir: float, _power: float, damage := 1) -> void:
		hp -= damage
		hits += 1
	func apply_arc_slow(seconds: float) -> void: slow = seconds


## 뒷벽에 붙은 배경 프랍 (사물함 같은 것) — 조준점이 안에 있을 때만 맞아야 한다
class BackProp extends RefCounted:
	var rect := Rect2(100, 40, 260, 140)
	var hits := 0
	func is_solid_at(p: Vector2) -> bool: return rect.has_point(p)
	func hit(_dir: float, _y: float, _p := Vector2.INF, _power := 1.0) -> void: hits += 1


class Arena extends Node2D:
	var monsters: Array = []
	var floor_y := 900.0
	var wall := 2000.0
	var prop: BackProp
	func clip_shot(a: Vector2, b: Vector2) -> Vector2:
		if a.x < wall and b.x >= wall:
			return a.lerp(b, (wall - a.x) / (b.x - a.x))
		return b
	func hit_at(point: Vector2) -> Dictionary:
		for m in monsters:
			if not m.is_dead() and m.hit_rect().has_point(point):
				return {"kind": "monster", "node": m}
		if prop != null and prop.is_solid_at(point):
			return {"kind": "prop", "node": prop}
		return {"kind": "wall"}
	func notify_shot(_a: Vector2, _b: Vector2) -> void: pass


class FakeObstacle extends RefCounted:
	var rect: Rect2
	var destroyed := false
	func is_solid_at(p: Vector2) -> bool: return not destroyed and rect.has_point(p)


func _initialize() -> void:
	start.call_deferred()


func start() -> void:
	seed(22311)
	load("res://scripts/app_flow.gd").start_test(self, "hangar", 2000.0, 1)
	run.call_deferred()


func frames(n: int) -> void:
	for i in range(n):
		await process_frame


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func arena(xs: Array, with_prop := false) -> Arena:
	var a := Arena.new()
	root.add_child(a)
	if with_prop:
		a.prop = BackProp.new()
	for x in xs:
		var t := Target.new()
		t.position = Vector2(x, 100)
		a.add_child(t)
		a.monsters.append(t)
	return a


func fire(a: Arena, id: String, to := Vector2(1500, 100)):
	return load(WP).fire(a, a, id, Vector2(0, 100), to)


func run() -> void:
	await frames(20)
	main = current_scene
	main.set_process(false)
	main.current_room.disable_monsters()
	var player = main.player
	player.set_process(false)
	player.input_enabled = true
	player.facing = 1
	player.aim_target = player.position + Vector2(1000, -150)

	# ── 원래 캐릭터 리그 유지 ──
	check(player.weapon_id == "bulldog" and player.ammo == 8, "default Bulldog, eight shells")
	check(player.body.visible and player.head.visible and player.arm_pivot.visible, "original hand-drawn body/head/arm rig stays visible")
	check(player.arm.texture != null and Lighting.path_of(player.arm.texture).ends_with("bulldog_gun.png") or str(player.arm.texture.resource_path).ends_with("bulldog_gun.png"), "arm sprite carries the Bulldog art")
	check(player.get_node_or_null("ConceptWeaponPose") == null, "static paper-doll pose layer removed")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	check(player.weapon_id == "coil" and player.ammo == 6, "Q switches to Coil Lance")

	# ── 충전 ──
	player._fire_cd = 0
	player._swap_t = 0
	var fired := [0]
	player.shoot_fired.connect(func(_a, _b): fired[0] += 1)
	Input.action_press("shoot")
	for i in range(12):
		player._process(1.0 / 60.0)
	check(fired[0] == 0 and player.charge_ratio() > 0.5, "charge delays the shot")
	Input.action_release("shoot")
	player._process(1.0 / 60.0)
	check(player.charge_ratio() == 0 and player.ammo == 6, "release cancels partial charge without spending ammo")
	Input.action_press("shoot")
	for i in range(20):
		player._process(1.0 / 60.0)
	Input.action_release("shoot")
	check(fired[0] == 1 and player.ammo == 5, "full 0.3s charge fires once")
	check(player._arm_rc.y != 0.0 or player._arm_rc.x != 0.0, "shot kicks the arm recoil spring")
	HitStop.clear()
	player.equip_weapon("bulldog")
	player.ammo = 2
	player.start_reload()
	player._update_reload(1.05)
	check(player.ammo == 8 and not player.reloading, "Bulldog reload fills its magazine")
	player.equip_weapon("coil")
	check(player.ammo == 5, "switching preserves each weapon's ammo")

	# ── 충돌: 경로 위 배경 사물에 박히지 않는다 ──
	for id in ["bulldog", "coil", "arc_weaver"]:
		var a := arena([], true)
		var p = fire(a, id)
		for i in range(40):
			p._process(1.0 / 60.0)
		check(a.prop.hits == 0, id + ": shot passes a background prop lying between muzzle and aim point")
		a.queue_free()
		await frames(2)
		a = arena([], true)
		p = fire(a, id, Vector2(230, 100))
		for i in range(40):
			if is_instance_valid(p):
				p._process(1.0 / 60.0)
		check(a.prop.hits > 0, id + ": aiming at the prop hits it")
		a.queue_free()
		await frames(2)

	# ── 몬스터는 경로에서 가로챈다 ──
	var a := arena([400])
	var p = fire(a, "bulldog")
	check(a.monsters[0].hp == 7, "Bulldog pellets hit a monster in the path, capped at 3 damage")
	check(p.total_hits >= 1, "Bulldog reports hits for hitstop")
	a.queue_free()
	await frames(2)
	a = arena([180, 350, 510])
	p = fire(a, "coil")
	check(a.monsters.all(func(m): return m.hp == 7), "Coil pierces every body on the line once")
	a.queue_free()
	await frames(2)
	a = arena([180, 350, 510])
	a.wall = 400
	p = fire(a, "coil")
	check(a.monsters[0].hp == 7 and a.monsters[1].hp == 7 and a.monsters[2].hp == 10, "wall stops the Coil rail")
	a.queue_free()
	await frames(2)

	# ── 아크 ──
	a = arena([600, 700, 1100])
	a.wall = 1000
	p = fire(a, "arc_weaver", Vector2(1500, 100))
	check(a.monsters[0].hp == 10, "arc orb deals no damage before it arrives")
	for i in range(20):
		p._process(1.0 / 60.0)
	check(a.monsters[0].hp == 7 and a.monsters[0].slow > 2.0, "arc orb bursts on the first body: 3 damage + slow")
	check(a.monsters[1].hp == 8, "arc chains to a nearby enemy for 2 damage")
	check(a.monsters[2].hp == 10, "chain does not cross a solid wall")
	check(a.monsters[0].weapon_hitstop_left > 0.0, "arc stuns (per-monster freeze)")
	a.queue_free()
	await frames(2)

	# ── 장애물: 총구가 이미 상자 안이면 막지 않는다 ──
	var room = main.current_room
	var ob := FakeObstacle.new()
	ob.rect = Rect2(1000, room.floor_y - 200, 200, 200)
	room.obstacles.append(ob)
	var inside: Vector2 = room.clip_shot(Vector2(1100, room.floor_y - 100), Vector2(1900, room.floor_y - 100))
	check(inside.x > 1500, "obstacle containing the muzzle does not swallow the shot")
	var behind: Vector2 = room.clip_shot(Vector2(700, room.floor_y - 100), Vector2(1900, room.floor_y - 100))
	check(behind.x <= 1001, "obstacle in front still intercepts")
	room.obstacles.erase(ob)

	# ── 실제 크롤러 ──
	var enemy = room._add_crawler(2500.0, -1)
	enemy.set_process(false)
	var center: Vector2 = enemy.hit_center()
	load(WP).fire(main.bullets, room, "coil", center - Vector2(95, 0), center + Vector2(500, 0), main.camera)
	check(enemy.is_dead(), "real Crawler dies to one Coil rail")

	# ── 버그봇 ──
	main._toggle_bugbot_battle()
	await frames(90)
	var bots = room.bugbot_battle.bots
	check(bots[1].weapon_id == "arc_weaver" and is_instance_valid(bots[1]._arc_mount), "F10 support bot equips Arc Weaver")
	check(not bots[1]._rig._barrel.visible, "Arc Weaver hides the original cannon")
	HitStop.clear()
	main._load_room("workshop", 900, 1)
	await frames(5)
	check(not is_instance_valid(main.current_room.bugbot_battle), "room transition cleans weapon squad")
	print("WEAPONS RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
