extends SceneTree
## 공간감 테스트 씬 스모크: 카메라 워킹 7종 · 속도 3종 · 레이어 구성 3종 · 명도만 · 색온도 · 구역 5곳을 전부 돌리며
## 쏘고 오류가 없는지, 센트리건·버그봇·몬스터가 있는지 본다.  실행: godot --path . --script res://tools/depth_lab_smoke.gd

var lab
var _f := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/DepthLab.tscn")


func _key(k: Key, shift := false) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	e.shift_pressed = shift
	lab._unhandled_key_input(e)


func _process(_d: float) -> bool:
	_f += 1
	if lab == null:
		lab = current_scene
		if lab == null or lab.get("motion") == null or lab.motion == null:
			lab = null
		return false
	match _f:
		30:
			print("센트리건 %d · 버그봇 %d · 몬스터 %d" % [lab.current_room.sentries.size(), lab.current_room.walkers.size(), lab.current_room.alive_monsters()])
			Input.action_press("shoot")
		200:
			Input.action_release("shoot")
	if _f > 30 and _f < 200 and _f % 20 == 0:
		_key(KEY_C)
	if _f == 210:
		for k in [KEY_1, KEY_3, KEY_2]:
			_key(k)
		for i in range(3):
			_key(KEY_L)
		_key(KEY_V)
		_key(KEY_V)
		_key(KEY_T)
		_key(KEY_T)
	if _f > 220 and _f < 330 and _f % 20 == 0:
		_key(KEY_BRACKETRIGHT)
		print("구역 → %s · 줌 단계 %d" % [lab.DD.ZONES[lab.DD.zone_index(lab.player.position.x)]["name"], lab.zoom_index])
	if _f == 340:
		print("탄 %d · 카메라 프리셋 %s · 완료" % [lab.bullets.get_child_count(), lab.DD.CAMERA_PRESETS[lab.cam_i]["name"]])
		quit(0)
		return true
	return false
