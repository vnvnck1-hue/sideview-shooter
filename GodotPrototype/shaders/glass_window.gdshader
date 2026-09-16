shader_type canvas_item;
// 창문 유리: 비스듬한 하이라이트가 천천히 스치고, 맞으면 탄착점에서 방사형 균열이 퍼진다.

uniform float crack : hint_range(0.0, 1.0) = 0.0;
uniform vec2 crack_uv = vec2(0.5, 0.5);
uniform float crack_seed = 1.0;
uniform float sheen : hint_range(0.0, 2.0) = 0.7;
uniform vec3 glass_tint : source_color = vec3(0.55, 0.7, 1.0);

float hash(float n) { return fract(sin(n) * 43758.5453123); }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 col = c.rgb;
	// 스치는 사선 하이라이트
	float band = UV.x * 0.8 - UV.y * 0.6 + sin(TIME * 0.35) * 0.9;
	float s = smoothstep(0.0, 0.07, band) * (1.0 - smoothstep(0.07, 0.15, band));
	col += glass_tint * s * 0.35 * sheen;
	// 차가운 유리 톤
	col = mix(col, col * glass_tint * 1.3, 0.25);

	if (crack > 0.001) {
		vec2 d = UV - crack_uv;
		d.x *= 1.6;                                  // 창 비율 보정
		float dist = length(d);
		float ang = atan(d.y, d.x);
		float line = 0.0;
		// 방사형 금 9개, 각각 살짝 굽음
		for (int i = 0; i < 9; i++) {
			float fi = float(i);
			float a0 = fi * 0.698 + hash(crack_seed + fi) * 0.5;
			float bend = (hash(crack_seed * 3.0 + fi) - 0.5) * 2.5 * dist;
			float da = abs(atan(sin(ang - a0 - bend), cos(ang - a0 - bend)));
			float len = 0.25 + hash(crack_seed * 7.0 + fi) * 0.55;
			line += (1.0 - smoothstep(0.0, 0.012 + dist * 0.02, da * dist)) * step(dist, len * crack) * step(0.02, dist);
		}
		// 동심 고리 균열
		float rings = 0.0;
		for (int j = 1; j <= 3; j++) {
			float rr = float(j) * 0.11 * crack;
			rings += 1.0 - smoothstep(0.0, 0.008, abs(dist - rr + sin(ang * 5.0 + crack_seed) * 0.012));
		}
		rings *= step(dist, 0.36 * crack);
		float ck = clamp(line + rings * 0.7, 0.0, 1.0);
		// 탄착 중심 하얀 구멍
		float hole = 1.0 - smoothstep(0.0, 0.05 * crack, dist);
		col = mix(col, vec3(0.85, 0.92, 1.0), ck * 0.9);
		col = mix(col, vec3(0.05, 0.06, 0.09), hole * 0.85);
		// 균열 주변 미세하게 어둡게(빛 산란)
		col *= 1.0 - 0.15 * crack * (1.0 - smoothstep(0.0, 0.4, dist));
	}
	COLOR = vec4(col, c.a);
}
