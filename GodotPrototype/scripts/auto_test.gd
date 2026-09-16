extends Node
## 개발용 자동 테스트: 메인 씬을 띄우고 입력을 시뮬레이션하며 스크린샷을 저장한 뒤 종료한다.
## 실행: godot --path . res://scenes/AutoTest.tscn

var main: Node2D
var t := 0.0
var step := 0
var out_dir := "user://shots/"
var steps := [
	# [시각(초), 동작]  — 마우스 워프는 다음 프레임에 반영되므로 스텝 간격을 0.1초 이상 둔다
	[0.5, "shot:01_workshop_start"],
	[0.52, "aimw:610:158"],
	[0.7, "press:shoot"],
	[0.72, "release:shoot"],
	[0.76, "shot:00a_lamp_hit"],
	[1.0, "shot:00b_lamp_broken"],
	[1.02, "aimw:1560:380"],
	[1.2, "press:shoot"],
	[1.22, "release:shoot"],
	[1.24, "shot:00c_prop_hit"],
	[1.3, "shot:00c2_prop_hit_late"],
	[1.32, "aimw:1070:160"],
	[1.5, "press:shoot"],
	[1.52, "release:shoot"],
	[1.56, "shot:00d_glass_hit"],
	[1.75, "shot:00e_glass_cracked"],
	[1.4, "aim:1300:250"],
	[0.6, "aim:1300:250"],
	[0.8, "press:shoot"],
	[0.9, "shot:02_shoot_upright"],
	[1.0, "release:shoot"],
	[1.1, "aim:-700:140"],
	[1.3, "press:shoot"],
	[1.4, "shot:02b_aim_left_level"],
	[1.5, "release:shoot"],
	[1.6, "aim:600:-30"],
	[1.8, "shot:02c_aim_right_down"],
	[1.9, "aim:-500:420"],
	[2.0, "press:crouch"],
	[2.6, "press:shoot"],
	[2.7, "shot:03_crouch_aim_left"],
	[2.75, "release:shoot"],
	[2.9, "release:crouch"],
	[3.0, "aim:1300:250"],
	[3.2, "press:roll"],
	[3.25, "release:roll"],
	[3.35, "shot:04_roll"],
	[3.45, "shot:04b_roll"],
	[3.8, "press:move_right"],
	[5.2, "shot:05_walking_right"],
	[6.6, "shot:06_after_door"],
	[9.1, "shot:07_storage"],
	[10.6, "shot:08_hangar_enter"],
	[11.6, "release:move_right"],
	[11.9, "shot:09_hangar_stop"],
	[12.0, "aim:-520:170"],
	[12.2, "press:shoot"],
	[12.25, "release:shoot"],
	[12.27, "shot:10_hangar_impact"],
	[12.4, "shot:10b_hangar_debris"],
	[13.2, "shot:11_hangar_idle"],
	[13.3, "quit"],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)


func _process(delta: float) -> void:
	t += delta
	while step < steps.size() and t >= steps[step][0]:
		_do(steps[step][1])
		step += 1


func _do(cmd: String) -> void:
	var parts := cmd.split(":")
	match parts[0]:
		"press":
			Input.action_press(parts[1])
		"release":
			Input.action_release(parts[1])
		"aimw":
			var screen_w: Vector2 = get_viewport().get_canvas_transform() * Vector2(float(parts[1]), float(parts[2]))
			Input.warp_mouse(screen_w)
		"aim":
			# 플레이어 기준 상대 오프셋으로 마우스를 옮긴다 (월드 → 화면)
			var world: Vector2 = main.player.position + Vector2(float(parts[1]), -float(parts[2]))
			var screen: Vector2 = get_viewport().get_canvas_transform() * world
			Input.warp_mouse(screen)
		"shot":
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				# HDR 2D 는 선형 16F 버퍼라 그대로 저장하면 어둡게 보인다. linear_to_srgb 는 8비트에서만 동작.
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			var path := out_dir + parts[1] + ".png"
			img.save_png(path)
			var room: String = main.current_room.room_id if main.current_room else "?"
			print("SHOT %s  room=%s player.x=%.0f state=%s" % [parts[1], room, main.player.position.x, main.player.state])
		"quit":
			print("AUTOTEST DONE")
			get_tree().quit()
