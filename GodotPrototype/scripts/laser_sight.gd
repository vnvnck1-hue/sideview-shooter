class_name LaserSight
extends Node2D
## 붉은 조준선. 포신 축을 따라 벽면까지 뻗는 얇은 빛줄기 + 착점의 붉은 점.
##
## 조준점(마우스)이 아니라 **실제 포신이 가리키는 방향**을 그린다 — 포신 회전이 마우스를 따라오는 지연과
## 부앙 한계(±ELEV_MAX)가 눈에 보여서, 지금 어디로 나갈지가 정직하게 읽힌다.
## 좌표는 부모 로컬(센트리건 루트) — SentryTurret 이 to_local() 로 변환해 넣어 준다.
##
## 그리는 순서: 굵은 붉은 산광(가산) → 얇은 흰 심 → 착점 글로우 점. 가산 블렌드라 어두운 방에서
## 스스로 빛나고 글로우(임계 0.85)에도 걸린다. 미세한 밝기 떨림(FLICKER)으로 죽은 선이 되지 않게 한다.

## 색 (2026-09-19: 더 얇고 연하게) — 진한 피처럼 붉은 선은 화면에서 무거웠다.
const CORE := Color(1.0, 0.80, 0.78, 1.0)        # 심 (연한 분홍빛 흰색)
const BEAM := Color(1.0, 0.44, 0.40, 1.0)        # 산광 (연한 붉은색)
const DOT := Color(1.0, 0.50, 0.42, 1.0)         # 착점
const FLICKER := 0.12                            # 밝기 떨림 폭
const FLICKER_SPEED := 22.0

var from := Vector2.ZERO           # 부모 로컬
var to := Vector2.ZERO
var width := 3.0                   # 심 두께 (부모 로컬 단위)
var intensity := 1.0               # 0 = 꺼짐. 조종 중 1.0 · 무인 대기 0.45 · 과열 중 깜빡임

var _t := 0.0


func _ready() -> void:
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if intensity <= 0.01 or from.distance_squared_to(to) < 4.0:
		return
	var f := intensity * (1.0 - FLICKER * (0.5 + 0.5 * sin(_t * FLICKER_SPEED)))
	# 산광 — 얇게 두 겹만 (연한 붉은 기만 남긴다). 2026-09-19: 한 단계 더 연하게
	draw_line(from, to, Color(BEAM, 0.12 * f), width * 2.6)
	draw_line(from, to, Color(BEAM, 0.26 * f), width * 1.5)
	# 심 — 아주 얇고 연하게
	draw_line(from, to, Color(CORE, 0.30 * f), width * 0.7)
	# 착점 — 벽에 찍히는 연한 붉은 점 (선보다는 조금 또렷하게 남긴다)
	draw_circle(to, width * 2.0, Color(DOT, 0.20 * f))
	draw_circle(to, width * 0.9, Color(CORE, 0.52 * f))
