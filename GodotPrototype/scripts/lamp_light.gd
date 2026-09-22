class_name LampLight
extends PointLight2D
## 천장 램프 라이트. **줄에 매달려 흔들린다** — 평소엔 미풍에 느리게, 총에 맞으면 크게.
## 줄의 물리는 끊긴 전선과 같은 것을 쓴다 (scripts/rope_chain.gd, 버렛 체인).
##
## 램프가 흔들리면 라이트·빛 기둥·바닥 풀이 전부 따라 움직이고, 프랍 그림자(PropShadow)가 매 프레임
## 광원 위치를 다시 읽으므로 **방 안의 그림자가 통째로 쓸린다**. 정적인 조명이 만들지 못하던 공간감이
## 여기서 나온다. 그래서 램프는 한 방에 깨지지 않는다 — MAX_HP 발을 맞는 동안 계속 흔들린다.
##
## 총에 맞으면: 체력이 남았으면 크게 흔들리며 지직거리고 유리 파편이 튄다.
## 체력이 다하면 깨진다 — 글리치 + 빠르게 꺼지고, 전구 위에 어두운 커버가 덮이며, 그 뒤로도 계속 흔들린다.
## 램프 스프라이트(HDR 발광)·빛 기둥(볼류메트릭 콘)·줄(Line2D)도 함께 관리한다.

const RADIUS := 560.0
var BASE_ENERGY := Lighting.LAMP_ENERGY            # Lighting.LAMP_ENERGY (VFX_LAMP 환경변수로 튜닝 가능)
const COLOR := Color(1.0, 0.86, 0.62)
const HIT_RADIUS := 60.0          # 이 거리 안에 탄착하면 맞은 것으로 본다
const MAX_HP := 3                 # 한 방에 깨지지 않는다 — 맞을 때마다 크게 흔들리고 지직거린다
const CORD_SEGMENTS := 6
const CORD_DROP := 118.0          # 천장 마운트에서 램프까지 (방 층고에 맞춰 줄인다)
const CORD_COLOR := Color(0.09, 0.09, 0.11)
const CORD_HILITE := Color(0.20, 0.20, 0.24)
## 맞았을 때 줄을 미는 힘. 진자 주기 T=2π√(L/g) 에서 진폭 θ≈v/(L·ω) 이므로
## 줄 118px·중력 1900 이면 110 이 약 13° 다. 240(≈28°)은 눈에 거슬릴 만큼 컸다.
const HIT_KICK := 110.0
## 스친 총알·충격파에 대한 민감도. 전선(1.0)과 같은 값을 주면 빗나간 총알마다 요란하게 출렁인다.
const CORD_IMPULSE_SCALE := 0.16
## 평소 미풍 진폭. 14 면 2.5초 동안 최대 기울기 0.63° — 흔들린다기보다 "아주 천천히 표류한다" 수준이다.
## (참고: 끊긴 전선은 26. 무게가 다르므로 같은 값을 주면 안 된다.)
const CORD_WIND := 14.0
const HIT_FLICKER := 0.42         # 맞은 직후 지직거리는 시간
const BREAK_TIME := 0.22
const GLITCH_TAIL := 0.35         # 꺼진 뒤에도 잠깐 잔상 글리치

const CONE_TOP_HALF := 34.0       # 빛 기둥 윗변 반폭 (전구 아래)
const CONE_BOTTOM_HALF := 330.0   # 바닥에서의 반폭
const CONE_INTENSITY := 0.55
const POOL_RADIUS := 400.0        # 램프 바로 아래 바닥에 고이는 빛
const POOL_ENERGY_RATIO := 0.35   # 램프 밝기 대비 (0.7 → 절반)
const POOL_SQUASH := 0.4          # 바닥에 납작하게

