class_name Room
extends Node2D
## RoomData 정의를 읽어 모듈러 타일맵(테마 × 열 프로필)·램프·조명 기구·프랍·문·환경 연출(fx)을 조립하는 방 노드.
## 레이어 순서(뒤→앞): Tiles(타일맵) → Lights(램프 스프라이트·기구·그을음·비상등) → Back-wall Doors → Floor Props(+웅덩이·파편)
##                     → Air(빛 기둥 · 비상등 팬 · 불꽃 · 연기 · 물줄기 · 전선 · 먼지) → (Character) → Water(고인 물, 반사) → Front Effects
##                     → WallShadow(벽 바깥 어둠, 모든 층 위)
## 벽은 RoomSolid(열 프로필에서 뽑은 충돌 기하)로 실제로 막혀 있다 — 탄·파편·독액이 벽 너머 어둠으로 넘어가지 못한다.
## 문·프랍은 노멀맵이 붙은 CanvasTexture + lit_surface/prop_surface 셰이더로 그려 라이트에 입체·림으로 반응한다.

const LightMood := preload("res://scripts/light_mood.gd")
const PropShadow := preload("res://scripts/prop_shadow.gd")
const GalleryPlaytest := preload("res://scripts/service_gallery_playtest.gd")

## 몬스터의 독액이 플레이어에 맞음 (Main 이 카메라 흔들림·밀림 처리)
signal player_hit(point: Vector2, dir: float)
## power: 운 개체의 덩치 배율 (일반 1.0 · 거대종 Crawler.GIANT_SIZE)
signal monster_roared(pos: Vector2, power: float)
## 거대종이 바닥을 내려찍었다 (Main 이 카메라를 크게 울린다)
signal monster_slammed(pos: Vector2)
signal wave_started(index: int, count: int)   # 웨이브 스폰이 한 무리를 내보내기 시작했다

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
var foreground: ForegroundLayer   # 근경 실루엣 층 (z7)
var monsters: Array = []      # Crawler
var sentries: Array = []
var walkers: Array = []          # 사족보행 기체(WalkerUnit). 센트리건과 같은 규칙으로 산다      # SentryTurret (바닥 격납형 센트리건 — Main 이 조종을 잡는다)
var terminals: Array = []     # AccessTerminal (플레이어가 W/↑ 로 접속하는 대형 단말기)
var npcs: Array = []          # Npc (플레이어가 W/↑ 로 말을 거는 생존자)
var player: Node2D            # Main 이 넣어준다 (전선 밀치기)
var prop_shadows: Node2D      # 프랍 그림자 층 (PropShadow — 프랍 레이어 맨 뒤)
var room_tiles: RoomTiles     # 테마 타일맵 (RoomTiles.build — 실행 중 생성)
var solid: RoomSolid          # 벽 충돌 기하 (사격 클리핑 · 자유 물체 가두기)
var wall_shadow: WallShadow   # 벽 바깥 어둠 층 (맵 뷰어의 "전체 밝게" 에서 끈다)
var heights: Array = []       # 열별 높이(셀)

var _ambient: CanvasModulate
var _monster_layer: Node2D
var _npc_layer: Node2D
var _props_layer: Node2D
var _stains: Array = []       # BloodStain (오래된 것부터 정리)
const MAX_STAINS := 120
var _spawn_cfg: Dictionary = SPAWN_DEFAULT
var _spawn_t := 0.0
## 웨이브 스폰 상태 ("spawn": {"wave": {"interval": 초, "size": [최소, 최대], "gap": 마리 사이 초, "first": 첫 웨이브까지 초}})
var wave_index := 0           # 지금까지 나온 웨이브 수 (HUD)
var _wave_t := 0.0            # 다음 웨이브까지 남은 초
var _wave_left := 0           # 이번 웨이브에서 아직 안 나온 마리
var _wave_gap := 0.0
var _lights: Node2D
var _doors: Array = []        # [{sprite, rect, heat}]

