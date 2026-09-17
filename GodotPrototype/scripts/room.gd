class_name Room
extends Node2D
## RoomData 정의를 읽어 배경 타일·프랍·문·환경 연출(fx)을 조립하는 방 노드.
## 레이어 순서(뒤→앞): Background Tiles → Lamp Sprites/Windows/그을음/비상등 → Back-wall Doors → Floor Props(+웅덩이·파편)
##                     → Air(빛 기둥 · 비상등 팬 · 불꽃 · 연기 · 물줄기 · 전선 · 먼지) → (Character) → Front Effects
## 타일·문·프랍은 노멀맵이 붙은 CanvasTexture + lit_surface/prop_surface 셰이더로 그려 라이트에 입체·림으로 반응한다.

const LightMood := preload("res://scripts/light_mood.gd")

## 몬스터의 독액이 플레이어에 맞음 (Main 이 카메라 흔들림·밀림 처리)
signal player_hit(point: Vector2, dir: float)

var room_id: String
var width: int = 0
var floor_y: float = RoomData.FLOOR_Y
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
var monsters: Array = []      # Crawler
var player: Node2D            # Main 이 넣어준다 (전선 밀치기)

var _ambient: CanvasModulate
var _monster_layer: Node2D
var _props_layer: Node2D
var _stains: Array = []       # BloodStain (오래된 것부터 정리)
const MAX_STAINS := 48
var _spawn_cfg: Dictionary = SPAWN_DEFAULT
var _spawn_t := 0.0
var _lights: Node2D
var _tiles: Array = []        # [{sprite, rect, heat}] 벽 열 잔광용
var room_tiles: RoomTiles      # Workshop_Modular 터레인 타일맵 씬 (scenes/rooms/<id>.tscn, Godot 에디터에서 편집)
var _doors: Array = []        # [{sprite, rect, heat}]

const FRONT_DOOR_W := 315
const MONSTER_MARGIN := 150.0
## 지속 스폰 기본값 — RoomData 의 "spawn": {"max": 살아 있는 최대 수, "interval": [최소, 최대 초]} 로 방마다 덮어쓴다
const SPAWN_DEFAULT := {"max": 6, "interval": [1.8, 3.5]}
const SPAWN_MIN_PLAYER_DIST := 900.0    # 플레이어에서 이만큼 떨어진 곳(가능하면 화면 밖)에 나온다
const FRONT_DOOR_INTERACT_RANGE := 110.0


