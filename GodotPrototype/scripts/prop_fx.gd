class_name PropFx
extends Node2D
## 장애물 프랍의 재질 파티클 — 나무 파편·톱밥, 돌 조각·분진, 가스 분출, 불씨, 폭발 연기.
## 한 노드가 알갱이 여럿을 _draw 로 그린다. 모든 위치·크기는 4px 격자(1 art px)에 맞춰 찍어
## 캐릭터·프랍 원화와 같은 픽셀 밀도로 보이게 한다.
##   chip : 단단한 조각. 중력·회전·바닥 튕김 후 눕는다 (나무 파편, 돌, 쇳조각, 불씨)
##   puff : 뭉게 덩어리 텍스처. 공기 저항으로 멎고 부풀며 사라진다 (톱밥, 분진, 가스, 연기)
## glow = true 면 라이트를 무시하고 밝기를 올려 CanvasModulate 어둠을 이긴다 (불씨·불꽃).

const GRID := 4.0
const PUFF_VARIANTS := 4

var floor_y := 100000.0
var glow := false
var tag := ""                     # 검사·디버그용 ("leak", "wood", ...)
var _parts: Array = []
var _drawn := false
static var _puff_tex: Array = []
## 라이팅을 받는 쪽(먼지·파편·균열)의 밝기 보정. 기본 재질은 인물층에서 램프 빛을 약하게만 받아
## 앰비언트(CanvasModulate ≈0.3)에 묻힌다 — 색을 이만큼 올려 두면 어둠 속에서도 원래 색 근처로 읽히고,
## 램프 아래에서는 밝게 뜬다. (lit_surface 는 정점 색을 무시해 쓸 수 없다)
const LIT_BOOST := 1.6          # 단단한 조각
const PUFF_BOOST := 1.25        # 먼지·가스 — 반투명이 겹쳐 쌓이므로 더 낮게


static func make(parent: Node, floor_line: float, glowing := false, z := 6, kind_tag := "") -> PropFx:
	var fx := PropFx.new()
	fx.floor_y = floor_line
	fx.glow = glowing
	fx.z_index = z
	fx.tag = kind_tag
	fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if glowing:
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		fx.material = mat
	parent.add_child(fx)
	return fx


## 16×16 art px 뭉게 덩어리. 원 서너 개를 겹친 울퉁불퉁한 외곽 + 아래쪽 한 톤 어두운 그늘.
static func puff_texture(i: int) -> Texture2D:
	if _puff_tex.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 9127
		for v in range(PUFF_VARIANTS):
			var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			var blobs: Array = [[Vector2(8, 8.5), 5.6]]
			for b in range(3 + v % 2):
				blobs.append([Vector2(rng.randf_range(4.5, 11.5), rng.randf_range(4.5, 11.0)), rng.randf_range(2.6, 4.2)])
			for y in range(16):
				for x in range(16):
					var inside := false
					var depth := 0.0
					for blob in blobs:
						var d: float = (Vector2(x + 0.5, y + 0.5) - blob[0]).length() / float(blob[1])
						if d < 1.0:
							inside = true
							depth = maxf(depth, 1.0 - d)
					if inside:
						# 아래·가장자리는 조금 어둡게 — 평면 원판이 아니라 덩어리로 읽힌다
						var shade := 0.78 if (y > 10 or depth < 0.18) else 1.0
						img.set_pixel(x, y, Color(shade, shade, shade, 1.0))
			_puff_tex.append(ImageTexture.create_from_image(img))
	return _puff_tex[i % PUFF_VARIANTS]


func chip(p: Vector2, v: Vector2, size: Vector2, col: Color, life: float, gravity := 2200.0,
		spin := 0.0, bounce := 0.3, end_col := Color(-1, 0, 0), drag := 0.0) -> void:
	_parts.append({"t": 0, "p": p, "v": v, "size": size, "col": col, "end": col if end_col.r < 0.0 else end_col,
		"life": life, "age": 0.0, "g": gravity, "rot": randf_range(-0.6, 0.6) if spin != 0.0 else 0.0,
		"spin": spin, "bounce": bounce, "rest": false, "drag": drag})


