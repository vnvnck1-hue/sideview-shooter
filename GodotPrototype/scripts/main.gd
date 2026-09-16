extends Node2D
## 방 로딩·전환, 카메라, HUD 를 담당하는 메인 씬.

const START_ROOM := "workshop"
const START_X := 1840.0 - 96.0 + 120.0      # 검증 이미지의 캐릭터 위치(발 중심)
const WALL_MARGIN := 110.0                   # 캡 타일 안쪽 벽까지의 여유
const DOOR_PASS_MARGIN := 60.0              # 열린 측벽문으로 들어갈 때 허용되는 초과 거리
const SIDE_PAD := 180.0                      # 카메라가 방 밖 어두운 여백을 보여주는 폭
const FADE_TIME := 0.11
const CAMERA_ZOOM := 0.5                     # 원본 픽셀의 1/2 크기로 표시 (정수 배율 축소)

var current_room: Room
var player: Player
var camera: Camera2D
var bullets: Node2D
var fade: ColorRect
var title_label: Label
var hint_label: Label
var prompt_label: Label
var crosshair: Node2D
var transitioning := false
var _shake := 0.0
var _post_mat: ShaderMaterial
var _aberration := 0.0

const SHAKE_PER_SHOT := 3.5
const SHAKE_DECAY := 14.0
const ABERRATION_PER_SHOT := 2.2      # 사격 시 색수차 (화면 px)
const ABERRATION_DECAY := 18.0


func _ready() -> void:
	_setup_input_map()
	_setup_environment()
	_setup_ui()

	player = Player.new()
	player.name = "Player"
	player.z_index = 5
	player.shoot_fired.connect(_on_player_shoot)
	player.shell_ejected.connect(_on_shell_ejected)
	player.request_front_door.connect(_on_front_door_requested)

	bullets = Node2D.new()
	bullets.name = "Bullets"
	bullets.z_index = 6

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 16.0
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)

	crosshair = Crosshair.new()
	crosshair.name = "Crosshair"
	crosshair.z_index = 20
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	add_child(player)
	add_child(bullets)
	add_child(crosshair)
	add_child(camera)
	_load_room(START_ROOM, START_X, 1)
	camera.make_current()
	camera.reset_smoothing()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

	if current_room == null:
		return

	# 조준: 마우스 포인터의 월드 좌표가 곧 탄착 지점
	var mouse_world := get_global_mouse_position()
	crosshair.position = mouse_world
	if not transitioning:
		player.aim_target = mouse_world

	# 카메라: 플레이어 X 추적, 방 범위로 제한 (+ 사격 흔들림)
	camera.position = Vector2(player.position.x, RoomData.TILE_HEIGHT * 0.5)
	_shake = maxf(_shake - SHAKE_DECAY * _delta * maxf(_shake, 0.5), 0.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	# 사격 색수차: 흔들림과 같은 리듬으로 빠르게 빠진다
	_aberration = maxf(_aberration - ABERRATION_DECAY * _delta * maxf(_aberration, 0.4), 0.0)
	_post_mat.set_shader_parameter("aberration", _aberration)
	# 피격 열 잔광이 식는다 (벽·문·프랍 표면)
	HeatSurface.tick_all(_delta)

	if transitioning:
		return

	# 측벽문 통과 판정
	if current_room.right_door_open and player.position.x >= current_room.width - 10:
		_go_to_room(current_room.right_target, "left")
	elif current_room.left_door_open and player.position.x <= 10:
		_go_to_room(current_room.left_target, "right")

	# 정면문 안내 문구
	var fd := current_room.front_door_near(player.position.x)
	prompt_label.visible = not fd.is_empty()
	if not fd.is_empty():
		prompt_label.text = "▲  W / ↑  —  %s 으로 들어가기" % RoomData.get_room(fd["target"])["title"]


func _load_room(id: String, spawn_x: float, face_dir: int) -> void:
	if current_room:
		current_room.queue_free()
	for b in bullets.get_children():
		b.queue_free()
	HeatSurface.clear_all()

	current_room = Room.new()
	current_room.name = "Room_" + id
	current_room.build(id)
	current_room.player = player
	add_child(current_room)
	move_child(current_room, 0)

	# 이동 한계: 닫힌 쪽은 벽 앞에서 멈추고, 열린 쪽은 문을 지나갈 수 있게 조금 더 허용
	var left_limit := -DOOR_PASS_MARGIN if current_room.left_door_open else WALL_MARGIN
	var right_limit := current_room.width + DOOR_PASS_MARGIN if current_room.right_door_open else current_room.width - WALL_MARGIN
	player.position = Vector2(spawn_x, RoomData.FLOOR_Y + 2)
	player.set_bounds(left_limit, right_limit)
	player.face(face_dir)

	_apply_camera_limits()
	title_label.text = RoomData.get_room(id)["title"]


func _apply_camera_limits() -> void:
	var vp := get_viewport_rect().size / CAMERA_ZOOM   # 줌을 반영한 실제 월드 가시 폭
	var room_w := float(current_room.width) + SIDE_PAD * 2.0
	var left := -SIDE_PAD
	var right := current_room.width + SIDE_PAD
	if room_w < vp.x:
		# 방이 화면보다 좁으면 가운데 고정
		var cx := current_room.width * 0.5
		left = cx - vp.x * 0.5
		right = cx + vp.x * 0.5
	camera.limit_left = int(left)
	camera.limit_right = int(right)
	var cy := RoomData.TILE_HEIGHT * 0.5
	camera.limit_top = int(cy - vp.y * 0.5)
	camera.limit_bottom = int(cy + vp.y * 0.5)


## 측벽문으로 이동. enter_side = 목표 방에서 등장하는 쪽("left"/"right")
func _go_to_room(target: String, enter_side: String) -> void:
	var target_w := RoomData.room_width(target)
	var spawn_x := 120.0 if enter_side == "left" else target_w - 120.0
	var face_dir := 1 if enter_side == "left" else -1
	_transition(target, spawn_x, face_dir)


func _on_front_door_requested() -> void:
	if transitioning or current_room == null:
		return
	var fd := current_room.front_door_near(player.position.x)
	if fd.is_empty():
		return
	var target: String = fd["target"]
	var tmp := Room.new()
	tmp.build(target)
	var spawn_x := tmp.front_door_spawn_x(fd["target_door"])
	tmp.free()
	_transition(target, spawn_x, player.facing)


func _transition(target: String, spawn_x: float, face_dir: int) -> void:
	transitioning = true
	player.input_enabled = false
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, FADE_TIME)
	tw.tween_callback(func():
		_load_room(target, spawn_x, face_dir)
		camera.position = Vector2(player.position.x, RoomData.TILE_HEIGHT * 0.5)
		camera.reset_smoothing()
	)
	tw.tween_property(fade, "color:a", 0.0, FADE_TIME)
	tw.tween_callback(func():
		transitioning = false
		player.input_enabled = true
	)


