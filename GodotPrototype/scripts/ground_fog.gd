class_name GroundFog
extends Polygon2D
## 바닥 안개 — 바닥선 위로 얕게 깔려 천천히 흐르는 띠 (shaders/ground_fog.gdshader).
##
## 방마다 두 겹을 깐다 (Room.build):
##   · 뒤 겹 (공기층 z4) — 인물 뒤. 벽 밑동과 프랍 다리를 흐리게 덮어 바닥이 멀어 보이게 한다.
##   · 앞 겹 (인물 층 위 z6) — 더 얕고 옅게, 더 빨리 흐른다. 인물·몬스터의 발목을 살짝 덮어 "안개 속에 서 있다" 로 읽힌다.
## 둘 다 조명을 받지 않고(unshaded) 램프·비상등·불 근처에서 그 색으로 밝아진다 (DustLayer 와 같은 광원 목록).
##
## 프리셋 (F2 다음 · Shift+F2 이전) — 바꾸면 지금 방에 바로 반영되고 다음 방에도 이어진다.
##   color  — 화면에서 보일 최종 색 (앰비언트로 나눠 보정한다)
##   alpha  — 바닥선에서의 농도 (뒤 겹)
##   height — 안개가 올라오는 높이 (월드 px, 아트 1px = 4)
##   speed  — 흐르는 속도 (px/s) · scale 결의 크기 (px) · wisp 결의 대비 (0 = 고른 막, 1 = 뚜렷한 가닥)
##   roll   — 윗선이 너울지는 정도 (height 대비)
##   light  — 광원 색을 받아 밝아지는 정도
##   steps  — 농도 계단 수 (0 = 부드럽게)
##   front  — 앞 겹 농도 (뒤 겹 대비) · front_h 앞 겹 높이 (뒤 겹 대비)

const TOP_PAD := 1.6                   # 폴리곤 윗변 = height × 이 값 (윗선 너울 여유)
const SIDE_PAD := 40.0

const PRESETS := [
	{
		"id": "off", "name": "끔", "desc": "안개 없음",
		"color": Color(0, 0, 0), "alpha": 0.0, "height": 0.0, "speed": 0.0, "scale": 1.0,
		"wisp": 0.0, "roll": 0.0, "light": 0.0, "steps": 0, "front": 0.0, "front_h": 0.0,
	},
	{
		"id": "mist", "name": "옅은 바닥 안개", "desc": "푸른 회색 막이 허리 아래로 느리게 흐른다",
		"color": Color(0.42, 0.48, 0.56), "alpha": 0.30, "height": 240.0, "speed": 9.0, "scale": 260.0,
		"wisp": 0.7, "roll": 0.35, "light": 0.5, "steps": 0, "front": 0.45, "front_h": 0.45,
	},
	{
		"id": "coolant", "name": "냉각수 냉기", "desc": "차가운 청록 냉기가 바닥에 낮게 붙어 빠르게 번진다",
		"color": Color(0.50, 0.68, 0.74), "alpha": 0.38, "height": 170.0, "speed": 18.0, "scale": 180.0,
		"wisp": 0.75, "roll": 0.5, "light": 0.7, "steps": 0, "front": 0.6, "front_h": 0.55,
	},
	{
		"id": "toxic", "name": "독성 증기", "desc": "탁한 녹색 증기가 괴어 거의 움직이지 않는다 — 4단 계단",
		"color": Color(0.38, 0.54, 0.30), "alpha": 0.26, "height": 270.0, "speed": 4.0, "scale": 300.0,
		"wisp": 0.65, "roll": 0.45, "light": 0.45, "steps": 4, "front": 0.5, "front_h": 0.4,
	},
	{
		"id": "deep", "name": "짙은 저층 운무", "desc": "가슴까지 차오른 두꺼운 안개 — 발밑이 보이지 않는다",
		"color": Color(0.36, 0.40, 0.48), "alpha": 0.40, "height": 400.0, "speed": 6.0, "scale": 380.0,
		"wisp": 0.4, "roll": 0.3, "light": 0.6, "steps": 0, "front": 0.55, "front_h": 0.5,
	},
	{
		"id": "dust", "name": "마른 먼지 안개", "desc": "누런 먼지가 가닥지어 바닥을 쓸고 지나간다 — 5단 계단",
		"color": Color(0.54, 0.46, 0.36), "alpha": 0.28, "height": 200.0, "speed": 13.0, "scale": 220.0,
		"wisp": 0.85, "roll": 0.6, "light": 0.55, "steps": 5, "front": 0.4, "front_h": 0.5,
	},
]

static var index := 1                  # 기본: 옅은 바닥 안개

var front := false
var _floor_y := 0.0
var _width := 0.0
var _lamps: Array = []
var _sources: Array = []
var _ambient: CanvasModulate
var _mat: ShaderMaterial


static func preset() -> Dictionary:
	return PRESETS[index]


static func set_preset(i: int) -> void:
	index = wrapi(i, 0, PRESETS.size())


func setup(width: float, floor_y: float, lamps: Array, sources: Array, ambient: CanvasModulate, is_front: bool) -> void:
	front = is_front
	_width = width
	_floor_y = floor_y
	_lamps = lamps
	_sources = sources
	_ambient = ambient
	texture = Lighting.white_texture()
	_mat = Lighting.shader_material("ground_fog")
	material = _mat
	_mat.set_shader_parameter("floor_line", floor_y)
	_mat.set_shader_parameter("seed", 53.0 if front else 0.0)
	apply(index)


func apply(i: int) -> void:
	var p: Dictionary = PRESETS[wrapi(i, 0, PRESETS.size())]
	var a: float = p["alpha"] * (p["front"] * 0.5 if front else 1.0)
	var h: float = p["height"] * (p["front_h"] if front else 1.0)
	visible = a > 0.0 and h > 0.0
	if not visible:
		return
	var top := _floor_y - h * TOP_PAD
	var bottom := _floor_y + 8.0
	polygon = PackedVector2Array([Vector2(-SIDE_PAD, top), Vector2(_width + SIDE_PAD, top),
		Vector2(_width + SIDE_PAD, bottom), Vector2(-SIDE_PAD, bottom)])
	uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_mat.set_shader_parameter("fog_color", p["color"])
	_mat.set_shader_parameter("alpha", a)
	_mat.set_shader_parameter("height", h)
	_mat.set_shader_parameter("speed", p["speed"] * (1.35 if front else 1.0))   # 앞 겹은 가까우니 더 빨리 스친다
	_mat.set_shader_parameter("scale", p["scale"] * (0.8 if front else 1.0))
	_mat.set_shader_parameter("wisp", p["wisp"])
	_mat.set_shader_parameter("roll", p["roll"])
	_mat.set_shader_parameter("light_gain", p["light"])
	_mat.set_shader_parameter("steps", float(p["steps"]))
	_process(0.0)


func _process(_delta: float) -> void:
	if not visible or _mat == null:
		return
	DustLayer.upload_lights(_mat, _lamps, _sources)
	var amb := _ambient.color if is_instance_valid(_ambient) else Color(1, 1, 1)
	_mat.set_shader_parameter("ambient_inv", Vector3(
		1.0 / maxf(amb.r, 0.05), 1.0 / maxf(amb.g, 0.05), 1.0 / maxf(amb.b, 0.05)))
