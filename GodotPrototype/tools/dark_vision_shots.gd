extends SceneTree
## 암흑 시야 쇼케이스 캡처 — 격납고에서 정전(방 조명 끔) 뒤 먼 어둠으로 연사하며 프레임을 찍는다.
## 총구 화염 · 날아가는 탄 · 탄착 빛이 어둠 속 물체의 림/반사광을 드러내는지, 캐릭터와 배경의 어둠이 갈리는지 눈으로 본다.
## godot --path GodotPrototype --script res://tools/dark_vision_shots.gd   (렌더 필요 — --headless 금지)
## 저장: research-images/dark-vision/showcase-*.png

var game: Node
var out := "res://../research-images/dark-vision/"


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	AppFlow.start_room = "hangar"
	change_scene_to_file("res://scenes/MainGame.tscn")
	await process_frame
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	game = current_scene
	game.player.input_enabled = false
	game.current_room.disable_monsters()
	game._load_room("hangar", 260.0, 1)
	game.current_room.disable_monsters()
	await create_timer(0.5).timeout
	game.camera.lead_enabled = false
	game.camera.zoom = Vector2(0.5, 0.5)
	game.camera.snap()
	await create_timer(0.2).timeout
	await _shot("showcase-01-lit")
	# 정전 — 이미 있는 광원을 모두 끈다. 사격으로 새로 생기는 라이트는 자동으로 암흑 시야에 잡힌다.
	for l in game.dark_vision._lights:
		if is_instance_valid(l):
			l.enabled = false
	game.camera.set_process(false)
	await create_timer(0.2).timeout
	await _shot("showcase-02-blackout")
	var eye: Vector2 = game.player.head_pivot.global_position
	var target := Vector2(float(game.current_room.width) - 200.0, eye.y - 40.0)
	for i in 5:
		game._on_player_shoot(game.player.muzzle_position() if game.player.has_method("muzzle_position") else eye + Vector2(60, 10), target)
		await process_frame
		await process_frame
		await _shot("showcase-03-fire-%d" % i)
		await create_timer(0.05).timeout
	# 캐릭터 · 배경 분리 근접: 시야 중심을 먼 곳으로 치워 주변 전체를 어둠에 두고 플레이어 가까이 정전 속 불 하나만 켠다.
	game.camera.zoom = Vector2(1.0, 1.0)
	game.camera.snap()
	var probe := PointLight2D.new()
	probe.texture = Lighting.radial_texture()
	probe.texture_scale = Lighting.scale_for_radius(300.0)
	probe.height = Lighting.FLASH_HEIGHT
	probe.color = Lighting.FIRE_LIGHT
	probe.energy = 1.6
	probe.position = game.player.global_position + Vector2(-230, -120)
	game.current_room.add_child(probe)
	game.dark_vision.set_process(false)
	RenderingServer.global_shader_parameter_set("dv_eye", Vector2(-99999, 0))
	game.dark_vision.mask.visible = false
	await create_timer(0.2).timeout
	var inverse: Transform2D = game.world_vp.get_canvas_transform().affine_inverse()
	RenderingServer.global_shader_parameter_set("dv_origin", inverse.origin)
	RenderingServer.global_shader_parameter_set("dv_axis_x", inverse.x)
	RenderingServer.global_shader_parameter_set("dv_axis_y", inverse.y)
	await _shot("showcase-04-actor-vs-bg")
	print("DARK_VISION_SHOTS DONE")
	quit()


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	game.world_vp.get_texture().get_image().save_png(out + label + ".png")
