extends Node2D
## Demonstrates the 128 px coolant-room tile atlas and movable prop sprites.

const ROOT := "res://assets/coolant_pump_room/"
const CELL := Vector2i(128, 128)

@export_range(1, 16, 1) var repeat_pairs: int = 8
@export var show_demo_props: bool = true

var _props: Dictionary = {}


func _ready() -> void:
	_build_background()
	if show_demo_props:
		_build_demo_props()


func _build_background() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = CELL
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(ROOT + "Background/background_repeat_2x6_128.png")
	atlas.texture_region_size = CELL
	for row in range(6):
		for column in range(2):
			atlas.create_tile(Vector2i(column, row))
	tile_set.add_source(atlas, 0)

	var wall_fill := TileSetAtlasSource.new()
	wall_fill.texture = load(ROOT + "Background/wall_fill_repeat_128.png")
	wall_fill.texture_region_size = CELL
	wall_fill.create_tile(Vector2i.ZERO)
	tile_set.add_source(wall_fill, 1)

	var layer := TileMapLayer.new()
	layer.name = "BackgroundTiles"
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(layer)
	for column in range(repeat_pairs * 2):
		for row in range(6):
			layer.set_cell(Vector2i(column, row), 0, Vector2i(column % 2, row))


func _build_demo_props() -> void:
	add_prop("door", Vector2(232, 596), 1)
	add_prop("tank", Vector2(1617, 596), 1)
	add_prop("valve_manifold", Vector2(1482, 565), 2)
	add_prop("pump", Vector2(862, 606), 2)
	add_prop("console", Vector2(1789, 612), 3)
	add_prop("ceiling_lamp", Vector2(597, 137), 2, true)
	add_prop("ceiling_lamp_right", Vector2(1447, 137), 2, true)


func add_prop(id: String, anchor: Vector2, depth: int = 2, top_anchor: bool = false) -> Sprite2D:
	var file_name := "ceiling_lamp" if id.begins_with("ceiling_lamp") else id
	var texture: Texture2D = load(ROOT + "Props/" + file_name + ".png")
	var sprite := Sprite2D.new()
	sprite.name = id
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = Vector2(-texture.get_width() / 2.0, 0.0 if top_anchor else -texture.get_height())
	sprite.position = anchor
	sprite.z_index = depth
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_props[id] = sprite
	return sprite


func move_prop(id: String, anchor: Vector2) -> void:
	if _props.has(id):
		(_props[id] as Sprite2D).position = anchor


func set_prop_visible(id: String, is_visible: bool) -> void:
	if _props.has(id):
		(_props[id] as Sprite2D).visible = is_visible
