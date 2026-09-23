@tool
extends Node2D
## Reusable image-preserving service gallery pack.
## Source-derived 128px architectural cells are rendered by two TileMapLayers;
## the movable props and five active fixture/light nodes are separate assets.

const CELL := 128
const GRID := Vector2i(16, 7)
const ROOT := "res://assets/service_gallery/"
const FIXTURE_SCENE := preload("res://scenes/ServiceGalleryLightProp.tscn")

@export_range(-24.0, 24.0, 1.0) var front_shift_px := 0.0:
	set(value):
		front_shift_px = value
		if is_instance_valid(_front_root):
			_front_root.position.x = value

@export var fixtures_on := true:
	set(value):
		fixtures_on = value
		for fixture in _fixture_nodes:
			if is_instance_valid(fixture):
				fixture.light_enabled = value

var _front_root: Node2D
var _fixture_nodes: Array[Node2D] = []
var _prop_nodes: Dictionary = {}
var _repair_nodes: Dictionary = {}
var _prop_original_positions: Dictionary = {}


func _ready() -> void:
	var rear_root := Node2D.new()
	rear_root.name = "RearPlate"
	add_child(rear_root)
	_add_atlas(rear_root, ROOT + "service_gallery_rear.tres", "RearArchitecture")

	_front_root = Node2D.new()
	_front_root.name = "FrontPlate"
	_front_root.position.x = front_shift_px
	add_child(_front_root)
	_add_atlas(_front_root, ROOT + "service_gallery_front.tres", "FrontArchitecture")
	var repairs_root := Node2D.new()
	repairs_root.name = "PropRestorations"
	_front_root.add_child(repairs_root)

	var placements = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "placements.json"))
	if not placements is Array:
		push_error("ServiceGallery: invalid placements.json")
		return
	for entry in placements:
		if not entry is Dictionary:
			continue
		var texture := load(String(entry["texture"])) as Texture2D
		if texture == null:
			push_error("ServiceGallery: missing " + String(entry["texture"]))
			continue
		var p := Vector2(float(entry["position"][0]), float(entry["position"][1]))
		var parent: Node2D = rear_root if entry["type"] == "light_fixture" and entry["kind"] == "cool" else _front_root
		if entry["type"] == "light_fixture":
			var fixture := FIXTURE_SCENE.instantiate() as Node2D
			fixture.name = String(entry["id"])
			fixture.position = p
			fixture.fixture_texture = texture
			fixture.emitter_offset = Vector2(float(entry["emitter"][0]), float(entry["emitter"][1])) - p
			fixture.light_radius = float(entry["radius"])
			fixture.light_color = Color(0.70, 0.86, 1.0) if entry["kind"] == "cool" else Color(1.0, 0.82, 0.57)
			fixture.light_energy = 0.53 if entry["kind"] == "cool" else 0.84
			fixture.light_enabled = fixtures_on
			parent.add_child(fixture)
			_fixture_nodes.append(fixture)
		else:
			var repair_texture := load(String(entry["repair_texture"])) as Texture2D
			if repair_texture == null:
				push_error("ServiceGallery: missing repair " + String(entry["repair_texture"]))
				continue
			var repair := Sprite2D.new()
			repair.name = String(entry["id"]) + "_repair"
			repair.position = Vector2(float(entry["repair_position"][0]), float(entry["repair_position"][1]))
			repair.texture = repair_texture
			repair.centered = false
			repair.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			repair.visible = false
			repairs_root.add_child(repair)
			var sprite := Sprite2D.new()
			sprite.name = String(entry["id"])
			sprite.position = p
			sprite.texture = texture
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			parent.add_child(sprite)
			_prop_nodes[String(entry["id"])] = sprite
			_repair_nodes[String(entry["id"])] = repair
			_prop_original_positions[String(entry["id"])] = p


func set_prop_visible(id: String, present: bool) -> void:
	## Toggle the original prop and its source-derived restoration patch together.
	if not _prop_nodes.has(id):
		push_error("ServiceGallery: unknown prop " + id)
		return
	var sprite := _prop_nodes[id] as Sprite2D
	var repair := _repair_nodes[id] as Sprite2D
	sprite.visible = present
	repair.visible = not present


func move_prop(id: String, new_position: Vector2) -> void:
	## Positions are local to FrontPlate; uncover the old spot if the prop moves.
	if not _prop_nodes.has(id):
		push_error("ServiceGallery: unknown prop " + id)
		return
	var sprite := _prop_nodes[id] as Sprite2D
	var repair := _repair_nodes[id] as Sprite2D
	sprite.position = new_position
	repair.visible = not new_position.is_equal_approx(_prop_original_positions[id])
	sprite.visible = true


func reset_prop(id: String) -> void:
	if _prop_original_positions.has(id):
		move_prop(id, _prop_original_positions[id])


func _add_atlas(parent: Node2D, path: String, label: String) -> void:
	var tileset: TileSet = load(path) as TileSet if ResourceLoader.exists(path) else null
	if tileset == null:
		# Keep the scene usable before the optional ResourceSaver step has run.
		# The saved .tres is preferred once produced by the project tool.
		var atlas_path := ROOT + ("rear_atlas_128.png" if label == "RearArchitecture" else "front_atlas_128.png")
		var atlas_texture := load(atlas_path) as Texture2D
		if atlas_texture == null:
			push_error("ServiceGallery: missing atlas " + atlas_path)
			return
		tileset = TileSet.new()
		tileset.tile_size = Vector2i(CELL, CELL)
		var atlas := TileSetAtlasSource.new()
		atlas.texture = atlas_texture
		atlas.texture_region_size = Vector2i(CELL, CELL)
		for atlas_y in range(GRID.y):
			for atlas_x in range(GRID.x):
				atlas.create_tile(Vector2i(atlas_x, atlas_y))
		tileset.add_source(atlas, 0)
	var layer := TileMapLayer.new()
	layer.name = label
	layer.tile_set = tileset
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# map_to_local(0,0) is already the tile center (64,64); an unshifted
	# TileMapLayer therefore aligns the atlas's first pixel to source (0,0).
	for y in range(GRID.y):
		for x in range(GRID.x):
			layer.set_cell(Vector2i(x, y), 0, Vector2i(x, y))
	parent.add_child(layer)
