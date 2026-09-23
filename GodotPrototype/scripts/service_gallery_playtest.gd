extends RefCounted
## Data and visual assembly for the gallery test room inside the existing Main scene.

const ROOM_ID := "service_gallery_playtest"
const PACK := preload("res://scenes/ServiceGalleryPack.tscn")
const REPEAT := preload("res://assets/service_gallery/service_gallery_repeat.tres")
const CELL := 128
const SOURCE_WIDTH := 1978
const ROOM_COLUMNS := 20
const EXTENSION_COLUMNS := 5
# The source image puts the walkable floor at about y=661. The game floor is 486.
const ART_OFFSET := Vector2(0, -175)


static func register_room() -> void:
	RoomData.register_extra(ROOM_ID, {
		"title": "서비스 갤러리 타일 플레이 테스트",
		"zone": RoomData.ZONE_WORKSHOP,
		"theme": "workshop",
		"visual_pack": "service_gallery",
		"shape": [[ROOM_COLUMNS, 5]],
		"left_door": {"open": false},
		"right_door": {"open": false},
		"front_doors": [],
		"props": [],
		"lamps": [],
		"fixtures": [],
		"fx": [],
		"monsters": [
			{"type": "crawler", "x": 600, "facing": 1},
			{"type": "crawler", "x": 2180, "facing": -1},
		],
		"spawn": {"max": 3, "interval": [7.0, 10.0]},
	})


static func decorate(room: Node2D) -> void:
	# Keep the regular RoomTiles for hit testing and RoomSolid for movement,
	# but draw the source-preserving art tiles instead of the workshop theme.
	room.get_node("Tiles/RoomTiles").visible = false
	room.get_node("Foreground").visible = false
	room.get_node("WallShadow").visible = false
	var ambient := room.get_node("Ambient") as CanvasModulate
	ambient.color = Color.WHITE
	var tiles := room.get_node("Tiles") as Node2D
	var pack := PACK.instantiate() as Node2D
	pack.name = "SourceGalleryTiles"
	pack.position = ART_OFFSET
	tiles.add_child(pack)
	_add_repeat_extension(tiles)


static func _add_repeat_extension(tiles: Node2D) -> void:
	var extension := Node2D.new()
	extension.name = "RepeatTileExtension"
	# The 16-cell source atlases are padded from 1978 to 2048 px. Start the
	# repeat strip at the actual art edge so the 70px transparent tail vanishes.
	extension.position = ART_OFFSET + Vector2(SOURCE_WIDTH, 0)
	tiles.add_child(extension)

	var rear := _tile_layer(extension, "WallCeilingFloor", REPEAT)
	var underfloor := _tile_layer(extension, "DarkUnderfloor", REPEAT)
	underfloor.modulate = Color(0.30, 0.32, 0.38)
	var front := _tile_layer(extension, "Pillars", REPEAT)
	for x in range(EXTENSION_COLUMNS):
		rear.set_cell(Vector2i(x, 0), 1, Vector2i(x % 2, 0))
		for y in range(1, 5):
			rear.set_cell(Vector2i(x, y), 0, Vector2i(x % 2, (y - 1) % 2))
		rear.set_cell(Vector2i(x, 5), 2, Vector2i(x % 2, 0))
		underfloor.set_cell(Vector2i(x, 6), 0, Vector2i(x % 2, 0))
	for x in [0, EXTENSION_COLUMNS - 1]:
		for y in range(1, 5):
			front.set_cell(Vector2i(x, y), 3, Vector2i.ZERO)


static func _tile_layer(parent: Node2D, label: String, tileset: TileSet) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = label
	layer.tile_set = tileset
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(layer)
	return layer
