class_name WaterPool
extends Node2D
## 바닥에 고인 물 (fx "water"). 수면선 아래 방 전체(또는 x0~x1)를 덮는 Polygon2D 하나에
## water_surface.gdshader 를 올려 이미 그려진 화면을 수면선 기준으로 반사·굴절한다.
## 인물·몬스터가 반사에 들어가야 하므로 Room 이 인물 층(z5) 위, 탄 층과 같은 z6 에 올린다.
##
## 수면은 **스프링 열**(Hoffman 방식)로 살아 있다: SPACING px 마다 높이·속도 하나. 매 스텝 각 점이 원위치로 당겨지고
## 이웃끼리 높이 차를 나눠 파문이 좌우로 퍼진다. 높이는 N×1 RF 텍스처로 셰이더에 넘기고, 셰이더가 수면선을 그만큼
## 올리고 기울기로 반사를 흔든다. 탄착·탄피·파편·물방울이 수면을 지나면 splash(), 플레이어가 걸으면 wake().
## 다른 노드는 정적 WaterPool.active 로 현재 방의 물을 찾는다 (방마다 최대 하나).
##
## 데이터: {"type": "water", "level": 수면선이 바닥선 위로 올라오는 px(기본 26), "x0"/"x1": 선택 범위, "tint": 선택 색}

const DEFAULT_LEVEL := 26.0
const SPACING := 4.0              # 스프링 간격 (월드 px) = 뷰 1px — 잔물결이 픽셀 단위로 갈라진다
const MAX_AMP := 22.0             # 파고 상한 (월드 px = 뷰 5~6px)
const SIM_DT := 1.0 / 60.0
const TENSION := 0.018            # 원위치 복원 (스텝당) — 낮을수록 파동이 오래·멀리 간다
const DAMPING := 0.012            # 감쇠 — 낮을수록 멀리 퍼진다 (0.045 → 0.012)
const SPREAD := 0.24              # 이웃 전파 (간격 4px; 패스 수와 함께 전파 속도를 정한다)
const SPREAD_PASSES := 10
const PUSH := 5.5                 # disturb 세기 1.0 당 속도 (px/스텝) — 파고를 키움
const DROP_GRAVITY := 1500.0

static var active: WaterPool = null     # 현재 방의 물 (Room 이 만들 때 설정, 사라질 때 해제)

var surface_y := 0.0
var x0 := 0.0
var x1 := 0.0
var _poly: Polygon2D
var _mat: ShaderMaterial
var _n := 0
var _h := PackedFloat32Array()
var _v := PackedFloat32Array()
var _ld := PackedFloat32Array()
var _rd := PackedFloat32Array()
var _img: Image
var _tex: ImageTexture
var _acc := 0.0
var _drops: Array = []            # {p, v, life, age, size, core}
var _spouts: Array = []           # 물기둥 {x, age, life, h(최대 높이 px), w(밑폭 px), lean(기울기)}
var _rings: Array = []            # 수면 물보라 고리 {x, age, life, r(최대 반지름 px)}
var _wake_acc := 0.0


func setup(fx: Dictionary, room_width: float, floor_line: float, room_bottom: float) -> void:
	var level := float(fx.get("level", DEFAULT_LEVEL))
	surface_y = floor_line - level
	x0 = float(fx.get("x0", 0.0))
	x1 = float(fx.get("x1", room_width))
	var top := surface_y - MAX_AMP - 4.0
	var bottom := room_bottom

	_n = int(ceilf((x1 - x0) / SPACING)) + 1
	_h.resize(_n); _v.resize(_n); _ld.resize(_n); _rd.resize(_n)
	_h.fill(0.0); _v.fill(0.0)
	_img = Image.create_from_data(_n, 1, false, Image.FORMAT_RF, _h.to_byte_array())
	_tex = ImageTexture.create_from_image(_img)

	_poly = Polygon2D.new()
	_poly.name = "Surface"
	_poly.polygon = PackedVector2Array([
		Vector2(x0, top), Vector2(x1, top), Vector2(x1, bottom), Vector2(x0, bottom),
	])
	_poly.texture = Lighting.white_texture()
	_poly.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_mat = Lighting.shader_material("water_surface")
	_mat.set_shader_parameter("surface_y", surface_y)
	_mat.set_shader_parameter("depth_px", bottom - surface_y)
	_mat.set_shader_parameter("height_tex", _tex)
	_mat.set_shader_parameter("x_range", Vector2(x0, x1))
	var tint: Color = fx.get("tint", Color(0.22, 0.38, 0.55))
	_mat.set_shader_parameter("water_tint", Vector3(tint.r, tint.g, tint.b))
	var amb := Lighting.AMBIENT
	_mat.set_shader_parameter("ambient_inv", Vector3(1.0 / maxf(amb.r, 0.05), 1.0 / maxf(amb.g, 0.05), 1.0 / maxf(amb.b, 0.05)))
	_poly.material = _mat
	add_child(_poly)
	active = self