var broken := false
var hp := MAX_HP
var bulb_rect := Rect2()          # 월드 좌표 전구 픽셀 영역
## 램프를 매단 줄. 물리는 끊긴 전선과 같은 것을 쓴다 (scripts/rope_chain.gd).
## 램프가 흔들리면 라이트·빛 기둥·바닥 풀이 같이 흔들리고, 프랍 그림자(PropShadow)가 매 프레임
## 광원 위치를 다시 읽으므로 **그림자까지 같이 쓸린다** — 방의 공간감이 여기서 나온다.
var _rope: RopeChain
var _cord: Line2D
var _cord_hi: Line2D
var _anchor := Vector2.ZERO
var _bulb_local := Rect2()
var _floor_y := 486.0
var energy_ratio := 1.0           # 현재 밝기 / 기본 밝기 (먼지 레이어가 읽는다)
var _cover: ColorRect
var _sprite: Sprite2D
var _sprite_mat: ShaderMaterial
var _cone: Polygon2D
var _cone_mat: ShaderMaterial
var _pool: PointLight2D           # 바닥 풀 라이트 (자식, 램프와 같이 깜빡인다)
var _t := 0.0
var _phase := 0.0
var _next_flicker := 0.0
var _flicker_left := 0.0
var _flicker_seed := 0.0
var _break_t := 0.0
var _spark_drizzle := 0.0        # 깨진 직후 잔불이 흘러내리는 시간
var _spark_node: SparkBurst


func _ready() -> void:
	texture = Lighting.radial_texture()
	color = COLOR
	shadow_enabled = false
	BASE_ENERGY = LightTuning.value("lamp", "energy", Lighting.LAMP_ENERGY)
	texture_scale = Lighting.scale_for_radius(LightTuning.value("lamp", "radius", RADIUS))
	energy = BASE_ENERGY
	height = LightTuning.value("lamp", "height", Lighting.LAMP_HEIGHT)
	LightTuning.register(self, "lamp")
	_phase = randf() * TAU
	_next_flicker = randf_range(2.0, 6.0)
	Lighting.split_by_depth(self)                  # 벽 정면, 인물 층은 55%


## 전구 픽셀을 덮을 커버 (깨진 뒤 보임). parent 는 타일 위 레이어.
## 천장 마운트에 줄로 매단다. attach_sprite 뒤에 부른다.
##   anchor : 천장 쪽 고정점 (스프라이트 윗변 가운데)
##   drop   : 마운트에서 램프까지 늘어뜨릴 길이
func attach_cord(parent: Node2D, anchor_pos: Vector2, drop: float, floor_line: float) -> void:
	_anchor = anchor_pos
	_floor_y = floor_line
	_rope = RopeChain.new()
	_rope.wind_amp = CORD_WIND       # 전선보다 무거운 물건이라 미풍에는 거의 안 흔들린다
	_rope.wind_amp2 = CORD_WIND * 0.3
	_rope.damping = 0.990            # 한 번 맞으면 천천히 잦아든다
	_rope.impulse_scale = CORD_IMPULSE_SCALE
	# tilt 0 · slack 1 — 방에 들어선 순간에는 **완전히 멈춰 있다**. 비스듬히 시작하면 첫 프레임에
	# 길이 제약이 확 당기면서 조명이 저절로 출렁이며 시작한다.
	_rope.setup(anchor_pos, drop, CORD_SEGMENTS, floor_line, 0.0, 1.0)
	_cord = Line2D.new()
	_cord.name = "LampCord"
	_cord.width = 5.0
	_cord.default_color = CORD_COLOR
	_cord.joint_mode = Line2D.LINE_JOINT_ROUND
	_cord.end_cap_mode = Line2D.LINE_CAP_ROUND
	_cord.top_level = true
	_cord.z_index = -1               # 램프 갓 뒤로
	parent.add_child(_cord)
	_cord_hi = Line2D.new()
	_cord_hi.width = 1.5
	_cord_hi.default_color = CORD_HILITE
	_cord_hi.top_level = true
	_cord_hi.z_index = -1
	parent.add_child(_cord_hi)
	_sync_cord()


## 줄 끝에 램프를 걸고, 거기에 딸린 것들(라이트·전구 커버·빛 기둥·바닥 풀)을 따라 옮긴다.
func _sync_cord() -> void:
	if _rope == null or _sprite == null:
		return
	var tip := _rope.tip()
	var ang := _rope.tip_angle()
	_sprite.position = tip
	_sprite.rotation = ang
	_cord.points = _rope.points()
	_cord_hi.points = _rope.points()
	# 전구 월드 좌표 — 스프라이트가 기울어진 만큼 같이 돈다
	var bulb_center: Vector2 = tip + (_sprite.offset + _bulb_local.get_center()).rotated(ang)
	global_position = bulb_center
	bulb_rect = Rect2(bulb_center - _bulb_local.size * 0.5, _bulb_local.size)
	if _cover:
		_cover.pivot_offset = _cover.size * 0.5
		_cover.rotation = ang                 # 깨진 전구 덮개도 갓과 같이 기운다
		_cover.position = bulb_rect.position - Vector2(1, 1)
	if _pool:
		_pool.position = Vector2(0.0, _floor_y + 8.0 - global_position.y)
	if _cone:
		# 빛 기둥은 수직으로 두되 전구를 따라 좌우로 쓸린다 (셰이더가 세로축 기준으로 폭을 잰다)
		var top := Vector2(bulb_center.x, bulb_rect.end.y - 2.0)
		var bottom_y: float = _floor_y + 14.0
		_cone.polygon = PackedVector2Array([
			top + Vector2(-CONE_TOP_HALF, 0), top + Vector2(CONE_TOP_HALF, 0),
			Vector2(top.x + CONE_BOTTOM_HALF, bottom_y), Vector2(top.x - CONE_BOTTOM_HALF, bottom_y),
		])
		_cone_mat.set_shader_parameter("top_center", top)


