class_name BloodStain
extends Node2D
## 벽에 남는 초록 체액 자국. 몬스터 피격·죽음 위치 뒤 벽면에 방울 무리를 찍고,
## 몇 방울은 아래로 흘러내린다(높이가 1.5초 동안 늘어남). 오래 남았다가 천천히 옅어진다.
## 한 노드가 방울 전부를 _draw 로 그린다. 프랍 층(z 2: 타일·문 앞, 캐릭터 뒤)에 올린다.
##
## spray(): 가끔 벽면으로 부채꼴로 펼쳐지며 흩뿌려지는 분사. 덩어리마다 도착 시각(t0)이 달라
## 가까운 것부터 순차적으로 벽에 찍히고(찍히는 순간 살짝 크게 튀어 보임), 이후 중력으로 천천히 흘러내린다
## (SPRAY_DRIP_TIME 동안 가속하며 늘어남, 덩어리 자체도 조금 미끄러짐).

const LIFE := 28.0
const FADE := 6.0
const DRIP_TIME := 1.5
const FLOOR_Y := 486.0
const WALL_TOP := 40.0
const SPRAY_DRIP_TIME := 6.5     # 분사 덩어리가 흘러내리는 시간 (느리게 시작해 가속)
const SPRAY_POP := 0.09          # 벽에 찍히는 순간 커 보이는 시간

## 체액 기본색 — 채도·밝기를 눌러 형광기 없이 '젖은 초록'으로. 빛 반응은 fluid.gdshader 가 light_response 로 낮춘다.
const FLUID := Color(0.34, 0.60, 0.16)

var _blobs: Array = []       # {p, size(Vector2), col, drip(최대 늘어나는 높이), [t0 도착 시각, slide 미끄러짐]}
var _t := 0.0
var _spray := false
var _spray_end := 0.0        # 마지막 덩어리가 흘러내림을 끝내는 시각


## pos: 튄 중심 월드 좌표, dir: 탄 진행 방향(자국이 이쪽으로 길게 번짐), amount: 방울 수, spread: 퍼지는 반경
static func splat(parent: Node, pos: Vector2, dir: Vector2, amount: int, spread: float) -> BloodStain:
	var bs := BloodStain.new()
	bs.z_index = 1
	bs._build(pos, dir, amount, spread)
	parent.add_child(bs)
	return bs


## 벽면 분사. pos: 분사 원점, dir: 뿜는 방향, amount: 덩어리 수, length: 최대 도달 거리, fan: 부채꼴 전체 각(rad)
static func spray(parent: Node, pos: Vector2, dir: Vector2, amount: int, length: float, fan: float) -> BloodStain:
	var bs := BloodStain.new()
	bs.z_index = 1
	bs._build_spray(pos, dir, amount, length, fan)
	parent.add_child(bs)
	return bs


func _init() -> void:
	# 빛에 둔한 체액 재질 (스페큘러·림 없음, 광원 밝기 28% 만 받음)
	material = Lighting.shader_material("fluid")


func _build_spray(pos: Vector2, dir: Vector2, amount: int, length: float, fan: float) -> void:
	_spray = true
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var last := 0.0
	for i in range(amount):
		var ang := randf_range(-0.5, 0.5) * fan
		var dist := length * pow(randf(), 0.65)                 # 멀리까지 고르게, 원점 근처는 조금 더 촘촘
		var p := pos + d.rotated(ang) * dist
		p.y = clampf(p.y, WALL_TOP, FLOOR_Y - 2.0)
		var frac := dist / maxf(length, 1.0)
		# 도착 시각: 멀수록 늦게 (분사가 퍼져 나가는 순서) + 약간의 흔들림
		var t0 := frac * randf_range(0.22, 0.34) + randf_range(0.0, 0.05)
		var sz := randf_range(4.0, 8.0) + (1.0 - frac) * randf_range(4.0, 12.0)
		var shade := randf_range(0.6, 1.0)
		var col := Color(FLUID.r * shade, FLUID.g * shade, FLUID.b * shade, randf_range(0.82, 0.97))
		var drip := 0.0
		if sz >= 6.0:
			drip = randf_range(14.0, 60.0) * randf_range(0.6, 1.2)  # 대부분 흘러내림
		var slide := randf_range(0.0, 6.0) if sz >= 8.0 else 0.0   # 굵은 덩어리는 자체도 조금 미끄러짐
		_blobs.append({"p": p, "size": Vector2(sz, sz * randf_range(0.7, 1.0)), "col": col, "drip": drip, "t0": t0, "slide": slide})
		last = maxf(last, t0)
	_spray_end = last + SPRAY_DRIP_TIME
	for b in _blobs:
		b["p"] = (b["p"] / 2.0).floor() * 2.0
		b["size"] = (b["size"] / 2.0).ceil() * 2.0


