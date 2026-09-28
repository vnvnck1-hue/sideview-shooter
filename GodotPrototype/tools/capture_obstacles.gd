extends Node
var main: Node2D
var out := "res://../research-images/obstacle-props"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600,900)
	ObstaclePlaytest.register_room()
	Room.obstacle_history.clear()
	AppFlow.start_room = ObstaclePlaytest.ROOM_ID
	AppFlow.resume_x = 200.0
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.set_process(false)
	main.player.set_process(false)
	main.current_room.set_process(false)
	main.camera.set_process(false)
	main.camera.position_smoothing_enabled = false
	main.camera.zoom = Vector2(0.49,0.49)
	main.camera.position = Vector2(1536,100)
	main.camera.offset = Vector2.ZERO
	main.camera.limit_left = -10000
	main.camera.limit_right = 10000
	main.camera.limit_top = -10000
	main.camera.limit_bottom = 10000
	main.get_node("UI").visible = false
	main.crosshair.visible = false
	for m in main.current_room.monsters:
		m.set_process(false)
		m.set_physics_process(false)
	for i in range(12):
		await get_tree().process_frame
	await save_frame("01_all_props.png")
	# Close-up at the actual interaction camera scale.
	main.camera.zoom = Vector2(0.85,0.85)
	main.camera.position = Vector2(2140,225)
	main.player.position.x = 1930
	main.player.face(1)
	await save_frame("02_gas_before.png")
	var gas = main.current_room.obstacles[4]
	gas.hit(1,gas.rect.get_center().y,gas.rect.get_center(),3)
	for m in main.current_room.monsters:
		m.set_process(true)
	await get_tree().create_timer(0.16).timeout
	await save_frame("03_gas_explosion.png")
	await get_tree().create_timer(1.6).timeout
	await save_frame("04_gas_after.png")
	# Actual campaign placement: all five props in Assembly Hall.
	main._load_room("hall",150,1)
	main.camera.set_process(false)
	main.camera.zoom = Vector2(0.49,0.49)
	main.camera.position = Vector2(1536,100)
	main.camera.offset = Vector2.ZERO
	main.camera.limit_left = -10000
	main.camera.limit_right = 10000
	main.camera.limit_top = -10000
	main.camera.limit_bottom = 10000
	main.current_room.set_process(false)
	for m in main.current_room.monsters:
		m.set_process(false)
	for i in range(6):
		await get_tree().process_frame
	await save_frame("05_campaign_hall.png")
	get_tree().quit()

func save_frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out+"/"+name)
	print("OBSTACLE CAPTURE ",name," result=",result)