func puff(p: Vector2, v: Vector2, size: float, col: Color, life: float, grow := 1.2,
		drag := 3.0, gravity := -20.0, delay := 0.0) -> void:
	_parts.append({"t": 1, "p": p, "v": v, "size": size, "col": col, "life": life, "age": -delay,
		"grow": grow, "drag": drag, "g": gravity, "var": randi() % PUFF_VARIANTS, "flip": randf() < 0.5})


func _process(delta: float) -> void:
	var i := 0
	while i < _parts.size():
		var s: Dictionary = _parts[i]
		s.age += delta
		if s.age >= s.life:
			_parts.remove_at(i)
			continue
		if s.age < 0.0:
			i += 1
			continue
		if s.t == 0:
			_step_chip(s, delta)
		else:
			s.v *= exp(-float(s.drag) * delta)
			s.v.y += float(s.g) * delta
			s.p += s.v * delta
		i += 1
	if not _parts.is_empty() or _drawn:
		queue_redraw()
	if _parts.is_empty():
		queue_free()


func _step_chip(s: Dictionary, delta: float) -> void:
	if s.rest:
		return
	s.v.y += float(s.g) * delta
	if float(s.drag) > 0.0:
		s.v *= exp(-float(s.drag) * delta)
	var p: Vector2 = s.p + s.v * delta
	var hit := RoomSolid.bounce_walls(p, s.v, 0.3)
	p = hit[0]
	s.v = hit[1]
	s.rot += float(s.spin) * delta
	var half: float = maxf(s.size.x, s.size.y) * 0.25
	if p.y + half >= floor_y and s.v.y > 0.0:
		p.y = floor_y - half
		s.v = Vector2(s.v.x * 0.5, -s.v.y * float(s.bounce))
		s.spin *= 0.45
		if absf(s.v.y) < 70.0:
			s.v = Vector2.ZERO
			s.rest = true
			s.rot = roundf(float(s.rot) / (PI * 0.5)) * PI * 0.5   # 바닥에 눕는다
			s.p = Vector2(p.x, floor_y - minf(s.size.x, s.size.y) * 0.5)
			return
	s.p = p


