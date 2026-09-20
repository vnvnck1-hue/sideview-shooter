extends Node
## 단말기 플로우 헤드리스 점검 (Docs/TERMINAL_SYSTEM_CONCEPT.md).
## 실행:  godot --path . --headless res://scenes/TerminalTest.tscn
## 오류가 하나라도 있으면 종료 코드 1.
##
## --script 가 아니라 **씬**으로 도는 이유: 자동 로드(CrtFx)는 커스텀 MainLoop 에는 붙지 않는다.
## 그래서 이 노드가 Main 을 자식으로 직접 띄운다 (씬 전환을 쓰면 이 노드가 같이 사라진다).
##
## 입력 없이 Main 의 접속 흐름을 코드로 직접 밟는다:
##   데이터 무결성 → 지도 골격 → 접속(부팅→메뉴) → 방어 그리드(지도에서 포탑 선택)
##   → 원격 조종(방 교체·포탑 인계) → 링크 해제 → 접속 종료 → 역할별 화면
## 헤드리스라 셰이더 컴파일 경고가 섞여 나오지만 스크립트 오류만 결과에 반영된다.

const BOOT_ROOM := "sec_quarters"      # 원격 링크를 시험할 보안 단말기 (숙소 복도, 관할: 승무원·전력)

var _fails: Array = []
var _main: Node


func _ready() -> void:
	_check_data()
	AppFlow.start_room = "quarters_corr"
	AppFlow.resume_x = -1.0
	_main = load(AppFlow.TEST_SCENE).instantiate()
	add_child(_main)
	_run.call_deferred()


func _fail(msg: String) -> void:
	_fails.append(msg)
	printerr("FAIL  " + msg)


func _ok(msg: String) -> void:
	print("  ok   " + msg)


## 맵의 id 와 TerminalData 가 서로 맞물리는지 — 실행 전에 데이터만으로 확인할 수 있는 것들
func _check_data() -> void:
	print("=== 데이터 ===")
	var placed := {}
	for room_id in RoomData.ROOMS:
		for p in RoomData.ROOMS[room_id].get("props", []):
			if p.get("type", "") != "terminal":
				continue
			var tid := str(p.get("id", ""))
			if not TerminalData.has(tid):
				_fail("맵의 단말기 id '%s' (%s) 가 TerminalData 에 없다" % [tid, room_id])
			elif placed.has(tid):
				_fail("단말기 id '%s' 가 %s 와 %s 에 중복 배치되었다" % [tid, placed[tid], room_id])
			else:
				placed[tid] = room_id
	for tid in TerminalData.TERMINALS:
		if not placed.has(tid):
			_fail("TerminalData 의 단말기 '%s' 가 맵 어디에도 배치되지 않았다" % tid)
	_ok("단말기 %d기 배치·정의 일치" % placed.size())

	var sentries := TerminalData.sentries()
	if sentries.is_empty():
		_fail("맵에 id 가 붙은 센트리건이 하나도 없다")
	_ok("센트리건 %d기: %s" % [sentries.size(), ", ".join(sentries.map(func(s): return s["id"]))])

	# 보안 단말기마다 관할 안에 잡을 포탑이 실제로 있는지 — 없으면 메뉴가 통째로 잠긴다
	for tid in TerminalData.TERMINALS:
		if TerminalData.get_terminal(tid).get("role", "") != "security":
			continue
		var room: String = placed.get(tid, "")
		var reachable: Array = TerminalData.grid_entries(tid, room).filter(func(e): return e["authorized"])
		if reachable.is_empty():
			_fail("보안 단말기 '%s' 의 관할에 포탑이 하나도 없다" % tid)
		else:
			var remote: Array = reachable.filter(func(e): return not e["local"])
			_ok("%s (%s) → 관할 %d기 (다른 방 %d기)" % [tid, room, reachable.size(), remote.size()])
			if remote.is_empty():
				_fail("보안 단말기 '%s' 가 같은 방 포탑만 잡는다 — 원격의 의미가 없다" % tid)

	_check_map()


## 지도 골격 — StationMap 이 맵 데이터(문 그래프)만으로 방을 전부 줄 세우는지.
## 방이 빠지거나 한 줄 안에서 겹치면 지도가 조용히 틀린 그림을 그리므로 여기서 잡는다.
func _check_map() -> void:
	StationMap.invalidate()
	var lay := StationMap.layout()
	var nodes: Dictionary = lay["nodes"]
	if nodes.size() != RoomData.ROOMS.size():
		_fail("지도에서 빠진 방이 있다 (%d / %d)" % [nodes.size(), RoomData.ROOMS.size()])
	else:
		_ok("지도 골격: 방 %d개 · %d줄 · 가로 %d셀" % [nodes.size(), lay["rows"].size(), lay["cols"]])
	var overlap := ""
	for r in lay["rows"].size():
		var chain: Array = lay["rows"][r]
		if chain.is_empty():
			_fail("지도 %d번 줄(%s)에 방이 하나도 없다" % [r, StationMap.ZONE_ROWS[r]])
		for i in range(chain.size() - 1):
			var a: Dictionary = nodes[str(chain[i])]
			var b: Dictionary = nodes[str(chain[i + 1])]
			if int(a["col"]) + int(a["cells"]) > int(b["col"]):
				overlap = "%s 와 %s" % [a["id"], b["id"]]
	if overlap != "":
		_fail("지도에서 방이 겹쳐 놓였다: %s" % overlap)
	else:
		_ok("지도 줄 배치 겹침 없음")
	# 정면문이 지도에서도 양쪽 다 노드를 찾는지 (한쪽만 있으면 선이 허공으로 간다)
	for link in lay["front"]:
		if not nodes.has(str(link[0])) or not nodes.has(str(link[1])):
			_fail("정면문 %s ↔ %s 의 한쪽이 지도에 없다" % [link[0], link[1]])


