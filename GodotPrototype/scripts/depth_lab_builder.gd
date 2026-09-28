class_name DepthLabBuilder
extends RefCounted
## 공간감 테스트 씬의 그레이박스 레이어를 채운다 — 구역(ZONES) × 역할(ROLES) 마다 도형 문법이 다르다.
##
## 좌표 (레이어 로컬): y 0 = 바닥선, 위가 음수. x 는 "월드와 같은 척도" 이고 구역 기준점 A(구역 가운데)에
## 카메라가 서 있을 때 월드와 겹친다. 월드 위치에 **맞춰 보여야 하는** 것(턱 높이의 벽등, 환풍기)은 _lx(w) · _ly(h) 로 옮긴다.
##
## 조명 규칙
##   · 주광 방향은 구역마다 다르다 (tone.key): top 위에서 · bottom 아래에서 올라오는 빛(전력 홀) · back 역광(행성광 림)
##   · 먼 레이어는 면 사이 명도 차가 contrast(역할) 만큼 줄어든다 — 공기 원근
##   · 빛과 어둠은 그라데이션으로 번진다: 낮게 깔린 안개 · 샤프트 아래쪽 어둠 · 덕트 가운데로 짙어지는 어둠 · 아래에서 올라오는 빛
##   · 광원(투광등·벽등·경고등·코일 탑·유도등·채광창)은 레이어의 빛 겹(가산)에 굽고, 같은 자리에 실제 광원(DepthLabLights)도 선다
## "명도만 보기"(flat) 는 레이어마다 대표 명도 한 값만 남긴다.

const D := preload("res://scripts/depth_lab_data.gd")
const HW := 2400.0                  # 가시 반폭 여유 (넓게 줌 · 넓은 화면)
const HH := 1500.0
const AY := -180.0                  # 기준점 세로 (바닥 위 카메라 중심 근처)
const FAN_X := 10752.0              # 환풍기실 가운데
const FAN_H := 400.0

var tone: Dictionary
var zone: Dictionary
var zi := 0
var flat := false
var tint := false
var role := ""
var f := 1.0
var L: DepthLayer
var rng := RandomNumberGenerator.new()
var ax := 0.0                       # 구역 기준점 x (월드)
var x0 := 0.0                       # 이 레이어가 채울 로컬 범위
var x1 := 0.0
var top := 0.0
var bottom := 0.0


static func anchor_x(z: Dictionary) -> float:
	return (float(z["x0"]) + float(z["x1"])) * 0.5


static func hmax(z: Dictionary) -> float:
	var m := 0.0
	for p in D.PLATFORMS:
		if float(p["x0"]) < float(z["x1"]) and float(p["x1"]) > float(z["x0"]):
			m = maxf(m, float(p["h"]))
	return m


func build(layer: DepthLayer, zone_index: int, factor: float, flat_: bool, tint_: bool) -> void:
	L = layer
	zi = zone_index
	zone = D.ZONES[zi]
	tone = zone["tone"]
	role = layer.role
	f = factor
	flat = flat_
	tint = tint_
	rng.seed = hash("depth_%s_%s" % [zone["id"], role])
	ax = anchor_x(zone)
	var za := float(zone["x0"])
	var zb := float(zone["x1"])
	if role == "ground" or role == "front":
		x0 = za - 80.0
		x1 = zb + 80.0
		top = -4400.0
		bottom = 2200.0
	else:
		x0 = ax + (za - HW - ax) * f - HW
		x1 = ax + (zb + HW - ax) * f + HW
		var hm := hmax(zone)
		top = AY - (hm + 700.0) * f - HH
		bottom = AY + 400.0 * f + HH
	L.clear_ops()
	var fn := "_%s_%s" % [zone["id"], role]
	if has_method(fn):
		call(fn)
	elif role == "ground":
		_ground_common()
	L.set_light_visible(not flat)
	L.commit()


# ── 좌표 ───────────────────────────────────────────────────────────────────────

## 월드 x → 이 레이어 로컬 x (카메라가 그 자리에 섰을 때 화면에서 겹치는 곳)
func _lx(w: float) -> float:
	return ax + (w - ax) * f


## 바닥 위 높이 h → 이 레이어 로컬 y
func _ly(h: float) -> float:
	return AY + (-h - AY) * f


# ── 명도 ───────────────────────────────────────────────────────────────────────

func _base() -> float:
	if role == "front":
		return float(tone["fg"]["fg1"])
	return D.base_value(tone, role)


func _v(dv := 0.0) -> float:
	if flat:
		return _base()
	return clampf(_base() + dv * D.contrast(tone, role), 0.0, 1.0)


func _c(v: float, a := 1.0) -> Color:
	var col := Color(v, v, v, a)
	if tint and not flat and tone["haze"].has(role):
		var k := float(tone["haze"][role])
		var t: Color = Color.WHITE.lerp(tone["tint_far"], k)
		col = Color(clampf(v * t.r, 0, 1), clampf(v * t.g, 0, 1), clampf(v * t.b, 0, 1), a)
	return col


func _s(dv := 0.0) -> Color:
	return _c(_v(dv))


func _lamp(k: float) -> Color:
	if tint:
		var t: Color = tone["tint_lamp"]
		return Color(k * t.r, k * t.g, k * t.b, 1.0)
	return Color(k, k, k, 1.0)


## 주광 방향을 받는 상자. lit/side 는 면 명도 차 (먼 층일수록 _v 가 줄인다)
func _block(x: float, y: float, w: float, h: float, dv := 0.0, lit := 0.12, side := -0.07) -> void:
	L.box(x, y, w, h, _s(dv))
	if flat:
		return
	match String(tone["key"]):
		"bottom":
			L.box(x, y + h - 8, w, 8, _s(dv + lit))                  # 아래에서 올라온 빛이 밑 모서리에
			L.box(x, y, w, 8, _s(dv - 0.05))
			L.box(x + w * 0.8, y, w * 0.2, h - 8, _s(dv + side * 0.6))
		"back":
			L.box(x, y, w, 6, _s(dv + float(tone["rim"])))           # 역광 — 윗모서리에 빛이 맺힌다
			L.box(x, y, 6, h, _s(dv + float(tone["rim"]) * 0.6))
		_:
			L.box(x, y, w, 8, _s(dv + lit))
			L.box(x + w * 0.8, y + 8, w * 0.2, h - 8, _s(dv + side))


func _fill(dv := 0.0) -> void:
	L.box(x0, top, x1 - x0, bottom - top, _s(dv))


## 낮게 깔린 안개 — 레이어 아래쪽을 안개 명도로 덮는다
func _height_fog(fog_top: float, fog_bottom: float) -> void:
	if flat or not tone["haze"].has(role):
		return
	var fv := float(tone["fog"])
	var a := float(tone["haze"][role]) * float(tone["height_fog"])
	if a <= 0.0:
		return
	L.vgrad(x0, fog_top, x1 - x0, fog_bottom - fog_top, _c(fv, 0.0), _c(fv, a))


## 어둠 그라데이션 (검정 알파) — 세로: a_top → a_bottom
func _dark_v(y0: float, y1: float, a_top: float, a_bottom: float) -> void:
	if flat:
		return
	L.vgrad(x0, y0, x1 - x0, y1 - y0, Color(0, 0, 0, a_top), Color(0, 0, 0, a_bottom))