const MONSTER_MARGIN := 150.0
## 한 방이 동시에 살려 둘 수 있는 몬스터 수의 **엔진 상한**. 방 데이터의 spawn.max 가 이보다 커도 여기서 잘린다.
const MONSTER_HARD_CAP := 14
## 지속 스폰 기본값 — RoomData 의 "spawn": {"max": 살아 있는 최대 수, "interval": [최소, 최대 초]} 로 방마다 덮어쓴다
const SPAWN_DEFAULT := {"max": 6, "interval": [1.8, 3.5]}
const SPAWN_MIN_PLAYER_DIST := 900.0    # 플레이어에서 이만큼 떨어진 곳(가능하면 화면 밖)에 나온다
const FRONT_DOOR_INTERACT_RANGE := 110.0
const NPC_WALL_MARGIN := 150.0          # 어슬렁거리는 생존자가 벽에 붙지 않게 두는 여유 (플레이어보다 조금 넓다)
## 사족보행 기체가 걸어다닐 수 있는 방 안쪽 여유. 생존자보다 넓다 — 몸통이 넓고 포신이 앞으로 길어서,
## 벽에 바짝 붙으면 총구가 벽 안에 박힌 채로 쏘게 된다 (그 자리에서 탄이 바로 벽에 박힌다).
const WALKER_MARGIN := 260.0
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

	# 0. 벽 충돌 기하 — 타일을 찍기 전에 만들어 둔다 (프랍·탄피 등이 바로 참조한다)
	solid = RoomSolid.new()
	solid.build(heights, floor_y)
	RoomSolid.active = solid

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
	dim.color = Lighting.ambient_color()
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
	# 프랍 그림자 — 프랍 레이어의 **첫 자식**이라 모든 프랍보다 뒤에 그려진다 (벽 드리움이 프랍을 덮지 않게)
	prop_shadows = PropShadow.new()
	prop_shadows.setup(floor_y, float(width))
	props.add_child(prop_shadows)
	# 생존자는 프랍이 아니라 **인물**이다 — 플레이어·몬스터와 같은 층(z5)에 서야
	# 같은 비율의 거울 라이트를 받고 먼지·빛 기둥 뒤에 서지 않는다 (DepthLayers.Z_ACTOR_MIN).
	_npc_layer = Node2D.new()
	_npc_layer.name = "Npcs"
	_npc_layer.z_index = DepthLayers.Z_ACTOR_MIN
	add_child(_npc_layer)
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
				wp.z_index = DepthLayers.Z_ACTOR_MAX
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
		_add_crawler(float(m["x"]), int(m.get("facing", -1)), String(m.get("type", "crawler")) == "giant")
	_spawn_cfg = data.get("spawn", SPAWN_DEFAULT)
	_spawn_t = _next_spawn_delay() * 0.5
	# 첫 웨이브는 들어오자마자 덮치지 않는다 — 방을 한 번 둘러볼 틈(기본: 간격의 절반)을 준다
	if _spawn_cfg.has("wave"):
		var wv: Dictionary = _spawn_cfg["wave"]
		_wave_t = float(wv.get("first", float(wv.get("interval", 30.0)) * 0.5))

	# 부유 먼지 — 프랍 앞·빛 기둥 뒤(z3). 벽과 인물 사이의 "공기" 가 된다.
	var dust := DustLayer.new()
	dust.name = "Dust"
	dust.setup(room_rect, lamps, sources)
	dust.z_index = -1
	air.add_child(dust)

	# 7. 근경 실루엣 층 (z7) — 조명 제외, 카메라 1.12배 패럴랙스. 램프·정면문 자리는 기둥·케이블이 피한다.
	var avoid: Array = []
	for lamp in lamps:
		avoid.append(lamp.position.x)
	for fd in front_doors:
		avoid.append(fd["center"].x)
	for t in sentries:
		avoid.append(t.position.x)          # 근경 기둥이 센트리건 앞을 가리지 않게
	foreground = ForegroundLayer.new()
	foreground.name = "Foreground"
	foreground.z_index = DepthLayers.Z_FOREGROUND
	add_child(foreground)
	var cols: Array = []
	for c in range(heights.size()):
		cols.append(ceiling_at(c * RoomTheme.CELL + RoomTheme.CELL * 0.5))
	foreground.build(id, float(width), floor_y, room_rect.position.y, avoid, cols, room_rect.end.y)

	# 8. 벽 바깥 어둠 (z8) — 모든 층 위. 실루엣 밖을 덮고 벽 가장자리를 어둠으로 잇는다.
	#    비상등 부채꼴·램프 빛·근경이 벽 너머로 새지 않게 하는 시각 마감이다.
	wall_shadow = WallShadow.new()
	wall_shadow.name = "WallShadow"
	wall_shadow.z_index = DepthLayers.Z_FOREGROUND + 1
	add_child(wall_shadow)
	wall_shadow.build(solid, heights)
	if data.get("visual_pack", "") == "service_gallery":
		GalleryPlaytest.decorate(self)


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
	# 천장 마운트에 줄로 매단다. 층고가 낮은 방에서는 프랍에 닿지 않게 늘어뜨림을 줄인다.
	var head := floor_y - (ceiling_at(x) + RoomTiles.CEILING_BAND)
	var drop := clampf(LampLight.CORD_DROP, 34.0, maxf(head * 0.32, 34.0))
	lamp.attach_cord(parent, origin + Vector2(size.x * 0.5, 2.0), drop, floor_y)
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
		point.color = fd.get("color", FIXTURE_COLOR)
		point.set_meta("base_radius", float(fd.get("radius", 200.0)))
		LightTuning.apply_plain(point, "fixture", float(fd.get("radius", 200.0)))
		LightTuning.register(point, "fixture")
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
		# 벽걸이: 조명·피격 반응 없는 표면 스프라이트. "flip": true 면 좌우를 뒤집는다
		# (측벽문 문틀처럼 좌우가 한 쌍인 건축물에 쓴다)
		var s := Sprite2D.new()
		s.centered = false
		s.texture = tex
		s.position = _fx_pos(p) - Vector2(w * 0.5, 0.0)
		s.flip_h = bool(p.get("flip", false))
		s.material = Lighting.shader_material("prop_surface")
		parent.add_child(s)
		return
	var top_left: Vector2
	if p.has("pos"):
		top_left = p["pos"]
	else:
		top_left = Vector2(round(float(p["x"]) - w * 0.5), floor_y + PROP_SINK - (h - _ground_margin(path)))
	var hp := HitProp.new()
	hp.setup(tex, top_left)
	parent.add_child(hp)
	props_hit.append(hp)
	prop_shadows.add_caster(hp, tex)


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