func _run() -> void:
	await _wait(0.3)
	print("=== 접속 흐름 ===")
	var screen: TerminalScreen = _main.terminal_screen
	var terminal: AccessTerminal = _main.current_room.terminal_by_id(BOOT_ROOM)
	if terminal == null:
		_fail("%s 단말기를 방에서 찾지 못했다" % BOOT_ROOM)
		_finish()
		return
	_ok("단말기 배치 확인: %s @ %s" % [BOOT_ROOM, _main.current_room.room_id])

	# 1. 접속 — 카메라가 밀려 들어가고 CRT 가 켜지며 부팅이 시작된다
	terminal.activate()
	await _wait(2.0)            # 카메라 밀어넣기(0.28s) + 부팅 타이핑(0.9s) 이 끝날 시간
	if screen.state != TerminalScreen.State.MENU:
		_fail("접속 후 루트 메뉴에 도달하지 못했다 (state=%d)" % screen.state)
	else:
		_ok("부팅 → 루트 메뉴")
	if not CrtFx.overridden():
		_fail("CRT 프리셋이 밀려 들어가지 않았다")
	elif CrtPreset.get_preset(CrtFx.index)["id"] != terminal.role["crt"]:
		_fail("CRT 프리셋이 역할의 '%s' 가 아니다" % terminal.role["crt"])
	else:
		_ok("CRT 프리셋 '%s' 적용" % terminal.role["crt"])
	if _main.player.input_enabled:
		_fail("접속 중인데 플레이어 입력이 살아 있다")

	# 2. 방어 그리드 → 지도에서 포탑을 골라 원격 링크
	screen._open_grid()
	if screen.state != TerminalScreen.State.GRID:
		_fail("방어 그리드로 들어가지 못했다 (state=%d)" % screen.state)
	if not screen._map.visible:
		_fail("방어 그리드인데 지도가 그려지지 않는다")
	if not screen._map.has_targets():
		_fail("지도 위에 잡을 수 있는 포탑이 하나도 없다")
	else:
		_ok("방어 그리드 지도: 커서가 설 수 있는 포탑 %d기" % screen._map._targets.size())
	for t in screen._map._targets:          # 커서는 관할 포탑에만 선다
		if not screen._grid[int(t["entry"])]["authorized"]:
			_fail("지도 커서가 관할 밖 포탑(%s)에 선다" % screen._grid[int(t["entry"])]["id"])
	var moved := false                       # 커서가 실제로 다른 포탑으로 옮겨 가는지
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if screen._map.move(dir):
			moved = true
			break
	if not moved and screen._map._targets.size() > 1:
		_fail("포탑이 여러 기인데 지도 커서가 움직이지 않는다")

	var remote_entry := {}
	for e in screen._grid:
		if e["authorized"] and not e["local"]:
			remote_entry = e
			break
	if remote_entry.is_empty():
		_fail("다른 방에 있는 관할 포탑이 없다")
		_finish()
		return
	_ok("원격 대상: %s (%s)" % [remote_entry["name"], remote_entry["room_title"]])

	var home_room: String = _main.current_room.room_id
	_main._on_terminal_link(remote_entry)
	await _wait(1.2)            # 채널 전환 글리치(0.57s) 중간에 방이 교체된다
	if _main.current_room.room_id != remote_entry["room"]:
		_fail("월드가 원격 방(%s)으로 바뀌지 않았다 (지금 %s)" % [remote_entry["room"], _main.current_room.room_id])
	else:
		_ok("월드 교체: %s → %s" % [home_room, _main.current_room.room_id])
	if screen.state != TerminalScreen.State.REMOTE:
		_fail("화면이 원격 관제 상태로 넘어가지 않았다 (state=%d)" % screen.state)
	if _main.player.visible:
		_fail("원격 중인데 플레이어가 보인다")
	var turret: SentryTurret = _main.current_room.sentry_by_id(str(remote_entry["id"]))
	if turret == null:
		_fail("원격 방에서 포탑 '%s' 를 찾지 못했다" % remote_entry["id"])
	else:
		await _wait(1.5)                      # 전개 애니(8프레임 10fps = 0.8s)가 끝나고 조종으로 넘어올 시간
		if not turret.controlled:
			_fail("포탑이 전개 후 조종 상태로 넘어오지 않았다 (state=%d)" % turret.state)
		elif _main.controlled_turret != turret:
			_fail("Main 이 이 포탑을 조종 중으로 잡지 않았다")
		else:
			_ok("포탑 전개 → 원격 조종 인계")

	# 3. 링크 해제 — 원래 방·원래 자리로
	_main._on_terminal_unlink()
	await _wait(1.2)
	if _main.current_room.room_id != home_room:
		_fail("링크 해제 후 원래 방(%s)으로 돌아오지 않았다 (지금 %s)" % [home_room, _main.current_room.room_id])
	else:
		_ok("원래 방으로 복귀")
	if not _main.player.visible:
		_fail("복귀했는데 플레이어가 아직 숨어 있다")
	if screen.state != TerminalScreen.State.GRID:
		_fail("복귀 후 방어 그리드 목록으로 돌아가지 않았다 (state=%d)" % screen.state)

	# 4. 접속 종료 — 프리셋이 플레이어가 고른 것으로 되돌아와야 한다
	screen._back()                            # GRID → MENU
	screen._back()                            # MENU → 종료 요청
	await _wait(1.2)
	if screen.is_open():
		_fail("접속이 끊기지 않았다 (state=%d)" % screen.state)
	else:
		_ok("접속 종료")
	if CrtFx.overridden():
		_fail("CRT 프리셋이 원래대로 돌아오지 않았다")
	if not _main.player.input_enabled:
		_fail("접속을 끊었는데 플레이어 입력이 돌아오지 않았다")
	else:
		_ok("플레이어 조작 복귀")

	await _roles()
	_finish()


