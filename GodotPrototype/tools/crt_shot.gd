extends SceneTree
## CRT 프리셋 비교 스크린샷 도구: Main(테스트 씬)을 띄우고 전역 오버레이(CrtFx)의 프리셋을 차례로 바꿔 가며 저장한다.
## 실행:  godot --path . --script res://tools/crt_shot.gd -- [방 id=workshop] [프리셋 번호,...=전체] [대기 프레임=60]
## 예:    -- workshop 0,2,3   → user://shots/crt_workshop_p0_off.png, ..._p2_arcade.png, ..._p3_tv.png
## 창을 띄운 채로 돈다(헤드리스 불가). 저장되는 것은 루트 뷰포트 = CRT 후처리가 적용된 최종 화면.

var _room := "workshop"
var _targets: Array = []
var _wait := 60
var _frames := 0
var _stage := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_room = args[0]
	if args.size() > 1:
		for t in args[1].split(","):
			_targets.append(int(t))
	else:
		for i in CrtPreset.count():
			_targets.append(i)
	if args.size() > 2:
		_wait = maxi(2, int(args[2]))
	if not RoomData.ROOMS.has(_room):
		push_error("unknown room id: " + _room)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	AppFlow.start_room = _room
	change_scene_to_file(AppFlow.TEST_SCENE)


func _process(_delta: float) -> bool:
	if current_scene == null or not current_scene.has_method("_load_room"):   # Main 이 떴는지 확인
		return false
	var crt = root.get_node_or_null("CrtFx")
	if crt == null:
		push_error("CrtFx autoload not found")
		return true
	if _frames == 0:
		crt.set_preset(_targets[_stage], false)
	_frames += 1
	if _frames < _wait:
		return false
	var p: Dictionary = CrtPreset.get_preset(crt.index)
	var out := "user://shots/crt_%s_p%d_%s.png" % [_room, crt.index, p["id"]]
	root.get_viewport().get_texture().get_image().save_png(out)
	print("crt preset %d (%s) -> %s" % [crt.index, p["name"], ProjectSettings.globalize_path(out)])
	_stage += 1
	_frames = 0
	return _stage >= _targets.size()
