class_name Room
extends Node2D
## RoomData 정의를 읽어 모듈러 타일맵(테마 × 열 프로필)·램프·조명 기구·프랍·문·환경 연출(fx)을 조립하는 방 노드.
## 레이어 순서(뒤→앞): Tiles(타일맵) → Lights(램프 스프라이트·기구·그을음·비상등) → Back-wall Doors → Floor Props(+웅덩이·파편)
##                     → Air(빛 기둥 · 비상등 팬 · 불꽃 · 연기 · 물줄기 · 전선 · 먼지) → (Character) → Water(고인 물, 반사) → Front Effects
## 문·프랍은 노멀맵이 붙은 CanvasTexture + lit_surface/prop_surface 셰이더로 그려 라이트에 입체·림으로 반응한다.

const LightMood := preload("res://scripts/light_mood.gd")

## 몬스터의 독액이 플레이어에 맞음 (Main 이 카메라 흔들림·밀림 처리)
signal player_hit(point: Vector2, dir: float)
signal monster_roared(pos: Vector2)

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
var windows: Array = []       # GlassWindow (현재 타일맵 방에는 창문 타일이 없어 비어 있다)
var beacons: Array = []       # EmergencyLight
var wires: Array = []         # BrokenWire
var leaks: Array = []         # WaterLeak
var fires: Array = []         # FireSource
var water: WaterPool          # 고인 물 (fx "water", 방마다 최대 하나)
var foreground: ForegroundLayer   # 근경 실루엣 층 (DepthPreset "근경 분리" 일 때만)
var monsters: Array = []      # Crawler
var player: Node2D            # Main 이 넣어준다 (전선 밀치기)
var room_tiles: RoomTiles     # 테마 타일맵 (RoomTiles.build — 실행 중 생성)
var heights: Array = []       # 열별 높이(셀)

var _ambient: CanvasModulate
var _monster_layer: Node2D
var _props_layer: Node2D
var _stains: Array = []       # BloodStain (오래된 것부터 정리)
const MAX_STAINS := 48
var _spawn_cfg: Dictionary = SPAWN_DEFAULT
var _spawn_t := 0.0
var _lights: Node2D
var _doors: Array = []        # [{sprite, rect, heat}]

const MONSTER_MARGIN := 150.0
## 지속 스폰 기본값 — RoomData 의 "spawn": {"max": 살아 있는 최대 수, "interval": [최소, 최대 초]} 로 방마다 덮어쓴다
const SPAWN_DEFAULT := {"max": 6, "interval": [1.8, 3.5]}
const SPAWN_MIN_PLAYER_DIST := 900.0    # 플레이어에서 이만큼 떨어진 곳(가능하면 화면 밖)에 나온다
const FRONT_DOOR_INTERACT_RANGE := 110.0
const FRONT_DOOR_LIFT := 306.0          # 정면문 스프라이트 상단 = 바닥선 − 306 (문 하단 여백 포함)
const PENDANT_TEX := RoomData.LIGHTS_DIR + "pendant_lamp.png"
const PENDANT_META := RoomData.LIGHTS_DIR + "pendant_lamp.json"
const FIXTURE_COLOR := Color(1.0, 0.9, 0.75)
const PROP_SINK := 2.0                  # 프랍 다리가 바닥선을 살짝 침범하는 px

static var _ground_cache := {}          # 텍스처 경로 → 하단 투명 여백 px


