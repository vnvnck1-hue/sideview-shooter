class_name Bullet
extends Node2D
## 고속 탄환. 총구에서 목표점(마우스 포인터)까지 직선으로 날아가 정확히 그 지점에 탄착한다.
## 시각: 총구부터 탄두까지 이어지는 한 줄 궤적이 찍히고 탄착 직후 사라진다.
## 탄착: 플래시 + 불꽃 스파크 + 중력을 받는 벽 파편 + 짧은 라이트 (타격감). 궤적·플래시·스파크·라이트는 붉은 팔레트(Lighting.RED_*).
## 잔상: 궤적 라인이 사라지는 순간 선이 발사 방향으로 누운 긴 선분 1~3개로 끊어지고, 각 선분은 앞으로 살짝 밀리며
##       선분 안의 임의 지점을 향해 길이가 점(화면 2px)으로 수렴한 뒤 계단식으로 꺼진다 (만화적 궤적 흔적: 선 → 점 → 소멸).
##       개수가 적을수록 한 선분이 길고, 선분마다 길이가 다르다. 색은 가산 블렌드 주황 불씨(EMBER)가 어두워지며 사라진다.

const SPEED := 20800.0
const TRAIL_W := 7.0
const TRAIL_FADE := 0.05       # 탄착 후 궤적이 사라지는 시간 (거의 즉시)

# 픽셀 잔상 (궤적 라인이 부서진 조각). 카메라 zoom 0.5 → 월드 2유닛 = 화면 1px.
const RESIDUE_PX := 2.0                  # 월드 유닛/화면 px (격자 스냅 단위)
const RESIDUE_SIZE := 4.0                # 선분 두께 = 화면 2px (가끔 3px). 수렴 후 점의 크기
const RESIDUE_COUNT_MAX := 3             # 한 발에서 나오는 선분 수: 1 ~ 이 값 사이 랜덤
const RESIDUE_BUDGET := Vector2(260.0, 720.0)  # 선분 길이 합계 예산 (월드). 사거리의 절반을 이 범위로 클램프 → 개수로 나눔
const RESIDUE_LEN_JITTER := Vector2(0.55, 1.45) # 선분별 길이 배율 범위 (서로 다르게)
const RESIDUE_DOT_CHANCE := 0.8          # 점 잔상이 함께 나올 확률 (발사당)
const RESIDUE_DOT_COUNT := Vector2i(4, 9)  # 점 잔상 개수 범위
const RESIDUE_DOT_LIFE_MIN := 0.22       # 점 잔상 수명 — 첫 버전 값 그대로 (선분보다 오래 남는다)
const RESIDUE_DOT_LIFE_MAX := 0.55

