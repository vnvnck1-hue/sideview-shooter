extends CanvasLayer
## 암흑 시야. 두 층으로 동작한다.
##   1. 표면 암흑 (shaders/dark_common.gdshaderinc) — 타일·프랍·캐릭터 셰이더가 **앰비언트만** 가시도만큼 가라앉힌다.
##      PointLight2D 의 빛은 그대로 더해지므로, 어둠 속에서도 램프·총구 화염·탄환·탄착 빛을 받은 면과 림·반사광만 떠오른다.
##      캐릭터는 배경과 다른 곡선(조금 더 멀리 · 어둠 속 실루엣 유지)이라 배경의 어둠에서 떨어져 읽힌다.
##   2. 화면 마스크 (shaders/dark_vision.gdshader) — 그 바깥의 안전망. 조명을 받지 않는 요소까지 먼 어둠에서 지우되,
##      씬의 모든 켜진 PointLight2D 주변은 걷어낸다.
## 이 노드가 전역 셰이더 값(dv_*)을 매 프레임 올린다. 노드가 없으면 dv_on = 0 이라 다른 씬(랩·로비)은 영향이 없다.

const NEAR_CLEAR := 800.0              # 완전히 보이는 반경 (월드 px)
const NEAR_DARK := 1700.0              # 완전한 암흑이 시작되는 반경
const MAX_MASK_LIGHTS := 32            # dark_vision.gdshader 의 배열 크기

## 방 테마별 그림자 팔레트 (dark_common.dv_palette) — 어둠을 검정 대신 공간의 분위기 색으로 가라앉힌다.
##   edge   어둠이 막 시작되는 경계색 · deep 가장 깊은 곳 · accent 흐르는 결을 따라 은은하게 섞이는 보조색
## 픽셀아트식 hue-shift: 밝은 쪽은 채도 있는 보라·청록, 깊을수록 명도와 채도를 같이 떨어뜨린 남색으로.
const PALETTES := {
	"workshop": {       # 녹슨 정비 구역 — 자줏빛 그늘에 차가운 청록 기운
		"edge": Color(0.187, 0.077, 0.165), "deep": Color(0.026, 0.015, 0.053), "accent": Color(0.033, 0.110, 0.143)},
	"corridor": {       # 차가운 통로 — 푸른 그늘에 보랏빛 결
		"edge": Color(0.066, 0.099, 0.209), "deep": Color(0.011, 0.015, 0.045), "accent": Color(0.121, 0.044, 0.165)},
	"crewquarters": {   # 거주구 — 따뜻한 자두색 그늘에 호박색 잔광
		"edge": Color(0.187, 0.077, 0.121), "deep": Color(0.034, 0.015, 0.038), "accent": Color(0.143, 0.077, 0.022)},
	"hydroponics": {    # 수경재배 — 초록 청록 그늘에 보랏빛 결 (식물 조명의 보색)
		"edge": Color(0.033, 0.143, 0.110), "deep": Color(0.007, 0.030, 0.034), "accent": Color(0.110, 0.044, 0.154)},
	"power_relay": {    # 전력 중계 — 전기 남보라 그늘에 시안 결
		"edge": Color(0.077, 0.066, 0.231), "deep": Color(0.009, 0.011, 0.049), "accent": Color(0.022, 0.143, 0.176)},
	"research": {       # 연구 구역 — 임상적인 청록 그늘에 자홍 결
		"edge": Color(0.044, 0.121, 0.176), "deep": Color(0.009, 0.022, 0.041), "accent": Color(0.143, 0.044, 0.121)},
}

var game: Node
var mask: ColorRect
var _material: ShaderMaterial
var _lights: Array = []                # 씬의 PointLight2D (WeakRef 아님 — tree_exiting 에서 뺀다)
var _palette_theme := ""
var palette_override: Dictionary = {}  # 비어 있지 않으면 테마 대신 이 팔레트 (검증 툴이 순수 검정으로 비교할 때)


func _ready() -> void:
	layer = 10
	process_priority = 100 # Follow player animation and camera (priority 10).
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/dark_vision.gdshader")
	mask = ColorRect.new()
	mask.name = "VisibilityMask"
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.material = _material
	add_child(mask)
	RenderingServer.global_shader_parameter_set("dv_clear", NEAR_CLEAR)
	RenderingServer.global_shader_parameter_set("dv_dark", NEAR_DARK)
	# 모든 광원을 자동으로 따라간다 — 총구·탄환·탄착처럼 순간 생기는 라이트도 따로 등록할 필요가 없다
	for node in get_tree().root.find_children("*", "PointLight2D", true, false):
		_track(node)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("dv_on", 0.0)
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is PointLight2D:
		_track(node)


