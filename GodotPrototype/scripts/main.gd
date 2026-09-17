extends Node2D
## 방 로딩·전환, 카메라, HUD 를 담당하는 메인 씬.

const LightMood := preload("res://scripts/light_mood.gd")
const MouseRecoil := preload("res://scripts/mouse_recoil.gd")

const START_ROOM := "workshop"
const START_X := 1840.0 - 96.0 + 120.0      # 검증 이미지의 캐릭터 위치(발 중심)
const WALL_MARGIN := 110.0                   # 캡 타일 안쪽 벽까지의 여유
const DOOR_PASS_MARGIN := 60.0              # 열린 측벽문으로 들어갈 때 허용되는 초과 거리
const SIDE_PAD := 180.0                      # 카메라가 방 밖 어두운 여백을 보여주는 폭
const FADE_TIME := 0.11
const CAMERA_ZOOM := 0.5                     # 원본 픽셀의 1/2 크기로 표시 (정수 배율 축소)

var current_room: Room
var player: Player
var camera: GameCamera
var bullets: Node2D
var fade: ColorRect
var title_label: Label
var hint_label: Label
var prompt_label: Label
var ammo_label: Label
var recoil_label: Label                    # 반동 프리셋 비교용 (선택 후 제거)
var crosshair: Node2D
var transitioning := false
var _post_mat: ShaderMaterial
var _aberration := 0.0
var _recoil := MouseRecoil.new()          # 사격 반동 → 실제 마우스 포인터 이동

const SHAKE_PER_SHOT := 3.5
const PLAYER_HIT_KNOCKBACK := 480.0   # 독액에 맞았을 때 밀리는 속도 (px/s)
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
	player.ammo_changed.connect(_on_ammo_changed)

	bullets = Node2D.new()
	bullets.name = "Bullets"
	bullets.z_index = 6

	camera = GameCamera.new()
	camera.name = "Camera"
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.target = player
	camera.base_y = RoomData.TILE_HEIGHT * 0.5

	crosshair = Crosshair.new()
	crosshair.name = "Crosshair"
	crosshair.z_index = 20
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	add_child(player)
	add_child(bullets)
	add_child(crosshair)
	add_child(camera)
	var room_id := AppFlow.start_room if RoomData.ROOMS.has(AppFlow.start_room) else START_ROOM
	var spawn_x := START_X if room_id == START_ROOM else RoomData.room_width(room_id) * 0.5
	_load_room(room_id, spawn_x, 1)
	camera.make_current()
	camera.set_preset(GameCamera.DEFAULT_PRESET)
	camera.snap()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

	# F1: 로비로
	if Input.is_action_just_pressed("to_lobby") and not transitioning:
		AppFlow.go_lobby(get_tree())
		return

	# 반동 프리셋 비교 (P) — 선택 후 제거 예정
	if Input.is_action_just_pressed("recoil_cycle"):
		set_recoil_preset(Player.recoil_index + 1)

	if current_room == null:
		return

	# 사격 반동: 포인터를 실제로 밀어 올린다 (조준점 읽기 전에 적용)
	_recoil.tick(get_viewport(), _delta)

	# 조준: 마우스 포인터의 월드 좌표가 곧 탄착 지점
	var mouse_world := get_global_mouse_position()
	crosshair.position = mouse_world
	crosshair.heat = player.spread_ratio()
	if not transitioning:
		player.aim_target = mouse_world

	# 카메라 추적·마우스/시선 리드·흔들림은 GameCamera 가 스스로 처리한다
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
	current_room.player_hit.connect(_on_player_hit)
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
	camera.set_room(float(current_room.width), SIDE_PAD)


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
		camera.snap()
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
		"monster":
			hit["node"].hit(target_pos, signf(target_pos.x - muzzle_pos.x))
			b.impact_kind = Bullet.Impact.FLESH
			camera.add_shake(1.2)
		"lamp":
			hit["node"].break_lamp()
			b.impact_kind = Bullet.Impact.GLASS
			camera.add_shake(3.0)
		"beacon":
			hit["node"].break_light()
			b.impact_kind = Bullet.Impact.GLASS
			camera.add_shake(2.5)
		"wall":
			current_room.heat_wall(hit["node"], target_pos)
		"glass":
			hit["node"].crack(target_pos)
			b.impact_kind = Bullet.Impact.GLASS
			camera.add_shake(1.5)
		"prop":
			hit["node"].hit(signf(target_pos.x - muzzle_pos.x), target_pos.y, target_pos)
			b.impact_kind = Bullet.Impact.PROP
	bullets.add_child(b)
	current_room.notify_shot(muzzle_pos, target_pos)      # 전선 등 물리 반응
	camera.add_shake(SHAKE_PER_SHOT)
	_aberration = minf(_aberration + ABERRATION_PER_SHOT, 6.0)
	crosshair.kick()
	_recoil.kick(float(player.facing))


