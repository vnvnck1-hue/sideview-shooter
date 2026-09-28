class_name WeaponLightPool
extends Node2D
## Four total combat lights per room. A volley shares a traveling light; no
## per-pellet light explosion that would exceed Godot's per-item light limit.
const LIMIT := 4
var slots: Array = []
var enabled := true
static func get_pool(host: Node) -> WeaponLightPool:
	var p := host.get_node_or_null("WeaponLights") as WeaponLightPool
	if p == null:
		p = WeaponLightPool.new()
		p.name = "WeaponLights"
		host.add_child(p)
	return p
func _ready() -> void:
	for i in range(LIMIT):
		var light := PointLight2D.new()
		light.texture = Lighting.radial_texture()
		light.height = 110.0
		light.range_z_min = -100
		light.range_z_max = 20
		light.enabled = false
		add_child(light)
		Lighting.split_by_depth(light, 0.28)
		Lighting.register_dynamic(light, 0.5, "shot")
		slots.append({"light": light, "key": -1, "left": 0.0, "life": 0.1, "energy": 0.0})
func pulse(key: int, point: Vector2, color: Color, radius: float, energy: float, life := 0.12) -> void:
	var index := -1
	var remaining := INF
	for i in range(slots.size()):
		if slots[i].key == key:
			index = i
			break
		if slots[i].left < remaining:
			remaining = slots[i].left
			index = i
	var s: Dictionary = slots[index]
	s.key = key
	s.left = life
	s.life = life
	s.energy = energy
	var light: PointLight2D = s.light
	light.global_position = point
	light.color = color
	light.texture_scale = Lighting.scale_for_radius(radius)
	for child in light.get_children():
		if child is PointLight2D:
			child.texture_scale = light.texture_scale
	light.energy = energy
	light.enabled = enabled
func _process(delta: float) -> void:
	for s in slots:
		s.left = maxf(0.0, s.left - delta)
		var l: PointLight2D = s.light
		l.energy = s.energy * sqrt(s.left / s.life)
		l.enabled = enabled and s.left > 0.0