func build(id: String) -> void:
	room_id = id
	var data := RoomData.get_room(id)
	heights = RoomData.heights(id)
	width = RoomData.room_width(id)
	floor_y = float(RoomData.floor_y(id))

	# 1. 테마 타일맵 — 열 프로필로 실루엣을 찍는다 (배경 무늬는 방 id 시드로 고정)
	var tiles := Node2D.new()
	tiles.name = "Tiles"
	tiles.z_index = 0
	add_child(tiles)
	room_tiles = RoomTiles.new()
	room_tiles.name = "RoomTiles"
	room_tiles.build(data["theme"], heights, id)
	room_tiles.apply_lit_material()
	tiles.add_child(room_tiles)
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

	# 1b. 천장 펜던트 램프(깨지는 램프) + 장식 조명 기구
	for lx in data.get("lamps", []):
		_add_pendant_lamp(lights, float(lx))
	_build_fixtures(lights, data)

	# 2. 뒷벽 정면문
	var doors := Node2D.new()
	doors.name = "BackWallDoors"
	doors.z_index = 1
	add_child(doors)
	for fd in data["front_doors"]:
		var s := Sprite2D.new()
		s.centered = false
		s.texture = Lighting.textured(RoomData.FRONT_DOOR_TEX)
		s.position = Vector2(fd["x"], floor_y - FRONT_DOOR_LIFT)
		var dm := Lighting.lit_material()
		s.material = dm
		doors.add_child(s)
		_doors.append({"sprite": s, "rect": Rect2(s.position, s.texture.get_size()), "heat": HeatSurface.new(dm)})
		var info: Dictionary = fd.duplicate()
		info["center"] = Vector2(fd["x"] + RoomData.FRONT_DOOR_W * 0.5, floor_y)
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

	# 4. 프랍 — 바닥 프랍(HitProp, 접지 자동)·벽걸이·전력실 전용
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = 2
	add_child(props)
	_props_layer = props
	for p in data.get("props", []):
		_add_prop(props, p)

	# 5. 공기층: 볼류메트릭 빛 기둥 + 환경 연출 + 부유 먼지 — 프랍 앞, 캐릭터 뒤
	var air := Node2D.new()
	air.name = "Air"
	air.z_index = 4
	add_child(air)
	for lamp in lamps:
		lamp.attach_cone(air, floor_y)

	var room_rect := RoomData.room_rect(id)            # 층고가 높은 방은 천장이 0 위로 올라간다
	var sources: Array = []
	for fx in data.get("fx", []):
		var pos := _fx_pos(fx)
		match fx["type"]:
			"beacon":
				var b := EmergencyLight.new()
				b.name = "Beacon"
				b.position = pos
				lights.add_child(b)
				b.setup(air, room_rect, floor_y)
				beacons.append(b)
				sources.append(b)
			"leak":
				var wl := WaterLeak.new()
				wl.name = "Leak"
				wl.position = pos
				air.add_child(wl)
				wl.setup(props, fx.get("dir", Vector2(0.3, 1.0)), floor_y, fx.get("pressure", 1.0))
				leaks.append(wl)
			"wire":
				var w := BrokenWire.new()
				w.name = "Wire"
				w.position = pos
				air.add_child(w)
				w.setup(fx.get("length", 200.0), floor_y)
				wires.append(w)
				sources.append(w)
			"power_cable":
				var cable := PowerRelayCable.new()
				cable.name = "PowerRelayCable"
				cable.position = pos
				air.add_child(cable)
				cable.setup(float(fx.get("length", 260.0)), floor_y)
				wires.append(cable)
				sources.append(cable)
			"water":
				# 고인 물: 인물(z5)·몬스터가 반사에 들어가야 하므로 인물 층 위(z6, 탄과 같은 층)
				var wp := WaterPool.new()
				wp.name = "Water"
				wp.z_index = DepthPreset.Z_ACTOR_MAX
				add_child(wp)
				wp.setup(fx, float(width), floor_y, float(room_rect.end.y))
				water = wp
			"fire":
				var f := FireSource.new()
				f.name = "Fire"
				f.position = pos
				air.add_child(f)
				f.setup(air, lights, fx.get("size", Vector2(170.0, 210.0)))
				fires.append(f)
				sources.append(f)

	# 물이 있으면 수도관 물줄기는 바닥 대신 수면에 떨어져 잔물결을 남긴다
	if water:
		for wl in leaks:
			wl.water = water

	apply_mood(LightMood.index)

	# 6. 몬스터 — 캐릭터와 같은 층(z 5). 발 밑은 플레이어와 같은 바닥선, 좌우는 벽 띠 안쪽까지
	_monster_layer = Node2D.new()
	_monster_layer.name = "Monsters"
	_monster_layer.z_index = 5
	add_child(_monster_layer)
	for m in data.get("monsters", []):
		_add_crawler(float(m["x"]), int(m.get("facing", -1)))
	_spawn_cfg = data.get("spawn", SPAWN_DEFAULT)
	_spawn_t = _next_spawn_delay() * 0.5

	# 부유 먼지. 근경 분리: 프랍 앞·빛 기둥 뒤(z3) 로 내려 벽과 인물 사이의 "공기" 가 된다.
	# 이전(평면): air 기준 +2 = z6 로 플레이어·몬스터까지 덮었다 (비교용으로 남김).
	var dust := DustLayer.new()
	dust.name = "Dust"
	dust.setup(room_rect, lamps, sources)
	dust.z_index = -1 if DepthPreset.enabled() else 2
	air.add_child(dust)

	# 7. 근경 실루엣 층 (z7) — 조명 제외, 카메라 1.12배 패럴랙스. 램프·정면문 자리는 기둥·케이블이 피한다.
	if DepthPreset.enabled():
		var avoid: Array = []
		for lamp in lamps:
			avoid.append(lamp.position.x)
		for fd in front_doors:
			avoid.append(fd["center"].x)
		foreground = ForegroundLayer.new()
		foreground.name = "Foreground"
		foreground.z_index = DepthPreset.Z_FOREGROUND
		add_child(foreground)
		var cols: Array = []
		for c in range(heights.size()):
			cols.append(ceiling_at(c * RoomTheme.CELL + RoomTheme.CELL * 0.5))
		foreground.build(id, float(width), floor_y, room_rect.position.y, avoid, cols, room_rect.end.y)


