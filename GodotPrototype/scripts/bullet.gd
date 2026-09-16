class_name Bullet
extends Node2D
## 고속 탄환. 총구에서 목표점(마우스 포인터)까지 직선으로 날아가 정확히 그 지점에 탄착한다.
## 시각: 총구부터 탄두까지 이어지는 한 줄 궤적이 찍히고 탄착 직후 사라진다.
## 탄착: 플래시 + 불꽃 스파크 + 중력을 받는 벽 파편 + 짧은 라이트 (타격감).

const SPEED := 10400.0
const TRAIL_W := 7.0
const TRAIL_FADE := 0.05       # 탄착 후 궤적이 사라지는 시간 (거의 즉시)

const IMPACT_LIFE := 0.6      # 파편이 남는 시간
const SPARK_COUNT := 8         # (30% 축소)        # 밝은 불꽃 (빠르고 곧게)
const CHIP_COUNT := 8          # (30% 축소)         # 벽 파편 (중력, 회전, 바닥 튕김)
const GRAVITY := 2600.0
const FLASH_TIME := 0.08
const RING_TIME := 0.16

enum Impact { WALL, GLASS, PROP }

var impact_kind: Impact = Impact.WALL
var start := Vector2.ZERO
var target := Vector2.ZERO
var floor_y := 100000.0        # 파편이 튕기는 바닥 (Main 이 넣어준다)
var _dir := Vector2.RIGHT
var _total := 0.0
var _travelled := 0.0
var _impacting := false
var _impact_t := 0.0
var _trail: Line2D
var _core: Line2D
var _head: ColorRect
var _flash: ColorRect
var _ring: Node2D
var _light: PointLight2D
var _debris: Array = []        # [{node, vel, spin, gravity, life}]


func setup(from: Vector2, to: Vector2) -> void:
	start = from
	target = to
	_dir = (to - from).normalized() if to.distance_to(from) > 1.0 else Vector2.RIGHT
	_total = from.distance_to(to)
	position = Vector2.ZERO          # 월드 좌표를 그대로 쓴다


func _ready() -> void:
	_trail = Line2D.new()
	_trail.width = TRAIL_W
	_trail.default_color = Color(1.0, 0.8, 0.3, 0.9)
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.7, 0.25, 0.0))
	grad.set_color(1, Color(1.0, 0.85, 0.4, 1.0))
	_trail.gradient = grad
	_trail.modulate = Lighting.EMISSIVE_SOFT      # HDR → 글로우
	add_child(_trail)

	_core = Line2D.new()
	_core.width = 2.5
	_core.default_color = Color(1.0, 1.0, 0.95, 1.0)
	_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	_core.modulate = Lighting.EMISSIVE
	add_child(_core)

	_head = ColorRect.new()
	_head.color = Color(1.0, 1.0, 0.9)
	_head.size = Vector2(12, 12)
	_head.pivot_offset = _head.size * 0.5
	_head.modulate = Lighting.EMISSIVE
	add_child(_head)

	_update_trail(start)


func _update_trail(head: Vector2) -> void:
	_trail.points = PackedVector2Array([start, head])
	_core.points = PackedVector2Array([start, head])
	_head.position = head - _head.size * 0.5
	_head.rotation = _dir.angle()


func _process(delta: float) -> void:
	if _impacting:
		_process_impact(delta)
		return

	_travelled += SPEED * delta
	if _travelled >= _total:
		_travelled = _total
		_update_trail(target)
		_impact()
	else:
		_update_trail(start + _dir * _travelled)


func _process_impact(delta: float) -> void:
	_impact_t += delta

	# 궤적 즉시 페이드
	var f := 1.0 - clampf(_impact_t / TRAIL_FADE, 0.0, 1.0)
	_trail.modulate.a = f
	_core.modulate.a = f * f
	_trail.width = TRAIL_W * (0.4 + 0.6 * f)

	# 플래시: 크게 시작해 빠르게 수축
	var fk := clampf(_impact_t / FLASH_TIME, 0.0, 1.0)
	var fs := 1.0 - fk
	_flash.scale = Vector2.ONE * (0.4 + 1.6 * fs)
	_flash.modulate.a = fs
	_flash.visible = fk < 1.0

	# 충격 링: 퍼지면서 사라짐
	var rk := clampf(_impact_t / RING_TIME, 0.0, 1.0)
	_ring.scale = Vector2.ONE * (0.3 + 1.7 * rk)
	_ring.modulate.a = 1.0 - rk
	_ring.visible = rk < 1.0

	# 라이트
	if _light:
		_light.energy = 2.2 * maxf(0.0, 1.0 - _impact_t / 0.16)
		_light.enabled = _light.energy > 0.01

	# 파편
	for d in _debris:
		var n: ColorRect = d["node"]
		d["vel"].y += d["gravity"] * delta
		n.position += d["vel"] * delta
		n.rotation += d["spin"] * delta
		var center_y: float = n.position.y + n.size.y * 0.5
		if center_y >= floor_y and d["vel"].y > 0.0:
			n.position.y = floor_y - n.size.y * 0.5
			d["vel"].y = -d["vel"].y * 0.35
			d["vel"].x *= 0.6
			d["spin"] *= 0.5
		var lk: float = _impact_t / float(d["life"])
		n.modulate.a = clampf(1.0 - maxf(0.0, lk - 0.55) / 0.45, 0.0, 1.0)

	if _impact_t >= IMPACT_LIFE:
		queue_free()