## 특수 프랍: cabinet(파츠 파괴 PowerRelayProp) · capacitor · cart · breaker(벽걸이) · sentry(바닥 격납 센트리건) ·
## walker(사족보행 기체) · terminal(접속 단말기) · npc(생존자)
func _add_special_prop(parent: Node2D, prop: Dictionary) -> void:
	var x := float(prop["x"])
	match prop.get("type", ""):
		"cabinet":
			var cabinet := PowerRelayProp.new()
			cabinet.setup(x, floor_y)
			parent.add_child(cabinet)
			props_hit.append(cabinet)
			prop_shadows.add_caster(cabinet, Lighting.textured(PowerRelayProp.ROOT + "Props/power_relay_cabinet_assembled.png"))
		"capacitor", "cart":
			var file := "power_relay_capacitor_bank.png" if prop["type"] == "capacitor" else "power_relay_maintenance_cart.png"
			var path := RoomData.POWER_RELAY_DIR + "Props/" + file
			var tex := Lighting.textured(path)
			var w := float(tex.get_width())
			var top_left := Vector2(round(x - w * 0.5), floor_y + PROP_SINK - (tex.get_height() - _ground_margin(path)))
			var hp := HitProp.new()
			hp.setup(tex, top_left)
			parent.add_child(hp)
			props_hit.append(hp)
			prop_shadows.add_caster(hp, tex)
		"sentry":
			# 바닥 격납형 센트리건. 프랍 층 맨 앞(z3)에 두어 다른 프랍보다 앞, 인물(z5) 보다는 뒤에 선다.
			# id 는 보안 단말기의 방어 그리드가 이 포탑을 지목하는 열쇠다 (TerminalData.sentries).
			var turret := SentryTurret.new()
			turret.z_index = 1
			turret.turret_id = str(prop.get("id", ""))
			turret.setup(x, floor_y, self)
			parent.add_child(turret)
			sentries.append(turret)
		"walker":
			# 사족보행 기체. 평소엔 꺼진 채 웅크리고 있다가 W/↑ 로 기동·조종한다 (WalkerUnit).
			# 센트리건과 달리 **걸어다니므로** 방 좌우 끝을 알려 준다 — 벽을 뚫고 나가지 않게.
			var unit := WalkerUnit.new()
			unit.z_index = 1
			unit.name = "Walker_" + str(prop.get("id", "?"))    # 디버그·필름에서 알아볼 수 있게
			unit.walker_id = str(prop.get("id", ""))
			unit.display_name = str(prop.get("name", "보행 기체"))
			unit.setup(x, floor_y, self)
			unit.set_span(WALKER_MARGIN, float(width) - WALKER_MARGIN)
			parent.add_child(unit)
			walkers.append(unit)
		"terminal":
			# 역할(link·security·rewire·save·survey)은 id 로 TerminalData 에서 끌어온다.
			# rewire 처럼 벽걸이인 역할은 바닥이 아니라 cy/fy 높이에 붙는다.
			var tid := str(prop.get("id", ""))
			var terminal := AccessTerminal.new()
			var wall_y := NAN
			if TerminalData.is_wall(tid):
				var d := prop.duplicate()
				if not d.has("cy") and not d.has("fy"):
					d["fy"] = AccessTerminal.WALL_DEFAULT_FY
				wall_y = _fx_pos(d).y
			terminal.setup(tid, x, floor_y, wall_y)
			parent.add_child(terminal)
			terminals.append(terminal)
			# 바닥형 단말기는 방에서 제일 큰 프랍이다 — 그림자를 안 주면 혼자 떠 보인다 (벽걸이는 접지가 없어 제외)
			if not TerminalData.is_wall(tid):
				prop_shadows.add_caster(terminal, Lighting.textured(TerminalData.texture_of(tid)))
		"npc":
			# 생존자. 인물·대사는 id 로 NpcData 에서 끌어온다 (배치만 여기, 내용은 저쪽 — 단말기와 같은 규칙).
			# parent(프랍 층)가 아니라 인물 층에 붙인다.
			var person := Npc.new()
			person.setup(str(prop.get("id", "")), x, floor_y, int(prop.get("facing", -1)))
			_npc_layer.add_child(person)
			# roam 이 있으면 배치점 둘레를 오간다. 구간은 방 벽 안쪽으로 잘린다 — 문 밖으로는 나가지 않는다.
			person.set_roam(float(prop.get("roam", 0.0)), NPC_WALL_MARGIN, float(width) - NPC_WALL_MARGIN)
			npcs.append(person)
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


