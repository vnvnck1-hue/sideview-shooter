extends SceneTree
## godot --headless --path . --fixed-fps 60 --script res://tools/validate_bugbot_battle.gd
var failures := 0
var shots := [0, 0, 0]
var main: Node


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	seed(4812)
	load("res://scripts/app_flow.gd").start_test(self, "hangar", 2000.0, 1)
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	print("%s %s" % ["PASS" if value else "FAIL", message])
	if not value:
		failures += 1


func frames(count: int) -> void:
	for i in range(count):
		await process_frame


func toggle_key() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F10
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	key = InputEventKey.new()
	key.physical_keycode = KEY_F10
	key.pressed = false
	Input.parse_input_event(key)
	await frames(2)


func _run() -> void:
	await frames(20)
	main = current_scene
	var room = main.get("current_room")
	var original_spawn: Dictionary = room._spawn_cfg.duplicate(true)
	await toggle_key()
	var battle: Node = room.bugbot_battle
	check(is_instance_valid(battle), "F10 starts battle")
	if not is_instance_valid(battle):
		quit(1)
		return
	check(battle.bots.size() == 3, "exactly three bots")
	var start_x := []
	for i in range(3):
		start_x.append(battle.bots[i].position.x)
		battle.bots[i].shoot_fired.connect(func(_a, _b): shots[i] += 1)
	await frames(80)
	check(main.controlled_turret == null and main.player.input_enabled, "AI wake preserves player input")
	check(battle.bots.all(func(b): return b.state == WalkerUnit.State.READY), "all bots awake autonomously")
	var bot = battle.bots[0]
	bot._hit_lock = 0.0
	var hp_before: float = bot.armor
	var glob := AcidGlob.new()
	glob.setup(bot.hit_rect().get_center(), bot, room.floor_y, room)
	room.add_child(glob)
	glob._splat(true)
	check(bot.armor < hp_before, "acid damages bot armor")
	bot._hit_lock = 0.0
	bot.receive_monster_hit(bot.position + Vector2(0, -90), 1.0, 100.0)
	check(not bot.available(), "disabled bot enters repair")
	await frames(500)
	check(bot.available(), "disabled bot returns after repair")
	var maximum := 0
	var moved := [false, false, false]
	var took_damage := false
	for second in range(50):
		await frames(60)
		maximum = maxi(maximum, room.alive_monsters())
		for i in range(3):
			moved[i] = moved[i] or absf(battle.bots[i].position.x - float(start_x[i])) > 100.0
			took_damage = took_damage or battle.bots[i].armor < 95.0
		if second % 10 == 0:
			print("BATTLE t=%d shots=%s kills=%d alive=%d target=%d interval=%.2f" % [second, shots, battle.kills, room.alive_monsters(), battle.desired_count, battle.spawn_interval])
	check(shots.all(func(n): return n > 10), "all three bots fire")
	check(moved.all(func(value): return value), "all bots move to hunt")
	check(battle.kills >= 5, "autonomous shots actually kill monsters (%d)" % battle.kills)
	check(took_damage, "monsters fight back during natural combat")
	check(maximum <= room.MONSTER_HARD_CAP, "live population stays bounded (%d)" % maximum)
	check(battle._spawn_serial > 14, "reinforcements continue beyond initial population")
	check(main.controlled_turret == null, "combat never takes player control")
	# Strength and kill rate both affect reinforcement pressure.
	battle.kill_rate = 0.0
	battle._recent_kills = 0
	for b in battle.bots:
		b.armor = 100.0
		b.repair_left = 0.0
	battle._balance_timer = 0.0
	battle._process(0.01)
	var healthy_target: int = battle.desired_count
	for b in battle.bots:
		b.repair_left = 6.0
	battle._balance_timer = 0.0
	battle._process(0.01)
	check(battle.desired_count < healthy_target, "repairing squad reduces pressure")
	for b in battle.bots:
		b.repair_left = 0.0
	battle._recent_kills = 16
	battle._balance_timer = 0.0
	battle._process(0.01)
	check(battle.desired_count > healthy_target, "fast kills increase pressure")
	var bots: Array = battle.bots.duplicate()
	await toggle_key()
	check(not is_instance_valid(room.bugbot_battle), "F10 stops battle")
	check(bots.all(func(b): return not is_instance_valid(b)), "stop removes summoned bots")
	check(room._spawn_cfg == original_spawn, "original spawn configuration preserved")
	await toggle_key()
	check(is_instance_valid(room.bugbot_battle) and room.bugbot_battle.bots.size() == 3, "restart creates exactly three bots")
	battle = room.bugbot_battle
	main._load_room("corr_west", 900.0, 1)
	await frames(3)
	check(not is_instance_valid(battle), "room transition cleans up battle")
	print("BUGBOT RESULT: %d failures" % failures)
	main.queue_free()
	await frames(3)
	quit(1 if failures else 0)
