class_name Lighting
extends RefCounted
## 2D 라이팅 공용 값. 방은 CanvasModulate 로 어둡게 깔고, 램프·총구·탄착 PointLight2D 가 비춘다.
## 노멀맵(CanvasTexture)·셰이더 로딩 헬퍼도 여기 모아둔다.

static var AMBIENT := _tune_color("VFX_AMB", Color(0.26, 0.28, 0.40))      # 라이트가 없는 곳의 밝기. HDR(선형) 이전 sRGB 0.26 과 같은 체감 밝기
## 2D 노멀맵용 라이트 높이(px). 0 이면 표면에 평행해 노멀이 반응하지 않는다
static var LAMP_HEIGHT := _tune("VFX_H", 140.0)
const FLASH_HEIGHT := 90.0
static var LAMP_ENERGY := _tune("VFX_LAMP", 1.0)     # height 140 이면 1.0 이 예전(height 0, 1.7) 램프 밑 밝기와 같다

static func _tune(k: String, d: float) -> float:
	var v := OS.get_environment(k)
	return float(v) if v != "" else d

static func _tune_color(k: String, d: Color) -> Color:
	var v := OS.get_environment(k)
	if v == "":
		return d
	var p := v.split(",")
	return Color(float(p[0]), float(p[1]), float(p[2]))
const TEX_SIZE := 512
const NORMAL_DIR := "res://assets/normals/"

## 발광 배율 — CanvasModulate(≈0.3)로 어두워진 만큼 보정해 글로우 임계값(0.85)을 넘긴다 (LDR 이라 1.0 에서 클램프)
const EMISSIVE := Color(4.5, 4.5, 4.5, 1.0)
const EMISSIVE_SOFT := Color(2.6, 2.6, 2.6, 1.0)
const BULB_EMISSION := 1.7                    # 전구 픽셀 최종 밝기 목표 (임계 0.85 초과 = 글로우)

static var _radial: GradientTexture2D
static var _canvas_cache := {}
static var _shader_cache := {}
static var _white: ImageTexture


## 부드러운 원형 감쇠 텍스처 (모든 PointLight2D 가 공유)
static func radial_texture() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.30, Color(1, 1, 1, 0.6))
		g.add_point(0.65, Color(1, 1, 1, 0.18))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = TEX_SIZE
		t.height = TEX_SIZE
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_radial = t
	return _radial


## 반지름(px)에 맞는 texture_scale
static func scale_for_radius(radius: float) -> float:
	return radius * 2.0 / TEX_SIZE


## res://assets/<group>/<name>.png 를 노멀맵이 붙은 CanvasTexture 로. 노멀맵이 없으면 원본 텍스처.
## 노멀맵은 Tools/build_normal_maps.py 가 assets/normals/<group>/<name>.png 에 만든다.
static func textured(path: String) -> Texture2D:
	if _canvas_cache.has(path):
		return _canvas_cache[path]
	var diffuse: Texture2D = load(path)
	var normal_path := path.replace("res://assets/", NORMAL_DIR)
	var result: Texture2D = diffuse
	if normal_path != path and ResourceLoader.exists(normal_path):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = diffuse
		ct.normal_texture = load(normal_path)
		ct.specular_color = Color(0.35, 0.35, 0.4)
		ct.specular_shininess = 0.6
		result = ct
	_canvas_cache[path] = result
	return result


## shaders/<name>.gdshader 로 새 ShaderMaterial (셰이더 자체는 캐시, 머티리얼은 인스턴스마다 새로)
static func shader_material(name: String) -> ShaderMaterial:
	if not _shader_cache.has(name):
		_shader_cache[name] = load("res://shaders/%s.gdshader" % name)
	var m := ShaderMaterial.new()
	m.shader = _shader_cache[name]
	return m


## Polygon2D 에 UV 를 주기 위한 1x1 흰색 텍스처 (1px 이므로 uv 픽셀좌표 == 정규화 UV)
static func white_texture() -> ImageTexture:
	if _white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white
