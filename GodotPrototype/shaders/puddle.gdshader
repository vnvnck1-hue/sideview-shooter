shader_type canvas_item;
// 바닥 물웅덩이 — 어두운 반투명 물 + 흐르는 스페큘러 결 + 물방울 파문 고리. UV.x 가로, UV.y 세로(얇은 타원).

uniform float fill : hint_range(0.0, 1.0) = 1.0;         // 웅덩이 확장 정도
uniform vec3 water_tint : source_color = vec3(0.35, 0.55, 0.85);
uniform float seed = 0.0;
uniform vec4 ripples[6];                                 // (u, v, 시작 후 경과, 세기)
uniform int ripple_count = 0;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	// 타원 마스크 (fill 로 커진다), 가장자리 픽셀 계단
	float rr = length(c * vec2(2.0, 2.0)) / max(fill, 0.02);
	float edge_noise = noise(vec2(atan(c.y, c.x) * 2.0 + seed, 0.0)) * 0.12;
	float m = 1.0 - step(1.0 - edge_noise, rr);
	// 물 몸체
	vec3 col = water_tint * 0.22;
	// 흐르는 결
	float sheen = noise(vec2(UV.x * 9.0 + TIME * 0.35 + seed, UV.y * 3.0 - TIME * 0.2));
	sheen = smoothstep(0.55, 0.85, sheen);
	col += water_tint * sheen * 0.9;
	// 파문 고리
	float rings = 0.0;
	for (int i = 0; i < ripple_count; i++) {
		vec4 rp = ripples[i];
		float d = length((UV - rp.xy) * vec2(1.0, 4.0));
		float radius = rp.z * 0.55;
		float ring = 1.0 - smoothstep(0.0, 0.03, abs(d - radius));
		rings += ring * rp.w * max(0.0, 1.0 - rp.z / 0.9);
	}
	col += vec3(0.9, 0.95, 1.0) * rings * 0.8;
	float a = m * (0.55 + sheen * 0.3 + rings * 0.4);
	COLOR = vec4(col, a);
}
