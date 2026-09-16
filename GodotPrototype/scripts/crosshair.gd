class_name Crosshair
extends Node2D
## 마우스 포인터 위치(월드)에 그리는 조준점. 사격 시 살짝 벌어진다.

const ARM := 14.0
const GAP := 6.0
const KICK := 8.0
const RETURN := 26.0

var _spread := 0.0


func kick() -> void:
	_spread = KICK


func _process(delta: float) -> void:
	_spread = maxf(_spread - RETURN * delta * maxf(_spread, 0.4), 0.0)
	queue_redraw()


func _draw() -> void:
	var g := GAP + _spread
	var c := Color(1.0, 0.9, 0.55, 0.95)
	var shadow := Color(0, 0, 0, 0.6)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(d * g + Vector2(1, 1), d * (g + ARM) + Vector2(1, 1), shadow, 4.0)
		draw_line(d * g, d * (g + ARM), c, 4.0)
	draw_circle(Vector2.ZERO, 2.5, c)
