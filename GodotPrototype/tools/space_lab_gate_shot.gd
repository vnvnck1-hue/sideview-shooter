extends SceneTree
## 구역 문(SectionGate) 스크린샷: 닫힌 문 앞 → 여는 중 → 열린 뒤를 한 문마다 세 장 찍는다.
## "문을 열면 저쪽 구역이 이쪽과 한 화면에 이어진다" 가 실제로 그렇게 보이는지 보는 용도.
##
## 실행:  godot --path . --script res://tools/space_lab_gate_shot.gd -- [문 번호=0] [대기 프레임=60]
## 저장:  user://shots/gate<번호>_closed.png · _opening.png · _open.png

var _wait := 60
var _frames := 0
var _stage := 0
var _gate_i := 0
var _main: Node = null
var _gate = null


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_gate_i = maxi(0, int(args[0]))
	if args.size() > 1:
		_wait = maxi(4, int(args[1]))
	change_scene_to_file(AppFlow.SPACE_LAB_SCENE)


func _process(_delta: float) -> bool:
	if _main == null:
		_main = root.get_child(root.get_child_count() - 1)
		if _main == null or not _main.has_method("world_to_screen"):
			_main = null
			return false
		var gates: Array = _main.get("_gates")
		if gates == null or gates.size() <= _gate_i:
			printerr("구역 문 %d 가 없다 (문 %d개)" % [_gate_i, gates.size() if gates else 0])
			return true
		_gate = gates[_gate_i]
		# 문 앞으로 데려간다 (플레이어 이동 한계가 이미 문 앞에서 멈춰 있다)
		_main.get("player").position.x = _gate.gate_x - SectionGate.STOP_MARGIN - 60.0
		_main.get("camera").snap()
	_frames += 1
	if _frames < _wait:
		return false
	_frames = 0
	match _stage:
		0:
			_shot("closed")
			_gate.activate()
			_wait = maxi(8, int(SectionGate.OPEN_TIME * 60.0 * 0.45))
		1:
			_shot("opening")
			_wait = 60
		2:
			_shot("open")
		_:
			return true
	_stage += 1
	return false


func _shot(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var out := "user://shots/gate%d_%s.png" % [_gate_i, tag]
	print("SHOT -> %s (%s)" % [ProjectSettings.globalize_path(out), error_string(img.save_png(out))])
