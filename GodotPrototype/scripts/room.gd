class_name Room
extends Node2D
## RoomData 정의를 읽어 배경 타일·프랍·문·환경 연출(fx)을 조립하는 방 노드.
## 레이어 순서(뒤→앞): Background Tiles → Lamp Sprites/Windows/그을음/비상등 → Back-wall Doors → Floor Props(+웅덩이·파편)
##                     → Air(빛 기둥 · 비상등 팬 · 불꽃 · 연기 · 물줄기 · 전선 · 먼지) → (Character) → Front Effects
## 타일·문·프랍은 노멀맵이 붙은 CanvasTexture + lit_surface/prop_surface 셰이더로 그려 라이트에 입체·림으로 반응한다.

var room_id: String
var width: int = 0
var front_doors: Array = []   # [{"x", "target", "target_door", "center": Vector2}]
var left_door_open := false
var right_door_open := false
var left_target := ""
var right_target := ""
var lamps: Array = []         # LampLight
var props_hit: Array = []     # HitProp
var windows: Array = []       # GlassWindow
var beacons: Array = []       # EmergencyLight
var wires: Array = []         # BrokenWire
var leaks: Array = []         # WaterLeak
var fires: Array = []         # FireSource
var player: Node2D            # Main 이 넣어준다 (전선 밀치기)

var _tiles: Array = []        # [{sprite, rect, heat}] 벽 열 잔광용
var _doors: Array = []        # [{sprite, rect, heat}]

const FRONT_DOOR_W := 315
const FRONT_DOOR_INTERACT_RANGE := 110.0


func build(id: String) -> void:
	room_id = id
	var data := RoomData.get_room(id)
	width = RoomData.room_width(id)

	# 1. 배경 타일 — Bottom Left 피벗, 같은 Y, 간격 없이 X 누적
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	tiles.z_index = 0
	add_child(tiles)
	# 어둡게 깔고 램프 라이트가 비추게 한다
	var dim := CanvasModulate.new()
	dim.name = "Ambient"
	dim.color = Lighting.AMBIENT
	add_child(dim)
	var lights := Node2D.new()
	lights.name = "Lights"
	add_child(lights)

	var x := 0
	for tile_name in data["tiles"]:
		var s := Sprite2D.new()
		s.centered = false
		s.texture = Lighting.textured(RoomData.TILE_DIR + tile_name + ".png")
		s.position = Vector2(x, 0)
		var tm := Lighting.lit_material()
		tm.set_shader_parameter("rim_ambient_strength", 0.0)      # 타일은 실루엣 림 없음(불투명), 노멀 림만
		s.material = tm
		tiles.add_child(s)
		_tiles.append({"sprite": s, "rect": Rect2(s.position, s.texture.get_size()), "heat": HeatSurface.new(tm)})
		var origin := Vector2(x, 0)
		for lp in RoomData.TILE_LAMPS.get(tile_name, []):
			var lamp := LampLight.new()
			lamp.position = origin + lp["pos"]
			lights.add_child(lamp)
			var bulb: Rect2 = lp["bulb"]
			lamp.attach_cover(lights, Rect2(origin + bulb.position, bulb.size))
			lamp.attach_sprite(lights, s.texture, origin, lp["sprite"], bulb)
			lamps.append(lamp)
		for wr in RoomData.TILE_WINDOWS.get(tile_name, []):
			var win := GlassWindow.new()
			win.setup(s.texture, origin, wr)
			lights.add_child(win)
			windows.append(win)
		x += RoomData.tile_width(tile_name)

	# 2. 뒷벽 정면문
	var doors := Node2D.new()
	doors.name = "BackWallDoors"
	doors.z_index = 1
	add_child(doors)
	for fd in data["front_doors"]:
		var s := Sprite2D.new()
		s.centered = false
		s.texture = Lighting.textured(RoomData.FRONT_DOOR_TEX)
		s.position = Vector2(fd["x"], 180)
		var dm := Lighting.lit_material()
		s.material = dm
		doors.add_child(s)
		_doors.append({"sprite": s, "rect": Rect2(s.position, s.texture.get_size()), "heat": HeatSurface.new(dm)})
		var info: Dictionary = fd.duplicate()
		info["center"] = Vector2(fd["x"] + FRONT_DOOR_W * 0.5, RoomData.FLOOR_Y)
		front_doors.append(info)

	# 3. 측벽문 — 방 좌우 끝 중심에 배치. 왼쪽은 X 뒤집기.
	var ld: Dictionary = data["left_door"]
	var rd: Dictionary = data["right_door"]
	left_door_open = ld.get("open", false)
	right_door_open = rd.get("open", false)
	left_target = ld.get("target", "")
	right_target = rd.get("target", "")
	_add_side_door(doors, 0, left_door_open, true)
	_add_side_door(doors, width, right_door_open, false)

	# 4. 바닥 프랍 — top-left 좌표 그대로(JSON 검증값에 접지 침범 포함)
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = 2
	add_child(props)
	for p in data["props"]:
		var shadow := _add_contact_shadow(props, p)
		var s := HitProp.new()
		s.setup(Lighting.textured(RoomData.PROP_DIR + p["tex"] + ".png"), p["pos"], shadow)
		props.add_child(s)
		props_hit.append(s)

	# 5. 공기층: 볼류메트릭 빛 기둥 + 환경 연출 + 부유 먼지 — 프랍 앞, 캐릭터 뒤
	var air := Node2D.new()
	air.name = "Air"
	air.z_index = 4
	add_child(air)
	for lamp in lamps:
		lamp.attach_cone(air, RoomData.FLOOR_Y)

	var room_rect := Rect2(0, 0, width, RoomData.TILE_HEIGHT)
	var sources: Array = []
	for fx in data.get("fx", []):
		match fx["type"]:
			"beacon":
				var b := EmergencyLight.new()
				b.name = "Beacon"
				b.position = fx["pos"]
				lights.add_child(b)
				b.setup(air, room_rect, RoomData.FLOOR_Y)
				beacons.append(b)
				sources.append(b)
			"leak":
				var wl := WaterLeak.new()
				wl.name = "Leak"
				wl.position = fx["pos"]
				air.add_child(wl)
				wl.setup(props, fx.get("dir", Vector2(0.3, 1.0)), RoomData.FLOOR_Y, fx.get("pressure", 1.0))
				leaks.append(wl)
			"wire":
				var w := BrokenWire.new()
				w.name = "Wire"
				w.position = fx["pos"]
				air.add_child(w)
				w.setup(fx.get("length", 200.0), RoomData.FLOOR_Y)
				wires.append(w)
				sources.append(w)
			"fire":
				var f := FireSource.new()
				f.name = "Fire"
				f.position = fx["pos"]
				air.add_child(f)
				f.setup(air, lights, fx.get("size", Vector2(170.0, 210.0)))
				fires.append(f)
				sources.append(f)

	var dust := DustLayer.new()
	dust.name = "Dust"
	dust.setup(float(width), float(RoomData.TILE_HEIGHT), lamps, sources)
	dust.z_index = 2
	air.add_child(dust)