## 근경 랩용: 몬스터를 모두 치우고 스폰을 멈춘다
func disable_monsters() -> void:
	_spawn_cfg = {"max": 0, "interval": [9999.0, 9999.0]}
	for m in monsters:
		if is_instance_valid(m):
			m.queue_free()
	monsters.clear()


## x 열의 천장 타일 상단 y
func ceiling_at(x: float) -> float:
	return RoomTiles.ceiling_at(heights, x)


## 데이터 항목의 위치: "pos" 그대로, 아니면 x 와 cy(천장 기준 아래로) / fy(바닥선 기준 위로), 둘 다 없으면 바닥선.
func _fx_pos(d: Dictionary) -> Vector2:
	if d.has("pos"):
		return d["pos"]
	var x := float(d.get("x", 0.0))
	if d.has("cy"):
		return Vector2(x, ceiling_at(x) + float(d["cy"]))
	if d.has("fy"):
		return Vector2(x, floor_y - float(d["fy"]))
	return Vector2(x, floor_y)


## 천장 펜던트 램프 — 스프라이트(발광·글리치)·라이트·전구 커버. 그 열의 천장 띠 아랫선에 매단다.
func _add_pendant_lamp(parent: Node2D, x: float) -> void:
	var tex: Texture2D = load(PENDANT_TEX)
	var meta := _pendant_meta()
	var bulb: Array = meta.get("bulb", [40, 96, 24, 12])
	var size := tex.get_size()
	var origin := Vector2(round(x - size.x * 0.5), ceiling_at(x) + RoomTiles.CEILING_BAND - 2.0)
	var bulb_local := Rect2(float(bulb[0]), float(bulb[1]), float(bulb[2]), float(bulb[3]))
	var lamp := LampLight.new()
	lamp.position = origin + bulb_local.get_center()
	parent.add_child(lamp)
	lamp.attach_cover(parent, Rect2(origin + bulb_local.position, bulb_local.size))
	lamp.attach_sprite(parent, tex, origin, Rect2(Vector2.ZERO, size), bulb_local)
	lamps.append(lamp)


