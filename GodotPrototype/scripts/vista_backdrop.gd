class_name VistaBackdrop
extends Node2D
## 방 너머 원경 (2026-09-25, 공간 테스트 씬 시험 적용).
##
## 지금까지 방 실루엣 밖은 WallShadow 가 완전한 검정으로 덮었다 — "검은 공간에 방 상자 하나" 라서
## 큰 화면일수록 화면의 2/3 가 비었다. 이 층은 그 자리에 **지하 거대 공동 속에 선 시설 단면**을 깐다:
## 먼 탑·트러스·창 불빛(먼 층)과 가까운 거대 배관·거더(가까운 층)를 패럴랙스로 겹친다.
##
## 규칙
##   · 전용 원경 아트가 아직 없어 **코드로 그린다.** 모든 사각형은 아트 1px(월드 4px) 격자에 맞춘다 — 픽셀 규칙.
##   · 조명을 받지 않는다(unshaded). 방 안 램프가 원경을 밝히면 벽 너머가 같은 공간처럼 읽힌다.
##     단, 방의 CanvasModulate(앰비언트)는 그대로 곱해지므로 색은 그만큼 밝게 잡는다(BRIGHT).
##   · 패럴랙스는 가로만. 세로는 월드와 같이 움직인다 — 방 안에서 카메라 세로 이동은 조준 리드 정도뿐이다.
##   · 방 타일 뒤(z −100). 방 배경 타일이 불투명하므로 원경은 **방 실루엣 밖에서만** 보인다.
##
## 이 방이 원경을 쓰는지는 방 데이터의 "vista": true 로 정한다 (지금은 SpaceLabData 만).

const Q := 4.0                          # 아트 1px = 월드 4px
const MARGIN := 4000.0                  # 방 좌우 밖으로 더 그리는 폭
const SKY_TOP := -3200.0                # 바닥선 기준 위로
const SKY_BOTTOM := 2400.0              # 바닥선 기준 아래로
const BRIGHT := 2.1                     # 앰비언트(≈0.42~0.55)가 곱해지는 만큼 미리 밝힌다

## [패럴랙스 계수, 층 이름]. 계수 = 월드가 움직일 때 그 층이 따라 움직이는 비율 (1 = 방과 같이, 0 = 화면에 고정)
const LAYERS := [[0.12, "Sky"], [0.28, "Far"], [0.52, "Mid"]]

var _layers: Array = []                 # [Node2D, 계수]


func setup(room_width: float, floor_y: float, seed_text: String) -> void:
	z_index = -100
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text + "_vista")
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for spec in LAYERS:
		var layer := VistaLayer.new()
		layer.name = spec[1]
		layer.material = mat
		add_child(layer)
		_layers.append([layer, float(spec[0])])
	var x0 := -MARGIN
	var x1 := room_width + MARGIN
	_build_sky(_layers[0][0], x0, x1, floor_y)
	_build_far(_layers[1][0], x0, x1, floor_y, rng)
	_build_mid(_layers[2][0], x0, x1, floor_y, rng)
	for l in _layers:
		(l[0] as VistaLayer).queue_redraw()


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var cx := cam.get_screen_center_position().x
	for l in _layers:
		# 층의 로컬 x 가 화면 가운데에서 cx·계수 가 되도록 — 계수가 작을수록 느리게 흐른다
		(l[0] as Node2D).position.x = cx * (1.0 - float(l[1]))


static func _q(v: float) -> float:
	return round(v / Q) * Q


static func _c(r: float, g: float, b: float, a := 1.0) -> Color:
	return Color(minf(r * BRIGHT, 1.0), minf(g * BRIGHT, 1.0), minf(b * BRIGHT, 1.0), a)


# ── 하늘: 공동의 어둠. 바닥선 조금 위가 가장 밝은(먼 조명에 번진) 띠 ───────────────────

