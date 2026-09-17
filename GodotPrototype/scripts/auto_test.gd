extends Node
## 개발용 자동 테스트: 메인 씬을 띄우고 입력을 시뮬레이션하며 스크린샷을 저장한 뒤 종료한다.
## 실행: godot --path . res://scenes/AutoTest.tscn

var main: Node2D
var t := 0.0
var step := 0
var out_dir := "user://shots/"
var steps := [
	# [시각(초), 동작]  — 마우스 워프는 다음 프레임에 반영되므로 스텝 간격을 0.1초 이상 둔다
	[0.6, "shot:01_workshop_start"],
	# 몬스터: 크롤러가 다가오고, 맞고, 점프하고, 죽는다 (aimm = 첫 몬스터 중심 조준, mjump = 강제 점프)
	[0.62, "aimm"],
	[0.8, "shot:m0_crawler_approach"],
	[0.82, "aimm"],
	[0.9, "press:shoot"], [0.92, "release:shoot"],
	[0.93, "shot:m1_crawler_hit"],
	[1.0, "shot:m1b_crawler_hit_late"],
	[1.05, "mjump"],
	[1.35, "shot:m2_crawler_jump_air"],
	[1.6, "shot:m2b_crawler_jump_peak"],
	[1.9, "shot:m2c_crawler_land"],
	# 연사(홀드)로 처치 — 조준은 0.1초마다 갱신
	[2.0, "aimm"],
	[2.1, "press:shoot"],
	[2.2, "aimm"], [2.3, "aimm"], [2.4, "aimm"], [2.5, "aimm"], [2.6, "aimm"],
	[2.62, "release:shoot"],
	[2.66, "shot:m3_crawler_dying"],
	[2.8, "shot:m3a_crawler_chunks"],
	[3.4, "shot:m3b_crawler_dead"],
	[2.95, "mattack"],
	[3.2, "shot:m4_crawler_spit"],
	[3.42, "shot:m4b_acid_flight"],
	[3.6, "shot:m4c_acid_splat"],
	[3.32, "aimw:610:158"],
	[3.5, "press:shoot"],
	[3.52, "release:shoot"],
	[3.56, "shot:00a_lamp_hit"],
	[3.8, "shot:00b_lamp_broken"],
	[3.82, "aimw:1560:380"],
	[4, "press:shoot"],
	[4.02, "release:shoot"],
	[4.04, "shot:00c_prop_hit"],
	[4.1, "shot:00c2_prop_hit_late"],
	[4.12, "aimw:1070:160"],
	[4.3, "press:shoot"],
	[4.32, "release:shoot"],
	[4.36, "shot:00d_glass_hit"],
	[4.55, "shot:00e_glass_cracked"],
	# 벽 피격 열 잔광 + 전선 스침
	[4.6, "aimw:1240:300"],
	[4.75, "press:shoot"],
	[4.77, "release:shoot"],
	[4.85, "aimw:1250:330"],
	[4.95, "press:shoot"],
	[4.97, "release:shoot"],
	[5.1, "shot:00f_wall_heat"],
	[6.2, "shot:00g_wall_heat_cooling"],
	# 프랍 파츠 파괴: 캐비넷 같은 자리에 여러 발
	[6.25, "aimw:330:330"],
	[6.4, "press:shoot"], [3.62, "release:shoot"],
	[6.55, "press:shoot"], [3.77, "release:shoot"],
	[6.7, "press:shoot"], [3.92, "release:shoot"],
	[6.75, "shot:00h_prop_chunks"],
	[6.8, "aimw:300:290"],
	[6.85, "press:shoot"], [4.07, "release:shoot"],
	[7, "press:shoot"], [4.22, "release:shoot"],
	[7.15, "press:shoot"], [4.37, "release:shoot"],
	[7.2, "shot:00i_prop_chunks_2"],
	[7.8, "shot:00j_prop_broken_rest"],
	# 비상등 파손
	[7.85, "aimw:1370:118"],
	[8, "press:shoot"], [5.22, "release:shoot"],
	[8.06, "shot:00k_beacon_hit"],
	[8.5, "shot:00l_beacon_dark"],
	[8.8, "aim:1300:250"],
	[9, "press:shoot"],
	[9.1, "shot:02_shoot_upright"],
	[9.2, "release:shoot"],
	[9.3, "aim:-700:140"],
	[9.5, "press:shoot"],
	[9.6, "shot:02b_aim_left_level"],
	[9.7, "release:shoot"],
	[9.8, "aim:600:-30"],
	[10, "shot:02c_aim_right_down"],
	[10.1, "aim:-500:420"],
	[10.2, "press:crouch"],
	[10.8, "press:shoot"],
	[10.9, "shot:03_crouch_aim_left"],
	[10.95, "release:shoot"],
	[11.1, "release:crouch"],
	[11.2, "aim:1300:250"],
	[11.4, "press:roll"],
	[11.45, "release:roll"],
	[11.55, "shot:04_roll"],
	[11.65, "shot:04b_roll"],
	[12, "press:move_right"],
	[12.9, "shot:05_corridor_fire"],
	[13.4, "shot:05b_walking_right"],
	[14.8, "shot:06_after_door"],
	[14.85, "release:move_right"],
	[15.6, "shot:07_storage_fire"],
	[16.4, "shot:07b_storage_fire_2"],
	[16.5, "press:move_right"],
	[18.4, "shot:08_hangar_enter"],
	[19.35, "release:move_right"],
	[19.7, "shot:09_hangar_fire_smoke"],
	[19.8, "aim:-520:170"],
	[20, "press:shoot"],
	[20.05, "release:shoot"],
	[20.07, "shot:10_hangar_impact"],
	[20.2, "shot:10b_hangar_debris"],
	[21.2, "shot:11_hangar_idle"],
	# 격납고 불 앞 (확정 세팅: 잉걸 불 · 그라데이션 필 · 부드러운 림)
	[21.22, "warp:2250"],
	[21.3, "aim:250:200"],
	[22.4, "shot:12_hangar_fire_close"],
	[22.5, "quit"],
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
		"fire":
			main.set_fire_style(int(parts[1]))
		"mood":
			main.set_light_mood(int(parts[1]))
		"rim":
			main.set_rim_preset(int(parts[1]))
		"mousepos":
			print("MOUSE %s %s" % [parts[1], get_viewport().get_mouse_position()])
		"aimm":
			# 첫 살아 있는 몬스터의 히트 박스 중심을 조준
			for m in main.current_room.monsters:
				if is_instance_valid(m) and not m.is_dead():
					Input.warp_mouse(get_viewport().get_canvas_transform() * m.hit_center())
					break
		"mattack":
			for m in main.current_room.monsters:
				if is_instance_valid(m) and not m.is_dead():
					m.force_attack()
					break
		"mjump":
			for m in main.current_room.monsters:
				if is_instance_valid(m) and not m.is_dead():
					m.force_jump()
					break
		"warp":
			main.player.position.x = float(parts[1])
			main.camera.snap()
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
			var mon := ""
			for m in main.current_room.monsters:
				if is_instance_valid(m):
					mon += " crawler(x=%.0f hp=%d state=%d)" % [m.position.x, m.hp, m.state]
			print("SHOT %s  room=%s player.x=%.0f state=%s%s" % [parts[1], room, main.player.position.x, main.player.state, mon])
		"quit":
			print("AUTOTEST DONE")
			get_tree().quit()
