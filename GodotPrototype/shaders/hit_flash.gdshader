shader_type canvas_item;
#include "res://shaders/light_falloff.gdshaderinc"
// 피격 플래시: 탄착점(hit_uv) 주변만 흰색으로 번쩍인다. 거리(픽셀)로 부드럽게 감쇠.
// NORMAL 을 건드리지 않으므로 CanvasTexture 노멀맵 라이팅은 그대로 유지.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 hit_uv = vec2(0.5, 0.5);
uniform float radius_px = 64.0;              // 플래시 반경 (텍스처 픽셀)
uniform vec3 flash_color : source_color = vec3(1.0, 0.96, 0.88);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = length((UV - hit_uv) / TEXTURE_PIXEL_SIZE);
	float k = flash * (1.0 - smoothstep(radius_px * 0.25, radius_px, d));
	// 중심은 HDR 로 1.0 을 넘겨 글로우가 살짝 잡힌다
	COLOR = vec4(mix(c.rgb, flash_color * 2.2, k), c.a);
}

// 기본 라이트 패스와 같은 결과(라이트 색 × 표면색)에 거리 감쇠만 원래 반경 곡선으로 되돌린다 (림 범위 프리셋의 반경 배율 보정)
void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * COLOR.rgb, diffuse_atten(LIGHT_COLOR.a));
}
