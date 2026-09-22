class_name BloodStain
extends Node2D
## 몬스터 체액 자국. **덩어리마다 어느 면에 착지했는지 따로 판정**해서, 그 면에 맞는 깊이·형태·재질로 그린다.
##
## 예전에는 뿌려진 덩어리 전부가 한 노드에 담겨 프랍 층(z2) 한 겹에만, 같은 크기·같은 색·같은 불투명도로 찍혔다.
## 뒷벽에 튄 것과 눈앞 프랍에 튄 것이 구분되지 않으니 자국이 화면에 붙은 평평한 스티커로 읽혔다. 지금은:
##
##   ① 레이 판정   — 덩어리마다 원점→목표 선분을 훑어 처음 만나는 면(프랍 / 바닥 / 벽 / 뒷벽)에 착지시킨다.
##                   착지면이 다르면 **자국 노드가 나뉜다** (spray/splat 은 노드 배열을 돌려준다).
##                   프랍에 붙은 자국은 그 프랍의 자식이라 프랍이 들썩이고 밀리면 같이 움직이고,
##                   프랍 실루엣(is_solid_at) 밖으로 삐져나온 덩어리는 아예 버린다.
##   ② 젖은 재질   — fluid.gdshader 가 스페큘러를 갖고, 프랍 자국은 숙주 프랍의 노멀맵으로 라이팅된다.
##                   얇은 부분은 fluid_film.gdshader(곱연산)로 아래 표면의 명암·결이 그대로 비친다.
##   ③ 면 방향     — 바닥에 떨어진 것은 흘러내리지 않고 원근에 눌린 납작한 웅덩이로 그린다.
##   ④ 코어/미스트 — 굵은 코어(적음·흐름 있음)와 미세 비말(많음·아주 얇음) 두 집단으로 나눠 밀도 대비를 만든다.
##   ⑤ 3톤 방울    — 어두운 외곽 / 본체 / 윗면 하이라이트. 픽셀 격자(2px)는 그대로 지킨다.
##   ⑥ 근경 방울   — 가끔 근경 층(z7)에 크고 어두운 방울 몇 개. 카메라 바로 앞에 튄 것이라 깊이 폭이 단번에 벌어진다.
##
## 재질은 두 겹이다. 노드 자신(_draw)이 **두꺼운 코어·흐름**을 fluid 로 그리고,
## z -1 의 자식 Film 이 **얇은 막·미세 비말**을 fluid_film(곱연산)으로 먼저 그린다.

enum Surface { WALL, PROP, FLOOR, FRONT }

const LIFE := 28.0
const FADE := 6.0
const DRIP_TIME := 1.5
const FLOOR_Y := 486.0
const WALL_TOP := 40.0
const SPRAY_DRIP_TIME := 6.5     # 분사 덩어리가 흘러내리는 시간 (느리게 시작해 가속)
const SPRAY_POP := 0.09          # 벽에 찍히는 순간 커 보이는 시간
const FRONT_LIFE := 11.0         # 근경 방울은 오래 두면 화면을 가린다
const FRONT_FADE := 3.5

## 체액 기본색 — 채도·밝기를 눌러 형광기 없이 '젖은 초록'으로.
## 젖은 재질로 바꾸면서 베이스를 더 어둡게 내렸다 (밝기는 스페큘러가 낸다).
const FLUID := Color(0.30, 0.53, 0.14)

## 착지면별 깊이 프로필 — 공기원근. 먼 뒷벽은 작고 어둡고 채도·두께가 낮고, 눈앞 프랍은 크고 또렷하다.
##   size 크기 · value 명도 · sat 채도 · film 얇은 막 두께 · drip 흘러내림 배율 · spec 젖은 하이라이트 배율
const DEPTH := {
	Surface.WALL:  {"size": 0.80, "value": 0.86, "sat": 0.78, "film": 0.78, "drip": 0.85, "spec": 0.55},
	Surface.PROP:  {"size": 1.16, "value": 1.14, "sat": 1.00, "film": 1.05, "drip": 1.00, "spec": 1.00},
	Surface.FLOOR: {"size": 1.04, "value": 0.95, "sat": 0.86, "film": 0.92, "drip": 0.00, "spec": 0.85},
	Surface.FRONT: {"size": 2.70, "value": 0.34, "sat": 0.55, "film": 1.30, "drip": 1.40, "spec": 0.30},
}

