extends Node

class Target extends Node2D:
	var hits := 0
	var rolling := false
	func hit_rect() -> Rect2:
		return Rect2(position - Vector2(24, 50), Vector2(48, 100))
	func receive_monster_hit(_at: Vector2, _dir: float, _damage: float) -> void:
		hits += 1
	func is_rolling() -> bool:
		return rolling

var errors: Array[String] = []
func _ready() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
func run() -> void:
	var r := Room.new()
	r.build("corr_west")
	add_child(r)
	r.set_process(false)
	check(r.monsters.size() == 2 and r.monsters[0] is CreatureEnemy and r.monsters[1] is CreatureEnemy, "Main room placements")
	r.disable_monsters()
	await get_tree().process_frame
	r.obstacles.clear()
	var target := Target.new()
	r.add_child(target)
	r.player = target
	for species in CreatureEnemy.IDS:
		for face in [-1, 1]:
			var c := r._add_creature(species, 1100.0, face)
			c.set_process(false)
			c.ai_enabled = false
			var attack := "strike" if species == "ceiling_bell" else ("lash" if species == "ring_spine" else "snap")
			c._play(attack)
			c.frame_index = 2
			c._apply_frame()
			target.position = c.attack_rect().get_center()
			var before := target.hits
			c.force_attack()
			for i in range(80):
				c._process(0.05)
			check(target.hits == before + 1, "%s/%d must hit exactly once at 20 fps (%d)" % [species, face, target.hits - before])
			check(c.state == "idle", species + " must finish recovery")
			target.rolling = true
			before = target.hits
			c.force_attack()
			for i in range(80):
				c._process(0.05)
			check(target.hits == before, species + " dodge immunity")
			target.rolling = false
			var mask: Image = c._masks[c._frame]
			var opaque := Vector2.ZERO
			for y in range(mask.get_height()):
				for x in range(mask.get_width()):
					if mask.get_pixel(x, y).a > 0.5:
						opaque = Vector2(x + 0.5, y + 0.5)
						break
				if opaque != Vector2.ZERO:
					break
			var point := c._body.to_global(opaque * CreatureEnemy.SCALE + c._body.offset)
			var found := false
			for hit in WeaponProjectile.sweep_monsters(r, point - Vector2.ONE, point + Vector2.ONE):
				if hit.node == c:
					found = true
			check(found, species + " swept weapon trace must hit opaque pixels")
			target.position = Vector2(200, 300)
			before = target.hits
			c.force_attack()
			for i in range(80):
				c._process(0.05)
			check(target.hits == before, species + " out-of-reach attack must miss")
			if species == "ring_spine":
				target.position = Vector2(2050, 300)
				c.state = "roll"
				c.facing = 1
				var start := c.position.x
				for i in range(10):
					c._process(0.016)
				check(absf(c.roll_angle) > 0.2 and is_equal_approx(c._body.rotation, c.roll_angle), "Actual body rotation")
				check(is_equal_approx(c.roll_angle * c.roll_radius, c.position.x - start), "Rolling distance synchronization")
				check(not c.is_hit(c._body.to_global(c._spin_center + c._body.offset)), "Ring hollow must not absorb a bullet")
			var old_hp := c.hp
			c.hit(c.hit_center(), 1.0, 1.0, 1)
			check(c.hp < old_hp, species + " weapon damage")
			c.hit(c.hit_center(), 1.0, 1.0, 100)
			check(c.is_dead() and not c.is_hit(c.hit_center()), species + " death disables collision")
			for i in range(30):
				c._process(0.05)
			check(c.frame_index == 3, species + " death holds last pose")
			c.queue_free()
			await get_tree().process_frame
	for giant in [false, true]:
		var c := r._add_crawler(800, 1, giant)
		var frames: SpriteFrames = c._sprite.sprite_frames
		check(is_equal_approx(frames.get_animation_speed("attack"), 1.0), "Crawler uses authored time")
		check(frames.get_frame_duration("attack", 1) > frames.get_frame_duration("attack", 2) * 4, "Crawler brace / snap ratio")
		c.queue_free()
	print("CREATURE_V2: ", "PASS" if errors.is_empty() else "FAIL", " ", errors)
	r.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if errors.is_empty() else 1)
