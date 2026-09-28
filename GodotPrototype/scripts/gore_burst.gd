class_name GoreBurst
extends Node2D
## 몬스터가 죽는 순간 터지는 체액 비산 (2026-09-24).
## 피격 체액을 절반으로 줄인 대신, 죽음 한 번에 몰아서 터뜨려 체액을 확실히 느끼게 한다.
## 한 노드가 전부 _draw 로 그리되, 형태는 MonsterFx 전용 아틀라스를 사용한다
## (SparkBurst 와 같은 규약 — 월드 좌표, 부모는 변환 없는 층).
##
## ## 사실적으로 (2차 조정)
## 1차는 쨍한 형광 초록 + 가시 돋친 팝이라 만화 같았다. 지금은:
##   · 발광 없음 — 1.0 이하 색으로 그려 CanvasModulate·주변 라이트를 그대로 받는다 (어두운 곳에선 어둡게)
##   · 채도 낮은 탁한 올리브색, 알파로 젖은 반투명감
##   · 방울 크기는 멱분포 — 대부분 아주 잘고 굵은 건 몇 개뿐. 잔 방울일수록 공기 저항을 크게 받아 빨리 멈춘다
##   · 굵은 방울이 바닥에 떨어지면 잔 방울이 튀고(2차 비산) 납작한 자국이 잠시 남는다
##   · 벽에 붙은 방울은 천천히 흘러내리며 세로로 늘어진다
##   · 팝 대신 옅은 비말(에어로졸) 구름이 잠깐 퍼졌다 가라앉는다
## 물리는 점 하나당 적분 몇 줄 + 벽 판정(RoomSolid.confine) 뿐이라 부하가 작다.

const GRAVITY := 2300.0
const STICK_LIFE := 2.2           # 바닥·벽에 붙은 자국이 남아 있는 시간 (1.1 은 눈치채기 전에 사라졌다)
const LIFT := 1.35                # 명도 보정 — 어두운 방(앰비언트 ≈0.45)에 묻히지 않게. 채도는 그대로라 탁한 색은 유지된다
const RIM_DARK := Color(0.07, 0.08, 0.05, 1.0)   # 굵은 방울 외곽 — 밝은 벽·어두운 벽 어디서나 윤곽이 읽힌다
const PUFF_LIFE := 0.28           # 비말 구름

var floor_y := 100000.0
var _t := 0.0
var _center := Vector2.ZERO
var _radius := 100.0
var _wet := Color.WHITE           # 막 튄 체액 (조금 밝고 반투명)
var _dry := Color.WHITE           # 식어 가라앉은 색 (어둡게)
var _drops: Array = []            # {p, v, life, age, size, drag, stuck, flat(Vector2), slide, splashed}
var _mist: Array = []             # {p, v, life, age, size}
var _puff: Array = []             # {off(Vector2), r}


## radius: 비산 반경 기준(월드 px). dir: 탄 진행 방향(+1 왼→오) — 방울이 그쪽으로 조금 더 쏠린다.
static func spawn(parent: Node, pos: Vector2, dir: float, radius: float, floor_line: float,
		wet: Color, dry: Color) -> GoreBurst:
	var g := GoreBurst.new()
	g.floor_y = floor_line
	g.z_index = 1
	parent.add_child(g)
	g._start(pos, dir, radius, wet, dry)
	return g