func _exit_tree() -> void:
	if active == self:
		active = null


## 먼지 레이어용 — 물은 광원이 아니다 (인터페이스 통일용)
func light_info() -> Dictionary:
	return {}


## x 가 물 범위 안인가
func covers(x: float) -> bool:
	return x >= x0 and x <= x1


## 점(월드)이 물속인가 (현재 수면 높이 기준)
func contains(p: Vector2) -> bool:
	return covers(p.x) and p.y >= surface_at(p.x)


## x 에서의 현재 수면 y (월드). 위로 솟으면 작아진다.
func surface_at(x: float) -> float:
	if _n == 0:
		return surface_y
	var i := clampi(int(roundf((x - x0) / SPACING)), 0, _n - 1)
	return surface_y - _h[i]


## prev_y → new_y 로 움직이며 수면을 위→아래로 통과했나 (낙하물 착수 판정)
func crossed(x: float, prev_y: float, new_y: float) -> bool:
	if not covers(x):
		return false
	var s := surface_at(x)
	return prev_y < s and new_y >= s


## 수면을 누른다. strength 1.0 ≈ 총알 착수. 이웃 몇 칸에 함께 준다.
func disturb(x: float, strength: float, radius_px := 12.0) -> void:
	if _n == 0 or not covers(x):
		return
	var c := (x - x0) / SPACING
	var r := maxf(radius_px / SPACING, 0.5)
	var lo := maxi(int(floorf(c - r)), 0)
	var hi := mini(int(ceilf(c + r)), _n - 1)
	for i in range(lo, hi + 1):
		var k := 1.0 - absf(float(i) - c) / (r + 0.001)
		if k > 0.0:
			_v[i] -= strength * PUSH * k          # h 는 위가 양수 → 누르면 음의 속도


## 착수: 수면 눌림 + 물방울이 튄다 (count 는 세기에 비례)
func splash(x: float, strength := 1.0) -> void:
	if not covers(x):
		return
	disturb(x, strength, 6.0 + 8.0 * strength)
	var n := int(roundf(3.0 + 9.0 * strength))
	var sy := surface_at(x)
	for k in range(n):
		var sv := Vector2(randf_range(-190.0, 190.0) * (0.5 + 0.5 * strength), -randf_range(160.0, 420.0) * (0.55 + 0.45 * strength))
		_drops.append({"p": Vector2(x + randf_range(-4.0, 4.0), sy), "v": sv,
			"life": randf_range(0.3, 0.7), "age": 0.0, "size": randf_range(1.5, 3.0)})
	queue_redraw()


