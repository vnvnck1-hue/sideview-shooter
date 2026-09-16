shader_type canvas_item;
render_mode blend_add, unshaded;
// 비상등의 회전 광선(볼류메트릭 팬). 두 방향으로 뻗는 부채꼴, 거리·각도로 감쇠, 먼지 노이즈.
// 방 밖(room_rect 밖)은 그리지 않는다 — 검은 여백 위로 붉은 부채꼴이 새지 않게.

uniform vec3 tint : source_color = vec3(1.0, 0.16, 0.10);
uniform float intensity : hint_range(0.0, 3.0) = 0.9;
uniform float half_angle : hint_range(0.02, 0.8) = 0.20;
uniform float length_px = 760.0;
uniform vec4 room_rect = vec4(0.0, 0.0, 4000.0, 560.0);   // x, y, w, h (월드)
uniform float seed = 0.0;

varying vec2 local_px;
varying vec2 world_px;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	local_px = VERTEX;
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	// 방 영역 클립
	float inside = step(room_rect.x, world_px.x) * step(world_px.x, room_rect.x + room_rect.z)
	             * step(room_rect.y, world_px.y) * step(world_px.y, room_rect.y + room_rect.w);
	float r = length(local_px);
	float ang = atan(local_px.y, local_px.x);
	// 두 방향 (0, PI) 중 가까운 쪽 각도 차
	float da = abs(atan(sin(ang), cos(ang)));
	da = min(da, PI - da);
	float beam = 1.0 - smoothstep(half_angle * 0.35, half_angle, da);
	float fall = pow(1.0 - clamp(r / length_px, 0.0, 1.0), 1.7) * smoothstep(0.0, 40.0, r);
	// 흐르는 먼지 노이즈
	float n = noise(vec2(r * 0.02 + seed, ang * 3.0 + TIME * 0.4)) * 0.5 + 0.5;
	float a = beam * fall * mix(0.7, 1.15, n) * intensity * inside;
	COLOR = vec4(tint * a, a);
}
