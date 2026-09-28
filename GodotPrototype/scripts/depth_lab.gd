extends "res://scripts/main.gd"
## 공간감 테스트 씬 (scenes/DepthLab.tscn) — 성격이 다른 다섯 공간을 한 줄로 이어 붙이고,
## 그레이박스 패럴렉스 레이어 · 명도 계단 · 깊이마다 다르게 닿는 조명 · 점프/사다리 동선 · 카메라 워킹을 본다.
## 설명: Docs/DEPTH_TEST_SCENE.md · 수치: depth_lab_data.gd · 도형: depth_lab_builder.gd · 발판: depth_lab_motion.gd · 조명: depth_lab_lights.gd
##
## 본편과 **같은 플레이 루프**(이동·조준·사격·구르기·크롤러·센트리건·버그봇)를 그대로 돌린다 (main.gd 상속).
## 방 타일은 숨기고(충돌·몬스터 벽 타기는 방 모양 그대로) 그 자리를 구역별 레이어가 채운다.
##
## 구역 레이어는 **구역마다 따로 잘린다**(clip_children). 구역 A 의 원경은 구역 A 의 월드 범위 안에서만 보이므로
## 먼 레이어가 느리게 흘러도 이웃 구역 배경이 섞여 들지 않고, 경계는 땅 레이어의 문틀이 덮는다.
##
## 조작 (본편 + 여기만):
##   W/↑ 점프 · 사다리 잡기 · 센트리건/버그봇 · S+W 발판 아래로 · 사다리 꼭대기에서 S 내려가기
##   [ ] 구역 이동 · C 카메라 워킹 · 1 2 3 패럴렉스 속도 · L 레이어 수 · V 명도만 · T 색온도 · Z 구역 줌 자동 · H 정보

const DD := preload("res://scripts/depth_lab_data.gd")
const DB := preload("res://scripts/depth_lab_builder.gd")

var speed_i := DD.SPEED_DEFAULT
var comp_i := DD.COMPOSITION_DEFAULT
var cam_i := DD.CAMERA_DEFAULT
var flat := false
var tint := false
var auto_zoom := true
var hud_on := true

var motion: DepthLabMotion
var lights: DepthLabLights
var clips := []                     # [구역][역할] → Polygon2D (clip)
var layers := []                    # [구역][역할] → DepthLayer
var fan: DepthLabFan
var ladder_nodes: Array = []
var _builder := DB.new()
var _zone := -1
var _feet_y := 0.0                  # 카메라가 따라가는 발 높이 (월드 y, 보간)
var _kick := Vector2.ZERO
var _punch := Vector2.ZERO
var _vel_lead := 0.0
var _t := 0.0
var _actor_sprites: Array = []
var _info: Array = []
var _legend: VBoxContainer
var _hud_font: Font

const ROLES_ALL := ["sky", "far3", "far2", "far1", "back", "ground", "front", "fg1", "fg2"]


func _ready() -> void:
	DD.register()
	AppFlow.start_room = DD.ROOM_ID
	AppFlow.resume_x = DD.SPAWN_X
	AppFlow.resume_facing = 1
	zoom_index = clampi(1 + int(DD.ZONES[0]["zoom"]), 0, ZOOM_PRESETS.size() - 1)
	super()
	# 방 그림은 숨긴다 — 충돌(RoomSolid)·몬스터·센트리건·기체·먼지는 그대로
	current_room.room_tiles.visible = false
	current_room.room_tiles.under.visible = false
	current_room.wall_shadow.visible = false
	current_room.foreground.visible = false
	current_room._ambient.color = Color.WHITE
	for l in [shadow_label, dyn_shadow_label, idle_label, mark_label]:
		if l:
			l.visible = false               # 본편 프리셋 표시는 이 씬의 범례와 겹친다 — 줌 표시만 남긴다

	motion = DepthLabMotion.new()
	motion.name = "DepthMotion"
	add_child(motion)
	motion.setup(player, current_room.floor_y, current_room.solid)
	_feet_y = current_room.floor_y

	lights = DepthLabLights.new()
	lights.name = "DepthLights"
	lights.camera = camera
	world.add_child(lights)

	_build_layers()
	_build_ladders()
	_build_lights()
	_rebuild()

	var post := _Stage.new()
	post.lab = self
	post.name = "DepthStage"
	post.process_priority = 11            # 카메라(10) 뒤 — 카메라 효과를 얹고 레이어를 맞춘다
	add_child(post)
	var frame := _Frame.new()
	frame.lab = self
	frame.name = "DepthFrame"
	frame.process_priority = 6            # 발판 물리(5) 뒤 · 카메라(10) 앞 — 세로 프레이밍
	add_child(frame)

	player.shoot_fired.connect(_on_lab_shot)
	for n in player.find_children("*", "", true, false):
		if (n is Sprite2D or n is AnimatedSprite2D) and n.name != "Flash":
			_actor_sprites.append(n)
	_apply_camera_preset()
	_build_hud()
	camera.room_top = NAN
	camera.snap()