## 총알 착수: 수면이 크게 파이고 되튀며 좌우로 멀리 출렁이고, 물기둥이 팍 솟는다.
## shot_dir: 총알 진행 방향(±1) — 물기둥이 그쪽으로 살짝 기울고 물보라도 그쪽으로 더 튄다.
func bullet_splash(x: float, shot_dir := 0.0) -> void:
	if not covers(x):
		return
	# 1) 수면: 중심을 깊게 누르고 양옆을 살짝 들어 왕관 모양 → 스프링이 되튀며 큰 파동이 멀리 간다
	disturb(x, 2.2, 10.0)
	disturb(x - 18.0, -0.6, 8.0)
	disturb(x + 18.0, -0.6, 8.0)
	var sy := surface_at(x)
	# 2) 물기둥 (중심 굵은 기둥 + 옆에 가는 기둥 1~3개). 높이·굵기·기울기를 매번 크게 다르게, 수명은 짧게(60%)
	_spouts.append({"x": x + randf_range(-4.0, 4.0), "age": 0.0, "life": randf_range(0.25, 0.38),
		"h": randf_range(70.0, 175.0), "w": randf_range(12.0, 28.0),
		"lean": shot_dir * randf_range(-0.05, 0.32) + randf_range(-0.12, 0.12)})
	for k in range(randi_range(1, 3)):
		var side := -1.0 if k % 2 == 0 else 1.0
		_spouts.append({"x": x + side * randf_range(6.0, 26.0), "age": randf_range(0.0, 0.06), "life": randf_range(0.15, 0.26),
			"h": randf_range(22.0, 95.0), "w": randf_range(4.0, 11.0),
			"lean": side * randf_range(0.08, 0.6) + shot_dir * randf_range(0.0, 0.2)})
	# 3) 물보라: 위로 빠르게 솟는 굵은 방울(심) + 사방으로 흩어지는 잔방울. 크기·각도·속도 분산 확대, 수명 60%
	for k in range(randi_range(7, 12)):
		var sv := Vector2(randf_range(-130.0, 130.0) + shot_dir * randf_range(0.0, 90.0), -randf_range(380.0, 900.0))
		_drops.append({"p": Vector2(x + randf_range(-6.0, 6.0), sy), "v": sv,
			"life": randf_range(0.30, 0.56), "age": 0.0, "size": randf_range(2.0, 6.0), "core": true})
	for k in range(randi_range(16, 26)):
		var sv := Vector2(randf_range(-420.0, 420.0) + shot_dir * randf_range(0.0, 160.0), -randf_range(120.0, 640.0))
		_drops.append({"p": Vector2(x + randf_range(-10.0, 10.0), sy), "v": sv,
			"life": randf_range(0.20, 0.50), "age": 0.0, "size": randf_range(1.0, 3.5), "core": false})
	# 4) 수면 물보라 고리 (좌우로 퍼지는 밝은 점선)
	_rings.append({"x": x, "age": 0.0, "life": 0.3, "r": randf_range(55.0, 90.0)})
	queue_redraw()


## 플레이어가 물속을 걷는다: 속도에 비례해 발 주위 수면이 계속 술렁인다
func wake(x: float, vx: float, delta: float) -> void:
	var sp := absf(vx)
	if sp < 30.0 or not covers(x):
		return
	_wake_acc += delta * (sp / 588.0)
	if _wake_acc >= 0.055:
		_wake_acc = 0.0
		var side := signf(vx)
		disturb(x + side * 10.0, 0.12 + 0.18 * (sp / 588.0), 8.0)
		if randf() < 0.35:
			var sy := surface_at(x)
			_drops.append({"p": Vector2(x + side * randf_range(4.0, 14.0), sy), "v": Vector2(side * randf_range(40.0, 160.0), -randf_range(90.0, 220.0)),
				"life": randf_range(0.2, 0.4), "age": 0.0, "size": randf_range(1.5, 2.5)})


func _process(delta: float) -> void:
	_acc += minf(delta, 0.1)
	var stepped := false
	while _acc >= SIM_DT:
		_acc -= SIM_DT
		_step()
		stepped = true
	if stepped:
		_img.set_data(_n, 1, false, Image.FORMAT_RF, _h.to_byte_array())
		_tex.update(_img)
	_tick_drops(delta)
	_tick_fx(delta)


func _tick_fx(delta: float) -> void:
	if _spouts.is_empty() and _rings.is_empty():
		return
	var i := 0
	while i < _spouts.size():
		_spouts[i]["age"] += delta
		if _spouts[i]["age"] >= _spouts[i]["life"]:
			_spouts.remove_at(i)
		else:
			i += 1
	i = 0
	while i < _rings.size():
		_rings[i]["age"] += delta
		if _rings[i]["age"] >= _rings[i]["life"]:
			_rings.remove_at(i)
		else:
			i += 1
	queue_redraw()


