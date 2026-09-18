class_name Lighting
extends RefCounted
## 2D 라이팅 공용 값. 방은 CanvasModulate 로 어둡게 깔고, 램프·총구·탄착 PointLight2D 가 비춘다.
## 노멀맵(CanvasTexture)·셰이더 로딩 헬퍼, 절차 생성 텍스처(연기 구 노멀·비상등 광선)도 여기 모아둔다.

static var AMBIENT := _tune_color("VFX_AMB", Color(0.42, 0.43, 0.55))      # 라이트가 없는 곳의 밝기. 0.26,0.28,0.40 → 배경 색이 보이도록 올림 (푸른 기는 유지해 난색 라이트와 대비)
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

## 림라이트 (확정 2026-09-18 — "이전 (좁음)"). lit_surface / prop_surface / foreground_rim 머티리얼 전부에 적용된다.
##   reach 0 · range 1 : 림이 광원 디퓨즈와 같은 감쇠 곡선으로 꺼진다 (반경 65% 에서 18%, 라이트 가장자리에서 0).
##   도달 범위 프리셋 5종(완만·넓게 ×1.6·아주 넓게 ×2.2·방 전체 ×3)은 F3 비교 후 폐기 — 두께·범위가 아니라 림 **색**이 문제였다.
##   width  : 실루엣 안쪽으로 번지는 폭(px)   falloff : 폭 안 감쇠 지수   strength : 광원 림 세기   ambient : 고정 키 림 세기   white : 림 색의 흰색 비율
const RIM := {"id": "legacy", "name": "이전 (좁음)", "desc": "림이 광원 디퓨즈와 같은 곡선으로 꺼짐",
	"reach": 0.0, "range": 1.0,
	"width": 15.0, "falloff": 1.0, "strength": 0.9, "ambient": 0.32, "white": 0.35}
static var _lit_materials: Array = []          # WeakRef — 런타임 재적용용
static var _fg_rim_materials: Array = []       # WeakRef — foreground_rim (reach 만 받는다)

static func rim_preset() -> Dictionary:
	return RIM

## 라이트 반경 배율 (scale_for_radius 가 곱한다). 확정 1.0 — light_falloff.gdshaderinc 의 diffuse_atten 은 이때 항등이다.
static func light_range_mul() -> float:
	return float(RIM["range"])

## 캐릭터(플레이어·몬스터) 전용 림 (확정 2026-09-18 — "두껍게"). 배경보다 한 단계 두껍고 밝은 외곽.
## "배경과 같음"·"굵고 선명"·"외곽선 강조" 는 F4 비교 후 폐기. character_material() 로 만든 머티리얼만 이 값으로 덮어쓴다.
##   width 는 플레이어 스케일(1.0) 기준 텍스처 px — 크롤러(0.4 배)처럼 축소된 스프라이트는 rim_px_scale 메타로 나눠 화면 두께를 맞춘다.
const CHAR_RIM := {"id": "thick", "name": "두껍게", "desc": "폭 24px · 세기 1.8 · 흰색 60% · 고정 키 0.65",
	"width": 24.0, "falloff": 1.2, "strength": 1.8, "ambient": 0.65, "white": 0.6}

static func char_rim_preset() -> Dictionary:
	return CHAR_RIM