func build(id: String) -> void:
	room_id = id
	var data := RoomData.get_room(id)
	width = RoomData.room_width(id)
	floor_y = float(RoomData.floor_y(id))

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
	_ambient = dim
	var lights := Node2D.new()
	lights.name = "Lights"
	add_child(lights)
	_lights = lights
	if data.get("theme", "") == "power_relay":
		_build_power_relay_background(tiles)

	var x := 0
	for tile_name in data["tiles"]:
		var s := Sprite2D.new()
		s.centered = false
		s.texture = Lighting.textured(RoomData.TILE_DIR + tile_name + ".png")
		s.position = Vector2(x, 0)
		var tm := Lighting.lit_material()
		tm.set_shader_parameter("rim_ambient_strength", 0.0)      # 타일은 실루엣 림 없음(불투명), 노멀 림만
		tm.set_meta("rim_ambient_fixed", true)
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

	# 1b. 모듈러 타일맵 씬(Godot 터레인 오토타일) — 스트립 타일 위에 덧그린다. scenes/rooms/<id>.tscn 이 있을 때만.
	#     RoomTiles.hide_legacy_tiles 가 켜져 있으면 옛 560px 스트립을 숨기고 이 타일맵만 배경으로 쓴다.
	if RoomTiles.exists(id):
		room_tiles = load(RoomTiles.scene_path(id)).instantiate()
		room_tiles.apply_lit_material()
		tiles.add_child(room_tiles)
		set_legacy_tiles_visible(not room_tiles.hide_legacy_tiles)

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
		info["center"] = Vector2(fd["x"] + FRONT_DOOR_W * 0.5, floor_y)
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
	_props_layer = props
	if data.get("theme", "") == "power_relay":
		_build_power_relay_props(props, data)
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
	if data.get("theme", "") == "power_relay":
		_build_power_relay_lights(lights, data)
	for lamp in lamps:
		lamp.attach_cone(air, floor_y)

	var room_rect := RoomData.room_rect(id)            # 층고가 높은 방은 천장이 0 위로 올라간다
	var sources: Array = []
	for fx in data.get("fx", []):
		match fx["type"]:
			"beacon":
				var b := EmergencyLight.new()
				b.name = "Beacon"
				b.position = fx["pos"]
				lights.add_child(b)
				b.setup(air, room_rect, floor_y)
				beacons.append(b)
				sources.append(b)
			"leak":
				var wl := WaterLeak.new()
				wl.name = "Leak"
				wl.position = fx["pos"]
				air.add_child(wl)
				wl.setup(props, fx.get("dir", Vector2(0.3, 1.0)), floor_y, fx.get("pressure", 1.0))
				leaks.append(wl)
			"wire":
				var w := BrokenWire.new()
				w.name = "Wire"
				w.position = fx["pos"]
				air.add_child(w)
				w.setup(fx.get("length", 200.0), floor_y)
				wires.append(w)
				sources.append(w)
			"power_cable":
				var cable := PowerRelayCable.new()
				cable.name = "PowerRelayCable"
				cable.position = fx["pos"]
				air.add_child(cable)
				cable.setup(float(fx.get("length", 260.0)), floor_y)
				wires.append(cable)
				sources.append(cable)
			"fire":
				var f := FireSource.new()
				f.name = "Fire"
				f.position = fx["pos"]
				air.add_child(f)
				f.setup(air, lights, fx.get("size", Vector2(170.0, 210.0)))
				fires.append(f)
				sources.append(f)

	apply_mood(LightMood.index)

	# 6. 몬스터 — 캐릭터와 같은 층(z 5). 발 밑은 플레이어와 같은 바닥선, 좌우는 캡 타일 안쪽까지
	_monster_layer = Node2D.new()
	_monster_layer.name = "Monsters"
	_monster_layer.z_index = 5
	add_child(_monster_layer)
	for m in data.get("monsters", []):
		_add_crawler(float(m["x"]), int(m.get("facing", -1)))
	_spawn_cfg = data.get("spawn", SPAWN_DEFAULT)
	_spawn_t = _next_spawn_delay() * 0.5

	var dust := DustLayer.new()
	dust.name = "Dust"
	dust.setup(room_rect, lamps, sources)
	dust.z_index = 2
	air.add_child(dust)


func _build_power_relay_background(parent: Node2D) -> void:
	var bg_names := [
		"power_relay_bg_plain.png", "power_relay_bg_blocks.png", "power_relay_bg_channel.png",
		"power_relay_bg_vent.png", "power_relay_bg_repaired.png", "power_relay_bg_cracked.png",
	]
	for y in range(8):
		for x in range(14):
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture = Lighting.textured(RoomData.POWER_RELAY_DIR + "Tiles/Background/" + bg_names[(x + y * 2) % bg_names.size()])
			sprite.position = Vector2(x * 128, y * 128)
			var material := Lighting.lit_material()
			material.set_shader_parameter("rim_ambient_strength", 0.0)
			material.set_meta("rim_ambient_fixed", true)
			sprite.material = material
			parent.add_child(sprite)
			_tiles.append({"sprite": sprite, "rect": Rect2(sprite.position, Vector2(128, 128)), "heat": HeatSurface.new(material)})

	var frame_entries := [
		["power_relay_frame_top_left.png", Vector2i(0, 0)], ["power_relay_frame_top_right.png", Vector2i(13, 0)],
		["power_relay_frame_bottom_left.png", Vector2i(0, 7)], ["power_relay_frame_bottom_right.png", Vector2i(13, 7)],
	]
	for x in range(1, 13):
		frame_entries.append(["power_relay_frame_top.png", Vector2i(x, 0)])
		frame_entries.append(["power_relay_frame_bottom.png", Vector2i(x, 7)])
	for y in range(1, 7):
		frame_entries.append(["power_relay_frame_left.png", Vector2i(0, y)])
		frame_entries.append(["power_relay_frame_right.png", Vector2i(13, y)])
	for entry in frame_entries:
		var frame := Sprite2D.new()
		frame.centered = false
		frame.texture = Lighting.textured(RoomData.POWER_RELAY_DIR + "Tiles/Frame/" + String(entry[0]))
		frame.position = Vector2(entry[1]) * 128.0
		frame.material = Lighting.lit_material()
		frame.material.set_shader_parameter("rim_ambient_strength", 0.0)
		frame.material.set_meta("rim_ambient_fixed", true)
		parent.add_child(frame)