# ── 레이어 ─────────────────────────────────────────────────────────────────────

func _build_layers() -> void:
	var top := -9000.0
	var bottom := float(current_room.floor_y) + 4000.0
	for zi in range(DD.ZONES.size()):
		var z: Dictionary = DD.ZONES[zi]
		var zc := {}
		var zl := {}
		for role in ROLES_ALL:
			var clip := Polygon2D.new()
			clip.name = "Clip_%s_%s" % [z["id"], role]
			var a := float(z["x0"]) - (1.0 if zi > 0 else 4000.0)
			var b := float(z["x1"]) + (1.0 if zi < DD.ZONES.size() - 1 else 4000.0)
			clip.polygon = PackedVector2Array([Vector2(a, top), Vector2(b, top), Vector2(b, bottom), Vector2(a, bottom)])
			clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
			clip.z_index = _role_z(role)
			world.add_child(clip)
			var l := DepthLayer.new()
			l.name = "Layer"
			l.role = role
			l.light_mask = DepthLabLights.zone_bit(zi)
			clip.add_child(l)
			zc[role] = clip
			zl[role] = l
		clips.append(zc)
		layers.append(zl)
		if z["id"] == "duct":
			fan = DepthLabFan.new()
			fan.name = "Fan"
			zl["far1"].add_child(fan)


func _role_z(role: String) -> int:
	if role == "front":
		return 11                        # 인물(5~6)·탄(6) 앞, 근경(12) 뒤
	return int(DD.ROLES[role]["z"])


func _factor(zi: int, role: String) -> float:
	if role == "ground" or role == "front":
		return 1.0
	return DD.factor(speed_i, role, zi)


func _rebuild() -> void:
	for zi in range(DD.ZONES.size()):
		for role in ROLES_ALL:
			_builder.build(layers[zi][role], zi, _factor(zi, role), flat, tint)
	if fan:
		var duct := _zone_by_id("duct")
		fan.position = DB.fan_local(_factor(duct, "far1"), DD.ZONES[duct])
		fan.flat = flat
		var tone: Dictionary = DD.ZONES[duct]["tone"]
		fan.housing = DD.base_value(tone, "far1") * 0.8
	lights.enabled_flat = flat
	_apply_composition()


func _apply_composition() -> void:
	var roles: Array = DD.COMPOSITIONS[comp_i]["roles"]
	for zi in range(DD.ZONES.size()):
		for role in ROLES_ALL:
			clips[zi][role].visible = role == "front" or roles.has(role)
	_update_hud()


func _zone_by_id(id: String) -> int:
	for i in range(DD.ZONES.size()):
		if DD.ZONES[i]["id"] == id:
			return i
	return 0


func _build_ladders() -> void:
	var props := current_room.get_node("Props")
	for l in DD.LADDERS:
		var node := Ladder.new()
		node.name = "DepthLadder"
		node.setup(float(l[0]), current_room.floor_y - float(l[1]), current_room.floor_y - float(l[2]) - 72.0)
		props.add_child(node)
		ladder_nodes.append(node)


