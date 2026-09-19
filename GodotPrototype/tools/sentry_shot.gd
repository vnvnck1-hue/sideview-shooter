extends SceneTree
## 센트리건 확인용 자동 스크린샷: 작업실(workshop)에서 플레이어를 센트리건 해치 옆에 세우고
## W/↑ 로 전개 → 마우스로 조준 → 사격까지 진행하며 단계마다 한 장씩 저장하고 종료한다.
## 실행: godot --path . --script res://tools/sentry_shot.gd     (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/sentry_*.png  (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\)

const OUT := "user://shots/"
const TURRET_X := 1230.0

var main: Node2D
var t := 0.0
var step := 0
var steps := [
	[0.35, "setup"],
	[0.50, "shot:sentry_00_stowed"],
	[0.60, "interact"],
	[0.75, "shot:sentry_01_deploy_a"],
	[0.95, "shot:sentry_02_deploy_b"],
	[1.15, "shot:sentry_03_deploy_c"],
	[1.50, "shot:sentry_04_ready"],
	[1.60, "aim:900:330"],
	[1.75, "press:shoot"],
	[1.82, "shot:sentry_05_fire_right"],
	[1.95, "shot:sentry_06_fire_burst"],
	[2.30, "release:shoot"],
	[2.40, "aim:-900:120"],
	[2.70, "shot:sentry_07_aim_left"],
	[2.80, "press:shoot"],
	[2.90, "shot:sentry_08_fire_left"],
	[3.10, "release:shoot"],
	[3.40, "shot:sentry_09_smoke"],
	[3.45, "unman"],
	[3.75, "shot:sentry_10_unmanned"],          # 조종을 놓으면 천천히 좌우를 훑는다
	[3.85, "interact"],                          # 다시 잡기
	[3.95, "shot:sentry_11_regrab"],
	[4.00, "retract"],
	[4.25, "shot:sentry_12_retract"],
	[4.75, "shot:sentry_13_stowed_again"],
	[4.85, "quit"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AppFlow.start_room = "workshop"
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
			main.current_room.disable_monsters()
			main.player.position.x = TURRET_X - 230.0
			main.camera.snap()
		"unman":
			main.current_room.sentries[0].set_controlled(false)
		"retract":
			main.current_room.sentries[0]._start_retract()
		"interact":
			main._on_front_door_requested()          # 플레이어의 W/↑ 와 같은 경로
		"aim":
			var world: Vector2 = Vector2(TURRET_X, main.current_room.floor_y) + Vector2(float(parts[1]), -float(parts[2]))
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
			print("SHOT %s  state=%d controlled=%s ammo=%d" % [parts[1], turret.state, turret.controlled, turret.ammo])
		"quit":
			print("SENTRY SHOT DONE")
			return true
	return false
