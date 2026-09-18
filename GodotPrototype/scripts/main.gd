extends Node2D
## 방 로딩·전환, 카메라, HUD 를 담당하는 플레이 씬. scenes/Main.tscn(테스트: 랜덤 방) 과 scenes/MainGame.tscn(main_game.gd, 전체 맵) 이 쓴다.

const LightMood := preload("res://scripts/light_mood.gd")
const MouseRecoil := preload("res://scripts/mouse_recoil.gd")

const WALL_MARGIN := 110.0                   # 캡 타일 안쪽 벽까지의 여유
const DOOR_PASS_MARGIN := 60.0              # 열린 측벽문으로 들어갈 때 허용되는 초과 거리
const SIDE_PAD := 180.0                      # 카메라가 방 밖 어두운 여백을 보여주는 폭
const FADE_TIME := 0.11
## 렌더 확정 (2026-09-18, "베이크 자산 · 풀해상도"): 월드는 1600×900 SubViewport ×1 에 그리고 카메라 zoom 0.5 —
## 그림은 4px 블록 베이크 자산(아트 1px = 월드 4px = 화면 2px), 조명·파티클·이동은 부드럽게(스냅 없음).
## 저해상도 뷰포트(534×300 ×3 등)·계단형 광원·원본 자산 프리셋은 비교 후 폐기. 글로우·후처리는 SubViewport 안, HUD 는 바깥.
const VIEW_SIZE := Vector2i(1600, 900)
const VIEW_SCALE := 1
const CAMERA_ZOOM := 0.5
var depth_label: Label                     # 우상단: 공간감 프리셋 A/B (F2)

var world_vp: SubViewport                  # 월드 뷰포트
var world: Node2D                          # 방·플레이어·탄 등 월드 노드의 부모 (world_vp 안)
var current_room: Room
var player: Player
var camera: GameCamera
var bullets: Node2D
var fade: ColorRect
var title_label: Label
var hint_label: Label
var prompt_label: Label
var ammo_label: Label
var crosshair: Node2D
var transitioning := false
var _post_mat: ShaderMaterial
var _aberration := 0.0
var _recoil := MouseRecoil.new()          # 사격 반동 → 실제 마우스 포인터 이동

const SHAKE_PER_SHOT := 3.5
const PLAYER_HIT_KNOCKBACK := 480.0   # 독액에 맞았을 때 밀리는 속도 (px/s)
## 색수차 (화면 px = 뷰 px, 풀해상도)
const ABERRATION_PER_SHOT := 3.3
const ABERRATION_CAP := 9.0
const ABERRATION_PLAYER_HIT := 5.25
const ABERRATION_DECAY := 18.0


func _ready() -> void:
	var room_id := AppFlow.start_room if RoomData.ROOMS.has(AppFlow.start_room) else RoomData.START_ROOM
	DepthPreset.activate()
	Lighting.apply_light_range()
	_setup_input_map()
	_setup_view()
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
	camera.view_scale = float(VIEW_SCALE)

	crosshair = Crosshair.new()
	crosshair.name = "Crosshair"
	crosshair.z_index = 20
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	world.add_child(player)
	world.add_child(bullets)
	world.add_child(crosshair)
	world.add_child(camera)
	var spawn_x := RoomData.room_width(room_id) * 0.5
	var face_dir := 1
	var cam_preset := GameCamera.DEFAULT_PRESET
	if AppFlow.resume_x >= 0.0:                 # 프리셋 전환(재로드) 뒤 이어서
		spawn_x = AppFlow.resume_x
		face_dir = AppFlow.resume_facing
		if AppFlow.resume_camera_preset >= 0:
			cam_preset = AppFlow.resume_camera_preset
		AppFlow.resume_x = -1.0
		AppFlow.resume_camera_preset = -1
	_load_room(room_id, spawn_x, face_dir)
	camera.make_current()
	camera.set_preset(cam_preset)
	camera.snap()
	if AppFlow.lab_mode:
		_setup_lab()


