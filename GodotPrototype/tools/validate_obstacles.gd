extends Node
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("OBSTACLE FAIL: " + message)
	else:
		print("OBSTACLE PASS: " + message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	ObstaclePlaytest.register_room()
	Room.obstacle_history.clear()
	AppFlow.start_room = ObstaclePlaytest.ROOM_ID
	AppFlow.resume_x = 180.0
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var room = main.current_room
	var player = main.player
	main.set_process(false)
	room.set_process(false)
	player.set_process(false)
	for m in room.monsters:
		m.set_process(false)
		m.set_physics_process(false)
	check(room.obstacles.size()==7,"five obstacle types plus chain-reaction pair are instantiated")
	var barrier = room.obstacles[0]
	var reel = room.obstacles[1]
	var crate = room.obstacles[2]
	var rubble = room.obstacles[3]
	var gas = room.obstacles[4]
	var gas2 = room.obstacles[5]
	var chain_crate = room.obstacles[6]
	for prop in room.obstacles:
		check(prop.texture is CanvasTexture and (prop.texture as CanvasTexture).normal_texture != null,"normal-mapped sprite: "+prop.kind)
		check(prop.rect.end.y==room.floor_y+2,"floor contact: "+prop.kind)
	Input.action_press("move_right")
	for i in range(100):
		player._process(1.0/60)
	check(player.position.x <= barrier.rect.position.x-27,"walking is blocked by barricade")
	player._start_roll(1)
	for i in range(50):
		player._process(1.0/60)
	check(player.position.x <= barrier.rect.position.x-27,"rolling cannot tunnel through barricade")
	player.settle()
	player.position = Vector2(barrier.rect.position.x-40,room.floor_y+2)
	player.jump()
	var landed_on_top := false
	for i in range(85):
		player._process(1.0/60)
		if absf(player.position.y-barrier.rect.position.y)<3:
			landed_on_top = true
	check(landed_on_top,"jump lands on barricade top")
	check(player.position.x > barrier.rect.end.x+20,"player crosses barricade and steps off")
	check(absf(player.position.y-player.air_height()-(room.floor_y+2))<4,"player returns to floor after stepping off")
	Input.action_release("move_right")
	for prop in [reel,crate]:
		player.settle()
		player.position = Vector2(prop.rect.end.x+45,room.floor_y+2)
		Input.action_press("move_left")
		player.jump()
		for i in range(100):
			player._process(1.0/60)
		Input.action_release("move_left")
		check(player.position.x < prop.rect.position.x-20,"jump crosses from right to left: "+prop.kind)
	player.settle()
	player.position = Vector2(rubble.rect.position.x-40,room.floor_y+2)
	Input.action_press("move_right")
	player.jump()
	for i in range(65):
		player._process(1.0/60)
	Input.action_release("move_right")
	check(player.position.x <= rubble.rect.position.x-27,"concrete is too tall for a ground jump")
	check(room.obstacle_move_x(100.0,800.0,room.floor_y)==barrier.rect.position.x-28.0,"large frame step cannot tunnel through barrier")
	# Standing on a destroyed prop must drop the player, not leave floating feet.
	player.settle()
	player.position = Vector2(crate.position.x,crate.rect.position.y)
	barrier.hit(1,barrier.rect.get_center().y,barrier.rect.get_center(),100)
	reel.hit(1,reel.rect.get_center().y,reel.rect.get_center(),100)
	check(not barrier.destroyed and not reel.destroyed,"jump-only props remain solid under heavy fire")
	# Aim beyond a prop: the actual shot path, not cursor location, must hit it.
	var from: Vector2 = crate.rect.get_center()-Vector2(280,0)
	var clipped: Vector2 = room.clip_shot(from,from+Vector2(600,0))
	check(room.hit_at(clipped).get("node")==crate,"shot is intercepted when aiming behind a crate")
	for i in range(4):
		main._spawn_shot(from,from+Vector2(600,0),1.0,1.0)
	check(crate.destroyed,"legacy gun destroys crate after four hits")
	check(room.stain_layer().get_children().filter(func(n): return n is ChunkDebris).size()>=6,"crate bursts into plank-shaped chunks")
	check(room.get_children().any(func(n): return n is PropFx and n.tag=="wood_break"),"crate break throws splinters and sawdust cloud")
	player._process(1.0/60)
	check(player.is_airborne(),"destroying the support starts player falling")
	for i in range(70):
		player._process(1.0/60)
	check(absf(player.position.y-player.air_height()-(room.floor_y+2))<4,"player lands after support destruction")
	check(room.obstacle_move_x(crate.position.x-200,crate.position.x+200,room.floor_y)==crate.position.x+200,"broken crate clears walking collision")
	# Every current player weapon must damage obstacles through real projectile code.
	for weapon in [WeaponCatalog.BULLDOG,WeaponCatalog.COIL,WeaponCatalog.ARC]:
		var old_hp: float = rubble.hp
		var p = load("res://scripts/weapon_projectile.gd").fire(main.bullets,room,weapon,rubble.rect.get_center()-Vector2(250,0),rubble.rect.get_center()+Vector2(100,0),main.camera)
		p.set_process(false)
		for i in range(35):
			p._process(0.016)
		check(rubble.hp<old_hp or rubble.destroyed,"player weapon hits solid prop: "+weapon)
		# Keep alive so all three weapon checks exercise the same target.
		if rubble.destroyed:
			rubble.destroyed=false
			rubble._set_art(false)
		rubble.hp=8.0
	rubble.hit(1,0,rubble.rect.get_center(),8)
	check(rubble.destroyed,"concrete breaks and clears the tall obstruction")
	# Put a real crawler and the player in blast range, separated from gas body.
	var monster = room.monsters[0]
	monster.position.x = gas2.position.x+120
	var monster_hp: int = monster.hp
	player.position=Vector2(gas.position.x-200,room.floor_y+2)
	player.settle()
	gas.hit(1,0,gas.rect.get_center(),1)
	check(not gas.destroyed and gas.hp==2,"gas cylinder survives first shot and starts leaking")
	gas._process(0.2)
	check(room.get_children().any(func(n): return n is PropFx and n.tag=="leak"),"damaged cylinder emits gas leak VFX")
	gas.hit(1,0,gas.rect.get_center(),2)
	check(not gas.destroyed and gas._fuse > 0.0,"lethal shot ignites a short fuse instead of popping instantly")
	check(room.obstacle_move_x(gas.position.x-200,gas.position.x+200,room.floor_y) < gas.position.x,"burning cylinder stays solid until it detonates")
	for i in range(40):
		if not gas.destroyed:
			gas._process(1.0/60)
	check(gas.destroyed and gas2._fuse > 0.0 and not gas2.destroyed,"blast ignites the neighbour on a shorter chain fuse")
	for i in range(30):
		if not gas2.destroyed:
			gas2._process(1.0/60)
	check(gas.destroyed and gas2.destroyed,"gas cylinder explosion chains to nearby cylinder exactly once")
	check(chain_crate.destroyed,"chain explosion damages nearby destructible props")
	check(monster.hp<monster_hp,"explosion applies radial damage to real monster")
	check(player.health<100 and player.health>0,"nearby player takes distance-based blast damage")
	var explosions: Array = room.get_children().filter(func(n): return n is ObstacleExplosion and n.mode=="explosion")
	check(explosions.size()==2,"each cylinder produces one explosion emitter")
	check(WeaponLightPool.get_pool(room).slots.size()==4,"explosions reuse bounded combat light pool")
	for fx in explosions:
		check(fx.sprite.texture != null and fx.get_child_count()>=2,"explosion has painted animation and positional sound")
	for fx in explosions:
		fx._process(3.0)
	await get_tree().process_frame
	check(explosions.all(func(fx): return not is_instance_valid(fx)),"explosion emitters clean up after their lifetime")
	var saved = Room.obstacle_history[ObstaclePlaytest.ROOM_ID].duplicate(true)
	main._load_room(ObstaclePlaytest.ROOM_ID,180,1)
	await get_tree().process_frame
	check(main.current_room.obstacles[2].destroyed and main.current_room.obstacles[4].destroyed,"destroyed props stay destroyed after room reload")
	check(saved.size()>=7,"all damaged prop states persisted")
	main._load_room("hall",120,1)
	await get_tree().process_frame
	check(main.current_room.obstacles.size()==5,"all five props placed in actual Assembly Hall map")
	main._load_room("storage",120,1)
	await get_tree().process_frame
	check(main.current_room.obstacles.size()==3,"storage contains breakable crate and two gas cylinders")
	# Distance falloff must not damage remote actors or props.
	room = main.current_room
	room.set_process(false)
	player.position = Vector2(120,room.floor_y+2)
	player.restore_health()
	var remote_hp: float = room.obstacles[0].hp
	room.obstacle_blast(Vector2(1550,room.floor_y-100),100.0,null)
	check(player.health==100 and room.obstacles[0].hp==remote_hp,"blast radius excludes distant player and props")
	# Lethal damage respawns safely and keeps the destroyed map state.
	player.receive_explosion_damage(1000)
	check(main.transitioning and player.health==0,"lethal blast starts recovery transition and rejects further hits")
	player.receive_explosion_damage(1000)
	await get_tree().create_timer(1.2).timeout
	check(player.health==100 and not main.transitioning,"player health and controls recover after respawn")
	check(absf(player.position.x-120)<1 or absf(player.position.x-(main.current_room.width-120))<1,"respawn is at safe room entry")
	main._load_room("airlock",120,1)
	await get_tree().process_frame
	player.set_process(false)
	Input.action_press("move_right")
	for i in range(50):
		player._process(1.0/60)
	check(player.velocity_x==Player.WALK_SPEED,"normal walking speed is preserved in unobstructed rooms")
	player.jump()
	for i in range(70):
		player._process(1.0/60)
	Input.action_release("move_right")
	check(absf(player.position.y-(main.current_room.floor_y+2))<2 and not player.is_airborne(),"ordinary floor jump still lands in an unobstructed room")
	print("OBSTACLE RESULT: %d checks, %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
