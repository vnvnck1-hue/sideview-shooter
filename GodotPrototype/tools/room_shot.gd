extends SceneTree
## 방 스크린샷 도구: 고른 방을 플레이 씬(main) · 메인 게임 씬(game) · 맵 뷰어(viewer)로 띄워 N 프레임 뒤 한 장 저장하고 종료한다.
## 실행:  godot --path . --script res://tools/room_shot.gd -- <방 id> [main|game|viewer] [대기 프레임=90]
## 저장:  user://shots/<방 id>_<모드>.png   (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\)
## 헤드리스로는 렌더가 없어 창을 띄운 채로 돈다. 방 배치·층고·카메라 프레이밍을 빠르게 확인하는 용도.

var _frames := 0
var _wait := 90
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var room: String = args[0] if args.size() > 0 else "hall"
	var mode: String = args[1] if args.size() > 1 else "main"
	if args.size() > 2:
		_wait = maxi(2, int(args[2]))
	if not RoomData.ROOMS.has(room):
		push_error("unknown room id: " + room)
		quit(1)
		return
	AppFlow.start_room = room
	_out = "user://shots/%s_%s.png" % [room, mode]
	match mode:
		"game": change_scene_to_file(AppFlow.MAIN_GAME_SCENE)
		"viewer": change_scene_to_file(AppFlow.MAP_VIEWER_SCENE)
		_: change_scene_to_file(AppFlow.TEST_SCENE)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _wait:
		return false
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var err := img.save_png(_out)
	print("SHOT -> %s (%s)" % [ProjectSettings.globalize_path(_out), error_string(err)])
	return true
