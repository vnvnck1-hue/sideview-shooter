class_name Ladder
extends Node2D
## 벽 사다리 — 바닥선에서 그 열 천장 띠 아래(점검 해치)까지 이어진 정비용 사다리.
## 플레이어가 W/↑ 로 잡아 측면 자세(Frames/climb)로 오르내린다 (Player.start_climb).
## 원화 프레임에는 사다리가 없다(MOVEMENT_CLIPS.md) — 레벨이 그리는 이 노드가 그 자리를 채운다.
## 그림은 절차적으로 4px 격자 블록만 쓴다 (베이크 자산의 4px 블록과 맞춤). 기본 CanvasItem 이라 방 라이트를 받는다.
## 위치: position.x = 사다리 축, position.y = 바닥선. 위로 음수.

const GRAB_RANGE := 84.0            # 사다리 축에서 이 거리 안이면 W/↑ 로 잡는다
const PLAYER_REACH := 300.0         # 발 → 뻗은 손 끝 (climb_02·03 원화 높이). 손이 해치에 닿는 곳까지 오른다
const HALF_W := 32                  # 레일 바깥 폭의 반
const RAIL_W := 8
const RUNG_GAP := 32                # 가로대 간격 — 오르기 원화 한 장(CLIMB_STEP ≈ 32.5px)과 맞춘다
const RUNG_H := 8
const BRACKET_GAP := 192            # 벽 고정 브래킷 간격
const HATCH_W := 112
const HATCH_H := 20

const C_OUTLINE := Color(0.07, 0.06, 0.06)
const C_RAIL := Color(0.40, 0.37, 0.34)
const C_RAIL_HI := Color(0.62, 0.56, 0.48)
const C_RUNG := Color(0.33, 0.31, 0.29)
const C_RUNG_HI := Color(0.52, 0.48, 0.42)
const C_SHADOW := Color(0, 0, 0, 0.35)
const C_HATCH := Color(0.16, 0.15, 0.15)
const C_HATCH_RIM := Color(0.46, 0.40, 0.30)
const C_STRIPE := Color(0.70, 0.52, 0.16)

var top_y := 0.0                    # 해치 아랫면 월드 y (천장 띠 아래)
var _len := 0.0


func setup(x: float, floor_y: float, ceiling_bottom_y: float) -> void:
	position = Vector2(roundf(x / 4.0) * 4.0, floor_y)
	top_y = ceiling_bottom_y
	_len = floor_y - ceiling_bottom_y
	queue_redraw()


## 발이 올라갈 수 있는 최대 높이 (바닥 위 px)
func climb_height() -> float:
	return maxf(_len - PLAYER_REACH, 0.0)


func _draw() -> void:
	var h := int(_len)
	if h <= 0:
		return
	var l := -HALF_W
	var r := HALF_W - RAIL_W
	# 벽에 드리운 그림자 — 오른쪽 아래로 8px
	draw_rect(Rect2(l + 8, -h + 8, HALF_W * 2, h - 8), C_SHADOW)
	# 벽 고정 브래킷 (레일 뒤, 벽까지 짧은 팔)
	var by := BRACKET_GAP
	while by < h - 16:
		draw_rect(Rect2(l - 8, -by - 4, HALF_W * 2 + 16, 12), C_OUTLINE)
		draw_rect(Rect2(l - 4, -by, HALF_W * 2 + 8, 4), C_RUNG)
		by += BRACKET_GAP
	# 가로대
	var y := RUNG_GAP
	while y < h - 8:
		draw_rect(Rect2(l + RAIL_W - 4, -y - 4, HALF_W * 2 - RAIL_W * 2 + 8, RUNG_H + 4), C_OUTLINE)
		draw_rect(Rect2(l + RAIL_W, -y, HALF_W * 2 - RAIL_W * 2, RUNG_H - 4), C_RUNG)
		draw_rect(Rect2(l + RAIL_W, -y, HALF_W * 2 - RAIL_W * 2, 4), C_RUNG_HI)
		y += RUNG_GAP
	# 레일 두 줄 (외곽선 · 몸통 · 왼쪽 윗면 하이라이트)
	for rx in [l, r]:
		draw_rect(Rect2(rx - 4, -h, RAIL_W + 8, h), C_OUTLINE)
		draw_rect(Rect2(rx, -h, RAIL_W, h), C_RAIL)
		draw_rect(Rect2(rx, -h, 4, h), C_RAIL_HI)
	# 바닥 발판
	draw_rect(Rect2(l - 8, -8, HALF_W * 2 + 16, 8), C_OUTLINE)
	# 천장 점검 해치 (사다리가 향하는 곳)
	var hx := -HATCH_W / 2
	draw_rect(Rect2(hx - 4, -h - 4, HATCH_W + 8, HATCH_H + 8), C_OUTLINE)
	draw_rect(Rect2(hx, -h, HATCH_W, HATCH_H), C_HATCH_RIM)
	draw_rect(Rect2(hx + 8, -h, HATCH_W - 16, HATCH_H - 8), C_HATCH)
	var sx := hx + 8
	while sx < hx + HATCH_W - 8:
		draw_rect(Rect2(sx, -h + HATCH_H - 8, 8, 4), C_STRIPE)
		sx += 16