## 어둠 그라데이션 — 가로: 로컬 xa..xb 에서 a0 → a1
func _dark_h(xa: float, xb: float, a0: float, a1: float) -> void:
	if flat:
		return
	L.poly_colors(PackedVector2Array([Vector2(xa, top), Vector2(xb, top), Vector2(xb, bottom), Vector2(xa, bottom)]),
		PackedColorArray([Color(0, 0, 0, a0), Color(0, 0, 0, a1), Color(0, 0, 0, a1), Color(0, 0, 0, a0)]))


## 위에서 아래로 떨어지는 빛 기둥 (가산) — 폭 tw → bw, 세기 k → 0
func _beam(x: float, y0: float, y1: float, tw: float, bw: float, k: float, slant := 0.0) -> void:
	if flat or k <= 0.0:
		return
	L.light_poly(PackedVector2Array([
		Vector2(x - tw * 0.5, y0), Vector2(x + tw * 0.5, y0),
		Vector2(x + slant + bw * 0.5, y1), Vector2(x + slant - bw * 0.5, y1)]),
		PackedColorArray([_lamp(k), _lamp(k), _lamp(0.0), _lamp(0.0)]))


## 아래에서 올라오는 빛 (가산) — y0(아래, 밝음 k) → y1(위, 0)
func _uplight(y0: float, y1: float, k: float) -> void:
	if flat or k <= 0.0:
		return
	L.light_poly(PackedVector2Array([Vector2(x0, y1), Vector2(x1, y1), Vector2(x1, y0), Vector2(x0, y0)]),
		PackedColorArray([_lamp(0.0), _lamp(0.0), _lamp(k), _lamp(k)]))


func _glow(p: Vector2, s: Vector2, k: float) -> void:
	if flat or k <= 0.0:
		return
	L.glow(p, s, _lamp(k))


func _fixture(v: float) -> Color:
	return _c(clampf(v, 0.0, 1.0)) if not flat else _s()


# ════════════════════════════════════════════════════════════════════════════════
# 1. 도킹 관측 회랑 — 우주. 행성·별(배경판) · 먼 위성(원경3) · 자매 정거장(원경2) · 선체 트러스(원경1) · 관측창 벽(뒤벽)
# ════════════════════════════════════════════════════════════════════════════════

func _dock_sky() -> void:
	var s: Array = tone["sky"]
	if flat:
		_fill()
		return
	L.vgrad(x0, top, x1 - x0, -700 - top, _c(s[0]), _c(s[1]))
	L.vgrad(x0, -700, x1 - x0, bottom + 700, _c(s[1]), _c(s[2]))
	# 별 — 작은 점은 많이, 큰 별은 드물게
	var n := int((x1 - x0) * (bottom - top) / 52000.0)
	for i in range(n):
		var k := pow(rng.randf(), 3.0) * 0.9 + 0.05
		L.light_box(rng.randf_range(x0, x1), rng.randf_range(top, 400), 4, 4, _lamp(k))
	for i in range(n / 40):
		var p := Vector2(rng.randf_range(x0, x1), rng.randf_range(top, -600))
		L.light_box(p.x - 8, p.y, 20, 4, _lamp(0.45))
		L.light_box(p.x, p.y - 8, 4, 20, _lamp(0.45))
		L.glow(p + Vector2(2, 2), Vector2(90, 90), _lamp(0.25))
	# 성운 — 아주 옅은 큰 번짐
	for i in range(4):
		L.glow(Vector2(rng.randf_range(x0, x1), rng.randf_range(top * 0.6, -900)), Vector2(3400, 1800) * rng.randf_range(0.7, 1.3), _lamp(0.06))
	# 해 — 왼쪽 위 화면 밖에서 번지는 빛
	L.glow(Vector2(x0 + (x1 - x0) * 0.12, top + 600), Vector2(5200, 4200), _lamp(0.16))
	# 행성 — 화면 아래쪽을 크게 차지하는 원호. 왼쪽에서 햇빛을 받는다 (오른쪽으로 갈수록 밤)
	var c := Vector2(ax - 400.0, 5300.0)
	var r := 6200.0                                            # 꼭대기가 바닥 위 900 — 관측창 한가운데에 걸린다
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in range(97):
		var a := PI + PI * i / 96.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		var lit := clampf(1.0 - float(i) / 96.0 * 1.3, 0.0, 1.0)
		cols.append(_c(0.06 + 0.30 * lit))
	L.poly_colors(pts, cols)                                   # 윗반원 — 양 끝이 원 중심 높이(화면 훨씬 아래)에서 닫힌다
	# 구름 띠 — 원호를 따라 조금 밝은 줄
	for band in range(3):
		var rr := r - 240.0 - band * 380.0
		var bp := PackedVector2Array()
		for i in range(49):
			var a := PI * 1.08 + PI * 0.55 * i / 48.0
			bp.append(c + Vector2(cos(a), sin(a)) * rr)
		L.polyline(bp, _c(0.14 - band * 0.03), 28.0 - band * 6.0)
	# 대기 테두리 — 가장 밝은 가산 띠 (햇빛 쪽이 더 밝다)
	var ring := PackedVector2Array()
	var rcol := PackedColorArray()
	for i in range(49):
		var a := PI + PI * i / 48.0
		ring.append(c + Vector2(cos(a), sin(a)) * (r + 200.0))
		rcol.append(_lamp(0.0))
	for i in range(48, -1, -1):
		var a := PI + PI * i / 48.0
		var lit := clampf(1.0 - float(i) / 48.0 * 1.2, 0.08, 1.0)
		ring.append(c + Vector2(cos(a), sin(a)) * (r - 30.0))
		rcol.append(_lamp(0.85 * lit))
	L.light_poly(ring, rcol)


func _dock_far3() -> void:
	# 먼 위성·파편 — 작고 흐린 실루엣, 깜빡이는 점
	var x := x0 + rng.randf_range(200, 900)
	while x < x1:
		var y := rng.randf_range(-2400, -700)
		var w := rng.randf_range(60, 200)
		var h := w * rng.randf_range(0.3, 0.7)
		_block(x, y, w, h, 0.0, 0.1, -0.05)
		L.box(x - w * 0.8, y + h * 0.3, w * 0.7, h * 0.35, _s(0.03))
		L.box(x + w, y + h * 0.3, w * 0.7, h * 0.35, _s(0.03))
		if not flat:
			L.light_box(x + w * 0.5, y - 8, 4, 4, _lamp(0.6))
		x += rng.randf_range(900, 2200)


func _dock_far2() -> void:
	# 자매 정거장 — 고리 · 허브 · 살 · 태양 전지판 · 도킹 모듈
	var n := maxi(1, int((x1 - x0) / 5200.0))
	for s in range(n):
		var c := Vector2(x0 + (x1 - x0) * (s + 0.5) / n + rng.randf_range(-400, 400), rng.randf_range(-1500, -1000))
		var rx := rng.randf_range(1100, 1500)
		var ry := rx * 0.26
		var ring := PackedVector2Array()
		for i in range(65):
			var a := TAU * i / 64.0
			ring.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		L.polyline(ring, _s(0.0), 64.0)
		if not flat:
			var rim := PackedVector2Array()
			for i in range(33):
				var a := PI + PI * i / 32.0
				rim.append(c + Vector2(cos(a) * rx, sin(a) * ry - 26.0))
			L.polyline(rim, _s(0.16), 10.0)
		for k in range(4):
			var a := TAU * k / 4.0 + 0.4
			L.line(c, c + Vector2(cos(a) * rx, sin(a) * ry), _s(-0.02), 22.0)
		_block(c.x - 150, c.y - 150, 300, 300, 0.04, 0.14, -0.08)
		_block(c.x - 60, c.y - 520, 120, 370, 0.02, 0.12, -0.06)
		_block(c.x - 40, c.y + 150, 80, 420, 0.0, 0.1, -0.06)
		for side in [-1, 1]:                                   # 태양 전지판
			var px: float = c.x + 260.0 if side > 0 else c.x - 820.0
			L.box(px, c.y - 90, 560, 180, _s(-0.04))
			if not flat:
				var gx := px
				while gx < px + 560:
					L.box(gx, c.y - 90, 4, 180, _s(0.05))
					gx += 70.0
				L.box(px, c.y - 90, 560, 4, _s(0.1))
		if not flat:
			for k in range(10):                               # 고리 불빛
				var a := rng.randf() * TAU
				L.light_box(c.x + cos(a) * rx, c.y + sin(a) * ry, 8, 8, _lamp(rng.randf_range(0.3, 0.8)))
		_glow(c + Vector2(0, -520), Vector2(260, 260), 0.5)