const RAY_STEP := 7.0            # 착지면 탐색 간격 (px)
const RAY_SKIP := 14.0           # 원점 근처(몬스터 몸 안)는 건너뛴다
const FLOOR_BAND := 6.0          # 이 안쪽이면 바닥면으로 친다
const MIST_PER_CORE := 2.2       # 코어 하나당 미세 비말 수
const FRONT_CHANCE := 0.22       # 분사 한 번이 근경에 방울을 남길 확률


## 얇은 막·미세 비말 층 (곱연산). 부모 자국의 draw_film 이 그린다.
class Film extends Node2D:
	var host: BloodStain
	func _draw() -> void:
		if host and is_instance_valid(host):
			host.draw_film(self)


var surface: int = Surface.WALL
var _blobs: Array = []       # {p, size, col, drip, t0, slide, flat, mist}
var _t := 0.0
var _spray := false
var _spray_end := 0.0        # 마지막 덩어리가 흘러내림을 끝내는 시각
var _life := LIFE
var _fade := FADE
var _film: Film
var _prof: Dictionary = DEPTH[Surface.WALL]


# ----------------------------------------------------------------------------- 공개 창구

## 피격·죽음 자리에 튀는 자국. 착지면별로 나뉜 자국 노드 배열을 돌려준다.
## room: Room (props_hit / solid / floor_y / 층 노드를 쓴다), pos: 튄 중심, dir: 탄 진행 방향,
## amount: 방울 수, spread: 퍼지는 반경
static func splat(room: Node, pos: Vector2, dir: Vector2, amount: int, spread: float) -> Array:
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var seeds: Array = []
	for i in range(amount):
		var along := randf_range(-0.3, 1.0) * spread
		var side := randf_range(-1.0, 1.0) * spread * 0.55
		var q := pos + d * along + Vector2(-d.y, d.x) * side
		var near := 1.0 - clampf(q.distance_to(pos) / maxf(spread, 1.0), 0.0, 1.0)
		var sz := randf_range(4.0, 9.0) + near * randf_range(6.0, 18.0)
		var dp := randf_range(10.0, 40.0) if (sz > 9.0 and randf() < 0.5) else 0.0
		seeds.append({"from": pos, "to": q, "size": sz, "t0": 0.0, "drip": dp, "slide": 0.0})
	# 미세 비말 — 튄 자리 둘레로 더 넓게 흩어진다
	for i in range(int(amount * MIST_PER_CORE * 0.7)):
		var ma := randf_range(-1.0, 1.0)
		var q2 := pos + d * (randf_range(-0.5, 1.5) * spread) + Vector2(-d.y, d.x) * (ma * spread * 1.2)
		seeds.append({"from": pos, "to": q2, "size": randf_range(2.0, 4.0), "t0": 0.0,
			"drip": 0.0, "slide": 0.0, "mist": true})
	return _emit(room, seeds, false, pos)


