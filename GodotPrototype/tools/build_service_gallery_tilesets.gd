extends SceneTree
## Run after the PNGs have been imported:
## godot --headless --path GodotPrototype --script res://tools/build_service_gallery_tilesets.gd

const ROOT := "res://assets/service_gallery/"
const CELL := Vector2i(128, 128)


func _initialize() -> void:
	var rear := _one_sheet(ROOT + "rear_atlas_128.png", Vector2i(16, 7))
	var front := _one_sheet(ROOT + "front_atlas_128.png", Vector2i(16, 7))
	var repeat := TileSet.new()
	repeat.tile_size = CELL
	repeat.add_source(_source(ROOT + "wall_repeat_256.png", Vector2i(2, 2)), 0)
	repeat.add_source(_source(ROOT + "ceiling_repeat_256x128.png", Vector2i(2, 1)), 1)
	repeat.add_source(_source(ROOT + "floor_repeat_256x128.png", Vector2i(2, 1)), 2)
	repeat.add_source(_source(ROOT + "pillar_repeat_128.png", Vector2i(1, 1)), 3)
	var outputs := [
		[rear, ROOT + "service_gallery_rear.tres"],
		[front, ROOT + "service_gallery_front.tres"],
		[repeat, ROOT + "service_gallery_repeat.tres"],
	]
	for entry in outputs:
		var err := ResourceSaver.save(entry[0], entry[1])
		if err != OK:
			push_error("Could not save %s: %s" % [entry[1], error_string(err)])
			quit(1)
			return
		print("TILESET -> ", entry[1])
	quit()


func _one_sheet(path: String, grid: Vector2i) -> TileSet:
	var result := TileSet.new()
	result.tile_size = CELL
	result.add_source(_source(path, grid), 0)
	return result


func _source(path: String, grid: Vector2i) -> TileSetAtlasSource:
	var result := TileSetAtlasSource.new()
	result.texture = load(path)
	result.texture_region_size = CELL
	for y in range(grid.y):
		for x in range(grid.x):
			result.create_tile(Vector2i(x, y))
	return result