func _dock_far1() -> void:
	# 가까운 선체 — 트러스 붐 · 안테나 · 접시 · 모듈
	var y := -560.0
	L.box(x0, y, x1 - x0, 20, _s(0.02))
	L.box(x0, y + 72, x1 - x0, 14, _s(-0.02))
	if not flat:
		var sx := x0
		var up := true
		while sx < x1:
			L.line(Vector2(sx, y + (20.0 if up else 72.0)), Vector2(sx + 92, y + (72.0 if up else 20.0)), _s(0.0), 8.0)
			sx += 92.0
			up = not up
	var x := x0 + rng.randf_range(300, 900)
	while x < x1:
		var pick := rng.randf()
		if pick < 0.4:
			var h := rng.randf_range(500, 1100)
			L.box(x, y - h, 16, h, _s(0.0))
			L.box(x - 60, y - h * 0.7, 136, 10, _s(0.04))
			if not flat:
				L.light_box(x + 4, y - h - 12, 8, 8, _lamp(0.7))
		elif pick < 0.7:
			var r := rng.randf_range(160, 280)
			var cc := Vector2(x, y - r - 60)
			var dish := PackedVector2Array()
			for i in range(17):
				var a := PI * 0.1 + PI * 0.8 * i / 16.0
				dish.append(cc + Vector2(cos(a) * r, sin(a) * r * 0.5))
			L.poly(dish, _s(0.02))
			L.box(x - 8, cc.y, 16, y - cc.y, _s(-0.02))
		else:
			_block(x, y - 240, 360, 240, 0.0, 0.12, -0.08)
			L.box(x + 40, y - 300, 280, 60, _s(0.03))
		x += rng.randf_range(700, 1500)
	_uplight(600, -900, 0.10)


func _dock_back() -> void:
	# 관측창 벽 — 창턱 · 창살 · 가로대 · 머리벽. 유리는 그리지 않고 반사 줄만 얹는다
	var sill := -150.0
	var head := -1020.0
	L.box(x0, sill, x1 - x0, bottom - sill, _s(0.0))
	L.box(x0, top, x1 - x0, head - top, _s(-0.02))
	if not flat:
		L.box(x0, sill, x1 - x0, 8, _s(0.14))
		L.box(x0, head - 16, x1 - x0, 16, _s(float(tone["rim"])))      # 머리벽 아랫면 — 행성광이 맺힌다
		var rx := x0
		while rx < x1:
			L.box(rx, top, 24, head - top, _s(-0.07))
			rx += 512.0
	var mx := x0 + 200.0
	while mx < x1:
		L.box(mx, head, 48, sill - head, _s(0.02))
		if not flat:
			L.box(mx, head, 6, sill - head, _s(float(tone["rim"])))
			L.box(mx + 48, head, 20, sill - head, _s(-0.08))              # 창틀 두께 (안쪽 그늘)
		mx += 640.0
	L.box(x0, -660, x1 - x0, 20, _s(0.02))
	if not flat:
		var gx := x0 + 300.0
		while gx < x1:                                                # 유리 반사 — 사선 두 줄
			for k in range(2):
				var ox := gx + k * 70.0
				L.light_poly(PackedVector2Array([Vector2(ox, head), Vector2(ox + 40 + k * 20, head),
					Vector2(ox - 260 + k * 20, sill), Vector2(ox - 300, sill)]),
					PackedColorArray([_lamp(0.05), _lamp(0.05), _lamp(0.0), _lamp(0.0)]))
			gx += rng.randf_range(700, 1300)


func _dock_ground() -> void:
	_ground_common()
	var zx := float(zone["x0"])
	# 에어록 문 (방 왼쪽 끝)
	_block(zx + 40, -620, 360, 620, 0.02, 0.14, -0.1)
	L.box(zx + 90, -560, 260, 560, _s(-0.1) if not flat else _s())
	if flat:
		return
	L.light_box(zx + 205, -600, 30, 12, _lamp(0.8))
	L.glow(Vector2(zx + 220, -594), Vector2(260, 200), _lamp(0.4))
	# 활주로 유도등 — 바닥 앞 모서리를 따라 점점이
	var x := zx + 64.0
	while x < float(zone["x1"]):
		L.light_box(x, 26, 12, 6, _lamp(0.7))
		L.glow(Vector2(x + 6, 30), Vector2(120, 40), _lamp(0.35))
		x += 128.0


func _dock_fg1() -> void:
	_fg_struts()
	_fg_top_rib(-1180)


func _dock_fg2() -> void:
	_fg_columns(2600, 3800, 150, 230)


# ════════════════════════════════════════════════════════════════════════════════
# 2. 다층 정비 격납고 — 먼 격납 구획 · 탑 · 탱크/배관 · 뒤벽(기둥·벽등·격납 셔터·천장 크레인)
# ════════════════════════════════════════════════════════════════════════════════

func _hangar_sky() -> void:
	var s: Array = tone["sky"]
	if flat:
		_fill()
		return
	L.vgrad(x0, top, x1 - x0, -260 - top, _c(s[0]), _c(s[1]))
	L.vgrad(x0, -260, x1 - x0, bottom + 260, _c(s[1]), _c(s[2]))
	var x := x0 + rng.randf_range(200, 900)
	while x < x1:
		_beam(x, top, 300, rng.randf_range(100, 220), rng.randf_range(500, 900), 0.05, rng.randf_range(260, 520))
		x += rng.randf_range(1400, 2600)


func _hangar_far3() -> void:
	L.box(x0, -240, x1 - x0, bottom + 240, _s(-0.02))
	var x := x0
	while x < x1:
		var w := rng.randf_range(280, 760)
		var h := rng.randf_range(1000, 2300)
		var dv := rng.randf_range(-0.05, 0.05)
		_block(x, -h, w, h + 300, dv, 0.08, -0.05)
		if not flat:
			for i in range(rng.randi_range(2, 6)):
				L.light_box(x + rng.randf_range(12, w - 20), -h + rng.randf_range(40, h - 60), 8, 8, _lamp(0.2))
		x += w + rng.randf_range(60, 460)
	_height_fog(-1200, 400)


func _hangar_far2() -> void:
	L.box(x0, -150, x1 - x0, bottom + 150, _s(-0.03))
	var x := x0
	var towers: Array = []
	while x < x1:
		var w := rng.randf_range(110, 300)
		var h := rng.randf_range(520, 1400)
		var dv := rng.randf_range(-0.05, 0.05)
		_block(x, -h, w, h + 160, dv, 0.10, -0.07)
		if not flat:
			var fy := -h + 128.0
			while fy < -80.0:
				L.box(x, fy, w, 8, _s(dv - 0.06))
				fy += 128.0
		towers.append([x, w, h])
		x += w + rng.randf_range(180, 820)
	for i in range(towers.size() - 1):
		if rng.randf() > 0.5:
			continue
		var a: Array = towers[i]
		var b: Array = towers[i + 1]
		var y := -minf(a[2], b[2]) + rng.randf_range(120, 260)
		L.box(a[0] + a[1], y, b[0] - a[0] - a[1], 28, _s(0.04))
		L.box(a[0] + a[1], y + 88, b[0] - a[0] - a[1], 12, _s(-0.04))
	_height_fog(-900, 300)


