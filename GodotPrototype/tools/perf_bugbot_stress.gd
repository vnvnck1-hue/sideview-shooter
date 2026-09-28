extends SceneTree
## 버그봇 전투 부하 측정: 격납고에서 F10 전투를 켜고 플레이어도 계속 쏘면서 일정 간격으로 프레임 비용을 찍는다.
## "몬스터·버그봇·액션이 많아지면 점점 렉" 을 재현해 최적화 전후를 같은 시뮬레이션(고정 시드·고정 델타)으로 비교한다.
##
## 실행 (렌더 포함 — 창을 띄운다):
##   godot --path . --fixed-fps 60 --script res://tools/perf_bugbot_stress.gd -- [총 초=90] [찍는 간격 초=10]
## --fixed-fps 는 실시간 동기화를 끄므로 벽시계 프레임 시간 = 실제 CPU+GPU 비용이다.
## 헤드리스(--headless)로 돌리면 스크립트 비용만 본다.

var main: Node
var _t := 0.0
var _next := 0.0
var _total := 90.0
var _step := 10.0
var _started := false
var _shot_t := 0.0
var _frame_us: PackedInt64Array = PackedInt64Array()
var _proc_ms: PackedFloat64Array = PackedFloat64Array()
var _last_us := 0
var _all_us: PackedInt64Array = PackedInt64Array()
var _warm := 0
var _ablate := false
var _ab_keys: Array = []
var _ab_i := -1
var _ab_frames := 0
var _ab_sum := 0
var _ab_base := 0.0
var _ab_off: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_total = maxf(5.0, float(args[0]))
	if args.size() > 1:
		_step = maxf(1.0, float(args[1]))
	if args.size() > 2 and args[2] == "ablate":
		_ablate = true
	seed(4812)
	# 수직 동기화를 끄지 않으면 창 모드 프레임 시간이 60Hz(16.7ms)에 붙어 실제 비용이 안 보인다
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	AppFlow.start_test(self, "hangar", 2000.0, 1)
	print("t\tavg_ms\tp95_ms\tmax_ms\tscript_ms\tnodes\torphans\tobjects\tres\tmem_mb\tdraws\tmonsters\tlights_on\tdyn_reg\tbullets\troom_nodes")


func _process(delta: float) -> bool:
	if main == null:
		main = current_scene
		if main == null or main.get("player") == null or main.get("current_room") == null:
			main = null
			return false
	var now := Time.get_ticks_usec()
	if _last_us > 0 and _started:
		_frame_us.append(now - _last_us)
		_all_us.append(now - _last_us)
		_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_last_us = now
	if ResourceLoader.exists("res://scripts/perf_probe.gd"):
		load("res://scripts/perf_probe.gd").end_frame()
	var room = main.get("current_room")
	if not _started:
		_warm += 1
		if _warm == 20:
			_key(true)
		if _warm == 23:
			_key(false)
		if _warm >= 30:
			_started = true
			var battle = room.get("bugbot_battle")
			if battle == null:
				print("PERF FAIL: battle did not start")
				return true
		return false
	_t += delta
	# 전투를 최대 압박으로: 목표 개체 수를 상한으로 고정한다
	var battle = room.get("bugbot_battle")
	if battle != null:
		battle.desired_count = room.MONSTER_HARD_CAP
		battle.spawn_interval = 0.35
		battle._balance_timer = 99.0
	# 플레이어도 초당 10발 사격 (탄착·탄피·파편·동적 광원)
	_shot_t -= delta
	if _shot_t <= 0.0:
		_shot_t = 0.1
		var p: Node2D = main.get("player")
		var target := Vector2(p.position.x + randf_range(-900.0, 900.0), randf_range(200.0, float(room.floor_y) - 10.0))
		main.call("_spawn_shot", p.position + Vector2(0, -40), target, 1.0, 1.0)
		main.call("_on_shell_ejected", p.position + Vector2(0, -40), 1)
	if _ablate and _t > 15.0:
		return _ablate_step(room, now)
	if _t >= _next:
		_next += _step
		_row(room)
	if _t >= _total:
		_all_us.sort()
		var n := _all_us.size()
		var sum := 0
		for v in _all_us:
			sum += v
		print("PERF TOTAL frames=%d avg_ms=%.2f p50=%.2f p95=%.2f p99=%.2f" % [n, sum / 1000.0 / n,
			_all_us[n / 2] / 1000.0, _all_us[int(n * 0.95)] / 1000.0, _all_us[int(n * 0.99)] / 1000.0])
		return true
	return false


