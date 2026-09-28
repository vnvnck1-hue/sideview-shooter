extends SceneTree
## Read-only visual audit. Only this process changes; gameplay defaults are untouched.
const OUT := "res://../research-images/readability-audit/"
var frame := 0
var capturing := false

func _initialize() -> void:
	seed(4812)
	AppFlow.start_test(self, "hangar", 2000.0, 1)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 10:
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(2240, 900)
		current_scene.player.input_enabled = false
	if frame == 30:
		current_scene._toggle_bugbot_battle()
	if frame == 600 and not capturing:
		capturing = true
		capture.call_deferred()
	return false

func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png(OUT + label + ".png")
	print("READABILITY ", label, " ", error_string(err))
	if err != OK:
		quit(1)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT).simplify_path())
	paused = true
	var crt := root.get_node("CrtFx")
	var original_crt: int = crt.index
	var crt_rect: ColorRect = crt.get("_rect")
	await shot("01_current")
	crt_rect.visible = false
	await shot("02_crt_off")
	crt_rect.visible = original_crt != 0
	for fog in current_scene.current_room.fog_layers:
		if fog.front:
			fog.visible = false
	await shot("03_front_fog_off")
	crt_rect.visible = false
	await shot("04_crt_and_front_fog_off")
	var f := FileAccess.open(OUT + "metadata.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"room": "hangar", "seed": 4812, "frame": 600,
		"size": [root.size.x, root.size.y], "crt_index": original_crt,
		"fog_index": GroundFog.index, "paused_poses": true,
		"note": "Shader TIME may advance between shots. No gameplay or preset files changed."}, "\t"))
	quit()
