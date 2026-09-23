class_name BulletMark
extends Node2D
## 탄흔 — **모든 총의 모든 탄이** 맞힌 면에 남기는 자국 (플레이어 소총 · 센트리건 · 보행 기체 공용).
##
## 예전에는 문 스프라이트와 바닥 프랍에만 셰이더 열 잔광(HeatSurface, 붉은색)이 떴고, 타일 벽·뒷벽에는
## 아무것도 남지 않았다. 센트리건·보행 기체는 대개 뒷벽을 맞히므로 "어떤 총은 자국이 있고 어떤 총은 없다"로 읽혔다.
## 지금은 Main._spawn_shot 이 면의 종류와 상관없이 이 노드를 하나씩 붙인다 (몬스터·물·유리 제외 — 각자 반응이 따로 있다).
##
## 한 자국은 두 층이다.
##   ① 구멍  (일반 블렌드, 라이트 무시 · 프리셋 확률로만) — 가운데가 까맣게 파이고 둘레에 그을음이 톱니처럼 번진다. 오래 남는다.
##   ② 열    (가산 블렌드, 라이트 무시) — 박힌 순간 **노란 백열**로 달아올랐다가
##            흑체 복사 색 순서(흰노랑 → 노랑 → 주황 → 검붉음)로 식는다. 식을수록 뜨거운 영역이 가운데로 오그라든다.
##            아트 격자(4 월드 px) 셀 단위로 그리고 온도를 계단으로 끊어 픽셀아트처럼 식는다.
##   + 작은 PointLight2D 가 온도를 따라 꺼진다 (주변 노멀맵이 잔열에 반응). 동시에 켜지는 수는 LIGHT_CAP 으로 제한.
##
## 방이 CanvasModulate 로 어둡게 깔려 있으므로 열 색은 **화면에서 보일 최종 색**으로 적고,
## 그리는 순간 앰비언트로 나눠 보정한다 (_emit) — 그래서 어느 방에서도 같은 노랑으로 읽힌다.
##
## 프리셋 3종 (F9 순환 · Shift+F9 이전) — PRESETS 참고. 새 자국부터 적용된다.

const CELL := 4.0                       # 아트 1px = 월드 4px (Main.ART_CELL)
const MAX_MARKS := 90                   # 방 하나에 쌓이는 자국 상한 (오래된 것부터 지운다)
const LIGHT_CAP := 6                    # 동시에 켜진 잔열 라이트 상한 (센트리건 연사 대비)
const HOLE_LIFE := 40.0                 # 구멍이 남는 시간 (초) — 그 뒤 HOLE_FADE 에 걸쳐 흐려진다
const HOLE_FADE := 3.0

## 흑체 복사 램프 — 온도(0~1) → **화면 최종 색**. 위에서 아래로 식는다.
## 흰색은 쓰지 않는다 (2026-09-23 — 흰 빛으로 보여 어색했다). 가장 뜨거운 색도 붉은 기가 도는 노랑이다.
const RAMP := [
	[1.00, Color(1.00, 0.70, 0.22)],   # 붉은 노랑 (박힌 순간)
	[0.80, Color(1.00, 0.57, 0.13)],   # 황주황
	[0.58, Color(0.97, 0.40, 0.07)],   # 주황
	[0.36, Color(0.82, 0.23, 0.04)],   # 붉은 주황
	[0.18, Color(0.48, 0.09, 0.02)],   # 검붉음
	[0.00, Color(0.00, 0.00, 0.00)],
]