## 배경 라이팅 무드 프리셋 적용 (앰비언트 색 + 보조 광원)
func apply_mood(i: int) -> void:
	LightMood.apply(self, _lights, _ambient, i)
	# 무드 광원이 갈아 끼워졌으니 그림자도 새 광원 목록으로 다시 잡는다
	if prop_shadows:
		prop_shadows.build(_lights, PropShadow.index)


## 기본 그림자 프리셋 적용 (F6 순환 — PropShadow.BASE_PRESETS)
func apply_prop_shadow(i: int) -> void:
	if prop_shadows:
		prop_shadows.apply(i)


## 동적 광원(총구 화염·탄착·불·아크·비상등) 그림자 프리셋 적용 (F8 순환 — PropShadow.DYN_PRESETS)
func apply_dyn_shadow(i: int) -> void:
	if prop_shadows:
		prop_shadows.apply_dynamic(i)


## 거대종이 설 수 있는 열인가 — 머리 위로 Crawler.GIANT_CLEARANCE 가 남아야 한다.
## 방은 열마다 천장 높이가 다른 계단형이라, "이 방" 이 아니라 "이 자리" 를 물어야 한다.
func _giant_headroom_ok(x: float) -> bool:
	return floor_y - ceiling_at(x) >= Crawler.GIANT_CLEARANCE