## 벽면 분사. pos: 분사 원점, dir: 뿜는 방향, amount: 코어 수, length: 최대 도달 거리, fan: 부채꼴 전체 각(rad)
static func spray(room: Node, pos: Vector2, dir: Vector2, amount: int, length: float, fan: float) -> Array:
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var seeds: Array = []
	# ④ 코어: 적고 굵고 흘러내린다
	for i in range(amount):
		var ang := randf_range(-0.5, 0.5) * fan
		var dist := length * pow(randf(), 0.65)
		var frac := dist / maxf(length, 1.0)
		var sz := randf_range(5.0, 9.0) + (1.0 - frac) * randf_range(5.0, 13.0)
		var dp := randf_range(14.0, 60.0) * randf_range(0.6, 1.2) if sz >= 7.0 else 0.0
		var sl := randf_range(0.0, 6.0) if sz >= 9.0 else 0.0
		seeds.append({"from": pos, "to": pos + d.rotated(ang) * dist, "size": sz,
			"t0": frac * randf_range(0.22, 0.34) + randf_range(0.0, 0.05), "drip": dp, "slide": sl})
	# ④ 미세 비말: 많고 아주 얇다 (곱연산 막으로만 그려져 표면을 살짝 물들인다).
	# 부채꼴을 더 넓게 벌리고 더 멀리 뿌려 코어 무리 바깥을 감싼다 — 밀도 대비가 생겨 균질함이 깨진다.
	for i in range(int(amount * MIST_PER_CORE)):
		var mang := randf_range(-0.5, 0.5) * fan * 1.45
		var mdist := length * randf_range(0.25, 1.35)
		seeds.append({"from": pos, "to": pos + d.rotated(mang) * mdist, "size": randf_range(2.0, 6.0),
			"t0": (mdist / maxf(length, 1.0)) * randf_range(0.18, 0.30), "drip": 0.0, "slide": 0.0, "mist": true})
	var made := _emit(room, seeds, true, pos)
	# ⑥ 근경 방울 — 카메라 바로 앞을 스치는 층에 크고 어두운 몇 방울
	var fg = room.get("foreground") if room else null
	if fg != null and is_instance_valid(fg) and randf() < FRONT_CHANCE:
		var front := _front_drops(fg, pos, d, length)
		if front != null:
			made.append(front)
	return made


# ----------------------------------------------------------------------------- 착지면 판정 · 조립

## ① 덩어리 씨앗들을 착지면별로 갈라 자국 노드들을 만든다
static func _emit(room: Node, seeds: Array, is_spray: bool, origin: Vector2) -> Array:
	var groups: Dictionary = {}          # key → {"surface", "host", "blobs"}
	for s in seeds:
		var hit := _resolve(room, s["from"], s["to"])
		var host = hit["host"]
		var key := "%d:%d" % [hit["surface"], host.get_instance_id() if host != null else 0]
		if not groups.has(key):
			groups[key] = {"surface": hit["surface"], "host": host, "blobs": []}
		var b := _make_blob(hit, s, origin)
		if not b.is_empty():
			groups[key]["blobs"].append(b)
	var made: Array = []
	for key in groups:
		var g: Dictionary = groups[key]
		if g["blobs"].is_empty():
			continue
		var bs := BloodStain.new()
		bs._setup(g["surface"], g["host"], g["blobs"], is_spray)
		_attach(room, bs, g["surface"], g["host"])
		made.append(bs)
	return made


## 착지면 판정: **도착점이 어느 면 위에 있는가**. → {"surface", "point", "host", "floor_y"}
## 사이드뷰라 화면의 한 점 뒤에는 늘 뒷벽이 있고, 그 앞을 프랍·바닥이 가린다. 그래서 선분을 훑어
## "처음 만나는 면"을 찾으면 안 된다 — 원점이 프랍 안이나 방 밖이면 모든 덩어리가 한 점으로 뭉친다.
## 도착점을 직접 질의하면 부채꼴이 그대로 퍼진 채 면만 갈린다: 프랍 실루엣 안이면 프랍, 바닥 띠면 바닥,
## 벽 기하 안이면 그 벽면(선분을 벽까지 당겨서), 그 밖이면 전부 뒷벽.
static func _resolve(room: Node, from: Vector2, to: Vector2) -> Dictionary:
	var floor_y: float = float(room.get("floor_y")) if room != null and room.get("floor_y") != null else FLOOR_Y
	var props: Array = room.stain_props() if room != null and room.has_method("stain_props") else []
	var solid = room.get("solid") if room != null else null
	var out := {"surface": Surface.WALL, "point": to, "host": null, "floor_y": floor_y}
	# ③ 바닥면 — 벽보다 먼저 본다 (RoomSolid.is_solid 는 바닥 아래도 벽으로 치기 때문에)
	if to.y >= floor_y - FLOOR_BAND:
		out["surface"] = Surface.FLOOR
		out["point"] = Vector2(to.x, floor_y - 2.0)
		return out
	# 프랍 앞면 — 실루엣(깨진 구멍 제외) 안에 떨어진 것만
	for pr in props:
		if is_instance_valid(pr) and pr.is_solid_at(to):
			out["surface"] = Surface.PROP
			out["point"] = to
			out["host"] = pr
			return out
	# 측벽·천장 — 벽 기하 안으로 들어갔으면 표면까지 당긴다
	if solid != null and solid.is_solid(to):
		out["point"] = solid.clip_ray(from, to)
		return out
	return out