func _draw() -> void:
	_drawn = not _parts.is_empty()
	for s in _parts:
		if s.age < 0.0:
			continue
		var k: float = s.age / s.life
		if s.t == 0:
			var col: Color = (s.col as Color).lerp(s.end, smoothstep(0.0, 0.7, k))
			col.a *= 1.0 - smoothstep(0.75, 1.0, k)
			if glow:
				var b := lerpf(3.2, 1.3, k)
				col = Color(col.r * b, col.g * b, col.b * b, col.a)
			else:
				col = Color(col.r * LIT_BOOST, col.g * LIT_BOOST, col.b * LIT_BOOST, col.a)
			var sz: Vector2 = s.size
			var p: Vector2 = (s.p as Vector2).snapped(Vector2(GRID, GRID))
			if is_zero_approx(float(s.rot)):
				draw_rect(Rect2(p - sz * 0.5, sz), col)
			else:
				draw_set_transform(p, snappedf(float(s.rot), PI / 8.0), Vector2.ONE)
				draw_rect(Rect2(-sz * 0.5, sz), col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var col: Color = s.col
			col.a *= smoothstep(0.0, 0.08, k) * pow(1.0 - k, 1.4)
			if glow:
				var b := lerpf(3.0, 1.0, k)
				col = Color(col.r * b, col.g * b, col.b * b, col.a)
			else:
				col = Color(col.r * PUFF_BOOST, col.g * PUFF_BOOST, col.b * PUFF_BOOST, col.a)
			var size: float = snappedf(float(s.size) * (1.0 + float(s.grow) * sqrt(k)), GRID * 2.0)
			var p: Vector2 = (s.p as Vector2).snapped(Vector2(GRID, GRID))
			var r := Rect2(p - Vector2(size, size) * 0.5, Vector2(size, size))
			if s.flip:
				r = Rect2(r.position + Vector2(r.size.x, 0), Vector2(-r.size.x, r.size.y))
			draw_texture_rect(puff_texture(s.var), r, false, col)


# ------------------------------------------------------------------ 재질별 프리셋

const WOOD := [Color(0.62, 0.38, 0.18), Color(0.48, 0.28, 0.13), Color(0.74, 0.5, 0.26), Color(0.34, 0.19, 0.09)]
const STONE := [Color(0.62, 0.62, 0.66), Color(0.5, 0.5, 0.55), Color(0.74, 0.72, 0.74), Color(0.38, 0.38, 0.44)]
const DUST_WOOD := Color(0.5, 0.42, 0.33, 0.5)
const DUST_STONE := Color(0.46, 0.46, 0.5, 0.5)


## 한 발 맞은 자리: 나무는 가시 같은 파편 + 톱밥, 돌은 자갈 + 분진. out = 탄이 튀어나오는 방향(쏜 쪽).
static func hit_chips(room: Node2D, point: Vector2, out: Vector2, material_id: String, power := 1.0) -> void:
	var floor_line: float = room.floor_y
	var fx := make(room, floor_line, false, 6, material_id)
	var n := int(clampf(4.0 + power * 2.0, 4.0, 10.0))
	for i in range(n):
		var v := out.rotated(randf_range(-0.9, 0.9)) * randf_range(180, 520) + Vector2(0, -randf_range(80, 260))
		if material_id == "wood":
			fx.chip(point, v, Vector2(4, [8, 8, 12, 16][randi() % 4]), WOOD[randi() % WOOD.size()],
				randf_range(0.9, 1.6), 2200.0, randf_range(-22, 22), 0.25)
		else:
			var s: float = [4.0, 4.0, 8.0][randi() % 3]
			fx.chip(point, v, Vector2(s, s), STONE[randi() % STONE.size()], randf_range(0.8, 1.4), 2400.0, 0.0, 0.35)
	var dust: Color = DUST_WOOD if material_id == "wood" else DUST_STONE
	for i in range(2):
		fx.puff(point + Vector2(randf_range(-6, 6), randf_range(-6, 6)), out * randf_range(90, 180) + Vector2(0, -30),
			randf_range(24, 36), dust, randf_range(0.45, 0.7), 1.3, 4.0, -40.0)


## 파괴: rect 전체에서 한꺼번에 터져 나온다. 목재 = 긴 판자 조각·쇠 모서리 장식·톱밥 구름,
## 콘크리트 = 자갈·철근 토막·두꺼운 분진 구름. 두 경우 모두 바닥을 타고 좌우로 번지는 먼지 띠를 깐다.
static func break_burst(room: Node2D, rect: Rect2, hit_point: Vector2, dir: float, material_id: String) -> void:
	var floor_line: float = room.floor_y
	var fx := make(room, floor_line, false, 7, material_id + "_break")
	var wood := material_id == "wood"
	var center := rect.get_center()
	for i in range(30 if wood else 34):
		var from := Vector2(randf_range(rect.position.x + 8, rect.end.x - 8), randf_range(rect.position.y + 8, rect.end.y - 8))
		var away := (from - hit_point).normalized() if from.distance_to(hit_point) > 4.0 else Vector2(dir, -1).normalized()
		var v := (away * 0.55 + Vector2(dir * 0.45, -0.75)).normalized() * randf_range(260, 860)
		if wood:
			var long: float = [12.0, 16.0, 20.0, 28.0, 36.0][randi() % 5]
			var sz := Vector2(long, 4) if randf() < 0.6 else Vector2(4, long)
			fx.chip(from, v, sz, WOOD[randi() % WOOD.size()], randf_range(1.6, 2.8), 2300.0, randf_range(-18, 18), 0.3)
		else:
			var s: float = [4.0, 8.0, 8.0, 12.0, 16.0][randi() % 5]
			fx.chip(from, v * 0.8, Vector2(s, s), STONE[randi() % STONE.size()], randf_range(1.4, 2.6), 2600.0,
				randf_range(-8, 8) if s >= 12.0 else 0.0, 0.3)
	# 쇠 부속: 상자의 모서리 장식·못 / 콘크리트의 녹슨 철근 토막
	for i in range(5):
		var v := Vector2(dir * randf_range(120, 420) + randf_range(-200, 200), -randf_range(500, 900))
		if wood:
			fx.chip(center, v, Vector2(8, 8), Color(0.3, 0.32, 0.26), randf_range(1.8, 2.6), 2400.0, randf_range(-10, 10), 0.4)
		else:
			fx.chip(center, v, Vector2(4, [16, 24][randi() % 2]), Color(0.52, 0.22, 0.16), randf_range(1.8, 2.6), 2400.0, randf_range(-14, 14), 0.35)
	var dust: Color = DUST_WOOD if wood else DUST_STONE
	# 몸통 크기만 한 분진 구름 — 상자가 있던 자리가 한순간 먼지로 가려졌다가 걷힌다
	for i in range(10 if wood else 16):
		var at := Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y + rect.size.y * 0.2, rect.end.y))
		fx.puff(at, (at - center).normalized() * randf_range(60, 220) + Vector2(dir * 60, -40), randf_range(40, 72) * (1.0 if wood else 1.25),
			dust, randf_range(0.8, 1.3) * (1.0 if wood else 1.5), 1.6, 3.2, -30.0, randf_range(0.0, 0.08))
	floor_wave(fx, Vector2(center.x, floor_line - 10), rect.size.x * 0.5, dust, 1.0 if wood else 1.3)