## 구역 광원 — 역할마다 비율을 달리해 쪼갠다 (DepthLabLights)
func _build_lights() -> void:
	lights.clear_zone_lights()
	var fy := current_room.floor_y
	for zi in range(DD.ZONES.size()):
		var z: Dictionary = DD.ZONES[zi]
		var tone: Dictionary = z["tone"]
		var lamp: Color = tone["tint_lamp"] if tint else Color.WHITE
		var far: Color = tone["tint_far"] if tint else Color.WHITE
		var a := float(z["x0"])
		var w := float(z["x1"]) - a
		match String(z["id"]):
			"dock":
				for k in [0.2, 0.5, 0.8]:
					lights.add_light(zi, Vector2(a + w * k, fy + 900), 2300, 0.45,
						{"back": 0.6, "ground": 0.35, "far1": 0.5, "fg1": 0.4, "fg2": 0.3, "front": 0.4}, far, 0.12)
				lights.add_light(zi, Vector2(a + 220, fy - 594), 800, 0.7, {"ground": 1.0, "back": 0.6, "fg1": 0.3}, lamp, 0.45)
			"hangar":
				for fx in DB.flood_xs():
					lights.add_light(zi, Vector2(fx, fy - 1282), 1400, 0.7,
						{"ground": 1.0, "back": 0.55, "far1": 0.2, "far2": 0.06, "fg1": 0.35, "front": 0.5}, lamp, 0.5)
			"duct":
				for wx in DB.warning_xs():
					var pulse := func() -> float: return 0.55 + 0.45 * absf(sin(_t * 2.6 + wx))
					lights.add_light(zi, Vector2(wx, fy - 266), 800, 0.9, {"ground": 1.0, "back": 0.8, "fg1": 0.45, "front": 0.4},
						lamp, 0.5, pulse)
				lights.add_light(zi, Vector2(DB.FAN_X, fy - DB.FAN_H), 1200, 1.0,
					{"far1": 1.0, "back": 0.7, "ground": 0.8, "fg1": 0.35}, far, 0.55, fan.openness)
			"shaft":
				lights.add_light(zi, Vector2(a + w * 0.5, fy - 3300), 2600, 0.5,
					{"ground": 0.8, "back": 0.5, "far1": 0.35, "far2": 0.2, "fg1": 0.4}, far, 0.12)
				for p in DD.PLATFORMS:
					if String(p["look"]) == "ledge":
						var lx := (float(p["x0"]) + float(p["x1"])) * 0.5
						lights.add_light(zi, Vector2(lx, fy - float(p["h"]) - 190), 620, 0.55,
							{"ground": 1.0, "back": 0.6, "fg1": 0.3, "front": 0.4}, lamp, 0.45)
			"relay":
				for ux in DB.uplight_xs():
					lights.add_light(zi, Vector2(ux, fy + 30), 1300, 0.45,
						{"ground": 0.9, "back": 0.5, "far1": 0.3, "far2": 0.12, "fg1": 0.35, "fg2": 0.2, "front": 0.4}, lamp, 0.35)


# ── 매 프레임 ──────────────────────────────────────────────────────────────────

class _Frame extends Node:
	var lab

	func _process(delta: float) -> void:
		lab._frame_camera(delta)


class _Stage extends Node:
	var lab

	func _process(delta: float) -> void:
		lab._stage(delta)


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("zoom_cycle"):
		auto_zoom = false                    # F3 로 직접 고르면 구역 줌 자동은 쉰다 (Z 로 다시 켠다)
	super(delta)
	if current_room == null or player == null:
		return
	var zi := DD.zone_index(player.position.x)
	if zi != _zone:
		_zone = zi
		if auto_zoom:
			_set_zoom_index(clampi(1 + int(DD.ZONES[zi]["zoom"]), 0, ZOOM_PRESETS.size() - 1))
		_update_hud()
	_light_actors()
	_update_prompt()
	_update_live_hud()


## 세로 프레이밍 — 발판 높이를 따라 카메라 바닥선을 옮긴다. 세로 공간(frame 1)은 몸을 화면 가운데에 둔다
func _frame_camera(delta: float) -> void:
	if camera == null or motion == null:
		return
	var fy := current_room.floor_y
	var h := motion.g + (player.air_height() if player.is_climbing() else player.air_height() * 0.35)
	var want := fy - h
	var p: Dictionary = DD.CAMERA_PRESETS[cam_i]
	_feet_y = lerpf(_feet_y, want, 1.0 - exp(-float(p["y_speed"]) * delta))
	var vh := float(world_vp.size.y) / camera.zoom.y
	var fr := DD.zone_value(player.position.x, "frame")
	if not is_finite(camera.focus_x):
		camera.floor_y = _feet_y + fr * ((GameCamera.FLOOR_FRAC - 0.5) * vh - 140.0)
		camera.room_top = NAN


