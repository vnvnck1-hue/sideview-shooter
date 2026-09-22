extends SceneTree
## 공간 테스트 방(SpaceLabData) 검사 — tools/validate_map.gd 와 같은 규칙을 임시 방 하나에 적용한다.
## 이 방은 RoomData.ROOMS 에 없으므로 validate_map.gd 가 보지 않는다. 그래서 검사도 따로 둔다.
## 실행:  godot --path . --headless --script res://tools/validate_space_lab.gd

const MIN_ROWS := 4
const SIDE_MARGIN := 190.0          # 방 좌우 끝에서 이만큼은 비워 둔다 (측벽문 자리)

var _errors: Array = []
var _warnings: Array = []


func _init() -> void:
	var id := SpaceLabData.register()
	var data := RoomData.get_room(id)
	var hs := RoomData.heights(id)
	var lay := RoomData.layout(id)
	var w := float(lay["width"])
	var floor_y := float(RoomData.floor_y(id))

	print("=== %s ===" % data["title"])
	print("테마 %s · %d열 × %d행 · %d × %d px · 천장 최고 %d · 몬스터 %s(max %d)" % [
		data["theme"], hs.size(), lay["rows"], int(w),
		int(lay["bottom_y"] - lay["ceiling_y"]), int(lay["ceiling_y"]),
		RoomData.danger(id), int(data["spawn"]["max"])])
	print("구획: %d (방 %d · 열린 통로 %d · 구역 문 %d)" % [
		SpaceLabData.CHAMBERS.size(), _count_kind("room"), _count_kind("link"), _count_kind("gate")])
	for gi in SpaceLabData.gate_indices():
		var rv: Array = SpaceLabData.gate_reveal(gi)
		print("  구역 문 %s  x=%d  →  드러나는 구역 %d ~ %d (%s)" % [
			SpaceLabData.CHAMBERS[gi]["name"], int(SpaceLabData.gate_x(gi)),
			int(rv[0]), int(rv[1]), SpaceLabData.next_room_name(gi)])

	if not RoomTheme.THEMES.has(data["theme"]):
		_errors.append("테마 없음 '%s'" % data["theme"])
	for h in hs:
		if int(h) < MIN_ROWS:
			_errors.append("열 높이 %d < %d" % [h, MIN_ROWS])
			break
	var bad := RoomTiles.invalid_cells(hs)
	if not bad.is_empty():
		_errors.append("프레임 조각이 없는 셀 %d개: %s" % [bad.size(), bad.slice(0, 8)])

	if not data["front_doors"].is_empty():
		_errors.append("이 방은 정면문을 쓰지 않는다 (트랜지션 없는 구조를 보는 씬)")
	if data["left_door"].get("open", false) or data["right_door"].get("open", false):
		_errors.append("측벽문이 열려 있으면 존재하지 않는 방으로 나가게 된다")

	# 구역 문 — 통로 안에 서고, 드러나는 구역이 비어 있지 않아야 한다
	var prev_gx := -1.0
	for gi in SpaceLabData.gate_indices():
		var gx := SpaceLabData.gate_x(gi)
		var span: Array = SpaceLabData.spans()[gi]
		if gx <= float(span[0]) or gx >= float(span[1]):
			_errors.append("구역 문 %d 의 x=%d 가 통로(%d~%d) 밖" % [gi, int(gx), int(span[0]), int(span[1])])
		var rv: Array = SpaceLabData.gate_reveal(gi)
		if float(rv[1]) - float(rv[0]) < 1000.0:
			_errors.append("구역 문 %d 가 드러내는 구역이 %dpx 뿐" % [gi, int(float(rv[1]) - float(rv[0]))])
		if gx <= prev_gx:
			_errors.append("구역 문 순서가 뒤집혔다 (x=%d)" % int(gx))
		prev_gx = gx

	# 웨이브 스폰 — 엔진 상한 안인지
	var sp_cfg: Dictionary = data["spawn"]
	if int(sp_cfg.get("max", 0)) > Room.MONSTER_HARD_CAP:
		_errors.append("spawn.max %d 가 Room.MONSTER_HARD_CAP %d 를 넘는다" % [int(sp_cfg["max"]), Room.MONSTER_HARD_CAP])
	if sp_cfg.has("wave"):
		var wv: Dictionary = sp_cfg["wave"]
		var wsize: Array = wv.get("size", [0, 0])
		print("웨이브: %0.0f초마다 %d~%d마리 (첫 웨이브 %0.0f초) · 동시 상한 %d" % [
			float(wv.get("interval", 0.0)), int(wsize[0]), int(wsize[1]),
			float(wv.get("first", 0.0)), mini(int(sp_cfg.get("max", 0)), Room.MONSTER_HARD_CAP)])
		if int(wsize[1]) > Room.MONSTER_HARD_CAP:
			_warnings.append("웨이브 한 무리(%d)가 동시 상한(%d)보다 크다 — 남는 마리는 버려진다" % [int(wsize[1]), Room.MONSTER_HARD_CAP])

	# 프랍 — x 가 벽 안쪽인지, 텍스처가 있는지, 서로 겹치지 않는지
	var floor_props: Array = []       # [x0, x1, 이름]
	for p in data["props"]:
		var x := float(p["x"])
		var label := str(p.get("tex", p.get("type", "?"))).get_file()
		if x < SIDE_MARGIN or x > w - SIDE_MARGIN:
			_errors.append("프랍 %s x=%d 가 방 밖/측벽 자리" % [label, int(x)])
		if p.has("tex"):
			var path := Room._prop_path(p["tex"])
			if not ResourceLoader.exists(path):
				_errors.append("프랍 텍스처 없음 %s" % path)
				continue
			if p.has("cy") or p.has("fy"):
				continue          # 벽걸이는 바닥 자리를 먹지 않는다
			var tex: Texture2D = load(path)
			floor_props.append([x - tex.get_width() * 0.5, x + tex.get_width() * 0.5, label])
		else:
			match p.get("type", ""):
				"sentry":
					floor_props.append([x - 188.0, x + 188.0, "sentry"])
					if floor_y - RoomData.ceiling_at(id, x) < 440.0:
						_errors.append("센트리건 x=%d 자리의 천장이 440px 보다 낮다" % int(x))
				"walker":
					floor_props.append([x - 250.0, x + 250.0, "walker"])
				"capacitor", "cart", "cabinet":
					floor_props.append([x - 150.0, x + 150.0, str(p["type"])])

	floor_props.sort_custom(func(a, b): return a[0] < b[0])
	for i in range(1, floor_props.size()):
		if floor_props[i][0] < floor_props[i - 1][1]:
			_warnings.append("바닥 프랍 겹침: %s ↔ %s" % [floor_props[i - 1][2], floor_props[i][2]])

	# 램프·기구·fx — 천장 띠 아래인지, 벽 안쪽인지
	for lx in data["lamps"]:
		if float(lx) < SIDE_MARGIN or float(lx) > w - SIDE_MARGIN:
			_errors.append("램프 x=%d 가 방 밖" % int(lx))
	for f in data["fixtures"]:
		var fx_x := float(f["x"])
		if fx_x < SIDE_MARGIN or fx_x > w - SIDE_MARGIN:
			_errors.append("조명 기구 %s x=%d 가 방 밖" % [f["file"], int(fx_x)])
		if not ResourceLoader.exists(RoomData.POWER_RELAY_DIR + "Lighting/power_relay_%s.png" % f["file"]):
			_errors.append("조명 기구 텍스처 없음 %s" % f["file"])
	var waters := 0
	for e in data["fx"]:
		var ex := float(e.get("x", 0.0))
		if e["type"] == "water":
			waters += 1
			continue
		if ex < SIDE_MARGIN or ex > w - SIDE_MARGIN:
			_errors.append("fx %s x=%d 가 방 밖" % [e["type"], int(ex)])
		if e.has("cy"):
			var head := floor_y - (RoomData.ceiling_at(id, ex) + float(e["cy"]))
			if head < 120.0:
				_warnings.append("fx %s x=%d 가 바닥에서 %dpx 밖에 안 뜬다" % [e["type"], int(ex), int(head)])
	if waters > 1:
		_errors.append("고인 물(water)은 방마다 하나만 — %d개" % waters)

	for m in data["monsters"]:
		var mx := float(m["x"])
		if mx < SIDE_MARGIN or mx > w - SIDE_MARGIN:
			_errors.append("몬스터 x=%d 가 방 밖" % int(mx))

	# 구획 경계 — 문틀이 통로 안에 들어 있는지
	for span in SpaceLabData.spans():
		if float(span[1]) > w:
			_errors.append("구획 경계 %d 가 방 폭 %d 를 넘는다" % [int(span[1]), int(w)])

	print("\n프랍 %d · 램프 %d · 조명 기구 %d · fx %d · 시작 몬스터 %d" % [
		data["props"].size(), data["lamps"].size(), data["fixtures"].size(),
		data["fx"].size(), data["monsters"].size()])
	for wn in _warnings:
		print("경고: ", wn)
	for e in _errors:
		printerr("오류: ", e)
	print("오류 %d · 경고 %d" % [_errors.size(), _warnings.size()])
	quit(1 if not _errors.is_empty() else 0)


func _count_kind(kind: String) -> int:
	var n := 0
	for c in SpaceLabData.CHAMBERS:
		if c["kind"] == kind:
			n += 1
	return n