func attach_cover(parent: Node2D, world_rect: Rect2) -> void:
	bulb_rect = world_rect
	_cover = ColorRect.new()
	_cover.color = Color(0.16, 0.15, 0.17)
	_cover.position = world_rect.position - Vector2(1, 1)
	_cover.size = world_rect.size + Vector2(2, 3)
	_cover.visible = false
	parent.add_child(_cover)


## 램프 스프라이트: 타일 텍스처에서 램프 영역(tile_region, 타일 로컬)을 잘라 같은 자리에 올린다.
## 전구 픽셀은 HDR 로 발광(글로우), 깨질 때 글리치.
func attach_sprite(parent: Node2D, tile_tex: Texture2D, tile_origin: Vector2, tile_region: Rect2, bulb_local: Rect2) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = tile_tex
	atlas.region = tile_region
	_sprite = Sprite2D.new()
	_sprite.name = "LampSprite"
	_sprite.centered = false
	_sprite.texture = atlas
	_bulb_local = bulb_local
	# 회전축을 윗변 가운데(천장에 매달리는 지점)로 옮긴다 — 위치는 그대로 그려진다
	_sprite.offset = Vector2(-tile_region.size.x * 0.5, 0.0)
	_sprite.position = tile_origin + tile_region.position + Vector2(tile_region.size.x * 0.5, 0.0)
	_sprite_mat = Lighting.shader_material("lamp_glitch")
	_sprite_mat.set_shader_parameter("time_seed", randf() * 100.0)
	var b0 := (bulb_local.position - tile_region.position) / tile_region.size
	var b1 := (bulb_local.end - tile_region.position) / tile_region.size
	_sprite_mat.set_shader_parameter("bulb_uv", Vector4(b0.x - 0.02, b0.y - 0.02, b1.x + 0.02, b1.y + 0.03))
	_sprite_mat.set_shader_parameter("emit", _emit_for(1.0))
	_sprite.material = _sprite_mat
	parent.add_child(_sprite)


## 볼류메트릭 빛 기둥: 전구 아래에서 바닥까지 사다리꼴 (가산 블렌드)
func attach_cone(parent: Node2D, floor_y: float) -> void:
	var top := Vector2(global_position.x, bulb_rect.end.y - 2.0)
	var bottom_y := floor_y + 14.0
	_cone = Polygon2D.new()
	_cone.name = "LightCone"
	_cone.polygon = PackedVector2Array([
		top + Vector2(-CONE_TOP_HALF, 0), top + Vector2(CONE_TOP_HALF, 0),
		Vector2(top.x + CONE_BOTTOM_HALF, bottom_y), Vector2(top.x - CONE_BOTTOM_HALF, bottom_y),
	])
	_cone.texture = Lighting.white_texture()
	_cone.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_cone_mat = Lighting.shader_material("light_cone")
	_cone_mat.set_shader_parameter("seed", randf() * 10.0)
	_cone_mat.set_shader_parameter("top_center", top)
	_cone_mat.set_shader_parameter("top_half", CONE_TOP_HALF)
	_cone_mat.set_shader_parameter("bottom_y", bottom_y)
	_cone_mat.set_shader_parameter("bottom_half", CONE_BOTTOM_HALF)
	_cone_mat.set_shader_parameter("tint", COLOR)
	_cone_mat.set_shader_parameter("intensity", CONE_INTENSITY)
	_cone.material = _cone_mat
	parent.add_child(_cone)

	# 바닥 풀: 램프 바로 아래 바닥선에 납작한 라이트. 바닥 타일 노멀이 반응해 바닥이 살아난다.
	_pool = PointLight2D.new()
	_pool.name = "FloorPool"
	_pool.texture = Lighting.radial_texture()
	_pool.texture_scale = Lighting.scale_for_radius(LightTuning.value("lamp_pool", "radius", POOL_RADIUS))
	_pool.scale = Vector2(1.0, POOL_SQUASH)
	_pool.color = COLOR
	_pool.energy = BASE_ENERGY * LightTuning.value("lamp_pool", "energy", POOL_ENERGY_RATIO)
	_pool.height = LightTuning.value("lamp_pool", "height", 90.0)
	_pool.shadow_enabled = false
	_pool.position = Vector2(0.0, floor_y + 8.0 - global_position.y)
	add_child(_pool)
	Lighting.split_by_depth(_pool, DepthLayers.ACTOR_FLOOR_LIGHT_RATIO)   # 발 밑 바닥 빛은 인물에도 조금 더


