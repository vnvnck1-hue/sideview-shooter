extends SceneTree
## Rendered review: godot --path GodotPrototype --fixed-fps 60 --script res://tools/capture_bugbot_battle.gd
var frame := 0


func _initialize() -> void:
	seed(4812)
	AppFlow.start_test(self, "hangar", 2000.0, 1)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		current_scene._toggle_bugbot_battle()
	if frame == 600:
		capture.call_deferred()
	return false


func capture() -> void:
	await RenderingServer.frame_post_draw
	var folder := "res://tools/artifacts/bugbot_battle/"
	DirAccess.make_dir_recursive_absolute(folder)
	var result := root.get_texture().get_image().save_png(folder + "combat.png")
	print("BUGBOT CAPTURE: ", error_string(result))
	quit(0 if result == OK else 1)
