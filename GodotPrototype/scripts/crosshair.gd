class_name Crosshair
extends Node2D
## 마우스 포인터 위치(월드)에 그리는 조준점. 모드가 두 개다.
##
##   RIFLE  (플레이어 소총) : 십자 네 팔 + 중심 점. 연사 열(heat)·발사 반동(kick)에 벌어진다.
##   SENTRY (센트리건 조종) : 네 귀퉁이 브래킷 + 천천히 도는 점선 고리 + **총열 과열 게이지 링**.
##                            조준점만 봐도 지금 센트리건을 잡고 있다는 게 읽히고, 열이 차면 링이 붉게
##                            채워지다가 과열되면 전체가 붉게 깜빡이며 잠금 표시(X 틱)가 뜬다.
##
## 밝기: 어두운 방에서도 잘 보이도록 흰 심(WHITE_CORE) + 검은 외곽선(밝은 벽 위에서도 읽힌다)으로 그리고,
## 노드 modulate 를 1 이상으로 올려 글로우(임계 0.85)에 살짝 걸리게 한다 — 조준점이 스스로 발광한다.
## 모든 치수는 월드 px (카메라 zoom 0.625 → 화면 px 의 1.6배). 선 굵기 4 = 아트 1px.

enum Mode { RIFLE, SENTRY }

const KICK := 8.0                   # 한 발당 벌어짐 (RIFLE)
const KICK_SENTRY := 12.0           # 센트리건은 더 크게 튄다
const RETURN := 26.0
## 발광 배율. 조준점도 방의 CanvasModulate(앰비언트 ≈0.42)로 어두워지므로 그 역수 이상으로 올려야
## 원래 색으로 보인다 — Lighting.EMISSIVE 계열과 같은 이유. 3.0 이면 흰 심이 1.0 을 넘어 글로우에도 걸린다.
const GLOW := Color(3.0, 3.0, 3.0, 1.0)

## 색 — 밝은 심 + 색 있는 외곽. 어두운 배경에서는 흰 심이, 밝은 배경에서는 검은 외곽선이 대비를 만든다.
const CORE := Color(1.0, 1.0, 0.96, 1.0)
const RIFLE_TINT := Color(1.0, 0.86, 0.45, 1.0)
const SENTRY_TINT := Color(0.62, 0.95, 1.0, 1.0)      # 조종 중엔 차가운 청록 (총열 링만 난색)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.7)
const HEAT_COOL_COL := Color(1.0, 0.72, 0.30, 1.0)
const HEAT_HOT_COL := Color(1.0, 0.26, 0.16, 1.0)
const RING_DIM := Color(0.16, 0.19, 0.26, 0.6)        # 과열 링의 빈 부분 (GLOW 배율을 감안해 어둡게)

## SENTRY 치수
const BRACKET_R := 34.0             # 귀퉁이 브래킷까지의 거리
const BRACKET_LEN := 15.0
const SPIN_R := 52.0                # 점선 고리 반지름
const SPIN_SPEED := 0.5             # 고리 회전 (rad/s)
const SPIN_TICKS := 10
const HEAT_R := 64.0                # 과열 게이지 링 반지름

var line_w := 4.0
var mode: Mode = Mode.RIFLE
var heat := 0.0                     # 연사 열 (Player/WalkerUnit.spread_ratio) — 조준점 벌어짐 유지
var sentry_heat := 0.0              # 총열 과열 0..1 (SENTRY 링)
var sentry_overheated := false

var _spread := 0.0
var _spin := 0.0
var _blink := 0.0


func _ready() -> void:
	modulate = GLOW


## 센트리건 조종 시작/해제
func set_sentry(active: bool) -> void:
	mode = Mode.SENTRY if active else Mode.RIFLE
	_spread = 0.0
	queue_redraw()


func kick() -> void:
	_spread = KICK_SENTRY if mode == Mode.SENTRY else KICK


func _process(delta: float) -> void:
	_spread = maxf(_spread - RETURN * delta * maxf(_spread, 0.4), 0.0)
	if mode == Mode.SENTRY:
		_spin = wrapf(_spin + SPIN_SPEED * delta, 0.0, TAU)
		_blink += delta
	queue_redraw()


func _draw() -> void:
	if mode == Mode.SENTRY:
		_draw_sentry()
	else:
		_draw_rifle()


