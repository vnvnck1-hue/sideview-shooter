extends SceneTree
## Render the actual in-game WalkerUnit with its existing textures and shared spider IK.
const Unit = preload("res://scripts/walker_unit.gd")
const OUT := "res://tools/artifacts/spider_runtime/"
var viewport: SubViewport
var unit: Node2D
var camera: Camera2D
var title: Label
var world: Node2D


func _initialize() -> void:
	root.hide()
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for action in ["move_left", "move_right", "run", "shoot", "roll"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("142330")
	background.size = Vector2(1280, 720)
	var backdrop := CanvasLayer.new()
	backdrop.layer = -100
	viewport.add_child(backdrop)
	backdrop.add_child(background)
	world = Node2D.new()
	viewport.add_child(world)
	world.draw.connect(_draw_floor)
	unit = Unit.new()
	unit.setup(600, 620, world)
	world.add_child(unit)
	unit.set_process(false)
	unit.state = Unit.State.READY
	unit._power = 1.0
	unit.set_controlled(true)
	unit._tick_power(0.0)
	unit._walker.body_pos = Vector2(1200, 1240 - unit._tune["ride"])
	unit._walker.reset_stance()
	unit._sync_node()
	camera = Camera2D.new()
	camera.zoom = Vector2(2.5, 2.5)
	world.add_child(camera)
	camera.make_current()
	var overlay := CanvasLayer.new()
	overlay.layer = 30
	viewport.add_child(overlay)
	title = Label.new()
	title.position = Vector2(35, 24)
	title.add_theme_font_size_override("font_size", 25)
	overlay.add_child(title)
	var legend := Label.new()
	legend.position = Vector2(35, 675)
	legend.text = "ACTUAL WALKER UNIT  |  saved pivots / rigid spatial links / existing game sprites"
	legend.add_theme_font_size_override("font_size", 18)
	legend.modulate = Color("89adbd")
	overlay.add_child(legend)
	await process_frame
	for i in 90:
		_tick(0, false, 1)
	await _capture("idle", "READY / shared spider joints")
	for i in 65:
		_tick(1, true, -1)
	await _capture("move_right_aim_left", "MOVE RIGHT / AIM LEFT")
	for i in 90:
		_tick(-1, true, 1)
	await _capture("move_left_aim_right", "MOVE LEFT / AIM RIGHT")
	if "frames" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames/"))
		Input.action_release("shoot")
		for i in 30:
			await process_frame
		for frame in 30:
			for tick in 4:
				_tick(1, false, -1)
			await _capture("frames/frame_%04d" % frame, "SPIDER WALK / independent aim")
	print("Spider runtime captures: ", ProjectSettings.globalize_path(OUT))
	quit()


func _tick(direction: float, firing: bool, aim: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if absf(direction) > .01:
		Input.action_press("move_right" if direction > 0 else "move_left")
	if firing:
		Input.action_press("shoot")
	else:
		Input.action_release("shoot")
	unit.aim_target = Vector2(unit.position.x + aim * 550, unit.floor_y - 160)
	unit._process(1.0 / 60.0) # Actual Unit input, heat, movement, clamp and parent-space conversion.
	unit._rig._process(0.0)
	camera.position = unit.position + Vector2(0, -100)
	camera.force_update_scroll()
	world.queue_redraw()


func _capture(filename: String, caption: String) -> void:
	title.text = caption
	await process_frame
	RenderingServer.force_draw(false, 1.0 / 60.0)
	await process_frame
	var picture := viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("Capture needs a real rendering driver")
		quit(1)
		return
	var error := picture.save_png(OUT + filename + ".png")
	if error != OK:
		push_error("Unable to save capture " + str(error))
		quit(1)


func _draw_floor() -> void:
	var back := 620.0 - 58.5 * Unit.SCALE
	world.draw_rect(Rect2(-4000, back, 10000, 2000), Color("1d303b"))
	world.draw_rect(Rect2(-4000, back, 10000, 620.0 - back), Color("263d48"))
	world.draw_line(Vector2(-4000, back), Vector2(6000, back), Color("354d56"), 1)
	world.draw_line(Vector2(-4000, 620), Vector2(6000, 620), Color("617c82"), 2)
	for x in range(-4000, 6000, 80):
		world.draw_line(Vector2(x + 50, back), Vector2(x, 620), Color("3a505b"), 1)
		world.draw_line(Vector2(x, 620), Vector2(x + 120, 2000), Color("263d49"), 1)