func _hangar_far1() -> void:
	L.box(x0, -70, x1 - x0, bottom + 70, _s(-0.04))
	var x := x0
	while x < x1:
		var pick := rng.randf()
		var dv := rng.randf_range(-0.04, 0.04)
		if pick < 0.4:
			var w := rng.randf_range(240, 420)
			var h := rng.randf_range(280, 560)
			_block(x, -h, w, h + 80, dv, 0.14, -0.09)
			_block(x + w * 0.15, -h - 28, w * 0.7, 32, dv + 0.02, 0.10, -0.06)
			x += w + rng.randf_range(40, 200)
		elif pick < 0.65:
			var w := rng.randf_range(64, 110)
			var h := rng.randf_range(700, 1150)
			_block(x, -h, w, h + 80, dv, 0.14, -0.09)
			x += w + rng.randf_range(60, 260)
		else:
			var w := rng.randf_range(400, 720)
			var h := rng.randf_range(200, 330)
			_block(x, -h, w, h + 80, dv, 0.14, -0.09)
			x += w + rng.randf_range(80, 300)
	x = x0
	while x < x1:
		var seg := rng.randf_range(1200, 3000)
		L.box(x, -452, seg, 20, _s(0.06))
		L.box(x, -404, seg, 28, _s(0.03))
		x += seg + rng.randf_range(400, 1200)
	_height_fog(-700, 200)


func _hangar_back() -> void:
	var wall_top := -620.0
	var x := x0
	while x < x1:
		var seg := rng.randf_range(1100, 2000)
		L.box(x, wall_top, seg, bottom - wall_top, _s(0.0))
		if not flat:
			L.box(x, wall_top - 24, seg, 24, _s(0.12))
			L.box(x, wall_top, seg, 12, _s(-0.08))
			L.box(x, -330, seg, 16, _s(-0.05))
			var sx := x + 256.0
			while sx < x + seg - 64.0:
				L.box(sx, wall_top, 8, 40 - wall_top, _s(-0.06))
				sx += 256.0
		x += seg + rng.randf_range(420, 820)
	# 격납 셔터 — 크게 열려 안쪽이 어둡다
	var bx := _lx(6200.0) - 700.0
	L.box(bx, -1000, 1400, 1040, _s(-0.14))
	if not flat:
		var sy := -1000.0
		while sy < -700.0:
			L.box(bx, sy, 1400, 20, _s(0.02))
			L.box(bx, sy + 20, 1400, 6, _s(-0.1))
			sy += 36.0
		L.box(bx - 40, -1040, 40, 1080, _s(0.06))
		L.box(bx + 1400, -1040, 40, 1080, _s(-0.08))
	# 기둥 + 벽등
	var k := float(tone["lamp"])
	x = x0 + rng.randf_range(100, 500)
	while x < x1:
		var w := rng.randf_range(112, 152)
		L.box(x, top, w, bottom - top, _s(0.0))
		if not flat:
			L.box(x, top, 8, bottom - top, _s(0.07))
			L.box(x + w - 20, top, 20, bottom - top, _s(-0.08))
		var cx := x + w * 0.5
		L.box(cx - 28, -760, 56, 28, _fixture(0.55 + 0.45 * k))
		_glow(Vector2(cx, -746), Vector2(560, 560), k * 0.35)
		_beam(cx, -732, 40, 60, 600, k * 0.18)
		x += w + rng.randf_range(1000, 1500)
	# 천장 크레인 레일 + 훅
	L.box(x0, -1320, x1 - x0, 60, _s(0.02))
	if not flat:
		L.box(x0, -1320, x1 - x0, 8, _s(0.12))
		L.box(x0, -1260, x1 - x0, 12, _s(-0.08))
	var hx := _lx(5800.0)
	_block(hx - 120, -1260, 240, 90, 0.04, 0.12, -0.08)
	L.box(hx - 6, -1170, 12, 360, _s(-0.02))
	_block(hx - 40, -810, 80, 70, 0.03, 0.1, -0.06)
	_height_fog(-600, 60)


func _hangar_ground() -> void:
	_ground_common()
	# 천장 투광등 — 구조 천장에 매달려 층마다 빛 웅덩이를 떨군다 (같은 자리에 실제 광원도 선다)
	var k := float(tone["lamp"])
	for fx in flood_xs():
		var y := -1300.0
		L.box(fx - 12, y - 140, 24, 140, _s(-0.02) if not flat else _s())
		L.box(fx - 70, y, 140, 36, _fixture(0.6 + 0.4 * k))
		if flat:
			continue
		_glow(Vector2(fx, y + 18), Vector2(420, 300), k * 0.6)
		_beam(fx, y + 36, 24, 120, 900, k * 0.16)
		L.glow(Vector2(fx, 14), Vector2(1100, 120), _lamp(k * 0.45))
		for p in D.PLATFORMS:                                      # 발판에 떨어진 빛 웅덩이
			if float(p["x0"]) < fx + 300 and float(p["x1"]) > fx - 300 and p["kind"] == "oneway":
				L.glow(Vector2(fx, -float(p["h"]) + 8), Vector2(700, 70), _lamp(k * 0.40))


static func flood_xs() -> Array:
	return [5000.0, 6500.0, 7950.0]


func _hangar_fg1() -> void:
	_fg_rail(96.0)
	_fg_cables(-900.0)


func _hangar_fg2() -> void:
	_fg_columns(2600, 3600, 130, 210)


func _hangar_front() -> void:
	_front_rails(["gantry"], 56.0)


# ════════════════════════════════════════════════════════════════════════════════
# 3. 환풍 덕트 — 덕트 안벽(뒤벽, 거의 붙어 온다) · 환풍기 터널(원경1) · 바깥은 전부 막혀 있다
# ════════════════════════════════════════════════════════════════════════════════

func _duct_far1() -> void:
	# 환풍기실 너머 — 멀어질수록 어두워지는 사각 링 (터널 원근). 환풍기 노드는 DepthLab 이 이 레이어에 붙인다
	var c := Vector2(_lx(FAN_X), _ly(FAN_H))
	L.box(c.x - 1400, c.y - 1200, 2800, 2400, _s(-0.06))
	for i in range(7):
		var t := float(i) / 6.0
		var w := lerpf(1300.0, 700.0, t)
		var h := lerpf(1000.0, 700.0, t)
		var v := lerpf(0.10, -0.12, t)
		L.box(c.x - w * 0.5, c.y - h * 0.5, w, h, _s(v))
		if not flat:
			L.box(c.x - w * 0.5, c.y - h * 0.5, w, 8, _s(v + 0.06))
	_glow(c, Vector2(1600, 1600), 0.18)


static func fan_local(f_: float, z: Dictionary) -> Vector2:
	var a := anchor_x(z)
	return Vector2(a + (FAN_X - a) * f_, AY + (-FAN_H - AY) * f_)