## 카메라 효과(반동·밀기·속도 앞보기·숨) 를 얹고, 레이어를 카메라에 맞춘다
func _stage(delta: float) -> void:
	var p: Dictionary = DD.CAMERA_PRESETS[cam_i]
	_kick = _kick * exp(-14.0 * delta)
	_punch = _punch * exp(-4.0 * delta)
	var vl := player.velocity_x * float(p["vel_lead"]) if not player.is_climbing() else 0.0
	_vel_lead = lerpf(_vel_lead, vl, 1.0 - exp(-3.0 * delta))
	var drift := float(p["drift"])
	var extra := _kick + _punch + Vector2(_vel_lead, 0.0) + Vector2(sin(_t * 0.37) * drift, sin(_t * 0.23 + 1.0) * drift * 0.6)
	camera.offset += extra
	# 쏘는 동안 리드를 늘린다 (조준 밀기)
	var want := p
	if Input.is_action_pressed("shoot") and float(p["hold"]) != 1.0 and controlled_turret == null:
		want = _held(p)
	if camera.preset != want:
		camera.preset = want
	_place_layers()


var _held_cache := {}
func _held(p: Dictionary) -> Dictionary:
	if _held_cache.get("_src", "") != p["id"]:
		var h := float(p["hold"])
		_held_cache = p.duplicate()
		_held_cache["_src"] = p["id"]
		_held_cache["mouse_weight"] = float(p["mouse_weight"]) * h
		_held_cache["mouse_max_x"] = float(p["mouse_max_x"]) * h
		_held_cache["mouse_max_y"] = float(p["mouse_max_y"]) * h
	return _held_cache


func _place_layers() -> void:
	var c := camera.get_screen_center_position()
	var z := camera.zoom.x
	var fy := current_room.floor_y
	var vis := Vector2(world_vp.size) / z
	for zi in range(DD.ZONES.size()):
		var zd: Dictionary = DD.ZONES[zi]
		var near := c.x + vis.x * 0.5 > float(zd["x0"]) - 200.0 and c.x - vis.x * 0.5 < float(zd["x1"]) + 200.0
		var ax := DB.anchor_x(zd)
		for role in ROLES_ALL:
			var clip: Polygon2D = clips[zi][role]
			var l: DepthLayer = layers[zi][role]
			var show: bool = near and (role == "front" or (DD.COMPOSITIONS[comp_i]["roles"] as Array).has(role))
			clip.visible = show
			if not show:
				continue
			var f := _factor(zi, role)
			var pos := Vector2((c.x - ax) * (1.0 - f), fy + (c.y - (fy + DB.AY)) * (1.0 - f))
			l.position = (pos * z).round() / z


## 인물·몬스터·센트리건·기체·사다리가 받는 밝기 (구역 기본 + 광원 거리)
func _light_actors() -> void:
	var fy := current_room.floor_y
	var v := lights.actor_light(player.position + Vector2(0, -140), fy)
	var col := Color(v, v, v)
	for s in _actor_sprites:
		if is_instance_valid(s):
			s.self_modulate = col
	for m in current_room.monsters:
		if is_instance_valid(m):
			var k := lights.actor_light(m.position + Vector2(0, -60), fy)
			m.modulate = Color(k, k, k)
	for t in current_room.sentries + current_room.walkers:
		if is_instance_valid(t):
			var k := lights.actor_light(t.position + Vector2(0, -120), fy)
			t.modulate = Color(k, k, k)
	for i in range(ladder_nodes.size()):
		var l: Array = DD.LADDERS[i]
		var k := lights.actor_light(Vector2(float(l[0]), fy - (float(l[1]) + float(l[2])) * 0.5), fy)
		ladder_nodes[i].modulate = Color(k, k, k)


# ── 입력 · 본편 훅 ─────────────────────────────────────────────────────────────