func _build_power_relay_props(parent: Node2D, data: Dictionary) -> void:
	for prop in data.get("power_relay_props", []):
		match prop.get("type", ""):
			"cabinet":
				_add_power_relay_shadow(parent, float(prop["x"]), 368.0)
				var cabinet := PowerRelayProp.new()
				cabinet.setup(float(prop["x"]), floor_y)
				parent.add_child(cabinet)
				props_hit.append(cabinet)
			"capacitor":
				var capacitor_tex := Lighting.textured(RoomData.POWER_RELAY_DIR + "Props/power_relay_capacitor_bank.png")
				var capacitor_shadow := _add_power_relay_shadow(parent, float(prop["x"]), float(capacitor_tex.get_width()))
				var capacitor := HitProp.new()
				capacitor.setup(capacitor_tex, Vector2(float(prop["x"]) - capacitor_tex.get_width() * 0.5, floor_y - capacitor_tex.get_height()), capacitor_shadow)
				parent.add_child(capacitor)
				props_hit.append(capacitor)
			"cart":
				var cart_tex := Lighting.textured(RoomData.POWER_RELAY_DIR + "Props/power_relay_maintenance_cart.png")
				var cart_shadow := _add_power_relay_shadow(parent, float(prop["x"]), float(cart_tex.get_width()))
				var cart := HitProp.new()
				cart.setup(cart_tex, Vector2(float(prop["x"]) - cart_tex.get_width() * 0.5, floor_y - cart_tex.get_height()), cart_shadow)
				parent.add_child(cart)
				props_hit.append(cart)
			"breaker":
				var breaker := Sprite2D.new()
				breaker.centered = false
				breaker.texture = Lighting.textured(RoomData.POWER_RELAY_DIR + "Props/power_relay_breaker_box.png")
				breaker.position = Vector2(float(prop["x"]), float(prop.get("y", 240.0)))
				breaker.material = Lighting.shader_material("prop_surface")
				parent.add_child(breaker)


func _add_power_relay_shadow(parent: Node2D, center_x: float, width: float) -> ColorRect:
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.38)
	shadow.position = Vector2(center_x - width * 0.5 + 18.0, floor_y - 2.0)
	shadow.size = Vector2(maxf(width - 36.0, 18.0), 10.0)
	parent.add_child(shadow)
	return shadow


func _build_power_relay_lights(parent: Node2D, data: Dictionary) -> void:
	for light_data in data.get("power_relay_lights", []):
		var fixture := Sprite2D.new()
		fixture.centered = true
		fixture.texture = Lighting.textured(RoomData.POWER_RELAY_DIR + String(light_data["file"]))
		fixture.position = light_data["pos"]
		fixture.material = Lighting.shader_material("prop_surface")
		parent.add_child(fixture)
		var point := PointLight2D.new()
		point.texture = Lighting.radial_texture()
		point.texture_scale = Lighting.scale_for_radius(float(light_data.get("radius", 200.0)))
		point.color = Color(1.0, 0.54, 0.25)
		point.energy = 1.0
		point.position = light_data["pos"]
		parent.add_child(point)


## 옛 가로 스트립 타일 표시/숨김 (모듈러 타일맵만 배경으로 쓸 때 숨긴다). 램프·창문 등 부속은 그대로 둔다.
func set_legacy_tiles_visible(v: bool) -> void:
	for t in _tiles:
		t["sprite"].visible = v


## 배경 라이팅 무드 프리셋 적용 (앰비언트 색 + 보조 광원)
func apply_mood(i: int) -> void:
	LightMood.apply(self, _lights, _ambient, i)


func _add_crawler(x: float, facing: int) -> Crawler:
	var c := Crawler.new()
	c.name = "Crawler"
	c.setup(self, x, floor_y + 2.0, MONSTER_MARGIN, width - MONSTER_MARGIN, facing)
	c.spat.connect(_on_monster_spat)
	_monster_layer.add_child(c)
	monsters.append(c)
	return c


func _next_spawn_delay() -> float:
	var iv: Array = _spawn_cfg.get("interval", SPAWN_DEFAULT["interval"])
	return randf_range(float(iv[0]), float(iv[1]))