func _impact() -> void:
	_impacting = true
	_head.visible = false

	# 플래시 (밝은 코어)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.97, 0.85)
	_flash.size = Vector2(24, 24)
	_flash.pivot_offset = _flash.size * 0.5
	_flash.position = target - _flash.size * 0.5
	_flash.rotation = randf_range(0.0, TAU)
	_flash.modulate = Lighting.EMISSIVE
	add_child(_flash)

	# 충격 링 (얇은 사각 테두리 4개)
	_ring = Node2D.new()
	_ring.position = target
	_ring.modulate = Lighting.EMISSIVE_SOFT
	add_child(_ring)
	var half := 17.0
	for side in range(4):
		var r := ColorRect.new()
		r.color = Color(1.0, 0.85, 0.5, 0.9)
		if side < 2:
			r.size = Vector2(half * 2.0, 3.0)
			r.position = Vector2(-half, (-half if side == 0 else half) - 1.5)
		else:
			r.size = Vector2(3.0, half * 2.0)
			r.position = Vector2((-half if side == 2 else half) - 1.5, -half)
		_ring.add_child(r)

	# 탄착 라이트
	_light = PointLight2D.new()
	_light.texture = Lighting.radial_texture()
	_light.texture_scale = Lighting.scale_for_radius(260.0)
	_light.color = Color(1.0, 0.85, 0.55)
	_light.energy = 2.2
	_light.height = Lighting.FLASH_HEIGHT          # 주변 노멀맵이 섬광에 반응
	_light.position = target
	add_child(_light)

	var back := -_dir
	var spark_n := SPARK_COUNT
	var chip_n := CHIP_COUNT
	if impact_kind == Impact.PROP:
		spark_n = int(SPARK_COUNT * 0.6)
		chip_n = int(CHIP_COUNT * 0.5)
	elif impact_kind == Impact.GLASS:
		spark_n = int(SPARK_COUNT * 0.8)
		chip_n = CHIP_COUNT + 4
	# 불꽃 스파크: 진행 반대 방향 원뿔로 빠르게, 약한 중력
	for i in range(spark_n):
		var s := ColorRect.new()
		var len := randf_range(13.0, 25.0)
		s.size = Vector2(len, 4.0)
		s.pivot_offset = s.size * 0.5
		s.color = Color(1.0, randf_range(0.7, 0.95), randf_range(0.25, 0.5))
		var v := back.rotated(randf_range(-1.1, 1.1)) * randf_range(560.0, 1150.0)
		s.position = target - s.size * 0.5
		s.rotation = v.angle()
		s.modulate = Lighting.EMISSIVE
		add_child(s)
		_debris.append({"node": s, "vel": v, "spin": 0.0, "gravity": GRAVITY * 0.35,
			"life": randf_range(0.18, 0.32)})

	# 파편: 벽=회색 조각 / 유리=밝은 청백색 얇은 조각(아래로 쏟아짐) / 프랍=나무·금속색 소량
	for i in range(chip_n):
		var c := ColorRect.new()
		var sz := randf_range(7.0, 14.0)
		c.size = Vector2(sz, sz * randf_range(0.5, 1.0))
		c.pivot_offset = c.size * 0.5
		var v := back.rotated(randf_range(-1.4, 1.4)) * randf_range(210.0, 580.0) + Vector2(0, -randf_range(60.0, 210.0))
		match impact_kind:
			Impact.GLASS:
				var gl := randf_range(0.75, 1.0)
				c.color = Color(gl * 0.85, gl * 0.95, gl, 0.95)
				c.size = Vector2(sz * 1.3, sz * randf_range(0.25, 0.5))
				v = Vector2(randf_range(-260.0, 260.0), randf_range(-120.0, 220.0))   # 사방으로 흩어지며 낙하
			Impact.PROP:
				var w := randf_range(0.35, 0.55)
				c.color = Color(w * 1.25, w * 0.95, w * 0.7)
			_:
				var g := randf_range(0.42, 0.62)
				c.color = Color(g * 0.9, g * 0.95, g * 1.15)
		c.position = target - c.size * 0.5
		c.rotation = randf_range(0.0, TAU)
		add_child(c)
		_debris.append({"node": c, "vel": v, "spin": randf_range(-18.0, 18.0), "gravity": GRAVITY,
			"life": IMPACT_LIFE})
