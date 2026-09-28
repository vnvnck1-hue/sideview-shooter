extends SceneTree
## 바닥 안개 확인용 자동 스크린샷 — 같은 자리에서 GroundFog 프리셋을 하나씩 바꿔 가며 화면 전체를 찍는다.
## 실행: godot --path . --script res://tools/fog_shot.gd -- [방 id]   (렌더 필요 — --headless 금지)
## 저장: user://shots/fog_<번호>_<id>.png

const OUT := "user://shots/"

var room_id := "workshop"
var main: Node2D
var t := 0.0
var _i := 0
var _next := 1.5


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		room_id = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AppFlow.start_room = room_id
	change_scene_to_file(AppFlow.TEST_SCENE)


func _process(delta: float) -> bool:
	if main == null:
		main = current_scene as Node2D
		if main == null or main.get("player") == null or main.get("current_room") == null:
			return false
		main.current_room.disable_monsters()
		main.set_fog_preset(0)
	t += delta
	if t < _next:
		return false
	var p: Dictionary = GroundFog.PRESETS[_i]
	var img := root.get_texture().get_image()
	img.save_png(OUT + "fog_%d_%s.png" % [_i, p["id"]])
	# 바닥 띠 확대 크롭 (화면 높이 35~65%)
	var sz := img.get_size()
	var crop := img.get_region(Rect2i(int(sz.x * 0.08), int(sz.y * 0.36), int(sz.x * 0.45), int(sz.y * 0.28)))
	crop.save_png(OUT + "fog_crop_%d_%s.png" % [_i, p["id"]])
	print("FOG SHOT ", _i, " ", p["id"])
	_i += 1
	if _i >= GroundFog.PRESETS.size():
		print("FOG DONE")
		return true
	main.set_fog_preset(_i)
	_next = t + 0.8
	return false