func _key(pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F10
	key.pressed = pressed
	Input.parse_input_event(key)


func _row(room) -> void:
	var avg := 0.0
	var mx := 0
	var sorted := _frame_us.duplicate()
	sorted.sort()
	for v in _frame_us:
		avg += v
		mx = maxi(mx, v)
	var n := maxi(1, _frame_us.size())
	avg /= n
	var p95: int = sorted[int(sorted.size() * 0.95)] if sorted.size() > 0 else 0
	var sp := 0.0
	for v in _proc_ms:
		sp += v
	sp /= maxf(1.0, _proc_ms.size())
	_print_probe(n)
	_frame_us.clear()
	_proc_ms.clear()
	var lights := [0]
	var nodes := [0]
	_walk(room, lights, nodes)
	var bullets = main.get("bullets")
	print("%.0f\t%.2f\t%.2f\t%.2f\t%.2f\t%d\t%d\t%d\t%d\t%.1f\t%d\t%d\t%d\t%d\t%d\t%d" % [
		_t, avg / 1000.0, p95 / 1000.0, mx / 1000.0, sp,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		room.alive_monsters(), lights[0], load("res://scripts/lighting.gd")._dyn_lights.size(),
		bullets.get_child_count() if bullets != null else -1, nodes[0],
	])


func _walk(n: Node, lights: Array, nodes: Array) -> void:
	nodes[0] += 1
	if n is PointLight2D and (n as PointLight2D).enabled and (n as PointLight2D).visible:
		lights[0] += 1
	for c in n.get_children():
		_walk(c, lights, nodes)


## 스크립트 종류별로 _process/_physics_process 를 잠깐 꺼서 프레임 시간이 얼마나 줄어드는지 본다 (비용 귀속).
func _ablate_step(room, now: int) -> bool:
	if _ab_keys.is_empty():
		var seen := {}
		_collect(root, seen)
		_ab_keys = seen.keys()
		_ab_keys.push_front("<none>")
		_ab_i = 0
		_ab_frames = -10
		_ab_sum = 0
	var dt: int = _frame_us[_frame_us.size() - 1] if _frame_us.size() > 0 else 0
	_ab_frames += 1
	if _ab_frames > 0:
		_ab_sum += dt
	if _ab_frames >= 180:
		var avg := _ab_sum / 1000.0 / _ab_frames
		if _ab_i == 0:
			_ab_base = avg
		print("ABLATE %-45s avg=%.2f  saved=%.2f  (n=%d)" % [_ab_keys[_ab_i], avg, _ab_base - avg, _ab_off.size()])
		for n in _ab_off:
			if is_instance_valid(n):
				n.set_process(true)
				n.set_physics_process(true)
		_ab_off.clear()
		_ab_i += 1
		# 비교 기준을 다시 잡는다 (전투 상태가 바뀌므로 매 3개마다)
		if _ab_i >= _ab_keys.size():
			return true
		_ab_frames = -10
		_ab_sum = 0
	if _ab_frames == -9 and _ab_i > 0:
		_disable(root, str(_ab_keys[_ab_i]))
	elif _ab_i > 0 and _ab_frames > 0 and _ab_frames % 30 == 0:
		_disable(root, str(_ab_keys[_ab_i]))
	return false


func _script_key(n: Node) -> String:
	var s: Script = n.get_script()
	if s == null:
		return ""
	return s.resource_path.get_file()


func _collect(n: Node, seen: Dictionary) -> void:
	var k := _script_key(n)
	if k != "" and n != current_scene and k != "perf_bugbot_stress.gd":
		seen[k] = true
	for c in n.get_children():
		_collect(c, seen)


func _disable(n: Node, key: String) -> void:
	if _script_key(n) == key and n.is_processing() or (_script_key(n) == key and n.is_physics_processing()):
		n.set_process(false)
		n.set_physics_process(false)
		_ab_off.append(n)
	for c in n.get_children():
		_disable(c, key)


## scripts/perf_probe.gd 가 있으면(임시 계측) 스크립트별 프레임당 비용 상위 목록을 찍는다.
func _print_probe(frames: int) -> void:
	if not ResourceLoader.exists("res://scripts/perf_probe.gd"):
		return
	var pp = load("res://scripts/perf_probe.gd")
	var keys: Array = pp.acc.keys()
	keys.sort_custom(func(a, b): return pp.acc[a] > pp.acc[b])
	var line := "  PROBE"
	var total := 0
	for k in keys:
		total += pp.acc[k]
	line += " sum=%.2fms |" % (total / 1000.0 / frames)
	for i in range(mini(22, keys.size())):
		var k = keys[i]
		line += " %s=%.2f(%d)" % [k, pp.acc[k] / 1000.0 / frames, pp.cnt[k] / frames]
	var mkeys: Array = pp.mx.keys()
	mkeys.sort_custom(func(a, b): return pp.mx[a] > pp.mx[b])
	line += "
  MAX |"
	for i in range(mini(10, mkeys.size())):
		line += " %s=%.1fms" % [mkeys[i], pp.mx[mkeys[i]] / 1000.0]
	for k in keys:
		if str(k).ends_with("#"):
			line += " [%s %.1f/frame]" % [k, float(pp.cnt[k]) / frames]
	print(line)
	pp.reset()
