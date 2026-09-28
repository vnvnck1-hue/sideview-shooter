extends SceneTree
## 규격 테스트 씬 스크린샷: ScaleLab 을 띄우고 구역·후보 자리로 옮겨 가며 한 장씩 저장한다.
## 실행:  godot --path . --script res://tools/scale_lab_shot.gd -- [대기 프레임=40] [세로 판정 규칙=0]
## 저장:  user://shots/scale_lab_<번호>_<이름>.png   (렌더가 필요하므로 창을 띄운 채로 돈다)

var _wait := 40
var _rule := 0
var _frames := 0
var _shot := 0
var _points: Array = []          # [x, 이름]
var D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_wait = maxi(4, int(args[0]))
	if args.size() > 1:
		_rule = int(args[1])
	change_scene_to_file("res://scenes/ScaleLab.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _wait:
		return false
	_frames = 0
	var lab := current_scene
	if lab == null or lab.get("player") == null:
		return false
	if D == null:
		D = load("res://scripts/scale_lab_data.gd")
		lab.rule_index = _rule
		lab.view.set_rules(D.RULES[_rule], float(D.STEP_RULES[lab.step_index]))
		var spans: Array = D.zone_spans()
		for i in range(spans.size()):
			_points.append([float(spans[i][0]) + 1300.0, "zone%d_%s" % [i, D.ZONES[i]["id"]]])
		for id in ["D256", "T224x512", "S48", "C128", "H5", "H9", "전경 기둥 192"]:
			for c in D.candidates():
				if str(c.get("id", "")) == id:
					_points.append([float(c["stand_x"]) + 180.0, "cand_%s" % id.replace(" ", "_")])
		_goto(lab)
		return false
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var out := "user://shots/scale_lab_%02d_%s.png" % [_shot, _points[_shot][1]]
	img.save_png(out)
	print("SHOT -> %s" % ProjectSettings.globalize_path(out))
	_shot += 1
	if _shot >= _points.size():
		return true
	_goto(lab)
	return false


func _goto(lab: Node) -> void:
	lab._teleport(float(_points[_shot][0]))