## 림 색 블렌딩 (확정 2026-09-18 — "명도 계단 3단"). 림의 두께·범위가 아니라 **색**이 어색함의 원인이었다.
## 원래 방식은 광원색 × (표면색→흰색 35%) 덧셈 + 광원과 무관한 파란 고정 키였고, 그 위에 CanvasModulate 앰비언트가
## 라이트 기여분까지 곱해져 따뜻한 램프 림도 파스텔로 탈색됐다. 확정 방식은:
##   색   : 표면색 × 광원 휘도 (색상·채도 유지). 광원 색조는 25% 만 섞는다.
##   세기 : mix(계단, 연속, cont) — 연속 성분(28%)이 바닥에 깔려 약한 빛에서도 림이 보이고, 3단 계단이 문턱을 넘으면 확 켜진다.
##   고정 키 : 앰비언트 색에서 파생한 색 × 표면색 (파란 고정색 폐기).
## F3 로 비교한 7종(덧셈·흰색 / 앰비언트 보정 / 덧셈·표면색 / 스크린 / 명도 부스트 / 광원색 치환 / 팔레트)과
## 계단 변형 3종(2단 · 2단 하드 · 2단 연속 강조)은 폐기했다.
const RIM_BLEND := {
	"id": "step3", "name": "명도 계단 3단",
	"steps": 3, "soft": 0.05, "knee": 0.10, "hue": 0.25, "gain": 2.2, "cont": 0.28,
	"key_surface": 1.0,
}

## 고정 키 림 색: 앰비언트(CanvasModulate) 색을 밝게 정규화한 것 — 원래의 고정 파랑 (0.40, 0.50, 0.74) 은 폐기
static func rim_key_color() -> Color:
	var a := AMBIENT
	var m := maxf(a.r, maxf(a.g, a.b))
	return Color(a.r / m, a.g / m, a.b / m) * 0.9

## 캐릭터용 라이팅 머티리얼: 배경 프리셋 위에 캐릭터 림 프리셋을 덮어쓴다.
## px_scale = 스프라이트 스케일 (0.4 면 텍스처 px 가 화면에서 0.4 배 → 폭을 1/0.4 배로 키운다)
static func character_material(shader_name := "lit_surface", px_scale := 1.0) -> ShaderMaterial:
	var m := shader_material(shader_name)
	m.set_meta("rim_character", true)
	m.set_meta("rim_px_scale", px_scale)
	_apply_rim_to(m, rim_preset())
	return m

static func _apply_rim_to(m: ShaderMaterial, p: Dictionary) -> void:
	m.set_shader_parameter("rim_width_px", p["width"])
	m.set_shader_parameter("rim_falloff", p["falloff"])
	m.set_shader_parameter("rim_strength", p["strength"])
	m.set_shader_parameter("rim_white_mix", p["white"])
	m.set_shader_parameter("rim_reach", p["reach"])
	m.set_shader_parameter("rim_ambient", rim_key_color())
	m.set_shader_parameter("rim_key_mul", 1.0)
	m.set_shader_parameter("rim_key_surface", float(RIM_BLEND["key_surface"]))
	m.set_shader_parameter("rim_steps", int(RIM_BLEND["steps"]))
	m.set_shader_parameter("rim_step_soft", float(RIM_BLEND["soft"]))
	m.set_shader_parameter("rim_knee", float(RIM_BLEND["knee"]))
	m.set_shader_parameter("rim_hue_mix", float(RIM_BLEND["hue"]))
	m.set_shader_parameter("rim_step_gain", float(RIM_BLEND["gain"]))
	m.set_shader_parameter("rim_cont", float(RIM_BLEND["cont"]))
	# 타일(0)·파편(0.6)처럼 개별로 정한 앰비언트 림은 유지, 기본값을 쓰는 곳만 갱신
	if not m.has_meta("rim_ambient_fixed"):
		m.set_shader_parameter("rim_ambient_strength", p["ambient"])
	if m.has_meta("rim_character"):
		var c := char_rim_preset()
		if float(c["width"]) > 0.0:
			var px_scale: float = m.get_meta("rim_px_scale", 1.0)
			m.set_shader_parameter("rim_width_px", float(c["width"]) / maxf(px_scale, 0.05))
			m.set_shader_parameter("rim_falloff", c["falloff"])
			m.set_shader_parameter("rim_strength", c["strength"])
			m.set_shader_parameter("rim_white_mix", c["white"])
			m.set_shader_parameter("rim_ambient_strength", c["ambient"])