func _start(pos: Vector2, dir: float, radius: float, wet: Color, dry: Color) -> void:
	_center = pos
	_radius = radius
	_wet = wet
	_dry = dry
	var s := radius / 100.0                                   # 기본 크롤러 기준 배율
	# 굵기 멱분포: t³ — 열에 일곱은 잔 방울
	var bias := Vector2(signf(dir) * 0.45, -1.0)             # 위로 더 솟게 — 몸 중심이 바닥에 가까워 금방 떨어지면 보이지 않는다
	for i in range(randi_range(17, 21)):
		var t := pow(randf(), 3.0)
		var size := lerpf(3.0, 12.0, t) * s
		var v := Vector2.RIGHT.rotated(randf() * TAU)
		v = (v + bias * randf_range(0.3, 1.0)).normalized()
		# 굵은 방울은 느리게 무겁게, 잔 방울은 빠르게 튀어 나갔다가 공기에 잡힌다
		var speed := radius * lerpf(randf_range(5.0, 9.0), randf_range(2.2, 4.0), t)
		_add_drop(pos + v * radius * randf_range(0.0, 0.15), v * speed, size, lerpf(4.5, 0.9, t))
	for i in range(randi_range(28, 35)):
		var v := Vector2.RIGHT.rotated(randf() * TAU)
		v = (v + bias * 0.4).normalized()
		_mist.append({
			"p": pos, "v": v * radius * randf_range(3.0, 8.0),
			"life": randf_range(0.25, 0.5), "age": 0.0,
			"size": randf_range(1.0, 2.2) * s, "variant": randi_range(2, 3),
		})
	for i in range(6):
		_puff.append({"off": Vector2.RIGHT.rotated(randf() * TAU) * radius * randf_range(0.1, 0.35),
			"r": radius * randf_range(0.35, 0.6), "variant": randi_range(2, 3),
			"rot": randf_range(-PI, PI)})
	queue_redraw()


func _add_drop(p: Vector2, v: Vector2, size: float, drag: float) -> void:
	_drops.append({
		"p": p, "v": v, "life": randf_range(0.8, 1.3), "age": 0.0,
		"size": size, "drag": drag,
		"stuck": false, "flat": Vector2.ONE, "slide": 0.0, "splashed": false,
		"variant": randi_range(0, MonsterFx.VARIANTS - 1), "rot": randf_range(-PI, PI),
	})


func _stick(d: Dictionary, flat: Vector2, slide := 0.0) -> void:
	d["stuck"] = true
	d["flat"] = flat
	d["slide"] = slide
	d["life"] = d["age"]


func _process(delta: float) -> void:
	_t += delta
	var spawned: Array = []
	var i := 0
	while i < _drops.size():
		var d: Dictionary = _drops[i]
		d["age"] += delta
		if d["age"] >= d["life"] + (STICK_LIFE if d["stuck"] else 0.0):
			_drops.remove_at(i)
			continue
		if d["stuck"]:
			# 벽에 붙은 방울: 점성으로 점점 느려지며 흘러내리고, 흐른 만큼 세로로 늘어진다
			var sl: float = d["slide"]
			if sl > 0.5:
				d["p"] = (d["p"] as Vector2) + Vector2(0, sl * delta)
				d["flat"] = (d["flat"] as Vector2) + Vector2(0, sl * delta * 0.02)
				d["slide"] = sl * exp(-2.5 * delta)
			i += 1
			continue
		var v: Vector2 = d["v"]
		v *= exp(-float(d["drag"]) * delta)
		v.y += GRAVITY * delta
		var p: Vector2 = d["p"] + v * delta
		var hit := RoomSolid.bounce_walls(p, v, 0.0)
		var hv: Vector2 = hit[1]
		p = hit[0]
		var sz: float = d["size"]
		if hv.x != v.x:
			_stick(d, Vector2(0.7, 1.3), randf_range(15.0, 45.0) * clampf(sz / 5.0, 0.3, 1.0))
		elif hv.y != v.y:
			_stick(d, Vector2(1.5, 0.6))
		elif p.y >= floor_y and v.y > 0.0:
			p.y = floor_y
			# 굵은 방울이 세게 떨어지면 잔 방울이 튄다 (한 번만)
			if sz > 3.5 * _radius / 100.0 and v.y > 500.0 and not d["splashed"]:
				d["splashed"] = true
				for k in range(randi_range(2, 3)):
					spawned.append([p + Vector2(0, -2), Vector2(randf_range(-1.0, 1.0) * 220.0 + v.x * 0.2,
						-randf_range(180.0, 380.0)), sz * randf_range(0.2, 0.35)])
			_stick(d, Vector2(2.4, 0.4))
		d["v"] = v
		d["p"] = p
		i += 1
	for sp in spawned:
		_add_drop(sp[0], sp[1], sp[2], 3.0)
		_drops[-1]["splashed"] = true
		_drops[-1]["life"] = randf_range(0.3, 0.5)
	i = 0
	while i < _mist.size():
		var m: Dictionary = _mist[i]
		m["age"] += delta
		if m["age"] >= m["life"]:
			_mist.remove_at(i)
			continue
		var mv: Vector2 = m["v"] * exp(-8.0 * delta)
		mv.y += 400.0 * delta
		m["v"] = mv
		m["p"] = (m["p"] as Vector2) + mv * delta
		i += 1
	queue_redraw()
	if _t > PUFF_LIFE and _drops.is_empty() and _mist.is_empty():
		queue_free()