## 바닥을 타고 양옆으로 번지는 먼지 띠 (착지·파괴·폭발 공통)
static func floor_wave(fx: PropFx, at: Vector2, half_width: float, col: Color, strength := 1.0, count := 8) -> void:
	for side in [-1.0, 1.0]:
		for i in range(count / 2):
			var p := at + Vector2(side * randf_range(0, half_width * 0.6), randf_range(-6, 4))
			fx.puff(p, Vector2(side * randf_range(260, 620) * strength, -randf_range(10, 50)), randf_range(28, 48) * strength,
				col, randf_range(0.7, 1.1) * strength, 1.4, 4.5, -18.0, randf_range(0.0, 0.05))


## 구멍 난 가스통에서 새는 가스 한 모금. dir = 분출 방향. burning 이면 불꽃 혀가 된다(점화 직전).
static func gas_jet(room: Node2D, at: Vector2, dir: Vector2, burning := false) -> void:
	var fx := make(room, room.floor_y, burning, 8, "leak")
	for i in range(3 if not burning else 4):
		var v := dir.rotated(randf_range(-0.18, 0.18)) * randf_range(420, 760)
		if burning:
			fx.puff(at + dir * 8.0, v * 1.1, randf_range(20, 36), [Color(1.0, 0.72, 0.25, 0.95), Color(1.0, 0.45, 0.12, 0.9), Color(1.0, 0.9, 0.55, 1.0)][i % 4 % 3],
				randf_range(0.2, 0.34), 2.0, 6.5, -300.0)
		else:
			# 구멍 바로 앞은 좁고 빠른 흰 줄기, 멀어지며 퍼져 옅어진다
			fx.puff(at + dir * 6.0, v, randf_range(16, 24), Color(0.86, 0.9, 0.92, 0.75), randf_range(0.45, 0.7), 3.2, 5.0, -70.0)
	if not burning and randf() < 0.5:
		fx.chip(at, dir.rotated(randf_range(-0.3, 0.3)) * randf_range(300, 500), Vector2(4, 4), Color(0.95, 0.97, 1.0, 0.9), 0.25, 300.0)