## 라이트 반경 배율을 셰이더 전역 유니폼에 올린다 (Main 시작·프리셋 전환 시)
static func apply_light_range() -> void:
	RenderingServer.global_shader_parameter_set("light_range_mul", light_range_mul())

## 모든 살아 있는 라이팅 머티리얼에 확정 림 값을 다시 적용 (개발용 — 값을 바꿔 보며 확인할 때)
static func apply_rim_preset(_i := 0) -> void:
	var p := rim_preset()
	apply_light_range()
	var alive: Array = []
	for w in _lit_materials:
		var m = w.get_ref()
		if m != null:
			_apply_rim_to(m, p)
			alive.append(w)
	_lit_materials = alive
	alive = []
	for w in _fg_rim_materials:
		var m = w.get_ref()
		if m != null:
			m.set_shader_parameter("rim_reach", p["reach"])
			alive.append(w)
	_fg_rim_materials = alive

static var _radial: GradientTexture2D
static var _canvas_cache := {}
static var _shader_cache := {}
static var _white: ImageTexture
static var _sphere_normal: ImageTexture
static var _puff: ImageTexture
static var _smoke_tex: CanvasTexture
static var _beam: ImageTexture


## 원형 감쇠 텍스처 (모든 PointLight2D 가 공유). 부드러운 3점 그라데이션 — 렌더는 풀해상도(베이크 자산·풀해상도 확정)라
## 그림만 4px 블록이고 조명은 부드럽게 간다. (계단형 5단계 고리는 저해상도 뷰포트 프리셋과 함께 폐기)
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


## 반지름(px)에 맞는 texture_scale. 림 프리셋의 반경 배율이 곱해진다 — 셰이더(light_falloff.diffuse_atten)가
## 디퓨즈는 원래 반경 곡선으로 되돌리므로 보이는 광원 범위는 그대로, 림만 커진 반경까지 닿는다.
static func scale_for_radius(radius: float) -> float:
	return radius * 2.0 / TEX_SIZE * light_range_mul()


## 층별 조명 분리 (DepthPreset "근경 분리" 일 때만). 이 라이트는 배경 층(타일·문·프랍·먼지·빛 기둥, z≤4)만 비추고,
## 인물 층(플레이어·몬스터·탄, z5~6)은 ratio 배로 약한 거울 라이트(LightMirror, 자식)가 비춘다.
## 근경 층(z7)은 light_mask 0 이라 어느 라이트도 받지 않는다. 벽이 인물보다 밝게 빛나 실루엣이 앞으로 떠 보인다.
## 총구·탄착·불·아크처럼 인물 층에 있는 광원은 부르지 않는다 (모든 층을 그대로 비춘다).
static func split_by_depth(light: PointLight2D, ratio := DepthPreset.ACTOR_LIGHT_RATIO) -> void:
	if not DepthPreset.enabled():
		return
	light.range_z_max = DepthPreset.Z_BACK_MAX
	var m := LightMirror.new()
	m.setup(light, ratio)
	light.add_child(m)


## res://assets/<group>/<name>.png 를 노멀맵이 붙은 CanvasTexture 로. 노멀맵이 없으면 원본 텍스처.
## 노멀맵은 Tools/build_normal_maps.py 가 assets/normals/<group>/<name>.png 에 만든다.
static func textured(path: String) -> Texture2D:
	if _canvas_cache.has(path):
		return _canvas_cache[path]
	var diffuse: Texture2D = load(path)
	var normal_path := NORMAL_DIR + path.trim_prefix("res://assets/")
	var result: Texture2D = diffuse
	if path.begins_with("res://assets/") and ResourceLoader.exists(normal_path):
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
	if name == "lit_surface" or name == "prop_surface":
		_apply_rim_to(m, rim_preset())
		_lit_materials.append(weakref(m))
	elif name == "foreground_rim":
		m.set_shader_parameter("rim_reach", rim_preset()["reach"])
		_fg_rim_materials.append(weakref(m))
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
