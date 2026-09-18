extends SceneTree
## 물 착수 스크린샷 도구: 저수조실(tank_room)을 테스트 씬으로 띄우고, 플레이어 앞 수면에 총알을 한 발 넣은 뒤
## 몇 프레임 지나 한 장 저장하고 종료한다. 물기둥·물보라·수면 출렁임 확인용.
## 실행:  godot --path . --script res://tools/water_shot.gd -- [방 id=tank_room] [사격 후 대기 프레임=6] [사격 전 대기=120]
## 저장:  user://shots/<방 id>_water_<대기>.png

var _frames := 0
var _pre := 120
var _post := 6
var _room := "tank_room"
var _fired := false
var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_room = args[0]
	if args.size() > 1:
		_post = maxi(1, int(args[1]))
	if args.size() > 2:
		_pre = maxi(2, int(args[2]))
	AppFlow.start_room = _room
	_out = "user://shots/%s_water_%d.png" % [_room, _post]
	change_scene_to_file(AppFlow.TEST_SCENE)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == _pre and not _fired:
		_fired = true
		var main := current_scene
		var player: Node2D = main.get("player")
		var room: Node = main.get("current_room")
		if player == null or room == null or room.get("water") == null:
			push_error("water room not ready")
			quit(1)
			return true
		var w = room.get("water")
		# 몬스터·프랍이 없는 수면 지점을 고른다 (플레이어 앞뒤 60~420px 를 훑음)
		var target := Vector2(player.position.x + 260.0, w.surface_at(player.position.x + 260.0) + 6.0)
		for off in [260.0, 200.0, 320.0, -200.0, -260.0, 140.0, -140.0, 380.0, -320.0, 420.0, -420.0, 80.0, -80.0]:
			var tx: float = player.position.x + off
			var cand := Vector2(tx, w.surface_at(tx) + 6.0)
			var kind: String = room.call("hit_at", cand)["kind"]
			if (kind == "none" or kind == "wall") and w.covers(tx):
				target = cand
				break
		main.call("_on_player_shoot", player.position + Vector2(20.0, -70.0), target)
		print("FIRED at ", target)
	if _frames < _pre + _post:
		return false
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	var err := img.save_png(_out)
	print("SHOT -> %s (%s)" % [ProjectSettings.globalize_path(_out), error_string(err)])
	return true