# 연기 잔상: 궤적 전체를 하나의 Line2D 로 이어 그리는 연한 회색 연기. 각 점이 따로 움직이지 않고 궤적 위치(k)의
# 부드러운 저주파 파동으로 함께 흔들려 이어진 연기처럼 보인다. 셰이더가 4px 블록 단위로 군데군데 침식(dissolve)시켜
# 시간이 갈수록 실오라기처럼 끊어지며 사라진다. 일반 블렌드(가산 아님) — 빛이 아니라 연기.
const SMOKE_CHANCE := 0.2                # 발사당 연기가 생길 확률
const SMOKE_SPANS := Vector2i(1, 3)      # 연기 구간 수 (궤적 일부에만 뜨문뜨문)
const SMOKE_SPAN_FRAC := Vector2(0.10, 0.28)  # 구간 하나가 덮는 궤적 비율
const SMOKE_SPACING := 8.0               # 라인 정점 간격 (월드, 화면 4px)
const SMOKE_MAX := 80                    # 구간 하나의 정점 상한
const SMOKE_COLOR := Color(0.74, 0.75, 0.78)
const SMOKE_ALPHA := 0.32                # 시작 알파 (연하게)
const SMOKE_WIDTH := 4.0                 # 라인 두께 (월드, 화면 2px)
const SMOKE_LIFE := Vector2(1.1, 1.6)    # 수명 범위 (초)
const SMOKE_RISE := 12.0                 # 전체 상승 속도 (월드/s) — 매우 느림, 위치별로 ±40% 차이
const SMOKE_SWAY := 7.0                  # 법선 방향 파동 진폭 최대 (월드) — 시간이 갈수록 커진다
const SMOKE_SHADER := """
shader_type canvas_item;
render_mode blend_mix;
uniform float age : hint_range(0.0, 1.0) = 0.0;   // 0=막 생김, 1=소멸
uniform float cell = 4.0;                          // 침식 블록 크기 (월드)
uniform float line_width = 4.0;                    // Line2D.width — UV.x(타일 수) → 거리 변환
uniform float base_alpha = 0.32;
float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void fragment() {
	float d = UV.x * line_width;                        // 라인 시작점부터의 거리 (월드)
	float fine = hash1(floor(d / cell) + 7.0);           // 블록 단위 난수
	float coarse = hash1(floor(d / (cell * 6.0)) + 3.0); // 덩어리 단위 난수 — 이웃 블록이 함께 사라진다
	float n = mix(coarse, fine, 0.45);
	float keep = step(age * 1.05, n);                    // 난수가 낮은 곳부터 침식
	float grow = min(age / 0.12, 1.0);                   // 처음 12% 동안 피어오름
	float a = base_alpha * grow * (1.0 - age * age) * keep;
	COLOR = vec4(COLOR.rgb, COLOR.a * a);
}
"""
const RESIDUE_LIFE_MIN := 0.09
const RESIDUE_LIFE_MAX := 0.20
const RESIDUE_DRIFT := Vector2(120.0, 280.0)  # 발사 방향 초속 범위
const RESIDUE_SCATTER := 60.0            # 수직 흩어짐 초속 최대
const RESIDUE_DAMP := 4.0                # 속도 감쇠 (1/s)
const RESIDUE_STEPS := 5                 # 색·알파 계단 수 (픽셀 느낌)
# 잔상 색 (EMBER): 가산 블렌드 광원 파티클. 주황 불씨가 배경 위에 빛으로 얹히고 밝기만 줄어 사라진다 —
# 어떤 배경에서도 배경보다 어두워지지 않아 딱딱하게 "칠해진" 느낌이 없다. 모든 선분이 같은 색을 쓰고 hot → mid → cold 로 식는다.
const RESIDUE_COLOR_HOT := Color(1.0, 0.62, 0.28)
const RESIDUE_COLOR_MID := Color(0.95, 0.38, 0.14)
const RESIDUE_COLOR_COLD := Color(0.45, 0.14, 0.06)
const RESIDUE_GLOW_HOT := Color(1.8, 1.8, 1.8)         # 초반 밝기 배율
const RESIDUE_GLOW_COLD := Color(0.5, 0.5, 0.5)        # 말기 밝기 배율 (알파는 0 까지)
static var _residue_add_mat: CanvasItemMaterial         # 가산 블렌드 머티리얼 (공유)

const IMPACT_LIFE := 0.6      # 파편이 남는 시간
const SPARK_COUNT := 8         # (30% 축소)        # 밝은 불꽃 (빠르고 곧게)
const CHIP_COUNT := 8          # (30% 축소)         # 벽 파편 (중력, 회전, 바닥 튕김)
const GRAVITY := 2600.0
const FLASH_TIME := 0.08
const RING_TIME := 0.16
const LIGHT_TIME := 0.16      # 탄착 라이트 소등 시간

enum Impact { WALL, GLASS, PROP, FLESH, WATER }

var impact_kind: Impact = Impact.WALL
var start := Vector2.ZERO
var target := Vector2.ZERO
var floor_y := 100000.0        # 파편이 튕기는 바닥 (Main 이 넣어준다)
var _dir := Vector2.RIGHT
var _total := 0.0
var _travelled := 0.0
var _impacting := false
var _impact_t := 0.0
var _trail: Line2D
var _core: Line2D
var _head: ColorRect
var _flash: ColorRect
var _ring: Node2D
var _light: PointLight2D
var _debris: Array = []        # [{node, vel, spin, gravity, life}]
var _residue: Array = []       # [{node, pos, vel, life, delay}] 픽셀 잔상
var _smoke_lines: Array = []   # [{line: Line2D, base: PackedVector2Array, seed: float}] 연기 잔상 구간들
var _smoke_mat: ShaderMaterial
var _smoke_life := 1.0
var _smoke_delay := 0.0
var _smoke_t := 0.0
static var _smoke_shader: Shader     # 공유


