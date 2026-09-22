extends SceneTree
## 거대종(Crawler.make_giant) 검사 — 어느 방이 이 덩치를 받아 줄 수 있나.
##
## 거대종은 폭 약 1050 · 높이 약 890 월드 px 로, **이 게임의 방 대부분보다 크다.**
## 방은 열마다 천장이 다른 계단형이라 "이 방" 이 아니라 "이 자리" 가 문제다.
## 그래서 Room 과 똑같은 규칙(Crawler.GIANT_CLEARANCE · GIANT_HALF_W)으로 열을 훑어
## 거대종이 몸을 펴고 설 수 있는 연속 구간을 방마다 뽑고, 배치된 거대종이 그 안에 있는지 본다.
##
## 실행:  godot --path . --headless --script res://tools/validate_giant.gd
## 주의:  --script 모드에는 오토로드(Audio)가 없어 Crawler 컴파일 시 "Identifier not found: Audio"
##        오류가 한 줄 찍힌다. tools/validate_map.gd 도 같고, 검사 결과에는 영향이 없다.

var _errors: Array = []


func _init() -> void:
	var art: float = Crawler.SCALE * Crawler.GIANT_SIZE
	var box := _max_bbox()
	print("=== 거대종 ===")
	print("몸집 %d × %d px (일반종 %d × %d 의 %.0f배) · 플레이어 키 320 px" % [
		int(box.x * art), int(box.y * art),
		int(box.x * Crawler.SCALE), int(box.y * Crawler.SCALE), Crawler.GIANT_SIZE])
	print("체력 %d (일반 %d) · 이동 %.0f px/s (일반 %.0f) · 사거리 %.0f px · 내려찍기 %.0f px 안" % [
		Crawler.GIANT_HP, Crawler.MAX_HP, Crawler.WALK_SPEED * Crawler.GIANT_SPEED,
		Crawler.WALK_SPEED, Crawler.GIANT_ATTACK_MAX, Crawler.SLAM_RANGE])
	print("설 자리 조건: 천장 ≥ %d px (걷기·포효) · 벽에서 ≥ %d px" % [
		int(Crawler.GIANT_CLEARANCE), int(Crawler.GIANT_HALF_W)])
	print("내려찍기 조건: 천장 ≥ %d px — 낮으면 그 자리에서는 산탄만 쓴다
" % int(Crawler.GIANT_SLAM_CLEARANCE))

	print("=== 방별 수용 ===")
	var capable := 0
	# 공간 테스트 방(SpaceLabData)은 RoomData.ROOMS 에 없어 ids() 가 보지 않는다.
	# 거대종 배치가 가장 많은 방이라 여기서만큼은 같이 잰다.
	var room_ids := RoomData.ids().duplicate()
	room_ids.append(SpaceLabData.register())
	for id in room_ids:
		var spans := _spans(id)
		var placed: Array = []
		for m in RoomData.get_room(id).get("monsters", []):
			if String(m.get("type", "crawler")) == "giant":
				placed.append(float(m["x"]))
		if not spans.is_empty():
			capable += 1
		var mark := "★" if not placed.is_empty() else ("+" if not spans.is_empty() else " ")
		var slam_ok := _headroom(id) >= Crawler.GIANT_SLAM_CLEARANCE
		print("%s %-16s 폭 %5d · 천장 %4d · 설 자리 %s%s" % [
			mark, id, RoomData.room_width(id), int(_headroom(id)), _fmt(spans),
			"" if slam_ok or spans.is_empty() else "   ← 내려찍기 못 함 (산탄만)"])
		for x in placed:
			if not _inside(spans, x):
				_errors.append("%s: 거대종 x=%d 가 설 자리 밖이다 (%s)" % [id, int(x), _fmt(spans)])

	print("\n거대종을 받는 방 %d / %d" % [capable, room_ids.size()])
	if _errors.is_empty():
		print("배치 이상 없음")
	else:
		for e in _errors:
			printerr("[오류] ", e)
	quit(0 if _errors.is_empty() else 1)


## 모든 프레임을 통틀어 가장 큰 내용 영역 (셀 px)
func _max_bbox() -> Vector2:
	var f := FileAccess.open(Crawler.DIR + "crawler_meta.json", FileAccess.READ)
	var meta: Dictionary = JSON.parse_string(f.get_as_text())
	var out := Vector2.ZERO
	for key in meta["frames"].keys():
		var b: Array = meta["frames"][key]["bbox"]
		out.x = maxf(out.x, float(b[2] - b[0]))
		out.y = maxf(out.y, float(b[3] - b[1]))
	return out


## 방에서 가장 높은 천장까지의 높이
func _headroom(id: String) -> float:
	var lay := RoomData.layout(id)
	return float(RoomData.floor_y(id)) - float(lay["ceiling_y"])


## Room._giant_spans() 와 같은 규칙 — 열을 훑어 천장이 충분한 연속 구간을 뽑고 몸 절반 폭만큼 들인다
func _spans(id: String) -> Array:
	var hs := RoomData.heights(id)
	var floor_y := float(RoomData.floor_y(id))
	var w := float(RoomData.room_width(id))
	var step := float(RoomTheme.CELL)
	var out: Array = []
	var run_lo := -1.0
	var c := step * 0.5
	while c < w:
		if floor_y - RoomTiles.ceiling_at(hs, c) >= Crawler.GIANT_CLEARANCE:
			if run_lo < 0.0:
				run_lo = c - step * 0.5
		elif run_lo >= 0.0:
			_append(out, run_lo, c - step * 0.5)
			run_lo = -1.0
		c += step
	if run_lo >= 0.0:
		_append(out, run_lo, w)
	return out


func _append(out: Array, lo: float, hi: float) -> void:
	var a := lo + Crawler.GIANT_HALF_W
	var b := hi - Crawler.GIANT_HALF_W
	if b > a:
		out.append(Vector2(a, b))


func _inside(spans: Array, x: float) -> bool:
	for sp in spans:
		if x >= sp.x and x <= sp.y:
			return true
	return false


func _fmt(spans: Array) -> String:
	if spans.is_empty():
		return "없음"
	var parts: Array = []
	for sp in spans:
		parts.append("%d~%d" % [int(sp.x), int(sp.y)])
	return ", ".join(parts)