func _build_sky(l: VistaLayer, x0: float, x1: float, floor_y: float) -> void:
	var top := floor_y + SKY_TOP
	var bottom := floor_y + SKY_BOTTOM
	var glow_y := floor_y - 520.0
	var band := 48.0                      # 띠 단위로 끊어 칠한다 (계단 그라데이션 — 픽셀 아트 톤)
	var y := top
	var deep := _c(0.030, 0.038, 0.066)
	var glow := _c(0.070, 0.086, 0.130)
	var under := _c(0.022, 0.026, 0.044)
	while y < bottom:
		var t: float
		var col: Color
		if y < glow_y:
			t = clampf((y - top) / (glow_y - top), 0.0, 1.0)
			col = deep.lerp(glow, t * t)
		else:
			t = clampf((y - glow_y) / (bottom - glow_y), 0.0, 1.0)
			col = glow.lerp(under, sqrt(t))
		l.rects.append([Rect2(x0, y, x1 - x0, band), col])
		y += band


# ── 먼 층: 거대 탑 · 층마다 띠 · 창 불빛 · 탑 사이 트러스 · 안개 ───────────────────────

func _build_far(l: VistaLayer, x0: float, x1: float, floor_y: float, rng: RandomNumberGenerator) -> void:
	var body := _c(0.052, 0.063, 0.100)
	var rib := _c(0.066, 0.079, 0.122)
	var edge := _c(0.080, 0.095, 0.142)
	var truss := _c(0.060, 0.072, 0.112)
	var warm := _c(0.42, 0.28, 0.12)
	var cool := _c(0.16, 0.36, 0.42)
	var red := _c(0.50, 0.08, 0.06)
	var bottom := floor_y + SKY_BOTTOM
	var towers: Array = []                # [x, w, top]
	var x := x0
	while x < x1:
		var w := _q(rng.randf_range(128.0, 336.0))
		var top := _q(floor_y + rng.randf_range(-2700.0, -1100.0))
		towers.append([_q(x), w, top])
		x += w + rng.randf_range(360.0, 900.0)
	for tw in towers:
		var tx: float = tw[0]
		var w: float = tw[1]
		var top: float = tw[2]
		l.rects.append([Rect2(tx, top, w, bottom - top), body])
		l.rects.append([Rect2(tx, top, Q * 2.0, bottom - top), edge])          # 한쪽 모서리만 밝게 — 먼 빛의 방향
		var step := _q(rng.randf_range(96.0, 176.0))
		var ry := top + step
		while ry < bottom:
			l.rects.append([Rect2(tx, ry, w, Q * 2.0), rib])
			ry += step
		# 창 불빛 — 대부분 꺼져 있고 드문드문 켜져 있다
		var wy := top + 32.0
		while wy < bottom - 32.0:
			var wx := tx + 16.0
			while wx < tx + w - 16.0:
				if rng.randf() < 0.07:
					l.rects.append([Rect2(wx, wy, Q * 2.0, Q * 2.0), warm if rng.randf() < 0.7 else cool])
				wx += 32.0
			wy += 32.0
		# 꼭대기 안테나 + 적색 표지등
		var ax := _q(tx + w * rng.randf_range(0.3, 0.7))
		var ah := _q(rng.randf_range(80.0, 220.0))
		l.rects.append([Rect2(ax, top - ah, Q * 2.0, ah), edge])
		l.rects.append([Rect2(ax - Q, top - ah - Q * 2.0, Q * 4.0, Q * 3.0), red])
	# 이웃 탑을 잇는 트러스 (두께 16 + X 가새)
	for i in range(towers.size() - 1):
		if rng.randf() < 0.35:
			continue
		var a: Array = towers[i]
		var b: Array = towers[i + 1]
		var sx: float = a[0] + a[1]
		var ex: float = b[0]
		if ex - sx < 64.0:
			continue
		var ty := _q(floor_y + rng.randf_range(-1800.0, -700.0))
		ty = maxf(ty, maxf(float(a[2]), float(b[2])) + 64.0)
		var th := 64.0
		l.rects.append([Rect2(sx, ty, ex - sx, Q * 3.0), truss])
		l.rects.append([Rect2(sx, ty + th, ex - sx, Q * 3.0), truss])
		var cx := sx
		while cx < ex - th:
			for k in range(int(th / (Q * 2.0))):
				var d := float(k) * Q * 2.0
				l.rects.append([Rect2(cx + d, ty + d, Q * 2.0, Q * 2.0), truss])
				l.rects.append([Rect2(cx + th - d - Q * 2.0, ty + d, Q * 2.0, Q * 2.0), truss])
			cx += th
	# 대기 — 먼 층 전체를 하늘색으로 한 겹 눌러 뒤로 물린다(대기 원근). 창 불빛은 그 위에 한 번 더 찍어 살린다
	var lights: Array = []
	for r in l.rects:
		if r[1] == warm or r[1] == cool or r[1] == red:
			lights.append(r)
	l.rects.append([Rect2(x0, floor_y + SKY_TOP, x1 - x0, SKY_BOTTOM - SKY_TOP), _c(0.050, 0.062, 0.096, 0.45)])
	l.rects.append_array(lights)
	# 안개 띠 — 먼 층을 한 겹 흐리게 눌러 가까운 층과 분리한다
	for i in range(3):
		var hy := _q(floor_y + rng.randf_range(-1300.0, -200.0))
		l.rects.append([Rect2(x0, hy, x1 - x0, _q(rng.randf_range(120.0, 260.0))), _c(0.09, 0.11, 0.16, 0.22)])