func setup(from: Vector2, to: Vector2) -> void:
	start = from
	target = to
	_dir = (to - from).normalized() if to.distance_to(from) > 1.0 else Vector2.RIGHT
	_total = from.distance_to(to)
	position = Vector2.ZERO          # 월드 좌표를 그대로 쓴다


func _ready() -> void:
	_trail = Line2D.new()
	_trail.width = TRAIL_W
	_trail.default_color = Lighting.TRACER
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.set_color(0, Color(Lighting.TRACER, 0.0))
	grad.set_color(1, Color(1.0, 0.5, 0.35, 1.0))
	_trail.gradient = grad
	_trail.modulate = Lighting.RED_EMISSIVE_SOFT      # 붉은 발광 → 글로우
	add_child(_trail)

	_core = Line2D.new()
	_core.width = 2.5
	_core.default_color = Lighting.TRACER_CORE
	_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_core.end_cap_mode = Line2D.LINE_CAP_ROUND
	_core.modulate = Lighting.RED_EMISSIVE
	add_child(_core)

	_head = ColorRect.new()
	_head.color = Color(1.0, 0.88, 0.82)
	_head.size = Vector2(12, 12)
	_head.pivot_offset = _head.size * 0.5
	_head.modulate = Lighting.RED_EMISSIVE
	add_child(_head)

	_update_trail(start)


func _update_trail(head: Vector2) -> void:
	_trail.points = PackedVector2Array([start, head])
	_core.points = PackedVector2Array([start, head])
	_head.position = head - _head.size * 0.5
	_head.rotation = _dir.angle()


func _process(delta: float) -> void:
	if _impacting:
		_process_impact(delta)
		return

	_travelled += SPEED * delta
	if _travelled >= _total:
		_travelled = _total
		_update_trail(target)
		_impact()
	else:
		_update_trail(start + _dir * _travelled)


func _process_impact(delta: float) -> void:
	_impact_t += delta

	# 궤적 즉시 페이드
	var f := 1.0 - clampf(_impact_t / TRAIL_FADE, 0.0, 1.0)
	_trail.modulate.a = f
	_core.modulate.a = f * f
	_trail.width = TRAIL_W * (0.4 + 0.6 * f)

	# 플래시: 크게 시작해 빠르게 수축
	var fk := clampf(_impact_t / FLASH_TIME, 0.0, 1.0)
	var fs := 1.0 - fk
	_flash.scale = Vector2.ONE * (0.4 + 1.6 * fs)
	_flash.modulate.a = fs
	_flash.visible = fk < 1.0

	# 충격 링: 퍼지면서 사라짐
	var rk := clampf(_impact_t / RING_TIME, 0.0, 1.0)
	_ring.scale = Vector2.ONE * (0.3 + 1.7 * rk)
	_ring.modulate.a = 1.0 - rk
	_ring.visible = rk < 1.0

	# 라이트
	if _light:
		_light.energy = 2.2 * maxf(0.0, 1.0 - _impact_t / LIGHT_TIME)
		_light.enabled = _light.energy > 0.01

	# 파편
	for d in _debris:
		var n: ColorRect = d["node"]
		d["vel"].y += d["gravity"] * delta
		n.position += d["vel"] * delta
		n.rotation += d["spin"] * delta
		var center_y: float = n.position.y + n.size.y * 0.5
		if center_y >= floor_y and d["vel"].y > 0.0:
			n.position.y = floor_y - n.size.y * 0.5
			d["vel"].y = -d["vel"].y * 0.35
			d["vel"].x *= 0.6
			d["spin"] *= 0.5
		var lk: float = _impact_t / float(d["life"])
		n.modulate.a = clampf(1.0 - maxf(0.0, lk - 0.55) / 0.45, 0.0, 1.0)

	_process_residue(delta)
	_process_smoke(delta)

	if _impact_t >= IMPACT_LIFE and _residue.is_empty() and _smoke_lines.is_empty():
		queue_free()


