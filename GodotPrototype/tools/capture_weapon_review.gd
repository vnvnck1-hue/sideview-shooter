extends SceneTree
## 새 무기 연출 캡처 — 실제 OpenGL 렌더. tools/artifacts/weapons/ 에 PNG.
## 기존 손그림 몸 클립 위에 새 총이 붙어 있는지(정지·걷기·앉기·좌향·위 조준), 발사 순간의 화염·궤적·탄착,
## 코일 충전·레일, 버그봇 아크위버 발사·터짐을 프레임 단위로 찍는다.
var main: Node
var frame := 0
var capturing := false
const OUT := "res://tools/artifacts/weapons/"


func _initialize() -> void:
	start.call_deferred()


func start() -> void:
	seed(5928)
	DirAccess.make_dir_recursive_absolute(OUT)
	load("res://scripts/app_flow.gd").start_test(self, "hangar", 2100.0, 1)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 25 and not capturing:
		capturing = true
		run.call_deferred()
	return false


var crop := Rect2i(950, 330, 1500, 820)


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(OUT + name + ".png")
	var r := crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png(OUT + name + "_crop.png")
	print("CAPTURE " + name)


func wait_frames(n: int) -> void:
	for i in range(n):
		await process_frame


func frame_player(dx := 180.0) -> void:
	main.camera.position = Vector2(main.player.position.x + dx, main.player.position.y - 140)


func run() -> void:
	main = current_scene
	main.current_room.disable_monsters()
	main.set_process(false)
	var p = main.player
	p.input_enabled = false
	main.camera.set_process(false)
	main.camera.zoom = Vector2(1.5, 1.5)
	frame_player()
	p.aim_target = p.position + Vector2(900, -150)
	await wait_frames(20)
	await capture("01_bulldog_idle")
	# 걷기 — 원래 손그림 클립이 도는지 (몸은 움직이고 총은 조준 유지)
	p.state = p.State.WALK
	p.body.play("walk")
	for i in range(4):
		p.body.frame = i
		p.body.pause()
		await wait_frames(1)
		await capture("02_bulldog_walk_%d" % i)
	p.state = p.State.IDLE
	p.body.play("idle")
	# 발사 순간 (0 · 2 · 5 · 10 프레임 뒤)
	await wait_frames(10)
	p._fire()
	var last := 0
	for f in [1, 3, 6, 11]:
		await wait_frames(f - last)
		last = f
		await capture("03_bulldog_fire_f%02d" % f)
	await wait_frames(40)
	p.facing = -1
	p.aim_target = p.position + Vector2(-800, -260)
	frame_player(-180)
	crop = Rect2i(1450, 330, 1500, 820)
	await wait_frames(6)
	await capture("04_bulldog_left_up")
	p.facing = 1
	p.aim_target = p.position + Vector2(900, -150)
	frame_player()
	crop = Rect2i(950, 330, 1500, 820)
	p.equip_weapon("coil")
	await wait_frames(20)
	await capture("05_coil_idle")
	p.set_process(false)
	p._charge = p.charge_time() * 0.8
	p._update_arm(0.0, true)
	p._charge_fx.queue_redraw()
	await wait_frames(2)
	await capture("06_coil_charge")
	p.set_process(true)
	p._fire()
	await wait_frames(1)
	await capture("07_coil_fire_f01")
	await wait_frames(3)
	await capture("07_coil_fire_f04")
	await wait_frames(40)
	main._toggle_bugbot_battle()
	await wait_frames(110)
	for bot in main.current_room.bugbot_battle.bots:
		bot.set_process(false)
	var bot = main.current_room.bugbot_battle.bots[1]
	main.camera.position = bot.global_position + Vector2(260, -100)
	crop = Rect2i(900, 250, 1900, 950)
	await wait_frames(2)
	await capture("08_arc_mount")
	var origin: Vector2 = bot._arc_mount.muzzle_world()
	var aim: Vector2 = Vector2.from_angle(bot._arc_mount.rotation)
	main.camera.position = origin + aim * 330.0 + Vector2(0, 40)
	bot._arc_mount.kick()
	bot._arc_mount.set_process(true)
	load("res://scripts/weapon_projectile.gd").fire(main.bullets, main.current_room, "arc_weaver", origin, origin + aim * 520.0, main.camera)
	await wait_frames(3)
	await capture("09_arc_flight")
	await wait_frames(9)
	await capture("10_arc_burst")
	await wait_frames(6)
	await capture("11_arc_burst_late")
	print("WEAPON REVIEW COMPLETE")
	quit()
