extends SceneTree
## 거대종 스크린샷: 격납고를 띄우고 거대종 앞에 플레이어를 세운 뒤
## 걷기 → 포효 → 산탄 → 내려찍기를 순서대로 강제해 한 장씩 저장한다.
## 배율·히트박스·자세가 방 안에서 실제로 어떻게 보이는지 확인하는 용도다.
##
## 실행:  godot --path . --script res://tools/giant_shot.gd -- [대기 프레임=26] [방 id=hangar]
##        방 id 에 space_lab 을 주면 공간 테스트 씬의 거대종을 본다 (SpaceLabData 를 먼저 등록한다).
## 저장:  user://shots/giant_<번호>_<이름>.png
## 헤드리스로는 렌더가 없으므로 창을 띄운 채로 돈다.

const DEFAULT_ROOM := "hangar"

var _room := DEFAULT_ROOM
var _wait := 26
var _frames := 0
var _step := 0
## [이름, 이 단계 들어갈 때 시킬 일]
var _plan := [
	["01_stand", "none"],
	["02_walk", "none"],
	["03_roar", "roar"],
	["04_roar_hold", "none"],
	["05_spray_open", "spray"],
	["06_spray_volley", "none"],
	["07_spray_late", "none"],
	["08_slam_rear", "slam"],
	["09_slam_drop", "none"],
	["10_slam_impact", "none"],
	["11_hit", "hit"],
	["12_after", "none"],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_wait = maxi(4, int(args[0]))
	if args.size() > 1:
		_room = String(args[1])
	# 공간 테스트 방은 RoomData.ROOMS 가 아니라 extra 에 얹힌다 — 먼저 등록해야 start_test 가 찾는다
	if _room == SpaceLabData.ROOM_ID:
		SpaceLabData.register()
		AppFlow.start_room = SpaceLabData.ROOM_ID
		change_scene_to_file(AppFlow.SPACE_LAB_SCENE)
		return
	AppFlow.start_test(self, _room)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < _wait:
		return false
	_frames = 0
	var main := root.get_child(root.get_child_count() - 1)
	if main == null or main.get("current_room") == null:
		return false
	var giant := _giant(main)
	if giant == null:
		printerr("%s 에 거대종이 없다 — monsters 배치를 확인할 것" % _room)
		return true
	if _step > 0:
		_save(_plan[_step - 1][0])
	if _step >= _plan.size():
		print("거대종: hp %d/%d · 히트박스 %s" % [giant.hp, giant.max_hp, giant.hit_rect()])
		return true

	# 플레이어를 산탄 사거리 밖(걷기·포효) → 내려찍기 거리 안으로 옮겨 가며 본다
	var player = main.get("player")
	var act: String = _plan[_step][1]
	match act:
		"roar", "spray":
			player.position.x = giant.position.x + 900.0
		"slam", "hit":
			player.position.x = giant.position.x + 420.0
	main.get("camera").snap()
	match act:
		"roar":
			giant.force_roar()
		"spray":
			giant.force_spray()
		"slam":
			giant.force_slam()
		"hit":
			var c: Vector2 = giant.hit_center()
			giant.hit(c, 1.0, 2.0)
	_step += 1
	return false


func _giant(main: Node) -> Node2D:
	for m in main.current_room.monsters:
		if is_instance_valid(m) and m.get("is_giant"):
			return m
	return null


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var out := "user://shots/giant_%s_%s.png" % [_room, name]
	var err := img.save_png(out)
	print("SHOT -> %s (%s)" % [ProjectSettings.globalize_path(out), error_string(err)])
