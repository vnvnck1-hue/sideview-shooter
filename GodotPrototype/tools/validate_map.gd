extends SceneTree
## 맵 데이터 검사 (헤드리스): RoomData.ROOMS 의 모양·문 연결·프랍·조명·리소스를 검사하고 방마다 문자 지도를 찍는다.
## 실행:  godot --path . --headless --script res://tools/validate_map.gd
## 오류가 하나라도 있으면 종료 코드 1.
##   - 테마 존재 · 열 프로필(높이 ≥ 4, 조각 없는 셀 없음)
##   - 측벽문: 열린 문의 목적지가 존재하고 그 방의 반대편 문이 이 방을 가리킨다
##   - 정면문: 목적지·번호가 유효하고 서로를 가리킨다, 방 폭 안, 측벽문 자리(양 끝 190px)와 겹치지 않음
##   - 프랍·램프·기구·fx 의 x 가 벽 띠 안쪽, 텍스처 파일 존재
##   - START_ROOM 에서 모든 방에 닿는다 (연결 그래프)
##   - 테마마다 방이 1개 이상, 몬스터 없음/적음/위험 방이 각각 1개 이상

const SIDE_DOOR_ZONE := 190.0
const MIN_ROWS := 4

var _errors: Array = []
var _sentry_ids := {}                  # 센트리건 id 는 맵 전체에서 유일해야 한다 (보안 단말기가 id 로 지목한다)
var _npc_ids := {}                     # 생존자도 맵 전체에서 유일 — 다른 인물의 대사가 "그 사람은 어디 있다" 고 가리킨다
var _warnings: Array = []


func _init() -> void:
	var ids: Array = RoomData.ids()
	var theme_count := {}
	var danger_count := {"안전": 0, "적음": 0, "위험": 0}
	print("=== 방 %d개 ===" % ids.size())
	for id in ids:
		_check_room(id)
		var data := RoomData.get_room(id)
		theme_count[data["theme"]] = theme_count.get(data["theme"], 0) + 1
		danger_count[RoomData.danger(id)] += 1

	for theme in RoomTheme.ids():
		if theme_count.get(theme, 0) == 0:
			_errors.append("테마 '%s' 를 쓰는 방이 없다" % theme)
	for k in danger_count.keys():
		if danger_count[k] == 0:
			_errors.append("몬스터 '%s' 방이 없다" % k)
	_check_connectivity()
	_check_map_layout()
	_check_dialogue()

	print("\n=== 요약 ===")
	print("테마별 방 수: ", theme_count)
	print("몬스터 밀도: ", danger_count)
	for w in _warnings:
		print("경고: ", w)
	for e in _errors:
		printerr("오류: ", e)
	print("오류 %d · 경고 %d" % [_errors.size(), _warnings.size()])
	quit(1 if not _errors.is_empty() else 0)


