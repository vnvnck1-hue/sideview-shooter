extends SceneTree
## 최적화 전후 화면 비교용 캡처: trace_determinism.gd 와 같은 고정 시나리오(격납고 F10 전투 + 고정 패턴 사격)를
## 창 모드로 돌리며 지정 프레임의 화면을 RGB8 원시 바이트로 저장한다. 두 빌드의 출력을 바이트 단위로 비교한다.
##
## 실행: godot --path . --fixed-fps 60 --script res://tools/capture_frames.gd -- <출력 폴더> [프레임 목록=120,300,480,700,900] [pin]
## 주의: 카메라가 **실제 마우스 커서** 쪽으로 앞서 나가므로, 캡처 중 마우스를 움직이면 화면 구도가 달라진다.
##       마우스를 가만히 두거나, 마지막 인자에 pin 을 주면 매 프레임 커서를 창 가운데로 고정한다(커서가 잠깐 묶인다).

var main: Node
var _frame := 0
var _warm := 0
var _out := ""
var _frames: Array = [120, 300, 480, 700, 900]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_pin = args.size() > 2 and args[2] == "pin"
	if args.size() > 1:
		_frames = []
		for f in args[1].split(","):
			_frames.append(int(f))
	DirAccess.make_dir_recursive_absolute(_out)
	# 창 크기를 고정한다 — 최대화 창은 시작 몇 프레임 사이 크기가 바뀌는 시점이 실행마다 달라 카메라 시작점이 흔들렸다
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))



var _settle := 0
var _pin := false


func _process(_delta: float) -> bool:
	if _pin:
		Input.warp_mouse(Vector2(root.size) * 0.5)
	# 창이 자리를 잡을 때까지 기다렸다가 씬을 연다 (창 크기 확정 시점이 실행마다 달라 카메라 시작점이 흔들렸다)
	if _settle < 45:
		_settle += 1
		if _settle == 45:
			seed(4812)
			AppFlow.start_test(self, "hangar", 2000.0, 1)
		return false
	if main == null:
		main = current_scene
		if main == null or main.get("player") == null or main.get("current_room") == null:
			main = null
			return false
	_warm += 1
	if _warm == 20:
		_key(true)
	elif _warm == 23:
		_key(false)
	if _warm < 30:
		return false
	_frame += 1
	if _frame % 6 == 0:
		var p: Node2D = main.get("player")
		var k := float(_frame)
		var target := Vector2(p.position.x + sin(k * 0.37) * 850.0, 300.0 + cos(k * 0.21) * 150.0)
		main.call("_spawn_shot", p.position + Vector2(0, -40), target, 1.0, 1.0)
	if _frame % 10 == 0:
		_dump(main.get("current_room"))
	if _frame in _frames:
		# 이 프레임에 그려진 결과는 다음 프레임 초에 읽힌다 — 캡처 요청만 걸어 두고 한 프레임 뒤 저장한다
		_save.call_deferred(_frame)
	return _frame > int(_frames.max()) + 3


func _save(at: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var f := FileAccess.open("%s/f%04d_%dx%d.rgb" % [_out, at, img.get_width(), img.get_height()], FileAccess.WRITE)
	f.store_buffer(img.get_data())
	f.close()
	print("CAPTURED ", at)


func _key(pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F10
	key.pressed = pressed
	Input.parse_input_event(key)


func _v(v: Vector2) -> String:
	return "%.4f,%.4f" % [v.x, v.y]


## trace_determinism.gd 와 같은 상태 기록 + 플레이어·카메라 (창 모드에서 어디서 갈라지는지 찾는다)
func _dump(room) -> void:
	var p: Node2D = main.get("player")
	var cam = main.get("camera")
	var line := "F%d P %s" % [_frame, _v(p.position)]
	if cam != null:
		line += " C %s" % _v(cam.global_position + cam.offset)
	line += " r=%.6f" % randf()
	var battle = room.get("bugbot_battle")
	if battle != null:
		for bot in battle.bots:
			if is_instance_valid(bot):
				line += " | B %s a=%.2f" % [_v(bot.get("_walker").body_pos), bot.armor]
		line += " | kills=%d serial=%d" % [battle.kills, battle._spawn_serial]
	for m in room.monsters:
		if is_instance_valid(m):
			line += " | M %s hp=%s" % [_v(m.position), str(m.hp)]
	print(line)