## 궤적의 일부 구간(1~3개)에만 연기 라인을 만든다 (발사당 SMOKE_CHANCE 확률). 라인이 꺼지는 순간 이어받아 피어오르고,
## 한 덩어리로 느리게 떠오르며 침식된다. 구간들은 서로 겹치지 않게 궤적을 슬롯으로 나눠 배치한다.
func _spawn_smoke() -> void:
	if randf() >= SMOKE_CHANCE:
		return
	if _smoke_shader == null:
		_smoke_shader = Shader.new()
		_smoke_shader.code = SMOKE_SHADER
	_smoke_mat = ShaderMaterial.new()
	_smoke_mat.shader = _smoke_shader
	_smoke_mat.set_shader_parameter("age", 0.0)
	_smoke_mat.set_shader_parameter("cell", RESIDUE_SIZE)
	_smoke_mat.set_shader_parameter("line_width", SMOKE_WIDTH)
	_smoke_mat.set_shader_parameter("base_alpha", SMOKE_ALPHA)
	var spans := randi_range(SMOKE_SPANS.x, SMOKE_SPANS.y)
	var slot := 1.0 / float(spans)
	for si in range(spans):
		var frac := randf_range(SMOKE_SPAN_FRAC.x, SMOKE_SPAN_FRAC.y)
		frac = minf(frac, slot * 0.9)
		var k0 := si * slot + randf_range(0.0, slot - frac)     # 슬롯 안 임의 위치
		var len := _total * frac
		var count := clampi(int(len / SMOKE_SPACING), 2, SMOKE_MAX)
		var base := PackedVector2Array()
		for i in range(count + 1):
			base.append(start + _dir * (_total * k0 + len * float(i) / float(count)))
		var line := Line2D.new()
		line.width = SMOKE_WIDTH
		line.default_color = SMOKE_COLOR
		line.joint_mode = Line2D.LINE_JOINT_SHARP
		line.antialiased = false
		line.texture_mode = Line2D.LINE_TEXTURE_TILE      # UV.x = 거리/두께 → 셰이더가 거리로 환산
		line.texture = Lighting.white_texture()
		line.material = _smoke_mat
		line.points = base
		line.visible = false
		line.z_index = -1                                  # 선분·점 잔상 뒤
		add_child(line)
		_smoke_lines.append({"line": line, "base": base, "seed": randf_range(0.0, 100.0)})
	_smoke_life = randf_range(SMOKE_LIFE.x, SMOKE_LIFE.y)
	_smoke_delay = TRAIL_FADE * 0.6
	_smoke_t = 0.0


func _process_smoke(delta: float) -> void:
	if _smoke_lines.is_empty() or _impact_t < _smoke_delay:
		return
	_smoke_t += delta
	var age := _smoke_t / _smoke_life
	if age >= 1.0:
		for sm in _smoke_lines:
			(sm["line"] as Line2D).queue_free()
		_smoke_lines.clear()
		return
	_smoke_mat.set_shader_parameter("age", age)
	# 정점 변위: 위치(k)의 부드러운 함수 → 이웃 정점이 함께 움직여 라인이 끊기지 않는다.
	#  · 상승: 전체가 같은 속도로 뜨되 위치별로 ±40% 차이 (긴 파장) → 완만한 기복
	#  · 흔들림: 법선 방향 저주파 파동 2개 합. 진폭은 시간이 갈수록 커진다 (흩어짐)
	var perp := _dir.orthogonal()
	var spread := SMOKE_SWAY * minf(age * 1.6, 1.0)
	for sm in _smoke_lines:
		var line: Line2D = sm["line"]
		var base: PackedVector2Array = sm["base"]
		var sd: float = sm["seed"]
		line.visible = true
		var n := base.size()
		var pts := PackedVector2Array()
		pts.resize(n)
		for i in range(n):
			var k := float(i) / float(maxf(n - 1, 1))
			var rise := SMOKE_RISE * _smoke_t * (1.0 + 0.4 * sin(k * 5.1 + sd))
			var sway := sin(k * 9.7 + sd + _smoke_t * 0.9) * 0.65 				+ sin(k * 23.3 - sd * 0.7 - _smoke_t * 1.4) * 0.35
			var p: Vector2 = base[i] + Vector2(0.0, -rise) + perp * (sway * spread)
			pts[i] = (p / RESIDUE_PX).floor() * RESIDUE_PX          # 픽셀 격자 스냅
		line.points = pts