## 조명 랩이 수치를 바꿨을 때. 깜빡임·파괴 상태는 건드리지 않고 기준값만 갈아 끼운다.
func apply_tuning() -> void:
	BASE_ENERGY = LightTuning.value("lamp", "energy", Lighting.LAMP_ENERGY)
	texture_scale = Lighting.scale_for_radius(LightTuning.value("lamp", "radius", RADIUS))
	height = LightTuning.value("lamp", "height", Lighting.LAMP_HEIGHT)
	if not broken:
		energy = BASE_ENERGY * energy_ratio
	if _pool:
		_pool.texture_scale = Lighting.scale_for_radius(LightTuning.value("lamp_pool", "radius", POOL_RADIUS))
		_pool.height = LightTuning.value("lamp_pool", "height", 90.0)
		_pool.energy = BASE_ENERGY * LightTuning.value("lamp_pool", "energy", POOL_ENERGY_RATIO) * energy_ratio


func is_hit(point: Vector2) -> bool:
	return not broken and global_position.distance_to(point) <= HIT_RADIUS


## 총알이 맞았다. 바로 깨지지 않고 체력을 깎으며 **크게 흔들리고 지직거린다**.
## 흔들리는 동안 라이트가 같이 움직여 방 전체의 그림자가 쓸린다. 돌려주는 값은 "이번에 깨졌나".
func hit_lamp(point: Vector2, dir: float) -> bool:
	if broken:
		return false
	hp -= 1
	var d := dir if absf(dir) > 0.01 else signf(randf() - 0.5)
	if _rope:
		_rope.kick(Vector2(d * HIT_KICK, -HIT_KICK * 0.15))
	_flicker_left = maxf(_flicker_left, HIT_FLICKER)
	_flicker_seed = randf() * 100.0
	# 유리 파편 몇 알이 맞은 방향으로 튄다
	var sb := SparkBurst.spawn(get_parent(), _floor_y)
	sb.burst(bulb_rect.get_center() + Vector2(0, 3), 8, Vector2(d, 0.4).normalized(), 1.0, Vector2(90, 380),
		Color(1.0, 0.95, 0.85), Color(1.0, 0.45, 0.15), Vector2(0.4, 0.9), 2000.0, 1.6)
	if hp <= 0:
		break_lamp()
		return true
	return false


## 총알이 곁을 스치면 줄이 흔들린다 (맞히지 않아도 공간이 움직인다)
func apply_shot(from: Vector2, to: Vector2) -> void:
	if _rope:
		_rope.apply_shot(from, to, 46.0, 300.0)


func break_lamp() -> void:
	if broken:
		return
	broken = true
	_break_t = 0.0
	if _cover:
		_cover.visible = true
	# 전구가 터지며 뜨거운 불꽃이 바닥으로 흩뿌려진다 (즉시 한 뭉치 + 잠깐 흘러내리는 잔불)
	var sb := SparkBurst.spawn(get_parent(), float(RoomData.FLOOR_Y))
	var origin := bulb_rect.get_center() + Vector2(0, 4)
	sb.burst(origin, 30, Vector2(0, 1), 1.35, Vector2(140, 640),
		Color(1.0, 0.95, 0.8), Color(1.0, 0.28, 0.08), Vector2(0.45, 1.2), 2100.0, 3.0)
	sb.burst(origin, 10, Vector2(0, 1), 0.5, Vector2(60, 220),
		Color(1.0, 0.9, 0.75), Color(1.0, 0.35, 0.1), Vector2(0.8, 1.6), 1600.0, 2.2, false)
	_spark_drizzle = 0.5
	_spark_node = sb


