extends Node2D
## 조명·그림자 랩 (2026-09-20). **마우스 포인터가 곧 광원**인 그레이박스 실험실.
## 실제 방·자산 없이 회색 상자·공·기둥만 세워 두고, 광원을 손으로 끌고 다니며
## "빛과 물체의 각도 → 그림자" 가 어떻게 만들어지는지 눈으로 보고 그 자리에서 수치를 고친다.
##
## 실제 게임과 **같은 코드**(PropShadow)를 쓴다 — 랩에서 맞춘 값이 그대로 본편에 적용된다.
## PropShadow.WEDGE / DYN_WEDGE 가 static var 인 이유가 이것이다. 값이 확정되면 P 로 찍어 prop_shadow.gd 에 적는다.
##
## 그레이박스 텍스처는 **일부러 투명 여백을 넣어** 만든다 — 실제 자산도 여백이 수십 px 씩 있고,
## 그림자 상자를 텍스처 크기로 잡으면 물체보다 크고 높은 데서 시작하는 버그가 났던 자리다.
## 랩에서 그 경로(Image.get_used_rect)를 늘 같이 검증한다.
##
## 조작
##   마우스        광원 위치            Space 광원 고정/해제 (손을 떼고 관찰)
##   좌클릭        **사격** — 마우스 자리에서 총구 화염이 번쩍인다. 누르고 있으면 연사(게임과 같은 0.09초 간격).
##                 총구 화염만 Lighting.register_dynamic 에 등록돼 있으므로, F8(동적) 그림자는 **쏠 때만** 반응한다.
##   휠            광원 반경            Shift+휠 세기        Ctrl+휠 높이(height)
##   L             천장 보조 램프 켜기/끄기 (광원 2개일 때 그림자가 어떻게 갈라지는지)
##   H             기하 디버그 — 노란 광선 · 빨강 이론값(자르기 전) · 하늘색 실제 그려진 삼각형
##   F6/Shift+F6   기본 그림자 프리셋 (붙박이 광원 경로)
##   F8/Shift+F8   동적 광원 프리셋 (총구 화염 경로 — 물체보다 낮은 광원도 센다)
##   Q/A  세기(alpha)     W/S  최소 길이 비율     E/D  최대 길이 비율
##   R/F  꼭짓점 진하기   T/G  끝점 진하기
##   Z             수치 초기화
##   Ctrl+S        **저장** — shadow/tuning.json 에 쓴다. 본편이 방을 만들 때 읽으므로 그대로 적용된다.
##   Ctrl+R        저장 파일 무시하고 코드 기본값으로 되돌리기
##   P             현재 수치를 콘솔에 출력 (prop_shadow.gd 에 직접 적고 싶을 때)
##   F1            로비

const PropShadow := preload("res://scripts/prop_shadow.gd")

const FLOOR_Y := 700.0
const WALL_TOP := 90.0
const PAD := 20.0                       # 그레이박스 텍스처에 일부러 넣는 투명 여백 (실제 자산 흉내)
const AMBIENT := Color(0.30, 0.32, 0.42)

## 그레이박스 프랍 — 높이·폭·모양이 고루 섞이게 (그림자 길이는 높이에 비례하므로 높이 차가 중요하다)
const PROPS := [
	{"x": 260.0, "w": 130.0, "h": 110.0, "round": false, "name": "낮은 상자"},
	{"x": 560.0, "w": 210.0, "h": 300.0, "round": false, "name": "큰 상자"},
	{"x": 880.0, "w": 190.0, "h": 190.0, "round": true, "name": "공"},
	{"x": 1240.0, "w": 420.0, "h": 90.0, "round": false, "name": "낮고 긴 것"},
	{"x": 1620.0, "w": 70.0, "h": 380.0, "round": false, "name": "얇은 기둥"},
	{"x": 1950.0, "w": 240.0, "h": 200.0, "round": true, "name": "큰 공"},
]

