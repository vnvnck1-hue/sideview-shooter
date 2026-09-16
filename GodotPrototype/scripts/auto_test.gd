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
	# 벽 피격 열 잔광 + 전선 스침
	[1.8, "aimw:1240:300"],
	[1.95, "press:shoot"],
	[1.97, "release:shoot"],
	[2.05, "aimw:1250:330"],
	[2.15, "press:shoot"],
	[2.17, "release:shoot"],
	[2.3, "shot:00f_wall_heat"],
	[3.4, "shot:00g_wall_heat_cooling"],
	# 프랍 파츠 파괴: 캐비넷 같은 자리에 여러 발
	[3.45, "aimw:330:330"],
	[3.6, "press:shoot"], [3.62, "release:shoot"],
	[3.75, "press:shoot"], [3.77, "release:shoot"],
	[3.9, "press:shoot"], [3.92, "release:shoot"],
	[3.95, "shot:00h_prop_chunks"],
	[4.0, "aimw:300:290"],
	[4.05, "press:shoot"], [4.07, "release:shoot"],
	[4.2, "press:shoot"], [4.22, "release:shoot"],
	[4.35, "press:shoot"], [4.37, "release:shoot"],
	[4.4, "shot:00i_prop_chunks_2"],
	[5.0, "shot:00j_prop_broken_rest"],
	# 비상등 파손
	[5.05, "aimw:1370:118"],
	[5.2, "press:shoot"], [5.22, "release:shoot"],
	[5.26, "shot:00k_beacon_hit"],
	[5.7, "shot:00l_beacon_dark"],
	[6.0, "aim:1300:250"],
	[6.2, "press:shoot"],
	[6.3, "shot:02_shoot_upright"],
	[6.4, "release:shoot"],
	[6.5, "aim:-700:140"],
	[6.7, "press:shoot"],
	[6.8, "shot:02b_aim_left_level"],
	[6.9, "release:shoot"],
	[7.0, "aim:600:-30"],
	[7.2, "shot:02c_aim_right_down"],
	[7.3, "aim:-500:420"],
	[7.4, "press:crouch"],
	[8.0, "press:shoot"],
	[8.1, "shot:03_crouch_aim_left"],
	[8.15, "release:shoot"],
	[8.3, "release:crouch"],
	[8.4, "aim:1300:250"],
	[8.6, "press:roll"],
	[8.65, "release:roll"],
	[8.75, "shot:04_roll"],
	[8.85, "shot:04b_roll"],
	[9.2, "press:move_right"],
	[10.1, "shot:05_corridor_fire"],
	[10.6, "shot:05b_walking_right"],
	[12.0, "shot:06_after_door"],
	[12.05, "release:move_right"],
	[12.8, "shot:07_storage_fire"],
	[13.6, "shot:07b_storage_fire_2"],
	[13.7, "press:move_right"],
	[15.6, "shot:08_hangar_enter"],
	[16.55, "release:move_right"],
	[16.9, "shot:09_hangar_fire_smoke"],
	[17.0, "aim:-520:170"],
	[17.2, "press:shoot"],
	[17.25, "release:shoot"],
	[17.27, "shot:10_hangar_impact"],
	[17.4, "shot:10b_hangar_debris"],
	[18.4, "shot:11_hangar_idle"],
	[18.5, "quit"],
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