## W/↑ — 공중이면 사다리만 · S+W 발판 아래로 · 바닥이면 센트리건/기체 · 사다리 · 점프(머리 위 여유가 있을 때만)
func _on_front_door_requested() -> void:
	if transitioning or current_room == null:
		return
	if player.is_airborne():
		_grab_ladder()
		return
	if Input.is_action_pressed("crouch") and motion.can_drop():
		motion.drop()
		return
	if motion.g < 1.0 and (current_room.sentry_near(player.position.x) != null or current_room.walker_near(player.position.x) != null):
		super()
		return
	if _grab_ladder():
		return
	if motion.can_jump():
		player.jump()


func _grab_ladder() -> bool:
	if motion == null:
		return false
	var l := motion.ladder_near()
	if l.is_empty():
		return false
	motion.start_climb(l)
	return player.is_climbing()


## 몬스터 근접 공격은 x 거리로만 판정된다 — 높은 발판 위에 있으면 아래층 몬스터의 공격은 닿지 않는다
func _on_player_hit(point: Vector2, dir: float) -> void:
	if motion != null and motion.g > 120.0 and absf(point.y - player.position.y) > 220.0:
		return
	super(point, dir)


func _on_lab_shot(muzzle_pos: Vector2, target_pos: Vector2) -> void:
	var p: Dictionary = DD.CAMERA_PRESETS[cam_i]
	var dir := (target_pos - muzzle_pos).normalized()
	_kick -= dir * float(p["kick"])
	_punch = (_punch + dir * float(p["punch"])).limit_length(140.0)


func _set_zoom_index(i: int) -> void:
	if i == zoom_index:
		return
	zoom_index = i
	_update_zoom_label()
	if camera == null or dialogue.active or terminal_screen.is_open() or controlled_turret != null:
		return
	var to := _base_zoom()
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(to, to), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _apply_camera_preset() -> void:
	camera.preset = DD.CAMERA_PRESETS[cam_i]
	camera._apply_limits()
	_update_hud()


func _teleport_zone(zi: int) -> void:
	var z: Dictionary = DD.ZONES[zi]
	if controlled_turret != null:
		controlled_turret.set_controlled(false)
	player.position.x = float(z["x0"]) + 420.0
	player.velocity_x = 0.0
	player.settle()
	motion.snap_to_ground(0.0)
	_feet_y = current_room.floor_y
	camera.snap()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or current_room == null:
		return
	if dialogue.active or terminal_screen.is_open():
		return
	var back := key.shift_pressed
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			speed_i = key.keycode - KEY_1
			_rebuild()
		KEY_L:
			comp_i = wrapi(comp_i + (-1 if back else 1), 0, DD.COMPOSITIONS.size())
			_apply_composition()
		KEY_V:
			flat = not flat
			_rebuild()
		KEY_T:
			tint = not tint
			_rebuild()
			_build_lights()
		KEY_C:
			cam_i = wrapi(cam_i + (-1 if back else 1), 0, DD.CAMERA_PRESETS.size())
			_apply_camera_preset()
		KEY_BRACKETRIGHT, KEY_BRACKETLEFT:
			var zi := DD.zone_index(player.position.x)
			_teleport_zone(clampi(zi + (1 if key.keycode == KEY_BRACKETRIGHT else -1), 0, DD.ZONES.size() - 1))
		KEY_Z:
			auto_zoom = not auto_zoom
			if auto_zoom:
				_set_zoom_index(clampi(1 + int(DD.ZONES[DD.zone_index(player.position.x)]["zoom"]), 0, ZOOM_PRESETS.size() - 1))
			_update_hud()
		KEY_H:
			hud_on = not hud_on
			for l in _info:
				l.visible = hud_on
			_legend.visible = hud_on
		_:
			return
	get_viewport().set_input_as_handled()