## 사격 — 게임(player.gd)과 같은 규격
const FIRE_COOLDOWN := 0.09             # Player.FIRE_COOLDOWN (≈11발/초)
const FLASH_TIME := 0.055               # 총구 화염이 켜져 있는 시간
## 게임의 player.gd muzzle_light 과 같은 값 (energy 1.8 · texture_scale 2.2 ≈ 반경 563)
const MUZZLE_ENERGY := 1.8
const MUZZLE_RADIUS := 563.0

const DEFAULT_WEDGE := {"alpha": 0.58, "top": 0.20, "tip": 0.04, "min_ratio": 0.12, "max_ratio": 1.2, "count": 2}

var _shadows: Node2D                    # PropShadow
var _mouse_light: PointLight2D
var _lamp: PointLight2D                 # 천장 보조 램프 (L)
var _debug: Node2D
var _casters: Array = []                # {"node", "lx", "rx", "ty", "name"} — 디버그 오버레이용
var _light_pos := Vector2(1120.0, 200.0)
var _frozen := false
var _radius := 900.0
var _energy := 1.6
var _height := 120.0
var _show_debug := true
var _info: Label
var _muzzle: PointLight2D                # 총구 화염 — 평소 꺼져 있고 쏠 때만 켜진다 (동적 광원)
var _flash_sprite: Sprite2D
var _firing := false
var _fire_cd := 0.0
var _flash_t := 0.0
var _shots := 0
var _msg := ""
var _msg_t := 0.0

## 스윕 캡처: 환경변수 SHADOW_LAB_SHOTS=1 로 실행하면 광원을 아래 자리들에 차례로 놓고
## user://shots/lab_<번호>_<이름>.png 를 저장한 뒤 종료한다. 각도별 그림자를 나란히 놓고 비교하는 용도.
const SWEEP := [
	# 상하 반응 확인용 — 같은 X 에서 광원 **높이만** 바꾼다 (벽 드리움이 위아래로 움직여야 한다)
	{"n": "v1_x900_top", "p": Vector2(900, 120)},
	{"n": "v2_x900_mid", "p": Vector2(900, 330)},
	{"n": "v3_x900_low", "p": Vector2(900, 620)},
	{"n": "01_high_left", "p": Vector2(180, 150)},
	{"n": "02_high_mid", "p": Vector2(880, 150)},
	{"n": "03_overhead_box", "p": Vector2(560, 130)},
	{"n": "04_high_right", "p": Vector2(2080, 150)},
	{"n": "05_low_left_graze", "p": Vector2(120, 600)},
	{"n": "06_mid_between", "p": Vector2(720, 420)},
	{"n": "07_close_low_right", "p": Vector2(1450, 630)},
]
var _sweep := -1
var _sweep_t := 0.0
var _tag := ""


func _ready() -> void:
	_setup_world()
	_setup_ui()
	_add_actions()
	# 수치 후보를 환경변수로 밀어 넣어 같은 광원 자리에서 A/B 캡처한다:
	#   SHADOW_LAB_TUNE="alpha,top,tip,min_ratio,max_ratio"   SHADOW_LAB_TAG="후보이름"
	var tune := OS.get_environment("SHADOW_LAB_TUNE")
	if tune != "":
		var v := tune.split(",")
		var keys := ["alpha", "top", "tip", "min_ratio", "max_ratio"]
		for i in mini(v.size(), keys.size()):
			PropShadow.WEDGE[keys[i]] = float(v[i])
	_tag = OS.get_environment("SHADOW_LAB_TAG")
	var preset := OS.get_environment("SHADOW_LAB_PRESET")
	if preset != "":
		_shadows.apply(int(preset))
	var dyn := OS.get_environment("SHADOW_LAB_DYN")
	if dyn != "":
		_shadows.apply_dynamic(int(dyn))
	if OS.get_environment("SHADOW_LAB_SHOTS") != "":
		_sweep = 0
		_frozen = true
		_show_debug = OS.get_environment("SHADOW_LAB_NODEBUG") == ""
		DirAccess.make_dir_recursive_absolute("user://shots")
	set_process(true)


