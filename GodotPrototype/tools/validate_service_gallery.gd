extends SceneTree
## Engine-level checks for the source-preserving service gallery pack.
## godot --headless --path GodotPrototype --script res://tools/validate_service_gallery.gd

const ROOT := "res://assets/service_gallery/"
const CELL := Vector2(128, 128)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scene := load("res://scenes/ServiceGalleryPreview.tscn") as PackedScene
	if scene == null:
		push_error("Preview scene could not load")
		quit(1)
		return
	var preview := scene.instantiate()
	root.add_child(preview)
	var pack := preview.get_node("ServiceGalleryPack") as Node2D
	var rear := pack.get_node_or_null("RearPlate/RearArchitecture") as TileMapLayer
	var front := pack.get_node_or_null("FrontPlate/FrontArchitecture") as TileMapLayer
	if rear == null or front == null:
		failures.append("Missing front or rear TileMapLayer")
	else:
		for layer in [rear, front]:
			if layer.get_used_cells().size() != 112:
				failures.append("%s has %d cells instead of 112" % [layer.name, layer.get_used_cells().size()])
			if layer.tile_set == null or layer.tile_set.get_source_count() != 1:
				failures.append("%s is missing its one-source TileSet" % layer.name)
			else:
				var atlas := layer.tile_set.get_source(0) as TileSetAtlasSource
				if atlas == null or atlas.get_tiles_count() != 112:
					failures.append("%s atlas does not contain 112 source cells" % layer.name)
			var top_left: Vector2 = layer.position + layer.map_to_local(Vector2i.ZERO) - CELL / 2.0
			if top_left.distance_to(Vector2.ZERO) > 0.01:
				failures.append("%s first tile origin is %s, not (0,0)" % [layer.name, top_left])
	var expected_props := ["workbench", "motor_cart", "service_cabinet", "storage_cases"]
	for prop_name in expected_props:
		var prop := pack.get_node_or_null("FrontPlate/" + prop_name) as Sprite2D
		var repair := pack.get_node_or_null("FrontPlate/PropRestorations/" + prop_name + "_repair") as Sprite2D
		if prop == null or prop.texture == null:
			failures.append("Missing independent prop: " + prop_name)
		if repair == null or repair.texture == null or repair.visible:
			failures.append("Missing dormant repair patch: " + prop_name)
	pack.call("set_prop_visible", "motor_cart", false)
	var cart := pack.get_node("FrontPlate/motor_cart") as Sprite2D
	var cart_repair := pack.get_node("FrontPlate/PropRestorations/motor_cart_repair") as Sprite2D
	if cart.visible or not cart_repair.visible:
		failures.append("Hiding cart did not expose the background repair")
	pack.call("move_prop", "motor_cart", Vector2(1160, 478))
	if not cart.visible or not cart_repair.visible or cart.position != Vector2(1160, 478):
		failures.append("Moving cart did not reveal and restore its old place")
	pack.call("reset_prop", "motor_cart")
	if cart_repair.visible or cart.position != Vector2(1300, 478):
		failures.append("Resetting cart did not return to the original source layout")
	var fixtures := [
		["FrontPlate/wall_lantern", "warm"],
		["FrontPlate/ceiling_strip", "warm"],
		["RearPlate/blue_strip_left", "cool"],
		["RearPlate/blue_strip_mid", "cool"],
		["RearPlate/blue_strip_right", "cool"],
	]
	for item in fixtures:
		var node := pack.get_node_or_null(item[0]) as Node2D
		if node == null:
			failures.append("Missing fixture " + item[0])
			continue
		var emitter := node.get_node_or_null("EngineLight") as PointLight2D
		var picture := node.get_node_or_null("FixtureSprite") as Sprite2D
		if emitter == null or picture == null or picture.texture == null:
			failures.append("Fixture lacks picture or live PointLight2D: " + item[0])
		elif not emitter.enabled or emitter.texture == null or emitter.texture_scale <= 0.0:
			failures.append("Fixture light is not configured: " + item[0])
	pack.set("fixtures_on", false)
	for item in fixtures:
		var emitter := pack.get_node_or_null(item[0] + "/EngineLight") as PointLight2D
		if emitter != null and emitter.enabled:
			failures.append("Fixture did not switch off: " + item[0])
	pack.set("fixtures_on", true)
	pack.set("front_shift_px", 12.0)
	var front_root := pack.get_node("FrontPlate") as Node2D
	if abs(front_root.position.x - 12.0) > 0.01:
		failures.append("Front parallax shift did not apply")
	var repeat := load(ROOT + "service_gallery_repeat.tres") as TileSet
	if repeat == null or repeat.get_source_count() != 4:
		failures.append("Repeat TileSet does not have wall, ceiling, floor and pillar sources")
	if failures.is_empty():
		print("SERVICE_GALLERY_VALID: 112 rear + 112 front cells, 4 detachable props/repairs, 5 live lights, 4 repeat sources, placement/toggles OK")
		quit()
	else:
		for message in failures:
			push_error(message)
		quit(1)
