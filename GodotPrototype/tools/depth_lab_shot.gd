extends SceneTree
## 공간감 테스트 씬 스크린샷: DepthLab 을 띄우고 구역마다 대표 자리(바닥·발판 위)로 옮겨 가며 저장한다.
## 실행:  godot --path . --script res://tools/depth_lab_shot.gd -- [대기 프레임=45] [이름 필터]
## 저장:  user://shots/depth_lab_<번호>_<이름>.png   (렌더가 필요하므로 창을 띄운 채로 돈다)

var _wait := 45
var _frames := 0
var _shot := 0
var _applied := -1
var _plan: Array = []        # [이름, {x, h, comp, speed, flat, cam}]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_wait = maxi(10, int(args[0]))
	var all := [
		["dock_floor", {"x": 900.0, "h": 0.0}],
		["dock_deck", {"x": 2400.0, "h": 144.0}],
		["hangar_floor", {"x": 4700.0, "h": 0.0}],
		["hangar_gantry1", {"x": 5900.0, "h": 360.0}],
		["hangar_gantry2", {"x": 7100.0, "h": 760.0}],
		["duct_entry", {"x": 9500.0, "h": 0.0}],
		["duct_fan", {"x": 10600.0, "h": 0.0}],
		["duct_crawl", {"x": 11700.0, "h": 0.0}],
		["shaft_floor", {"x": 12700.0, "h": 0.0}],
		["shaft_mid", {"x": 13400.0, "h": 1360.0}],
		["shaft_top", {"x": 12800.0, "h": 2120.0}],
		["relay_catwalk", {"x": 15000.0, "h": 2240.0}],
		["relay_crane", {"x": 16600.0, "h": 1440.0}],
		["relay_floor", {"x": 16000.0, "h": 0.0}],
		["flat_hangar", {"x": 5900.0, "h": 360.0, "flat": true}],
		["few_relay", {"x": 15000.0, "h": 2240.0, "comp": 2}],
	]
	var filt := args[1] if args.size() > 1 else ""
	for p in all:
		if filt == "" or String(p[0]).contains(filt):
			_plan.append(p)
	change_scene_to_file("res://scenes/DepthLab.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var lab := current_scene
	if lab == null or lab.get("motion") == null or lab.motion == null:
		return false
	if _applied != _shot:
		_applied = _shot
		_frames = 1
		_apply(lab, _plan[_shot][1])
	if _frames < _wait:
		return false
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var out := "user://shots/depth_lab_%02d_%s.png" % [_shot, _plan[_shot][0]]
	img.save_png(out)
	print("SHOT -> %s" % ProjectSettings.globalize_path(out))
	_shot += 1
	return _shot >= _plan.size()


func _apply(lab: Node, p: Dictionary) -> void:
	var rebuild := false
	if int(p.get("comp", 0)) != lab.comp_i:
		lab.comp_i = int(p.get("comp", 0))
		lab._apply_composition()
	if bool(p.get("flat", false)) != lab.flat:
		lab.flat = bool(p.get("flat", false))
		rebuild = true
	if rebuild:
		lab._rebuild()
	lab.player.position.x = float(p["x"])
	lab.player.velocity_x = 0.0
	lab.motion.snap_to_ground(float(p["h"]) + 1.0)
	lab._feet_y = lab.current_room.floor_y - lab.motion.g
	lab.camera.snap()
