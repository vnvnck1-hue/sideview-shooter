extends SceneTree
## 공간 테스트 씬 스크린샷: SpaceLab 을 띄우고 플레이어를 구획마다 옮겨 가며 한 장씩 저장한다.
## 실행:  godot --path . --script res://tools/space_lab_shot.gd -- [구획당 대기 프레임=70] [문 열고 시작=1]
##        문 열고 시작 0 = 구역 문을 닫아 둔 채로 찍는다 (문 뒤 구획은 장막에 덮여 검게 나온다).
## 저장:  user://shots/space_lab_<번호>_<구획 이름>.png
## 헤드리스로는 렌더가 없으므로 창을 띄운 채로 돈다.

var _wait := 70
var _frames := 0
var _shot := 0
var _points: Array = []
var _names: Array = []
var _open_gates := true          # 구역 문을 미리 다 열고 찍는다 (방 생김새를 보는 용도)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_wait = maxi(4, int(args[0]))
	if args.size() > 1:
		_open_gates = int(args[1]) != 0
	# 구획 가운데 + 통로를 지나며 "옆방이 드러나는" 순간(통로 입구)도 한 장씩
	var spans := SpaceLabData.spans()
	for i in range(spans.size()):
		var ch: Dictionary = SpaceLabData.CHAMBERS[i]
		_points.append((float(spans[i][0]) + float(spans[i][1])) * 0.5)
		_names.append("%02d_%s" % [i, "link" if ch["kind"] == "link" else "room"])
	change_scene_to_file(AppFlow.SPACE_LAB_SCENE)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _wait:
		return false
	_frames = 0
	var main := root.get_child(root.get_child_count() - 1)
	if main == null or not main.has_method("world_to_screen"):
		return false
	var player = main.get("player")
	var camera = main.get("camera")
	if _open_gates:
		_open_gates = false
		for g in (main.get("_gates") if main.get("_gates") != null else []):
			g.activate()
		return false          # 여는 연출이 끝날 때까지 한 주기 기다린다
	if _shot > 0:
		var img := root.get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
		var out := "user://shots/space_lab_%s.png" % _names[_shot - 1]
		var err := img.save_png(out)
		print("SHOT -> %s (%s)" % [ProjectSettings.globalize_path(out), error_string(err)])
	if _shot >= _points.size():
		return true
	player.position.x = _points[_shot]
	camera.snap()
	_shot += 1
	return false
