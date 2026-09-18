// 라이팅 공용 코드 — lit_surface / prop_surface 가 include 한다.
// 1) 강한 노멀맵 반응 (pow 감쇠 + Blinn 스페큘러)
// 2) 림라이트: 실루엣(알파 경계)을 화면 공간 방향으로 구해 광원을 향한 외곽선을 밝힌다.
//    광원이 없어도 은은한 고정 키(우상단)로 외곽선이 항상 살짝 읽힌다.
// 3) 피격 열 잔광: 탄착 UV 목록(heat_hits)이 붉게 달아올랐다가 천천히 식는다.
// 4) 파츠 마스크: 셀 단위로 조각난 프랍 — 깨진 셀은 투명 (lit_surface 는 기본 흰색 = 전부 온전).

#include "res://shaders/light_falloff.gdshaderinc"

uniform float rim_strength : hint_range(0.0, 6.0) = 1.15;
uniform float rim_width_px : hint_range(0.5, 120.0) = 2.0;      // 림이 실루엣 안쪽으로 번지는 폭 (스프라이트 안쪽으로만 — 알파 밖은 그리지 않는다)
uniform float rim_falloff : hint_range(0.3, 4.0) = 2.0;        // 폭 안에서의 감쇠 지수 (클수록 가장자리에 몰려 예리함)
uniform float rim_white_mix : hint_range(0.0, 1.0) = 0.55;     // 림 색: 표면색(0) ↔ 흰색(1)
uniform float rim_reach : hint_range(0.0, 1.0) = 0.35;         // 림 전용 감쇠 지수 (light_falloff.rim_atten): 라이트 반경 안에서 1 선형, 작을수록 멀리까지 평평. 0 이면 디퓨즈 곡선 그대로
uniform vec3 rim_ambient : source_color = vec3(0.40, 0.50, 0.74);
uniform float rim_ambient_strength : hint_range(0.0, 3.0) = 0.42;
// 림 색 블렌딩 (확정 2026-09-18 — "명도 계단 3단"). 색은 표면색 × 광원 휘도라 색상·채도가 유지되고(파스텔로 뜨지 않는다),
// 세기는 mix(계단, 연속, rim_cont) — 연속 성분이 바닥에 깔려 약한 빛에서도 림이 보이고, 계단 성분이 문턱을 넘으면 확 켜진다.
// F3 로 비교한 7종(덧셈·흰색 / 앰비언트 보정 / 덧셈·표면색 / 스크린 / 명도 부스트 / 광원색 치환 / 팔레트)과
// 계단 변형 3종(2단 · 2단 하드 · 2단 연속 강조)은 폐기. 값은 Lighting.RIM_BLEND 가 넣는다.
uniform int rim_steps : hint_range(1, 4) = 3;                 // 켜짐 단계 수
uniform float rim_step_soft : hint_range(0.0, 0.5) = 0.05;    // 단계 경계 보간 폭 (0 = 딱딱한 계단. 램프 깜빡임에 지글거리면 올린다)
uniform float rim_knee : hint_range(0.0, 0.8) = 0.10;         // 이 아래 구동값은 계단이 0 (문턱을 넘어야 확 켜진다)
uniform float rim_hue_mix : hint_range(0.0, 1.0) = 0.25;      // 계단 색에 섞는 광원 색조 (0 = 순수 표면색)
uniform float rim_step_gain : hint_range(0.5, 6.0) = 2.2;     // 구동값 배율 (클수록 약한 빛에도 상단 단계까지 간다)
uniform float rim_cont : hint_range(0.0, 1.0) = 0.28;         // 연속 성분 비율 = 평소 가시성 (0 순수 계단 · 1 순수 연속)
uniform float rim_key_mul : hint_range(0.0, 1.0) = 1.0;       // 고정 키 림 배율
uniform float rim_key_surface : hint_range(0.0, 1.0) = 1.0;   // 고정 키 림을 표면색으로 물들이는 비율 (1 = 표면색 × 키색)
uniform float normal_response : hint_range(0.5, 4.0) = 1.9;
uniform float specular_strength : hint_range(0.0, 3.0) = 0.85;
uniform float specular_power : hint_range(2.0, 64.0) = 16.0;