## 프리셋. 시간은 초, 반경은 아트 셀 수(위력 1.0 기준).
##   hold      — 박힌 뒤 최고 온도가 유지되는 시간 (순간 고열)
##   cool      — 식는 데 걸리는 시간 (hold 이후)
##   curve     — 식는 곡선 지수 (크면 초반에 빨리 떨어지고 잔열이 오래 꼬리를 끈다)
##   radius    — 열이 퍼진 반경 (셀)
##   shrink    — 식으면서 뜨거운 영역이 오그라드는 정도 (0 = 그대로, 1 = 끝에 중심 한 점)
##   peak      — 박힌 순간의 온도 (1 이상이면 흰 심이 넓게 뜬다)
##   flash     — 첫 flash_t 초 동안 반경에 더해지는 섬광 셀 수
##   steps     — 온도 계단 수 (픽셀아트처럼 끊어서 식는다)
##   flicker   — 잔열이 지글거리는 세기 (셀마다 따로)
##   light     — 잔열 라이트 세기 / light_r 반경 (월드)
##   embers    — 튀어 나오는 불똥 픽셀 수 / smoke 피어오르는 연기 픽셀 수
##   drip      — 벽에 박힌 쇳물이 아래로 처지는 셀 수 (0 이면 없음)
##   (선택) cool_range — 자국마다 식는 시간을 이 범위에서 무작위로 (없으면 cool 고정)
##   (선택) gain       — 열 발광·라이트 밝기 배율 (기본 1)
##   (선택) hole_chance — 식은 뒤 구멍 자국이 남을 확률 (기본 1) / hole_alpha 구멍 진하기 배율 (기본 1)
const PRESETS := [
	{
		"id": "whitehot", "name": "백열 탄착",
		"desc": "박히는 순간 노란 백열 → 2.6초에 걸쳐 노랑·주황·검붉음으로 고르게 식는다",
		"hold": 0.10, "cool": 2.6, "curve": 1.35, "radius": 3.2, "shrink": 0.55, "peak": 1.15,
		"flash": 1.0, "flash_t": 0.06, "steps": 7, "flicker": 0.05,
		"light": 1.1, "light_r": 90.0, "embers": 3, "smoke": 0, "drip": 0,
	},
	{
		"id": "slag", "name": "용융 슬래그",
		"desc": "크게 녹아 오래 달궈진다 — 가장자리부터 식고, 쇳물이 아래로 처지며, 연기가 오른다 (4.5초)",
		"hold": 0.22, "cool": 4.5, "curve": 1.8, "radius": 4.2, "shrink": 0.75, "peak": 1.25,
		"flash": 1.0, "flash_t": 0.08, "steps": 8, "flicker": 0.10,
		"light": 1.5, "light_r": 120.0, "embers": 2, "smoke": 5, "drip": 3,
	},
	{
		# 채택 (2026-09-23). 발광은 20% 수준 · 붉은 노랑 · 식는 시간 최대 1.2초(무작위) ·
		# 구멍은 35% 확률로만, 아주 옅게, 조명을 받지 않게 남긴다 — 탄흔이 화면을 어지럽히지 않게.
		"id": "quench", "name": "섬광 담금질",
		"desc": "붉은 노랑으로 짧게 번쩍인 뒤 작은 점으로 급랭 — 4단 계단, 0.6~1.2초 무작위",
		"hold": 0.05, "cool": 0.85, "cool_range": [0.55, 1.15], "curve": 0.8, "radius": 2.2, "shrink": 0.35,
		"peak": 1.0, "gain": 0.2, "hole_chance": 0.35, "hole_alpha": 0.3,
		"flash": 3.0, "flash_t": 0.08, "steps": 4, "flicker": 0.0,
		"light": 2.2, "light_r": 140.0, "embers": 6, "smoke": 0, "drip": 0,
	},
]

static var preset_index := 2           # 기본: 섬광 담금질 (채택)
static var _marks: Array = []           # 살아 있는 자국 (오래된 것 먼저)
static var _lit: Array = []             # 라이트가 켜진 자국
static var _add_mat: CanvasItemMaterial
static var _hole_mat: CanvasItemMaterial   # 구멍: 일반 블렌드 · 라이트 무시 (조명이 비춰도 튀어 보이지 않게)


static func preset() -> Dictionary:
	return PRESETS[preset_index]


static func set_preset(i: int) -> void:
	preset_index = wrapi(i, 0, PRESETS.size())


