extends SceneTree
## 본편에 들어간 **사족보행 기체**가 센트리건과 같은 규칙으로 도는지 검사한다.
##   godot --path . --headless --script res://tools/validate_walker_unit.gd
##
## 눈으로 보는 스크린샷(tools/walker_game_shot.gd)과 달리 여기는 **배선**만 본다.
## 조종 상태는 Main 한 곳에서 갈리므로(controlled_turret), 한 군데라도 어긋나면
## "플레이어 입력이 영영 안 돌아온다" 같은 조용한 버그가 난다 — 그걸 잡는 그물이다.
##
## 검사 항목
##   1) 맵에 놓인 기체가 전부 유일한 id 를 갖고, 방을 조립하면 실제 노드로 선다
##   2) 보안 단말기의 방어 그리드에 **포탑과 함께** 올라온다 (원격 접속의 입구)
##   3) 꺼짐 → 기동 → 조종 → 내리기 가 돌고, 그동안 플레이어 입력이 정확히 꺼졌다 켜진다
##   4) 조종 중 사격이 Main 의 공용 사격 경로로 나간다
##   5) **걸으면 네 발이 따라 딛고, 그려진 다리가 그 발을 따라간다** (한 번 조용히 깨졌던 자리)
##   6) 방 좌우 끝을 넘어 걸어 나가지 않는다
##   7) 조종 중에는 **카메라가 기체를 따라가고**, 내리면 플레이어로 돌아온다
##   8) 접속·해제 연출(WalkerLink)이 조작을 가두지 않는다

const STEP := 1.0 / 60.0

var _fails: Array = []
var _notes: Array = []
var _main: Node
var _f := 0


func _initialize() -> void:
	AppFlow.start_test(self, "hangar", 900.0, -1)


func _process(_d: float) -> bool:
	_f += 1
	if _main == null:
		_main = root.get_child(root.get_child_count() - 1)
		if _main == null or not _main.has_method("_load_room"):
			_main = null
			return _f > 300
		return false
	if _f < 20:
		return false                       # 방이 다 서기를 기다린다
	_run()
	_report()
	quit(1 if _fails.size() > 0 else 0)
	return true


func _check(ok: bool, label: String) -> void:
	if ok:
		_notes.append("  OK   " + label)
	else:
		_fails.append("  실패 " + label)


