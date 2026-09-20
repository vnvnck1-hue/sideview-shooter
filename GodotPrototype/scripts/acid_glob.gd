class_name AcidGlob
extends Node2D
## 크롤러가 뱉는 독액 덩어리. 입에서 플레이어 몸 중심을 향해 포물선으로 날아가
## 플레이어에 닿으면(구르기 중이면 회피) Room.player_hit 를 알리고, 바닥에 닿으면 튀며 작은 독 웅덩이를 남긴다.
## 한 노드가 덩어리·꼬리 방울·웅덩이를 _draw 로 그린다. 위치는 월드 좌표 그대로.

const GRAVITY := 1900.0
const FLIGHT_TIME := 0.55
const MAX_SPEED := 1500.0
const PLAYER_HALF_W := 62.0
const PLAYER_HEIGHT := 250.0
const PUDDLE_LIFE := 4.5
const CORE := Color(0.92, 1.0, 0.55)
const BODY := Color(0.62, 0.82, 0.16)
const DARK := Color(0.38, 0.55, 0.08)

var target: Node2D
var room: Node2D
var floor_y := 0.0
var _p := Vector2.ZERO
var _v := Vector2.ZERO
var _trail: Array = []            # 지난 위치 (꼬리)
var _flying := true
var _t := 0.0
var _puddle_w := 0.0
var _light: PointLight2D


func setup(from: Vector2, player: Node2D, floor_line: float, room_node: Node2D) -> void:
	target = player
	room = room_node
	floor_y = floor_line
	_p = from
	var aim := player.position + Vector2(0, -PLAYER_HEIGHT * 0.45)
	# 플레이어가 움직이는 쪽을 조금 예측
	var pv: float = player.get("velocity_x") if player.get("velocity_x") != null else 0.0
	aim.x += pv * FLIGHT_TIME * 0.5
	var d := aim - from
	_v = (d - Vector2(0, 0.5 * GRAVITY * FLIGHT_TIME * FLIGHT_TIME)) / FLIGHT_TIME
	if _v.length() > MAX_SPEED:
		_v = _v.normalized() * MAX_SPEED
	z_index = 1


func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = Lighting.radial_texture()
	_light.texture_scale = Lighting.scale_for_radius(150.0)
	_light.color = Color(0.7, 0.95, 0.3)
	_light.energy = 0.6
	_light.height = Lighting.FLASH_HEIGHT
	add_child(_light)
	Lighting.register_dynamic(_light, 0.6, "ambient")           # 날아가는 독액 — 지나가며 그림자를 쓸고 간다
	_light.position = _p


func _process(delta: float) -> void:
	_t += delta
	if _flying:
		_v.y += GRAVITY * delta
		_p += _v * delta
		_trail.push_front(_p)
		if _trail.size() > 5:
			_trail.pop_back()
		_light.position = _p
		# 플레이어 명중 (구르기 중이면 회피)
		if target and is_instance_valid(target):
			var rolling: bool = target.has_method("is_rolling") and target.is_rolling()
			var rect := Rect2(target.position.x - PLAYER_HALF_W, target.position.y - PLAYER_HEIGHT,
				PLAYER_HALF_W * 2.0, PLAYER_HEIGHT)
			if not rolling and rect.has_point(_p):
				_splat(true)
				return
		if _p.y >= floor_y:
			_p.y = floor_y
			_splat(false)
			return
		# 벽에 닿으면 넘어가지 못하고 그 자리에서 터진다
		if RoomSolid.active != null and RoomSolid.active.is_solid(_p):
			_p = RoomSolid.active.clip_ray(_p - _v * delta, _p)
			_splat(false, false)
			return
		queue_redraw()
	else:
		_light.energy = maxf(0.0, 0.6 * (1.0 - _t / 0.25))
		_light.enabled = _light.energy > 0.01
		if _t >= PUDDLE_LIFE:
			queue_free()
			return
		queue_redraw()


## on_player: 플레이어에 명중 / puddle: 바닥 웅덩이를 남기는가 (벽에 맞으면 남기지 않는다)
func _splat(on_player: bool, puddle := true) -> void:
	_flying = false
	_t = 0.0
	_puddle_w = randf_range(48.0, 72.0) if (puddle and not on_player) else 0.0
	if not puddle:
		_t = PUDDLE_LIFE - 0.3          # 벽에 튄 독액은 자국 없이 곧 사라진다
	var sparks := SparkBurst.spawn(get_parent(), floor_y, false)
	sparks.z_index = 1
	var dir := Vector2(-signf(_v.x) * 0.3, -1.0)
	sparks.burst(_p, 14 if on_player else 10, dir, 1.0, Vector2(120, 380), CORE, DARK,
		Vector2(0.3, 0.7), 2000.0, 4.0, false)
	if on_player:
		if room and room.has_signal("player_hit"):
			room.player_hit.emit(_p, signf(_v.x))
		_t = PUDDLE_LIFE - 0.3          # 플레이어에 튄 독액은 곧 사라진다 (웅덩이 없음)
	queue_redraw()


func _draw() -> void:
	if _flying:
		# 꼬리 방울 (뒤로 갈수록 작고 어둡게)
		for i in range(_trail.size()):
			var k := float(i) / maxf(1.0, float(_trail.size() - 1))
			var sz := lerpf(14.0, 5.0, k)
			var col := BODY.lerp(DARK, k)
			col = Color(col.r * 2.2, col.g * 2.2, col.b * 2.2, 1.0 - k * 0.6)
			draw_rect(Rect2(_trail[i] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
		# 본체: 진행 방향으로 늘어진 덩어리 + 밝은 심 (발광 → 글로우)
		var dirn := _v.normalized()
		var body_col := Color(BODY.r * 2.6, BODY.g * 2.6, BODY.b * 2.6, 1.0)
		draw_rect(Rect2(_p - Vector2(13, 13), Vector2(26, 26)), body_col)
		draw_rect(Rect2(_p - dirn * 12.0 - Vector2(9, 9), Vector2(18, 18)), body_col)
		draw_rect(Rect2(_p - Vector2(6, 6), Vector2(12, 12)), Color(CORE.r * 4.0, CORE.g * 4.0, CORE.b * 4.0, 1.0))
	elif _puddle_w > 0.0:
		# 바닥 독 웅덩이: 얇은 타원형 픽셀 덩어리, 시간이 지나며 옅어진다
		var k := clampf(_t / PUDDLE_LIFE, 0.0, 1.0)
		var a := 1.0 - smoothstep(0.55, 1.0, k)
		var w := _puddle_w * (0.6 + 0.4 * minf(1.0, _t / 0.15))
		var col := Color(BODY.r * 1.1, BODY.g * 1.1, BODY.b * 1.1, 0.85 * a)     # 바닥 웅덩이는 덜 빛난다
		draw_rect(Rect2(_p.x - w * 0.5, _p.y - 5.0, w, 5.0), col)
		draw_rect(Rect2(_p.x - w * 0.3, _p.y - 9.0, w * 0.6, 4.0), col)
		draw_rect(Rect2(_p.x - w * 0.12, _p.y - 12.0, w * 0.24, 3.0),
			Color(CORE.r * 1.2, CORE.g * 1.2, CORE.b * 1.2, 0.8 * a))