uniform int heat_count = 0;
uniform vec4 heat_hits[12];                 // (u, v, 세기, 경과 시간)
uniform float heat_radius_px = 18.0;
uniform float heat_cool : hint_range(0.5, 10.0) = 1.7;

uniform sampler2D mask : filter_nearest, repeat_disable, hint_default_white;   // 파츠 마스크 (r=1 온전)

varying float v_edge;        // 실루엣 경계 세기 (fragment 에서 계산 → light 에서 읽음)
varying vec2 v_edge_dir;     // 경계 바깥 방향 (화면 공간)

float surf_alpha(sampler2D tex, vec2 uv) {
	return texture(tex, uv).a * step(0.5, texture(mask, uv).r);
}

// 실루엣 경계: 폭 w 안에서 8방향×3링으로 알파 커버리지를 재서 부드러운 경계 세기를 만든다.
// 커버리지가 낮을수록(투명에 가까울수록) 경계. falloff 로 예리함을 조절한다.
// 반환 (edge, 바깥방향 uv 공간)
vec3 silhouette_edge(sampler2D tex, vec2 uv, vec2 px, float w) {
	const vec2 dirs[8] = {vec2(1,0), vec2(-1,0), vec2(0,1), vec2(0,-1),
		vec2(0.7071,0.7071), vec2(-0.7071,0.7071), vec2(0.7071,-0.7071), vec2(-0.7071,-0.7071)};
	float cover = 0.0;
	vec2 g = vec2(0.0);
	for (int r = 1; r <= 3; r++) {
		float d = w * float(r) / 3.0;
		for (int i = 0; i < 8; i++) {
			float a = surf_alpha(tex, uv + dirs[i] * px * d);
			cover += a;
			g -= dirs[i] * a;                       // 불투명 쪽의 반대 = 바깥 방향
		}
	}
	cover /= 24.0;
	float edge = pow(clamp(1.0 - cover, 0.0, 1.0), rim_falloff);
	return vec3(edge, g);
}

// uv 공간 방향 → 화면 공간 방향 (플립·회전·스케일 보정)
vec2 uv_dir_to_screen(vec2 g, vec2 uv) {
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	float det = dx.x * dy.y - dy.x * dx.y;
	if (abs(det) < 1e-12 || length(g) < 1e-6) {
		return vec2(0.0);
	}
	mat2 inv = mat2(vec2(dy.y, -dx.y), vec2(-dy.x, dx.x)) / det;
	vec2 s = inv * g;
	return normalize(s);
}

vec3 heat_emission(vec2 uv, vec2 px) {
	float h = 0.0;
	for (int i = 0; i < heat_count; i++) {
		vec4 hh = heat_hits[i];
		float d = length((uv - hh.xy) / px);
		float fall = 1.0 - smoothstep(heat_radius_px * 0.12, heat_radius_px, d);
		h += hh.z * exp(-hh.w / heat_cool) * fall * fall;
	}
	h = clamp(h, 0.0, 1.6);
	// 흰 열 → 붉은 열 → 어두운 잔열
	vec3 hot = mix(vec3(1.5, 0.22, 0.07), vec3(2.6, 1.5, 1.0), smoothstep(0.75, 1.5, h));
	return hot * h;
}

// 공용 fragment 본체: 색 + 림 앰비언트 + 열. 경계 정보는 out 으로 돌려주고 호출측 fragment() 가 varying 에 넣는다
// (varying 은 fragment() 본문에서만 대입 가능).
vec4 lit_fragment(sampler2D tex, vec2 uv, vec2 px, vec4 c, out float edge, out vec2 edge_dir) {
	vec3 col = c.rgb;
	vec3 e = silhouette_edge(tex, uv, px, rim_width_px);
	vec2 sdir = uv_dir_to_screen(e.yz, uv);
	edge = e.x * c.a;
	edge_dir = sdir;
	// 고정 키 림 (우상단에서 오는 차가운 빛) — 어둠 속에서도 외곽선이 읽힌다
	float key = 0.45 + 0.55 * max(dot(sdir, normalize(vec2(0.55, -0.83))), 0.0);
	vec3 key_col = mix(rim_ambient, rim_ambient * c.rgb * 2.0, rim_key_surface);
	col += key_col * rim_ambient_strength * rim_key_mul * edge * key;
	col += heat_emission(uv, px);
	return vec4(col, c.a);
}

