extends SceneTree
## Rendered regression for the dark vision at different zooms/rooms:
##   · near the observer the scene is lit, far away (and away from every light) it is black,
##   · a room light reveals its surroundings beyond the observer's sight,
##   · a light that appears in the dark (muzzle flash / impact) reveals it, and the dark returns when it goes.
## godot --path GodotPrototype --script res://tools/validate_dark_vision.gd

const DarkVision := preload("res://scripts/dark_vision.gd")
const WARP := 156.0                    # dark_common DV_WARP (150) + snap margin
const BREATHE := 0.04                  # DV_BREATHE (0.035) + margin
const MASK_REACH := 1.3                # dark_vision.gdshader reach
const MASK_LIGHT_REACH := 1.25 * 1.25  # light_reach + flow margin

var game: Node
var failures := 0
var total_hidden := 0
var total_light_lit := 0
var output := "res://../research-images/dark-vision/"


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	AppFlow.start_room = "workshop"
	change_scene_to_file("res://scenes/MainGame.tscn")
	await process_frame
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	game = current_scene
	game.player.input_enabled = false
	game.current_room.disable_monsters()
	await create_timer(0.5).timeout
	# Freeze gameplay while keeping the mask following our explicit test poses.
	game.set_process(false)
	game.player.set_process(false)
	game.camera.set_process(false)
	game.camera.lead_enabled = false
	game.crosshair.position = Vector2(-10000, -10000)
	# Leak checks compare against pure black; the colour palette is checked separately (check_palette).
	game.dark_vision.set_black(true)
	await capture_case("01-right", Vector2.RIGHT)
	await capture_case("02-left", Vector2.LEFT)
	await check_reticle()
	game.camera.zoom = Vector2(0.5, 0.5)
	game.camera.snap()
	await capture_case("03-wide-up", Vector2(1, -0.5).normalized())
	game.player.position.x += 420.0
	game.camera.zoom = Vector2.ONE
	game.camera.snap()
	await capture_case("04-moved-close", Vector2.RIGHT)
	root.size = Vector2i(1280, 960)
	await process_frame
	await capture_case("05-resized", Vector2.LEFT)
	game._load_room(RoomData.START_ROOM, 600.0, 1)
	game.current_room.disable_monsters()
	game.camera.snap()
	await capture_case("06-room-change", Vector2.RIGHT)
	game._load_room("corr_west", 700.0, 1)
	game.current_room.disable_monsters()
	game.camera.snap()
	var sentry: Node2D = game.current_room.sentries[0]
	sentry.set_process(false)
	game.controlled_turret = sentry
	await capture_case("07-sentry", Vector2.LEFT)
	var walker: Node2D = game.current_room.walkers[0]
	walker.set_process(false)
	game.controlled_turret = walker
	await capture_case("08-walker", Vector2.RIGHT)
	game.controlled_turret = null
	# The widest room, observer at one end: the far side must sink into the dark except around lights.
	game._load_room("hangar", 260.0, 1)
	game.current_room.disable_monsters()
	game.camera.zoom = Vector2(0.3, 0.3)
	game.camera.snap()
	await create_timer(0.3).timeout
	await capture_case("09-hangar-far", Vector2.RIGHT)
	await check_flash_reveal()
	game.dark_vision.set_black(false)
	await check_palette()
	# Somewhere across the cases the far dark must actually be sampled, and a room light must reveal it.
	if total_hidden < 500 or total_light_lit < 20:
		failures += 1
	print("DARK_VISION totals hidden=", total_hidden, " light_lit=", total_light_lit)
	print("DARK_VISION_RESULT failures=", failures)
	quit(1 if failures else 0)


