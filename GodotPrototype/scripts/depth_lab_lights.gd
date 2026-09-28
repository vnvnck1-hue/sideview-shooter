class_name DepthLabLights
extends Node2D
## 공간감 테스트 씬의 조명 — **한 광원이 깊이마다 다르게** 닿게 한다.
##
## 1. 구역 광원: 광원 하나를 레이어 역할마다 PointLight2D 한 개씩으로 쪼갠다. 각 조각은 그 역할의 z 만 비추고
##    (range_z_min = max = 역할 z), 그 구역 레이어만 받는다(range_item_cull_mask = 구역 비트).
##    비율(ratio)이 역할마다 달라서, 예) 격납고 투광등은 땅 1.0 · 뒤벽 0.6 · 원경1 0.25 · 근경 0.35 로 닿는다.
##    같은 월드 위치에 서 있으므로 화면에서 광원 **바로 뒤의 먼 면**과 **바로 앞의 근경**이 함께 물든다.
## 2. 움직이는 광원(총구 화염·탄착·센트리건 섬광 — Lighting.dynamic_lights): 원본은 땅~인물 층만 비추게 줄이고,
##    깊이 거울(_Mirror)을 붙여 뒤벽·원경·근경에 약하고 넓게 번지게 한다. 쏘면 가까운 층부터 번쩍인다.
## 3. 인물 밝기: 방 CanvasModulate 는 흰색으로 두고(레이어 명도가 곧 최종 명도), 인물·몬스터·센트리건·기체는
##    구역 기본 밝기 + 가까운 광원으로 계산한 값을 self_modulate 로 받는다 — 어두운 덕트에서는 인물도 어둡다.
##
## Godot 2D 는 캔버스 아이템 하나당 라이트 15개까지만 적용한다(Lighting 주석). 레이어는 구역마다 따로 잘려 있고
## 멀리 있는 광원은 끈다(ACTIVE_RANGE) — 한 레이어가 동시에 받는 수는 구역 광원 몇 개 + 전투 광원이다.

const D := preload("res://scripts/depth_lab_data.gd")
const ALL_ZONES := 0xFFFE           # 구역 비트 전체 (비트 1..15). 비트 0 은 본편 아이템 기본값

## 움직이는 광원이 각 층에 닿는 비율 · 반경 배율
const DYN_SPLIT := {
	"back": [0.50, 1.25], "far1": [0.22, 1.6], "far2": [0.08, 2.2], "far3": [0.03, 2.8],
	"fg1": [0.45, 1.15], "fg2": [0.30, 1.1],
}
const ACTIVE_RANGE := 3400.0        # 카메라에서 이 거리 밖 구역 광원은 끈다

var camera: Camera2D
var zone_lights: Array = []         # {pos, radius, energy, zone, parts: [PointLight2D], flicker: Callable, actor: float}
var enabled_flat := false           # 명도만 보기 — 구역 광원을 끈다
var tint := false


static func zone_bit(i: int) -> int:
	return 1 << (i + 1)


## 구역 광원 하나. ratios = {역할: 비율}. actor = 인물 밝기에 더하는 비율
func add_light(zone: int, pos: Vector2, radius: float, energy: float, ratios: Dictionary, color := Color.WHITE,
		actor := 0.35, flicker := Callable()) -> Dictionary:
	var entry := {"pos": pos, "radius": radius, "energy": energy, "zone": zone, "parts": [], "ratios": ratios,
		"color": color, "flicker": flicker, "actor": actor}
	for role in ratios:
		var l := PointLight2D.new()
		l.name = "L_%s" % role
		l.texture = Lighting.radial_texture()
		var rs := 1.0 + (1.0 - D.factor(D.SPEED_DEFAULT, role)) * 0.4 if role != "ground" else 1.0
		l.texture_scale = Lighting.scale_for_radius(radius * rs)
		l.position = pos
		l.color = color
		l.energy = energy * float(ratios[role])
		l.set_meta("base_energy", l.energy)
		var z := int(D.ROLES[role]["z"])
		l.range_z_min = z
		l.range_z_max = z
		l.range_item_cull_mask = zone_bit(zone)
		l.shadow_enabled = false
		l.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(l)
		entry["parts"].append(l)
	zone_lights.append(entry)
	return entry


func clear_zone_lights() -> void:
	for e in zone_lights:
		for l in e["parts"]:
			l.queue_free()
	zone_lights.clear()


func _process(_delta: float) -> void:
	var c := camera.get_screen_center_position() if camera else Vector2.ZERO
	for e in zone_lights:
		var on := not enabled_flat and absf(float(e["pos"].x) - c.x) < ACTIVE_RANGE + float(e["radius"])
		var k := 1.0
		if on and e["flicker"].is_valid():
			k = float(e["flicker"].call())
		for l in e["parts"]:
			l.enabled = on
			if on:
				l.energy = float(l.get_meta("base_energy")) * k
	_mirror_dynamic()


## 움직이는 광원에 깊이 거울을 붙인다 (한 번만)
func _mirror_dynamic() -> void:
	for l in Lighting.dynamic_lights():
		if l.has_meta("depth_split"):
			continue
		l.set_meta("depth_split", true)
		l.range_item_cull_mask = l.range_item_cull_mask | ALL_ZONES
		l.range_z_min = int(D.ROLES["ground"]["z"])
		l.range_z_max = int(D.ROLES["ground"]["z"]) + 40      # 땅 · 방 노드 · 인물 · 탄 (근경 z12 아래)
		for role in DYN_SPLIT:
			var m := _Mirror.new()
			m.setup(l, role, float(DYN_SPLIT[role][0]), float(DYN_SPLIT[role][1]))
			l.add_child(m)


## 인물이 받는 밝기 (0.3 ~ 1.3). 구역 기본 밝기 + 구역 광원 (거리 감쇠)
func actor_light(pos: Vector2, floor_y: float) -> float:
	var v := D.zone_value(pos.x, "ambient")
	var zi := D.zone_index(pos.x)
	if D.ZONES[zi]["id"] == "shaft":
		v += 0.28 * clampf((floor_y - pos.y) / 2200.0, 0.0, 1.0)     # 샤프트는 올라갈수록 채광이 닿는다
	for e in zone_lights:
		var d := (e["pos"] as Vector2).distance_to(pos)
		var r := float(e["radius"])
		if d >= r:
			continue
		var fall := 1.0 - d / r
		var k := 1.0
		if e["flicker"].is_valid():
			k = float(e["flicker"].call())
		v += float(e["energy"]) * float(e["actor"]) * fall * fall * k
	return clampf(v, 0.3, 1.3)


class _Mirror extends PointLight2D:
	var _src: PointLight2D
	var _ratio := 1.0

	func setup(src: PointLight2D, role: String, ratio: float, scale_mul: float) -> void:
		_src = src
		_ratio = ratio
		name = "Depth_" + role
		texture = src.texture
		texture_scale = src.texture_scale * scale_mul
		height = src.height
		blend_mode = src.blend_mode
		shadow_enabled = false
		var z := int(D.ROLES[role]["z"])
		range_z_min = z
		range_z_max = z
		range_item_cull_mask = DepthLabLights.ALL_ZONES
		_sync()

	func _process(_delta: float) -> void:
		_sync()

	func _sync() -> void:
		if _src == null:
			return
		energy = _src.energy * _ratio
		enabled = _src.enabled
		color = _src.color
		visible = _src.visible
