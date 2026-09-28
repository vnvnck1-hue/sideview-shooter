class_name DepthLabFan
extends Node2D
## 환풍기실의 거대 환풍기 — 날개 뒤에 밝은 바깥 빛이 있고, 날개가 돌며 그 빛을 자른다.
## openness() 는 지금 빛이 새어 나오는 비율(0.35~1)이라 구역 광원·인물 밝기가 이 값으로 깜빡인다 (DepthLabLights flicker).
## 그림은 그레이박스 명도 — 하우징(어두움) · 뒤 빛 원판(밝음, 가산) · 날개(가장 어두움) · 날개 사이 빛살(가산).

const BLADES := 5
const SPEED := 1.35                 # rad/s

var radius := 300.0
var housing := 0.10                 # 명도
var blade := 0.03
var glow := 0.85
var flat := false
var _a := 0.0
var _light: Node2D


func _ready() -> void:
	_light = _Rays.new()
	_light.fan = self
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_light.material = m
	add_child(_light)


func _process(delta: float) -> void:
	_a = wrapf(_a + SPEED * delta, 0.0, TAU)
	queue_redraw()
	_light.queue_redraw()


func angle() -> float:
	return _a


## 날개 사이로 빛이 새는 비율 — 날개가 빛 중심(위쪽 수직)을 지날 때 어두워진다
func openness() -> float:
	if flat:
		return 1.0
	var step := TAU / BLADES
	var ph := fposmod(_a, step) / step
	return 0.35 + 0.65 * absf(sin(ph * PI))


func _draw() -> void:
	var hv := Color(housing, housing, housing)
	draw_rect(Rect2(-radius - 60, -radius - 60, (radius + 60) * 2, (radius + 60) * 2), hv)
	draw_circle(Vector2.ZERO, radius + 24, Color(housing * 0.6, housing * 0.6, housing * 0.6))
	if flat:
		draw_circle(Vector2.ZERO, radius, hv)
		return
	# 뒤 빛 원판 (가산 겹이 더해진다) — 본체는 어두운 원
	draw_circle(Vector2.ZERO, radius, Color(0.16, 0.16, 0.16))
	var bv := Color(blade, blade, blade)
	for i in range(BLADES):
		var a := _a + TAU * i / BLADES
		var pts := PackedVector2Array([Vector2.ZERO])
		for k in range(7):
			var t := a + (k / 6.0) * 0.62
			var r := radius * (0.25 + 0.75 * (k / 6.0 if k < 6 else 1.0))
			pts.append(Vector2(cos(t), sin(t)) * minf(r * 1.4, radius - 6.0))
		draw_colored_polygon(pts, bv)
	draw_circle(Vector2.ZERO, radius * 0.16, Color(housing * 1.6, housing * 1.6, housing * 1.6))
	# 격자 보호망
	var gv := Color(housing * 0.5, housing * 0.5, housing * 0.5)
	var y := -radius
	while y <= radius:
		draw_rect(Rect2(-radius, y, radius * 2, 4), gv)
		y += 48.0


class _Rays extends Node2D:
	var fan: DepthLabFan

	func _draw() -> void:
		if fan == null or fan.flat:
			return
		var r := fan.radius
		var g := fan.glow
		# 날개 사이 빛 — 날개와 날개 사이 부채꼴
		for i in range(DepthLabFan.BLADES):
			var a := fan.angle() + TAU * i / DepthLabFan.BLADES + 0.62
			var span := TAU / DepthLabFan.BLADES - 0.62
			var pts := PackedVector2Array([Vector2.ZERO])
			var cols := PackedColorArray([Color(g, g, g)])
			for k in range(7):
				var t := a + span * k / 6.0
				pts.append(Vector2(cos(t), sin(t)) * (r - 6.0))
				cols.append(Color(g * 0.55, g * 0.55, g * 0.55))
			draw_polygon(pts, cols)
		# 앞으로 새어 나오는 빛 번짐 (방으로 번지는 공기)
		var tex := DepthLayer.radial()
		var k := fan.openness()
		draw_texture_rect(tex, Rect2(-r * 2.4, -r * 2.4, r * 4.8, r * 4.8), false, Color(0.22 * k, 0.22 * k, 0.22 * k))