## 거대종이 몸을 다 펴고 설 수 있는 연속 구간들 (몸 절반 폭만큼 안으로 들인 뒤).
## 천장이 낮은 열에서 끊기므로 방 하나에 여러 구간이 나올 수 있고, 하나도 없을 수 있다.
func _giant_spans() -> Array:
	var out: Array = []
	var step := float(RoomTheme.CELL)
	var run_lo := -1.0
	var c := step * 0.5
	while c < float(width):
		if _giant_headroom_ok(c):
			if run_lo < 0.0:
				run_lo = c - step * 0.5
		elif run_lo >= 0.0:
			_append_giant_span(out, run_lo, c - step * 0.5)
			run_lo = -1.0
		c += step
	if run_lo >= 0.0:
		_append_giant_span(out, run_lo, float(width))
	return out


## 구간을 몸 절반 폭만큼 안으로 들여 담는다. 몸이 다 들어가지 못하는 구간은 버린다.
func _append_giant_span(out: Array, lo: float, hi: float) -> void:
	var a := lo + Crawler.GIANT_HALF_W
	var b := hi - Crawler.GIANT_HALF_W
	if b > a:
		out.append(Vector2(a, b))


## 몬스터가 돌아다닐 좌우 한계.
## 일반종은 벽 띠 안쪽 전체. 거대종은 x 가 든 **설 수 있는 구간** 하나로 가둔다 —
## 낮은 천장 밑으로 걸어 들어가 타일을 뚫고 지나가는 그림을 막는 게 목적이다.
## 받아 줄 구간이 아예 없는 방이면 그 자리 한 점으로 접힌다 (움직이지 않고 버티며 싸운다).
## **닫힌 문의 x 목록** (오름차순). 방을 여러 구역으로 자른다 — 몬스터는 자기 구역 밖으로 나가지 못하고,
## 지속 스폰은 **플레이어가 있는 구역 안에서만** 나온다. 빈 배열이면 방 전체가 한 구역이다(본 맵의 모든 방).
## 공간 테스트 씬의 구역 문(SectionGate)이 열릴 때마다 여기서 그 x 를 빼고 refresh_sections() 를 부른다.
var section_walls: Array = []


## x 가 속한 구역 [왼쪽 끝, 오른쪽 끝] — 닫힌 문과 방 벽으로 잘린 구간
func section_of(x: float) -> Vector2:
	var lo := MONSTER_MARGIN
	var hi := maxf(MONSTER_MARGIN, width - MONSTER_MARGIN)
	for w in section_walls:
		var wx := float(w)
		if wx <= x:
			lo = maxf(lo, wx)
		else:
			hi = minf(hi, wx)
	return Vector2(lo, maxf(lo, hi))


## 문이 열리거나 닫혀 구역이 바뀌었을 때 — 살아 있는 몬스터의 활동 범위를 다시 잡는다.
## **자리를 옮기지는 않는다.** 각자 지금 서 있는 구역을 그대로 받는다.
func refresh_sections() -> void:
	for m in monsters:
		if not is_instance_valid(m):
			continue
		var sp := section_of(m.position.x)
		if m.get("art_scale") != null and float(m.get("art_scale")) > 1.5:
			sp = _clip_to_giant(sp, m.position.x)
		m.min_x = sp.x
		m.max_x = sp.y


## 거대종은 설 수 있는 구간(천장 높이)이 따로 있다 — 구역과 겹치는 부분만 준다
func _clip_to_giant(span: Vector2, x: float) -> Vector2:
	var best := span
	for g in _giant_spans():
		if x >= g.x and x <= g.y:
			best = Vector2(maxf(span.x, g.x), minf(span.y, g.y))
			break
	return Vector2(best.x, maxf(best.x, best.y))


