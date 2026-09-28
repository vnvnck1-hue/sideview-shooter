shader_type canvas_item;
render_mode unshaded;
// 바닥 안개 (GroundFog). 바닥선 위로 얕게 깔리는 띠 하나를 그린다. UV 대신 방 로컬 px 를 쓴다.
//   · 세로: 바닥에서 가장 짙고 height 위로 갈수록 옅어진다. 윗선은 roll 만큼 느리게 너울진다.
//   · 가로: 길게 늘인 fbm 두 겹이 서로 다른 속도로 흘러 결이 겹친다 (wisp = 결의 대비).
//   · 픽셀: cell(월드 px) 격자로 샘플해 아트 픽셀과 같은 크기로 끊는다. steps > 0 이면 농도도 계단으로.
//   · 빛: 램프·비상등·불 근처에서 그 색으로 밝아진다 (DustLayer 와 같은 광원 목록).
// 암흑 시야(dark_common) 밖에서는 안개 본색 대신 그림자 팔레트 색의 옅은 안개가 남고, 광원에 물든 부분이 떠오른다.
// 방이 CanvasModulate 로 어둡게 깔려 있으므로 색은 "화면에서 보일 최종 색" 으로 받고 ambient_inv 로 보정한다.

#include "res://shaders/dark_common.gdshaderinc"

uniform vec3 fog_color : source_color = vec3(0.42, 0.48, 0.56);
uniform float alpha = 0.2;
uniform float floor_line = 486.0;
uniform float height = 110.0;
uniform float speed = 9.0;          // px/s
uniform float scale = 260.0;        // 결의 크기 (px)
uniform float wisp = 0.55;
uniform float roll = 0.35;
uniform float light_gain = 0.5;
uniform float steps = 0.0;
uniform float cell = 4.0;
uniform float seed = 0.0;
uniform vec3 ambient_inv = vec3(1.0);

uniform int light_count = 0;
uniform vec2 lights[16];
uniform vec4 light_color[16];        // rgb * energy, a = 0: 전방향 / 1: 램프(아래쪽 원뿔)
uniform float light_radius[16];

varying vec2 world_px;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v / 0.9375;
}

float max3(vec3 v) { return max(v.r, max(v.g, v.b)); }

void vertex() {
	world_px = VERTEX;
}

void fragment() {
	vec2 p = cell > 0.0 ? floor(world_px / cell) * cell + cell * 0.5 : world_px;
	float t = TIME;
	float up = floor_line - p.y;

	// 너울지는 윗선
	float top = fbm(vec2((p.x - t * speed * 0.6) / (scale * 1.7) + seed, t * 0.04));
	float h = height * (1.0 + roll * (top * 2.0 - 1.0));
	float prof = 1.0 - smoothstep(0.0, max(h, 1.0), up);
	prof *= prof;
	// 너울 윗선 위(prof = 0)는 dens = 0 → 알파 0 이라 보이지 않는다. 결 두 겹(fbm 8옥타브)과 광원 루프를 건너뛴다.
	if (prof <= 0.0) {
		COLOR = vec4(0.0);
	} else {

		// 흐르는 결 두 겹 — 세로를 눌러 가로로 길게
		float n1 = fbm(vec2(p.x - t * speed, p.y * 2.4) / scale + seed);
		float n2 = fbm(vec2(p.x + t * speed * 0.45, p.y * 2.4) / (scale * 0.6) + seed + 31.0);
		float n = mix(n1, n2, 0.4);
		float dens = prof * mix(1.0, smoothstep(0.3, 0.7, n), wisp);
		if (steps > 0.0) {
			dens = floor(dens * steps + 0.5) / steps;
		}

		vec3 lit = vec3(0.0);
		for (int i = 0; i < light_count; i++) {
			vec2 dv = p - lights[i];
			float rad = light_radius[i];
			vec4 lc = light_color[i];
			float fall = 1.0 - smoothstep(0.0, rad, length(dv));
			float shape = 1.0;
			if (lc.a > 0.5) {
				float below = smoothstep(-40.0, 60.0, dv.y);
				float cone = 1.0 - smoothstep(0.0, rad * (0.35 + 0.65 * clamp(dv.y / rad, 0.0, 1.0)), abs(dv.x));
				shape = below * cone;
			}
			lit += lc.rgb * fall * fall * shape;
		}
		vec3 glow = min(lit, vec3(1.2)) * light_gain;
		vec4 sh = dv_surface(FRAGCOORD.xy, t, 1.0);
		// 어둠 속에서는 본색 대신 그림자 팔레트 색의 옅은 안개로 남고, 빛을 받은 곳은 그 빛으로 물든다
		vec3 col = (mix(sh.rgb * 1.6, fog_color, sh.w) + glow) * ambient_inv;
		float keep = max(sh.w, max(clamp(max3(glow) * 2.0, 0.0, 1.0), 0.25));
		COLOR = vec4(min(col, vec3(4.0)), clamp(dens * alpha * keep, 0.0, 1.0));
	}
}