## 궤적 라인을 1~3개의 긴 선분으로 끊어 둔다. 선분은 발사 방향으로 밀리며 조금 벌어지고, 총구 쪽부터 먼저 꺼진다.
func _spawn_residue() -> void:
	var count := randi_range(1, RESIDUE_COUNT_MAX)
	var perp := _dir.orthogonal()
	var budget := clampf(_total * 0.5, RESIDUE_BUDGET.x, RESIDUE_BUDGET.y)
	var slot := _total / float(count)                    # 선분마다 궤적의 한 구간을 배정해 서로 겹치지 않게
	for i in range(count):
		var len0 := budget / float(count) * randf_range(RESIDUE_LEN_JITTER.x, RESIDUE_LEN_JITTER.y)
		len0 = minf(len0, slot * 0.92)
		var px := RESIDUE_SIZE * (1.0 if randf() < 0.7 else 1.5)   # 두께 화면 2px, 가끔 3px
		# 선분 중심: 배정 구간 안에서 랜덤 (선분이 구간을 벗어나지 않게)
		var lo := i * slot + len0 * 0.5
		var hi := (i + 1) * slot - len0 * 0.5
		var tc := randf_range(lo, hi) if hi > lo else (i + 0.5) * slot
		var k := tc / maxf(_total, 1.0)                   # 0=총구, 1=탄착
		var n := ColorRect.new()
		n.size = Vector2(len0, px)
		n.rotation = _dir.angle()                         # 발사 방향으로 누운 선분
		n.color = RESIDUE_COLOR_HOT
		n.modulate = RESIDUE_GLOW_HOT
		if _residue_add_mat == null:
			_residue_add_mat = CanvasItemMaterial.new()
			_residue_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = _residue_add_mat
		add_child(n)
		# 수렴 기준점: 선분 중앙 (양쪽 끝이 가운데로 모인다)
		var anchor := 0.5
		var seg_start := start + _dir * (tc - len0 * 0.5) + perp * randf_range(-RESIDUE_SIZE, RESIDUE_SIZE)
		var anchor_pos := seg_start + _dir * (anchor * len0)
		var vel := _dir * randf_range(RESIDUE_DRIFT.x, RESIDUE_DRIFT.y) 			+ perp * randf_range(-RESIDUE_SCATTER, RESIDUE_SCATTER) * (0.4 + 0.6 * k)
		_residue.append({
			"node": n, "pos": anchor_pos, "vel": vel, "len0": len0, "thick": px, "anchor": anchor,
			"life": randf_range(RESIDUE_LIFE_MIN, RESIDUE_LIFE_MAX) * (0.7 + 0.5 * k),   # 탄착 쪽이 조금 더 오래
			"delay": TRAIL_FADE * 0.6 + k * 0.03,                                       # 라인이 꺼지는 순간 이어받는다
			"t": 0.0,
		})
		_place_residue(n, anchor_pos, anchor, len0)

	# 점 잔상: 가끔, 적은 양. 선분 사이사이에 화면 2px 점이 몇 개 남아 앞으로 밀리며 꺼진다 (길이 = 두께인 선분으로 처리)
	if randf() < RESIDUE_DOT_CHANCE:
		for i in range(randi_range(RESIDUE_DOT_COUNT.x, RESIDUE_DOT_COUNT.y)):
			var px := RESIDUE_SIZE * (1.0 if randf() < 0.7 else 1.5)
			var t := randf_range(_total * 0.1, _total * 0.95)
			var k := t / maxf(_total, 1.0)
			var n := ColorRect.new()
			n.size = Vector2(px, px)
			n.rotation = _dir.angle()
			n.color = RESIDUE_COLOR_HOT
			n.modulate = RESIDUE_GLOW_HOT
			if _residue_add_mat == null:
				_residue_add_mat = CanvasItemMaterial.new()
				_residue_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			n.material = _residue_add_mat
			add_child(n)
			var pos := start + _dir * t + perp * randf_range(-RESIDUE_SIZE * 2.0, RESIDUE_SIZE * 2.0)
			var vel := _dir * randf_range(RESIDUE_DRIFT.x * 0.5, RESIDUE_DRIFT.y * 0.8) 				+ perp * randf_range(-RESIDUE_SCATTER, RESIDUE_SCATTER)
			_residue.append({
				"node": n, "pos": pos, "vel": vel, "len0": px, "thick": px, "anchor": 0.5,
				"life": randf_range(RESIDUE_DOT_LIFE_MIN, RESIDUE_DOT_LIFE_MAX) * (0.7 + 0.5 * k),   # 탄착 쪽이 조금 더 오래 (첫 버전과 동일)
				"delay": TRAIL_FADE * 0.6 + k * 0.03,
				"t": 0.0,
			})
			_place_residue(n, pos, 0.5, px)