func _monster_bounds(giant: bool, x: float) -> Vector2:
	if not giant:
		var full := section_of(x)
		return full
	var spans := _giant_spans()
	if spans.is_empty():
		var mid := clampf(x, 0.0, float(width))
		return Vector2(mid, mid)
	spans = spans.map(func(g): return Vector2(maxf(g.x, section_of(x).x), minf(g.y, section_of(x).y)))
	spans = spans.filter(func(g): return g.y > g.x)
	if spans.is_empty():
		var mid2 := clampf(x, 0.0, float(width))
		return Vector2(mid2, mid2)
	var best: Vector2 = spans[0]
	for sp in spans:
		if x >= sp.x and x <= sp.y:
			return sp
		if absf(x - clampf(x, sp.x, sp.y)) < absf(x - clampf(x, best.x, best.y)):
			best = sp
	return best


func _add_crawler(x: float, facing: int, giant := false) -> Crawler:
	var c := Crawler.new()
	c.name = "GiantCrawler" if giant else "Crawler"
	if giant:
		c.make_giant()                       # setup() 보다 먼저 — 체력·타이머가 거대종 값으로 잡힌다
	var b := _monster_bounds(giant, x)
	c.setup(self, x, floor_y + 2.0, b.x, b.y, facing)
	c.spat.connect(_on_monster_spat)
	c.roared.connect(monster_roared.emit)
	c.slammed.connect(monster_slammed.emit)
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


## **플레이어와 같은 구역**에 살아 있는 몬스터 수. 스폰 상한은 이 값으로 잰다 —
## 닫힌 문 뒤에 있어 만날 수도 죽일 수도 없는 개체가 상한을 먹으면, 정작 눈앞은 텅 빈 채로 굳는다.
func alive_in_section(x: float) -> int:
	var sec := section_of(x)
	var n := 0
	for m in monsters:
		if is_instance_valid(m) and not m.is_dead() and m.position.x >= sec.x and m.position.x <= sec.y:
			n += 1
	return n


## 지속 스폰: 살아 있는 수가 max 미만이면 interval 마다 한 마리. 플레이어에서 먼 자리를 고른다(8회 시도, 없으면 먼 쪽 끝)
func _tick_spawner(delta: float) -> void:
	var cap := spawn_cap()
	if cap <= 0 or player == null:
		return
	# 웨이브 스폰 ("spawn": {"wave": {...}}) — 한 마리씩 흘리지 않고 한 번에 몰아서 내보낸다
	if _spawn_cfg.has("wave"):
		_tick_wave(delta, cap)
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = _next_spawn_delay()
	if alive_in_section(player.position.x) >= cap:
		return
	_spawn_one()


## 이 방이 동시에 살려 둘 수 있는 몬스터 수. 방 데이터의 max 를 쓰되 **엔진 상한을 넘지 않는다.**
## 상한이 없으면 아주 긴 방에서 데이터 한 줄 실수로 프레임이 무너진다 — 몬스터 하나가
## 스프라이트·그림자·독액·체액 자국을 전부 끌고 다닌다.
func spawn_cap() -> int:
	return mini(int(_spawn_cfg.get("max", 0)), MONSTER_HARD_CAP)


## 다음 웨이브까지 남은 초 (HUD 용). 웨이브 방이 아니거나 지금 쏟아지는 중이면 -1.
func wave_countdown() -> float:
	if not _spawn_cfg.has("wave") or _wave_left > 0:
		return -1.0
	return maxf(_wave_t, 0.0)


func wave_pending() -> int:
	return _wave_left