func _run() -> void:
	# ── 1) 맵 배치 ────────────────────────────────────────────────────────────
	var listed: Array = TerminalData.machines().filter(func(m): return m["kind"] == "walker")
	var ids := {}
	for m in listed:
		ids[m["id"]] = true
	_check(listed.size() > 0, "맵에 보행 기체가 있다 (%d대)" % listed.size())
	_check(ids.size() == listed.size(), "기체 id 가 전부 유일하다")

	var room = _main.get("current_room")
	_check(room.walkers.size() > 0, "격납고를 조립하면 기체가 실제 노드로 선다 (%d대)" % room.walkers.size())
	if room.walkers.is_empty():
		return
	var unit: WalkerUnit = room.walkers[0]
	_check(room.walker_by_id(unit.walker_id) == unit, "id 로 기체를 찾을 수 있다 (원격 접속이 쓰는 길)")

	# ── 2) 방어 그리드 ────────────────────────────────────────────────────────
	# 격납고 보안 단말기(SEC-H3)는 정비 구역을 관할한다 — 그 구역의 기체가 올라와야 한다.
	var grid := TerminalData.grid_entries("sec_hangar", "hangar")
	var walkers_in_grid := grid.filter(func(e): return e.get("kind", "") == "walker" and e["authorized"])
	_check(walkers_in_grid.size() > 0, "보안 단말기 방어 그리드에 보행 기체가 올라온다 (%d대)" % walkers_in_grid.size())
	var sentries_in_grid := grid.filter(func(e): return e.get("kind", "") == "sentry" and e["authorized"])
	_check(sentries_in_grid.size() > 0, "같은 그리드에 포탑도 그대로 있다 (%d기)" % sentries_in_grid.size())

	# ── 3) 꺼짐 → 기동 → 조종 → 내리기 ────────────────────────────────────────
	var player = _main.get("player")
	_check(unit.state == WalkerUnit.State.DORMANT, "처음엔 꺼져 있다")
	_check(not unit.controlled, "처음엔 조종 중이 아니다")
	_check(unit.prompt_text().contains("기동"), "꺼져 있을 때 안내는 '기동'")

	# 접속음 — 표에 있고, 파일이 실제로 로드되고, UI 버스로 나가는가.
	# 파일이 빠지거나 경로가 어긋나도 게임은 조용히 잘 돌기 때문에(소리만 안 난다) 검사로 박아 둔다.
	var au := _main.get_tree().root.get_node_or_null("/root/Audio")
	if au != null:
		var cfg: Dictionary = au.SOUNDS.get("walker_link", {})
		_check(not cfg.is_empty(), "접속음이 Audio.SOUNDS 에 등록되어 있다")
		if not cfg.is_empty():
			_check(String(cfg["bus"]) == "UI",
				"접속음은 UI 버스로 나간다 (방 잔향·거리 감쇠를 타지 않게)")
			var st = load(String(au.DIR) + String((cfg["files"] as Array)[0]))
			_check(st != null, "접속음 파일이 실제로 있다")
			if st != null:
				_notes.append("  ---  접속음 길이 %.2f초 (연출 %.1f초)" % [st.get_length(), WalkerLink.SETTLE_SPAN])

	unit.activate()
	_check(unit.state == WalkerUnit.State.WAKING, "W/↑ 로 일어서기 시작한다")
	var stand_h := 0.0
	for i in range(int(WalkerUnit.WAKE_TIME / STEP) + 20):
		unit._process(STEP)
		stand_h = maxf(stand_h, unit.floor_y - unit._walker.body_pos.y * WalkerUnit.SCALE)
	_check(unit.state == WalkerUnit.State.READY, "다 서면 READY 로 넘어간다")
	_check(unit.controlled, "다 서면 스스로 조종으로 넘어온다 (센트리건과 같은 흐름)")
	_check(not player.input_enabled, "조종 중에는 플레이어 입력이 꺼진다")
	_check(_main.get("controlled_turret") == unit, "Main 의 조종 대상이 이 기체다")

	# 서 있는 키가 목표(플레이어의 약 2/3)에 맞는가 — 첨부 목업 비율
	var full := (float(ProcWalker.GAIT_SPIDER["ride"]) - ProcWalker.BODY_TOP) * WalkerUnit.SCALE
	_notes.append("  ---  선 자세 높이 %d 월드px (플레이어 267 의 %.2f 배)" % [int(full), full / 267.0])
	_check(full > 150.0 and full < 200.0, "선 자세 높이가 목표 범위(150~200)에 든다")

	# ── 4) 사격 — 센트리건과 같은 값·같은 탄착점 ──────────────────────────────
	_check(is_equal_approx(WalkerUnit.SHOT_POWER, SentryTurret.SHOT_POWER * 0.5), "탄착 위력이 센트리건의 절반이다")
	_check(WalkerUnit.TRACER_SCALE == SentryTurret.TRACER_SCALE, "궤적 두께가 센트리건과 같다")
	_check(WalkerUnit.SHELL_SCALE == SentryTurret.SHELL_SCALE, "탄피 크기가 센트리건과 같다")
	_check(WalkerUnit.SPREAD == SentryTurret.SPREAD, "산포가 센트리건과 같다")

	var hits: Array = []
	unit.shoot_fired.connect(func(m, t): hits.append([m, t]))
	# 포신이 조준점을 따라잡을 시간을 준다 (기계식 선회 — 센트리건과 같은 굼뜸)
	var aim := Vector2(unit.position.x + 600.0, unit.floor_y - 240.0)
	unit.aim_target = aim
	for i in range(int(1.2 / STEP)):
		unit._process(STEP)
	unit._walker.firing = true
	for i in range(int(0.6 / STEP)):
		unit._walker.tick(STEP)
	_check(hits.size() > 0, "조종 중 사격이 Main 의 공용 경로로 나간다 (%d발)" % hits.size())
	if hits.size() > 0:
		# 탄착점이 **마우스 자리**에 얹히는가. 포신 선회가 끝난 뒤이므로 산포(±0.016rad) 만큼만 벌어져야 한다.
		var last: Array = hits[-1]
		var err: float = (last[1] as Vector2).distance_to(aim)
		_notes.append("  ---  탄착점이 조준점에서 %d px 어긋남 (사거리 %d)" % [
			int(err), int((last[0] as Vector2).distance_to(aim))])
		_check(err < 40.0, "탄착점이 마우스 포인터에 얹힌다")
	_check(unit.heat > 0.0, "쏘면 열이 오른다 (%.2f)" % unit.heat)
	unit._walker.firing = false

	# ── 5) **걸으면 발이 따라 딛는가** ────────────────────────────────────────
	# 한 번 놓친 자리다. 리그가 ProcWalker 의 다리 딕셔너리를 **들고 있으면**, reset_stance() 가
	# 그걸 새 딕셔너리로 갈아 끼우는 순간 리그만 버려진 옛 다리를 계속 그린다 —
	# 몸통은 걸어가는데 발은 처음 자리에 얼어붙는다. 그림과 논리가 갈라져도 조용해서 검사로 못 박으면 또 놓친다.
	unit._rig._process(0.0)
	var foot0: Array = []
	var drawn0: Array = []
	for d2 in unit._rig._legs:
		foot0.append((unit._walker.legs()[int(d2["index"])]["foot"] as Vector2).x)
		drawn0.append((d2["shin"] as Sprite2D).global_position.x)
	var n0 := unit._walker.steps_normal
	for i in range(int(1.5 / STEP)):
		unit._walker.input_dir = 1.0     # _process 는 입력을 다시 읽어 덮어쓰므로 tick 을 직접 돈다
		unit._walker.tick(STEP)
	unit._walker.input_dir = 0.0
	unit._rig._process(0.0)              # 리그는 제 _process 에서 동기화한다 — 재기 전에 한 번 맞춘다
	_check(unit._walker.steps_normal > n0 + 4,
		"1.5초 걸으면 걸음이 난다 (%d걸음)" % (unit._walker.steps_normal - n0))

	# 논리적 발이 옮겨 갔는가, 그리고 **그려진 다리가 그만큼 같이 갔는가.**
	# 스프라이트의 원점은 무릎이라 절대 위치로는 비교할 수 없다 — **움직인 양**을 견준다.
	# (리그가 옛 다리 딕셔너리를 붙들고 있으면 논리 발만 가고 그림은 0 px 움직인다)
	var moved := 0
	var worst := 0.0
	for i in unit._rig._legs.size():
		var d2: Dictionary = unit._rig._legs[i]
		var df: float = (unit._walker.legs()[int(d2["index"])]["foot"] as Vector2).x - float(foot0[i])
		var dd: float = (d2["shin"] as Sprite2D).global_position.x - float(drawn0[i])
		if absf(df) > 50.0:
			moved += 1
		worst = maxf(worst, absf(dd - df * WalkerUnit.SCALE))
	_check(moved == 4, "네 발이 모두 새 자리로 옮겨 딛는다 (%d/4)" % moved)
	_notes.append("  ---  그려진 다리가 논리 발보다 덜 간 양: 최대 %d px" % int(worst))
	_check(worst < 30.0, "그려진 다리가 논리적 발을 따라간다 (얼어붙지 않는다)")

	# ── 6) 방 밖으로 나가지 않는다 ────────────────────────────────────────────
	unit._walker.body_pos.x = 99999.0
	unit._process(STEP)
	var w := float(room.width)
	_check(unit.position.x < w, "오른쪽 벽을 넘지 않는다 (x %d < 방 폭 %d)" % [int(unit.position.x), int(w)])
	unit._walker.body_pos.x = -99999.0
	unit._process(STEP)
	_check(unit.position.x > 0.0, "왼쪽 벽을 넘지 않는다 (x %d > 0)" % int(unit.position.x))

	# ── 7) 카메라 주체가 기체로 넘어왔는가 ────────────────────────────────────
	# 기체는 걸어다니므로 카메라가 플레이어에 붙어 있으면 기체만 화면 밖으로 나간다.
	var cam := _main.get("camera") as Camera2D
	_check(cam.target == unit, "조종 중에는 카메라가 **기체**를 따라간다")
	_check(not is_finite(cam.focus_x), "잡아 둔 초점은 풀려 있다 (고정점이면 걸어가는 기체를 못 따라간다)")
	# 바로 앞 검사가 기체를 벽까지 순간이동시켰다 — 카메라가 그 자리로 쓸려 가는 중이면
	# 걸어서 움직인 양과 섞인다. 한 번 붙여 놓고 잰다 (한 번 이걸로 -154px 가 나왔다).
	cam.snap()
	var cam0 := cam.position.x
	for i in range(int(0.8 / STEP)):
		unit._walker.input_dir = 1.0
		unit._walker.tick(STEP)
		unit._clamp_span()
		unit._sync_node()
		cam._process(STEP)
	unit._walker.input_dir = 0.0
	_check(cam.position.x > cam0 + 20.0, "기체가 걸어가면 카메라가 따라 움직인다 (%d px)" % int(cam.position.x - cam0))

	# ── 8) 접속 중 화면·플레이어 자세 ─────────────────────────────────────────
	# "기체의 눈으로 본다" 는 화면 세 가지로 말한다 — CRT 한 단 · 물러난 줌 · 가끔의 지지직.
	# 셋 다 _on_turret_control 한 곳에서만 갈리므로, 어떤 경로로 풀리든 원래대로 돌아와야 한다.
	_check(CrtPreset.get_preset(CrtPreset.DEFAULT)["id"] == "arcade", "기본 CRT 프리셋이 아케이드 모니터로 고정되어 있다")
	_check(CrtPreset.get_preset(CrtPreset.LINKED)["id"] == "tv", "접속 중 CRT 프리셋은 가정용 TV 다")
	_check(int(_main.ZOOM_PRESETS[_main.ZOOM_DEFAULT]["px"]) == 3, "기본 줌이 표준 ×3 으로 고정되어 있다")
	_check(player.standby, "접속 중에는 플레이어가 대기 모드다")
	# 자세를 **수치로** 본다. 방에 몬스터가 서 있으면 스크린샷으로는 몸이 가려 확인이 안 된다.
	var idle_before: float = player._idle_w
	for i in range(int(1.0 / STEP)):
		player._update_idle(STEP)
		player._update_head(STEP)
	_check(player._idle_w < 0.05,
		"아이들 모션이 멎는다 (가중치 %.2f → %.2f)" % [idle_before, player._idle_w])
	# 고개가 아래를 향하는가 — 바라보는 각의 sin 이 양수면 화면 아래쪽이다 (좌향·우향 모두 통한다)
	_notes.append("  ---  고개 각 sin = %.2f (양수 = 아래)" % sin(player._head_angle))
	_check(sin(player._head_angle) > 0.3, "고개를 아래로 떨군다")
	var base_z: float = float(_main.ZOOM_PRESETS[_main.zoom_index]["px"]) / _main.ART_CELL
	_main._apply_link_zoom(_main.LINK_ZOOM)
	_check(_main._base_zoom() < base_z - 0.01,
		"접속 중에는 화면이 물러나 있다 (%.3f → %.3f)" % [base_z, _main._base_zoom()])
	_main._apply_link_zoom(1.0)
	_check(is_equal_approx(_main._base_zoom(), base_z), "해제하면 줌이 원래대로 돌아온다")

	# ── 9) 내리기 ─────────────────────────────────────────────────────────────
	unit.set_controlled(false)
	_check(not unit.controlled, "S/Ctrl/↓ 로 손을 뗀다")
	_check(player.input_enabled, "내리면 플레이어 입력이 돌아온다")
	_check(_main.get("controlled_turret") == null, "Main 의 조종 대상이 비워진다")
	_check((_main.get("camera") as Camera2D).target == _main.get("player"),
		"내리면 카메라 주체가 플레이어로 돌아온다")
	_check(not player.standby, "내리면 플레이어가 대기 모드에서 풀린다")

	# 무인으로 두면 다시 웅크린다
	for i in range(int((WalkerUnit.SLEEP_AFTER + WalkerUnit.SLEEP_TIME + 0.5) / STEP)):
		unit._process(STEP)
	_check(unit.state == WalkerUnit.State.DORMANT, "무인으로 %d초 두면 다시 웅크린다" % int(WalkerUnit.SLEEP_AFTER))

	# ── 10) 단말기 원격 접속 ───────────────────────────────────────────────────
	# 방어 그리드에서 **보행 기체**를 고르면 Main 이 kind 를 보고 walker_by_id 로 찾아야 한다
	# (포탑만 찾던 코드에 kind 분기를 넣은 자리다). 여기서 실제로 한 번 태워 본다.
	#
	# **맨 끝에 둔다.** 원격은 단말기 화면을 띄운 채로 도는 상태라 플레이어 입력이 계속 꺼져 있고,
	# 방까지 갈아 끼운다 — 앞의 검사들과 섞으면 그 부작용을 서로의 실패로 읽게 된다 (한 번 그랬다).
	var entry: Dictionary = walkers_in_grid[0]
	_main._switch_to_remote(entry)
	var linked = _main.get("current_room").walker_by_id(str(entry["id"]))
	_check(linked != null, "원격 접속이 그 기체가 있는 방을 열고 기체를 찾는다 (%s)" % entry["id"])
	if linked == null:
		return
	_check(not player.visible, "원격 조종 중에는 플레이어가 숨는다")
	_check(linked.state == WalkerUnit.State.WAKING, "원격으로도 꺼진 기체를 기동시킨다")
	# 포탑과 같다 — 다 서고 나서야 조종이 넘어온다 (전개 중에 조종이 붙으면 반쯤 선 채로 움직인다)
	for i in range(int(WalkerUnit.WAKE_TIME / STEP) + 20):
		linked._process(STEP)
	_check(linked.controlled, "다 서면 원격 조종이 넘어온다")
	_check(_main.get("controlled_turret") == linked, "Main 의 조종 대상이 원격으로 잡은 그 기체다")


func _report() -> void:
	print("\n=== 사족보행 기체 (WalkerUnit) 검사 ===")
	for n in _notes:
		print(n)
	for f in _fails:
		print(f)
	print("--- 결과 ---")
	print("  통과" if _fails.is_empty() else "  실패 %d 건" % _fails.size())
