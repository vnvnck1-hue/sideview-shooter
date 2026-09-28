extends Node
## 장애물 타격감 확인용 시간순 캡처 (창 모드 필요 — 헤드리스는 렌더가 없다).
## 저장: research-images/obstacle-props-v2/
var main: Node2D
var out := "res://../research-images/obstacle-props-v2"

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
	main.player.set_process(false)
	main.current_room.set_process(false)
	main.get_node("UI").get_children().map(func(c): if c is CanvasItem and not (c is ColorRect): c.visible = false)
	main.crosshair.visible = false
	for m in main.current_room.monsters:
		m.set_process(false)
		m.set_physics_process(false)
	var room = main.current_room
	var props: Array = room.obstacles
	_cam(Vector2(1100, 180), 0.62)
	main.player.position.x = 240
	main.player.face(1)
	await _wait(0.3)
	await save_frame("01_lineup.png")
	# 상자: 두 발 → 균열·파편, 이어서 파괴 과정
	var crate = props[2]
	_cam(crate.position + Vector2(-60, -120), 1.0)
	main.player.position.x = crate.position.x - 330
	await _wait(0.1)
	for i in range(2):
		main._spawn_shot(crate.rect.get_center() - Vector2(300, 10 - i * 30), crate.rect.get_center() + Vector2(300, 10 - i*30), 1.0, 1.0)
		await _wait(0.03)
	await save_frame("02_crate_hits.png")
	await _wait(0.4)
	await save_frame("03_crate_cracked.png")
	for i in range(2):
		main._spawn_shot(crate.rect.get_center() - Vector2(300, 0), crate.rect.get_center() + Vector2(300, 0), 1.0, 1.0)
	await _wait(0.03)
	await save_frame("04_crate_break_a.png")
	await _wait(0.12)
	await save_frame("05_crate_break_b.png")
	await _wait(0.9)
	await save_frame("06_crate_after.png")
	# 콘크리트
	var rubble = props[3]
	_cam(rubble.position + Vector2(-40, -150), 1.0)
	main.player.position.x = rubble.position.x - 330
	rubble.hit(1, 0, rubble.rect.get_center() + Vector2(-40, -40), 3)
	rubble.hit(1, 0, rubble.rect.get_center() + Vector2(-50, 30), 3)
	await _wait(0.3)
	await save_frame("07_rubble_cracked.png")
	rubble.hit(1, 0, rubble.rect.get_center(), 3)
	await _wait(0.05)
	await save_frame("08_rubble_break.png")
	await _wait(0.3)
	await save_frame("09_rubble_dust.png")
	# 가스통
	var gas = props[4]
	_cam(gas.position + Vector2(80, -160), 0.75)
	main.player.position.x = gas.position.x - 520
	gas.hit(1, 0, gas.rect.get_center() + Vector2(0, -20), 1)
	await _wait(0.5)
	await save_frame("10_gas_leak.png")
	gas.hit(1, 0, gas.rect.get_center(), 2)
	await _wait(0.3)
	await save_frame("11_gas_fuse.png")
	var t := 0.0
	var shots := [[0.23, "12_boom_flash.png"], [0.3, "13_boom_ball.png"], [0.45, "14_boom_chain.png"], [0.8, "15_boom_smoke.png"], [1.6, "16_boom_fire.png"], [3.2, "17_boom_after.png"]]
	for s in shots:
		await _wait(s[0] - t)
		t = s[0]
		await save_frame(s[1])
	get_tree().quit()

func _cam(pos: Vector2, z: float) -> void:
	main.camera.set_process(false)
	main.camera.position_smoothing_enabled = false
	main.camera.zoom = Vector2(z, z)
	main.camera.position = pos
	main.camera.offset = Vector2.ZERO
	main.camera.limit_left = -10000
	main.camera.limit_right = 10000
	main.camera.limit_top = -10000
	main.camera.limit_bottom = 10000

func _wait(sec: float) -> void:
	if sec > 0.0:
		await get_tree().create_timer(sec).timeout

func save_frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(out+"/"+name)
	print("FX CAPTURE ",name," result=",result)