## 착지 결과 + 씨앗 → 그릴 덩어리. 프랍 실루엣 밖이면 빈 사전(버린다).
static func _make_blob(hit: Dictionary, s: Dictionary, origin: Vector2) -> Dictionary:
	var surf: int = hit["surface"]
	var prof: Dictionary = DEPTH[surf]
	var p: Vector2 = hit["point"]
	var host = hit["host"]
	var flat := surf == Surface.FLOOR
	var mist: bool = s.get("mist", false)
	if surf == Surface.WALL:
		p.y = clampf(p.y, WALL_TOP, float(hit.get("floor_y", FLOOR_Y)) - 2.0)
	var sz: float = float(s["size"]) * float(prof["size"])
	# 깊이별 명도·채도 (공기원근) + 덩어리마다의 흔들림
	var shade := randf_range(0.62, 1.0) * float(prof["value"])
	var col := Color(FLUID.r * shade, FLUID.g * shade, FLUID.b * shade, 1.0)
	var lum := col.r * 0.299 + col.g * 0.587 + col.b * 0.114
	var sat: float = float(prof["sat"])
	var alpha := randf_range(0.28, 0.58) if mist else randf_range(0.80, 0.97)
	col = Color(lerpf(lum, col.r, sat), lerpf(lum, col.g, sat), lerpf(lum, col.b, sat), alpha)
	var drip: float = float(s["drip"]) * float(prof["drip"])
	if surf == Surface.PROP and host != null and drip > 0.0:
		drip = minf(drip, maxf(host.rect.end.y - p.y - 4.0, 0.0))    # 프랍 아래로는 흘러내리지 않는다
	var local := p
	if host != null and host is Node2D:
		local = (host as Node2D).to_local(p)                          # 프랍이 들썩·밀려도 자국이 따라간다
	var h := randf_range(0.28, 0.42) if flat else randf_range(0.7, 1.0)
	var size := Vector2(sz, sz * h)
	return {
		"p": (local / 2.0).floor() * 2.0,
		"size": (size / 2.0).ceil() * 2.0,
		"col": col, "drip": drip, "t0": float(s["t0"]), "slide": float(s["slide"]),
		"flat": flat, "mist": mist,
		# ⑤ 실루엣을 깨는 고정 난수 — 네모 한 장이 아니라 겹친 덩이 세 개로 그린다
		"ar": randf_range(0.50, 0.76),                                   # 가운데 덩이의 가늘기
		"lobe": Vector2(randf_range(-0.34, 0.34), randf_range(-0.30, 0.30)),   # 곁덩이가 붙는 쪽
		"near": 1.0 - clampf(p.distance_to(origin) / 400.0, 0.0, 1.0),
	}


## 착지면에 맞는 층에 자국을 붙인다
static func _attach(room: Node, bs: BloodStain, surf: int, host) -> void:
	if surf == Surface.PROP and host != null and is_instance_valid(host):
		bs.z_index = 1                       # 숙주 프랍 바로 앞
		host.add_child(bs)
		return
	var layer: Node = room.stain_layer() if room.has_method("stain_layer") else room
	bs.z_index = -1                          # 프랍보다 뒤 (뒷벽·바닥면)
	layer.add_child(bs)


