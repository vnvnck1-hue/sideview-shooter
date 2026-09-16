shader_type canvas_item;
render_mode blend_add, unshaded;
// 램프 불빛 속에서만 보이는 부유 먼지. 방 전체를 덮는 사각형에 그린다. UV 대신 방 로컬 픽셀 좌표를 쓴다.

uniform int lamp_count = 0;
uniform vec2 lamps[12];
uniform float lamp_energy[12];
uniform float lamp_radius = 420.0;
uniform float density : hint_range(0.0, 3.0) = 1.0;

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
	// 셀 안에서 원을 그리며 흔들리는 위치
	vec2 c = vec2(0.5) + 0.32 * vec2(sin(t * (0.3 + r1) + r2 * 6.28), cos(t * (0.25 + r2) + r1 * 6.28));
	float d = length((f - c) * cell);
	float on = step(0.45, r1);                           // 절반의 셀만 먼지 있음
	float twinkle = 0.55 + 0.45 * sin(t * (1.5 + r2 * 2.0) + r1 * 20.0);
	return on * twinkle * (1.0 - smoothstep(size * 0.5, size, d));
}

void fragment() {
	vec2 p = world_px;
	float t = TIME;
	float d = dust_layer(p, 46.0, 6.0, 3.2, t) * 0.9
	        + dust_layer(p + vec2(311.0, 97.0), 70.0, 3.5, 4.2, t * 0.8) * 0.7
	        + dust_layer(p + vec2(77.0, 501.0), 30.0, 9.0, 2.4, t * 1.3) * 0.5;
	// 램프 조명 속에서만 보임
	float light = 0.0;
	for (int i = 0; i < lamp_count; i++) {
		vec2 lp = lamps[i];
		vec2 dv = p - lp;
		float below = smoothstep(-40.0, 60.0, dv.y);        // 램프 아래쪽
		float cone = 1.0 - smoothstep(0.0, lamp_radius * (0.35 + 0.65 * clamp(dv.y / lamp_radius, 0.0, 1.0)), abs(dv.x));
		float fall = 1.0 - smoothstep(0.0, lamp_radius, length(dv));
		light += lamp_energy[i] * below * cone * fall;
	}
	light = clamp(light, 0.0, 1.5);
	float a = d * light * density;
	COLOR = vec4(vec3(1.0, 0.9, 0.72) * a * 2.4, a);
}
