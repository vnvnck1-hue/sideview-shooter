extends "res://scripts/main.gd"
## Playable entry using the real Main, Room, player and weapon pipeline.
func _ready() -> void:
	AppFlow.start_room = "corr_west"
	AppFlow.resume_x = 650.0
	super._ready()
	current_room._add_creature("seam_ambusher", 2000.0, -1)
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _capture() -> void:
	var folder := ProjectSettings.globalize_path("res://../research-images/creatures-v2")
	DirAccess.make_dir_recursive_absolute(folder)
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600, 900)
	player.input_enabled = false
	player.position.x = 650.0
	current_room.set_process(false)
	camera.focus_x = 1400.0
	camera.lead_enabled = false
	camera.snap()
	var actors: Array = current_room.monsters.duplicate()
	for c in actors:
		c.ai_enabled = false
		c.set_process(false)
	for i in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "/game-idle.png")
	var ring: CreatureEnemy = actors[1]
	ring.position.x = 1700
	ring.state = "roll"
	ring.facing = -1
	ring._play("roll")
	for i in range(60):
		for c in actors:
			if i == 12 and c.species != "ring_spine":
				c.force_attack()
			c._process(1.0 / 30.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder + "/frame_%03d.png" % i)
		if i == 27:
			get_viewport().get_texture().get_image().save_png(folder + "/game-attack.png")
	for c in actors:
		c.hit(c.hit_center(), 1.0, 1.0, 100)
	for i in range(12):
		for c in actors:
			c._process(1.0 / 30.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "/game-fragments.png")
	get_tree().quit()
