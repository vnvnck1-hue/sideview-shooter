shader_type canvas_item;
// 풀스크린 후처리: 사격 순간 색수차 + 은은한 비네트. 픽셀이 뭉개지지 않게 오프셋은 정수 픽셀로 스냅.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float aberration : hint_range(0.0, 8.0) = 0.0;   // 화면 가장자리 최대 오프셋 (px)
uniform float vignette : hint_range(0.0, 1.0) = 0.25;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 dir = uv - center;
	float r = length(dir);
	vec2 off = normalize(dir + vec2(1e-5)) * aberration * r * 2.0;
	off = floor(off + 0.5) * px;                        // 정수 픽셀 스냅
	float cr = texture(screen_tex, uv + off).r;
	float cg = texture(screen_tex, uv).g;
	float cb = texture(screen_tex, uv - off).b;
	vec3 col = vec3(cr, cg, cb);
	// 비네트
	float v = 1.0 - vignette * smoothstep(0.45, 0.95, r * 1.25);
	col *= v;
	COLOR = vec4(col, 1.0);
}