# ── 정보 표시 ──────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud_font = SystemFont.new()
	_hud_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	var layer := get_node("UI") as CanvasLayer
	var colors := [Color(1.0, 0.86, 0.55), Color(0.85, 0.9, 1.0), Color(0.72, 0.9, 1.0), Color(0.75, 1.0, 0.78)]
	for i in range(colors.size()):
		var l := Label.new()
		l.position = Vector2(24, 58 + 28 * i)
		l.add_theme_font_override("font", _hud_font)
		l.add_theme_font_size_override("font_size", 19 if i > 0 else 22)
		l.add_theme_color_override("font_color", colors[i])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		layer.add_child(l)
		_info.append(l)
	_legend = VBoxContainer.new()
	_legend.anchor_left = 1.0
	_legend.anchor_right = 1.0
	_legend.offset_left = -300
	_legend.offset_right = -20
	_legend.offset_top = 150
	_legend.add_theme_constant_override("separation", 3)
	layer.add_child(_legend)
	hint_label.text = "F1 로비   A/D 이동 · Shift 달리기 · Space 구르기 · 좌클릭 사격   W/↑ 점프·사다리·센트리건·버그봇   S+W 발판 아래로   [ ] 구역   C 카메라   1 2 3 속도   L 레이어   V 명도만   T 색온도   Z 구역 줌   H 정보   F3 줌"
	_update_hud()


func _hud_label(text: String, color: Color, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _hud_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _update_hud() -> void:
	if _info.is_empty() or player == null:
		return
	var zi := DD.zone_index(player.position.x)
	var z: Dictionary = DD.ZONES[zi]
	var cp: Dictionary = DD.CAMERA_PRESETS[cam_i]
	_info[0].text = "[%d/%d] %s  (%s 축)  —  %s" % [zi + 1, DD.ZONES.size(), z["name"], z["axis"], z["desc"]]
	_info[1].text = "[C] 카메라  %s — %s" % [cp["name"], cp["desc"]]
	_info[2].text = "[1 2 3] 속도 %s · [L] 레이어 %s · [V] 명도만 %s · [T] 색온도 %s · [Z] 구역 줌 %s" % [
		DD.SPEED_PRESETS[speed_i]["name"], DD.COMPOSITIONS[comp_i]["name"],
		"켬" if flat else "끔", "켬" if tint else "끔", "자동" if auto_zoom else "수동"]
	for c in _legend.get_children():
		c.queue_free()
	_legend.add_child(_hud_label("레이어 (앞 → 뒤)   계수   명도", Color(0.85, 0.85, 0.88), 16))
	var roles: Array = (DD.COMPOSITIONS[comp_i]["roles"] as Array).duplicate()
	roles.reverse()
	for role in roles:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var v := DD.base_value(z["tone"], role)
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(40, 20)
		sw.color = Color(v, v, v)
		row.add_child(sw)
		row.add_child(_hud_label("%s  ×%.2f  %d%%" % [DD.ROLES[role]["name"], _factor(zi, role), roundi(v * 100.0)],
			Color(1.0, 0.86, 0.55) if role == "ground" else Color(0.92, 0.92, 0.95)))
		_legend.add_child(row)


func _update_live_hud() -> void:
	if _info.size() < 4:
		return
	var state := "사다리" if player.is_climbing() else ("공중" if player.is_airborne() else ("기어가기" if motion.crawling else "지면"))
	_info[3].text = "발 높이 %d px · %s · 인물 밝기 %d%% · 몬스터 %d · 웨이브 %d" % [
		int(motion.total()), state, roundi(lights.actor_light(player.position + Vector2(0, -140), current_room.floor_y) * 100.0),
		current_room.alive_monsters(), current_room.wave_index]


func _update_prompt() -> void:
	if walker_link.busy() or controlled_turret != null:
		return
	if player.is_climbing():
		prompt_label.visible = true
		prompt_label.text = "W / ↑  오르기   ·   S / ↓  내리기   ·   A / D  손 놓기"
		return
	if motion.g > 1.0 or current_room.sentry_near(player.position.x) == null and current_room.walker_near(player.position.x) == null:
		if not motion.ladder_near().is_empty():
			prompt_label.visible = true
			prompt_label.text = "▲  W / ↑  —  사다리"
		elif motion.can_drop():
			prompt_label.visible = true
			prompt_label.text = "S + W  —  아래로 내려서기"
		elif motion.crawling:
			prompt_label.visible = true
			prompt_label.text = "기어가는 구간 — 웅크린 채 A / D"
		elif motion.g > 1.0:
			prompt_label.visible = false
