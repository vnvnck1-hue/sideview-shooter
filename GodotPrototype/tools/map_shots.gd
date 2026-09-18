extends SceneTree
## 전체 맵 스크린샷: 방마다 맵 뷰어(MapViewer)로 조립해 방 전체가 보이게 맞춘 뒤 한 장씩 저장한다.
## 실행:  godot --path . --script res://tools/map_shots.gd -- [bright|lit] [대기 프레임=40] [방 id ...]
##   bright(기본): 앰비언트를 풀어 모양·프랍 접지 확인용   lit: 게임 조명 그대로
## 저장:  user://shots/map/<방 id>_<모드>.png   (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\map\)
## 헤드리스로는 렌더가 없어 창을 띄운 채로 돈다.

var _ids: Array = []
var _i := -1
var _frames := 0
var _wait := 40
var _bright := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_bright = args[0] != "lit"
	if args.size() > 1:
		_wait = maxi(2, int(args[1]))
	_ids = args.slice(2) if args.size() > 2 else RoomData.ids()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots/map"))
	_next()


func _next() -> void:
	_i += 1
	if _i >= _ids.size():
		print("DONE %d shots" % _ids.size())
		quit()
		return
	_frames = 0
	AppFlow.start_room = _ids[_i]
	change_scene_to_file(AppFlow.MAP_VIEWER_SCENE)


func _process(_delta: float) -> bool:
	if _i >= _ids.size():
		return false
	_frames += 1
	if _frames == 2:
		var viewer := current_scene
		if viewer and viewer.has_method("set_bright"):
			viewer.set_bright(_bright)
	if _frames < _wait:
		return false
	var img := root.get_viewport().get_texture().get_image()
	var out := "user://shots/map/%s_%s.png" % [_ids[_i], "bright" if _bright else "lit"]
	var err := img.save_png(out)
	print("SHOT -> %s (%s)" % [ProjectSettings.globalize_path(out), error_string(err)])
	_next()
	return false