func _build(pos: Vector2, dir: Vector2, amount: int, spread: float) -> void:
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	for i in range(amount):
		# 진행 방향으로 치우친 타원 분포 + 중심 근처에 큰 덩어리
		var along := randf_range(-0.3, 1.0) * spread
		var side := randf_range(-1.0, 1.0) * spread * 0.55
		var p := pos + d * along + Vector2(-d.y, d.x) * side
		p.y = minf(p.y, FLOOR_Y - 2.0)                    # 바닥선 아래로는 안 내려감
		var near := 1.0 - clampf(p.distance_to(pos) / maxf(spread, 1.0), 0.0, 1.0)
		var sz := randf_range(4.0, 9.0) + near * randf_range(6.0, 18.0)
		var shade := randf_range(0.6, 1.0)
		var col := Color(FLUID.r * shade, FLUID.g * shade, FLUID.b * shade, randf_range(0.8, 0.97))
		var drip := 0.0
		if sz > 9.0 and randf() < 0.5:
			drip = randf_range(10.0, 40.0)
		_blobs.append({"p": p, "size": Vector2(sz, sz * randf_range(0.7, 1.0)), "col": col, "drip": drip})
	# 픽셀 격자에 맞춘다 (2px)
	for b in _blobs:
		b["p"] = (b["p"] / 2.0).floor() * 2.0
		b["size"] = (b["size"] / 2.0).ceil() * 2.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	if _t < DRIP_TIME + 0.1 or _t > LIFE - FADE or (_spray and _t < _spray_end + 0.1):
		queue_redraw()


func _draw() -> void:
	var a := 1.0 if _t < LIFE - FADE else clampf((LIFE - _t) / FADE, 0.0, 1.0)
	var k := clampf(_t / DRIP_TIME, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)                       # 처음 빨리, 나중에 천천히
	for b in _blobs:
		var col: Color = b["col"]
		col.a *= a
		var p: Vector2 = b["p"]
		var s: Vector2 = b["size"]
		var kk := k
		if _spray:
			var age: float = _t - float(b["t0"])
			if age < 0.0:
				continue                                        # 아직 벽에 도달하지 않은 덩어리
			# 찍히는 순간 살짝 크게 튀어 보이고 곧 자리 잡는다
			var pop := 1.0 + 0.7 * maxf(0.0, 1.0 - age / SPRAY_POP)
			s = (s * pop / 2.0).ceil() * 2.0
			# 중력: 느리게 시작해 가속하며 흘러내림. 덩어리 자체도 조금 미끄러진다
			kk = clampf(pow(age / SPRAY_DRIP_TIME, 1.6), 0.0, 1.0)
			p.y = minf(p.y + floorf(float(b["slide"]) * kk / 2.0) * 2.0, FLOOR_Y - 2.0)
		draw_rect(Rect2(p - s * 0.5, s), col)
		if b["drip"] > 0.0:
			var h: float = b["drip"] * kk
			var w := maxf(2.0, floorf(s.x * 0.3 / 2.0) * 2.0)
			var drip_col := Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, col.a)
			draw_rect(Rect2(p.x - w * 0.5, p.y, w, h), drip_col)
			draw_rect(Rect2(p.x - w, p.y + h - 2.0, w * 2.0, 3.0), drip_col)   # 흘러내린 끝의 방울
