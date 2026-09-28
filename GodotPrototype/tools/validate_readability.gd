extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	AppFlow.start_test(self, "workshop", 700.0)
	await process_frame
	await process_frame
	for i in range(5):
		await process_frame
	var main := current_scene
	main.player.input_enabled = false
	check(main.player.body.material.get_shader_parameter("actor_fill") > 0.0, "Player fill missing")
	# The material factory is also used for actors created after scene startup.
	var spawned = load("res://scripts/crawler.gd").new()
	main.current_room.add_child(spawned)
	check(spawned._sprite.material.get_shader_parameter("actor_fill") > 0.0, "New crawler fill missing")
	var mechanical := Lighting.character_material("prop_surface", 0.5, true)
	check(mechanical.get_shader_parameter("actor_fill") > 0.0, "Mechanical actor fill missing")
	check(is_equal_approx(mechanical.get_shader_parameter("rim_width_px"), 30.0), "Mechanical rim scaling changed")
	Lighting.apply_rim_preset()
	check(mechanical.get_shader_parameter("actor_fill") > 0.0, "Preset reset lost actor fill")
	var fg: ForegroundLayer = main.current_room.foreground
	for actor in get_nodes_in_group("readability_actors"):
		actor.remove_from_group("readability_actors")
	var marker := Node2D.new()
	main.current_room.add_child(marker)
	marker.add_to_group("readability_actors")
	marker.set_meta("readability_bounds", Rect2(-10, -10, 20, 20))
	var item: Dictionary = fg._occlusion_items[0]
	marker.global_position = fg.global_transform * (item["rect"] as Rect2).get_center()
	fg._update_occlusion(1.0)
	check(is_equal_approx(item["node"].modulate.a, 0.25), "Overlapping foreground did not fade")
	check(is_equal_approx(item["rim"].get_shader_parameter("occlusion_alpha"), 0.25), "Rim did not fade")
	marker.global_position = Vector2(-100000, -100000)
	fg._update_occlusion(1.0)
	check(is_equal_approx(item["node"].modulate.a, 1.0), "Foreground did not recover")
	fg.rebuild_visuals()
	fg._update_occlusion(1.0)
	check(fg._occlusion_items.size() == fg.items.size(), "Foreground rebuild lost items")
	print("READABILITY_VALIDATION ", "PASS" if failures.is_empty() else str(failures))
	main.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
