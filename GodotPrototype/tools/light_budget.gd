extends SceneTree
## 청크별 라이트 예산 검사 (헤드리스).
## 실행:  godot --path . --headless --script res://tools/light_budget.gd -- [방id ...]
## 예산을 넘는 방이 하나라도 있으면 종료 코드 1.
##
## 왜 필요한가 — Godot 4 의 2D 렌더러는 **캔버스 아이템 하나가 받는 라이트를 15개까지만** 적용한다
## (MAX_LIGHTS_PER_ITEM). 넘치면 그 프레임 라이트 목록의 앞쪽 15개만 남고 나머지는 조용히 빠진다.
## 배경 타일맵은 rendering_quadrant_size(RoomTiles.QUADRANT) 단위로 캔버스 아이템이 쪼개지므로,
## 넘친 방에서는
##   · 청크 경계를 따라 조명이 칼같이 끊긴다 (갑자기 어두워지는 세로 띠)
##   · 총을 쏘면 총구·탄착 라이트가 목록에 끼어들어 순서가 바뀌며 램프가 번갈아 꺼졌다 켜진다
## 는 증상이 나온다. 그래서 방을 만들 때가 아니라 **청크 하나가 동시에 받는 수**를 세야 한다.
##
## 정적 광원은 CAP - COMBAT 이하로 유지한다 (전투 중 총구 화염·탄착·센트리건 섬광이 더 얹힌다).

const CAP := 15          # Godot 의 캔버스 아이템당 라이트 한도
const COMBAT := 4        # 전투 중 더해지는 라이트(총구 화염 · 탄착 2 · 센트리건 섬광) 여유분

var _frames := 0
var _ids: Array = []
var _i := 0
var _worst: Array = []
var _over := 0


func _initialize() -> void:
	_ids = OS.get_cmdline_user_args()
	if _ids.is_empty():
		_ids = RoomData.ROOMS.keys()
	AppFlow.start_room = _ids[0]
	change_scene_to_file(AppFlow.TEST_SCENE)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	var main := get_root().get_node_or_null("Main")
	if main == null:
		return true
	_report(main)
	_i += 1
	if _i >= _ids.size():
		_worst.sort_custom(func(a, b): return a[1] > b[1])
		print("\n=== 청크 최대 상위 10 ===")
		for w in _worst.slice(0, 10):
			print("  %-18s %2d  %s" % [w[0], w[1], w[2]])
		print("\n예산 초과 방: %d개 (한도 %d = 청크당 라이트 %d + 전투 여유 %d)" % [_over, CAP, CAP - COMBAT, COMBAT])
		quit(1 if _over > 0 else 0)
		return true
	main.call("_load_room", _ids[_i], 300.0, 1)
	_frames = 0
	return false


func _report(m: Node2D) -> void:
	var room = m.get("current_room")
	if room == null:
		return
	var lights: Array = []
	_collect(get_root(), lights)
	var tiles = room.get("room_tiles")
	var q := RoomTiles.QUADRANT
	var worst := 0
	var worst_names := ""
	for r in _chunk_rects(tiles, q):
		var names: Array = []
		for l in lights:
			if _affects(l, r, 0):
				names.append(_label(l))
		if names.size() > worst:
			worst = names.size()
			worst_names = _tally(names)
	if worst + COMBAT > CAP:
		_over += 1
	var flag := "  <<< 초과" if worst + COMBAT > CAP else ""
	print("%-18s 방 전체 %3d  청크 최대 %2d (+전투 %d = %2d)%s" % [room.room_id, lights.size(), worst, COMBAT, worst + COMBAT, flag])
	if worst + COMBAT > CAP:
		print("      %s" % worst_names)
	_worst.append([room.room_id, worst, worst_names])


## 타일맵이 캔버스 아이템으로 쪼개지는 단위(렌더 청크)의 월드 사각형들
func _chunk_rects(tiles, q: int) -> Array:
	var buckets := {}
	for c in tiles.cells.keys():
		var cell := Rect2(Vector2(c) * RoomTheme.CELL, Vector2(RoomTheme.CELL, RoomTheme.CELL))
		var key := Vector2i(floori(float(c.x) / q), floori(float(c.y) / q))
		buckets[key] = (buckets[key] as Rect2).merge(cell) if buckets.has(key) else cell
	var out: Array = []
	for key in buckets.keys():
		var r: Rect2 = buckets[key]
		r.position += tiles.global_position
		out.append(r)
	return out


func _tally(names: Array) -> String:
	var t := {}
	for n in names:
		t[n] = int(t.get(n, 0)) + 1
	var parts: Array = []
	for k in t.keys():
		parts.append("%s x%d" % [k, t[k]])
	return "  ".join(parts)


func _label(l: PointLight2D) -> String:
	if l is LampLight:
		return "Lamp"
	if not l.name.begins_with("@"):
		return l.name
	var p := l.get_parent()
	if p.name == "Mood":
		return "MoodFill" if l.position.y < 0.0 else "MoodFloor"
	return p.name


func _collect(n: Node, out: Array) -> void:
	if n is PointLight2D and n.enabled and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


## Godot 의 컬링과 같은 판정: z 범위 · 아이템 마스크 · 변환된 라이트 사각형과 아이템 사각형의 교차.
## 원이 아니라 **사각형** 으로 판정하므로 빛이 거의 닿지 않는 구석도 한 자리를 차지한다.
func _affects(l: PointLight2D, item: Rect2, z: int) -> bool:
	if z < l.range_z_min or z > l.range_z_max:
		return false
	if (l.range_item_cull_mask & 1) == 0:
		return false
	if l.texture == null:
		return false
	var size: Vector2 = l.texture.get_size() * l.texture_scale
	return (l.get_global_transform() * Rect2(l.offset - size * 0.5, size)).intersects(item)