## 스프링 한 스텝 (Hoffman): 복원 + 감쇠, 그 다음 이웃 전파 여러 번
func _step() -> void:
	for i in range(_n):
		var a := -TENSION * _h[i] - DAMPING * _v[i]
		_v[i] += a
		_h[i] += _v[i]
	for pass_i in range(SPREAD_PASSES):
		for i in range(_n):
			if i > 0:
				_ld[i] = SPREAD * (_h[i] - _h[i - 1])
				_v[i - 1] += _ld[i]
			if i < _n - 1:
				_rd[i] = SPREAD * (_h[i] - _h[i + 1])
				_v[i + 1] += _rd[i]
		for i in range(_n):
			if i > 0:
				_h[i - 1] += _ld[i]
			if i < _n - 1:
				_h[i + 1] += _rd[i]
	for i in range(_n):
		_h[i] = clampf(_h[i], -MAX_AMP, MAX_AMP)


func _tick_drops(delta: float) -> void:
	if _drops.is_empty():
		return
	var i := 0
	while i < _drops.size():
		var d: Dictionary = _drops[i]
		d["age"] += delta
		var v: Vector2 = d["v"]
		v.y += DROP_GRAVITY * delta
		var p: Vector2 = d["p"] + v * delta
		var dead: bool = d["age"] >= d["life"]
		if v.y > 0.0 and p.y >= surface_at(p.x) and d["age"] > 0.05:
			dead = true
			disturb(p.x, 0.16 if d.get("core", false) else 0.05, 4.0)
		d["v"] = v
		d["p"] = p
		if dead:
			_drops.remove_at(i)
		else:
			i += 1
	queue_redraw()


func _draw() -> void:
	var base := Lighting.WATER
	# 물기둥: 4px 블록으로 쌓은 기둥. 올라갈 땐 빠르게(sin^0.6), 내려올 땐 무너지며 가늘어진다.
	for sp in _spouts:
		var k: float = sp["age"] / sp["life"]
		var rise := pow(sin(k * PI), 0.6)
		var h: float = sp["h"] * rise
		var w: float = sp["w"] * (1.0 - k * 0.55)
		var sx: float = sp["x"]
		var sy := surface_at(sx)
		var lean: float = sp["lean"]
		var y := 0.0
		while y < h:
			var seg := 4.0
			var t := y / maxf(h, 1.0)
			var ww := maxf(4.0, roundf(w * (1.0 - t * 0.6) / 4.0) * 4.0)   # 위로 갈수록 가늘게, 4px 격자
			var cx := sx + lean * y
			var bright := 1.5 + 0.9 * t                                      # 꼭대기가 가장 밝다
			var a := 0.9 * (1.0 - k * k * 0.7)
			var col := Color(base.r * bright, base.g * bright, base.b * bright, a)
			if t > 0.75:
				col = Color(0.85 * bright, 0.93 * bright, 1.0 * bright, a)   # 흰 물보라 꼭대기
			draw_rect(Rect2(roundf((cx - ww * 0.5) / 4.0) * 4.0, sy - y - seg, ww, seg), col)
			y += seg
	# 수면 물보라 고리: 중심에서 좌우로 퍼지는 밝은 점선 (수면 위 1~2px)
	for rg in _rings:
		var k: float = rg["age"] / rg["life"]
		var r: float = rg["r"] * sqrt(k)
		var a := (1.0 - k) * 0.9
		var col := Color(0.8, 0.92, 1.0, a)
		for side in [-1.0, 1.0]:
			var px: float = rg["x"] + side * r
			draw_rect(Rect2(roundf(px / 4.0) * 4.0, surface_at(px) - 4.0, 4.0, 4.0), col)
			if k < 0.5:
				draw_rect(Rect2(roundf((px - side * 8.0) / 4.0) * 4.0, surface_at(px) - 2.0, 4.0, 2.0), col)
	for d in _drops:
		var p: Vector2 = d["p"]
		var v: Vector2 = d["v"]
		var sz: float = d["size"]
		var k: float = d["age"] / d["life"]
		var br := 2.3 if d.get("core", false) else 1.8
		var col := Color(base.r * br, base.g * br, base.b * br, 0.85 * (1.0 - k * 0.5))
		if d.get("core", false):
			col = Color(0.75 * br, 0.88 * br, 1.0 * br, col.a)
		var len := minf(v.length() * 0.02, 12.0)
		if len > sz:
			draw_line(p - v.normalized() * len, p, col, sz)
		else:
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