## 탄착점에 자국을 붙인다. host 가 있으면(바닥 프랍) 그 프랍의 자식이 되어 들썩임·밀림을 따라간다.
## dir = 탄 진행 방향, power = 위력 배율 (1.0 소총 · 1.7 센트리건). on_floor = 바닥면이면 납작하게.
static func spawn(room: Node, point: Vector2, dir: Vector2, host: Node2D = null, power := 1.0,
		on_floor := false, preset_override := -1) -> BulletMark:
	_trim()
	var m := BulletMark.new()
	m._p = PRESETS[preset_override] if preset_override >= 0 else preset()
	m._power = power
	m._dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	m._flat = on_floor
	if host != null and is_instance_valid(host):
		m.z_index = 1                                        # 숙주 프랍 바로 앞
		host.add_child(m)
		m.position = host.to_local(point)
	else:
		var layer: Node = room.stain_layer() if room != null and room.has_method("stain_layer") else room
		# 체액 자국(z -1)과 달리 프랍 층보다 한 단 위 — 단말기처럼 탄이 뚫고 지나가는 물체·장식이 이 층에 있어
		# 그 뒤에 깔면 구멍이 가려지고 열만 떠 보인다. 탄착점은 hit_at 이 "맞힐 수 있는 프랍이 아님"을 확인한 곳이라
		# 반경 몇 셀짜리 자국이 앞 프랍 위로 번질 일은 거의 없다.
		m.z_index = 1
		layer.add_child(m)
		m.position = point
	m.position = (m.position / CELL).floor() * CELL + Vector2(CELL, CELL) * 0.5   # 셀 중심에 스냅
	_marks.append(m)
	return m


static func _trim() -> void:
	_marks = _marks.filter(func(x): return is_instance_valid(x))
	while _marks.size() >= MAX_MARKS:
		var old: Node = _marks.pop_front()
		if is_instance_valid(old):
			old.queue_free()


static func clear_all() -> void:
	for m in _marks:
		if is_instance_valid(m):
			m.queue_free()
	_marks.clear()
	_lit.clear()


# ----------------------------------------------------------------------------- 인스턴스

var _p: Dictionary
var _power := 1.0
var _dir := Vector2.RIGHT
var _flat := false
var _t := 0.0
var _heat_done := false
var _hole_cells: Array = []     # [Vector2i 셀, Color] 구멍·버·그을음·변색 고리
var _heat_cells: Array = []     # [Vector2i 셀, 거리(셀), 난수] 열이 퍼질 수 있는 셀
var _drip_cells: Array = []     # [Vector2i 셀, 처지는 순서 0..1]
var _particles: Array = []      # {pos, vel, life, t, kind: "ember"|"smoke"}
var _glow: Node2D
var _light: PointLight2D
var _amb := Color(1, 1, 1)
var _rng := RandomNumberGenerator.new()
var _cool := 1.0                # 이 자국이 식는 시간 (cool_range 가 있으면 무작위)
var _gain := 1.0


func _ready() -> void:
	_rng.randomize()
	_amb = Lighting.ambient_color()
	_gain = float(_p.get("gain", 1.0))
	_cool = float(_p["cool"])
	if _p.has("cool_range"):
		_cool = _rng.randf_range(float(_p["cool_range"][0]), float(_p["cool_range"][1]))
	if _hole_mat == null:
		_hole_mat = CanvasItemMaterial.new()
		_hole_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _hole_mat
	_build_cells()
	# 열 층: 가산 블렌드 · 라이트 무시 (빛을 받는 게 아니라 스스로 빛난다)
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow = Node2D.new()
	_glow.material = _add_mat                            # 구멍보다 나중에 그려지는 자식 → 구멍 위에 얹힌다
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	# 잔열 라이트
	var le: float = float(_p["light"])
	if le > 0.0:
		_light = PointLight2D.new()
		_light.texture = Lighting.radial_texture()
		_light.texture_scale = Lighting.scale_for_radius(float(_p["light_r"]) * (0.6 + 0.4 * _power))
		_light.height = 30.0
		_light.color = Color(1.0, 0.78, 0.35)
		_light.energy = 0.0
		add_child(_light)
		_lit = _lit.filter(func(x): return is_instance_valid(x) and x._light != null)
		while _lit.size() >= LIGHT_CAP:
			var old = _lit.pop_front()
			old._kill_light()
		_lit.append(self)
	_spawn_particles()
	queue_redraw()
	_glow.queue_redraw()