# ── 가까운 층: 거대 수평 배관 · 수직 거더 · 늘어진 케이블. 더 어둡다(가까운 실루엣) ─────────

func _build_mid(l: VistaLayer, x0: float, x1: float, floor_y: float, rng: RandomNumberGenerator) -> void:
	var dark := _c(0.050, 0.060, 0.094)
	var lit := _c(0.086, 0.102, 0.156)
	var flange := _c(0.066, 0.078, 0.120)
	var lamp := _c(0.46, 0.30, 0.13)
	var top := floor_y + SKY_TOP
	var bottom := floor_y + SKY_BOTTOM
	# 수직 거더 — 공동 바닥에서 천장까지. 가새 사다리 무늬
	var x := x0 + rng.randf_range(0.0, 600.0)
	while x < x1:
		var gx := _q(x)
		var gw := _q(rng.randf_range(64.0, 112.0))
		l.rects.append([Rect2(gx, top, gw, bottom - top), dark])
		l.rects.append([Rect2(gx + gw - Q * 2.0, top, Q * 2.0, bottom - top), lit])
		var y := top
		while y < bottom:
			l.rects.append([Rect2(gx, y, gw, Q * 2.0), flange])
			y += gw * 1.5
		x += rng.randf_range(1100.0, 2200.0)
	# 거대 수평 배관 — 테두리 윗선만 밝고, 이음쇠(플랜지)가 일정 간격
	for i in range(int((x1 - x0) / 2600.0)):
		var px := _q(x0 + rng.randf_range(0.0, x1 - x0))
		var plen := _q(rng.randf_range(1400.0, 4200.0))
		var py := _q(floor_y + rng.randf_range(-1700.0, -420.0))
		var ph := _q(rng.randf_range(40.0, 96.0))
		l.rects.append([Rect2(px, py, plen, ph), dark])
		l.rects.append([Rect2(px, py, plen, Q * 2.0), lit])
		var fx := px + 64.0
		while fx < px + plen - 32.0:
			l.rects.append([Rect2(fx, py - Q * 2.0, Q * 4.0, ph + Q * 4.0), flange])
			fx += 256.0
		if rng.randf() < 0.5:                                     # 배관 밑 작업등 하나
			var lx := _q(px + plen * rng.randf_range(0.2, 0.8))
			l.rects.append([Rect2(lx, py + ph, Q * 3.0, Q * 2.0), lamp])
	# 늘어진 케이블 — 위에서 내려와 공중에서 끊긴다
	for i in range(int((x1 - x0) / 700.0)):
		var cx := _q(x0 + rng.randf_range(0.0, x1 - x0))
		var clen := _q(rng.randf_range(300.0, 1200.0))
		l.rects.append([Rect2(cx, top, Q, (floor_y - 1500.0 - top) + clen), dark])


## 사각형 목록을 한 번 그려 두는 층 (내용은 정적이고 패럴랙스는 position 으로만 움직인다)
class VistaLayer extends Node2D:
	var rects: Array = []                 # [Rect2, Color]

	func _draw() -> void:
		for r in rects:
			draw_rect(r[0], r[1])