func capture_case(label: String, direction: Vector2) -> void:
	var eye: Vector2 = game.player.head_pivot.global_position
	var observer: Node2D = game.player
	if is_instance_valid(game.controlled_turret):
		observer = game.controlled_turret
		eye = observer.vision_origin()
	observer.aim_target = eye + direction * 800.0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = game.world_vp.get_texture().get_image()
	var inverse: Transform2D = game.world_vp.get_canvas_transform().affine_inverse()
	var lights: Array = game.dark_vision.active_lights(game.world_vp.get_visible_rect(), inverse)
	var hidden := 0
	var light_lit := 0
	var leaked := 0
	var visible_lit := 0
	var r_clear := DarkVision.NEAR_CLEAR * (1.0 - BREATHE) - WARP
	var r_dark := DarkVision.NEAR_DARK * MASK_REACH * (1.0 + BREATHE) + WARP
	for y in range(4, image.get_height(), 8):
		for x in range(4, image.get_width(), 8):
			var p := inverse * Vector2(x + 0.5, y + 0.5)
			p = (p / 4.0).floor() * 4.0 + Vector2(2, 2)
			var d := p - eye
			var color := image.get_pixel(x, y)
			var brightness := maxf(color.r, maxf(color.g, color.b))
			if d.length() > r_dark:
				if not _near_light(p, lights, MASK_LIGHT_REACH):
					hidden += 1
					if brightness > 0.005:
						leaked += 1
				elif _near_light(p, lights, 0.3) and brightness > 0.02:
					light_lit += 1
			elif d.length() < r_clear and brightness > 0.02:
				visible_lit += 1
	total_hidden += hidden
	total_light_lit += light_lit
	var passed := leaked == 0 and visible_lit > 100
	if not passed:
		failures += 1
	print("DARK_VISION ", label, " hidden=", hidden, " leaked=", leaked, " visible_lit=", visible_lit, " light_lit=", light_lit, " pass=", passed)
	image.save_png(output + label + ".png")
	if label == "01-right":
		root.get_texture().get_image().save_png(output + "game-with-hud.png")


func check_reticle() -> void:
	var point := Vector2(120, 170)
	game.crosshair.position = game.world_vp.get_canvas_transform().affine_inverse() * point
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = game.world_vp.get_texture().get_image()
	var color := image.get_pixelv(Vector2i(point))
	var passed := color.r > 0.8 and color.g > 0.8
	if not passed:
		failures += 1
	print("DARK_VISION reticle_in_darkness pass=", passed)
	game.crosshair.position = Vector2(-10000, -10000)


func _near_light(p: Vector2, lights: Array, reach: float) -> bool:
	for info in lights:
		if p.distance_to(info["pos"]) < float(info["radius"]) * reach:
			return true
	return false


## A light that appears deep in the dark must reveal the surfaces around it; removing it must restore the dark.
func check_flash_reveal() -> void:
	# Blackout: switch every existing light off so the far side is truly dark.
	var switched: Array = []
	for l in game.dark_vision._lights:
		if is_instance_valid(l) and l.enabled:
			l.enabled = false
			switched.append(l)
	await capture_case("10-blackout", Vector2.RIGHT)
	await RenderingServer.frame_post_draw
	var inverse: Transform2D = game.world_vp.get_canvas_transform().affine_inverse()
	var eye: Vector2 = game.player.head_pivot.global_position
	var lights: Array = game.dark_vision.active_lights(game.world_vp.get_visible_rect(), inverse)
	# Farthest on-screen point inside the room (so there are surfaces to light) that is currently black.
	var size: Vector2 = game.world_vp.get_visible_rect().size
	var room_rect: Rect2 = RoomData.room_rect(game.current_room.room_id).grow(-80.0)
	var spot := Vector2.INF
	var shot: Image = game.world_vp.get_texture().get_image()
	for sy in range(60, int(size.y) - 60, 40):
		for sx in range(60, int(size.x) - 60, 40):
			var p := inverse * Vector2(sx, sy)
			var fy: float = game.current_room.floor_y
			if not room_rect.has_point(p) or p.y < fy - 350.0 or p.y > fy + 250.0 or p.distance_to(eye) < DarkVision.NEAR_DARK * 1.1 + WARP:
				continue
			if spot != Vector2.INF and p.distance_to(eye) <= spot.distance_to(eye):
				continue
			if _brightness_around(p, inverse, shot) < 0.002:
				spot = p
	if spot == Vector2.INF:
		print("DARK_VISION flash_reveal no dark spot on screen")
		failures += 1
		_restore(switched)
		return
	var before := _brightness_around(spot, inverse)
	var flash := PointLight2D.new()
	flash.texture = Lighting.radial_texture()
	flash.texture_scale = Lighting.scale_for_radius(360.0)
	flash.height = Lighting.FLASH_HEIGHT
	flash.color = Lighting.IMPACT_LIGHT
	flash.energy = 2.5
	flash.blend_mode = Light2D.BLEND_MODE_ADD
	flash.position = spot
	game.current_room.add_child(flash)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var during := _brightness_around(spot, inverse)
	game.world_vp.get_texture().get_image().save_png(output + "11-flash-reveal.png")
	flash.queue_free()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var after := _brightness_around(spot, inverse)
	var passed := before < 0.004 and during > 0.02 and after < 0.004   # measured with set_black(true)
	if not passed:
		failures += 1
	_restore(switched)
	print("DARK_VISION flash_reveal spot=", spot, " before=", before, " during=", during, " after=", after, " pass=", passed)
	game.camera.zoom = Vector2.ONE
	game.camera.snap()