func _process(_delta: float) -> void:
	# 플레이어가 전선을 지나가면 밀친다
	if player and not wires.is_empty():
		var vx: float = player.get("velocity_x") if player.get("velocity_x") != null else 0.0
		for w in wires:
			w.apply_body(player.position, vx)


## 탄착점이 무엇을 맞췃는지. {"kind": "lamp"|"beacon"|"glass"|"prop"|"wall"|"none", "node": ...}
## 프랍의 부서진 구멍은 통과해 뒤의 벽이 맞는다.
func hit_at(point: Vector2) -> Dictionary:
	for lamp in lamps:
		if lamp.is_hit(point):
			return {"kind": "lamp", "node": lamp}
	for b in beacons:
		if b.is_hit(point):
			return {"kind": "beacon", "node": b}
	for win in windows:
		if win.is_hit(point):
			return {"kind": "glass", "node": win}
	for pr in props_hit:
		if pr.is_solid_at(point):
			return {"kind": "prop", "node": pr}
	for d in _doors:
		if d["rect"].has_point(point):
			return {"kind": "wall", "node": d}
	for t in _tiles:
		if t["rect"].has_point(point):
			return {"kind": "wall", "node": t}
	return {"kind": "none"}


## 벽·문 표면에 열 잔광을 남긴다 (hit_at 이 돌려준 "wall" 항목)
func heat_wall(entry: Dictionary, point: Vector2) -> void:
	var r: Rect2 = entry["rect"]
	var uv := ((point - r.position) / r.size).clamp(Vector2.ZERO, Vector2.ONE)
	var s: Sprite2D = entry["sprite"]
	if s.flip_h:
		uv.x = 1.0 - uv.x
	entry["heat"].add_hit(uv, 1.0)


## 사격 한 발이 방에 미치는 물리 영향 (전선 튕김 등)
func notify_shot(from: Vector2, to: Vector2) -> void:
	for w in wires:
		w.apply_shot(from, to)


func _add_side_door(parent: Node2D, center_x: float, is_open: bool, flip: bool) -> void:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = Lighting.textured(RoomData.SIDE_DOOR_OPEN_TEX if is_open else RoomData.SIDE_DOOR_CLOSED_TEX)
	var w := s.texture.get_width()
	s.position = Vector2(center_x - w * 0.5, 14)
	s.flip_h = flip
	var dm := Lighting.lit_material()
	s.material = dm
	parent.add_child(s)
	_doors.append({"sprite": s, "rect": Rect2(s.position, s.texture.get_size()), "heat": HeatSurface.new(dm)})


## 프랍 아래 짧고 단단한 사각 픽셀 접촉 그림자 (GameReady 노트 권장)
func _add_contact_shadow(parent: Node2D, p: Dictionary) -> ColorRect:
	var tex: Texture2D = load(RoomData.PROP_DIR + p["tex"] + ".png")
	var pos: Vector2 = p["pos"]
	var w := tex.get_width()
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.position = Vector2(pos.x + 18, RoomData.FLOOR_Y - 2)
	shadow.size = Vector2(w - 36, 10)
	parent.add_child(shadow)
	return shadow


## 플레이어가 상호작용 가능한 정면문 반환(없으면 빈 Dictionary)
func front_door_near(px: float) -> Dictionary:
	for fd in front_doors:
		if absf(fd["center"].x - px) <= FRONT_DOOR_INTERACT_RANGE:
			return fd
	return {}


func front_door_spawn_x(index: int) -> float:
	if index >= 0 and index < front_doors.size():
		return front_doors[index]["center"].x
	return width * 0.5