## 십자 네 팔 + 중심 점 (검은 외곽선 → 색 팔 → 흰 심)
func _draw_rifle() -> void:
	var arm := line_w * 4.0
	var g := line_w * 2.0 + _spread + heat * 14.0
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a := d * g
		var b := d * (g + arm)
		draw_line(a, b, OUTLINE, line_w + 4.0)
		draw_line(a, b, RIFLE_TINT, line_w + 1.0)
		draw_line(a, b, CORE, line_w * 0.5)
	draw_rect(Rect2(Vector2.ONE * -(line_w * 0.5 + 2.0), Vector2.ONE * (line_w + 4.0)), OUTLINE)
	draw_rect(Rect2(Vector2.ONE * -line_w * 0.5, Vector2.ONE * line_w), CORE)


## 센트리건 조준 레티클
func _draw_sentry() -> void:
	var over := sentry_overheated
	var blink := (0.55 + 0.45 * sin(_blink * 14.0)) if over else 1.0
	var tint := SENTRY_TINT if not over else HEAT_HOT_COL
	tint.a = blink
	# 브래킷은 발사 반동(_spread)만이 아니라 **집탄 열(heat)** 로도 벌어진다 —
	# 보행 기체는 붙잡고 쏘면 산포가 커지므로, 소총 조준점과 같은 방식으로 그 값을 보여 준다.
	var r := BRACKET_R + _spread + heat * 18.0

	# 네 귀퉁이 브래킷 (L 자) — 기계식 조준 장치 느낌
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := Vector2(sx, sy) * r
			var h_end := corner - Vector2(sx * BRACKET_LEN, 0.0)
			var v_end := corner - Vector2(0.0, sy * BRACKET_LEN)
			draw_line(corner, h_end, OUTLINE, line_w + 4.0)
			draw_line(corner, v_end, OUTLINE, line_w + 4.0)
			draw_line(corner, h_end, tint, line_w + 1.0)
			draw_line(corner, v_end, tint, line_w + 1.0)
			draw_line(corner, h_end, Color(CORE, blink), line_w * 0.5)
			draw_line(corner, v_end, Color(CORE, blink), line_w * 0.5)

	# 안쪽 짧은 틱 (상하좌우) + 중심 마름모
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a := d * (line_w * 2.5)
		var b := d * (line_w * 5.0)
		draw_line(a, b, OUTLINE, line_w + 3.0)
		draw_line(a, b, Color(CORE, blink), line_w)
	var dsz := line_w * 1.6
	var diamond := PackedVector2Array([Vector2(0, -dsz), Vector2(dsz, 0), Vector2(0, dsz), Vector2(-dsz, 0)])
	draw_colored_polygon(diamond, Color(CORE, blink))

	# 천천히 도는 점선 고리 — "조준 장치가 돌아가고 있다"
	for i in range(SPIN_TICKS):
		var a0 := _spin + TAU * float(i) / float(SPIN_TICKS)
		var a1 := a0 + TAU / float(SPIN_TICKS) * 0.42
		draw_arc(Vector2.ZERO, SPIN_R, a0, a1, 4, OUTLINE, line_w + 3.0)
		draw_arc(Vector2.ZERO, SPIN_R, a0, a1, 4, Color(tint, 0.85 * blink), line_w)

	# 총열 과열 게이지 링 (12시에서 시계 방향으로 채워진다)
	draw_arc(Vector2.ZERO, HEAT_R, 0.0, TAU, 48, RING_DIM, line_w)
	var k := clampf(sentry_heat, 0.0, 1.0)
	if k > 0.001:
		var col := HEAT_COOL_COL.lerp(HEAT_HOT_COL, smoothstep(0.3, 1.0, k))
		col.a = blink
		var start := -PI * 0.5
		draw_arc(Vector2.ZERO, HEAT_R, start, start + TAU * k, 48, OUTLINE, line_w + 5.0)
		draw_arc(Vector2.ZERO, HEAT_R, start, start + TAU * k, 48, col, line_w + 2.0)

	# 과열 잠금: 링 위에 X 틱
	if over:
		var d := HEAT_R * 0.42
		for v: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			draw_line(-v * d, v * d, OUTLINE, line_w + 4.0)
			draw_line(-v * d, v * d, Color(HEAT_HOT_COL, blink), line_w + 1.0)
