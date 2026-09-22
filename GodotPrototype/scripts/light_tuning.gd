class_name LightTuning
extends RefCounted
## 게임 안 모든 2D 광원의 수치를 한곳에 모아 **조명 랩에서 고치고 저장**한다 (2026-09-22).
##
## 지금까지 반경·세기·높이는 광원 스크립트마다 상수로 박혀 있어서, 하나 바꾸려면 파일을 열고 숫자를 고친 뒤
## 게임을 다시 띄워야 했다. 여기로 모으면 실제 플레이 화면에서 조명을 고르고 슬라이더로 움직여 보고
## 그 값을 그대로 본편에 저장할 수 있다.
##
## 저장 파일 `res://lighting/tuning.json` 은 게임이 시작할 때 읽는다 (앰비언스·그림자 랩과 같은 규약).
## **파일이 없으면 아래 기본값 = 지금까지 코드에 박혀 있던 값 그대로**라, 저장하기 전까지 게임은 이전과 똑같다.
##
## 고치는 곳: 로비 → "조명·면 랩" (scripts/face_lab.gd). 저장은 패널의 [저장] 버튼.
##
## ## 값의 종류
## `abs` 인 값은 그 자리에 그대로 들어가는 절대값이고, `mul` 인 값은 **배율**이다 (1.0 이 지금 그대로).
## 방 데이터나 역할이 값을 정하는 것(벽등 반경, 단말기 화면등, 불 세기)은 배율로 둔다 — 절대값으로 덮으면
## 방마다 다르게 잡아 둔 연출이 통째로 뭉개진다.

const PATH := "res://lighting/tuning.json"

## 종류 목록. radius / energy / height 기본값은 **각 스크립트에 박혀 있던 상수 그대로**.
## mul: 배율로 다루는 항목. keys: 패널에 띄울 항목 (없는 항목은 그 광원에 의미가 없다는 뜻).
const KINDS := [
	{"id": "ambient", "name": "앰비언트 (방 전체 바닥 밝기)", "group": "static",
		"energy": 1.0, "keys": ["energy"], "mul": ["energy"],
		"hint": "Lighting.AMBIENT(0.42,0.43,0.55)에 곱한다. 올리면 면 대비가 묻히고 내리면 조명이 도드라진다"},
	{"id": "lamp", "name": "천장 램프 (깨지는 것)", "group": "static",
		"radius": 560.0, "energy": 1.0, "height": 140.0, "keys": ["radius", "energy", "height"], "mul": [],
		"hint": "방의 주 광원. height 가 0 이면 노멀이 반응하지 않는다"},
	{"id": "lamp_pool", "name": "램프 바닥 풀", "group": "static",
		"radius": 400.0, "energy": 0.35, "height": 90.0, "keys": ["radius", "energy", "height"], "mul": ["energy"],
		"hint": "램프 바로 아래 바닥에 고이는 빛. 세기는 램프 대비 비율이다"},
	{"id": "fixture", "name": "벽등·장식 조명", "group": "static",
		"radius": 1.0, "energy": 1.0, "height": 140.0, "keys": ["radius", "energy", "height"], "mul": ["radius"],
		"hint": "반경은 방 데이터(RoomData fixtures.radius)에 곱하는 배율"},
	{"id": "terminal", "name": "단말기 화면등", "group": "static",
		"radius": 1.0, "energy": 1.0, "height": 140.0, "keys": ["radius", "energy", "height"], "mul": ["radius", "energy"],
		"hint": "반경·세기는 단말기 역할(TerminalData)에 곱하는 배율"},
	{"id": "beacon_beam", "name": "비상등 회전 빔", "group": "static",
		"radius": 720.0, "energy": 1.7, "height": 110.0, "keys": ["radius", "energy", "height"], "mul": [],
		"hint": "원형이 아니라 빔 텍스처다"},
	{"id": "beacon_glow", "name": "비상등 글로우", "group": "static",
		"radius": 260.0, "energy": 0.55, "height": 60.0, "keys": ["radius", "energy", "height"], "mul": []},
	{"id": "fire", "name": "불 (주 라이트)", "group": "static",
		"radius": 950.0, "energy": 1.0, "height": 130.0, "keys": ["radius", "energy", "height"], "mul": ["energy"],
		"hint": "세기는 불 종류별 energy_base(1.5~2.0)에 곱하는 배율. 노이즈로 계속 흔들린다"},
	{"id": "fire_core", "name": "불 심 라이트", "group": "static",
		"radius": 320.0, "energy": 1.6, "height": 70.0, "keys": ["radius", "energy", "height"], "mul": []},
	{"id": "wire", "name": "끊어진 전선 아크", "group": "static",
		"radius": 260.0, "energy": 2.4, "height": 80.0, "keys": ["radius", "energy", "height"], "mul": [],
		"hint": "터질 때만 켜진다"},
	# ── 총 계열: 쏠 때만 잠깐 켜지므로 화면에서 클릭할 수 없다. 랩에서는 단축키로 고른다.
	{"id": "muzzle", "name": "총구 화염", "group": "gun",
		"radius": 420.0, "energy": 2.6, "height": 90.0, "keys": ["radius", "energy", "height"], "mul": [],
		"hint": "MuzzleBlast. 반경은 화염 크기(size)에 곱해진다"},
	{"id": "muzzle_hold", "name": "총구 상시등 (플레이어)", "group": "gun",
		"radius": 563.0, "energy": 1.8, "height": 90.0, "keys": ["radius", "energy", "height"], "mul": [],
		"hint": "발사 순간 켜지는 플레이어 총구 라이트"},
	{"id": "impact", "name": "탄착 섬광", "group": "gun",
		"radius": 260.0, "energy": 2.2, "height": 90.0, "keys": ["radius", "energy", "height"], "mul": [],
		"hint": "탄 위력(power)에 따라 반경·세기가 더 조절된다"},
	{"id": "spark", "name": "불꽃 스파크", "group": "gun",
		"radius": 240.0, "energy": 1.0, "height": 90.0, "keys": ["radius", "energy", "height"], "mul": ["energy"],
		"hint": "세기는 호출한 쪽이 정한 값에 곱하는 배율"},
]

