shader_type canvas_item;
// 불 뒤 벽면의 그을음. 아래가 짙고 위로 갈수록 노이즈 섞여 옅어진다. 곱셈 블렌드로 벽을 어둡게.
render_mode blend_mul, unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float seed = 0.0;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 q = floor(UV * vec2(24.0, 30.0)) / vec2(24.0, 30.0);   // 픽셀 양자화
	float x = abs(q.x * 2.0 - 1.0);
	float n = noise(q * vec2(5.0, 6.0) + seed) * 0.6 + noise(q * vec2(11.0, 13.0) - seed) * 0.4;
	float shape = (1.0 - smoothstep(0.35, 1.0, x + (n - 0.5) * 0.5)) * (1.0 - smoothstep(0.1, 1.0, (1.0 - q.y) + (n - 0.5) * 0.6));
	float dark = 1.0 - strength * shape;
	COLOR = vec4(vec3(dark), 1.0);
}