## The dark is tinted by the room's shadow palette, not flat black: the same frame rendered with the palette
## minus the pure-black render (in the far dark, where there is something to tint) must add colour leaning like the palette.
func check_palette() -> void:
	game.camera.zoom = Vector2(0.3, 0.3)
	game.camera.snap()
	var switched: Array = []
	for l in game.dark_vision._lights:
		if is_instance_valid(l) and l.enabled:
			l.enabled = false
			switched.append(l)
	# Reference with no darkness at all: pixels black here are genuinely empty void.
	game.dark_vision.set_process(false)
	game.dark_vision.mask.visible = false
	RenderingServer.global_shader_parameter_set("dv_on", 0.0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var reference: Image = game.world_vp.get_texture().get_image()
	game.dark_vision.set_process(true)
	game.dark_vision.mask.visible = true
	game.dark_vision.set_black(true)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var black: Image = game.world_vp.get_texture().get_image()
	game.dark_vision.set_black(false)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var tinted: Image = game.world_vp.get_texture().get_image()
	tinted.save_png(output + "12-palette.png")
	_restore(switched)
	var inverse: Transform2D = game.world_vp.get_canvas_transform().affine_inverse()
	var eye: Vector2 = game.player.head_pivot.global_position
	var diff := Color(0, 0, 0, 0)
	var n := 0
	var void_lit := 0
	for y in range(4, tinted.get_height(), 8):
		for x in range(4, tinted.get_width(), 8):
			var p := inverse * Vector2(x + 0.5, y + 0.5)
			if p.distance_to(eye) < DarkVision.NEAR_CLEAR * 1.2:
				continue
			var b := black.get_pixel(x, y)
			var c := tinted.get_pixel(x, y)
			var r := reference.get_pixel(x, y)
			if maxf(r.r, maxf(r.g, r.b)) <= 0.0:
				# Truly empty void must stay black even with the palette (keeps the room silhouette crisp).
				if maxf(c.r, maxf(c.g, c.b)) > 0.02:
					void_lit += 1
				continue
			diff += Color(c.r - b.r, c.g - b.g, c.b - b.b, 0)
			n += 1
	var avg := diff / maxf(n, 1)
	var pal: Dictionary = DarkVision.palette_for(str(RoomData.ROOMS[game.current_room.room_id].get("theme", "")))
	var edge: Color = pal["edge"]
	var deep: Color = pal["deep"]
	var tone := edge + deep
	var hue_ok := (avg.b >= avg.g) == (tone.b >= tone.g) and (avg.r >= avg.g) == (tone.r >= tone.g)
	var passed := n > 100 and maxf(avg.r, maxf(avg.g, avg.b)) > 0.004 and hue_ok and void_lit < n / 50
	if not passed:
		failures += 1
	print("DARK_VISION palette samples=", n, " added=", avg, " palette_tone=", tone, " void_lit=", void_lit, " pass=", passed)


func _restore(lights: Array) -> void:
	for l in lights:
		if is_instance_valid(l):
			l.enabled = true


func _brightness_around(spot: Vector2, inverse: Transform2D, image: Image = null) -> float:
	if image == null:
		image = game.world_vp.get_texture().get_image()
	var to_screen := inverse.affine_inverse()
	var total := 0.0
	var n := 0
	for oy in range(-80, 81, 16):
		for ox in range(-160, 161, 16):
			var sp := to_screen * (spot + Vector2(ox, oy))
			if sp.x < 0 or sp.y < 0 or sp.x >= image.get_width() or sp.y >= image.get_height():
				continue
			var c := image.get_pixel(int(sp.x), int(sp.y))
			total += maxf(c.r, maxf(c.g, c.b))
			n += 1
	return total / maxf(n, 1)
