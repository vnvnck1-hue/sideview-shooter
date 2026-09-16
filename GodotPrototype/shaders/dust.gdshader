shader_type canvas_item;
render_mode blend_add, unshaded;
// 부유 먼지(엠비언트). 방 전체를 덮는 사각형에 그린다. UV 대신 방 로컬 픽셀 좌표를 쓴다.
// 어둠 속에서도 아주 희미하게 떠다니고(ambient), 광원(램프·비상등·불·전선 스파크) 근처에서
// 그 광원의 색으로 밝게 드러난다. 램프는 아래쪽 원뿔, 나머지는 전방향.

const int MAX_LIGHTS = 16;
uniform int light_count = 0;
uniform vec2 lights[16];
uniform vec4 light_color[16];        // rgb * energy, a = 0: 전방향 / 1: 램프(아래쪽 원뿔)
uniform float light_radius[16];
uniform float density : hint_range(0.0, 3.0) = 1.0;
uniform float ambient : hint_range(0.0, 1.0) = 0.10;
uniform vec3 ambient_tint : source_color = vec3(0.55, 0.62, 0.85);

varying vec2 world_px;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_px = VERTEX;   // 부모 Node2D 가 방 원점에 있으므로 VERTEX 가 방 로컬 px
}

// 셀 크기 cell 의 그리드에 먼지 한 알씩, 느리게 떠다닌다
float dust_layer(vec2 p, float cell, float speed, float size, float t) {
	vec2 drift = vec2(sin(t * 0.13) * 30.0 + t * speed, t * speed * 0.35);
	vec2 q = (p + drift) / cell;
	vec2 id = floor(q);
	vec2 f = fract(q);
	float r1 = hash2(id);
	float r2 = hash2(id + 17.0);
	vec2 c = vec2(0.5) + 0.32 * vec2(sin(t * (0.3 + r1) + r2 * 6.28), cos(t * (0.25 + r2) + r1 * 6.28));
	float d = length((f - c) * cell);
	float on = step(0.45, r1);
	float twinkle = 0.55 + 0.45 * sin(t * (1.5 + r2 * 2.0) + r1 * 20.0);
	return on * twinkle * (1.0 - smoothstep(size * 0.5, size, d));
}

void fragment() {
	vec2 p = world_px;
	float t = TIME;
	float d = dust_layer(p, 46.0, 6.0, 3.2, t) * 0.9
	        + dust_layer(p + vec2(311.0, 97.0), 70.0, 3.5, 4.2, t * 0.8) * 0.7
	        + dust_layer(p + vec2(77.0, 501.0), 30.0, 9.0, 2.4, t * 1.3) * 0.5
	        + dust_layer(p + vec2(913.0, 233.0), 120.0, 2.0, 6.0, t * 0.5) * 0.35;   // 큰 느린 알갱이
	vec3 light = ambient_tint * ambient;
	for (int i = 0; i < light_count; i++) {
		vec2 dv = p - lights[i];
		float rad = light_radius[i];
		vec4 lc = light_color[i];
		float fall = 1.0 - smoothstep(0.0, rad, length(dv));
		float shape = 1.0;
		if (lc.a > 0.5) {
			// 램프: 아래쪽 원뿔
			float below = smoothstep(-40.0, 60.0, dv.y);
			float cone = 1.0 - smoothstep(0.0, rad * (0.35 + 0.65 * clamp(dv.y / rad, 0.0, 1.0)), abs(dv.x));
			shape = below * cone;
		}
		light += lc.rgb * fall * fall * shape;
	}
	light = min(light, vec3(1.6));
	float a = d * density;
	COLOR = vec4(light * a * 2.4, a * clamp(length(light), 0.0, 1.0));
}