## 근경 랩: 플레이어 입력·몬스터·조준점을 끄고 ForegroundLab 편집 오버레이를 근경 층에 붙인다. 안내는 하단 힌트 라벨에.
func _setup_lab() -> void:
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crosshair.visible = false
	ammo_label.visible = false
	current_room.disable_monsters()
	if current_room.foreground == null:
		hint_label.text = "근경 랩: 이 프리셋에는 근경 층이 없습니다 (F2 로 근경 분리 프리셋으로)"
		return
	var lab := ForegroundLab.new()
	lab.name = "ForegroundLab"
	lab.status_changed.connect(func(t: String): hint_label.text = t)
	current_room.foreground.add_child(lab)
	lab.setup(current_room.foreground, player)
	hint_label.position = Vector2(24, 900 - 24 - 110)
	hint_label.size = Vector2(1552, 110)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_label.text += "   ·   근경 랩"


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

	# F1: 로비로
	if Input.is_action_just_pressed("to_lobby") and not transitioning:
		AppFlow.go_lobby(get_tree())
		return

	# 공간감 프리셋 A/B (F2): 이전(평면) ↔ 근경 분리. 같은 방·위치에서 씬을 다시 로드한다
	if not transitioning and current_room != null and Input.is_action_just_pressed("depth_toggle"):
		_switch_depth_preset(DepthPreset.toggle_index())
		return

	if current_room == null:
		return

	# 사격 반동: 포인터를 실제로 밀어 올린다 (창 좌표 기준 — 루트 뷰포트)
	_recoil.tick(get_viewport(), _delta)

	# 조준: 마우스 포인터의 월드 좌표가 곧 탄착 지점
	var mouse_world := world.get_global_mouse_position()
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
	current_room.monster_roared.connect(_on_monster_roared)
	world.add_child(current_room)
	world.move_child(current_room, 0)

	# 이동 한계: 닫힌 쪽은 벽 앞에서 멈추고, 열린 쪽은 문을 지나갈 수 있게 조금 더 허용
	var left_limit := -DOOR_PASS_MARGIN if current_room.left_door_open else WALL_MARGIN
	var right_limit := current_room.width + DOOR_PASS_MARGIN if current_room.right_door_open else current_room.width - WALL_MARGIN
	player.position = Vector2(spawn_x, current_room.floor_y + 2)
	player.set_bounds(left_limit, right_limit)
	player.face(face_dir)

	_apply_camera_limits()
	var data := RoomData.get_room(id)
	title_label.text = "%s  ›  %s" % [data["zone"], data["title"]]


func _apply_camera_limits() -> void:
	# 세로 중심은 방의 실제 세로 범위(천장~560) 가운데 — 층고가 높은 방은 위로 올라간다
	camera.base_y = RoomData.room_rect(current_room.room_id).get_center().y
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
	var spawn_x := RoomData.front_door_center(target, int(fd["target_door"]))
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
	# 고인 물 위의 바닥을 맞히면 착수 — 물기둥이 튀고 수면이 파인다 (벽 열 잔광은 없음)
	if (hit["kind"] == "wall" or hit["kind"] == "none") and current_room.water != null and current_room.water.contains(target_pos):
		hit = {"kind": "water", "node": current_room.water}
	match hit["kind"]:
		"water":
			hit["node"].bullet_splash(target_pos.x, signf(target_pos.x - muzzle_pos.x))
			b.impact_kind = Bullet.Impact.WATER
			camera.add_shake(1.0)
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
	_aberration = minf(_aberration + ABERRATION_PER_SHOT, ABERRATION_CAP)
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
	_aberration = minf(_aberration + ABERRATION_PLAYER_HIT, ABERRATION_CAP)
	player.knockback(dir * PLAYER_HIT_KNOCKBACK)


## 몬스터 포효: 가까울수록 카메라가 낮게 울린다 (플레이어 피격 7 대비 최대 2.2)
func _on_monster_roared(pos: Vector2) -> void:
	var d := absf(pos.x - player.position.x)
	if d < Crawler.ROAR_SHAKE_RANGE:
		camera.add_shake(lerpf(2.2, 0.4, d / Crawler.ROAR_SHAKE_RANGE))


