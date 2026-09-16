class_name LampLight
extends PointLight2D
## 천장 램프 라이트. 평소엔 아주 미세하게 흔들리고, 가끔(3~9초) 짧게 깜빡인다.
## 총에 맞으면 깨진다: 지직거리는 글리치 셰이더 + 빠르게 꺼지고, 전구 픽셀 위에 어두운 커버가 덮인다.
## 램프 스프라이트(타일에서 잘라낸 아틀라스, HDR 발광)·빛 기둥(볼류메트릭 콘)도 함께 관리한다.

const RADIUS := 560.0
var BASE_ENERGY := Lighting.LAMP_ENERGY            # Lighting.LAMP_ENERGY (VFX_LAMP 환경변수로 튜닝 가능)
const COLOR := Color(1.0, 0.86, 0.62)
const HIT_RADIUS := 60.0          # 이 거리 안에 탄착하면 맞은 것으로 본다
const BREAK_TIME := 0.22
const GLITCH_TAIL := 0.35         # 꺼진 뒤에도 잠깐 잔상 글리치

const CONE_TOP_HALF := 34.0       # 빛 기둥 윗변 반폭 (전구 아래)
const CONE_BOTTOM_HALF := 330.0   # 바닥에서의 반폭
const CONE_INTENSITY := 0.55

var broken := false
var bulb_rect := Rect2()          # 월드 좌표 전구 픽셀 영역
var energy_ratio := 1.0           # 현재 밝기 / 기본 밝기 (먼지 레이어가 읽는다)
var _cover: ColorRect
var _sprite: Sprite2D
var _sprite_mat: ShaderMaterial
var _cone: Polygon2D
var _cone_mat: ShaderMaterial
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
	texture_scale = Lighting.scale_for_radius(RADIUS)
	color = COLOR
	energy = BASE_ENERGY
	shadow_enabled = false
	height = Lighting.LAMP_HEIGHT
	_phase = randf() * TAU
	_next_flicker = randf_range(2.0, 6.0)


## 전구 픽셀을 덮을 커버 (깨진 뒤 보임). parent 는 타일 위 레이어.
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
	_sprite.position = tile_origin + tile_region.position
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


func is_hit(point: Vector2) -> bool:
	return not broken and global_position.distance_to(point) <= HIT_RADIUS


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
				if _sprite:
					_sprite.visible = false      # 아래 타일의 원본 램프 픽셀 + 커버가 보인다
				set_process(false)
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
