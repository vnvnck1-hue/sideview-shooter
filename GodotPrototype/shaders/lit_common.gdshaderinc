// 라이팅 공용 코드 — lit_surface / prop_surface 가 include 한다.
// 1) 강한 노멀맵 반응 (pow 감쇠 + Blinn 스페큘러)
// 2) 림라이트: 실루엣(알파 경계)을 화면 공간 방향으로 구해 광원을 향한 외곽선을 밝힌다.
//    광원이 없어도 은은한 고정 키(우상단)로 외곽선이 항상 살짝 읽힌다.
// 3) 피격 열 잔광: 탄착 UV 목록(heat_hits)이 붉게 달아올랐다가 천천히 식는다.
// 4) 파츠 마스크: 셀 단위로 조각난 프랍 — 깨진 셀은 투명 (lit_surface 는 기본 흰색 = 전부 온전).

uniform float rim_strength : hint_range(0.0, 3.0) = 1.15;
uniform float rim_width_px : hint_range(0.5, 6.0) = 2.0;
uniform vec3 rim_ambient : source_color = vec3(0.40, 0.50, 0.74);
uniform float rim_ambient_strength : hint_range(0.0, 2.0) = 0.42;
uniform float normal_response : hint_range(0.5, 4.0) = 1.9;
uniform float specular_strength : hint_range(0.0, 3.0) = 0.85;
uniform float specular_power : hint_range(2.0, 64.0) = 16.0;

uniform int heat_count = 0;
uniform vec4 heat_hits[12];                 // (u, v, 세기, 경과 시간)
uniform float heat_radius_px = 36.0;
uniform float heat_cool : hint_range(0.5, 10.0) = 3.4;

uniform sampler2D mask : filter_nearest, repeat_disable, hint_default_white;   // 파츠 마스크 (r=1 온전)

varying float v_edge;        // 실루엣 경계 세기 (fragment 에서 계산 → light 에서 읽음)
varying vec2 v_edge_dir;     // 경계 바깥 방향 (화면 공간)

float surf_alpha(sampler2D tex, vec2 uv) {
	return texture(tex, uv).a * step(0.5, texture(mask, uv).r);
}

// 실루엣 경계: 이웃 알파가 비면 경계. 반환 (edge, 바깥방향 uv 공간)
vec3 silhouette_edge(sampler2D tex, vec2 uv, vec2 px, float w) {
	vec2 o = px * w;
	float ax0 = surf_alpha(tex, uv - vec2(o.x, 0.0));
	float ax1 = surf_alpha(tex, uv + vec2(o.x, 0.0));
	float ay0 = surf_alpha(tex, uv - vec2(0.0, o.y));
	float ay1 = surf_alpha(tex, uv + vec2(0.0, o.y));
	float mn = min(min(ax0, ax1), min(ay0, ay1));
	float edge = 1.0 - smoothstep(0.0, 0.6, mn);
	vec2 g = vec2(ax0 - ax1, ay0 - ay1);          // 불투명 → 투명 쪽
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
	col += rim_ambient * rim_ambient_strength * edge * key;
	col += heat_emission(uv, px);
	return vec4(col, c.a);
}

// 공용 light 본체: 강한 노멀 반응 + 스페큘러 + 광원 방향 림 + 프레넬
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
	vec3 lc = light_color.rgb * energy;
	vec3 rim_col = mix(base, vec3(1.0), 0.55);
	return vec4(lc * (base * diff + spec * (0.35 + 0.65 * base) + (rim + fres) * rim_col), light_color.a);
}