static var _pendant_meta_cache := {}
static func _pendant_meta() -> Dictionary:
	if _pendant_meta_cache.is_empty():
		var f := FileAccess.open(PENDANT_META, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_pendant_meta_cache = parsed
		if _pendant_meta_cache.is_empty():
			_pendant_meta_cache = {"bulb": [40, 96, 24, 12]}
	return _pendant_meta_cache


## 장식 조명 기구 (power_relay Lighting 스프라이트 + PointLight2D). 총으로는 깨지지 않는다.
func _build_fixtures(parent: Node2D, data: Dictionary) -> void:
	for fd in data.get("fixtures", []):
		var pos := _fx_pos(fd)
		var fixture := Sprite2D.new()
		fixture.centered = true
		fixture.texture = Lighting.textured(RoomData.POWER_RELAY_DIR + "Lighting/power_relay_%s.png" % fd["file"])
		fixture.position = pos
		fixture.material = Lighting.shader_material("prop_surface")
		parent.add_child(fixture)
		var point := PointLight2D.new()
		point.texture = Lighting.radial_texture()
		point.texture_scale = Lighting.scale_for_radius(float(fd.get("radius", 200.0)))
		point.color = fd.get("color", FIXTURE_COLOR)
		point.energy = 1.0
		point.height = Lighting.LAMP_HEIGHT
		point.position = pos
		parent.add_child(point)
		Lighting.split_by_depth(point)


## 프랍 하나. {"tex", "x"} 바닥 프랍(접지 자동) · {"tex", "x", "cy"|"fy"} 벽걸이 · {"type": 전력실 전용}
func _add_prop(parent: Node2D, p: Dictionary) -> void:
	if p.has("type"):
		_add_special_prop(parent, p)
		return
	var path := _prop_path(p["tex"])
	var tex := Lighting.textured(path)
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	if p.has("cy") or p.has("fy"):
		# 벽걸이: 조명·피격 반응 없는 표면 스프라이트
		var s := Sprite2D.new()
		s.centered = false
		s.texture = tex
		s.position = _fx_pos(p) - Vector2(w * 0.5, 0.0)
		s.material = Lighting.shader_material("prop_surface")
		parent.add_child(s)
		return
	var top_left: Vector2
	if p.has("pos"):
		top_left = p["pos"]
	else:
		top_left = Vector2(round(float(p["x"]) - w * 0.5), floor_y + PROP_SINK - (h - _ground_margin(path)))
	var shadow := _add_contact_shadow(parent, top_left.x, w)
	var hp := HitProp.new()
	hp.setup(tex, top_left, shadow)
	parent.add_child(hp)
	props_hit.append(hp)


static func _prop_path(tex: String) -> String:
	if tex.begins_with("res://"):
		return tex
	return RoomData.PROP_DIR + tex + ".png"


## 텍스처 하단의 투명 여백(px) — 실제 픽셀이 바닥선에 닿게 프랍을 내리는 데 쓴다
static func _ground_margin(path: String) -> int:
	if _ground_cache.has(path):
		return _ground_cache[path]
	var margin := 0
	var tex: Texture2D = load(path)
	var img: Image = tex.get_image() if tex else null
	if img:
		var w := img.get_width()
		var y := img.get_height() - 1
		while y >= 0:
			var opaque := false
			for x in range(w):
				if img.get_pixel(x, y).a >= 0.5:
					opaque = true
					break
			if opaque:
				break
			margin += 1
			y -= 1
	_ground_cache[path] = margin
	return margin


## 전력 릴레이실 전용 프랍: cabinet(파츠 파괴 PowerRelayProp) · capacitor · cart · breaker(벽걸이)
func _add_special_prop(parent: Node2D, prop: Dictionary) -> void:
	var x := float(prop["x"])
	match prop.get("type", ""):
		"cabinet":
			_add_contact_shadow(parent, x - 368.0 * 0.5, 368.0)
			var cabinet := PowerRelayProp.new()
			cabinet.setup(x, floor_y)
			parent.add_child(cabinet)
			props_hit.append(cabinet)
		"capacitor", "cart":
			var file := "power_relay_capacitor_bank.png" if prop["type"] == "capacitor" else "power_relay_maintenance_cart.png"
			var path := RoomData.POWER_RELAY_DIR + "Props/" + file
			var tex := Lighting.textured(path)
			var w := float(tex.get_width())
			var top_left := Vector2(round(x - w * 0.5), floor_y + PROP_SINK - (tex.get_height() - _ground_margin(path)))
			var shadow := _add_contact_shadow(parent, top_left.x, w)
			var hp := HitProp.new()
			hp.setup(tex, top_left, shadow)
			parent.add_child(hp)
			props_hit.append(hp)
		"breaker":
			var breaker := Sprite2D.new()
			breaker.centered = false
			breaker.texture = Lighting.textured(RoomData.POWER_RELAY_DIR + "Props/power_relay_breaker_box.png")
			var d := prop.duplicate()
			if not d.has("cy") and not d.has("fy"):
				d["fy"] = 330.0
			breaker.position = _fx_pos(d) - Vector2(breaker.texture.get_width() * 0.5, 0.0)
			breaker.material = Lighting.shader_material("prop_surface")
			parent.add_child(breaker)


## 프랍 아래 짧고 단단한 사각 픽셀 접촉 그림자 (GameReady 노트 권장)
func _add_contact_shadow(parent: Node2D, left_x: float, w: float) -> ColorRect:
	var shadow := ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.35)
	shadow.position = Vector2(left_x + 18.0, floor_y - 2.0)
	shadow.size = Vector2(maxf(w - 36.0, 18.0), 10.0)
	parent.add_child(shadow)
	return shadow


## 배경 라이팅 무드 프리셋 적용 (앰비언트 색 + 보조 광원)
func apply_mood(i: int) -> void:
	LightMood.apply(self, _lights, _ambient, i)


func _add_crawler(x: float, facing: int) -> Crawler:
	var c := Crawler.new()
	c.name = "Crawler"
	c.setup(self, x, floor_y + 2.0, MONSTER_MARGIN, width - MONSTER_MARGIN, facing)
	c.spat.connect(_on_monster_spat)
	c.roared.connect(monster_roared.emit)
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
	# 플레이어가 물속을 걸으면 발 주위 수면이 술렁인다
	if player and water:
		var wvx: float = player.get("velocity_x") if player.get("velocity_x") != null else 0.0
		water.wake(player.position.x, wvx, _delta)


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
	# 타일맵이 찍힌 셀(벽·천장·바닥)은 벽. 열 잔광은 없다(타일맵 UV 는 셀 단위).
	if room_tiles and room_tiles.is_wall_at(point):
		return {"kind": "wall", "node": {}}
	return {"kind": "none"}


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


## 플레이어가 상호작용 가능한 정면문 반환(없으면 빈 Dictionary)
func front_door_near(px: float) -> Dictionary:
	for fd in front_doors:
		if absf(fd["center"].x - px) <= FRONT_DOOR_INTERACT_RANGE:
			return fd
	return {}