## 편집 범위 (슬라이더 양 끝). 배율 항목은 0~3 배.
const RANGE := {"radius": [40.0, 2000.0], "energy": [0.0, 6.0], "height": [0.0, 400.0]}
const RANGE_MUL := [0.0, 3.0]

static var _values := {}             # id → {radius, energy, height}
static var _meta := {}               # id → KINDS 항목
static var _nodes: Array = []        # [{"ref": WeakRef, "id": String}] — 지금 방에 살아 있는 광원
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for k in KINDS:
		_meta[k["id"]] = k
		var v := {}
		for key in k["keys"]:
			v[key] = float(k[key])
		_values[k["id"]] = v
	var abs_path := ProjectSettings.globalize_path(PATH)
	if not FileAccess.file_exists(abs_path):
		return
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	for id in parsed:
		if not _values.has(id) or not (parsed[id] is Dictionary):
			continue
		for key in parsed[id]:
			if _values[id].has(key):
				_values[id][key] = float(parsed[id][key])


static func ids() -> Array:
	_load()
	var out := []
	for k in KINDS:
		out.append(k["id"])
	return out


static func meta(id: String) -> Dictionary:
	_load()
	return _meta.get(id, {})


## 이 종류의 현재 값. 없는 항목을 물으면 0 이 아니라 기본값이 나오도록 KINDS 를 되짚는다.
static func of(id: String) -> Dictionary:
	_load()
	return _values.get(id, {})


static func value(id: String, key: String, fallback := 0.0) -> float:
	_load()
	var v: Dictionary = _values.get(id, {})
	return float(v[key]) if v.has(key) else fallback


static func default_of(id: String, key: String) -> float:
	_load()
	var m: Dictionary = _meta.get(id, {})
	return float(m[key]) if m.has(key) else 0.0


static func is_mul(id: String, key: String) -> bool:
	_load()
	var m: Dictionary = _meta.get(id, {})
	return m.has("mul") and (key in m["mul"])


static func range_of(id: String, key: String) -> Array:
	return RANGE_MUL if is_mul(id, key) else RANGE.get(key, [0.0, 1.0])


static func set_value(id: String, key: String, v: float) -> void:
	_load()
	if _values.has(id) and _values[id].has(key):
		_values[id][key] = v


static func reset(id: String) -> void:
	_load()
	if not _values.has(id):
		return
	for key in _values[id]:
		_values[id][key] = default_of(id, key)


# ----------------------------------------------------------------------------- 살아 있는 광원

## 방이 만들어질 때 각 광원이 자기를 등록한다. 랩이 목록을 띄우고 값을 바로 반영하는 근거.
static func register(node: Node, id: String) -> void:
	_nodes = _nodes.filter(func(e): return is_instance_valid(e["ref"].get_ref()))
	_nodes.append({"ref": weakref(node), "id": id})


## 지금 방에 살아 있는 광원들 — [{"node", "id"}]
static func live() -> Array:
	_nodes = _nodes.filter(func(e): return is_instance_valid(e["ref"].get_ref()))
	var out := []
	for e in _nodes:
		out.append({"node": e["ref"].get_ref(), "id": e["id"]})
	return out


## 지금 값을 살아 있는 광원 전부에 다시 먹인다. 광원이 apply_tuning() 을 들고 있으면 그것을 부르고
## (깜빡임·파괴 같은 제 상태를 지켜야 하므로), 없으면 일반 PointLight2D 로 다룬다.
static func apply_all() -> void:
	for e in live():
		var n: Node = e["node"]
		if n.has_method("apply_tuning"):
			n.call("apply_tuning")
		elif n is PointLight2D:
			apply_plain(n as PointLight2D, e["id"])


## 애니메이션 없는 단순 광원용 — 벽등처럼 만들어 두고 그대로 켜져 있는 것.
## base_radius 를 주면 반경 배율이 거기에 곱해진다 (방 데이터가 반경을 정하는 경우).
static func apply_plain(light: PointLight2D, id: String, base_radius := -1.0) -> void:
	var v := of(id)
	if v.has("radius"):
		var r: float = v["radius"] * base_radius if (is_mul(id, "radius") and base_radius > 0.0) else v["radius"]
		if r > 0.0:
			light.texture_scale = Lighting.scale_for_radius(r)
	if v.has("energy"):
		light.energy = v["energy"]
	if v.has("height"):
		light.height = v["height"]


# ----------------------------------------------------------------------------- 저장

static func save() -> bool:
	_load()
	var abs_path := ProjectSettings.globalize_path(PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(_values, "\t"))
	return true


## 기본값과 다른 항목만 사람이 읽을 수 있게 (랩이 콘솔에 찍는다)
static func changes() -> Array:
	_load()
	var out := []
	for k in KINDS:
		for key in k["keys"]:
			var cur: float = value(k["id"], key)
			var def: float = default_of(k["id"], key)
			if absf(cur - def) > 0.0005:
				out.append("%s.%s  %.3f → %.3f" % [k["id"], key, def, cur])
	return out