## ⑥ 근경 방울 — 카메라 바로 앞 층에 크고 어두운 몇 방울
static func _front_drops(layer: Node2D, pos: Vector2, d: Vector2, length: float) -> BloodStain:
	var blobs: Array = []
	for i in range(randi_range(2, 4)):
		var q := pos + d.rotated(randf_range(-0.7, 0.7)) * length * randf_range(0.3, 1.1)
		q += Vector2(randf_range(-120.0, 120.0), randf_range(-90.0, 40.0))
		var sz := randf_range(7.0, 13.0) * float(DEPTH[Surface.FRONT]["size"])
		var shade := randf_range(0.7, 1.0) * float(DEPTH[Surface.FRONT]["value"])
		blobs.append({
			"p": (q / 2.0).floor() * 2.0,
			"size": (Vector2(sz, sz * randf_range(0.8, 1.15)) / 2.0).ceil() * 2.0,
			"col": Color(FLUID.r * shade, FLUID.g * shade, FLUID.b * shade, randf_range(0.85, 1.0)),
			"drip": randf_range(30.0, 90.0), "t0": randf_range(0.0, 0.12), "slide": randf_range(2.0, 10.0),
			"flat": false, "mist": false, "near": 1.0,
			"ar": randf_range(0.50, 0.76),
			"lobe": Vector2(randf_range(-0.34, 0.34), randf_range(-0.30, 0.30)),
		})
	if blobs.is_empty():
		return null
	var bs := BloodStain.new()
	bs._setup(Surface.FRONT, null, blobs, true)
	bs.light_mask = 0                        # 근경 층 규칙 — 라이트를 받지 않는다 (앰비언트만)
	bs.z_index = 1
	layer.add_child(bs)
	return bs


# ----------------------------------------------------------------------------- 인스턴스

func _setup(surf: int, host, blobs: Array, is_spray: bool) -> void:
	surface = surf
	_prof = DEPTH[surf]
	_blobs = blobs
	_spray = is_spray
	if surf == Surface.FRONT:
		_life = FRONT_LIFE
		_fade = FRONT_FADE
	var last := 0.0
	for b in _blobs:
		last = maxf(last, float(b["t0"]))
	_spray_end = last + SPRAY_DRIP_TIME
	# ② 젖은 재질. 프랍 자국은 그 프랍의 노멀맵으로 라이팅해 표면 굴곡을 따라 하이라이트가 흐른다.
	var mat := Lighting.shader_material("fluid")
	mat.set_shader_parameter("spec_strength", 2.6 * float(_prof["spec"]))
	mat.set_shader_parameter("key_wet", 0.20 * float(_prof["spec"]))
	var hs := _host_sprite(host)
	if hs != null and hs.texture != null:
		var nrm := _normal_of(hs)
		if nrm != null:
			mat.set_shader_parameter("host_normal", nrm)
			mat.set_shader_parameter("host_rect", _host_tex_rect(host, hs))
			mat.set_shader_parameter("host_flip", 1.0 if hs.flip_h else 0.0)
			mat.set_shader_parameter("use_host_normal", 1.0)
	material = mat
	_film = Film.new()
	_film.host = self
	_film.z_index = -1                       # 얇은 막이 먼저 (아래 표면을 곱한 뒤 그 위에 코어가 얹힌다)
	var fmat := Lighting.shader_material("fluid_film")
	fmat.set_shader_parameter("density", float(_prof["film"]))
	_film.material = fmat
	add_child(_film)


## 숙주가 그림을 그리는 스프라이트 (HitProp 은 자기 자신, 단말기는 자식 TerminalSprite)
static func _host_sprite(host) -> Sprite2D:
	if host is Sprite2D:
		return host as Sprite2D
	if host is Node:
		for c in (host as Node).get_children():
			if c is Sprite2D:
				return c as Sprite2D
	return null