func _setup_world() -> void:
	var amb := CanvasModulate.new()
	amb.name = "Ambient"
	amb.color = AMBIENT
	add_child(amb)

	# 배경: 뒷벽 + 바닥 띠. 기본 머티리얼이라 2D 라이트를 그대로 받는다.
	_panel("BackWall", Color(0.62, 0.63, 0.68), Vector2(0, WALL_TOP),
		Vector2(AppFlow.VIEW_SIZE.x, FLOOR_Y - WALL_TOP), 0)
	# 벽돌 눈금 — 그림자 경계가 어디에 걸리는지 읽기 위한 격자
	for gy in range(int(WALL_TOP) + 80, int(FLOOR_Y), 80):
		_panel("Grid", Color(0, 0, 0, 0.10), Vector2(0, gy), Vector2(AppFlow.VIEW_SIZE.x, 2), 0)
	# 바닥 띠는 **프랍 층(z2)보다 뒤**에 둔다 — 본편은 바닥이 타일맵(z0)이라 그림자가 그 위에 그려진다.
	# 앞에 두면 바닥에 깔리는 그림자(광원 블롭·접촉 띠)가 통째로 가려져 랩에서 보이지 않는다.
	_panel("Floor", Color(0.46, 0.47, 0.52), Vector2(0, FLOOR_Y),
		Vector2(AppFlow.VIEW_SIZE.x, AppFlow.VIEW_SIZE.y - FLOOR_Y), 1)

	var lights := Node2D.new()
	lights.name = "Lights"
	add_child(lights)

	_mouse_light = PointLight2D.new()
	_mouse_light.name = "MouseLight"
	_mouse_light.texture = Lighting.radial_texture()
	_mouse_light.texture_scale = Lighting.scale_for_radius(_radius)
	_mouse_light.color = Color(1.0, 0.92, 0.78)
	_mouse_light.energy = _energy
	_mouse_light.height = _height
	_mouse_light.position = _light_pos
	lights.add_child(_mouse_light)
	# 마우스 광원은 **붙박이 광원** 취급이다 (F6 기본 그림자 경로). 동적으로 등록하지 않는 이유:
	# 등록하면 가만히 있어도 동적 그림자가 늘 켜져 있어 "쏠 때만 반응" 을 볼 수 없다.

	# 총구 화염 — 좌클릭할 때만 번쩍인다. 이것만 동적 광원이라 F8 그림자는 사격에만 반응한다.
	_muzzle = PointLight2D.new()
	_muzzle.name = "MuzzleLight"
	_muzzle.texture = Lighting.radial_texture()
	_muzzle.texture_scale = Lighting.scale_for_radius(MUZZLE_RADIUS)
	_muzzle.color = Lighting.GUN_LIGHT
	_muzzle.energy = MUZZLE_ENERGY
	_muzzle.height = Lighting.FLASH_HEIGHT
	_muzzle.enabled = false
	lights.add_child(_muzzle)
	Lighting.register_dynamic(_muzzle, 1.6, "shot")          # 게임의 플레이어 총구와 같은 가중치

	_flash_sprite = Sprite2D.new()
	_flash_sprite.name = "MuzzleFlash"
	_flash_sprite.texture = Lighting.radial_texture()
	_flash_sprite.scale = Vector2.ONE * (110.0 / float(Lighting.TEX_SIZE))
	_flash_sprite.self_modulate = Lighting.RED_EMISSIVE_SOFT
	_flash_sprite.visible = false
	var fm := CanvasItemMaterial.new()
	fm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash_sprite.material = fm
	_flash_sprite.z_index = 6
	add_child(_flash_sprite)

	_lamp = PointLight2D.new()
	_lamp.name = "CeilingLamp"
	_lamp.texture = Lighting.radial_texture()
	_lamp.texture_scale = Lighting.scale_for_radius(800.0)
	_lamp.color = Color(0.72, 0.84, 1.0)
	_lamp.energy = 1.1
	_lamp.height = 140.0
	_lamp.position = Vector2(AppFlow.VIEW_SIZE.x * 0.5, WALL_TOP + 40.0)
	_lamp.enabled = false
	lights.add_child(_lamp)

	var props := Node2D.new()
	props.name = "Props"
	props.z_index = 2
	add_child(props)

	_shadows = PropShadow.new()
	_shadows.setup(FLOOR_Y, float(AppFlow.VIEW_SIZE.x))
	props.add_child(_shadows)           # 프랍 층 첫 자식 = 모든 프랍보다 뒤

	for p in PROPS:
		_add_greybox(props, p)

	_shadows.build(lights, PropShadow.index)

	_debug = Node2D.new()
	_debug.name = "DebugGeometry"
	_debug.z_index = 6
	_debug.draw.connect(_draw_debug)
	add_child(_debug)


