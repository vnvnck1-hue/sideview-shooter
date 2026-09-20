extends SceneTree
## 센트리건 확인용 자동 스크린샷: 가장 큰 방(격납고)에서 플레이어를 센트리건 해치 옆에 세우고
## W/↑ 로 전개 → 마우스로 조준 → 연사(과열) → 몬스터 피격까지 진행하며 단계마다 한 장씩 저장하고 종료한다.
## 실행: godot --path . --script res://tools/sentry_shot.gd [-- clean]   (렌더가 필요하므로 --headless 금지)
##       clean 을 주면 몬스터를 치우고 찍는다 (접지·크기 확인용. 기본은 몬스터를 두고 타격감까지 확인)
## 저장: user://shots/sentry_*.png  (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\)

const OUT := "user://shots/"

var main: Node2D
var t := 0.0
var step := 0
var steps := [
	[0.35, "setup"],
	[0.40, "aim:-300:340"],                    # 조준점이 잘 보이는 빈 벽 쪽 (레티클 확인용)
	[0.50, "shot:sentry_00_stowed"],
	[0.60, "interact"],
	[0.75, "shot:sentry_01_deploy_a"],
	[0.95, "shot:sentry_02_deploy_b"],
	[1.15, "shot:sentry_03_deploy_c"],
	[1.40, "aim:-300:340"],
	[1.50, "shot:sentry_04_ready"],
	# 오른쪽으로 짧게 연사
	[1.60, "aim:560:300"],
	[1.75, "press:shoot"],
	[1.82, "shot:sentry_05_fire_right"],
	[1.95, "shot:sentry_06_fire_burst"],
	[2.10, "release:shoot"],
	# 몬스터 피격 — 넉백·체액·육편
	[2.20, "aimm"],
	[2.30, "press:shoot"],
	[2.40, "shot:sentry_07_monster_hit"],
	[2.55, "aimm"],
	[2.70, "shot:sentry_08_monster_burst"],
	[2.85, "release:shoot"],
	# 기계식 선회 시차 — 포인터를 반대쪽으로 확 옮기면 조준선(= 실제 조준 방향)이 뒤늦게 따라온다
	[2.88, "aim:700:-120"],                    # 먼저 오른쪽 아래로
	[2.98, "aim:-700:420"],                    # 그리고 왼쪽 위로 확 옮긴다
	[3.06, "shot:sentry_08b_lag_a"],           # +0.08초: 아직 오른쪽을 겨눈다
	[3.35, "shot:sentry_08c_lag_b"],           # +0.37초: 돌아가는 중
	[3.90, "shot:sentry_08d_lag_c"],           # +0.92초: 조준점에 도착
	# 길게 물고 있으면 총열이 달아오르다 과열로 잠긴다 (한 발 0.0105 → 약 5.2초 연사)
	[4.05, "aim:380:250"],
	[4.10, "press:shoot"],
	[5.95, "shot:sentry_09_hot_barrel"],
	[9.35, "shot:sentry_10_overheat"],
	[9.45, "release:shoot"],
	[9.50, "aim:-300:340"],
	[9.80, "shot:sentry_11_vent_smoke"],
	# 게이지가 식는 과정 (과열 잠금 해제 → 계속 냉각)
	[10.55, "shot:sentry_12_cooling_a"],
	[11.55, "shot:sentry_13_cooling_b"],
	[12.55, "shot:sentry_14_cooling_c"],
	# 부앙 한계 확인 — 위 +75° / 아래 -20°
	[12.60, "aim:300:1150"],
	[13.70, "shot:sentry_14b_high_up"],
	[13.80, "aim:300:-240"],
	[14.70, "shot:sentry_14c_low_down"],
	# 조종 해제 → 다시 잡기 → 격납
	[14.80, "unman"],
	[14.86, "release:crouch"],
	[15.10, "shot:sentry_15_unmanned"],
	[15.20, "interact"],
	[15.30, "shot:sentry_16_regrab"],
	[15.40, "retract"],
	[15.65, "shot:sentry_17_retract"],
	[16.15, "shot:sentry_18_stowed_again"],
	[16.25, "quit"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AppFlow.start_room = RoomData.SENTRY_TEST_ROOM
	change_scene_to_file(AppFlow.TEST_SCENE)


func _process(delta: float) -> bool:
	if main == null:
		main = current_scene as Node2D
		if main == null or main.get("player") == null:
			return false
	t += delta
	while step < steps.size() and t >= steps[step][0]:
		var cmd: String = steps[step][1]
		step += 1
		if _do(cmd):
			return true
	return false


## true 를 돌려주면 종료
func _do(cmd: String) -> bool:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			if OS.get_cmdline_user_args().has("clean"):
				main.current_room.disable_monsters()
			main.player.position.x = RoomData.SENTRY_TEST_X - SentryTurret.INTERACT_RANGE * 0.7
			main.camera.snap()
		"aimm":
			for m in main.current_room.monsters:
				if is_instance_valid(m) and not m.is_dead():
					Input.warp_mouse(main.world_to_screen(m.hit_center()))
					break
		"unman":
			# 실제 키 경로로 손 떼기 (S/Ctrl/↓ = crouch). 다음 프레임에 Main 이 읽는다.
			Input.action_press("crouch")
		"retract":
			main.current_room.sentries[0]._start_retract()
		"interact":
			main._on_front_door_requested()          # 플레이어의 W/↑ 와 같은 경로
		"aim":
			var world: Vector2 = Vector2(RoomData.SENTRY_TEST_X, main.current_room.floor_y) + Vector2(float(parts[1]), -float(parts[2]))
			Input.warp_mouse(main.world_to_screen(world))
		"press":
			Input.action_press(parts[1])
		"release":
			Input.action_release(parts[1])
		"shot":
			var img := root.get_viewport().get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			img.save_png(OUT + parts[1] + ".png")
			var turret = main.current_room.sentries[0]
			var mouse_world: Vector2 = main.world.get_global_mouse_position()
			print("SHOT %s  state=%d controlled=%s heat=%.2f over=%s facing=%d angle=%.3f mouse=(%.0f,%.0f) impact=(%.0f,%.0f)" % [
				parts[1], turret.state, turret.controlled, turret.heat, turret.overheated,
				turret.facing, turret._angle, mouse_world.x, mouse_world.y,
				turret._impact_point().x, turret._impact_point().y])
		"quit":
			print("SENTRY SHOT DONE")
			return true
	return false