func _duct_back() -> void:
	# 덕트 안벽 — 판 이음 · 리벳 · 환기 그릴(뒤에서 빛이 새고, 빛살이 비스듬히 떨어진다)
	var hole := Rect2(_lx(10300.0), _ly(780.0), _lx(11200.0) - _lx(10300.0), _ly(0.0) - _ly(780.0) + 40.0)
	L.box(x0, top, hole.position.x - x0, bottom - top, _s(0.0))
	L.box(hole.end.x, top, x1 - hole.end.x, bottom - top, _s(0.0))
	L.box(hole.position.x, top, hole.size.x, hole.position.y - top, _s(0.0))
	L.box(hole.position.x, hole.end.y, hole.size.x, bottom - hole.end.y, _s(0.0))
	if flat:
		return
	L.box(hole.position.x - 24, hole.position.y - 24, hole.size.x + 48, 24, _s(0.12))
	L.box(hole.position.x - 24, hole.position.y, 24, hole.size.y, _s(0.05))
	L.box(hole.end.x, hole.position.y, 24, hole.size.y, _s(-0.1))
	var y := -64.0
	while y > top:
		L.box(x0, y, hole.position.x - x0, 4, _s(-0.06))
		L.box(hole.end.x, y, x1 - hole.end.x, 4, _s(-0.06))
		y -= 64.0
	var x := x0
	while x < x1:
		if x < hole.position.x - 20 or x > hole.end.x + 20:
			L.box(x, top, 6, bottom - top, _s(-0.05))
			for ry in range(-40, -380, -64):
				L.box(x + 12, ry, 4, 4, _s(0.08))
		x += 256.0
	# 그릴 — 슬랫 사이로 빛, 빛살은 오른쪽 아래로
	x = x0 + rng.randf_range(200, 500)
	while x < x1:
		if x > hole.position.x - 260 and x < hole.end.x + 60:
			x += 300
			continue
		var gy := -250.0
		L.box(x, gy, 160, 96, _s(-0.12))
		for s in range(5):
			L.light_box(x + 8, gy + 8 + s * 18, 144, 8, _lamp(0.55))
		L.light_poly(PackedVector2Array([Vector2(x, gy + 96), Vector2(x + 160, gy + 96), Vector2(x + 420, 20), Vector2(x + 160, 20)]),
			PackedColorArray([_lamp(0.16), _lamp(0.16), _lamp(0.0), _lamp(0.0)]))
		x += rng.randf_range(560, 900)
	# 덕트 가운데로 갈수록 짙어지는 어둠 — 양 끝(격납고·샤프트 쪽)은 바깥 빛이 조금 든다
	var za := _lx(float(zone["x0"]))
	var zb := _lx(float(zone["x1"]))
	var q1 := lerpf(za, zb, 0.25)
	var q3 := lerpf(za, zb, 0.75)
	_dark_h(za, q1, 0.0, 0.45)
	_dark_h(q3, zb, 0.45, 0.0)
	L.box(q1, top, hole.position.x - q1, bottom - top, Color(0, 0, 0, 0.45))
	L.box(hole.end.x, top, q3 - hole.end.x, bottom - top, Color(0, 0, 0, 0.45))


func _duct_ground() -> void:
	_ground_common()
	# 덕트 마디 — 캐릭터 뒤 얇은 테두리 (환풍기실은 비운다)
	var x := float(zone["x0"]) + 256.0
	while x < float(zone["x1"]) - 128.0:
		if x < 10240.0 or x > 11264.0:
			var clear := zone_clear_at(x)
			L.box(x, -clear, 24, clear, _s(-0.06) if not flat else _s())
		x += 512.0
	# 기어가는 구간 — 낮아진 덕트 천장
	for cr in D.CRAWLS:
		var a := float(cr[0])
		var b := float(cr[1])
		var gap := float(cr[2])
		var clear := zone_clear_at((a + b) * 0.5)
		L.box(a, -clear, b - a, clear - gap, _c(float(tone["floor_face"]) + 0.08) if not flat else _s())
		if not flat:
			L.box(a, -gap - 8, b - a, 8, _c(float(tone["floor_face"]) + 0.22))
			L.box(a, -clear, 8, clear - gap, _c(float(tone["floor_face"]) + 0.16))
	# 경고등 — 천장 밑에서 번진다 (실제 광원도 같은 자리에서 맥박친다)
	for wx in warning_xs():
		var clear := zone_clear_at(wx)
		L.box(wx - 24, -clear, 48, 20, _fixture(0.85))
		_glow(Vector2(wx, -clear + 20), Vector2(460, 300), 0.45)


static func warning_xs() -> Array:
	return [9560.0, 11700.0]


func zone_clear_at(x: float) -> float:
	var cx := float(zone["x0"])
	for seg in zone["cols"]:
		var w := float(seg[0]) * D.CELL
		if w > 0.0 and x < cx + w:
			return D.clearance_cells(int(seg[1]))
		cx += w
	for i in range(zone["cols"].size() - 1, -1, -1):
		if int(zone["cols"][i][0]) > 0:
			return D.clearance_cells(int(zone["cols"][i][1]))
	return 1000.0


func _duct_fg1() -> void:
	# 앞을 지나가는 덕트 테두리 — 폐쇄감을 가장 크게 만든다
	var v := float(tone["fg"]["fg1"])
	var body := _c(v)
	var edge := _c(v + float(tone["rim"])) if not flat else body
	var x := x0 + rng.randf_range(0, 500)
	while x < x1:
		var w := rng.randf_range(60, 90)
		L.box(x, top, w, bottom - top, body)
		L.box(x, top, 4, bottom - top, edge)
		x += w + rng.randf_range(700, 1100)
	L.box(x0, 60, x1 - x0, 90, body)
	L.box(x0, 60, x1 - x0, 4, edge)
	L.box(x0, 240, x1 - x0, bottom - 240, body)


func _duct_fg2() -> void:
	_fg_columns(3000, 4200, 110, 170)


# ════════════════════════════════════════════════════════════════════════════════
# 4. 수직 케이블 샤프트 — 아래는 어둠, 위는 채광. 뒤벽의 층 표시 · 작업등이 턱 높이에 맞는다
# ════════════════════════════════════════════════════════════════════════════════

func _shaft_sky() -> void:
	var s: Array = tone["sky"]
	if flat:
		_fill()
		return
	L.vgrad(x0, top, x1 - x0, -1200 - top, _c(s[0]), _c(s[1]))
	L.vgrad(x0, -1200, x1 - x0, bottom + 1200, _c(s[1]), _c(s[2]))


func _shaft_far3() -> void:
	var x := x0
	while x < x1:
		L.box(x, top, 140, bottom - top, _s(0.02))
		x += rng.randf_range(600, 900)
	var y := 200.0
	while y > top:
		L.box(x0, y, x1 - x0, 30, _s(0.0))
		y -= 520.0
	_dark_v(-600, bottom, 0.0, 0.85)


func _shaft_far2() -> void:
	L.box(x0, top, x1 - x0, bottom - top, _s(-0.04))
	var x := x0 + rng.randf_range(0, 200)
	while x < x1:
		_block(x, top, 64, bottom - top, 0.02, 0.0, -0.06)
		x += rng.randf_range(260, 360)
	var y := 100.0
	while y > top:
		_block(x0, y, x1 - x0, 24, 0.03, 0.10, 0.0)
		y -= 420.0
	# 매달린 케이블 다발
	x = x0 + rng.randf_range(100, 400)
	while x < x1:
		L.box(x, top, 10, rng.randf_range(bottom - top - 1400, bottom - top), _s(-0.06))
		x += rng.randf_range(180, 420)
	_beam(_lx(13120.0), top, 200, 600, 1600, 0.08)
	_dark_v(-900, bottom, 0.0, 0.9)