func _on_ammo_changed(ammo: int, mag: int, reloading: bool) -> void:
	if reloading:
		ammo_label.text = "재장전 중…   %d" % mag
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.4))
	else:
		ammo_label.text = "%d / %d" % [ammo, mag]
		var low := ammo <= mag / 4
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if low else Color(0.95, 0.9, 0.8))


## 몬스터 독액에 맞음: 카메라 흔들림 + 색수차 + 플레이어 밀림 (체력은 아직 없음)
func _on_player_hit(_point: Vector2, dir: float) -> void:
	camera.add_shake(7.0)
	_aberration = minf(_aberration + 3.5, 6.0)
	player.knockback(dir * PLAYER_HIT_KNOCKBACK)


## 불 스타일 (확정: 잉걸·검은 연기). 개발용 호출만 남긴다.
func set_fire_style(index: int) -> void:
	FireSource.style_index = wrapi(index, 0, FireSource.STYLES.size())
	if current_room:
		for f in current_room.fires:
			f.apply_style(FireSource.style_index)


## 배경 라이팅 무드 (확정: 그라데이션 필). 개발용 호출만 남긴다.
func set_light_mood(index: int) -> void:
	LightMood.index = wrapi(index, 0, LightMood.PRESETS.size())
	if current_room:
		current_room.apply_mood(LightMood.index)


## 림라이트 프리셋 (확정: 부드러운 중간). 개발용 호출만 남긴다.
func set_rim_preset(index: int) -> void:
	Lighting.apply_rim_preset(index)


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
	hint_label.text = "F1 로비    A/D ←/→ 이동    마우스 조준 · 좌클릭 사격    Space 구르기    Ctrl 앉기    W/↑ 정면문 진입    R 재장전    P 반동 프리셋    F11 전체화면"
	hint_label.position = Vector2(24, 860)
	hint_label.add_theme_font_override("font", font)
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	layer.add_child(hint_label)

	# 정면문 안내: 화면 하단 중앙(힌트 바로 위) — 우상단 디버그 라벨과 겹치지 않게
	prompt_label = Label.new()
	prompt_label.position = Vector2(0, 800)
	prompt_label.size = Vector2(1600, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_override("font", font)
	prompt_label.add_theme_font_size_override("font_size", 26)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	prompt_label.visible = false
	layer.add_child(prompt_label)

	# 우상단: 반동 프리셋 (비교 중)
	recoil_label = Label.new()
	recoil_label.position = Vector2(1600 - 24 - 900, 18)
	recoil_label.size = Vector2(900, 60)
	recoil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	recoil_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recoil_label.add_theme_font_override("font", font)
	recoil_label.add_theme_font_size_override("font_size", 20)
	recoil_label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.62))
	layer.add_child(recoil_label)
	set_recoil_preset(Player.recoil_index)

	# 우하단: 탄창
	ammo_label = Label.new()
	ammo_label.position = Vector2(1600 - 24 - 360, 900 - 24 - 60)
	ammo_label.size = Vector2(360, 60)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ammo_label.add_theme_font_override("font", font)
	ammo_label.add_theme_font_size_override("font_size", 34)
	ammo_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	layer.add_child(ammo_label)
	_on_ammo_changed(Player.MAG_SIZE, Player.MAG_SIZE, false)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


## 반동 프리셋 (비교 중). 선택되면 Player.recoil_index 기본값만 남기고 제거
func set_recoil_preset(index: int) -> void:
	Player.recoil_index = wrapi(index, 0, Player.RECOIL_PRESETS.size())
	var names := PackedStringArray()
	for i in range(Player.RECOIL_PRESETS.size()):
		var n: String = Player.RECOIL_PRESETS[i]["name"]
		names.append(("[%d %s]" if i == Player.recoil_index else " %d %s ") % [i + 1, n])
	recoil_label.text = "반동 (P)  %s\n%s" % [" ".join(names), Player.recoil_preset()["desc"]]


func _setup_input_map() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("interact", [KEY_W, KEY_UP])
	_add_action("crouch", [KEY_CTRL, KEY_S, KEY_DOWN])
	_add_action("shoot", [KEY_J])
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)
	_add_action("roll", [KEY_SPACE])
	_add_action("toggle_fullscreen", [KEY_F11])
	_add_action("reload", [KEY_R])
	_add_action("to_lobby", [KEY_F1])
	_add_action("recoil_cycle", [KEY_P])    # 반동 프리셋 비교 (임시)


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
