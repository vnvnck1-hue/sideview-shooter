shader_type canvas_item;
// 절차적 불꽃. 아래(UV.y=1)에서 위로 타오르며 노이즈로 혀가 갈라진다.
// 청키 픽셀 유지를 위해 좌표를 pixel_step 단위로 양자화하고 색은 4단계로 포스터라이즈한다.

uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float pixel_step = 4.0;        // 양자화 픽셀 크기 (로컬 px)
uniform vec2 size_px = vec2(160.0, 200.0);
uniform float seed = 0.0;
uniform float speed = 1.6;

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
	// 양자화된 로컬 픽셀 좌표
	vec2 px = floor(UV * size_px / pixel_step) * pixel_step;
	vec2 uv = px / size_px;
	float t = TIME * speed + seed;
	float x = uv.x * 2.0 - 1.0;                // -1..1
	float yup = 1.0 - uv.y;                    // 0 바닥, 1 꼭대기
	// 위로 흐르는 노이즈 (두 층)
	float n = fbm(vec2(uv.x * 3.2 + seed, uv.y * 4.0 + t * 1.1));
	float n2 = fbm(vec2(uv.x * 6.0 - seed, uv.y * 7.0 + t * 1.9));
	// 불꽃 실루엣: 바닥은 넓고 위로 갈수록 좁아짐, 노이즈로 가장자리 갈라짐
	float width = mix(0.95, 0.15, pow(yup, 0.8));
	float body = 1.0 - smoothstep(width * 0.55, width, abs(x) + (n - 0.5) * 0.7);
	float heat = body * (1.0 - yup * (0.85 + (n2 - 0.5) * 0.5));
	heat *= intensity;
	// 포스터라이즈 4단계
	float q = floor(clamp(heat, 0.0, 0.999) * 4.0);
	vec3 col;
	float a;
	if (q >= 3.0)      { col = vec3(1.0, 0.92, 0.65); a = 1.0; }     // 흰 노란 심
	else if (q >= 2.0) { col = vec3(1.0, 0.55, 0.12); a = 1.0; }     // 주황
	else if (q >= 1.0) { col = vec3(0.92, 0.18, 0.05); a = 0.92; }   // 붉은
	else               { col = vec3(0.32, 0.05, 0.02); a = 0.55 * step(0.06, heat); }   // 어두운 가장자리·그을음
	// 꼭대기 잔불 알갱이
	float ember = step(0.965, hash2(px + floor(t * 6.0))) * step(0.5, yup) * body;
	col += vec3(1.0, 0.7, 0.3) * ember;
	a = max(a, ember);
	COLOR = vec4(col * (1.0 + q * 0.35), a);
}
