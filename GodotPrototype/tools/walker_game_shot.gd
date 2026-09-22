extends SceneTree
## 본편에 들어간 사족보행 기체 확인용. 격납고에서 기체 옆에 서서 몇 장 찍는다.
##   godot --path . --script res://tools/walker_game_shot.gd   (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/walker_game/
##
## 본편은 월드를 SubViewport 에 그리므로 루트 텍스처가 한 프레임 비어 있을 수 있다 —
## 비면 그 프레임은 건너뛰고 다음 프레임에 다시 찍는다 (그냥 저장하면 빈 PNG 로 터진다).
const OUT := "user://shots/walker_game/"
## 사격 장면은 총구 화염이 0.075초만 살아 있어 한 장으로는 잘 안 걸린다 — 몇 프레임 연속으로 찍는다
const PLAN := [[30, "a_dormant"], [110, "b_waking"], [240, "c_ready"],
	[300, "d_fire1"], [303, "d_fire2"], [306, "d_fire3"], [309, "d_fire4"]]

var _main: Node
var _f := 0
var _i := 0
var _armed := false


func _initialize() -> void:
	AppFlow.start_test(self, "hangar", 880.0, -1)


func _process(_d: float) -> bool:
	_f += 1
	if _main == null:
		_main = root.get_child(root.get_child_count() - 1)
		if not _main.has_method("_load_room"):
			_main = null
			return _f > 300
		DirAccess.make_dir_recursive_absolute(OUT)
		return false

	if _armed:
		var img := root.get_texture().get_image()
		if img == null or img.get_width() == 0:
			return false                       # 아직 안 그려졌다 — 다음 프레임에 다시
		img.save_png(OUT + str(PLAN[_i][1]) + ".png")
		print("saved ", PLAN[_i][1])
		_armed = false
		_i += 1
		if _i >= PLAN.size():
			print("--- ", ProjectSettings.globalize_path(OUT), " ---")
			quit()
			return true
		return false

	var room = _main.get("current_room")
	var unit = room.walkers[0] if room != null and room.walkers.size() > 0 else null
	if unit != null and _i >= 2:               # 마지막 장은 쏘는 순간을 찍는다
		# 조준은 **마우스**로 준다. 기체를 조종 중이면 Main 이 매 프레임 unit.aim_target 에
		# 마우스 좌표를 다시 써 넣으므로, 여기서 aim_target 을 직접 정해도 곧바로 덮인다.
		# 왼쪽을 겨누게 둔다 — 화염이 포신 방향으로 나가는지는 왼쪽에서 가장 잘 보인다.
		Input.warp_mouse(Vector2(140.0, root.get_visible_rect().size.y * 0.62))
		# 사격은 **입력으로** 넣는다. 기체를 조종 중이면 WalkerUnit._tick_input() 이 매 프레임
		# Input 을 다시 읽어 firing 을 덮으므로, _walker.firing 에 직접 써 넣으면 한 발도 안 나간다.
		if _i >= 3:
			Input.action_press("shoot")
		else:
			Input.action_release("shoot")
	# 사격 장면은 **화염이 막 터진 프레임**에서만 찍는다. 고정 프레임으로 찍으면 연사 간격
	# (0.08초)과 어긋나 화염이 없는 틈만 계속 잡힌다 — 실제로 세 장 다 빈 총구가 나왔다.
	var fresh := true
	if _i >= 3 and unit != null:
		fresh = unit._blast._t < 0.02
	if _i < PLAN.size() and _f >= int(PLAN[_i][0]) and fresh:
		if _i == 1 and unit != null:           # 두 번째 장 직전에 기동시킨다
			unit.activate()
		_armed = true
	return false