## 배경 판때기(뒷벽·격자·바닥). **mouse_filter 를 반드시 IGNORE 로 둔다** —
## ColorRect 의 기본값은 STOP 이라, 화면을 덮는 뒷벽이 좌클릭을 통째로 삼켜
## _unhandled_input 까지 내려오지 않는다 (사격이 안 먹던 원인).
func _panel(name_: String, color: Color, pos: Vector2, size: Vector2, z: int) -> ColorRect:
	var r := ColorRect.new()
	r.name = name_
	r.color = color
	r.position = pos
	r.size = size
	r.z_index = z
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## 그레이박스 프랍 하나. 실제 자산처럼 사방에 PAD 만큼 투명 여백을 넣어 만든다.
func _add_greybox(parent: Node2D, p: Dictionary) -> void:
	var bw := float(p["w"])
	var bh := float(p["h"])
	var tex := _greybox_texture(bw, bh, bool(p["round"]))
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var s := Sprite2D.new()
	s.name = "Greybox_" + str(p["name"])
	s.centered = false
	s.texture = tex
	s.offset = Vector2(-tw * 0.5, -th)                  # 원점 = 텍스처 바닥 중심 (HitProp 과 같은 규약)
	# 불투명 바닥(= 텍스처 바닥에서 PAD 위)이 바닥선에 닿도록 원점을 PAD 만큼 내린다
	s.position = Vector2(float(p["x"]), FLOOR_Y + PAD)
	parent.add_child(s)
	_shadows.add_caster(s, tex)
	_casters.append({"node": s, "name": p["name"],
		"lx": -bw * 0.5, "rx": bw * 0.5, "ty": -(bh + PAD)})


## 회색 상자/공 텍스처. 위쪽이 조금 밝아 입체가 읽히고, 테두리가 어두워 실루엣이 또렷하다.
static func _greybox_texture(bw: float, bh: float, round_shape: bool) -> ImageTexture:
	var w := int(bw + PAD * 2.0)
	var h := int(bh + PAD * 2.0)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w * 0.5
	var cy := PAD + bh * 0.5
	for y in range(h):
		for x in range(w):
			var inside := false
			if round_shape:
				var nx := (x + 0.5 - cx) / (bw * 0.5)
				var ny := (y + 0.5 - cy) / (bh * 0.5)
				inside = nx * nx + ny * ny <= 1.0
			else:
				inside = x >= PAD and x < PAD + bw and y >= PAD and y < PAD + bh
			if not inside:
				continue
			# 위 → 아래로 옅은 그라데이션 + 가장자리 어둡게
			var t := clampf((float(y) - PAD) / maxf(bh, 1.0), 0.0, 1.0)
			var v := lerpf(0.82, 0.55, t)
			var edge := minf(minf(float(x) - PAD, PAD + bw - float(x)), minf(float(y) - PAD, PAD + bh - float(y)))
			if edge < 3.0:
				v *= 0.55
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return ImageTexture.create_from_image(img)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.layer = 10
	add_child(layer)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 0.82)
	bg.position = Vector2(18, 14)
	bg.size = Vector2(880, 250)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	_info = Label.new()
	_info.position = Vector2(32, 24)
	_info.size = Vector2(860, 234)
	_info.add_theme_font_override("font", font)
	_info.add_theme_font_size_override("font_size", 19)
	_info.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_info)

	var keys := Label.new()
	keys.position = Vector2(24, AppFlow.VIEW_SIZE.y - 66)
	keys.size = Vector2(AppFlow.VIEW_SIZE.x - 48, 60)
	keys.add_theme_font_override("font", font)
	keys.add_theme_font_size_override("font_size", 18)
	keys.add_theme_color_override("font_color", Color(0.68, 0.72, 0.82))
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.text = "좌클릭 사격(누르면 연사)   ·   마우스 광원   ·   Space 고정   ·   휠 반경 / Shift+휠 세기 / Ctrl+휠 높이   ·   L 천장 램프   ·   H 기하 디버그   ·   F6·F8 프리셋   ·   Q/A 세기   W/S 최소길이   E/D 최대길이   R/F 꼭짓점   T/G 끝점   ·   Z 초기화   Ctrl+S 저장(본편 적용)   P 수치 출력   ·   F1 로비"
	layer.add_child(keys)


