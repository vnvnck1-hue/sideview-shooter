class_name PowerRelayProp
extends Node2D
## 명시적 파츠 분해가 가능한 Power Relay 캐비닛.
## 초기에는 assembled 스프라이트 하나로 읽히고, 부위별 충격 누적 시
## 해당 도어/코어/캡/베이스를 숨긴 뒤 같은 파츠 텍스처를 RigidBody2D로 분리한다.

const ROOT := "res://assets/power_relay_room/"
const DAMAGE_TO_DETACH := 0.85
const IMPACT_DAMAGE := 0.42
const CABINET_SIZE := Vector2(368.0, 320.0)

var floor_y := 992.0
var rect := Rect2(-CABINET_SIZE.x * 0.5, -CABINET_SIZE.y, CABINET_SIZE.x, CABINET_SIZE.y)
var _assembled: Sprite2D
var _parts_layer: Node2D
var _part_sprites: Dictionary = {}
var _damage: Dictionary = {}
var _detached: Dictionary = {}
var _parts: Array[Dictionary] = [
	{"id": "left_door", "file": "Destruction/power_relay_cabinet_left_door.png", "offset": Vector2(-104, -180), "size": Vector2(144, 224)},
	{"id": "right_door", "file": "Destruction/power_relay_cabinet_right_door.png", "offset": Vector2(104, -180), "size": Vector2(144, 224)},
	{"id": "inner_core", "file": "Destruction/power_relay_cabinet_inner_core.png", "offset": Vector2(0, -180), "size": Vector2(144, 224)},
	{"id": "top_cap", "file": "Destruction/power_relay_cabinet_top_cap.png", "offset": Vector2(0, -310), "size": Vector2(256, 80)},
	{"id": "lower_base", "file": "Destruction/power_relay_cabinet_lower_base.png", "offset": Vector2(0, -42), "size": Vector2(256, 80)},
	{"id": "hinge_a", "file": "Destruction/power_relay_cabinet_hinge_a.png", "offset": Vector2(-166, -170), "size": Vector2(64, 64)},
	{"id": "hinge_b", "file": "Destruction/power_relay_cabinet_hinge_b.png", "offset": Vector2(166, -170), "size": Vector2(64, 64)},
	{"id": "cable_chunk_a", "file": "Destruction/power_relay_cabinet_cable_chunk_a.png", "offset": Vector2(-58, -65), "size": Vector2(96, 64)},
	{"id": "cable_chunk_b", "file": "Destruction/power_relay_cabinet_cable_chunk_b.png", "offset": Vector2(58, -65), "size": Vector2(96, 64)},
	{"id": "debris_a", "file": "Destruction/power_relay_cabinet_debris_a.png", "offset": Vector2(-108, -95), "size": Vector2(64, 64)},
	{"id": "debris_b", "file": "Destruction/power_relay_cabinet_debris_b.png", "offset": Vector2(-36, -72), "size": Vector2(64, 64)},
	{"id": "debris_c", "file": "Destruction/power_relay_cabinet_debris_c.png", "offset": Vector2(48, -82), "size": Vector2(64, 64)},
	{"id": "debris_d", "file": "Destruction/power_relay_cabinet_debris_d.png", "offset": Vector2(114, -104), "size": Vector2(64, 64)},
]


func setup(center_x: float, floor_line: float) -> void:
	floor_y = floor_line
	position = Vector2(center_x, floor_y)
	name = "PowerRelayCabinet"

	_assembled = Sprite2D.new()
	_assembled.texture = Lighting.textured(ROOT + "Props/power_relay_cabinet_assembled.png")
	_assembled.centered = true
	_assembled.position = Vector2(0, -_assembled.texture.get_height() * 0.5)
	_assembled.material = Lighting.shader_material("prop_surface")
	add_child(_assembled)

	_parts_layer = Node2D.new()
	_parts_layer.name = "DetachableParts"
	_parts_layer.visible = false
	add_child(_parts_layer)
	for spec in _parts:
		var id: String = spec["id"]
		_damage[id] = 0.0
		_detached[id] = false
		var s := Sprite2D.new()
		s.texture = Lighting.textured(ROOT + String(spec["file"]))
		s.centered = true
		s.position = spec["offset"]
		s.material = Lighting.shader_material("prop_surface")
		s.visible = false
		_parts_layer.add_child(s)
		_part_sprites[id] = s


func is_solid_at(point: Vector2) -> bool:
	var local := to_local(point)
	if _assembled.visible:
		return rect.has_point(local)
	for spec in _parts:
		var id: String = spec["id"]
		if _detached[id]:
			continue
		var size: Vector2 = spec["size"]
		if Rect2(Vector2(spec["offset"]) - size * 0.5, size).has_point(local):
			return true
	return false


func hit(dir: float, hit_y: float, hit_point: Vector2 = Vector2.INF) -> void:
	var local := to_local(hit_point) if hit_point.is_finite() else Vector2(0, -160)
	var id := _part_for_hit(local)
	if id.is_empty():
		id = "inner_core"
	_damage[id] = float(_damage[id]) + IMPACT_DAMAGE
	if _assembled.visible and float(_damage[id]) < DAMAGE_TO_DETACH:
		# 충격이 누적되는 동안 전체 캐비닛만 살짝 흔들어 분리 전에도 반응한다.
		var kick := create_tween()
		kick.tween_property(_assembled, "position:x", float(_assembled.position.x) + signf(dir) * 5.0, 0.035)
		kick.tween_property(_assembled, "position:x", 0.0, 0.08)
		return
	_detach(id, dir, local)


func _part_for_hit(local: Vector2) -> String:
	if local.y < -286.0:
		return "top_cap"
	if local.y > -78.0:
		return "lower_base"
	if local.x < -76.0:
		return "left_door"
	if local.x > 76.0:
		return "right_door"
	return "inner_core"


func _detach(id: String, dir: float, local_hit: Vector2) -> void:
	if not _detached.has(id) or _detached[id]:
		return
	if _assembled.visible:
		_assembled.visible = false
		_parts_layer.visible = true
		for value in _part_sprites.values():
			var part_sprite := value as Sprite2D
			if part_sprite != null:
				part_sprite.visible = true
	_detached[id] = true
	var selected_sprite: Sprite2D = _part_sprites[id] as Sprite2D
	var source: Texture2D = selected_sprite.texture
	selected_sprite.visible = false
	var part := PowerRelayPart.new()
	part.setup(source, global_position + selected_sprite.position, Vector2(signf(dir) * randf_range(140.0, 320.0), -randf_range(170.0, 340.0)), floor_y)
	get_parent().add_child(part)
	# 인접 부품에도 약한 충격을 전달해 떨어져 나가는 순서를 한 덩어리처럼 보이게 한다.
	for other in _parts:
		var other_id: String = other["id"]
		if other_id == id or _detached[other_id]:
			continue
		if Vector2(other["offset"]).distance_to(Vector2(_part_sprites[id].position)) < 170.0:
			_damage[other_id] = maxf(float(_damage[other_id]), 0.18)


func light_info() -> Dictionary:
	return {"pos": global_position + Vector2(0, -210), "color": Color(1.0, 0.48, 0.22), "radius": 230.0, "lamp": true}
