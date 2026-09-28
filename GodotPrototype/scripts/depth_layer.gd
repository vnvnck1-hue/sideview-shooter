class_name DepthLayer
extends Node2D
## 공간감 테스트 씬의 레이어 한 장 — 그레이박스 도형 목록을 들고 있다가 그대로 그린다.
## 본체(보통 합성)와 빛(가산 합성) 두 겹이다. 빛 겹은 벽등·빛줄기·먼 광원·창 불빛처럼 **더해지는 밝기**만 담는다.
## 모든 사각형은 아트 1px(4 월드 px) 격자에 맞춘다.

const CELL := 4.0

var role := ""
var factor := 1.0                   # 패럴렉스 계수 (DepthLabData.SPEED_PRESETS)
var _ops: Array = []
var _light: _LightPass
static var _radial: GradientTexture2D


func _init() -> void:
	_light = _LightPass.new()
	_light.name = "Light"
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_light.material = m
	add_child(_light)


func clear_ops() -> void:
	_ops.clear()
	_light.ops.clear()


func commit() -> void:
	queue_redraw()
	_light.queue_redraw()


func set_light_visible(on: bool) -> void:
	_light.visible = on


static func snap(v: float) -> float:
	return roundf(v / CELL) * CELL


## 격자에 맞춘 사각형 (x, y = 왼쪽 위)
func box(x: float, y: float, w: float, h: float, c: Color) -> void:
	var x0 := snap(x)
	var y0 := snap(y)
	var r := Rect2(x0, y0, maxf(CELL, snap(x + w) - x0), maxf(CELL, snap(y + h) - y0))
	_ops.append([0, r, c])


## 세로 그라데이션 사각형
func vgrad(x: float, y: float, w: float, h: float, top: Color, bottom: Color) -> void:
	var x0 := snap(x)
	var y0 := snap(y)
	var x1 := snap(x + w)
	var y1 := snap(y + h)
	_ops.append([1, PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([top, top, bottom, bottom])])


func poly(pts: PackedVector2Array, c: Color) -> void:
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(c)
	_ops.append([1, pts, cols])


## 꼭짓점마다 색이 다른 도형 (행성 명암 · 가로 어둠 그라데이션)
func poly_colors(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	_ops.append([1, pts, cols])


func line(a: Vector2, b: Vector2, c: Color, width: float) -> void:
	_ops.append([2, a, b, c, width])


func polyline(pts: PackedVector2Array, c: Color, width: float) -> void:
	_ops.append([3, pts, c, width])


# ── 빛 겹 (가산) ────────────────────────────────────────────────────────────────

## 둥근 번짐. size 로 타원도 된다 (바닥에 떨어진 빛 웅덩이는 납작하게)
func glow(center: Vector2, size: Vector2, c: Color) -> void:
	_light.ops.append([0, Rect2(center - size * 0.5, size), c])


## 꼭짓점마다 밝기가 다른 빛 도형 (빛줄기·벽등 원뿔)
func light_poly(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	_light.ops.append([1, pts, cols])


func light_box(x: float, y: float, w: float, h: float, c: Color) -> void:
	var x0 := snap(x)
	var y0 := snap(y)
	_light.ops.append([2, Rect2(x0, y0, maxf(CELL, snap(x + w) - x0), maxf(CELL, snap(y + h) - y0)), c])


static func radial() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 128
		_radial.height = 128
	return _radial


func _draw() -> void:
	for op in _ops:
		match int(op[0]):
			0:
				draw_rect(op[1], op[2])
			1:
				draw_polygon(op[1], op[2])
			2:
				draw_line(op[1], op[2], op[3], op[4])
			3:
				draw_polyline(op[1], op[2], op[3])


class _LightPass extends Node2D:
	var ops: Array = []

	func _draw() -> void:
		var tex := DepthLayer.radial()
		for op in ops:
			match int(op[0]):
				0:
					draw_texture_rect(tex, op[1], false, op[2])
				1:
					draw_polygon(op[1], op[2])
				2:
					draw_rect(op[1], op[2])
