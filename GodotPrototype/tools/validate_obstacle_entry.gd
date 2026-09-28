extends Node
func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600,900)
	var lobby: Control = load("res://scenes/Lobby.tscn").instantiate()
	get_tree().root.add_child.call_deferred(lobby)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().current_scene = lobby
	var button: Button
	var backlight: Button
	for child in lobby.find_children("*","Button",true,false):
		if "장애물 프랍" in child.text:
			button = child
		if "역광 테스트" in child.text:
			backlight = child
	assert(button != null,"Obstacle playtest button missing")
	assert(backlight == null or not button.get_global_rect().intersects(backlight.get_global_rect()),"Buttons overlap")
	for child in lobby.find_children("*","Button",true,false):
		if child != button and child.is_visible_in_tree():
			assert(not button.get_global_rect().intersects(child.get_global_rect()),"Obstacle button covers another menu entry")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../research-images/obstacle-props/06_lobby_entry.png")
	# Real button invokes the same AppFlow/Main route that the user will use.
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var scene = get_tree().current_scene
	assert(scene.get("current_room") != null,"Playtest route failed")
	assert(scene.current_room.room_id == ObstaclePlaytest.ROOM_ID,"Wrong room")
	assert(scene.current_room.obstacles.size()==7,"Missing demo props")
	print("OBSTACLE ENTRY PASS: button opens playable Main room; backlight button preserved")
	get_tree().quit()