## 웨이브: interval 초마다 size 마리를 gap 초 간격으로 내보낸다. 자리가 없으면 남은 마리는 버리고
## 다음 웨이브를 기다린다 — 밀린 마리가 계속 새어 나와 결국 "쉬지 않고 나오는" 상태가 되지 않게.
func _tick_wave(delta: float, cap: int) -> void:
	var cfg: Dictionary = _spawn_cfg["wave"]
	if _wave_left > 0:
		_wave_gap -= delta
		if _wave_gap > 0.0:
			return
		_wave_gap = float(cfg.get("gap", 0.35))
		if alive_in_section(player.position.x) >= cap:
			_wave_left = 0
			return
		_spawn_one()
		_wave_left -= 1
		return
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	_wave_t = float(cfg.get("interval", 30.0))
	var size: Array = cfg.get("size", [3, 5])
	_wave_left = maxi(0, mini(randi_range(int(size[0]), int(size[1])), cap - alive_in_section(player.position.x)))
	_wave_gap = 0.0
	if _wave_left > 0:
		wave_index += 1
		wave_started.emit(wave_index, _wave_left)


## 한 마리를 규칙(거대종 확률 · 스폰 밴드 · 플레이어와의 최소 거리)대로 내보낸다
func _spawn_one() -> void:
	# 지속 스폰에 거대종이 섞이는 확률 (방 데이터의 "spawn": {"giant": 0.0~1.0}).
	# 이 방이 그 덩치를 받아 주지 못하면 조용히 일반종으로 되돌린다 — 제자리에 못 박힌 거대종보다 낫다.
	var giant := randf() < float(_spawn_cfg.get("giant", 0.0))
	var bounds := Vector2(MONSTER_MARGIN, maxf(MONSTER_MARGIN, width - MONSTER_MARGIN))
	if giant:
		var spans := _giant_spans()
		if spans.is_empty():
			giant = false
		else:
			bounds = spans[randi() % spans.size()]
	# 닫힌 문 너머에는 나오지 않는다 — 플레이어가 있는 구역 안으로 자른다
	var sec := section_of(player.position.x)
	bounds.x = maxf(bounds.x, sec.x)
	bounds.y = minf(bounds.y, sec.y)
	if bounds.y <= bounds.x:
		return
	var lo := bounds.x
	var hi := bounds.y
	# spawn.band: 플레이어에서 이 거리 안에서만 나온다 (없으면 방 전체).
	# 아주 긴 방에서 max 마리를 방 끝까지 흩뿌리면 밀도가 0 에 가까워진다 — 공간 테스트 씬이 쓴다.
	var band := float(_spawn_cfg.get("band", 0.0))
	if band > 0.0:
		lo = maxf(lo, player.position.x - band)
		hi = minf(hi, player.position.x + band)
		if hi - lo < SPAWN_MIN_PLAYER_DIST * 2.0:
			lo = clampf(player.position.x - SPAWN_MIN_PLAYER_DIST * 1.2, bounds.x, bounds.y)
			hi = clampf(player.position.x + SPAWN_MIN_PLAYER_DIST * 1.2, bounds.x, bounds.y)
	var x := 0.0
	var found := false
	for i in range(8):
		x = randf_range(lo, hi)
		if absf(x - player.position.x) >= SPAWN_MIN_PLAYER_DIST:
			found = true
			break
	if not found:
		x = lo if player.position.x > width * 0.5 else hi
	var c := _add_crawler(x, 1 if player.position.x >= x else -1, giant)
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


## 뒷벽·바닥에 남는 체액 자국이 붙는 층 (프랍 층 — 타일·문 앞, 캐릭터 뒤).
## 프랍에 튄 자국은 이 층이 아니라 그 프랍의 자식으로 붙는다 (BloodStain._attach).
func stain_layer() -> Node2D:
	return _props_layer


## 체액이 앉을 수 있는 **앞쪽 면**들 — 바닥 프랍(HitProp) + 단말기. 뒷벽보다 앞에 서 있는 것들이다.
## 여기 없는 것에 뿌려진 덩어리는 전부 뒷벽으로 가고, 그 물체 뒤에 가려진다.
func stain_props() -> Array:
	var out: Array = props_hit.duplicate()
	for t in terminals:
		if is_instance_valid(t):
			out.append(t)
	return out


## 체액 자국. 덩어리마다 착지면(프랍·바닥·벽·뒷벽)을 따로 판정하므로 자국 노드가 여러 개 나온다.
## 너무 많이 쌓이면 오래된 것부터 지운다.
func add_stain(pos: Vector2, dir: Vector2, amount: int, spread: float) -> void:
	_trim_stains()
	_stains.append_array(BloodStain.splat(self, pos, dir, amount, spread))


