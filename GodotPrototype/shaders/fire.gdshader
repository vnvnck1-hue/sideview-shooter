shader_type canvas_item;
// 절차적 불꽃. 아래(UV.y=1)에서 위로 타오르며 노이즈로 혀가 갈라진다.
// style 0/2: 좌표를 pixel_step 단위로 양자화하고 색을 4단계로 포스터라이즈 (청키 픽셀)
// style 1  : 양자화 없이 부드러운 그라데이션
// 팔레트·실루엣 값은 FireSource.STYLES 가 넣어준다. 채도는 낮게 — 배경 팔레트와 결을 맞춘다.

uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float pixel_step = 4.0;        // 양자화 픽셀 크기 (로컬 px). 1 이면 양자화 없음
uniform vec2 size_px = vec2(160.0, 200.0);
uniform float seed = 0.0;
uniform float speed = 1.6;
uniform int style = 0;                 // 0 포스터  1 부드러운 그라데이션  2 잉걸(짧고 끊어진 불길)
uniform float height_k = 0.85;         // 위로 갈수록 열이 식는 속도 (클수록 낮은 불)
uniform float width_base = 0.95;       // 바닥 폭 (-1..1 기준)
uniform float width_top = 0.15;        // 꼭대기 폭
uniform float gap : hint_range(0.0, 1.0) = 0.0;   // 불길이 끊어지는 정도
uniform float boost = 0.15;            // 밴드(또는 열)별 밝기 가산 — 심만 글로우에 닿게
uniform vec3 col_core : source_color = vec3(0.98, 0.86, 0.62);
uniform vec3 col_mid  : source_color = vec3(0.90, 0.52, 0.22);
uniform vec3 col_red  : source_color = vec3(0.62, 0.20, 0.10);
uniform vec3 col_edge : source_color = vec3(0.22, 0.07, 0.05);

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.05 + vec2(13.7, 7.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = floor(UV * size_px / pixel_step) * pixel_step;
	vec2 uv = px / size_px;
	float t = TIME * speed + seed;
	float x = uv.x * 2.0 - 1.0;                // -1..1
	float yup = 1.0 - uv.y;                    // 0 바닥, 1 꼭대기
	float n = fbm(vec2(uv.x * 3.2 + seed, uv.y * 4.0 + t * 1.1));
	float n2 = fbm(vec2(uv.x * 6.0 - seed, uv.y * 7.0 + t * 1.9));
	float width = mix(width_base, width_top, pow(yup, 0.8));
	float body = 1.0 - smoothstep(width * 0.55, width, abs(x) + (n - 0.5) * 0.7);
	float heat = body * (1.0 - yup * (height_k + (n2 - 0.5) * 0.5));
	// 끊어진 불길: 노이즈가 낮은 곳은 꺼진다
	heat *= mix(1.0, smoothstep(0.38, 0.62, n2), gap);
	heat *= intensity;
	heat = clamp(heat, 0.0, 1.0);

	vec3 col;
	float a;
	if (style == 1) {
		a = smoothstep(0.03, 0.22, heat) * 0.95;
		col = mix(col_edge, col_red, smoothstep(0.05, 0.32, heat));
		col = mix(col, col_mid, smoothstep(0.32, 0.62, heat));
		col = mix(col, col_core, smoothstep(0.62, 0.92, heat));
		col *= 1.0 + heat * heat * boost * 4.0;
	} else {
		float q = floor(min(heat, 0.999) * 4.0);
		if (q >= 3.0)      { col = col_core; a = 1.0; }
		else if (q >= 2.0) { col = col_mid;  a = 1.0; }
		else if (q >= 1.0) { col = col_red;  a = 0.92; }
		else               { col = col_edge; a = 0.55 * step(0.06, heat); }
		col *= 1.0 + q * boost;
	}
	// 꼭대기 잔불 알갱이
	float ember = step(0.965, hash2(px + floor(t * 6.0))) * step(0.5, yup) * body;
	col += col_mid * 1.6 * ember;
	a = max(a, ember);
	COLOR = vec4(col, a);
}
