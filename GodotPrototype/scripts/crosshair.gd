class_name Crosshair
extends Node2D
## 마우스 포인터 위치(월드)에 그리는 조준점. 사격 시 살짝 벌어진다.

## 월드 px. 뷰 1px = 월드 4px 이므로 선 굵기 4 = 화면 픽셀 한 칸.
const ARM := 16.0
const GAP := 8.0
const KICK := 8.0
const RETURN := 26.0
const LINE_W := 4.0

var _spread := 0.0
var heat := 0.0                 # 연사 열 (Player.spread_ratio) — 벌어짐이 유지된다


func kick() -> void:
	_spread = KICK


func _process(delta: float) -> void:
	_spread = maxf(_spread - RETURN * delta * maxf(_spread, 0.4), 0.0)
	queue_redraw()


func _draw() -> void:
	var g := GAP + _spread + heat * 14.0
	var c := Color(1.0, 0.9, 0.55, 0.95)
	var shadow := Color(0, 0, 0, 0.6)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(d * g + Vector2(LINE_W, LINE_W), d * (g + ARM) + Vector2(LINE_W, LINE_W), shadow, LINE_W)
		draw_line(d * g, d * (g + ARM), c, LINE_W)
	draw_rect(Rect2(-LINE_W * 0.5, -LINE_W * 0.5, LINE_W, LINE_W), c)