## 전구 발광 배율. CanvasModulate(AMBIENT)는 셰이더 출력 뒤에 곱해지므로 그 역수만큼 키워야
## 최종 값이 글로우 임계(1.0)를 넘는다. HDR 2D 는 선형 공간이라 선형 변환값을 쓴다.
func _emit_for(ratio: float) -> float:
	var amb := Lighting.AMBIENT
	var inv := 3.0 / maxf((amb.r + amb.g + amb.b) / 3.0, 0.01)
	return Lighting.BULB_EMISSION * inv * ratio


func _apply_visuals(ratio: float, glitch: float) -> void:
	energy_ratio = ratio
	if _sprite_mat:
		_sprite_mat.set_shader_parameter("emit", _emit_for(ratio))
		_sprite_mat.set_shader_parameter("glitch", glitch)
	if _cone_mat:
		_cone_mat.set_shader_parameter("intensity", CONE_INTENSITY * ratio)
	if _cone:
		_cone.visible = ratio > 0.01
	if _pool:
		_pool.energy = BASE_ENERGY * POOL_ENERGY_RATIO * ratio
		_pool.enabled = ratio > 0.01


## 줄은 **고정 프레임**에서 돈다. _process 의 들쭉날쭉한 dt 로 버렛을 굴리면 프레임이 한 번 끊길 때
## 줄에 에너지가 들어가 저절로 흔들린다 (끊긴 전선도 같은 이유로 _physics_process 를 쓴다).
func _physics_process(delta: float) -> void:
	if _rope:
		_rope.anchor = _anchor
		_rope.step(delta, false)      # 천장 램프는 바닥에 닿을 일이 없다
		_sync_cord()


func _process(delta: float) -> void:
	_t += delta
	if broken:
		_break_t += delta
		if _spark_drizzle > 0.0 and is_instance_valid(_spark_node):
			_spark_drizzle -= delta
			if randf() < 0.6:
				_spark_node.burst(bulb_rect.get_center() + Vector2(randf_range(-6, 6), 4), 1, Vector2(0, 1), 0.7,
					Vector2(40, 260), Color(1.0, 0.9, 0.75), Color(1.0, 0.3, 0.1), Vector2(0.5, 1.1), 1900.0, 2.4, false)
		var k := _break_t / BREAK_TIME
		if k >= 1.0:
			energy = 0.0
			enabled = false
			# 꺼진 뒤 잔상 글리치가 잦아들면 스프라이트 커버 위에 고정
			var tail := clampf((_break_t - BREAK_TIME) / GLITCH_TAIL, 0.0, 1.0)
			_apply_visuals(0.0, (1.0 - tail) * 0.6)
			if tail >= 1.0:
				_apply_visuals(0.0, 0.0)         # 깨진 램프는 어두운 갓만 남아 계속 흔들린다
			return
		# 깨지는 순간: 강하게 번쩍 → 지직거리며 소멸
		var n := 0.5 + 0.5 * sin(_t * 90.0 + _phase)
		energy = BASE_ENERGY * (1.0 - k) * lerpf(0.2, 1.6, n)
		_apply_visuals(energy / BASE_ENERGY * 1.3, 1.0)
		return

	# 미세한 호흡 — 전구의 잔잔한 흔들림
	var e := BASE_ENERGY * (1.0 + 0.03 * sin(_t * 2.3 + _phase) + 0.02 * sin(_t * 5.1 + _phase * 1.7))

	_next_flicker -= delta
	if _next_flicker <= 0.0 and _flicker_left <= 0.0:
		_flicker_left = randf_range(0.18, 0.55)
		_flicker_seed = randf() * 100.0
		_next_flicker = randf_range(3.0, 9.0)

	var glitch := 0.0
	if _flicker_left > 0.0:
		_flicker_left -= delta
		# 빠르게 튀는 노이즈 + 이따금 거의 꺼짐
		var n := 0.5 + 0.5 * sin(_t * 61.0 + _flicker_seed) * sin(_t * 23.0 + _flicker_seed * 0.3)
		var drop := 0.15 if fmod(_t * 17.0 + _flicker_seed, 5.0) < 0.6 else 0.55
		e *= lerpf(drop, 1.05, n)
		glitch = 0.15

	energy = e
	_apply_visuals(e / BASE_ENERGY, glitch)