func _check_room(id: String) -> void:
	var data := RoomData.get_room(id)
	var hs := RoomData.heights(id)
	var lay := RoomData.layout(id)
	var w := float(lay["width"])
	print("\n[%s] %s › %s  theme=%s  %d×%d셀 (%d×%d px)  천장 %d  몬스터 %s(max %d)" % [
		id, data["zone"], data["title"], data["theme"], hs.size(), lay["rows"], int(w),
		int(lay["bottom_y"] - lay["ceiling_y"]), int(lay["ceiling_y"]), RoomData.danger(id), int(data["spawn"]["max"])])
	print(RoomTiles.ascii_map(hs))

	if not RoomTheme.THEMES.has(data["theme"]):
		_errors.append("%s: 테마 없음 '%s'" % [id, data["theme"]])
	for kind in ["bg", "frame", "bend"]:
		if RoomTheme.THEMES.has(data["theme"]) and not ResourceLoader.exists(RoomTheme.sheet(data["theme"], kind)):
			_errors.append("%s: 타일 시트 없음 %s" % [id, RoomTheme.sheet(data["theme"], kind)])
	for h in hs:
		if int(h) < MIN_ROWS:
			_errors.append("%s: 열 높이 %d < %d (측벽문 480px 가 천장을 넘는다)" % [id, h, MIN_ROWS])
			break
	var bad := RoomTiles.invalid_cells(hs)
	if not bad.is_empty():
		_errors.append("%s: 프레임 조각이 없는 셀 %s (1칸 폭 기둥·1칸 높이 구간)" % [id, bad])

	# 측벽문
	for side in ["left_door", "right_door"]:
		var d: Dictionary = data[side]
		if not d.get("open", false):
			continue
		var target: String = d.get("target", "")
		if not RoomData.ROOMS.has(target):
			_errors.append("%s: %s 목적지 없음 '%s'" % [id, side, target])
			continue
		var back: Dictionary = RoomData.get_room(target)["right_door" if side == "left_door" else "left_door"]
		if not back.get("open", false) or back.get("target", "") != id:
			_errors.append("%s: %s → %s 인데 %s 의 반대편 문이 되돌아오지 않는다 (%s)" % [id, side, target, target, back])

	# 정면문
	var doors: Array = data["front_doors"]
	for i in range(doors.size()):
		var fd: Dictionary = doors[i]
		var x := float(fd["x"])
		var target: String = fd["target"]
		if x < SIDE_DOOR_ZONE or x + RoomData.FRONT_DOOR_W > w - SIDE_DOOR_ZONE:
			_errors.append("%s: 정면문 %d x=%d 가 측벽문 자리와 겹치거나 방 밖" % [id, i, int(x)])
		if not RoomData.ROOMS.has(target):
			_errors.append("%s: 정면문 %d 목적지 없음 '%s'" % [id, i, target])
			continue
		var tdoors: Array = RoomData.get_room(target)["front_doors"]
		var ti := int(fd["target_door"])
		if ti < 0 or ti >= tdoors.size():
			_errors.append("%s: 정면문 %d → %s #%d 없음 (정면문 %d개)" % [id, i, target, ti, tdoors.size()])
		elif tdoors[ti]["target"] != id or int(tdoors[ti]["target_door"]) != i:
			_errors.append("%s: 정면문 %d ↔ %s #%d 가 서로를 가리키지 않는다" % [id, i, target, ti])
		for j in range(i):
			if absf(float(doors[j]["x"]) - x) < RoomData.FRONT_DOOR_W:
				_errors.append("%s: 정면문 %d 와 %d 가 겹친다" % [id, i, j])

	# 프랍
	var occupied: Array = []            # [x0, x1, 이름] 바닥 프랍 겹침 경고용
	for p in data.get("props", []):
		var x := float(p["x"])
		var label: String = str(p.get("tex", p.get("type", "?"))).get_file()
		var pw := 0.0
		var ph := 0.0                   # 세로 크기를 아는 프랍만 천장 높이를 검사한다
		if p.has("tex"):
			var path := Room._prop_path(p["tex"])
			if not ResourceLoader.exists(path):
				_errors.append("%s: 프랍 텍스처 없음 %s" % [id, path])
			else:
				var t: Texture2D = load(path)
				pw = float(t.get_width())
				ph = float(t.get_height())
		else:
			match p["type"]:
				"cabinet": pw = 368.0
				"capacitor": pw = 360.0
				"cart": pw = 224.0
				"breaker": pw = 192.0
				"sentry":
					pw = 376.0 * SentryTurret.SCALE
					ph = 440.0 * SentryTurret.SCALE
					var sid := str(p.get("id", ""))
					if sid == "" or _sentry_ids.has(sid):
						_errors.append("%s: 센트리건 id '%s' 가 비었거나 중복이다 — 보안 단말기가 지목할 수 없다" % [id, sid])
					_sentry_ids[sid] = true
				"npc":
					var nid := str(p.get("id", ""))
					if not NpcData.CAST.has(nid) or nid == "player":
						_errors.append("%s: 생존자 id '%s' 가 NpcData.CAST 에 없다" % [id, nid])
					elif _npc_ids.has(nid):
						_errors.append("%s: 생존자 id '%s' 가 다른 방에도 있다" % [id, nid])
					else:
						_npc_ids[nid] = id
						label = "npc:" + nid
						pw = float(NpcData.CAST[nid]["body"])    # 셀(320) 이 아니라 실제 몸 폭
						ph = float(NpcData.CAST[nid]["head"])
					if int(RoomData.get_room(id).get("spawn", {}).get("max", 0)) > 0:
						_warnings.append("%s: 생존자 '%s' 가 몬스터가 도는 방에 있다 — 대화 중에는 플레이어가 움직이지 못한다" % [id, nid])
				"terminal":
					# 폭·높이는 역할(또는 단말기 정의의 덮어쓰기)이 고른 자산에서 그대로 읽는다
					var tid := str(p.get("id", ""))
					if not TerminalData.has(tid):
						_errors.append("%s: 단말기 id '%s' 가 TerminalData.TERMINALS 에 없다" % [id, tid])
					else:
						label = "terminal:" + tid
						var tpath := TerminalData.texture_of(tid)
						var ttex: Texture2D = load(tpath)
						pw = float(ttex.get_width())
						ph = float(ttex.get_height())
				_: _errors.append("%s: 알 수 없는 프랍 type '%s'" % [id, p["type"]])
		if x - pw * 0.5 < RoomTiles.WALL_BAND or x + pw * 0.5 > w - RoomTiles.WALL_BAND:
			_errors.append("%s: 프랍 %s x=%d (폭 %d) 가 벽 밖으로 나간다" % [id, label, int(x), int(pw)])
		var wall_mounted: bool = p.has("cy") or p.has("fy")
		if p.get("type", "") == "terminal" and TerminalData.has(str(p.get("id", ""))):
			if TerminalData.is_wall(str(p["id"])) != wall_mounted:
				_errors.append("%s: 단말기 '%s' 의 설치 방식이 어긋난다 — TerminalData 는 %s, 맵은 %s" % [
					id, p["id"], "벽걸이" if TerminalData.is_wall(str(p["id"])) else "바닥",
					"벽걸이(cy/fy)" if wall_mounted else "바닥"])
		if not wall_mounted and ph > 0.0:
			var head := RoomData.floor_y(id) - RoomData.ceiling_at(id, x)
			if ph > head:
				_errors.append("%s: 바닥 프랍 %s x=%d 높이 %d 가 그 자리 천장 높이 %d 를 넘는다" % [id, label, int(x), int(ph), int(head)])
		if not wall_mounted and p.get("type", "") != "npc":
			for fd in doors:
				var dx0 := float(fd["x"])
				if x + pw * 0.5 > dx0 + 40.0 and x - pw * 0.5 < dx0 + RoomData.FRONT_DOOR_W - 40.0:
					_warnings.append("%s: 바닥 프랍 %s x=%d 가 정면문(x %d) 앞을 가린다" % [id, label, int(x), int(dx0)])
			for o in occupied:
				if x - pw * 0.5 < o[1] and x + pw * 0.5 > o[0]:
					_warnings.append("%s: 바닥 프랍 %s x=%d 와 %s 가 겹친다" % [id, label, int(x), o[2]])
			if x - pw * 0.5 < SIDE_DOOR_ZONE and data["left_door"].get("open", false) == false:
				_warnings.append("%s: 프랍 %s 가 닫힌 왼쪽 측벽문 위에 있다" % [id, label])
			if x + pw * 0.5 > w - SIDE_DOOR_ZONE and data["right_door"].get("open", false) == false:
				_warnings.append("%s: 프랍 %s 가 닫힌 오른쪽 측벽문 위에 있다" % [id, label])
			occupied.append([x - pw * 0.5, x + pw * 0.5, label])

	# 램프·기구·fx
	for lx in data.get("lamps", []):
		if float(lx) < RoomTiles.WALL_BAND + 52.0 or float(lx) > w - RoomTiles.WALL_BAND - 52.0:
			_errors.append("%s: 램프 x=%d 가 벽 띠에 걸친다" % [id, int(lx)])
	for f in data.get("fixtures", []):
		var path := RoomData.POWER_RELAY_DIR + "Lighting/power_relay_%s.png" % f["file"]
		if not ResourceLoader.exists(path):
			_errors.append("%s: 조명 기구 텍스처 없음 %s" % [id, path])
		if float(f["x"]) < 0.0 or float(f["x"]) > w:
			_errors.append("%s: 조명 기구 %s x=%d 방 밖" % [id, f["file"], int(f["x"])])
	for fx in data.get("fx", []):
		if fx["type"] == "water":
			continue
		var x := float(fx.get("x", fx.get("pos", Vector2.ZERO).x))
		if x < RoomTiles.WALL_BAND or x > w - RoomTiles.WALL_BAND:
			_errors.append("%s: fx %s x=%d 가 벽 안" % [id, fx["type"], int(x)])
		if fx["type"] in ["wire", "power_cable"]:
			var top := RoomData.ceiling_at(id, x) + float(fx.get("cy", 0.0))
			if top + float(fx.get("length", 200.0)) > RoomData.FLOOR_Y - 60.0:
				_warnings.append("%s: %s x=%d 길이 %d 가 바닥까지 닿는다" % [id, fx["type"], int(x), int(fx.get("length", 200.0))])
	for m in data.get("monsters", []):
		if float(m["x"]) < Room.MONSTER_MARGIN or float(m["x"]) > w - Room.MONSTER_MARGIN:
			_errors.append("%s: 몬스터 x=%d 가 벽에 붙어 있다" % [id, int(m["x"])])


