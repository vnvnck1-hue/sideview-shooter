extends SceneTree
## 장시간 플레이 누수 진단(임시): 격납고에서 계속 쏘면서 주기적으로 객체/노드/메모리/프레임 시간을 찍는다.
## 실행: godot --path . --script res://tools/leak_probe.gd -- [초]

var main: Node2D
var t := 0.0
var _next := 0.0
var _dur := 180.0
var _aim := Vector2.ZERO
var _mode := "combat"
var _room_t := 0.0
var _ids: Array = []
var _ri := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_float():
			_dur = float(a)
		else:
			_mode = a
	_ids = RoomData.ROOMS.keys()
	AppFlow.start_room = RoomData.SENTRY_TEST_ROOM
	change_scene_to_file(AppFlow.TEST_SCENE)
	print("t,fps,process_ms,physics_ms,objects,nodes,orphans,resources,static_mem_mb,video_mem_mb,draw_calls,lit_mats,fg_mats,heat,monsters,room_children,bullet_children")


func _process(delta: float) -> bool:
	if main == null:
		main = current_scene as Node2D
		if main == null or main.get("player") == null:
			return false
	t += delta
	if _mode == "reload":
		_room_t += delta
		if _room_t >= 3.0:
			_room_t = 0.0
			if t >= _next:
				_next += 5.0
				_row(main.get("current_room"))
			main = null
			AppFlow.start_room = str(_ids[_ri % _ids.size()])
			_ri += 1
			change_scene_to_file(AppFlow.TEST_SCENE)
		return t >= _dur
	if _mode == "rooms":
		_room_t += delta
		if _room_t >= 2.0:
			_room_t = 0.0
			_ri = (_ri + 1) % _ids.size()
			main.call("_load_room", str(_ids[_ri]), 300.0, 1)
		if t >= _next:
			_next += 5.0
			_row(main.get("current_room"))
		return t >= _dur
	# 방 밖으로 나가지 않게 플레이어를 방 가운데에 묶어 둔다 (전투 방에 계속 머무르는 상황 재현)
	var _r = main.get("current_room")
	if _r != null:
		var _p: Node2D = main.get("player")
		_p.position.x = float(_r.width) * 0.5
	# 계속 사격: 방 안 임의 지점을 쏜다 (플레이어 재장전 사이클 포함)
	var room = main.get("current_room")
	if room != null and _mode != "idle" and fmod(t, 0.1) < delta:
		var p: Node2D = main.get("player")
		var target := Vector2(randf_range(60.0, float(room.width) - 60.0), randf_range(200.0, 470.0))
		main.call("_spawn_shot", p.position + Vector2(0, -40), target, 1.0, 1.0)
		main.call("_on_shell_ejected", p.position + Vector2(0, -40), 1)
	if t >= _next:
		_next += 5.0
		_row(room)
	return t >= _dur


func _row(room) -> void:
	var lit: int = Lighting._lit_materials.size()
	var fg: int = Lighting._fg_rim_materials.size()
	var heat: int = HeatSurface._active.size()
	var mon := 0
	var rc := 0
	if room != null:
		mon = room.monsters.size()
		rc = _count(room)
	var bc := 0
	var bullets = main.get("bullets")
	if bullets != null:
		bc = bullets.get_child_count()
	print("%.0f,%.1f,%.2f,%.2f,%d,%d,%d,%d,%.1f,%.1f,%d,%d,%d,%d,%d,%d,%d" % [
		t,
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		lit, fg, heat, mon, rc, bc,
	])


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c