## 분사 자국 (덩어리가 순차적으로 찍히고 흘러내린다). 착지면별로 나뉘고, 가끔 근경 층에도 방울이 남는다.
func add_spray(pos: Vector2, dir: Vector2, amount: int, length: float, fan: float) -> void:
	_trim_stains()
	_stains.append_array(BloodStain.spray(self, pos, dir, amount, length, fan))


func _trim_stains() -> void:
	_stains = _stains.filter(func(s): return is_instance_valid(s))
	while _stains.size() >= MAX_STAINS:
		var old: Node = _stains.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## 사격 선분을 벽면까지 자른다 — 벽 너머(어둠·옆방)로는 탄이 나가지 않는다.
## 총구가 벽 띠 안이어도(벽에 붙어 쏠 때) 벽을 빠져나온 뒤부터 본다.
func clip_shot(from: Vector2, to: Vector2) -> Vector2:
	if solid == null:
		return to
	return solid.clip_ray(from, to)


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


## 사격 한 발이 방에 미치는 물리 영향 (전선 튕김 등)
func notify_shot(from: Vector2, to: Vector2) -> void:
	for w in wires:
		w.apply_shot(from, to)
	for lamp in lamps:                      # 스치기만 해도 매달린 램프가 흔들린다
		lamp.apply_shot(from, to)


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


## 플레이어가 조종할 수 있는 거리에 있는 센트리건 (없으면 null). 조종 중인 쪽을 먼저 돌려준다.
func sentry_near(px: float) -> SentryTurret:
	for t in sentries:
		if is_instance_valid(t) and t.controlled:
			return t
	for t in sentries:
		if is_instance_valid(t) and t.can_interact(px):
			return t
	return null


## 맵 전체에서 유일한 포탑 id 로 찾는다 (보안 단말기의 원격 접속이 쓴다)
func sentry_by_id(id: String) -> SentryTurret:
	for t in sentries:
		if is_instance_valid(t) and t.turret_id == id:
			return t
	return null


## 다가가 탈 수 있는 사족보행 기체 (없으면 null). sentry_near 와 같은 규칙 —
## 이미 조종 중인 것이 있으면 그게 먼저다 (내릴 수 있어야 하므로)
func walker_near(px: float) -> WalkerUnit:
	for w in walkers:
		if is_instance_valid(w) and w.controlled:
			return w
	for w in walkers:
		if is_instance_valid(w) and w.can_interact(px):
			return w
	return null


## 맵 전체에서 유일한 기체 id 로 찾는다 (보안 단말기의 원격 접속이 쓴다)
func walker_by_id(id: String) -> WalkerUnit:
	for w in walkers:
		if is_instance_valid(w) and w.walker_id == id:
			return w
	return null


## 원격 조종에서 돌아왔을 때 원래 접속하던 단말기를 다시 잡는다 (방을 새로 조립했으므로 노드가 바뀌었다)
func terminal_by_id(id: String) -> AccessTerminal:
	for t in terminals:
		if is_instance_valid(t) and t.terminal_id == id:
			return t
	return null


## 플레이어가 말을 걸 수 있는 거리의 생존자 (없으면 null)
func npc_near(px: float) -> Npc:
	for n in npcs:
		if is_instance_valid(n) and n.can_interact(px):
			return n
	return null


## 플레이어가 접속할 수 있는 거리의 단말기 (없으면 null)
func terminal_near(px: float) -> AccessTerminal:
	for t in terminals:
		if is_instance_valid(t) and t.can_interact(px):
			return t
	return null


## 플레이어가 상호작용 가능한 정면문 반환(없으면 빈 Dictionary)
func front_door_near(px: float) -> Dictionary:
	for fd in front_doors:
		if absf(fd["center"].x - px) <= FRONT_DOOR_INTERACT_RANGE:
			return fd
	return {}


func _exit_tree() -> void:
	if RoomSolid.active == solid:
		RoomSolid.active = null