func _shaft_far1() -> void:
	# 엘리베이터 가이드 레일 · 균형추 · 엇갈린 가새
	var rx := _lx(12900.0)
	L.box(rx - 180, top, 24, bottom - top, _s(0.04))
	L.box(rx + 156, top, 24, bottom - top, _s(0.04))
	_block(rx - 150, _ly(1700.0), 300, 380, 0.05, 0.12, -0.08)
	L.box(rx - 4, top, 8, _ly(1700.0) - top, _s(0.0))
	var y := 0.0
	while y > top:
		var xa := x0
		while xa < x1:
			L.line(Vector2(xa, y), Vector2(xa + 520, y - 520), _s(-0.02), 14.0)
			L.line(Vector2(xa + 520, y), Vector2(xa, y - 520), _s(-0.02), 14.0)
			xa += 1100.0
		y -= 520.0
	_dark_v(-800, bottom, 0.0, 0.8)


func _shaft_back() -> void:
	# 샤프트 뒤벽 — 좌우 벽판만 있고 가운데는 트여 샤프트 안쪽(원경)이 어둠으로 내려간다.
	# 판 격자 · 케이블 트레이 · 턱마다 층 표시 띠와 작업등
	var open_a := _lx(12900.0) - 200.0
	var open_b := _lx(12900.0) + 260.0
	for band in [[x0, open_a], [open_b, x1]]:
		L.box(band[0], top, band[1] - band[0], bottom - top, _s(0.0))
		if not flat:
			var gx: float = band[0]
			while gx < band[1]:
				L.box(gx, top, 6, bottom - top, _s(-0.06))
				gx += 256.0
			var gy := 0.0
			while gy > top:
				L.box(band[0], gy, band[1] - band[0], 6, _s(-0.06))
				gy -= 256.0
	L.box(open_a - 24, top, 24, bottom - top, _s(0.10))
	L.box(open_b, top, 24, bottom - top, _s(-0.10))
	var by := 0.0
	while by > top:                                               # 트인 곳을 가로지르는 보
		_block(open_a, by - 40, open_b - open_a, 40, 0.02, 0.12, 0.0)
		by -= 640.0
		for tx in [_lx(12650.0), _lx(13560.0)]:
			L.box(tx, top, 96, bottom - top, _s(-0.08))
			L.box(tx + 8, top, 8, bottom - top, _s(0.05))
			var ty := 0.0
			while ty > top:
				L.box(tx + 20, ty, 56, 12, _s(0.04))
				ty -= 96.0
	var k := float(tone["lamp"])
	for p in _zone_platforms():
		if String(p["look"]) != "ledge":
			continue
		var h := float(p["h"])
		var a := _lx(float(p["x0"]))
		var b := _lx(float(p["x1"]))
		var y := _ly(h) - 48.0
		if not flat:
			var sx := a
			var alt := false
			while sx < b:                                        # 층 표시 줄무늬
				L.box(sx, y, 32, 16, _s(0.20 if alt else -0.06))
				sx += 32.0
				alt = not alt
		var lx := (a + b) * 0.5
		L.box(lx - 24, _ly(h + 200.0), 48, 20, _fixture(0.6 + 0.4 * k))
		_glow(Vector2(lx, _ly(h + 190.0)), Vector2(520, 420), k * 0.35)
		_beam(lx, _ly(h + 180.0), _ly(h) + 10.0, 50, 560, k * 0.14)
	# 아래로 갈수록 어둠 — 바닥 쪽
	_dark_v(_ly(700.0), bottom, 0.0, 0.7)


func _shaft_ground() -> void:
	_ground_common()
	if flat:
		return
	# 천장 채광창 — 샤프트 꼭대기
	var cx := anchor_x(zone)
	var clear := D.clearance_cells(27)
	L.light_box(cx - 300, -clear - 24, 600, 24, _lamp(0.9))
	_beam(cx, -clear, -200, 600, 1400, 0.12)
	L.glow(Vector2(cx, -clear), Vector2(1400, 500), _lamp(0.4))


func _shaft_fg1() -> void:
	var v := float(tone["fg"]["fg1"])
	var body := _c(v)
	var edge := _c(v + float(tone["rim"])) if not flat else body
	var x := x0 + rng.randf_range(0, 400)
	while x < x1:
		var w := rng.randf_range(48, 80)
		L.box(x, top, w, bottom - top, body)
		L.box(x, top, 6, bottom - top, edge)
		x += w + rng.randf_range(900, 1500)
	L.box(x0, 140, x1 - x0, bottom - 140, body)
	L.box(x0, 140, x1 - x0, 4, edge)


func _shaft_fg2() -> void:
	_fg_columns(2600, 3400, 140, 220)


# ════════════════════════════════════════════════════════════════════════════════
# 5. 전력 홀 상층 캣워크 — 빛이 아래(홀 바닥)에서 올라온다. 코일 탑 · 크레인 · 캣워크 난간
# ════════════════════════════════════════════════════════════════════════════════

func _relay_sky() -> void:
	var s: Array = tone["sky"]
	if flat:
		_fill()
		return
	L.vgrad(x0, top, x1 - x0, -1400 - top, _c(s[0]), _c(s[1]))
	L.vgrad(x0, -1400, x1 - x0, bottom + 1400, _c(s[1]), _c(s[2]))
	_uplight(bottom, -1600, 0.10)


