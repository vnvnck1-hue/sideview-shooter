extends SceneTree

const OUTPUT := "C:/Users/Loadcomplete/Documents/ChatGPT/sideview-shooter/research-images/comparison"
const ROOMS := ["airlock", "workshop", "hall", "tank_room", "analysis_lab"]

func _initialize() -> void:
	call_deferred("_capture_rooms")

func _capture_rooms() -> void:
	seed(20260922)
	var records: Array = []
	for room_id in ROOMS:
		AppFlow.start_room = room_id
		AppFlow.resume_x = RoomData.room_width(room_id) * 0.38
		change_scene_to_file(AppFlow.TEST_SCENE)
		await process_frame
		await process_frame
		var scene = current_scene
		scene.player.input_enabled = false
		scene.player.aim_target = scene.player.position + Vector2(600, -140)
		scene.camera.lead_enabled = false
		scene.camera.snap()
		for n in range(45):
			await process_frame
		await RenderingServer.frame_post_draw
		var display_image: Image = root.get_texture().get_image()
		var world_image: Image = scene.world_vp.get_texture().get_image()
		display_image.save_png(OUTPUT + "/" + room_id + "_display.png")
		world_image.save_png(OUTPUT + "/" + room_id + "_world.png")
		var transform: Transform2D = scene.world_vp.canvas_transform
		var hs: Array = RoomData.heights(room_id)
		var columns: Array = []
		for x in range(hs.size()):
			var col_world := Rect2(x * 128.0, RoomData.ceiling_at(room_id, x * 128.0), 128.0, hs[x] * 128.0)
			var sr: Rect2 = transform * col_world
			columns.append([sr.position.x, sr.position.y, sr.size.x, sr.size.y])
		var feet: Vector2 = transform * scene.player.position
		var cr: Rect2 = RoomData.room_rect(room_id)
		var record := {"room": room_id, "viewport": [world_image.get_width(), world_image.get_height()], "root_size": [display_image.get_width(), display_image.get_height()], "zoom": scene.camera.zoom.x, "player_feet": [feet.x, feet.y], "room_world": [cr.position.x, cr.position.y, cr.size.x, cr.size.y], "columns_screen": columns, "crt": root.get_node("CrtFx").current()["id"], "camera_center": [scene.camera.get_screen_center_position().x, scene.camera.get_screen_center_position().y]}
		records.append(record)
		print("CAPTURE " + JSON.stringify(record))
	var file := FileAccess.open(OUTPUT + "/capture_metadata.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	quit()
