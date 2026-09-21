extends SceneTree
## 절차적 사족보행(ProcWalker) 검증 (헤드리스).
##   godot --headless --path . --script res://tools/validate_walker.gd
##
## 두 단계로 나눠 본다. 섞어 재면 "걸음이 이상한 것" 과 "험지가 어려운 것" 이 구분되지 않는다.
##
## 1단계 — 평지 걷기. 걸음이 제대로 나는가를 본다.
##   · 걸음은 **보폭 초과(정상)** 로 나야 한다. 대부분이 도달 한계(긴급)로 나면 다리 길이 대비
##     보폭·속도가 과한 것이고, 그때는 접지 유지·대각 규칙 같은 제동이 전부 무시된다.
##   · 네 발이 모두 붙는 구간이 충분히 있어야 한다. 없으면 늘 허둥대는 걸음으로 보인다.
##
## 2단계 — 지형 주파 (경사·턱·울퉁불퉁·급경사·낭떠러지). 규칙이 깨지지 않는가만 본다.
##   **속도에 무관하게** 같은 프레임 수를 돌린다 — 느린 걸음새(속도 70)도 같은 시간 안에 끝나야
##   프리셋을 하나씩 검증할 수 있다. 얼마나 멀리 갔는지는 실패가 아니라 기록으로만 남긴다.
##   · 동시에 뜬 발 2개 이하 · 뜬 발은 같은 대각 조 · 딛은 발은 지면 위 · 다리는 도달 거리 안
##   험지에서는 긴급 스텝이 나도 된다 — 그러라고 있는 장치다.

const STEP := 1.0 / 60.0
const Lab := preload("res://scripts/walker_lab.gd")

const FLAT_START := -2600.0        # 평지 구간 (TERRAIN 이 -4000~200 까지 평평하다)
const FLAT_FRAMES := 720           # 12초
const WARMUP := 90                 # 가속 구간은 통계에서 뺀다

var _lab: Node2D
var _walker: ProcWalker
var _fails: Array[String] = []
var _frame := 0
var _phase := 0
var _phase_frame := 0
var _turned := false
var _was_air := false
var _air_gap := 0.0            # 착지 직전 프레임에 가장 낮은 발이 지면에서 얼마나 떠 있었나
var _land_gap := -1.0
var _far := 0.0                # 2단계에서 가장 멀리 간 x (기록용)
var _shin_tilt := 0.0          # 정강이가 **기준 각**에서 벗어난 최대 각
var _shin_abs := 0.0           # 정강이가 수직에서 벗어난 최대 각 (절대)
var _air_hist := [0, 0, 0]     # 뜬 발이 0개 / 1개 / 2개인 프레임 수 — 걸음새의 성격을 가른다

var _max_air := 0
var _steps := 0
var _was_stepping := {}
var _grounded_frames := 0
var _walk_frames := 0
var _flat_normal := 0
var _flat_urgent := 0


## `-- preset=3` 을 주면 그 걸음새 프리셋을 적용하고 검증한다 (프리셋도 예산을 지켜야 한다)
var _preset := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("preset="):
			_preset = int(a.split("=")[1])
	_lab = Lab.new()
	root.add_child(_lab)


## WalkerLab._ready 는 노드가 트리에 들어간 **다음** 프레임에 돈다 (validate_locomotion.gd 와 같은 자리).
func _process(_delta: float) -> bool:
	_frame += 1
	if _lab == null:
		# 스크립트가 컴파일에 실패하면 Lab.new() 가 null 을 준다. 그대로 두면 매 프레임 에러만
		# 뱉으며 타임아웃까지 매달린다 — 바로 실패로 끝낸다.
		_fails.append("WalkerLab 을 만들지 못했다 (스크립트 컴파일 실패)")
		return _finish()
	if _walker == null:
		for c in _lab.get_children():
			if c is ProcWalker:
				_walker = c
		if _walker == null:
			if _frame < 10:
				return false
			_fails.append("ProcWalker 를 찾지 못했다")
			return _finish()
		_lab.set_physics_process(false)     # 틱은 이 스크립트가 돌린다 (이중 틱 방지)
		if _preset > 0:
			var key := KEY_0 + _preset
			var pset: Dictionary = Lab.PRESETS[key]
			for k in pset.keys():
				if k != "name":
					_walker.tune[k] = pset[k]
			print("[프리셋 %d] %s" % [_preset, pset["name"]])
		_walker.body_pos.x = FLAT_START
		_walker.reset_stance()
		return false

	if _phase == 0:
		return _tick_flat()
	return _tick_course()


# ── 1단계: 평지 걷기 ─────────────────────────────────────────────────────────