## 공간감 프리셋 전환 — 방·플레이어 위치·시선·카메라 프리셋을 남기고 Main 을 다시 로드한다
## (층 구성·라이트 분리·근경은 Room.build 에서 정해지므로 방을 새로 조립한다. 스폰된 몬스터는 초기화된다)
func _switch_depth_preset(preset: int) -> void:
	if preset == DepthPreset.index:
		return
	DepthPreset.index = preset
	transitioning = true
	player.input_enabled = false
	AppFlow.reload_in_place(get_tree(), current_room.room_id, player.position.x, player.facing, camera.preset_index)


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


func _update_depth_label() -> void:
	if depth_label == null:
		return
	depth_label.text = "공간감 (F2 A/B)  %s\n%s" % [DepthPreset.hud_line(), DepthPreset.current()["desc"]]


func _on_shell_ejected(pos: Vector2, dir: int) -> void:
	var sc := ShellCasing.new()
	sc.setup(pos, dir, player.position.y)
	bullets.add_child(sc)


## 월드 뷰포트. SubViewportContainer(1600×900) 안의 SubViewport(1600×900, ×1) — 글로우 환경·후처리를 월드에만 걸기 위해 분리한다.
## 컨테이너가 마우스 이벤트를 그대로 넘겨주므로 world 안의 노드는 get_global_mouse_position() 을 그대로 쓴다.
func _setup_view() -> void:
	var container := SubViewportContainer.new()
	container.name = "View"
	container.stretch = true
	container.stretch_shrink = VIEW_SCALE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.size = Vector2(VIEW_SIZE * VIEW_SCALE)
	container.position = Vector2.ZERO
	add_child(container)

	world_vp = SubViewport.new()
	world_vp.name = "World"
	world_vp.size = VIEW_SIZE
	world_vp.disable_3d = true
	world_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_vp.snap_2d_transforms_to_pixel = false                     # 이동·조명은 부드럽게 (그림만 픽셀)
	world_vp.use_hdr_2d = ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(world_vp)

	world = Node2D.new()
	world.name = "Stage"
	world_vp.add_child(world)


## 월드 좌표 → 창(루트 뷰포트) 좌표. AutoTest 의 마우스 워프 등에 쓴다.
func world_to_screen(p: Vector2) -> Vector2:
	var container := world_vp.get_parent() as Control
	return Vector2(world_vp.get_canvas_transform() * p) * float(VIEW_SCALE) + container.position


## 글로우(WorldEnvironment) + 풀스크린 후처리(색수차·비네트). 둘 다 저해상도 월드 뷰포트 안에 둔다.
## 2D 는 project.godot 의 hdr_2d 가 켜져야 글로우가 잡힌다.
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
	world_vp.add_child(we)

	var post_layer := CanvasLayer.new()
	post_layer.name = "PostFX"
	post_layer.layer = 9
	world_vp.add_child(post_layer)
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
	hint_label.text = "F1 로비    A/D ←/→ 이동    마우스 조준 · 좌클릭 사격    Space 구르기    Ctrl 앉기    W/↑ 정면문 진입    R 재장전    F2 공간감 A/B    F4 CRT 모니터    F11 전체화면"
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

	# 우상단: 공간감 프리셋 (이전/이후 A/B 비교 중 — 확정되면 제거)
	depth_label = Label.new()
	depth_label.position = Vector2(1600 - 24 - 1400, 18)
	depth_label.size = Vector2(1400, 200)
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	depth_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	depth_label.add_theme_font_override("font", font)
	depth_label.add_theme_font_size_override("font_size", 20)
	depth_label.add_theme_color_override("font_color", Color(0.62, 0.84, 0.86))
	layer.add_child(depth_label)
	_update_depth_label()

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
	_add_action("depth_toggle", [KEY_F2])   # 공간감 프리셋 이전/이후 A/B (비교 중)


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