func _kill_light() -> void:
	if _light != null and is_instance_valid(_light):
		_light.queue_free()
	_light = null


## 셀 배치: 구멍(가운데 1~2셀 + 그을음 톱니) · 열 확산 셀 · 쇳물 처짐 셀
func _build_cells() -> void:
	var r := float(_p["radius"]) * (0.7 + 0.3 * _power) + float(_p["flash"])
	var ri := int(ceil(r)) + 1
	var sy := 0.5 if _flat else 1.0                 # 바닥면: 원근으로 납작하게
	for y in range(-ri, ri + 1):
		for x in range(-ri, ri + 1):
			var d := Vector2(x + 0.5, (y + 0.5) / sy).length()    # 2×2 구멍 심(-0.5, -0.5)을 중심으로
			if d <= r + 0.5:
				_heat_cells.append([Vector2i(x, y), d, _rng.randf()])
	# 구멍 — 어두운 면 위의 까만 점만으로는 안 읽힌다(단말기 앞면에서 확인). 네 가지를 겹친다:
	#   · 심      : 2×2 셀 새까만 구멍 (위력이 크면 가장자리 셀이 더 붙는다)
	#   · 버      : 구멍 위·왼쪽 가장자리에 밝은 금속 테 (말려 올라간 쇳조각이 빛을 받는다)
	#   · 그을음  : 둘레로 톱니처럼 번지는 반투명 검정
	#   · 변색 고리: 그을음 바깥의 옅은 청동빛 — 달궈졌다 식은 금속의 산화 자국. 식은 뒤에도 "열 맞은 자리"로 읽힌다
	# 색은 CanvasModulate(≈0.3)를 거치므로 밝은 색은 1 을 넘겨 적는다.
	if _rng.randf() < float(_p.get("hole_chance", 1.0)):   # 확률에서 빠진 발은 구멍 없이 열만 남기고 사라진다
		_build_hole(sy)
	# 쇳물 처짐 (벽면만)
	var dn: int = int(_p["drip"])
	if dn > 0 and not _flat:
		var n := _rng.randi_range(maxi(dn - 1, 1), dn)
		var dx := _rng.randi_range(-1, 1) if _rng.randf() < 0.5 else 0
		for i in range(n):
			_drip_cells.append([Vector2i(dx, 1 + i), float(i + 1) / float(n)])


func _build_hole(sy: float) -> void:
	var ha := float(_p.get("hole_alpha", 1.0))
	var core := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]
	if _power > 1.3:
		core.append_array([Vector2i(1, -1), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)])
	var center := Vector2(-0.5, -0.5)                    # 2×2 심의 중심 (셀 좌표)
	var core_r := 1.2 + 0.5 * (_power - 1.0)
	var soot := core_r + 1.5 + _rng.randf_range(0.0, 0.8)
	var temper := soot + 1.2
	var ext := int(ceil(temper)) + 1
	for y in range(-ext, ext + 1):
		for x in range(-ext, ext + 1):
			var c := Vector2i(x, y)
			var v := Vector2(x, y) - center
			var d := Vector2(v.x, v.y / sy).length()
			if c in core:
				_hole_cells.append([c, Color(0.02, 0.015, 0.015, 0.96 * ha)])
			elif d <= core_r + 0.9 and v.y < -0.2 and v.x < 0.6 and _rng.randf() < 0.75:
				_hole_cells.append([c, Color(1.9, 1.75, 1.5, 0.55 * ha)])            # 버 (위·왼쪽, 주 광원 쪽)
			elif d <= soot and _rng.randf() < 1.1 - (d - core_r) / (soot - core_r + 0.01):
				_hole_cells.append([c, Color(0.04, 0.03, 0.03, _rng.randf_range(0.35, 0.6) * ha)])
			elif d <= temper and _rng.randf() < 0.55:
				_hole_cells.append([c, Color(1.25, 0.78, 0.40, _rng.randf_range(0.14, 0.24) * ha)])   # 변색 고리