func _tick_flat() -> bool:
	_walker.input_dir = 1.0
	_walker.running = false
	_walker.tick(STEP)
	_check()
	_phase_frame += 1
	if _phase_frame == WARMUP:
		_grounded_frames = 0            # 가속이 끝난 뒤부터 센다
		_walk_frames = 0
		_flat_normal = _walker.steps_normal
		_flat_urgent = _walker.steps_urgent
	if _phase_frame < FLAT_FRAMES:
		return false

	var normal := _walker.steps_normal - _flat_normal
	var urgent := _walker.steps_urgent - _flat_urgent
	var settle := 100.0 * float(_grounded_frames) / maxf(float(_walk_frames), 1.0)
	print("--- 1단계: 평지 걷기 (%.1f초) ---" % (float(FLAT_FRAMES - WARMUP) * STEP))
	print("  걸음 계기: 정상(보폭 초과) %d · 긴급(도달 한계) %d" % [normal, urgent])
	var tot := maxf(float(_air_hist[0] + _air_hist[1] + _air_hist[2]), 1.0)
	print("  뜬 발 분포: 0개 %.0f%% · 1개 %.0f%% · 2개 %.0f%%   (1개가 많으면 한 발씩, 2개가 많으면 대각 트롯)" % [
		100.0 * _air_hist[0] / tot, 100.0 * _air_hist[1] / tot, 100.0 * _air_hist[2] / tot])
	print("  네 발이 모두 붙어 있던 시간: %.0f%%  (접지 유지 %.2f초 → 기준 %.0f%%)" % [
		settle, _walker.tune["hold"], 15.0 if (_walker.tune["hold"] as float) >= 0.10 else 5.0])
	if urgent > int(float(normal) * 0.25):
		_fails.append("평지인데 긴급 스텝이 잦다 (정상 %d · 긴급 %d) — 다리 길이 대비 보폭·속도가 과하다" % [normal, urgent])
	# 네 발이 붙어 있기를 **요구한 걸음새인지**부터 본다. hold(접지 유지)가 곧 그 요구다 —
	# 거의 0 으로 둔 걸음새(거미처럼 한 발씩 계속 움직이는 것)는 낮은 접지율이 의도이지 결함이 아니다.
	var floor_pct: float = 15.0 if (_walker.tune["hold"] as float) >= 0.10 else 5.0
	if settle < floor_pct:
		_fails.append("평지에서 네 발이 모두 붙는 시간이 %.0f%% 뿐이다 (기준 %.0f%%) — 걸음이 가라앉지 않는다" % [
			settle, floor_pct])

	_phase = 1
	_phase_frame = 0
	_grounded_frames = 0
	_walk_frames = 0
	_walker.body_pos.x = 0.0
	_walker.reset_stance()
	return false


# ── 2단계: 전체 지형 왕복 ────────────────────────────────────────────────────

const COURSE_FRAMES := 2600        # 2단계 길이 (약 43초). 속도와 무관하게 고정한다
const COURSE_TURN := 1500          # 이 프레임에 방향을 돌린다 (앞뒤 다리가 뒤바뀌는 순간을 본다)


func _tick_course() -> bool:
	if not _turned and (_phase_frame >= COURSE_TURN or _walker.body_pos.x > 5200.0):
		_turned = true
	_walker.input_dir = -1.0 if _turned else 1.0
	_walker.running = _phase_frame > 900 and _phase_frame < COURSE_TURN
	_walker.tick(STEP)
	_check()
	_phase_frame += 1
	if _phase_frame == 400 or _phase_frame == 1100:
		_walker.jump()
	_far = maxf(_far, _walker.body_pos.x)
	if _phase_frame < COURSE_FRAMES:
		return false
	return _finish()