## 숙주 텍스처가 차지하는 사각형 — **자국 노드의 로컬 좌표계**로. 셰이더가 노멀맵 UV 를 여기서 만든다.
static func _host_tex_rect(host, s: Sprite2D) -> Vector4:
	var sz := s.texture.get_size()
	var base := Vector2.ZERO if host == s else s.position     # 숙주가 스프라이트 자신이면 위치는 이미 원점
	var o := base + (-sz * 0.5 if s.centered else s.offset)
	return Vector4(o.x, o.y, sz.x, sz.y)


## 숙주 프랍의 노멀맵 텍스처 (Lighting.textured 가 만든 CanvasTexture 안에 있다)
static func _normal_of(s: Sprite2D) -> Texture2D:
	var t := s.texture
	if t is CanvasTexture:
		return (t as CanvasTexture).normal_texture
	return null


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	if _t < DRIP_TIME + 0.1 or _t > _life - _fade or (_spray and _t < _spray_end + 0.1):
		queue_redraw()
		if _film != null:
			_film.queue_redraw()


## 시각 t 에서 덩어리의 실제 위치·크기·흐름 진행도 → [위치, 크기, kk] / 아직 도착 전이면 빈 배열
func _state(b: Dictionary) -> Array:
	var p: Vector2 = b["p"]
	var s: Vector2 = b["size"]
	var k := clampf(_t / DRIP_TIME, 0.0, 1.0)
	k = 1.0 - (1.0 - k) * (1.0 - k)
	if _spray:
		var age: float = _t - float(b["t0"])
		if age < 0.0:
			return []
		var pop := 1.0 + 0.7 * maxf(0.0, 1.0 - age / SPRAY_POP)
		s = (s * pop / 2.0).ceil() * 2.0
		k = clampf(pow(age / SPRAY_DRIP_TIME, 1.6), 0.0, 1.0)
		if not b["flat"]:
			p.y += floorf(float(b["slide"]) * k / 2.0) * 2.0
	if b["flat"]:
		s.x = s.x * (0.6 + 0.4 * minf(1.0, _t / 0.2))       # ③ 바닥 웅덩이는 옆으로 퍼진다
		s = (s / 2.0).ceil() * 2.0
	return [p, s, k]


func _alpha() -> float:
	return 1.0 if _t < _life - _fade else clampf((_life - _t) / _fade, 0.0, 1.0)


# ----------------------------------------------------------------------------- 그리기

## 얇은 막 층 (곱연산): 미세 비말 전부 + 코어를 감싸는 젖은 테두리.
## 아래 표면의 명암·결이 그대로 비쳐 자국이 표면에 "스며든" 것으로 읽힌다.
func draw_film(c: CanvasItem) -> void:
	var a := _alpha()
	for b in _blobs:
		var st := _state(b)
		if st.is_empty():
			continue
		var p: Vector2 = st[0]
		var s: Vector2 = st[1]
		var col: Color = b["col"]
		if b["mist"]:
			c.draw_rect(Rect2(p - s * 0.5, s), Color(col.r, col.g, col.b, col.a * a))
			continue
		# 코어 둘레로 번진 얇은 막 — 코어보다 넓고 훨씬 옅다
		var grow := 2.4 if b["flat"] else 1.9
		var halo := (s * grow / 2.0).ceil() * 2.0
		c.draw_rect(Rect2(p - halo * 0.5, halo), Color(col.r, col.g, col.b, col.a * a * 0.42))
		if b["drip"] > 0.0:
			var h: float = float(b["drip"]) * float(st[2])
			var w := maxf(4.0, floorf(s.x * 0.62 / 2.0) * 2.0)
			c.draw_rect(Rect2(p.x - w * 0.5, p.y, w, h), Color(col.r, col.g, col.b, col.a * a * 0.28))