func alive_monsters() -> int:
	var n := 0
	for m in monsters:
		if is_instance_valid(m) and not m.is_dead():
			n += 1
	return n


## 지속 스폰: 살아 있는 수가 max 미만이면 interval 마다 한 마리. 플레이어에서 먼 자리를 고른다(8회 시도, 없으면 먼 쪽 끝)
func _tick_spawner(delta: float) -> void:
	var cap := int(_spawn_cfg.get("max", 0))
	if cap <= 0 or player == null:
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = _next_spawn_delay()
	if alive_monsters() >= cap:
		return
	var lo := MONSTER_MARGIN
	var hi := width - MONSTER_MARGIN
	var x := 0.0
	var found := false
	for i in range(8):
		x = randf_range(lo, hi)
		if absf(x - player.position.x) >= SPAWN_MIN_PLAYER_DIST:
			found = true
			break
	if not found:
		x = lo if player.position.x > width * 0.5 else hi
	var c := _add_crawler(x, 1 if player.position.x >= x else -1)
	c.spawn_in()


func _process(_delta: float) -> void:
	# 죽어 사라진 몬스터 정리 + 지속 스폰
	monsters = monsters.filter(func(m): return is_instance_valid(m))
	_tick_spawner(_delta)
	# 플레이어가 전선을 지나가면 밀친다
	if player and not wires.is_empty():
		var vx: float = player.get("velocity_x") if player.get("velocity_x") != null else 0.0
		for w in wires:
			w.apply_body(player.position, vx)


func _on_monster_spat(glob: Node2D) -> void:
	_monster_layer.add_child(glob)


## 벽면 체액 자국 (프랍 층 — 타일·문 앞, 캐릭터 뒤). 너무 많이 쌓이면 오래된 것부터 지운다
func add_stain(pos: Vector2, dir: Vector2, amount: int, spread: float) -> void:
	_trim_stains()
	_stains.append(BloodStain.splat(_props_layer, pos, dir, amount, spread))


## 벽면 분사 자국 (덩어리가 순차적으로 찍히고 흘러내린다)
func add_spray(pos: Vector2, dir: Vector2, amount: int, length: float, fan: float) -> void:
	_trim_stains()
	_stains.append(BloodStain.spray(_props_layer, pos, dir, amount, length, fan))


func _trim_stains() -> void:
	_stains = _stains.filter(func(s): return is_instance_valid(s))
	while _stains.size() >= MAX_STAINS:
		var old: Node = _stains.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## 탄착점이 무엇을 맞췃는지. {"kind": "monster"|"lamp"|"beacon"|"glass"|"prop"|"wall"|"none", "node": ...}
## 몬스터가 맨 앞이라 먼저 본다. 죽은 몬스터·프랍의 부서진 구멍은 통과해 뒤의 벽이 맞는다.
func hit_at(point: Vector2) -> Dictionary:
	for m in monsters:
		if is_instance_valid(m) and m.is_hit(point):
			return {"kind": "monster", "node": m}
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
	# 옛 스트립 밖(층고가 높은 방의 위쪽 벽)이라도 모듈러 타일맵이 깔린 곳은 벽이다. 열 잔광은 없다(타일맵 UV 는 셀 단위).
	if room_tiles and _tilemap_rect().has_point(point):
		return {"kind": "wall", "node": {}}
	return {"kind": "none"}


## 모듈러 타일맵이 찍힌 영역(월드 px)
func _tilemap_rect() -> Rect2:
	var used: Rect2i
	var cell := Vector2(128, 128)
	var first := true
	for child in room_tiles.get_children():
		if child is TileMapLayer and child.tile_set:
			var r: Rect2i = child.get_used_rect()
			if r.size == Vector2i.ZERO:
				continue
			cell = Vector2(child.tile_set.tile_size)
			used = r if first else used.merge(r)
			first = false
	if first:
		return Rect2()
	return Rect2(room_tiles.position + Vector2(used.position) * cell, Vector2(used.size) * cell)


## 벽·문 표면에 열 잔광을 남긴다 (hit_at 이 돌려준 "wall" 항목). 타일맵 벽(빈 항목)은 잔광 없음.
func heat_wall(entry: Dictionary, point: Vector2) -> void:
	if not entry.has("heat"):
		return
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
	s.position = Vector2(center_x - w * 0.5, floor_y - s.texture.get_height())
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
	shadow.position = Vector2(pos.x + 18, floor_y - 2)
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