func _spawn_particles() -> void:
	var back := -_dir
	for i in range(int(_p["embers"])):
		var v := back.rotated(_rng.randf_range(-1.2, 1.2)) * _rng.randf_range(90.0, 260.0) * (0.7 + 0.3 * _power)
		v.y -= _rng.randf_range(40.0, 160.0)
		_particles.append({"pos": Vector2.ZERO, "vel": v, "life": _rng.randf_range(0.25, 0.55),
			"t": 0.0, "kind": "ember", "delay": 0.0})
	for i in range(int(_p["smoke"])):
		_particles.append({"pos": Vector2(_rng.randf_range(-CELL, CELL), 0.0),
			"vel": Vector2(_rng.randf_range(-8.0, 8.0), -_rng.randf_range(22.0, 40.0)),
			"life": _rng.randf_range(1.2, 2.0), "t": 0.0, "kind": "smoke",
			"delay": float(_p["hold"]) + _rng.randf_range(0.1, 1.2)})


## 현재 온도 (0~peak). hold 동안 최고, 그 뒤 curve 곡선으로 0 까지.
func temperature() -> float:
	var hold: float = _p["hold"]
	var peak: float = _p["peak"]
	if _t <= hold:
		return peak
	var k := clampf((_t - hold) / _cool, 0.0, 1.0)
	return peak * pow(1.0 - k, float(_p["curve"]))


func _process(delta: float) -> void:
	_t += delta
	var total_heat: float = float(_p["hold"]) + _cool
	for q in _particles:
		if _t < q["delay"]:
			continue
		q["t"] += delta
		if q["kind"] == "ember":
			q["vel"].y += 900.0 * delta
			q["vel"] *= maxf(0.0, 1.0 - 2.0 * delta)
		else:
			q["vel"].x += sin(_t * 2.3 + q["pos"].y * 0.05) * 14.0 * delta
		q["pos"] += q["vel"] * delta
	_particles = _particles.filter(func(q): return q["t"] < q["life"])

	var temp := temperature()
	if _light != null:
		_light.energy = float(_p["light"]) * _gain * pow(clampf(temp, 0.0, 1.0), 1.6) * (0.75 + 0.25 * _power)
		_light.color = _ramp(clampf(temp * 0.85 + 0.15, 0.0, 1.0))
		if _t > total_heat:
			_kill_light()
			_lit.erase(self)
	if not _heat_done:
		_glow.queue_redraw()
		if _t > total_heat and _particles.is_empty():
			_heat_done = true
			_glow.queue_redraw()
			if _hole_cells.is_empty():
				queue_free()                 # 구멍이 남지 않는 발 — 열이 식으면 끝
				return
	# 구멍은 오래 남다가 흐려진다
	if _t > HOLE_LIFE:
		modulate.a = clampf(1.0 - (_t - HOLE_LIFE) / HOLE_FADE, 0.0, 1.0)
		if _t > HOLE_LIFE + HOLE_FADE:
			queue_free()


## ① 구멍 — 조명을 받지 않는다(_hole_mat). 램프·총구 빛에 번쩍 드러나지 않고 앰비언트 속에 옅게 가라앉는다
func _draw() -> void:
	for hc in _hole_cells:
		var c: Vector2i = hc[0]
		draw_rect(Rect2(Vector2(c) * CELL - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), hc[1])


