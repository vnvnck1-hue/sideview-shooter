shader_type canvas_item;
render_mode blend_add, unshaded;
// 램프 아래 볼류메트릭 빛 기둥. UV.y 0=램프, 1=바닥. 위는 밝고 아래로 사라지며,
// 노이즈가 천천히 흘러 먼지 낀 공기 느낌을 낸다.

uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.62);
uniform float seed = 0.0;
// 사다리꼴 형상 (로컬 px). Polygon2D 의 UV 는 삼각형 단위 어파인 보간이라 사다리꼴에서 사선으로 찢어지므로 쓰지 않는다.
uniform vec2 top_center = vec2(0.0, 0.0);
uniform float top_half = 34.0;
uniform float bottom_y = 500.0;
uniform float bottom_half = 330.0;

varying vec2 local_px;

void vertex() {
	local_px = VERTEX;
}

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float y = clamp((local_px.y - top_center.y) / max(bottom_y - top_center.y, 1.0), 0.0, 1.0);
	float half_w = mix(top_half, bottom_half, y);
	float x = clamp((local_px.x - top_center.x) / half_w, -1.0, 1.0);   // -1..1
	vec2 UVc = vec2(x * 0.5 + 0.5, y);
	// 세로 감쇠: 램프 바로 아래가 가장 밝고 바닥으로 사라짐
	float v = pow(1.0 - y, 1.6) * smoothstep(0.0, 0.08, y);
	// 가로: 가운데 밝고 가장자리는 부드럽게
	float h = 1.0 - smoothstep(0.45, 1.0, abs(x));
	// 흘러가는 먼지 노이즈 (2 옥타브)
	vec2 np = vec2(UVc.x * 3.0 + seed, y * 4.0 - TIME * 0.12);
	float n = noise(np) * 0.65 + noise(np * 2.3 + vec2(7.0, TIME * 0.05)) * 0.35;
	n = mix(0.75, 1.25, n);
	// 세로 줄무늬 (빛살)
	float rays = 0.85 + 0.15 * sin(UVc.x * 40.0 + seed * 3.0 + noise(vec2(UVc.x * 6.0, TIME * 0.2)) * 4.0);
	float a = v * h * n * rays * intensity;
	COLOR = vec4(tint * a, a);
}
