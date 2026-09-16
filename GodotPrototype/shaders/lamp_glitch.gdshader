shader_type canvas_item;
// 천장 램프 스프라이트(타일에서 잘라낸 아틀라스). 전구 픽셀을 HDR 로 발광시키고,
// 깨질 때 가로 찢김 + 스캔라인 노이즈로 지직거린다.
// 라이팅은 타일과 같은 lit_common(light) 을 써서 아틀라스 경계가 티나지 않게 한다.
#include "res://shaders/lit_common.gdshaderinc"

uniform float emit : hint_range(0.0, 12.0) = 6.0;      // 전구 발광 배율 (CanvasModulate 로 어두워진 만큼 보정)
uniform float glitch : hint_range(0.0, 1.0) = 0.0;     // 지직거림 세기
uniform float time_seed = 0.0;
uniform vec4 bulb_uv = vec4(0.0, 0.0, 1.0, 1.0);        // 전구 영역 (u0, v0, u1, v1)

float hash(float n) { return fract(sin(n) * 43758.5453123); }

void fragment() {
	vec2 uv = UV;
	float t = TIME * 37.0 + time_seed;
	if (glitch > 0.001) {
		// 몇 픽셀 행 단위로 가로 찢김
		float row = floor(uv.y * 22.0);
		float r = hash(row + floor(t));
		float tear = (r - 0.5) * 0.35 * glitch * step(0.55, hash(row * 3.1 + floor(t * 1.7)));
		uv.x += tear;
		uv.x = clamp(uv.x, 0.0, 1.0);
	}
	vec4 c = texture(TEXTURE, uv);
	// 전구 마스크: 전구 영역 + 밝은 픽셀
	float in_bulb = step(bulb_uv.x, uv.x) * step(uv.x, bulb_uv.z) * step(bulb_uv.y, uv.y) * step(uv.y, bulb_uv.w);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float bulb = in_bulb * smoothstep(0.35, 0.7, lum);
	vec3 col = c.rgb * (1.0 + emit * bulb);
	if (glitch > 0.001) {
		float scan = step(0.5, fract(uv.y * 44.0 + t * 0.3));
		float flick = 0.6 + 0.8 * hash(floor(t * 2.3));
		col = mix(col, col * (0.4 + scan * 0.9) * flick, glitch);
		// 순간 하얀 번쩍임
		col += vec3(1.0, 0.9, 0.7) * bulb * glitch * step(0.7, hash(floor(t * 1.3))) * 3.0;
	}
	COLOR = vec4(col, c.a);
	v_edge = 0.0;
	v_edge_dir = vec2(0.0);
}

void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_COLOR, LIGHT_ENERGY, COLOR.rgb);
}