func _add_actions() -> void:
	if not InputMap.has_action("to_lobby"):
		InputMap.add_action("to_lobby")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F1
		InputMap.action_add_event("to_lobby", ev)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("to_lobby"):
		AppFlow.go_lobby(get_tree())
		return
	if _sweep >= 0:
		_run_sweep(_delta)
		return
	if not _frozen:
		_light_pos = get_global_mouse_position()
	_mouse_light.position = _light_pos
	_tick_gun(_delta)
	if _msg_t > 0.0:
		_msg_t -= _delta
	_debug.queue_redraw()
	_update_info()


## 사격: 누르고 있으면 FIRE_COOLDOWN 간격으로 연사한다 (게임의 player.gd 와 같은 규칙).
## 총구 화염은 **현재 마우스 자리**에서 터지므로, 마우스를 휘두르며 연사하면 그림자가 그 궤적을 따라 돈다.
func _tick_gun(delta: float) -> void:
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	if _firing and _fire_cd <= 0.0:
		_fire_cd = FIRE_COOLDOWN
		_flash_t = FLASH_TIME
		_shots += 1
	if _flash_t > 0.0:
		_flash_t -= delta
		_muzzle.position = _light_pos                # 쏘는 동안 총구는 마우스를 따라간다
		_muzzle.enabled = true
		# 짧게 튀었다 꺼진다 — 세기가 일정하면 연사 중 그림자가 붙박여 보인다
		_muzzle.energy = MUZZLE_ENERGY * (0.55 + 0.45 * (_flash_t / FLASH_TIME)) * randf_range(0.85, 1.15)
		_flash_sprite.position = _light_pos
		_flash_sprite.visible = true
		if _flash_t <= 0.0:
			_muzzle.enabled = false
			_flash_sprite.visible = false


