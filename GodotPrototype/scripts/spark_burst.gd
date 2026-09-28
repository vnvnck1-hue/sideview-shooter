class_name SparkBurst
extends Node2D
## 뜨거운 불꽃 알갱이 뭉치. 중력을 받아 떨어지고 바닥에서 튕기며, 흰 열 → 붉은 열로 식으며 사라진다.
## 한 노드가 여러 알갱이를 _draw 로 그린다(노드 수 절약). 위치는 월드 좌표를 그대로 쓴다.
## 전구 파손·끊긴 전선·비상등 파손이 공유한다.
## sprite_row >= 0 이면 절차 사각형 대신 MonsterFx 아틀라스의 실제 체액 스프라이트를 쓴다.

var floor_y := 100000.0
var persistent := false          # true 면 알갱이가 다 죽어도 노드를 유지 (전선처럼 계속 뿜는 곳)
var _sparks: Array = []           # {p, v, life, age, size, hot(Color), cold(Color), spin}
var _light: PointLight2D
var _light_t := 0.0
var _drawn := false               # 마지막 _draw 에 알갱이가 있었나 (비었으면 한 번 지운 뒤 다시 그리지 않는다)


static func spawn(parent: Node, floor_line: float, keep := false) -> SparkBurst:
	var sb := SparkBurst.new()
	sb.floor_y = floor_line
	sb.persistent = keep
	parent.add_child(sb)
	return sb


## dir: 중심 방향, spread: 각도 반폭(rad). hot→cold 색으로 식는다.
func burst(pos: Vector2, count: int, dir := Vector2(0, 1), spread := PI, speed := Vector2(180, 520),
		hot := Color(1.0, 0.9, 0.7), cold := Color(1.0, 0.25, 0.08), life := Vector2(0.35, 0.9),
		gravity := 2200.0, size := 3.0, with_light := true, glow := 1.0, sprite_row := -1) -> void:
	for i in range(count):
		var v := dir.normalized().rotated(randf_range(-spread, spread)) * randf_range(speed.x, speed.y)
		_sparks.append({
			"p": pos, "v": v, "life": randf_range(life.x, life.y), "age": 0.0,
			"size": size * randf_range(0.7, 1.3), "hot": hot, "cold": cold, "g": gravity,
			"bounce": randf_range(0.25, 0.5), "glow": glow,
			"sprite_row": sprite_row, "variant": randi_range(0, MonsterFx.VARIANTS - 1),
			"rot": randf_range(-0.45, 0.45),
		})
	if with_light:
		_flash_light(pos, minf(0.6 + count * 0.06, 2.4), cold.lerp(hot, 0.4))
	queue_redraw()


func _flash_light(pos: Vector2, energy: float, col: Color) -> void:
	if _light == null:
		_light = PointLight2D.new()
		_light.texture = Lighting.radial_texture()
		_light.texture_scale = Lighting.scale_for_radius(LightTuning.value("spark", "radius", 240.0))
		_light.height = LightTuning.value("spark", "height", Lighting.FLASH_HEIGHT)
		add_child(_light)
		Lighting.register_dynamic(_light, 0.8, "ambient")
	_light.position = pos
	_light.color = col
	_light.energy = energy * LightTuning.value("spark", "energy", 1.0)
	_light.enabled = true
	_light_t = 0.14


func _process(delta: float) -> void:
	# 빈 채로 쉬는 중(몬스터마다 붙은 persistent 노드의 대부분 시간) — 알갱이 루프·다시 그리기를 건너뛴다.
	# _process 자체는 끄지 않는다: 다시 켜면 그 프레임 적분이 한 번 빠질 수 있어 알갱이 궤적이 달라진다.
	if _sparks.is_empty() and (_light == null or not _light.enabled):
		if _drawn:
			queue_redraw()
		if not persistent:
			queue_free()
		return
	if _light and _light.enabled:
		_light_t -= delta
		_light.energy = maxf(_light.energy - delta * 12.0, 0.0)
		if _light_t <= 0.0 or _light.energy <= 0.02:
			_light.enabled = false
	var i := 0
	while i < _sparks.size():
		var s: Dictionary = _sparks[i]
		s["age"] += delta
		if s["age"] >= s["life"]:
			_sparks.remove_at(i)
			continue
		var v: Vector2 = s["v"]
		v.y += s["g"] * delta
		var p: Vector2 = s["p"] + v * delta
		var hit := RoomSolid.bounce_walls(p, v, s["bounce"])
		p = hit[0]
		v = hit[1]
		if p.y >= floor_y and v.y > 0.0:
			p.y = floor_y
			v.y = -v.y * s["bounce"]
			v.x *= 0.55
			if absf(v.y) < 40.0:
				v.y = 0.0
		s["v"] = v
		s["p"] = p
		i += 1
	# 알갱이가 없으면 다시 그릴 것도 없다 — 마지막 알갱이가 사라진 뒤 한 번만 지운다.
	# (몬스터마다 붙은 persistent 노드가 빈 채로 매 프레임 다시 그려지고 있었다)
	if not _sparks.is_empty() or _drawn:
		queue_redraw()
	if _sparks.is_empty() and (_light == null or not _light.enabled):
		if not persistent:
			queue_free()


func _draw() -> void:
	_drawn = not _sparks.is_empty()
	for s in _sparks:
		var k: float = s["age"] / s["life"]
		var col: Color = s["hot"].lerp(s["cold"], smoothstep(0.0, 0.6, k))
		var bright := lerpf(4.2, 1.6, k) * float(s.get("glow", 1.0))   # CanvasModulate 를 이겨 글로우에 닿는 발광 (체액은 glow<1 로 둔하게)
		col = Color(col.r * bright, col.g * bright, col.b * bright, 1.0 - smoothstep(0.7, 1.0, k))
		var p: Vector2 = s["p"]
		var v: Vector2 = s["v"]
		var sprite_row: int = int(s.get("sprite_row", -1))
		if sprite_row >= 0:
			var sz: float = float(s["size"])
			var stretch := clampf(v.length() / 420.0, 0.85, 1.65)
			var draw_size := Vector2(sz * 3.2, sz * 3.2 * stretch)
			var rot := v.angle() - PI * 0.5 + float(s["rot"])
			draw_set_transform(p, rot, Vector2.ONE)
			MonsterFx.draw(self, sprite_row, int(s["variant"]), Rect2(-draw_size * 0.5, draw_size), col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var tail := v * 0.018 * (1.0 - k * 0.5)
		if tail.length() > s["size"]:
			draw_line(p - tail, p, col, s["size"])
		else:
			var sz: float = s["size"]
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