func _relay_far3() -> void:
	L.box(x0, top, x1 - x0, bottom - top, _s(-0.02))
	var x := x0 + rng.randf_range(0, 300)
	var ribs: Array = []
	while x < x1:
		_block(x, top, 90, bottom - top, 0.03, 0.10, -0.04)
		ribs.append(x)
		x += rng.randf_range(560, 680)
	for i in range(ribs.size() - 1):                           # 늑재 사이 아치
		var a: float = ribs[i] + 90.0
		var b: float = ribs[i + 1]
		var pts := PackedVector2Array()
		for k in range(17):
			var t := float(k) / 16.0
			pts.append(Vector2(lerpf(a, b, t), -3000.0 + 260.0 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
		L.polyline(pts, _s(0.04), 30.0)
	_uplight(bottom, -1800, 0.14)


func _relay_far2() -> void:
	# 코일 탑 — 몸통 · 띠 · 절연체 · 빛나는 끝, 가끔 탑 사이 방전
	var tips: Array = []
	var x := x0 + rng.randf_range(0, 400)
	while x < x1:
		var w := rng.randf_range(170, 250)
		var h := rng.randf_range(1000, 1900)          # 끝이 캣워크 눈높이 근처 — 올라가면 빛나는 끝이 보인다
		var dv := rng.randf_range(-0.03, 0.03)
		_block(x, -h, w, h + 400, dv, 0.14, -0.06)
		if not flat:
			var by := -h + 120.0
			while by < 200.0:
				L.box(x, by, w, 10, _s(dv + 0.10))
				by += 160.0
		for d in range(4):
			var dw := w * (1.3 - d * 0.18)
			_block(x + (w - dw) * 0.5, -h - 60 - d * 70, dw, 50, dv + 0.05, 0.14, -0.05)
		var tip := Vector2(x + w * 0.5, -h - 330)
		tips.append(tip)
		_glow(tip, Vector2(420, 420), 0.55)
		_glow(tip, Vector2(120, 120), 0.8)
		x += w + rng.randf_range(520, 900)
	if not flat:
		for i in range(tips.size() - 1):
			if rng.randf() > 0.35:
				continue
			var a: Vector2 = tips[i]
			var b: Vector2 = tips[i + 1]
			var prev := a
			for k in range(1, 10):
				var t := float(k) / 9.0
				var q := a.lerp(b, t) + Vector2(0, rng.randf_range(-60, 60) if k < 9 else 0.0)
				L.light_poly(PackedVector2Array([prev + Vector2(0, -4), q + Vector2(0, -4), q + Vector2(0, 4), prev + Vector2(0, 4)]),
					PackedColorArray([_lamp(0.7), _lamp(0.7), _lamp(0.7), _lamp(0.7)]))
				prev = q
	_uplight(bottom, -1200, 0.12)


func _relay_far1() -> void:
	# 갠트리 크레인 · 변압기 · 늘어진 케이블
	var y := -1500.0
	L.box(x0, y, x1 - x0, 50, _s(0.02))
	var x := x0 + rng.randf_range(0, 600)
	while x < x1:
		_block(x, y, 60, -y + 400, 0.0, 0.10, -0.06)
		x += rng.randf_range(1400, 2200)
	x = x0 + rng.randf_range(0, 500)
	while x < x1:
		var w := rng.randf_range(300, 520)
		var h := rng.randf_range(300, 520)
		_block(x, -h, w, h + 400, 0.02, 0.14, -0.08)
		for k in range(3):
			L.box(x + 40 + k * (w - 80) / 2.0, -h - 120, 24, 120, _s(0.05))
		x += w + rng.randf_range(500, 1200)
	x = x0
	while x < x1:
		var span := rng.randf_range(700, 1300)
		var pts := PackedVector2Array()
		for i in range(13):
			var t := i / 12.0
			pts.append(Vector2(x + span * t, lerpf(-2100, -1800, 1.0 - pow(2.0 * t - 1.0, 2.0))))
		L.polyline(pts, _s(-0.02), 16.0)
		x += span + rng.randf_range(200, 700)
	_uplight(bottom, -900, 0.10)


func _relay_back() -> void:
	# 홀 가까운 쪽 구조 — 통벽이 아니다. 기둥 사이로 코일 탑(원경)이 보인다
	var x := x0 + rng.randf_range(0, 300)
	while x < x1:
		_block(x, top, 150, bottom - top, 0.0, 0.14, -0.08)
		x += rng.randf_range(860, 1100)
	# 캣워크 높이의 보 + 절연체 줄 (캣워크에 서면 눈앞에 온다)
	var cy := _ly(2240.0)
	_block(x0, cy - 380, x1 - x0, 44, 0.03, 0.12, 0.0)
	x = x0 + 60.0
	while x < x1:
		for d in range(4):
			L.box(x - 16 + (d % 2) * 4, cy - 336 + d * 34, 32 - (d % 2) * 8, 26, _s(0.10))
		x += 220.0
	# 아래쪽 변압기 외함 — 홀 바닥 뒤
	x = x0 + rng.randf_range(0, 400)
	while x < x1:
		var w := rng.randf_range(420, 700)
		_block(x, -520, w, bottom + 520, 0.02, 0.14, -0.08)
		x += w + rng.randf_range(300, 700)
	_uplight(bottom, _ly(1600.0), 0.16)


func _relay_ground() -> void:
	_ground_common()
	if flat:
		return
	# 홀 바닥 조명 줄 — 이 빛이 홀 전체를 아래에서 비춘다 (실제 광원도 같은 자리)
	var k := float(tone["lamp"])
	for ux in uplight_xs():
		L.light_box(ux - 220, 26, 440, 10, _lamp(0.9))
		L.glow(Vector2(ux, 20), Vector2(1200, 180), _lamp(k * 0.5))
		_beam(ux, 20, -1400, 440, 1600, k * 0.05)


static func uplight_xs() -> Array:
	return [14500.0, 15600.0, 16700.0, 17800.0]


func _relay_fg1() -> void:
	var v := float(tone["fg"]["fg1"])
	var body := _c(v)
	var edge := _c(v + float(tone["rim"])) if not flat else body
	var x := x0 + rng.randf_range(0, 600)
	while x < x1:                                                  # 앞 변압기 실루엣 (바닥 아래쪽)
		var w := rng.randf_range(300, 600)
		var y := rng.randf_range(120, 200)
		L.box(x, y, w, bottom - y, body)
		L.box(x, y, w, 4, edge)
		x += w + rng.randf_range(900, 1700)
	for h in [1100.0, 2700.0]:
		var yy := _ly(h)
		x = x0
		while x < x1:
			var span := rng.randf_range(600, 1100)
			var pts := PackedVector2Array()
			for i in range(13):
				var t := i / 12.0
				pts.append(Vector2(x + span * t, yy - 200.0 + 220.0 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
			L.polyline(pts, body, 16.0)
			x += span + rng.randf_range(600, 1400)


func _relay_fg2() -> void:
	_fg_columns(2400, 3400, 150, 240)


func _relay_front() -> void:
	_front_rails(["catwalk", "crane"], 64.0)


func _shaft_front() -> void:
	_front_rails(["catwalk"], 64.0)


# ════════════════════════════════════════════════════════════════════════════════
# 공통 — 땅(바닥판 · 구조 천장 · 발판 · 구역 문틀) · 근경 부품 · 앞 난간
# ════════════════════════════════════════════════════════════════════════════════

func _zone_platforms() -> Array:
	var out: Array = []
	for p in D.PLATFORMS:
		if float(p["x0"]) < float(zone["x1"]) and float(p["x1"]) > float(zone["x0"]):
			out.append(p)
	return out


func _ground_common() -> void:
	var t := float(tone["floor_top"])
	var face := float(tone["floor_face"])
	var w := x1 - x0
	# 구조 천장 — 열 프로필 밖(RoomSolid 가 막는 곳)을 덩어리로 칠한다. 몬스터가 여기를 타고 기어간다
	var cx := float(zone["x0"])
	var mass := clampf(face * 0.9, 0.02, 0.3)
	for seg in zone["cols"]:
		var sw := float(seg[0]) * D.CELL
		if sw <= 0.0:
			continue
		var clear := D.clearance_cells(int(seg[1]))
		L.box(cx, -6000, sw, 6000 - clear, _c(mass) if not flat else _s())
		if not flat:
			L.box(cx, -clear - 48, sw, 48, _c(mass + 0.06))
			L.box(cx, -clear - 4, sw, 4, _c(mass + 0.16))
			var rx := cx + 64.0
			while rx < cx + sw:
				L.box(rx, -clear - 48, 16, 48, _c(mass - 0.02))
				rx += 256.0
		cx += sw
	if flat:
		L.box(x0, 0, w, 24, _s())
		L.box(x0, 24, w, 2200, _c(face))
	else:
		L.box(x0, 0, w, 24, _c(t))
		L.box(x0, 24, w, 8, _c(minf(1.0, t + 0.14)))
		L.vgrad(x0, 32, w, 2100, _c(face), _c(face * 0.35))
		L.box(x0, 200, w, 12, _c(face * 0.6))
		var sx := float(zone["x0"])
		while sx < x1:
			L.box(sx, 0, 4, 24, _c(t - 0.10))
			sx += 256.0
	# 발판
	for p in _zone_platforms():
		_platform(p)
	# 구역 경계 문틀 — 이웃 구역과 배경이 바뀌는 이음매를 덮는다
	for edge in [float(zone["x0"]), float(zone["x1"])]:
		if edge <= 0.0 or edge >= float(D.world_w()):
			continue
		var clear := zone_clear_at(clampf(edge, float(zone["x0"]) + 1.0, float(zone["x1"]) - 1.0))
		L.box(edge - 56, -clear, 112, clear, _c(mass + 0.04) if not flat else _s())
		if not flat:
			L.box(edge - 56, -clear, 8, clear, _c(mass + 0.16))
			L.box(edge + 40, -clear, 16, clear, _c(mass - 0.02))
			L.box(edge - 80, -clear - 40, 160, 40, _c(mass + 0.10))


func _platform(p: Dictionary) -> void:
	var a := float(p["x0"])
	var b := float(p["x1"])
	var h := float(p["h"])
	var pv := float(tone["prop"])
	var look := String(p["look"])
	var body := _c(pv) if not flat else _s()
	match look:
		"step", "deck":
			L.box(a, -h, b - a, h, body)
			if not flat:
				L.box(a, -h, b - a, 8, _c(pv + 0.18))
				L.box(a, -h + 8, 4, h - 8, _c(pv + 0.06))
				L.box(b - 16, -h + 8, 16, h - 8, _c(pv - 0.10))
				if look == "deck":
					var sx := a + 160.0
					while sx < b - 80:
						L.box(sx, -h + 30, 8, h - 40, _c(pv - 0.06))
						sx += 240.0
		"crate":
			L.box(a, -h, b - a, h, body)
			if not flat:
				L.box(a, -h, b - a, 8, _c(pv + 0.18))
				L.box(b - 20, -h + 8, 20, h - 8, _c(pv - 0.11))
				var cy := -h
				while cy < -4.0:
					L.line(Vector2(a + 8, cy + 12), Vector2(b - 24, cy + 152), _c(pv - 0.06), 8.0)
					L.box(a, cy + 156, b - a, 4, _c(pv - 0.08))
					cy += 160.0
		_:
			var th := 20.0 if look == "catwalk" else 28.0
			L.box(a, -h, b - a, th, body)
			if flat:
				return
			L.box(a, -h, b - a, 6, _c(pv + 0.18))
			L.box(a, -h + th - 6, b - a, 6, _c(pv - 0.12))
			if look == "catwalk" or look == "grate":
				var gx := a + 8.0
				while gx < b - 8:
					L.box(gx, -h + 8, 12, th - 14, _c(pv - 0.14))
					gx += 24.0
			if look != "ledge":                                   # 뒤 난간 (캐릭터 뒤)
				L.box(a, -h - 92, b - a, 8, _c(pv - 0.04))
				var px := a
				while px < b:
					L.box(px, -h - 92, 8, 92, _c(pv - 0.06))
					px += 160.0
			match look:
				"gantry", "grate":
					var lx := a + 60.0
					while lx < b:
						L.box(lx, -h + th, 24, h - th, _c(pv - 0.08))
						L.line(Vector2(lx + 12, -h + th + 20), Vector2(lx + minf(220.0, h * 0.6), -h + th + minf(220.0, h * 0.6)), _c(pv - 0.1), 10.0)
						lx += 480.0
				"catwalk":
					var hx := a + 100.0
					while hx < b:
						L.box(hx, -3400, 10, 3400 - h, _c(pv - 0.12))
						hx += 400.0
				"crane":
					L.box(a + 40, -3400, 12, 3400 - h, _c(pv - 0.1))
					L.box(b - 52, -3400, 12, 3400 - h, _c(pv - 0.1))
					_block(a + (b - a) * 0.5 - 60, -h + th, 120, 60, 0.02, 0.12, -0.08)
				"ledge":
					var bx := a + 80.0
					while bx < b - 40:
						L.poly(PackedVector2Array([Vector2(bx, -h + th), Vector2(bx + 24, -h + th),
							Vector2(bx + 24, -h + th + 24), Vector2(bx, -h + th + 160)]), _c(pv - 0.08))
						bx += 260.0


## 앞 난간 (계수 1, 캐릭터 앞) — 발판 앞 모서리의 낮은 난간. 무릎 아래라 다리 움직임을 가리지 않는다
func _front_rails(looks: Array, rail_h: float) -> void:
	var v := float(tone["fg"]["fg1"]) + 0.02
	var body := _c(v)
	var edge := _c(v + float(tone["rim"])) if not flat else body
	for p in _zone_platforms():
		if not looks.has(String(p["look"])):
			continue
		var a := float(p["x0"])
		var b := float(p["x1"])
		var h := float(p["h"])
		L.box(a, -h + 20, b - a, 14, body)
		L.box(a, -h - rail_h, b - a, 10, body)
		L.box(a, -h - rail_h, b - a, 3, edge)
		var px := a
		while px < b:
			L.box(px, -h - rail_h, 10, rail_h + 20, body)
			px += 200.0


func _fg_struts() -> void:
	var v := float(tone["fg"]["fg1"])
	var body := _c(v)
	var edge := _c(v + float(tone["rim"])) if not flat else body
	var x := x0 + rng.randf_range(0, 600)
	while x < x1:
		var w := rng.randf_range(500, 900)
		L.poly(PackedVector2Array([Vector2(x, bottom), Vector2(x + 90, bottom), Vector2(x + w, 160), Vector2(x + w - 90, 160)]), body)
		L.box(x, 140, w * 1.1, 40, body)
		L.box(x, 140, w * 1.1, 4, edge)
		x += w + rng.randf_range(900, 1800)


func _fg_top_rib(y: float) -> void:
	var v := float(tone["fg"]["fg1"])
	var body := _c(v)
	var edge := _c(v + float(tone["rim"])) if not flat else body
	L.box(x0, top, x1 - x0, y - top, body)
	L.box(x0, y - 4, x1 - x0, 4, edge)
	var x := x0
	while x < x1:
		L.poly(PackedVector2Array([Vector2(x, y), Vector2(x + 160, y), Vector2(x + 60, y + 120), Vector2(x, y + 120)]), body)
		x += rng.randf_range(900, 1600)


func _fg_rail(y: float) -> void:
	var v := float(tone["fg"]["fg1"])
	var body := _c(v)
	var edge := _c(v + float(tone["rim"])) if not flat else body
	var x := x0
	while x < x1:
		var seg := rng.randf_range(1400, 3000)
		L.box(x, y, seg, 28, body)
		L.box(x, y, seg, 4, edge)
		L.box(x, y + 164, seg, 16, body)
		var px := x
		while px < x + seg:
			L.box(px, y + 28, 20, bottom - y, body)
			px += 360.0
		x += seg + rng.randf_range(600, 1400)


func _fg_cables(sag_y: float) -> void:
	var v := float(tone["fg"]["fg1"])
	var body := _c(v)
	var x := x0 + rng.randf_range(0, 600)
	while x < x1:
		var span := rng.randf_range(420, 900)
		var low := sag_y + rng.randf_range(0, 60)
		var pts := PackedVector2Array()
		for i in range(13):
			var t := i / 12.0
			pts.append(Vector2(x + span * t, lerpf(sag_y - 260.0, low, 1.0 - pow(2.0 * t - 1.0, 2.0))))
		L.polyline(pts, body, 14.0)
		x += span + rng.randf_range(500, 1400)


func _fg_columns(gap_min: float, gap_max: float, w_min: float, w_max: float) -> void:
	var v := float(tone["fg"]["fg2"])
	var body := _c(v)
	var edge := _c(v + float(tone["rim"]) * 0.7) if not flat else body
	var x := x0 + rng.randf_range(0, 1200)
	while x < x1:
		var w := rng.randf_range(w_min, w_max)
		L.box(x, top, w, bottom - top, body)
		L.box(x, top, 6, bottom - top, edge)
		x += w + rng.randf_range(gap_min, gap_max)