## 스윕 한 칸: 광원을 옮기고 몇 프레임 뒤 화면을 저장한다 (PropShadow 가 자리를 잡을 시간을 준다).
func _run_sweep(delta: float) -> void:
	if _sweep >= SWEEP.size():
		print("SHADOW LAB SWEEP DONE")
		get_tree().quit()
		return
	var step: Dictionary = SWEEP[_sweep]
	_light_pos = step["p"]
	_mouse_light.position = _light_pos
	_debug.queue_redraw()
	_update_info()
	_sweep_t += delta
	if _sweep_t < 0.25:
		return
	_sweep_t = 0.0
	# SHADOW_LAB_FIRE=1 이면 캡처 순간에 총구 화염을 강제로 켠다 (동적 그림자를 사진에 담기 위해)
	if OS.get_environment("SHADOW_LAB_FIRE") != "":
		_flash_t = FLASH_TIME
		_tick_gun(0.0)
		for _i in range(30):                         # 추종(attack)이 따라붙을 시간을 준다
			_shadows._process(1.0 / 60.0)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	img.save_png("user://shots/lab_%s%s.png" % [step["n"], ("_" + _tag) if _tag != "" else ""])
	print("LAB SHOT %s  light=(%.0f, %.0f)" % [step["n"], _light_pos.x, _light_pos.y])
	_sweep += 1


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_firing = (e as InputEventMouseButton).pressed
		if _firing:
			_fire_cd = 0.0                           # 첫 발은 즉시
		return
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		var dir := 0.0
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dir = 1.0
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dir = -1.0
		if dir != 0.0:
			if mb.shift_pressed:
				_energy = clampf(_energy + dir * 0.15, 0.1, 6.0)
				_mouse_light.energy = _energy
			elif mb.ctrl_pressed:
				_height = clampf(_height + dir * 15.0, 0.0, 400.0)
				_mouse_light.height = _height
			else:
				_radius = clampf(_radius + dir * 80.0, 160.0, 3000.0)
				_mouse_light.texture_scale = Lighting.scale_for_radius(_radius)
			return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := (e as InputEventKey).physical_keycode
	var shift := (e as InputEventKey).shift_pressed
	var W: Dictionary = PropShadow.WEDGE
	match k:
		KEY_SPACE: _frozen = not _frozen
		KEY_H: _show_debug = not _show_debug
		KEY_L:
			_lamp.enabled = not _lamp.enabled
		KEY_F6:
			_shadows.apply(PropShadow.index + (-1 if shift else 1))
		KEY_F8:
			_shadows.apply_dynamic(PropShadow.dyn_index + (-1 if shift else 1))
		KEY_Q: W["alpha"] = clampf(float(W["alpha"]) - 0.02, 0.0, 1.0)
		KEY_A: W["alpha"] = clampf(float(W["alpha"]) + 0.02, 0.0, 1.0)
		KEY_W: W["min_ratio"] = clampf(float(W["min_ratio"]) - 0.02, 0.0, 2.0)
		KEY_S: W["min_ratio"] = clampf(float(W["min_ratio"]) + 0.02, 0.0, 2.0)
		KEY_E: W["max_ratio"] = clampf(float(W["max_ratio"]) - 0.1, 0.1, 8.0)
		KEY_D: W["max_ratio"] = clampf(float(W["max_ratio"]) + 0.1, 0.1, 8.0)
		KEY_R: W["top"] = clampf(float(W["top"]) - 0.03, 0.0, 1.0)
		KEY_F: W["top"] = clampf(float(W["top"]) + 0.03, 0.0, 1.0)
		KEY_T: W["tip"] = clampf(float(W["tip"]) - 0.02, 0.0, 1.0)
		KEY_G: W["tip"] = clampf(float(W["tip"]) + 0.02, 0.0, 1.0)
		KEY_Z:
			for key in DEFAULT_WEDGE:
				W[key] = DEFAULT_WEDGE[key]
			_flash_msg("각도 그림자 수치를 기본값으로 되돌림")
		KEY_S when (e as InputEventKey).ctrl_pressed:
			var path := PropShadow.save_tuning()
			_flash_msg("저장됨 — %s" % path if path != "" else "저장 실패 (콘솔 확인)")
		KEY_R when (e as InputEventKey).ctrl_pressed:
			for key in DEFAULT_WEDGE:
				W[key] = DEFAULT_WEDGE[key]
			_flash_msg("코드 기본값으로 되돌림 — Ctrl+S 로 저장해야 본편에 반영됩니다")
		KEY_P:
			print('static var WEDGE := {\n\t"alpha": %.2f, "top": %.2f, "tip": %.2f,\n\t"min_ratio": %.2f, "max_ratio": %.2f, "count": %d,\n}' % [
				W["alpha"], W["top"], W["tip"], W["min_ratio"], W["max_ratio"], W["count"]])


## 저장 등 한 줄 알림을 잠깐 띄운다
func _flash_msg(text: String) -> void:
	_msg = text
	_msg_t = 3.0