## 발광 없이 — 젖은 색에서 마른 색으로 가라앉는다. 알파로 얇은 막의 반투명감을 준다.
func _col(k: float, alpha: float) -> Color:
	var c := _wet.lerp(_dry, clampf(k, 0.0, 1.0)) * LIFT
	return Color(c.r, c.g, c.b, alpha)


func _draw() -> void:
	# 비말 구름 — 전용 점액/미스트 스프라이트가 옅게 부풀었다 가라앉는다.
	if _t <= PUFF_LIFE:
		var k := _t / PUFF_LIFE
		var grow := 1.0 - pow(1.0 - k, 2.0)
		var a := 0.14 * (1.0 - k)
		for pf in _puff:
			var pc: Vector2 = _center + (pf["off"] as Vector2) * (0.6 + grow) + Vector2(0, k * 10.0)
			var pr: float = float(pf["r"]) * (0.5 + 0.7 * grow)
			draw_set_transform(pc, float(pf["rot"]), Vector2.ONE)
			MonsterFx.draw(self, MonsterFx.ROW_SALIVA, int(pf["variant"]),
				Rect2(Vector2(-pr, -pr), Vector2(pr, pr) * 2.0), Color(1, 1, 1, a * 1.6))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for m in _mist:
		var mk: float = m["age"] / m["life"]
		var ms: float = float(m["size"]) * 4.0
		MonsterFx.draw(self, MonsterFx.ROW_SALIVA, int(m["variant"]),
			Rect2((m["p"] as Vector2) - Vector2.ONE * ms, Vector2.ONE * ms * 2.0),
			Color(1, 1, 1, 0.5 * (1.0 - mk)))
	for d in _drops:
		var sz: float = d["size"]
		var p: Vector2 = d["p"]
		if d["stuck"]:
			var sk := clampf((d["age"] - d["life"]) / STICK_LIFE, 0.0, 1.0)
			var sa := 1.0 - sk * sk
			var stuck_size := Vector2.ONE * sz * 3.4
			draw_set_transform(p, float(d["rot"]), d["flat"])
			MonsterFx.draw(self, MonsterFx.ROW_SPLAT, int(d["variant"]),
				Rect2(-stuck_size * 0.5, stuck_size), Color(1, 1, 1, 0.92 * sa))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var k: float = d["age"] / d["life"]
		var col := _col(k * 0.5, 0.95 * (1.0 - smoothstep(0.85, 1.0, k)))
		var speed: float = (d["v"] as Vector2).length()
		var drop_size := Vector2(sz * 3.1, sz * 3.1 * clampf(speed / 360.0, 0.9, 1.8))
		var rot := (d["v"] as Vector2).angle() - PI * 0.5 + float(d["rot"]) * 0.12
		draw_set_transform(p, rot, Vector2.ONE)
		MonsterFx.draw(self, MonsterFx.ROW_FLUID, int(d["variant"]), Rect2(-drop_size * 0.5, drop_size),
			Color(1, 1, 1, col.a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