## 역할마다 페이지를 한 번씩 열어 본다 — 보안 말고도 로그·배전·저장 화면이 실제로 그려지는지.
## 방을 새로 조립해 그 방의 단말기를 직접 열고, 각 페이지의 본문이 비어 있지 않은지만 확인한다.
func _roles() -> void:
	print("=== 역할별 화면 ===")
	var screen: TerminalScreen = _main.terminal_screen
	var tour := {                       # 단말기 id → 그 역할에서 확인할 페이지
		"link_bunk_b": "logs",
		"rewire_nursery": "rewire",
		"save_corr_mid": "save",
		"survey_cable": "map",
	}
	for tid in tour:
		var room := _room_of(tid)
		_main._load_room(room, 200.0, 1)
		await _wait(0.1)
		var t: AccessTerminal = _main.current_room.terminal_by_id(tid)
		if t == null:
			_fail("%s 를 %s 에서 찾지 못했다" % [tid, room])
			continue
		screen.open(t, room)
		await _wait(1.6)                # 부팅이 끝나 메뉴가 뜰 때까지
		if screen.state != TerminalScreen.State.MENU:
			_fail("%s: 메뉴에 도달하지 못했다 (state=%d)" % [tid, screen.state])
			screen.force_close()
			continue
		if screen._rows.is_empty():
			_fail("%s: 메뉴가 비어 있다" % tid)
		screen._activate()              # 첫 항목 실행 → 그 역할의 본문 페이지
		await _wait(0.2)
		var page: String = "%d" % screen.state
		if screen._body.text.strip_edges() == "":
			_fail("%s: %s 페이지 본문이 비어 있다" % [tid, page])
		else:
			if tour[tid] == "logs":     # 목록 → 첫 로그 본문까지
				screen._activate()
				await _wait(0.2)
				if screen.state != TerminalScreen.State.LOG:
					_fail("%s: 로그 본문으로 들어가지 못했다" % tid)
			elif tour[tid] == "map":    # 구역 지도 → 관할 구역이 실시간으로 읽히는지
				if screen.state != TerminalScreen.State.MAP:
					_fail("%s: 구역 지도로 들어가지 못했다 (state=%d)" % [tid, screen.state])
				elif not screen._map.visible:
					_fail("%s: 구역 지도인데 지도가 그려지지 않는다" % tid)
				else:
					var lit := 0
					for rid in RoomData.ROOMS:
						if screen._map.reveal_of(str(rid)) == StationMap.Reveal.LIVE:
							lit += 1
					if lit == 0:
						_fail("%s: 실시간 판독되는 방이 하나도 없다" % tid)
					else:
						_ok("%s: 실시간 판독 %d개 방" % [tid, lit])
			_ok("%s (%s) → %s 페이지 %d자" % [tid, t.role_id, tour[tid], screen._body.text.length()])
		screen.force_close()
		await _wait(0.1)


func _room_of(tid: String) -> String:
	for room_id in RoomData.ROOMS:
		for p in RoomData.ROOMS[room_id].get("props", []):
			if p.get("type", "") == "terminal" and str(p.get("id", "")) == tid:
				return room_id
	return ""


## 연출은 전부 실시간 초 단위 트윈/타이머라 프레임 수가 아니라 **시간**으로 기다려야 한다
## (헤드리스는 프레임이 훨씬 빨리 돌아 프레임을 세면 거의 시간이 흐르지 않는다).
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _finish() -> void:
	print("\n=== 결과 ===")
	if _fails.is_empty():
		print("통과")
		get_tree().quit(0)
	else:
		print("실패 %d건" % _fails.size())
		for f in _fails:
			print("  - " + f)
		get_tree().quit(1)
