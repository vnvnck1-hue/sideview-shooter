extends SceneTree
## 단말기 지도 확인용 자동 스크린샷 (Docs/STATION_MAP.md).
##   ① 창고의 구역 현황 단말기(survey_storage) → 구역 지도 — 실시간/과거/미판독 세 등급이 한 화면에 나오게
##      다녀온 방을 몇 개 미리 심어 둔다.
##   ② 숙소 복도의 보안 관제 패널(sec_quarters) → 방어 그리드 — 같은 지도 위에서 포탑을 고른다.
## 실행: godot --path . --script res://tools/map_shot.gd   (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/map_*.png  (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\)

const OUT := "user://shots/"
const ROOM_A := "storage"               # 구역 현황 단말기 (벽걸이, x 900)
const TERMINAL_A_X := 900.0
const ROOM_B := "quarters_corr"         # 보안 관제 패널 (벽걸이, x 1560)
const TERMINAL_B_X := 1560.0

## 지도에 "다녀온 방(과거 기록)" 등급을 만들기 위해 미리 심는 방 — 창고 단말의 관할 밖인 구역에서 고른다
const SEEN := ["quarters_corr", "bunk_b", "power_relay", "cable_run"]

var main: Node2D
var t := 0.0
var step := 0
var steps := [
	[0.40, "setup"],
	[0.70, "interact"],
	[2.10, "shot:map_00_menu"],              # survey 루트 메뉴 — 첫 줄이 구역 지도
	[2.25, "enter"],
	[2.45, "shot:map_01_survey"],            # 구역 지도 (커서는 지금 있는 방)
	[2.60, "key:left"],
	[2.75, "shot:map_02_cursor_left"],       # 같은 줄에서 옆 방으로
	[2.90, "key:down"],
	[3.05, "key:down"],
	[3.20, "shot:map_03_cursor_down"],       # 다른 구역 줄로 건너뛰기 (미판독 방)
	[3.35, "close"],

	[4.10, "room_b"],
	[4.40, "interact"],
	[5.80, "shot:map_04_sec_menu"],          # 보안 관제 루트 메뉴
	[5.95, "enter"],
	[6.15, "shot:map_05_grid"],              # 방어 그리드 — 지도 위의 포탑
	[6.30, "key:right"],
	[6.50, "shot:map_06_grid_moved"],        # 커서가 다른 방 포탑으로
	[6.65, "close"],
	[7.30, "quit"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AppFlow.start_room = ROOM_A
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
			for id in SEEN:
				AppFlow.visit(str(id))
			main.current_room.disable_monsters()
			main.player.position.x = TERMINAL_A_X - 90.0
			main.camera.snap()
		"room_b":
			main._load_room(ROOM_B, TERMINAL_B_X - 90.0, 1)
			main.current_room.disable_monsters()
			main.camera.snap()
		"interact":
			main._on_front_door_requested()               # 플레이어의 W/↑ 와 같은 경로
		"enter":
			_screen()._activate()
		"key":
			var dir := Vector2i.ZERO
			match parts[1]:
				"left": dir = Vector2i(-1, 0)
				"right": dir = Vector2i(1, 0)
				"up": dir = Vector2i(0, -1)
				"down": dir = Vector2i(0, 1)
			_screen()._map.move(dir)
		"close":
			main._on_terminal_close()
		"shot":
			var img := root.get_viewport().get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			img.save_png(OUT + parts[1] + ".png")
			var sel: Dictionary = _screen()._map.selected()
			print("SHOT %-24s room=%-14s state=%d cursor=%s" % [
				parts[1], main.current_room.room_id, _screen().state, sel.get("room", "-")])
		"quit":
			print("MAP SHOT DONE")
			return true
	return false
