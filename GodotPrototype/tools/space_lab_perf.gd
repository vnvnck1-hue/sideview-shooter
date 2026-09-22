extends SceneTree
## 공간 테스트 씬 성능 추적: SpaceLab 을 띄우고 **전투를 흉내 내면서** 일정 간격으로 수치를 찍는다.
## "오래 있으면 점점 느려진다" 가 무엇 때문인지 — 프레임 시간이 올라가는지, 노드가 쌓이는지,
## 드로우콜이 느는지, 어떤 노드가 늘어나는지를 한 표에서 본다.
##
## 실행:  godot --path . --script res://tools/space_lab_perf.gd -- [총 초=90] [찍는 간격 초=10] [초당 사격=8]
##        초당 사격 0 = 전투 없이 **방 자체의 기본 비용**만 본다 (넓이·조명·그림자·근경).
## 헤드리스로는 렌더가 없어 창을 띄운 채로 돈다.

var _t := 0.0
var _next := 0.0
var _total := 90.0
var _step := 10.0
var _shot_t := 0.0
var _main: Node = null
var _rows: Array = []
var _rate := 8.0                 # 초당 사격 수 (0 이면 쏘지 않고 걷지도 않는다)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_total = maxf(5.0, float(args[0]))
	if args.size() > 1:
		_step = maxf(1.0, float(args[1]))
	if args.size() > 2:
		_rate = maxf(0.0, float(args[2]))
	change_scene_to_file(AppFlow.SPACE_LAB_SCENE)


func _process(delta: float) -> bool:
	if _main == null:
		_main = root.get_child(root.get_child_count() - 1)
		if _main == null or not _main.has_method("world_to_screen"):
			_main = null
			return false
		print("초\tFPS\t프레임ms\t노드\t고아\t드로우콜\t메모리MB\t몬스터\t자국\t탄\t월드노드")
	_t += delta

	# 전투 흉내: 0.12초마다 한 발씩 벽·프랍·몬스터 쪽으로 쏜다 (탄착 자국·탄피·파편·동적 광원을 만든다)
	if _rate > 0.0:
		_shot_t -= delta
		if _shot_t <= 0.0:
			_shot_t = 1.0 / _rate
			_fake_shot()

	if _t >= _next:
		_next += _step
		_sample()
	if _t >= _total:
		_report()
		return true
	return false


func _fake_shot() -> void:
	var player = _main.get("player")
	var room = _main.get("current_room")
	if player == null or room == null:
		return
	# 플레이어를 천천히 오른쪽으로 걷게 해 방 전체를 훑는다 (스폰 밴드가 따라온다)
	player.position.x = clampf(player.position.x + 6.0, 200.0, float(room.width) - 200.0)
	var muzzle: Vector2 = player.position + Vector2(60.0, -120.0)
	var target := muzzle + Vector2(randf_range(300.0, 900.0), randf_range(-260.0, 40.0))
	_main.call("_spawn_shot", muzzle, target)


func _sample() -> void:
	var room = _main.get("current_room")
	var world = _main.get("world")
	var row := {
		"t": int(_t),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"draw": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"mem": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"mon": int(room.alive_monsters()) if room else 0,
		"stain": _count(room, "stain_layer"),
		"bullet": _main.get("bullets").get_child_count() if _main.get("bullets") else 0,
		"world": world.get_child_count() if world else 0,
	}
	if _rows.is_empty() and room:
		print("방: 폭 %d · 붙박이 광원 %d · 그림자 캐스터 %d · 램프 %d · 피격 프랍 %d" % [
			room.width, _light_count(room), _caster_count(room), room.lamps.size(), room.props_hit.size()])
	_rows.append(row)
	print("%d\t%.0f\t%.2f\t%d\t%d\t%d\t%.1f\t%d\t%d\t%d\t%d" % [
		row["t"], row["fps"], row["ms"], row["nodes"], row["orphan"], row["draw"],
		row["mem"], row["mon"], row["stain"], row["bullet"], row["world"]])


## 방에 붙박인 PointLight2D 수 (동적 광원 제외)
func _light_count(room) -> int:
	var n := 0
	var stack: Array = [room]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for c in node.get_children():
			if c is PointLight2D:
				n += 1
			stack.append(c)
	return n


func _caster_count(room) -> int:
	var ps = room.get("prop_shadows")
	if ps == null:
		return 0
	var cs = ps.get("_casters")
	return cs.size() if cs != null else 0


func _count(room, method: String) -> int:
	if room == null or not room.has_method(method):
		return 0
	var layer = room.call(method)
	return layer.get_child_count() if layer else 0


func _report() -> void:
	if _rows.size() < 2:
		return
	var a: Dictionary = _rows[0]
	var b: Dictionary = _rows[_rows.size() - 1]
	print("\n=== %d초 → %d초 변화 ===" % [a["t"], b["t"]])
	for k in ["fps", "ms", "nodes", "orphan", "draw", "mem", "mon", "stain", "bullet", "world"]:
		print("  %-7s %10.1f → %10.1f   (%+.1f)" % [k, float(a[k]), float(b[k]), float(b[k]) - float(a[k])])