## 두꺼운 코어·흐름 (젖은 재질): ⑤ 어두운 외곽 / 본체 / 윗면 하이라이트 3톤
func _draw() -> void:
	var a := _alpha()
	for b in _blobs:
		if b["mist"]:
			continue
		var st := _state(b)
		if st.is_empty():
			continue
		var p: Vector2 = st[0]
		var s: Vector2 = st[1]
		var kk: float = st[2]
		var col: Color = b["col"]
		col.a *= a
		var dark := Color(col.r * 0.42, col.g * 0.42, col.b * 0.46, col.a)
		var lit := Color(minf(col.r * 2.1 + 0.06, 1.0), minf(col.g * 1.85 + 0.08, 1.0),
			minf(col.b * 1.9 + 0.05, 1.0), col.a)
		# 흘러내린 자국 (본체보다 먼저 — 본체가 그 위에 얹힌다)
		if b["drip"] > 0.0:
			_draw_drip(p, maxf(2.0, floorf(s.x * 0.3 / 2.0) * 2.0), float(b["drip"]) * kk, dark, col, lit)
		# ⑤ 어두운 외곽 → 본체 → 젖은 하이라이트. 본체는 겹친 덩이 세 개라 실루엣이 네모로 읽히지 않는다
		var shapes := _shapes(b, p, s)
		for r in shapes:
			draw_rect(r.grow(2.0), dark)
		for r in shapes:
			draw_rect(r, col)
		if s.x >= 8.0 and s.y >= 6.0:
			# 좁고 밝은 점 — 젖은 표면의 정반사. 크게 칠하면 다시 평평해지므로 2~4px 로 묶는다
			var hw := clampf(floorf(s.x * 0.22 / 2.0) * 2.0, 2.0, 4.0)
			var hh := clampf(floorf(s.y * 0.22 / 2.0) * 2.0, 2.0, 4.0)
			draw_rect(Rect2(p.x - s.x * 0.28, p.y - s.y * 0.30, hw, hh), lit)


## ⑤ 한 덩어리를 이루는 겹친 덩이 세 개 (본체 · 세로로 긴 심 · 한쪽에 붙은 곁덩이).
## 바닥 웅덩이(flat)는 반대로 가로로 퍼진 덩이를 쓴다 — ③ 면 방향.
func _shapes(b: Dictionary, p: Vector2, s: Vector2) -> Array:
	var ar: float = float(b["ar"])
	var lobe: Vector2 = b["lobe"]
	var core := Vector2(s.x * ar, s.y * 1.28) if not b["flat"] else Vector2(s.x * 1.26, s.y * ar)
	core = (core / 2.0).ceil() * 2.0
	var side := ((s * 0.56) / 2.0).ceil() * 2.0
	var off := (Vector2(lobe.x * s.x, lobe.y * s.y) / 2.0).round() * 2.0
	return [
		Rect2(p - s * 0.5, s),
		Rect2(p - core * 0.5, core),
		Rect2(p + off - side * 0.5, side),
	]


## 흘러내린 줄기 + 끝에 맺힌 방울 (3톤)
func _draw_drip(p: Vector2, w: float, h: float, dark: Color, col: Color, lit: Color) -> void:
	if h <= 0.0:
		return
	var narrow := maxf(2.0, w - 2.0)
	var top := h * 0.55
	draw_rect(Rect2(p.x - w * 0.5 - 2.0, p.y, w + 4.0, h), dark)
	draw_rect(Rect2(p.x - w * 0.5, p.y, w, top), col)                       # 위쪽은 굵고
	draw_rect(Rect2(p.x - narrow * 0.5, p.y + top, narrow, h - top), col)   # 아래로 갈수록 가늘어진다
	# 젖은 심은 줄기 맨 위 짧게만 — 전체를 칠하면 초록 막대로 읽힌다
	var wet := Color(lit.r, lit.g, lit.b, lit.a * 0.45)
	draw_rect(Rect2(p.x - w * 0.5, p.y, 2.0, minf(top, 8.0)), wet)
	draw_rect(Rect2(p.x - w - 2.0, p.y + h - 2.0, w * 2.0 + 4.0, 5.0), dark)
	draw_rect(Rect2(p.x - w, p.y + h - 2.0, w * 2.0, 3.0), col)             # 끝에 맺힌 방울