## ② 열 — 셀마다 (전체 온도 × 거리 감쇠)로 국소 온도를 구해 계단으로 끊고 램프 색을 찍는다
func _draw_glow() -> void:
	var g := _glow                                                       # 가산 층 노드에 그린다
	var temp := temperature()
	var half := Vector2(CELL, CELL) * 0.5
	if temp > 0.001:
		var peak: float = _p["peak"]
		var tn := clampf(temp / peak, 0.0, 1.0)                       # 0~1 정규화 진행도
		var r := float(_p["radius"]) * (0.7 + 0.3 * _power)
		r *= lerpf(1.0 - float(_p["shrink"]), 1.0, tn)                  # 식으면서 오그라든다
		if _t < float(_p["flash_t"]):
			r += float(_p["flash"]) * (1.0 - _t / float(_p["flash_t"]))  # 박힌 순간 섬광
		var steps: int = _p["steps"]
		var flick: float = _p["flicker"]
		for hc in _heat_cells:
			var d: float = hc[1]
			if d > r + 0.5:
				continue
			var fall := clampf(1.0 - d / (r + 0.5), 0.0, 1.0)
			fall = sqrt(fall)                                          # 가운데가 넓게 뜨겁다
			var local := temp * fall
			if flick > 0.0:
				local *= 1.0 + flick * sin(_t * 23.0 + float(hc[2]) * 40.0)
			local = floorf(local * steps + 0.5) / float(steps)           # 계단
			if local <= 0.02:
				continue
			var c: Vector2i = hc[0]
			g.draw_rect(Rect2(Vector2(c) * CELL - half, Vector2(CELL, CELL)), _emit(local))
		# 쇳물 처짐: 박힌 뒤 조금 있다 한 칸씩 흘러내리고, 본체보다 조금 먼저 식는다
		var sag := clampf((_t - float(_p["hold"])) / 0.6, 0.0, 1.0)
		for dc in _drip_cells:
			if float(dc[1]) > sag:
				continue
			var dl := temp * (0.85 - 0.25 * float(dc[1]))
			dl = floorf(dl * steps + 0.5) / float(steps)
			if dl > 0.02:
				g.draw_rect(Rect2(Vector2(dc[0]) * CELL - half, Vector2(CELL, CELL)), _emit(dl))
	# 불똥·연기 픽셀
	for q in _particles:
		if _t < q["delay"]:
			continue
		var lk: float = q["t"] / q["life"]
		var p: Vector2 = ((q["pos"] as Vector2) / CELL).floor() * CELL
		if q["kind"] == "ember":
			g.draw_rect(Rect2(p - half * 0.5, Vector2(CELL, CELL) * 0.5), _emit(lerpf(1.0, 0.35, lk)))
		else:
			# 연기는 가산이 아니라 빛을 조금 가리는 회색이어야 하지만, 이 층은 가산이라 아주 옅은 회백으로만 얹는다
			var a := 0.10 * (1.0 - lk) * minf(q["t"] / 0.2, 1.0)
			g.draw_rect(Rect2(p - half, Vector2(CELL, CELL)), Color(a, a, a * 1.05, 1.0) / _amb_safe())


func _amb_safe() -> Color:
	return Color(maxf(_amb.r, 0.05), maxf(_amb.g, 0.05), maxf(_amb.b, 0.05), 1.0)


## 온도 → 화면 최종 색을 앰비언트로 나눠 CanvasModulate 를 상쇄한 가산 색 (HDR — 글로우 임계를 넘으면 번진다)
func _emit(temp: float) -> Color:
	var c := _ramp(clampf(temp, 0.0, 1.0))
	var boost := (1.0 + maxf(temp - 1.0, 0.0) * 2.5) * _gain         # peak > 1 인 구간: 심이 번쩍 번진다
	var a := _amb_safe()
	return Color(c.r / a.r * boost, c.g / a.g * boost, c.b / a.b * boost, 1.0)


static func _ramp(t: float) -> Color:
	for i in range(RAMP.size() - 1):
		var hi: Array = RAMP[i]
		var lo: Array = RAMP[i + 1]
		if t >= float(lo[0]):
			var k := (t - float(lo[0])) / maxf(float(hi[0]) - float(lo[0]), 0.0001)
			return (lo[1] as Color).lerp(hi[1], k)
	return RAMP[RAMP.size() - 1][1]
