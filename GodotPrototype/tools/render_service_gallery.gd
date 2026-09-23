extends SceneTree
## Render the pack for image-level comparison when a non-dummy renderer exists.

const OUTPUT_ON := "res://../Assets/Generated/ParallaxConcepts/service-gallery-tile-pack-v1/godot_lights_on.png"
const OUTPUT_OFF := "res://../Assets/Generated/ParallaxConcepts/service-gallery-tile-pack-v1/godot_lights_off.png"
const OUTPUT_CART_REMOVED := "res://../Assets/Generated/ParallaxConcepts/service-gallery-tile-pack-v1/godot_cart_removed.png"
const OUTPUT_PARALLAX := "res://../Assets/Generated/ParallaxConcepts/service-gallery-tile-pack-v1/godot_front_shift_12px.png"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1978, 795)
	root.content_scale_size = Vector2i(1978, 795)
	var scene := load("res://scenes/ServiceGalleryPreview.tscn") as PackedScene
	if scene == null:
		push_error("Preview scene could not load")
		quit(1)
		return
	var preview := scene.instantiate()
	root.add_child(preview)
	# The game has a global CRT overlay; disable it for a pixel-faithful asset
	# review without changing the player's saved CRT preference.
	var crt := root.get_node_or_null("CrtFx") as CanvasLayer
	if crt != null:
		crt.visible = false
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var rendered := root.get_texture().get_image()
	if rendered == null or rendered.is_empty():
		push_error("Renderer returned no image")
		quit(1)
		return
	var err := rendered.save_png(OUTPUT_ON)
	if err != OK:
		push_error("Could not save render: " + error_string(err))
		quit(1)
		return
	var pack := preview.get_node("ServiceGalleryPack")
	pack.set("fixtures_on", false)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var dark := root.get_texture().get_image()
	err = dark.save_png(OUTPUT_OFF)
	if err != OK:
		push_error("Could not save lights-off render: " + error_string(err))
		quit(1)
		return
	pack.set("fixtures_on", true)
	pack.call("set_prop_visible", "motor_cart", false)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	err = root.get_texture().get_image().save_png(OUTPUT_CART_REMOVED)
	if err != OK:
		push_error("Could not save cart-removed render: " + error_string(err))
		quit(1)
		return
	pack.call("reset_prop", "motor_cart")
	pack.set("front_shift_px", 12.0)
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	err = root.get_texture().get_image().save_png(OUTPUT_PARALLAX)
	if err != OK:
		push_error("Could not save shifted render: " + error_string(err))
		quit(1)
		return
	print("RENDER -> lights on/off size=", rendered.get_size(), " root=", root.size, " scale=", root.content_scale_size)
	quit()