## 대사 나무: entry·next·branch·choices 가 가리키는 노드가 실제로 있는지, 조건식의 플래그가
## NpcData.FLAGS 에 적혀 있는지, 배치되지 않은 인물이 없는지 검사한다. 오타 하나가 대화를 통째로 끊는다.
func _check_dialogue() -> void:
	var reachable := {}
	for npc_id in NpcData.LINES.keys():
		if not _npc_ids.has(npc_id):
			_warnings.append("생존자 '%s' 의 대사는 있는데 어느 방에도 배치되지 않았다" % npc_id)
		var tree: Dictionary = NpcData.LINES[npc_id]
		var seen_nodes := {}
		for pair in tree.get("entry", []):
			_check_cond(npc_id, "entry", str(pair[0]))
			_link(npc_id, "entry", str(pair[1]), seen_nodes)
		for node_id in tree.keys():
			if node_id == "entry":
				continue
			var n: Dictionary = tree[node_id]
			var where := "%s/%s" % [npc_id, node_id]
			for f in n.get("set", []):
				if not NpcData.FLAGS.has(str(f)):
					_errors.append("%s: 플래그 '%s' 가 NpcData.FLAGS 에 없다" % [where, f])
			for pair in n.get("branch", []):
				_check_cond(npc_id, node_id, str(pair[0]))
				_link(npc_id, node_id, str(pair[1]), seen_nodes)
			for c in n.get("choices", []):
				_check_cond(npc_id, node_id, str(c.get("if", "")))
				for f in c.get("set", []):
					if not NpcData.FLAGS.has(str(f)):
						_errors.append("%s: 선택지 플래그 '%s' 가 NpcData.FLAGS 에 없다" % [where, f])
				_link(npc_id, node_id, str(c.get("to", "")), seen_nodes)
			if n.has("next"):
				_link(npc_id, node_id, str(n["next"]), seen_nodes)
			elif not n.has("choices") and not n.has("branch"):
				_errors.append("%s: next 도 choices 도 branch 도 없다 — 대화가 멈춘다" % where)
		for node_id in tree.keys():
			if node_id != "entry" and not seen_nodes.has(node_id):
				_warnings.append("%s/%s: 어디서도 닿지 않는 노드" % [npc_id, node_id])
		reachable[npc_id] = seen_nodes.size()
	print("
대사: 인물 %d명, 배치 %d명, 플래그 %d개" % [NpcData.LINES.size(), _npc_ids.size(), NpcData.FLAGS.size()])


func _link(npc_id: String, from: String, to: String, seen: Dictionary) -> void:
	if to == "":
		return                                   # 대화 종료
	if NpcData.node(npc_id, to).is_empty():
		_errors.append("%s/%s → 없는 노드 '%s'" % [npc_id, from, to])
		return
	seen[to] = true


func _check_cond(npc_id: String, node_id: String, cond: String) -> void:
	for term in cond.split("&"):
		var t := term.strip_edges().lstrip("!").strip_edges()
		if t == "" or t.begins_with("seen:"):
			continue
		if not NpcData.FLAGS.has(t):
			_errors.append("%s/%s: 조건의 플래그 '%s' 가 NpcData.FLAGS 에 없다" % [npc_id, node_id, t])


## 단말기 지도(StationMap)가 이 맵 데이터로 개략도를 짤 수 있는지 — 컨셉은 Docs/STATION_MAP.md.
## 지도는 문 그래프에서 레이아웃을 매번 산출하므로, 방을 추가하거나 문을 끊으면 여기서 먼저 티가 난다.
func _check_map_layout() -> void:
	StationMap.invalidate()
	var lay := StationMap.layout()
	var nodes: Dictionary = lay["nodes"]
	if nodes.size() != RoomData.ROOMS.size():
		for id in RoomData.ids():
			if not nodes.has(str(id)):
				_errors.append("%s: 단말기 지도에 자리가 없다 (zone 이 StationMap.ZONE_ROWS 에 없는지 확인)" % id)
	for r in lay["rows"].size():
		var chain: Array = lay["rows"][r]
		if chain.is_empty():
			_errors.append("지도 %d번 줄(%s)에 방이 하나도 없다" % [r, StationMap.ZONE_ROWS[r]])
			continue
		for i in range(chain.size() - 1):
			var a: Dictionary = nodes[str(chain[i])]
			var b: Dictionary = nodes[str(chain[i + 1])]
			if int(a["col"]) + int(a["cells"]) > int(b["col"]):
				_errors.append("지도에서 %s 와 %s 가 겹쳐 놓인다" % [a["id"], b["id"]])
	print("
지도: 방 %d개 · %d줄 · 가로 %d셀" % [nodes.size(), lay["rows"].size(), lay["cols"]])


func _check_connectivity() -> void:
	var seen := {RoomData.START_ROOM: true}
	var queue: Array = [RoomData.START_ROOM]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		var data := RoomData.get_room(id)
		var nexts: Array = []
		for side in ["left_door", "right_door"]:
			if data[side].get("open", false):
				nexts.append(data[side]["target"])
		for fd in data["front_doors"]:
			nexts.append(fd["target"])
		for n in nexts:
			if RoomData.ROOMS.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	for id in RoomData.ids():
		if not seen.has(id):
			_errors.append("%s: 시작 방 %s 에서 닿을 수 없다" % [id, RoomData.START_ROOM])
	print("\n연결: %s 에서 %d/%d 방 도달" % [RoomData.START_ROOM, seen.size(), RoomData.ROOMS.size()])
