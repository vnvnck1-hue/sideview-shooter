extends SceneTree
## 근경 랩 스모크 테스트: 랩 모드로 방을 띄워 한 장 찍고 끝낸다.
## 실행: godot --path . --script res://tools/foreground_lab_shot.gd -- [방 id=workshop] [대기 프레임=90]

var _room := "workshop"
var _wait := 90
var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_room = args[0]
	if args.size() > 1:
		_wait = maxi(2, int(args[1]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	AppFlow.start_foreground_lab(self, _room)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _wait:
		return false
	var out := "user://shots/lab_%s.png" % _room
	root.get_viewport().get_texture().get_image().save_png(out)
	var main = current_scene
	var lab = main.current_room.foreground.get_node_or_null("ForegroundLab") if main and main.current_room and main.current_room.foreground else null
	print("lab shot room=%s items=%d lab=%s -> %s" % [_room, main.current_room.foreground.items.size() if lab else -1, lab != null, ProjectSettings.globalize_path(out)])
	return true
