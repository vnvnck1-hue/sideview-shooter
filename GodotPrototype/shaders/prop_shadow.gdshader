shader_type canvas_item;
render_mode unshaded, blend_mix;
// 프랍 그림자 — 원본 프랍 텍스처의 **알파만** 써서 실루엣을 어둡게 찍는다.
// 놓이는 자리(바닥에 눕히는 전단 변환 · 벽에 맺히는 확대)는 prop_shadow.gd 가 Transform2D 로 잡고,
// 여기서는 부드러움(blur) · 먼 끝 페이드(far_fade) · 세기(strength)만 맡는다.
// 그림자는 라이트를 받으면 안 되므로 unshaded.

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float blur : hint_range(0.0, 12.0) = 1.5;       // 번짐 반경 (텍셀)
uniform float far_fade : hint_range(0.0, 1.0) = 0.7;    // 광원에서 먼 끝(UV.y=0)이 얼마나 옅어지는가
uniform vec3 tint : source_color = vec3(0.0, 0.0, 0.0);

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur;
	// 3x3 탭 — 가운데에 무게를 둬 실루엣은 유지하고 가장자리만 편다
	float a = texture(TEXTURE, UV).a * 4.0;
	a += texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	a += texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	a += texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	a += texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	a += texture(TEXTURE, UV + px).a;
	a += texture(TEXTURE, UV - px).a;
	a += texture(TEXTURE, UV + vec2(px.x, -px.y)).a;
	a += texture(TEXTURE, UV + vec2(-px.x, px.y)).a;
	a = clamp(a / 12.0, 0.0, 1.0);

	float far = 1.0 - UV.y;                  // 스프라이트 위쪽 = 프랍 꼭대기 = 투영의 먼 끝
	a *= mix(1.0, 1.0 - far_fade, far);
	COLOR = vec4(tint, a * strength);
}
