shader_type canvas_item;
#include "res://shaders/light_falloff.gdshaderinc"
// 연기 파티클. 구 노멀맵(CanvasTexture)을 달고 light() 에서 주변 광원(램프·불·비상등)에
// 부피감 있게 반응한다: 광원을 향한 면이 밝고 반대는 어둡게, 얇은 가장자리는 빛이 투과(래핑).
// 알파는 3단계로 양자화해 청키 픽셀 느낌을 유지한다.

uniform vec3 smoke_color : source_color = vec3(0.78, 0.76, 0.80);
uniform float light_wrap : hint_range(0.0, 1.0) = 0.65;
uniform float light_gain : hint_range(0.0, 6.0) = 4.0;
uniform bool use_particle_color = false;   // true 면 파티클 색 램프(불 연기: 붉은기 → 검정)를 연기색으로 쓴다

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = c.a * COLOR.a;
	a = floor(a * 4.0 + 0.001) / 4.0;
	// 기본은 연기색 고정 (밝기만 파티클 알파 곡선을 따른다). 불 연기는 파티클 색 램프를 따른다.
	vec3 base = use_particle_color ? COLOR.rgb : smoke_color;
	COLOR = vec4(base * c.rgb, a);
}

void light() {
	vec3 N = NORMAL;
	vec3 L = LIGHT_DIRECTION;
	float ndl = dot(N, L);
	// 래핑 디퓨즈: 얇은 연기라 뒷면도 조금 비친다
	float wrap = clamp((ndl + light_wrap) / (1.0 + light_wrap), 0.0, 1.0);
	wrap = pow(wrap, 1.4);
	// 가장자리 산란 (림): 광원 반대편 실루엣도 살짝 빛난다
	float rim = pow(1.0 - clamp(N.z, 0.0, 1.0), 2.0) * 0.35;
	vec3 lc = LIGHT_COLOR.rgb * LIGHT_ENERGY * light_gain;
	LIGHT = vec4(lc * COLOR.rgb * (wrap + rim), diffuse_atten(LIGHT_COLOR.a));
}
