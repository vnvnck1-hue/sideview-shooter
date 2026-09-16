class_name Lighting
extends RefCounted
## 2D 라이팅 공용 값. 방은 CanvasModulate 로 어둡게 깔고, 램프·총구·탄착 PointLight2D 가 비춘다.
## 노멀맵(CanvasTexture)·셰이더 로딩 헬퍼, 절차 생성 텍스처(연기 구 노멀·비상등 광선)도 여기 모아둔다.

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

## 사격 계열 붉은 팔레트 — 총구·궤적·탄착·피격 플래시가 모두 이 톤을 공유한다
const RED_EMISSIVE := Color(4.5, 1.7, 1.25, 1.0)        # 흰 심이 살아 있는 붉은 발광
const RED_EMISSIVE_SOFT := Color(3.0, 1.0, 0.75, 1.0)
const GUN_LIGHT := Color(1.0, 0.36, 0.26)               # 총구 라이트
const IMPACT_LIGHT := Color(1.0, 0.30, 0.20)            # 탄착 라이트
const TRACER := Color(1.0, 0.30, 0.18)                  # 궤적 본체
const TRACER_CORE := Color(1.0, 0.86, 0.80)             # 궤적 심
const SPARK_BASE := Color(1.0, 0.42, 0.22)              # 불꽃 스파크

## 비상등 · 불 · 전기 색
const EMERGENCY_RED := Color(1.0, 0.16, 0.10)
const FIRE_LIGHT := Color(1.0, 0.55, 0.22)
const ARC_BLUE := Color(0.70, 0.82, 1.0)
const WATER := Color(0.55, 0.75, 1.0)

static var _radial: GradientTexture2D
static var _canvas_cache := {}
static var _shader_cache := {}
static var _white: ImageTexture
static var _sphere_normal: ImageTexture
static var _puff: ImageTexture
static var _smoke_tex: CanvasTexture
static var _beam: ImageTexture


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
		ct.specular_color = Color(0.45, 0.45, 0.5)
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


## 강한 노멀 반응 + 림라이트 표면 머티리얼 (타일·문·캐릭터·파편)
static func lit_material() -> ShaderMaterial:
	return shader_material("lit_surface")


## Polygon2D 에 UV 를 주기 위한 1x1 흰색 텍스처 (1px 이므로 uv 픽셀좌표 == 정규화 UV)
static func white_texture() -> ImageTexture:
	if _white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


## 반구 노멀맵 (연기 파티클이 광원에 부피감 있게 반응하도록). OpenGL Y+ 규약.
static func sphere_normal_texture(size := 64) -> ImageTexture:
	if _sphere_normal == null:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var half := size * 0.5
		for y in range(size):
			for x in range(size):
				var nx := (x + 0.5 - half) / half
				var ny := -(y + 0.5 - half) / half          # 이미지 y 아래 → OpenGL y 위
				var r2 := nx * nx + ny * ny
				var n := Vector3(0, 0, 1)
				if r2 < 1.0:
					n = Vector3(nx, ny, sqrt(1.0 - r2)).normalized()
				# 가운데는 정면, 가장자리로 갈수록 기울어짐 — 약간 완만하게(0.8)
				n = Vector3(n.x * 0.8, n.y * 0.8, n.z).normalized()
				img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
		_sphere_normal = ImageTexture.create_from_image(img)
	return _sphere_normal


## 연기 뭉치 디퓨즈 — 부드러운 원형 + 노이즈 가장자리, 3단계 알파(청키)
static func puff_texture(size := 64) -> ImageTexture:
	if _puff == null:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var half := size * 0.5
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		var noise := FastNoiseLite.new()
		noise.seed = 7
		noise.frequency = 0.09
		for y in range(size):
			for x in range(size):
				var dx := (x + 0.5 - half) / half
				var dy := (y + 0.5 - half) / half
				var r := sqrt(dx * dx + dy * dy)
				var n := noise.get_noise_2d(x, y) * 0.28
				var a := clampf(1.0 - (r + n) / 0.92, 0.0, 1.0)
				a = floor(a * 3.0 + 0.001) / 3.0
				# 가운데가 조금 밝다 (광원 없이도 형태가 읽히게)
				var shade := 0.85 + 0.15 * (1.0 - r)
				img.set_pixel(x, y, Color(shade, shade, shade, a))
		_puff = ImageTexture.create_from_image(img)
	return _puff


## 연기 파티클용 CanvasTexture (디퓨즈 + 구 노멀)
static func smoke_canvas_texture() -> CanvasTexture:
	if _smoke_tex == null:
		var ct := CanvasTexture.new()
		ct.diffuse_texture = puff_texture()
		ct.normal_texture = sphere_normal_texture()
		ct.specular_color = Color(0.1, 0.1, 0.1)
		ct.specular_shininess = 0.2
		_smoke_tex = ct
	return _smoke_tex


## 비상등 라이트 텍스처: 중심에서 좌우 두 방향으로 뻗는 광선 + 약한 중심 글로우
static func beam_texture(size := 256, half_angle := 0.22) -> ImageTexture:
	if _beam == null:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var half := size * 0.5
		for y in range(size):
			for x in range(size):
				var dx := (x + 0.5 - half)
				var dy := (y + 0.5 - half)
				var r := sqrt(dx * dx + dy * dy) / half
				var ang := atan2(dy, dx)
				var da := absf(atan2(sin(ang), cos(ang)))
				da = minf(da, PI - da)
				var beam := 1.0 - smoothstep(half_angle * 0.3, half_angle, da)
				var fall := pow(clampf(1.0 - r, 0.0, 1.0), 1.4)
				var glow := pow(clampf(1.0 - r / 0.22, 0.0, 1.0), 2.0) * 0.6
				var v := clampf(beam * fall + glow, 0.0, 1.0)
				img.set_pixel(x, y, Color(v, v, v, v))
		_beam = ImageTexture.create_from_image(img)
	return _beam