func _on_player_shoot(muzzle_pos: Vector2, target_pos: Vector2) -> void:
	var b := Bullet.new()
	b.setup(muzzle_pos, target_pos)
	b.floor_y = player.position.y
	# 무엇을 맞췃나: 램프·비상등은 깨지고(유리 파편·스파크), 프랍은 흔들리며 조각나고, 벽은 붉게 달아오른다
	var hit := current_room.hit_at(target_pos)
	match hit["kind"]:
		"lamp":
			hit["node"].break_lamp()
			b.impact_kind = Bullet.Impact.GLASS
			_shake = minf(_shake + 3.0, 10.0)
		"beacon":
			hit["node"].break_light()
			b.impact_kind = Bullet.Impact.GLASS
			_shake = minf(_shake + 2.5, 10.0)
		"wall":
			current_room.heat_wall(hit["node"], target_pos)
		"glass":
			hit["node"].crack(target_pos)
			b.impact_kind = Bullet.Impact.GLASS
			_shake = minf(_shake + 1.5, 10.0)
		"prop":
			hit["node"].hit(signf(target_pos.x - muzzle_pos.x), target_pos.y, target_pos)
			b.impact_kind = Bullet.Impact.PROP
	bullets.add_child(b)
	current_room.notify_shot(muzzle_pos, target_pos)      # 전선 등 물리 반응
	_shake = minf(_shake + SHAKE_PER_SHOT, 10.0)
	_aberration = minf(_aberration + ABERRATION_PER_SHOT, 6.0)
	crosshair.kick()


func _on_shell_ejected(pos: Vector2, dir: int) -> void:
	var sc := ShellCasing.new()
	sc.setup(pos, dir, player.position.y)
	bullets.add_child(sc)


## 글로우(WorldEnvironment) + 풀스크린 후처리(색수차·비네트). 2D 는 project.godot 의 hdr_2d 가 켜져야 글로우가 잡힌다.
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.85      # LDR 2D: 거의 흰 픽셀(전구·총구·스파크)만 번진다
	env.glow_hdr_scale = 2.0
	env.glow_hdr_luminance_cap = 2.0        # 총구처럼 아주 밝은 곳이 거대한 광구로 번지지 않게 상한
	# 픽셀이 뭉개지지 않게 작은 레벨은 끄고 중간~큰 번짐만
	for i in range(7):
		env.set_glow_level(i, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.7)
	env.set_glow_level(4, 0.35)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	add_child(we)

	var post_layer := CanvasLayer.new()
	post_layer.name = "PostFX"
	post_layer.layer = 9
	add_child(post_layer)
	var post := ColorRect.new()
	post.name = "PostRect"
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = Lighting.shader_material("post_fx")
	post.material = _post_mat
	post_layer.add_child(post)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.layer = 10
	add_child(layer)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])

	title_label = Label.new()
	title_label.position = Vector2(24, 18)
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	layer.add_child(title_label)

	hint_label = Label.new()
	hint_label.text = "A/D ←/→ 이동    마우스 조준 · 좌클릭 사격(홀드 연사)    Space 구르기    Ctrl 앉기    W/↑ 정면문 진입    F11 전체화면"
	hint_label.position = Vector2(24, 860)
	hint_label.add_theme_font_override("font", font)
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	layer.add_child(hint_label)

	prompt_label = Label.new()
	prompt_label.position = Vector2(0, 96)
	prompt_label.size = Vector2(1600, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_override("font", font)
	prompt_label.add_theme_font_size_override("font_size", 26)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	prompt_label.visible = false
	layer.add_child(prompt_label)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


func _setup_input_map() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("interact", [KEY_W, KEY_UP])
	_add_action("crouch", [KEY_CTRL, KEY_S, KEY_DOWN])
	_add_action("shoot", [KEY_J])
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)
	_add_action("roll", [KEY_SPACE])
	_add_action("toggle_fullscreen", [KEY_F11])


func _add_mouse_action(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
