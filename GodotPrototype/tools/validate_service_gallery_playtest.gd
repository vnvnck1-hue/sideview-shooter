extends SceneTree
## godot --headless --path GodotPrototype --script res://tools/validate_service_gallery_playtest.gd

const GalleryPlaytest := preload("res://scripts/service_gallery_playtest.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	GalleryPlaytest.register_room()
	AppFlow.start_room = GalleryPlaytest.ROOM_ID
	AppFlow.resume_x = 960.0
	AppFlow.resume_facing = 1
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		push_error("Main scene could not load")
		quit(1)
		return
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var room := game.get("current_room") as Room
	var player := game.get("player") as Player
	if room == null or player == null:
		failures.append("Player or Room was not initialized")
	else:
		if room.width != 2560 or absf(room.floor_y - 486.0) > 0.1:
			failures.append("Room bounds or walkable floor are incorrect")
		if player.position.x != 960.0 or absf(player.position.y - 488.0) > 0.1:
			failures.append("Player did not spawn on the expected floor")
		if not player.input_enabled or player.min_x >= player.max_x:
			failures.append("Player controls or movement bounds are disabled")
		if room.monsters.size() != 2 or room.alive_monsters() != 2:
			failures.append("Two live Crawlers did not spawn")
		if room.room_tiles.visible:
			failures.append("Old workshop tiles are still visible")
		if room.solid == null or not room.solid.is_solid(Vector2(2561, 300)):
			failures.append("RoomSolid does not stop shots at the right wall")
		var pack := room.get_node_or_null("Tiles/SourceGalleryTiles") as Node2D
		var extension := room.get_node_or_null("Tiles/RepeatTileExtension") as Node2D
		if pack == null or extension == null:
			failures.append("Source gallery or repeat extension is missing")
		else:
			for path in ["RearPlate/RearArchitecture", "FrontPlate/FrontArchitecture"]:
				var layer := pack.get_node_or_null(path) as TileMapLayer
				if layer == null or layer.get_used_cells().size() != 112:
					failures.append("Source tile layer is incomplete: " + path)
			var rear := extension.get_node_or_null("WallCeilingFloor") as TileMapLayer
			var under := extension.get_node_or_null("DarkUnderfloor") as TileMapLayer
			var front := extension.get_node_or_null("Pillars") as TileMapLayer
			if rear == null or rear.get_used_cells().size() != 30:
				failures.append("Repeat wall, ceiling and floor tiles are incomplete")
			if under == null or under.get_used_cells().size() != 5:
				failures.append("Repeat underfloor tiles are incomplete")
			if front == null or front.get_used_cells().size() != 8:
				failures.append("Repeat pillar tiles are incomplete")
		var start_x := player.position.x
		Input.action_press("move_right")
		for i in range(8):
			await process_frame
		Input.action_release("move_right")
		if player.position.x <= start_x:
			failures.append("Player did not move right under game input")
		var bullets := game.get("bullets") as Node2D
		var before := bullets.get_child_count()
		game.call("_spawn_shot", player.position + Vector2(30, -120), player.position + Vector2(320, -120))
		if bullets.get_child_count() <= before:
			failures.append("Player shot did not create a bullet")
	Input.action_release("move_right")
	if failures.is_empty():
		print("SERVICE_GALLERY_PLAYTEST_VALID: 3 TileSets, 2 live Crawlers, player movement, bullet creation and room bounds OK")
		quit()
	else:
		for message in failures:
			push_error(message)
		quit(1)
