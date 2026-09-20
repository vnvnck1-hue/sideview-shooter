extends SceneTree
## 단말기 접속 확인용 자동 스크린샷: 숙소 복도의 보안 관제 패널 앞에 서서 접속 → 부팅 → 방어 그리드 →
## 다른 방 센트리건 원격 조종 → 링크 해제 → 접속 종료까지 진행하며 단계마다 한 장씩 저장하고 종료한다.
## 실행: godot --path . --script res://tools/terminal_shot.gd   (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/terminal_*.png  (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\)
## 컨셉·전환 연출 근거는 Docs/TERMINAL_SYSTEM_CONCEPT.md.

const OUT := "user://shots/"
const ROOM := "quarters_corr"
const TERMINAL := "sec_quarters"
const TERMINAL_X := 1560.0

var main: Node2D
var t := 0.0
var step := 0
var steps := [
	[0.40, "setup"],
	[0.60, "shot:terminal_00_world"],          # 벽걸이 보안 패널이 켜져 있는 방
	[0.70, "interact"],                         # W/↑ — 카메라가 화면으로 밀려 들어간다
	[0.82, "shot:terminal_01_push"],            # 밀어넣기 중
	[1.02, "shot:terminal_02_power_on"],        # CRT 전원 인가 (가로 한 줄 → 세로로 펼쳐짐)
	[1.35, "shot:terminal_03_boot"],            # 부팅 타이핑
	[2.10, "shot:terminal_04_menu"],            # 루트 메뉴
	[2.30, "grid"],
	[2.45, "shot:terminal_05_grid"],            # 방어 그리드 (관할 / 권한 없음)
	[2.60, "link"],
	[2.70, "shot:terminal_06_glitch"],          # 채널 전환 글리치
	[3.40, "shot:terminal_07_remote"],          # 원격 조종 — 다른 방, 포탑 전개 중
	[4.20, "aim:420:320"],
	[4.40, "shot:terminal_08_remote_ready"],    # 조준선이 살아 있는 원격 관제 화면
	[4.55, "press:shoot"],
	[4.85, "shot:terminal_09_remote_fire"],     # 원격 사격 (머리글에 총열 게이지)
	[5.30, "release:shoot"],
	[5.45, "unlink"],
	[5.60, "shot:terminal_10_unlink"],          # 역글리치
	[6.30, "shot:terminal_11_back_to_grid"],    # 그리드 목록으로 복귀
	[6.45, "close"],
	[6.55, "shot:terminal_12_power_off"],       # CRT 전원 차단 (가로 한 줄로 수축)
	[7.20, "shot:terminal_13_world_again"],     # 카메라가 물러나 조작 복귀
	[7.30, "quit"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AppFlow.start_room = ROOM
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


func _screen() -> TerminalScreen:
	return main.terminal_screen


func _do(cmd: String) -> bool:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			main.current_room.disable_monsters()          # 화면 구성이 몬스터에 가리지 않게
			main.player.position.x = TERMINAL_X - 90.0
			main.camera.snap()
		"interact":
			main._on_front_door_requested()               # 플레이어의 W/↑ 와 같은 경로
		"grid":
			_screen()._open_grid()
		"link":
			var entry := {}
			for e in _screen()._grid:
				if e["authorized"] and not e["local"]:
					entry = e
					break
			if entry.is_empty():
				printerr("원격으로 잡을 수 있는 다른 방 포탑이 없다")
				return true
			print("LINK → %s (%s)" % [entry["name"], entry["room_title"]])
			main._on_terminal_link(entry)
		"unlink":
			main._on_terminal_unlink()
		"close":
			main._on_terminal_close()
		"aim":
			var turret: SentryTurret = main.controlled_turret
			if turret == null:
				return false
			var world: Vector2 = turret.position + Vector2(float(parts[1]), -float(parts[2]))
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
			print("SHOT %-28s room=%-14s screen_state=%d remote=%s" % [
				parts[1], main.current_room.room_id, _screen().state, not main.remote_link.is_empty()])
		"quit":
			print("TERMINAL SHOT DONE")
			return true
	return false
