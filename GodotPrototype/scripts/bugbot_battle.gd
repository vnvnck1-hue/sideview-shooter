extends Node
## 방 수명에 묶인 임시 전투 감독. 기존 스포너는 전투 중 쉬고 종료하면 재개한다.
const Hunter := preload("res://scripts/bugbot_hunter.gd")
const SQUAD_SIZE := 3
const NORMAL_HP := 12
const GIANT_HP := 48
const LOCAL_BAND := 1650.0
var room: Node2D
var bots: Array = []
var spawned: Array = []
var kills := 0
var kill_rate := 0.0
var desired_count := 8
var spawn_interval := 0.75
var _spawn_timer := 1.0
var _balance_timer := 0.0
var _recent_kills := 0
var _spawn_serial := 0
var _home_x := 0.0


func start(host: Node2D, x: float) -> void:
	room = host
	_home_x = x
	var sec: Vector2 = room.section_of(x)
	for i in range(SQUAD_SIZE):
		var bot := Hunter.new()
		bot.name = "HunterBugbot%d" % (i + 1)
		bot.autonomous = true
		bot.director = self
		bot.slot = i
		bot.weapon_id = WeaponCatalog.ARC if i == 1 else "legacy"
		bot.z_index = 5
		bot.setup(clampf(x + (i - 1) * 220.0, sec.x + 180.0, sec.y - 180.0), room.floor_y, room)
		bot.set_span(sec.x + 90.0, sec.y - 90.0)
		room.add_child(bot)
		bot.state = WalkerUnit.State.WAKING
		bots.append(bot)


func stop() -> void:
	for bot in bots:
		if is_instance_valid(bot):
			bot.queue_free()
	for monster in spawned:
		if is_instance_valid(monster):
			monster.queue_free()
	bots.clear()
	spawned.clear()
	room.bugbot_battle = null
	queue_free()


func anchor_x() -> float:
	# 닫힌 구역 문 너머로 순간이동하거나 벽을 관통해 플레이어를 쫓지 않는다.
	var sec: Vector2 = room.section_of(_home_x)
	return clampf(room.player.position.x, sec.x + 220.0, sec.y - 220.0)


func pick_target(bot: Node2D) -> Node2D:
	var best: Node2D = null
	var score := INF
	var sec: Vector2 = room.section_of(bot.position.x)
	for monster in room.monsters:
		if not is_instance_valid(monster) or monster.is_queued_for_deletion() or monster.is_dead():
			continue
		if monster.position.x < sec.x or monster.position.x > sec.y:
			continue
		var distance: float = bot.position.distance_to(monster.hit_center())
		if distance > LOCAL_BAND * 1.5:
			continue
		for ally in bots:
			if ally != bot and is_instance_valid(ally) and ally.target == monster:
				distance += 420.0
		if distance < score:
			score = distance
			best = monster
	return best


func monster_target(from: Vector2) -> Node2D:
	var best: Node2D = null
	var distance := LOCAL_BAND * 2.0
	var sec: Vector2 = room.section_of(from.x)
	for bot in bots:
		if not is_instance_valid(bot) or not bot.available() or bot.position.x < sec.x or bot.position.x > sec.y:
			continue
		var d: float = from.distance_to(bot.position)
		if d < distance:
			distance = d
			best = bot
	return best if best != null else room.player


func _process(delta: float) -> void:
	spawned = spawned.filter(func(m): return is_instance_valid(m))
	# 화면 밖에서 계속 쌓이지 않도록 이 감독이 만든 먼 개체만 회수한다.
	for monster in spawned:
		if absf(monster.position.x - anchor_x()) > LOCAL_BAND * 2.0:
			monster.queue_free()
	_balance_timer -= delta
	if _balance_timer <= 0.0:
		_balance_timer = 4.0
		kill_rate = lerpf(kill_rate, float(_recent_kills) / 4.0, 0.45)
		_recent_kills = 0
		var strength := 0.0
		for bot in bots:
			if is_instance_valid(bot) and bot.available():
				strength += clampf(bot.armor / bot.MAX_ARMOR, 0.35, 1.0)
		# 세 대의 실효 전투력 + 최근 처치 속도. 피해/수리 중에는 압박을 줄인다.
		desired_count = clampi(int(ceil(strength * 2.6 + kill_rate * 2.5)), 3, Room.MONSTER_HARD_CAP)
		spawn_interval = clampf(1.0 / maxf(0.5, strength * 0.3 + kill_rate * 1.1), 0.35, 2.0)
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_interval
	if room.alive_monsters() >= Room.MONSTER_HARD_CAP or room.alive_in_section(anchor_x()) >= desired_count:
		return
	_spawn_enemy()


func _spawn_enemy() -> void:
	var center := anchor_x()
	var sec: Vector2 = room.section_of(center)
	var lo := maxf(sec.x + 180.0, center - LOCAL_BAND)
	var hi := minf(sec.y - 180.0, center + LOCAL_BAND)
	if hi <= lo:
		return
	# 양쪽에서 번갈아 진입. 안전한 자리가 없으면 다음 틱에 재시도한다.
	for attempt in range(16):
		var side := -1.0 if (_spawn_serial + attempt / 8) % 2 == 0 else 1.0
		var x := clampf(center + side * randf_range(850.0, LOCAL_BAND), lo, hi)
		if absf(x - room.player.position.x) < 380.0:
			continue
		var safe := true
		for bot in bots:
			if absf(x - bot.position.x) < 340.0:
				safe = false
		if not safe or room.floor_y - room.ceiling_at(x) < 300.0:
			continue
		var giant: bool = _spawn_serial % 5 == 4 and room._giant_headroom_ok(x)
		if giant:
			var bounds: Vector2 = room._monster_bounds(true, x)
			giant = x >= bounds.x and x <= bounds.y and bounds.y - bounds.x > 300.0
		var monster: Crawler = room._add_crawler(x, 1 if center >= x else -1, giant)
		monster.max_hp = GIANT_HP if giant else NORMAL_HP
		monster.hp = monster.max_hp
		monster.died.connect(_on_kill)
		monster.spawn_in()
		spawned.append(monster)
		_spawn_serial += 1
		return


func _on_kill(_pos: Vector2, _power: float) -> void:
	kills += 1
	_recent_kills += 1


func status_text() -> String:
	var active := 0
	for bot in bots:
		if is_instance_valid(bot) and bot.available():
			active += 1
	return "F10 전투 종료  |  버그봇 %d/3 · 수리 %d  |  몬스터 %d/%d  |  처치 %d" % [active, 3 - active, room.alive_in_section(anchor_x()), desired_count, kills]
