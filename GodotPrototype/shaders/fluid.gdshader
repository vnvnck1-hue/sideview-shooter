shader_type canvas_item;
#include "res://shaders/light_falloff.gdshaderinc"
// 몬스터 체액(벽 자국·바닥 웅덩이) 전용. 젖은 유기물이라 빛을 흡수해 광원에 둔하게 반응한다:
// 램프·불·비상등이 비쳐도 light_response 만큼만 밝아지고, 스페큘러·림은 없다.
// _draw 로 그린 사각형(버텍스 컬러)을 그대로 쓰므로 TEXTURE 는 샘플하지 않는다.

uniform float light_response : hint_range(0.0, 1.0) = 0.28;   // 1.0 = 기본 라이팅과 같음
uniform float saturation : hint_range(0.0, 1.5) = 0.8;         // 채도 눌러 형광기 제거

void fragment() {
	vec3 c = COLOR.rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(lum), c, saturation), COLOR.a);
}

void light() {
	// 광원 색을 채도 낮게 섭취: 빛의 밝기는 받되 색이 물들지는 덜 하게
	vec3 lc = LIGHT_COLOR.rgb * LIGHT_ENERGY;
	float llum = dot(lc, vec3(0.299, 0.587, 0.114));
	lc = mix(vec3(llum), lc, 0.5);
	LIGHT = vec4(lc * COLOR.rgb * light_response, diffuse_atten(LIGHT_COLOR.a));
}
