extends Node
## 숫자 1~4 런타임 입력이 Main → 기존 크롤러 → 이후 기본값까지 전파되는지 검사한다.
## 실행: godot --path GodotPrototype res://scenes/HitFxInputTest.tscn


func _ready() -> void:
	AppFlow.start_room = "workshop"
	var main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	Input.action_press("hit_fx_3")
	await get_tree().process_frame
	Input.action_release("hit_fx_3")
	await get_tree().process_frame

	var failures: Array[String] = []
	if Crawler.default_hit_fx_preset != 2:
		failures.append("3 key did not select preset index 2")
	var live := 0
	for monster in main.current_room.monsters:
		if is_instance_valid(monster) and monster is Crawler and not monster.is_dead():
			live += 1
			if monster.hit_fx_preset != 2:
				failures.append("live crawler did not receive preset index 2")
			if monster._flash <= 0.0:
				failures.append("live crawler did not play the zero-damage preview flash")
	if live == 0:
		failures.append("test room has no live crawlers")

	if failures.is_empty():
		print("HIT_FX_INPUT PASS preset=3 live_crawlers=%d" % live)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("HIT_FX_INPUT %s" % failure)
		get_tree().quit(1)