func _track(light: PointLight2D) -> void:
	if _lights.has(light):
		return
	_lights.append(light)
	light.tree_exiting.connect(_lights.erase.bind(light), CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player):
		RenderingServer.global_shader_parameter_set("dv_on", 0.0)
		return
	var eye: Vector2 = game.player.head_pivot.global_position
	if is_instance_valid(game.controlled_turret):
		eye = game.controlled_turret.vision_origin()
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	RenderingServer.global_shader_parameter_set("dv_on", 1.0)
	RenderingServer.global_shader_parameter_set("dv_origin", inverse.origin)
	RenderingServer.global_shader_parameter_set("dv_axis_x", inverse.x)
	RenderingServer.global_shader_parameter_set("dv_axis_y", inverse.y)
	RenderingServer.global_shader_parameter_set("dv_eye", eye)
	_apply_palette(game.current_room)
	_upload_lights(active_lights(get_viewport().get_visible_rect(), inverse))


## 방 테마 → 그림자 팔레트 (research_* 는 research 로 묶는다). 테마가 바뀔 때만 올린다.
static func palette_for(theme: String) -> Dictionary:
	if theme.begins_with("research"):
		theme = "research"
	return PALETTES.get(theme, PALETTES["workshop"])


## 검증용: 팔레트·빛무리를 끄고 순수 검정 어둠으로 (on = false 면 테마 팔레트로 복귀)
func set_black(on: bool) -> void:
	palette_override = {"edge": Color.BLACK, "deep": Color.BLACK, "accent": Color.BLACK} if on else {}
	_palette_theme = "#dirty"
	_material.set_shader_parameter("halo", 0.0 if on else 0.18)


func _apply_palette(room: Node) -> void:
	var theme := ""
	if is_instance_valid(room) and RoomData.ROOMS.has(room.room_id):
		theme = str(RoomData.ROOMS[room.room_id].get("theme", ""))
	if not palette_override.is_empty():
		theme = "#override"
	if theme == _palette_theme:
		return
	_palette_theme = theme
	var p := palette_override if not palette_override.is_empty() else palette_for(theme)
	RenderingServer.global_shader_parameter_set("dv_shadow_edge", p["edge"])
	RenderingServer.global_shader_parameter_set("dv_shadow_deep", p["deep"])
	RenderingServer.global_shader_parameter_set("dv_shadow_accent", p["accent"])


## 지금 화면 근처에서 켜져 있는 광원 — [{pos(월드), power(0..1), radius}] (검증 툴도 쓴다)
func active_lights(view: Rect2, inverse: Transform2D) -> Array:
	var world_view := (inverse * view).grow(600.0)
	var out: Array = []
	for l: PointLight2D in _lights:
		if not l.enabled or not l.is_visible_in_tree() or l.texture == null:
			continue
		var power := l.energy * maxf(l.color.r, maxf(l.color.g, l.color.b)) * l.color.a
		if power <= 0.02:
			continue
		var gt := l.global_transform
		var radius := float(l.texture.get_width()) * 0.5 * l.texture_scale * gt.get_scale().x
		var pos := gt * l.offset
		if not world_view.grow(radius).has_point(pos):
			continue
		var m := maxf(l.color.r, maxf(l.color.g, l.color.b))
		out.append({"pos": pos, "power": clampf(power, 0.0, 1.0), "radius": radius,
			"hue": Vector3(l.color.r, l.color.g, l.color.b) / maxf(m, 0.001)})
	if out.size() > MAX_MASK_LIGHTS:
		out.sort_custom(func(a, b): return a["power"] * a["radius"] > b["power"] * b["radius"])
		out.resize(MAX_MASK_LIGHTS)
	return out


func _upload_lights(list: Array) -> void:
	var pos := PackedVector2Array()
	var power := PackedFloat32Array()
	var rad := PackedFloat32Array()
	var hue := PackedVector3Array()
	for info in list:
		hue.append(info["hue"])
		pos.append(info["pos"])
		power.append(info["power"])
		rad.append(info["radius"])
	var n := pos.size()
	for i in range(n, MAX_MASK_LIGHTS):
		pos.append(Vector2(-99999, -99999))
		power.append(0.0)
		rad.append(1.0)
		hue.append(Vector3.ZERO)
	_material.set_shader_parameter("light_count", n)
	_material.set_shader_parameter("light_hue", hue)
	_material.set_shader_parameter("lights", pos)
	_material.set_shader_parameter("light_power", power)
	_material.set_shader_parameter("light_radius", rad)