## 수렴 기준점(anchor_pos, 선분 안 비율 anchor)과 현재 길이로 선분 위치를 잡는다. 기준점을 화면 픽셀 격자에 스냅해
## 미끄러지지 않고 "튀어" 움직이게. 회전은 좌상단 기준이므로 중심 → 좌상단 보정을 회전된 축으로 계산한다.
func _place_residue(n: ColorRect, anchor_pos: Vector2, anchor: float, len: float) -> void:
	var a := (anchor_pos / RESIDUE_PX).floor() * RESIDUE_PX
	var center := a + _dir * ((0.5 - anchor) * len)
	var half := n.size * 0.5
	n.position = center - half.rotated(n.rotation)


func _process_residue(delta: float) -> void:
	var i := _residue.size() - 1
	while i >= 0:
		var r: Dictionary = _residue[i]
		var n: ColorRect = r["node"]
		if _impact_t < r["delay"]:
			n.visible = false
			i -= 1
			continue
		n.visible = true
		r["t"] += delta
		var lk: float = r["t"] / float(r["life"])
		if lk >= 1.0:
			n.queue_free()
			_residue.remove_at(i)
			i -= 1
			continue
		r["vel"] *= maxf(0.0, 1.0 - RESIDUE_DAMP * delta)
		r["pos"] += r["vel"] * delta
		# 계단식 진행도: 색·발광·알파를 RESIDUE_STEPS 단계로 끊어 픽셀아트처럼 식는다
		var q := floorf(lk * RESIDUE_STEPS) / float(RESIDUE_STEPS)
		if q < 0.4:
			n.color = RESIDUE_COLOR_HOT.lerp(RESIDUE_COLOR_MID, q / 0.4)
		else:
			n.color = RESIDUE_COLOR_MID.lerp(RESIDUE_COLOR_COLD, (q - 0.4) / 0.6)
		var m := RESIDUE_GLOW_HOT.lerp(RESIDUE_GLOW_COLD, q)
		m.a = 1.0 - q                                        # 가산 블렌드라 알파 0 = 완전 소멸
		n.modulate = m
		# 선 → 점 수렴: 길이가 수명에 걸쳐 두께까지 줄어든다 (초반부터 강하게 줄어 긴 상태는 짧게만 보인다)
		var shrink := 1.0 - pow(lk, 0.45)
		var thick: float = r["thick"]
		var len := maxf(thick, lerpf(thick, float(r["len0"]), shrink))
		len = roundf(len / RESIDUE_PX) * RESIDUE_PX                    # 길이도 픽셀 단위로 끊어서 줄어든다
		n.size = Vector2(len, thick)
		_place_residue(n, r["pos"], r["anchor"], len)
		i -= 1


