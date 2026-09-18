extends SceneTree
## 공간감 프리셋 A/B 검증 도구: Main 을 띄워 프리셋(0 이전 / 1 근경 분리)을 실행 중에 바꿔 가며 스크린샷을 저장한다.
## 실행:  godot --path . --script res://tools/depth_ab_shot.gd -- <방 id> [프리셋 번호,...=1,0] [대기 프레임=90]
## 예:    -- workshop 1,0   → 시작(기본) → 1 → 0 순서로 전환, user://shots/depth_<방>_<단계>_p<번호>.png
## 창을 띄운 채로 돈다(헤드리스 불가).

var _room := "workshop"
var _targets: Array = [1, 0]
var _wait := 90
var _frames := 0
var _stage := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_room = args[0]
	if args.size() > 1:
		_targets = []
		for t in args[1].split(","):
			_targets.append(int(t))
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
	_frames += 1
	if _frames < _wait:
		return false
	_frames = 0
	var main = current_scene
	if main == null or not main.has_method("_switch_depth_preset"):
		return false
	var out := "user://shots/depth_%s_%d_p%d.png" % [_room, _stage, DepthPreset.index]
	root.get_viewport().get_texture().get_image().save_png(out)
	print("depth stage %d preset %d (%s) room=%s player.x=%.1f -> %s" % [
		_stage, DepthPreset.index, DepthPreset.current()["id"], main.current_room.room_id, main.player.position.x,
		ProjectSettings.globalize_path(out)])
	if _stage >= _targets.size():
		return true
	main._switch_depth_preset(_targets[_stage])
	_stage += 1
	return false
