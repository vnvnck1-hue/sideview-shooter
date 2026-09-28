extends SceneTree
## Render actual scene entry points, including their shared materials and CRT.
var records: Array = []
var variant := "after"
var folder: String

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		variant = args[0]
	folder = ProjectSettings.globalize_path("res://../research-images/readability-applied/" + variant).simplify_path()
	DirAccess.make_dir_recursive_absolute(folder)
	run.call_deferred()

func run() -> void:
	var scenes: Array = ["Main", "MainGame", "SpaceLab", "DepthLab", "FaceLab", "ScaleLab", "DialogueLab",
		"CrawlerDeathLab", "HitFxShowcase", "WalkerLab", "WalkerLegacyLab", "WalkerAuthoringLab",
		"ServiceGalleryPreview", "ServiceGalleryPack", "ServiceGalleryLightProp", "CoolantPumpRoomAssetPreview",
		"MapViewer", "Lobby"]
	if variant == "before":
		scenes = ["Main", "SpaceLab", "CrawlerDeathLab", "WalkerLab"]
	for scene_name in scenes:
		seed(4812)
		AppFlow.start_room = "workshop"
		AppFlow.resume_x = -1.0
		var err := change_scene_to_file("res://scenes/" + scene_name + ".tscn")
		if err != OK:
			push_error("Scene load failed: " + scene_name)
			quit(1)
			return
		await process_frame
		await process_frame
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1600, 900)
		if current_scene.get("player") != null:
			current_scene.player.input_enabled = false
			current_scene.player.aim_target = current_scene.player.position + Vector2(600, -140)
		for i in range(90):
			await process_frame
		await RenderingServer.frame_post_draw
		var result := root.get_texture().get_image().save_png(folder + "/" + scene_name + ".png")
		var stat := {"scene": scene_name, "capture_error": result, "actor_materials": 0, "actor_fill_materials": 0,
			"background_materials": 0, "foreground_nodes": 0, "crt": root.get_node("CrtFx").index}
		inspect(current_scene, stat)
		records.append(stat)
		print("READABILITY_SCENE ", JSON.stringify(stat))
	var f := FileAccess.open(folder + "/coverage.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(records, "\t"))
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit()

func inspect(node: Node, stat: Dictionary) -> void:
	if node is ForegroundLayer:
		stat.foreground_nodes += 1
	if node is CanvasItem and node.material is ShaderMaterial:
		var m: ShaderMaterial = node.material
		if m.has_meta("rim_character"):
			stat.actor_materials += 1
			var fill = m.get_shader_parameter("actor_fill")
			if fill != null and float(fill) > 0.0:
				stat.actor_fill_materials += 1
		if m.has_meta("readability_background"):
			stat.background_materials += 1
	for child in node.get_children():
		inspect(child, stat)
