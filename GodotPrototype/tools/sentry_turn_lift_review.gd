extends SceneTree
## 실행: godot --path GodotPrototype --script res://tools/sentry_turn_lift_review.gd
## 렌더링이 필요하다. 출력: Assets/Generated/SentryTurret/RuntimeReview/

var turret: SentryTurret
var out_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _step(count: int) -> void:
	for i in range(count):
		turret._update_head(1.0 / 60.0)
		turret._hose.update_chain(turret._hose.to_local(turret._recoil.to_global(turret._hose_head)),
			turret._hose_base + Vector2(0.0, -turret._lift_height), 1.0 / 60.0)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_viewport().get_texture().get_image()
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
	var path := out_dir.path_join(name + ".png")
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save sentry review image: " + path)
	else:
		print("SENTRY REVIEW " + path)


func _run() -> void:
	root.size = Vector2i(960, 720)
	out_dir = ProjectSettings.globalize_path("res://").path_join("../Assets/Generated/SentryTurret/RuntimeReview").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var fx := Node2D.new()
	root.add_child(fx)
	turret = SentryTurret.new()
	turret.setup(430.0, 680.0, fx)
	root.add_child(turret)
	var muzzle_world: Vector2 = (turret._muzzles[0].global_position + turret._muzzles[1].global_position) * 0.5
	turret.aim_target = muzzle_world + Vector2(800.0, 0.0)
	turret._set_ready()
	turret.set_process(false)
	await _shot("01_side_right")

	turret.aim_target = muzzle_world + Vector2(-800.0, 0.0)
	_step(6)
	await _shot("02_yaw30")
	_step(6)
	await _shot("03_yaw60")
	_step(4)
	await _shot("04_front")
	_step(10)
	await _shot("05_left_yaw60")
	_step(34)
	await _shot("06_side_left")

	turret.aim_target = muzzle_world + Vector2(-300.0, 900.0)
	_step(180)
	await _shot("07_down_riser")
	turret.aim_target = muzzle_world + Vector2(-300.0, -900.0)
	_step(200)
	await _shot("08_up")
	quit()