func _impact() -> void:
	_impacting = true
	_head.visible = false
	_spawn_residue()
	_spawn_smoke()

	# 플래시 (밝은 코어)
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.70, 0.60)
	_flash.size = Vector2(24, 24)
	_flash.pivot_offset = _flash.size * 0.5
	_flash.position = target - _flash.size * 0.5
	_flash.rotation = randf_range(0.0, TAU)
	_flash.modulate = Lighting.RED_EMISSIVE
	if impact_kind == Impact.WATER:
		# 착수: 붉은 섬광 대신 청백 물보라 플래시, 링은 수면에 납작하게
		_flash.color = Color(0.85, 0.95, 1.0)
		_flash.modulate = Color(2.4, 2.8, 3.2, 1.0)
		_flash.size = Vector2(28, 10)
		_flash.pivot_offset = _flash.size * 0.5
		_flash.position = target - _flash.size * 0.5
		_flash.rotation = 0.0
	add_child(_flash)

	# 충격 링 (얇은 사각 테두리 4개)
	_ring = Node2D.new()
	_ring.position = target
	_ring.modulate = Lighting.RED_EMISSIVE_SOFT
	if impact_kind == Impact.WATER:
		_ring.modulate = Color(1.6, 2.0, 2.4, 1.0)
		_ring.scale = Vector2(1.0, 0.3)
	add_child(_ring)
	var half := 17.0
	for side in range(4):
		var r := ColorRect.new()
		r.color = Color(1.0, 0.45, 0.32, 0.9)
		if side < 2:
			r.size = Vector2(half * 2.0, 3.0)
			r.position = Vector2(-half, (-half if side == 0 else half) - 1.5)
		else:
			r.size = Vector2(3.0, half * 2.0)
			r.position = Vector2((-half if side == 2 else half) - 1.5, -half)
		_ring.add_child(r)

	# 탄착 라이트
	_light = PointLight2D.new()
	_light.texture = Lighting.radial_texture()
	_light.texture_scale = Lighting.scale_for_radius(260.0)
	_light.color = Lighting.IMPACT_LIGHT if impact_kind != Impact.WATER else Lighting.WATER
	_light.energy = 2.2 if impact_kind != Impact.WATER else 1.4
	_light.height = Lighting.FLASH_HEIGHT          # 주변 노멀맵이 섬광에 반응
	_light.position = target
	add_child(_light)

	var back := -_dir
	var spark_n := SPARK_COUNT
	var chip_n := CHIP_COUNT
	if impact_kind == Impact.PROP:
		spark_n = int(SPARK_COUNT * 0.6)
		chip_n = int(CHIP_COUNT * 0.5)
	elif impact_kind == Impact.GLASS:
		spark_n = int(SPARK_COUNT * 0.8)
		chip_n = CHIP_COUNT + 4
	elif impact_kind == Impact.FLESH:
		spark_n = int(SPARK_COUNT * 0.4)          # 살에는 불꽃이 거의 없고 독액 방울(Crawler 가 뿌림)이 대신
		chip_n = int(CHIP_COUNT * 0.5)
	elif impact_kind == Impact.WATER:
		spark_n = 0                                # 물에는 불꽃·파편이 없다 — 물기둥·물방울은 WaterPool.bullet_splash 가 그린다
		chip_n = 0
	# 불꽃 스파크: 진행 반대 방향 원뿔로 빠르게, 약한 중력
	for i in range(spark_n):
		var s := ColorRect.new()
		var len := randf_range(13.0, 25.0)
		s.size = Vector2(len, 4.0)
		s.pivot_offset = s.size * 0.5
		s.color = Color(1.0, randf_range(0.30, 0.58), randf_range(0.12, 0.30))
		var v := back.rotated(randf_range(-1.1, 1.1)) * randf_range(560.0, 1150.0)
		s.position = target - s.size * 0.5
		s.rotation = v.angle()
		s.modulate = Lighting.RED_EMISSIVE
		add_child(s)
		_debris.append({"node": s, "vel": v, "spin": 0.0, "gravity": GRAVITY * 0.35,
			"life": randf_range(0.18, 0.32)})

	# 파편: 벽=회색 조각 / 유리=밝은 청백색 얇은 조각(아래로 쏟아짐) / 프랍=나무·금속색 소량 / 살=어두운 살점
	for i in range(chip_n):
		var c := ColorRect.new()
		var sz := randf_range(7.0, 14.0)
		c.size = Vector2(sz, sz * randf_range(0.5, 1.0))
		c.pivot_offset = c.size * 0.5
		var v := back.rotated(randf_range(-1.4, 1.4)) * randf_range(210.0, 580.0) + Vector2(0, -randf_range(60.0, 210.0))
		match impact_kind:
			Impact.GLASS:
				var gl := randf_range(0.75, 1.0)
				c.color = Color(gl * 0.85, gl * 0.95, gl, 0.95)
				c.size = Vector2(sz * 1.3, sz * randf_range(0.25, 0.5))
				v = Vector2(randf_range(-260.0, 260.0), randf_range(-120.0, 220.0))   # 사방으로 흩어지며 낙하
			Impact.PROP:
				var w := randf_range(0.35, 0.55)
				c.color = Color(w * 1.25, w * 0.95, w * 0.7)
			Impact.FLESH:
				var m := randf_range(0.3, 0.5)
				c.color = Color(m * 1.4, m * 0.25, m * 0.2)
				c.size = Vector2(sz * 0.8, sz * 0.6)
			_:
				var g := randf_range(0.42, 0.62)
				c.color = Color(g * 0.9, g * 0.95, g * 1.15)
		c.position = target - c.size * 0.5
		c.rotation = randf_range(0.0, TAU)
		add_child(c)
		_debris.append({"node": c, "vel": v, "spin": randf_range(-18.0, 18.0), "gravity": GRAVITY,
			"life": IMPACT_LIFE})
