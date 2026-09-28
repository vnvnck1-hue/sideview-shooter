class_name LightMirror
extends PointLight2D
## 층별 조명 분리용 거울 라이트. 원본 PointLight2D 의 자식으로 붙어(변환 상속) 텍스처·색·높이를 복제하고,
## 매 프레임 원본의 energy·enabled·color·height 를 ratio 배로 따라간다. 원본은 배경 층(z≤4)만, 이 노드는 인물 층(z5~6)만 비춘다.
## 램프 깜빡임·파손·비상등 회전이 그대로 전달되므로 호출 쪽은 원본만 다루면 된다. Lighting.split_by_depth 가 붙인다.
## 범위는 근경 층(z7)까지 — 근경 몸체는 light_mask 0 이라 안 받고, 림 띠(foreground_rim)만 이 거울 라이트로 윤곽이 물든다.
##
## 역광 (backlit): 광원이 인물보다 **뒤**(뒷벽)에 있다는 표시. height 를 음수로 복제해 LIGHT_DIRECTION.z 가 음수가 되고,
## lit_common.lit_light 가 그걸 보고 역광 모델로 그린다 — 몸 안쪽은 덜 받고(노출이 광원에 맞춰져 살짝 어두워짐),
## 광원 쪽 실루엣 윤곽이 강하게 빛난다. 켜고 끄는 것은 이 값 하나라 A/B 비교가 런타임에 된다.
## (앞쪽 광원 — Lighting.split_front — 은 거꾸로 이 노드가 배경 층을 약하게 비추고, 원본이 인물을 순광으로 비춘다.)

var _src: PointLight2D
var _ratio := 1.0
var backlit := false


func setup(src: PointLight2D, ratio: float, is_backlit := false,
		z_min := DepthLayers.Z_ACTOR_MIN, z_max := DepthLayers.Z_FOREGROUND) -> void:
	_src = src
	_ratio = ratio
	backlit = is_backlit
	name = "ActorMirror"
	texture = src.texture
	texture_scale = src.texture_scale
	blend_mode = src.blend_mode
	shadow_enabled = false
	range_item_cull_mask = src.range_item_cull_mask
	range_z_min = z_min
	range_z_max = z_max
	_sync()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	if _src == null:
		return
	energy = _src.energy * _ratio
	enabled = _src.enabled
	color = _src.color
	visible = _src.visible
	height = -absf(_src.height) if backlit else absf(_src.height)