func _check() -> void:
	var air: Array = []
	var groups := {}
	for i in range(4):
		var leg: Dictionary = _walker._legs[i]
		var hip: Vector2 = _walker._hip_world(leg)
		var foot: Vector2 = leg["foot"]
		if leg["stepping"]:
			air.append(i)
			groups[leg["group"]] = true
		elif not _walker.airborne:
			# 몸이 떠 있는 동안의 발은 "딛은 발" 이 아니다 — 낙하 중 한두 프레임 지형에 스치는 것은
			# 어쩔 수 없다(스트럿 한계와 동시에 만족할 수 없는 자리가 있다). 접지 상태만 엄격히 본다.
			var g: float = _walker.ground_at.call(foot.x)
			if foot.y > g + 2.0:
				_fail("딛은 발이 지면 아래 (%s, %.1f > %.1f)" % [leg["name"], foot.y, g])
		if not _was_stepping.get(i, false) and leg["stepping"]:
			_steps += 1
		_was_stepping[i] = leg["stepping"]
		var p0 := _walker._phi0(leg)
		var strut := _walker.strut_for(hip, foot, p0)
		if strut > ProcWalker.THIGH_MAX + 1.0:
			_fail("허벅지 스트럿이 한계를 넘었다 (%s, %.1f > %.1f)" % [leg["name"], strut, ProcWalker.THIGH_MAX])
		# 정강이가 수직에서 얼마나 벗어나는가 — "자이로 달린 것처럼" 이 지켜지는지 감시한다
		var knee := ProcWalker.solve_knee_v(hip, foot, p0)
		# 기준 각(바깥으로 벌린 각)에서 얼마나 더 벗어나는지를 본다. 절대 각도 따로 기록한다.
		var shin := wrapf((foot - knee).angle() - PI * 0.5, -PI, PI)
		_shin_tilt = maxf(_shin_tilt, absf(shin - p0))
		_shin_abs = maxf(_shin_abs, absf(shin))

	_max_air = maxi(_max_air, air.size())
	if air.size() > 2:
		_fail("동시에 %d 발이 떴다" % air.size())
	if groups.size() > 1:
		_fail("서로 다른 대각 조가 같이 떴다 (%s)" % str(groups.keys()))
	# 착지 순간: 바로 앞 프레임의 발-지면 간격을 남긴다. 접은 다리로 내려오면 여기가 크게 벌어지고,
	# 화면에서는 "허공에 착지" 로 보인다.
	if _was_air and not _walker.airborne:
		_land_gap = maxf(_land_gap, _air_gap)
	if _walker.airborne:
		var lowest := -1e9
		for leg in _walker._legs:
			var f: Vector2 = leg["foot"]
			lowest = maxf(lowest, f.y - _walker.ground_at.call(f.x))
		_air_gap = -lowest
	_was_air = _walker.airborne

	if not _walker.airborne:
		_walk_frames += 1
		if air.size() <= 2:
			_air_hist[air.size()] += 1
		if air.is_empty():
			_grounded_frames += 1
		if _walker.body_pos.y > _walker.ground_at.call(_walker.body_pos.x):
			_fail("몸체가 지면 아래로 내려갔다 (%.1f)" % _walker.body_pos.y)


func _fail(msg: String) -> void:
	var line := "[%d단계 %d] %s" % [_phase + 1, _phase_frame, msg]
	if _fails.size() < 12 and not _fails.has(line):
		_fails.append(line)


func _finish() -> bool:
	if _phase == 1:
		if _far < 300.0:
			_fails.append("2단계에서 전진하지 못했다 (가장 멀리 x=%.0f)" % _far)
		print("--- 2단계: 지형 주파 (%d프레임) ---" % COURSE_FRAMES)
		print("  가장 멀리 x %.0f · 돌아온 뒤 x %.0f · 걸음 %d · 동시에 뜬 발 최대 %d · 네 발 접지 %.0f%%" % [
			_far, _walker.body_pos.x, _steps, _max_air,
			100.0 * float(_grounded_frames) / maxf(float(_walk_frames), 1.0),
		])
	if _walker == null:
		print("--- 결과 ---")
		for f in _fails:
			print("    " + f)
		quit(1)
		return true
	print("  정강이 — 기준 각에서 벗어난 최대 %.1f° (한계 %.1f°) · 수직 기준 최대 %.1f° (기준 각 %.1f°)" % [
		rad_to_deg(_shin_tilt), rad_to_deg(ProcWalker.SHIN_TILT_MAX),
		rad_to_deg(_shin_abs), rad_to_deg(ProcWalker.SHIN_SPLAY),
	])
	if _shin_tilt > ProcWalker.SHIN_TILT_MAX + 0.02:
		_fails.append("정강이가 기준 각에서 %.1f° 까지 벗어났다 — 한계는 %.1f° 다" % [
			rad_to_deg(_shin_tilt), rad_to_deg(ProcWalker.SHIN_TILT_MAX)])
	if _land_gap >= 0.0:
		print("  착지 직전 발-지면 간격: %.0f px" % _land_gap)
		if _land_gap > 40.0:
			_fails.append("착지 직전에 발이 지면에서 %.0fpx 떠 있다 — 허공에 착지한 것처럼 보인다" % _land_gap)
	print("--- 결과 ---")
	if _fails.is_empty():
		print("  통과")
	else:
		print("  실패 %d 건:" % _fails.size())
		for f in _fails:
			print("    " + f)
	quit(0 if _fails.is_empty() else 1)
	return true
