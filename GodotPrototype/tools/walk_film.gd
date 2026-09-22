extends SceneTree
## 본편에서 기체가 **걷는** 연속 프레임. 발이 지면에서 제대로 갈아 딛는지 눈으로 본다.
##   godot --path . --script res://tools/walk_film.gd
const OUT := "user://shots/walk_film/"
const COUNT := 10
const EVERY := 6            # 프레임 간격
var _main: Node
var _f := 0
var _n := 0
var _armed := false
var _unit
func _initialize() -> void:
	AppFlow.start_test(self, "hangar", 900.0, -1)
func _process(_d: float) -> bool:
	_f += 1
	if _main == null:
		_main = root.get_child(root.get_child_count() - 1)
		if _main == null or not _main.has_method("_load_room"):
			_main = null
			return _f > 300
		DirAccess.make_dir_recursive_absolute(OUT)
		return false
	if _f == 20:
		var room = _main.get("current_room")
		_unit = room.walkers[0]
		_unit.activate()
	if _unit == null:
		return false
	# 다 서면 오른쪽으로 계속 걷게 한다 (조종 입력 자리에 직접 넣는다)
	# **진짜 입력으로 몬다.** WalkerUnit._tick_input 이 매 프레임 Input 을 읽어 덮어쓰므로
	# _walker.input_dir 에 직접 넣으면 소용이 없다 (그렇게 찍었다가 기체가 제자리에 있었다).
	if _unit.state == 2 and not Input.is_action_pressed("move_right"):
		Input.action_press("move_right")
	if _armed:
		var img := root.get_texture().get_image()
		if img == null or img.get_width() == 0:
			return false
		img.save_png(OUT + "w%02d.png" % _n)
		# 카메라는 플레이어를 따라가므로 기체가 화면 밖으로 나간다 — 잘라 볼 자리를 같이 남긴다
		var cam := _main.get("camera") as Camera2D
		var sx: float = (_unit.position.x - cam.get_screen_center_position().x) * cam.zoom.x + AppFlow.VIEW_SIZE.x * 0.5
		print("w%02d screen_x=%d" % [_n, int(sx)])
		_n += 1
		_armed = false
		if _n >= COUNT:
			print("--- ", ProjectSettings.globalize_path(OUT), " ---")
			quit()
			return true
	elif _f > 140 and _f % EVERY == 0:
		_armed = true
	return false