float max3(vec3 v) { return max(v.r, max(v.g, v.b)); }

// 계단 양자화: 0~1 → steps 단계. 각 단계는 평평하고 경계에서만 soft 폭으로 넘어간다 (soft 0 이면 딱 떨어지는 계단).
float rim_quantize(float v, float steps, float soft) {
	float sv = clamp(v, 0.0, 1.0) * steps;
	float f = floor(sv);
	float fr = sv - f;
	float e = max(soft, 0.001);
	return min((f + smoothstep(1.0 - e, 1.0, fr)) / steps, 1.0);
}

// 림 색 블렌딩 (확정). 반환값은 base 에 **더해지는** 양 (Godot 의 LIGHT 는 덧셈으로 누적된다).
// rim_lc = 광원색 × 에너지 × 림 감쇠. 색은 표면색 × 광원 휘도(색상·채도 유지), 세기는 연속 성분과 계단 성분의 혼합.
vec3 rim_blend(vec3 base, vec3 rim_lc, float rim) {
	float lum = dot(rim_lc, vec3(0.30, 0.59, 0.11));
	float drive = clamp(rim * lum * rim_step_gain, 0.0, 1.0);                      // 연속 성분 (문턱 없음 — 약한 빛에서도 남는다)
	float v = clamp((drive - rim_knee) / max(1.0 - rim_knee, 1e-3), 0.0, 1.0);
	float q = rim_quantize(v, float(rim_steps), rim_step_soft);                    // 계단 성분 (문턱을 넘으면 확 켜짐)
	vec3 hue = rim_lc / max(max3(rim_lc), 1e-3);
	float amount = mix(q, drive, rim_cont);                                        // 둘 다 밝은 곳에서 1 이라 최대 밝기는 그대로
	return base * amount * 1.6 * mix(vec3(1.0), hue, rim_hue_mix);
}

// 공용 light 본체: 강한 노멀 반응 + 스페큘러 + 광원 방향 림 + 프레넬
// light_color = (Light2D 색, 라이트 텍스처 알파 = 거리 감쇠). 디퓨즈·스페큘러는 diffuse_atten(원래 반경 곡선),
// 림·프레넬은 rim_atten(rim_reach) 으로 따로 감쇠시켜 광원 밝기는 그대로 두고 림만 훨씬 멀리 닿게 한다.
// 감쇠를 rgb 에 직접 곱했으므로 알파는 1 로 돌려준다 (그림자·텍스처 밖 클립은 엔진이 알파에 곱한다).
vec4 lit_light(vec3 N, vec3 L, vec4 light_color, float energy, vec3 base) {
	float ndl = max(dot(N, L), 0.0);
	float diff = pow(ndl, normal_response) * (1.0 + 0.4 * (normal_response - 1.0));
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(N, H), 0.0), specular_power) * specular_strength;
	// 광원을 향한 실루엣 외곽선
	float facing = max(dot(v_edge_dir, normalize(L.xy + vec2(1e-5))), 0.0);
	float rim = v_edge * (0.2 + 0.8 * facing) * rim_strength;
	// 노멀이 기울어진 면(베벨·경사) 프레넬
	float fres = pow(1.0 - clamp(N.z, 0.0, 1.0), 2.2) * ndl * 0.9 * rim_strength;
	vec3 lc = light_color.rgb * energy * diffuse_atten(light_color.a);
	vec3 rim_col = mix(base, vec3(1.0), rim_white_mix);
	vec3 rim_lc = light_color.rgb * energy * rim_atten(light_color.a, rim_reach);
	// 프레넬(벽돌·베벨의 기울어진 노멀)은 디퓨즈 감쇠를 따른다 — 넓어지는 것은 실루엣 림만. 안 그러면 벽 전체가 뿌옇게 밝아진다
	return vec4(lc * (base * diff + spec * (0.35 + 0.65 * base) + fres * rim_col) + rim_blend(base, rim_lc, rim), 1.0);
}
