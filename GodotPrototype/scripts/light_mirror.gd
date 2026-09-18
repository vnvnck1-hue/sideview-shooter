class_name LightMirror
extends PointLight2D
## 층별 조명 분리용 거울 라이트. 원본 PointLight2D 의 자식으로 붙어(변환 상속) 텍스처·색·높이를 복제하고,
## 매 프레임 원본의 energy·enabled·color 를 ratio 배로 따라간다. 원본은 배경 층(z≤4)만, 이 노드는 인물 층(z5~6)만 비춘다.
## 램프 깜빡임·파손·비상등 회전이 그대로 전달되므로 호출 쪽은 원본만 다루면 된다. Lighting.split_by_depth 가 붙인다.
## 범위는 근경 층(z7)까지 — 근경 몸체는 light_mask 0 이라 안 받고, 림 띠(foreground_rim)만 이 거울 라이트로 윤곽이 물든다.

var _src: PointLight2D
var _ratio := 1.0


func setup(src: PointLight2D, ratio: float) -> void:
	_src = src
	_ratio = ratio
	name = "ActorMirror"
	texture = src.texture
	texture_scale = src.texture_scale
	height = src.height
	blend_mode = src.blend_mode
	shadow_enabled = false
	range_item_cull_mask = src.range_item_cull_mask
	range_z_min = DepthPreset.Z_ACTOR_MIN
	range_z_max = DepthPreset.Z_FOREGROUND
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
