extends Node2D
## Standalone preview of the actual gameplay Crawler, including pose-event VFX.
var crawlers: Array[Crawler] = []
var errors: Array[String] = []
var deaths := 0

func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(760, 370)
	camera.zoom = Vector2.ONE
	add_child(camera)
	RenderingServer.set_default_clear_color(Color(0.10, 0.13, 0.15))
	if "--game-validate" in OS.get_cmdline_user_args():
		await _validate_game()
		get_tree().quit(0 if errors.is_empty() else 1)
		return
	var validate := "--validate" in OS.get_cmdline_user_args()
	if validate:
		await _validate()
		get_tree().quit(0 if errors.is_empty() else 1)
		return
	for i in range(3):
		var label := Label.new()
		label.text = ["INFLATE / BURST", "FLYBACK / IMPACT", "AGONY / LEAK"][i]
		label.position = Vector2([60, 620, 1090][i], 110)
		label.add_theme_font_size_override("font_size", 28)
		add_child(label)
	while is_inside_tree():
		for i in range(3):
			var c := _spawn(i + 2, false, [230.0, 850.0, 1260.0][i], 560.0, 1)
			c.set_process(false)
		await get_tree().create_timer(0.6).timeout
		for c in crawlers:
			c.set_process(true)
			c.hit(c.hit_center(), -1.0, 1.0)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture_sequence()
			get_tree().quit()
			return
		await get_tree().create_timer(3.0).timeout
		for c in crawlers:
			if is_instance_valid(c):
				c.queue_free()
		crawlers.clear()

func _capture_sequence() -> void:
	var out := "res://../Docs/crawler_death_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var previous := 0.0
	for t in [0.15, 0.40, 0.70, 1.10, 1.65]:
		await get_tree().create_timer(t - previous).timeout
		previous = t
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/death_%03d.png" % int(t * 100))

func _spawn(style: int, giant: bool, x: float, floor_line: float, face: int) -> Crawler:
	var c := Crawler.new()
	if giant:
		c.make_giant()
	c.death_style = style
	c.setup(null, x, floor_line, -4000.0, 4000.0, face)
	add_child(c)
	c.hp = 1
	c.died.connect(func(_pos: Vector2, _power: float): deaths += 1)
	crawlers.append(c)
	return c

func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)

func _validate_game() -> void:
	AppFlow.start_room = "workshop"
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var r = main.current_room
	r.disable_monsters()
	for i in range(3):
		var c: Crawler = r._add_crawler(1000.0 + i * 700.0, 1)
		c.death_style = i + 2
		c.hp = 1
		c.hit(c.hit_center(), -1.0, 1.0)
		crawlers.append(c)
	await get_tree().create_timer(2.0).timeout
	for c in crawlers:
		_check(c.is_dead() and c._death_fx_done, "Game room death did not play VFX")
		_check(is_equal_approx(c.position.y, c.floor_y), "Game room corpse did not land")
	print("DEATH_GAME_ROOM: all 3 variants through Room._add_crawler + hit + room stains/spray: ", "PASS" if errors.is_empty() else "FAIL")

func _validate() -> void:
	for giant in [false, true]:
		for style in range(1, 5):
			for face in [-1, 1]:
				var c := _spawn(style, giant, 0.0, 800.0, face)
				# Also exercise wall/ceiling death and an airborne corpse.
				if face == -1:
					c.position.y = 300.0
					c._surface = Crawler.Surface.CEILING
					c._sprite.rotation = PI
				c.hit(c.hit_center(), float(-face), 1.0)
				_check(c.is_dead() and not c.is_hit(c.hit_center()), "Dead crawler remains interactive")
				_check(c._sprite.animation == Crawler.DEATH_CLIPS[style - 1], "Wrong selected death clip")
				for clip in Crawler.DEATH_CLIPS:
					_check(c._sprite.sprite_frames.has_animation(clip), "Missing clip " + clip)
				c.hit(c.hit_center(), float(face), 1.0)
	_check(deaths == 16, "Death signal must emit exactly once per crawler")
	await get_tree().create_timer(2.4).timeout
	for c in crawlers:
		_check(is_equal_approx(c.position.y, c.floor_y), "Corpse did not land")
		_check(c._sprite.frame == c._sprite.sprite_frames.get_frame_count(c.death_clip) - 1, "Clip did not reach corpse pose")
		if c.death_clip != "death":
			_check(c._death_fx_done, "Missing timed variant VFX")
		_check(absf(c._sprite.position.x) < 0.01, "Agony jitter persists after death")
	await get_tree().create_timer(5.0).timeout
	for c in crawlers:
		_check(not is_instance_valid(c), "Corpse not cleaned up")
	print("DEATH_VARIANTS: 16 lethal-hit cases; clips, directions, giants, airborne landing, VFX, single signal and cleanup: ", "PASS" if errors.is_empty() else "FAIL")

func _draw() -> void:
	draw_rect(Rect2(-4000, 560, 8000, 400), Color(0.16, 0.19, 0.20))
	draw_line(Vector2(-4000, 560), Vector2(4000, 560), Color(0.38, 0.43, 0.42), 4.0)