func _update_info() -> void:
	var W: Dictionary = PropShadow.WEDGE
	var bp: Dictionary = PropShadow.BASE_PRESETS[PropShadow.index]
	var dp: Dictionary = PropShadow.DYN_PRESETS[PropShadow.dyn_index]
	_info.text = "조명·그림자 랩 (그레이박스)   —   마우스가 광원%s\n" % ("   [고정됨 · Space 해제]" if _frozen else "")
	_info.text += "광원  (%.0f, %.0f)   반경 %.0f   세기 %.2f   높이 %.0f   ·   바닥선 y=%.0f   ·   천장 램프 %s\n" % [
		_light_pos.x, _light_pos.y, _radius, _energy, _height, FLOOR_Y, "켜짐" if _lamp.enabled else "꺼짐"]
	_info.text += "기본 그림자 (F6) %d/%d  %s\n동적 광원 (F8) %d/%d  %s\n" % [
		PropShadow.index + 1, PropShadow.BASE_PRESETS.size(), bp["name"],
		PropShadow.dyn_index + 1, PropShadow.DYN_PRESETS.size(), dp["name"]]
	_info.text += "각도 그림자 수치 —  세기 %.2f (Q/A)   최소길이 ×%.2f (W/S)   최대길이 ×%.2f (E/D)   꼭짓점 %.2f (R/F)   끝점 %.2f (T/G)\n" % [
		W["alpha"], W["min_ratio"], W["max_ratio"], W["top"], W["tip"]]
	_info.text += "사격 (좌클릭 · 누르면 연사)  %s   발사 %d발
" % [
		"발사 중" if _firing else "대기", _shots]
	if _msg_t > 0.0:
		_info.text += "▸ %s
" % _msg
	_info.text += "디버그 기하 (H) %s — 노랑: 광선   빨강: 자르기 전 이론값   하늘색: 실제 그려진 삼각형" % (
		"켜짐" if _show_debug else "꺼짐")


## 이론값(자르기 전)과 실제 그려진 삼각형을 겹쳐 그려, min/max 비율 clamp 가 어디서 개입하는지 보여 준다.
func _draw_debug() -> void:
	if not _show_debug:
		return
	var P := _light_pos
	_debug.draw_circle(P, 9.0, Color(1.0, 0.95, 0.35))
	for c in _casters:
		var node: Node2D = c["node"]
		var left: float = node.position.x + float(c["lx"])
		var right: float = node.position.x + float(c["rx"])
		var top_y: float = node.position.y + float(c["ty"])
		var cx := (left + right) * 0.5
		var ex := right if P.x <= cx else left
		var corner := Vector2(ex, top_y)
		_debug.draw_line(Vector2(ex, top_y), Vector2(ex, FLOOR_Y), Color(0.4, 1.0, 0.5, 0.5), 1.0)
		# 노란 광선: 광원 → 그림자를 던지는 꼭대기 모서리 → 바닥까지 연장
		_debug.draw_line(P, corner, Color(1.0, 0.92, 0.3, 0.75), 2.0)
		var dy := top_y - P.y
		if dy > 1.0:
			var t := (FLOOR_Y - P.y) / dy
			var true_tip := P.x + (ex - P.x) * t
			_debug.draw_line(corner, Vector2(true_tip, FLOOR_Y), Color(1.0, 0.92, 0.3, 0.75), 2.0)
			# 빨강: 자르기 전 이론 삼각형
			_debug.draw_polyline(PackedVector2Array([
				Vector2(ex, FLOOR_Y), corner, Vector2(true_tip, FLOOR_Y), Vector2(ex, FLOOR_Y)]),
				Color(1.0, 0.25, 0.2, 0.9), 2.0)
	# 하늘색: PropShadow 가 실제로 그린 폴리곤
	for ch in _shadows.get_children():
		if ch is Polygon2D and ch.visible and ch.polygon.size() == 3:
			var pts: PackedVector2Array = ch.polygon
			_debug.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]),
				Color(0.4, 0.9, 1.0, 0.95), 2.0)
