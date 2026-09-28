class_name CreatureImpactFx
extends Node2D
## Short, stepped accents. Uses the actual body for ghosts, source-bone atlas for debris.
const FRAGMENTS: Texture2D = preload("res://assets/effects/creature_fragments.png")
var age := 0.0
var lifetime := 0.14
var kind := "strike"
var direction := Vector2.RIGHT
var radius := 60.0
var ghost: Sprite2D

static func accent(parent: Node, at: Vector2, axis: Vector2, style := "strike", reach := 60.0) -> CreatureImpactFx:
	var fx := CreatureImpactFx.new()
	fx.kind = style
	fx.direction = axis.normalized()
	fx.radius = reach
	fx.position = at
	fx.z_index = 1
	parent.add_child(fx)
	return fx

static func afterimage(parent: Node, body: Sprite2D) -> CreatureImpactFx:
	var fx := CreatureImpactFx.new()
	fx.kind = "ghost"
	fx.lifetime = 0.10
	fx.z_index = -1
	parent.add_child(fx)
	fx.ghost = Sprite2D.new()
	fx.ghost.texture = body.texture
	fx.ghost.centered = false
	fx.ghost.offset = body.offset
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fx.ghost.material = mat
	fx.add_child(fx.ghost)
	fx.ghost.global_transform = body.global_transform
	return fx

static func fragments(parent: Node, at: Vector2, floor_line: float, row: int, power := 1.0) -> void:
	for i in range(8):
		var chunk := ChunkDebris.new()
		chunk.setup(FRAGMENTS, Rect2((i % 4) * 64, row * 64, 64, 64), at,
			Vector2(randf_range(-360, 360), randf_range(-550, -220)) * sqrt(power), floor_line)
		chunk.scale = Vector2.ONE * randf_range(0.45, 0.8)
		parent.add_child(chunk)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	if ghost:
		ghost.modulate = Color(0.75, 0.68, 0.45, 0.22 * (1.0 - age / lifetime))
	queue_redraw()

func _draw() -> void:
	if kind == "ghost":
		return
	var step := floorf(age / lifetime * 3.0)
	var alpha := 1.0 - step / 3.0
	var tangent := direction.orthogonal()
	if kind == "charge":
		for side in [-1.0, 1.0]:
			var p: Vector2 = tangent * side * (radius + step * 6.0)
			draw_line(p, p - direction * 20.0, Color(0.78, 0.76, 0.30, alpha), 4.0)
	else:
		for i in range(3):
			var spread := float(i - 1) * 12.0
			var start := tangent * spread - direction * radius * (0.65 + 0.15 * step)
			var end := direction * radius * 0.35 + tangent * spread * 0.15
			draw_line(start, end, Color(0.96, 0.85, 0.55, alpha * 0.65), 8.0 - step * 2.0)
		if step == 0:
			draw_line(-tangent * 18.0, tangent * 18.0, Color(1.0, 0.97, 0.78), 4.0)
