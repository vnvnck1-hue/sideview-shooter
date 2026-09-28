// 암흑 시야 공용 코드 — 표면 셰이더(lit_common · 안개 · 먼지)와 화면 마스크(dark_vision)가 함께 include 한다.
//
// 값은 전역 유니폼으로 DarkVision 이 매 프레임 올린다 (project.godot [shader_globals]). dv_on 이 0 이면(랩·로비 등) 항상 1 = 다 보임.
// 표면 셰이더는 이 값으로 **앰비언트(주변광) 성분만** 어둡게 한다. PointLight2D 의 기여(디퓨즈·림·스페큘러)는 light() 에서
// 그대로 더해지므로, 어둠 속에서도 램프·총구 화염·탄환·탄착 빛을 받은 면과 외곽선만 떠오른다.
//
// 가시도 = 관찰자(플레이어 머리 / 조종 중인 포탑) 둘레의 거리 곡선. 방향과 무관하다.
//   · 경계는 느리게 흐르는 노이즈가 밀고 당겨 원 모양이 드러나지 않고 연기처럼 일렁인다.
//   · 농도는 levels 단계로 끊고 단계 사이를 4×4 Bayer 로 섞는다. 격자는 월드 4px(아트 1px)에 고정 — 카메라가 움직여도 무늬가 헤엄치지 않는다.
// 색: 어둠은 검정이 아니라 방 테마의 그림자 팔레트로 색조 이동한다 (픽셀아트식 hue-shift 그림자).
//   · edge  : 어둠이 막 시작되는 경계색 (채도 있는 보라·청록 등) — 빛과 어둠 사이 띠가 물든다
//   · deep  : 가장 깊은 곳의 색 (거의 검정에 가까운 남색 계열)
//   · accent: 흐르는 결을 따라 은은하게 섞이는 보조색 — 어둠이 한 가지 색으로 죽지 않고 천천히 일렁인다
//   경계 → 심연 전환도 Bayer 로 끊어 팔레트 밴드처럼 보인다.
// 좌표는 화면 픽셀(FRAGCOORD) → 월드 px 로 되돌려 쓴다 (dv_origin/axis = 캔버스 변환의 역). 그래서 어느 캔버스 층이든 같은 자리의 어둠이 같다.

global uniform float dv_on;
global uniform vec2 dv_origin;
global uniform vec2 dv_axis_x;
global uniform vec2 dv_axis_y;
global uniform vec2 dv_eye;
global uniform float dv_clear;       // 여기까지 완전히 보인다 (월드 px)
global uniform float dv_dark;        // 여기부터 완전한 암흑
global uniform vec4 dv_shadow_edge;
global uniform vec4 dv_shadow_deep;
global uniform vec4 dv_shadow_accent;

const float DV_PIXEL = 4.0;
const float DV_LEVELS = 5.0;
const float DV_WARP = 150.0;         // 노이즈가 경계를 밀고 당기는 거리 (px)
const float DV_DRIFT = 14.0;         // 노이즈가 흐르는 속도 (px/s)
const float DV_BREATHE = 0.035;      // 반경이 숨 쉬는 폭 (비율)
const float DV_DEEP_KEEP = 0.15;     // 깊은 어둠에 남는 그림자색 비율 (어둠은 확실히 어둡게)

const float DV_BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
                                     3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// sin 없는 해시 (Hoskins) — fract(sin) 은 GPU 에 따라 정밀도가 깨져 각진 블록 무늬가 생긴다
float dv_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float dv_vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(dv_hash(i), dv_hash(i + vec2(1.0, 0.0)), u.x),
	           mix(dv_hash(i + vec2(0.0, 1.0)), dv_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float dv_fbm(vec2 p) {
	float v = 0.5 * dv_vnoise(p);
	v += 0.25 * dv_vnoise(p * 2.07 + vec2(17.1, 9.3));
	v += 0.125 * dv_vnoise(p * 4.13 + vec2(-5.7, 23.9));
	return v / 0.875;
}

// 화면 픽셀(FRAGCOORD.xy) → 월드 px 격자 칸
vec2 dv_cell(vec2 frag) {
	vec2 w = dv_origin + dv_axis_x * frag.x + dv_axis_y * frag.y;
	return floor(w / DV_PIXEL);
}

// 흐르는 어둠 결 (-1..1) — 큰 결은 천천히 옆으로, 작은 결은 반대로 위로 흘러 겹친다. t = TIME
float dv_flow(vec2 p, float t) {
	float n1 = dv_fbm((p + vec2(t * DV_DRIFT, t * DV_DRIFT * 0.35)) / 380.0);
	float n2 = dv_fbm((p + vec2(-t * DV_DRIFT * 0.6, -t * DV_DRIFT * 0.8)) / 150.0 + 41.0);
	return mix(n1, n2, 0.35) * 2.0 - 1.0;
}

float dv_breath(float t) {
	return 1.0 + DV_BREATHE * (0.6 * sin(t * 0.55) + 0.4 * sin(t * 1.37 + 1.3));
}

// 관찰자 둘레 연속 가시도 (0..1). reach 는 반경 배율 (캐릭터는 배경보다 조금 멀리까지 읽힌다).
float dv_seen(vec2 p, float n, float t, float reach) {
	float b = dv_breath(t) * reach;
	float r_clear = dv_clear * b;
	float r_dark = dv_dark * b;
	float dist = length(p - dv_eye);
	// 가까운 곳은 덜 흔들어 발밑이 떨리지 않게, 경계로 갈수록 많이
	float edge = smoothstep(r_clear * 0.5, r_clear, dist);
	float d = dist + n * DV_WARP * (0.3 + 0.7 * edge);
	return 1.0 - smoothstep(r_clear, r_dark, d);
}

// 계단 + Bayer 디더 (0..1 → 0, 1/L, …, 1)
float dv_dither(float v, vec2 dv_c) {
	vec2 q = mod(dv_c, 4.0);
	float th = (DV_BAYER[int(q.x) + int(q.y) * 4] + 0.5) / 16.0;
	float s = clamp(v, 0.0, 1.0) * DV_LEVELS;
	float base = floor(s);
	return clamp((base + step(th, s - base)) / DV_LEVELS, 0.0, 1.0);
}

// 흐르는 액센트 결 (0..1) — 가시도 결(dv_flow)과 다른 크기·방향으로 천천히 흐른다
float dv_accent(vec2 p, float t) {
	return smoothstep(0.45, 0.85, dv_fbm((p + vec2(-t * 9.0, t * 4.0)) / 700.0 + 73.0));
}

// 그림자 팔레트 색. dark = 어둠 정도(0..1, 이미 디더된 값), a = 액센트 결, dv_c = 격자 칸 (경계→심연 밴드 디더용)
vec3 dv_palette(float dark, float a, vec2 dv_c) {
	float depth = dv_dither(smoothstep(0.2, 1.0, dark), dv_c + vec2(2.0, 1.0));
	vec3 base = mix(dv_shadow_edge.rgb, dv_shadow_deep.rgb, depth);
	// 색은 경계 띠에만 — 깊은 어둠은 거의 검정 그대로 (DV_DEEP_KEEP 만큼만 색이 남는다)
	return (base + dv_shadow_accent.rgb * a * 0.5) * mix(1.0, DV_DEEP_KEEP, depth);
}

// 표면용 가시도 + 그림자색. 반환 xyz = 어둠 속 표면이 물드는 색(명도 곱하기 전), w = 디더된 가시도(1 = 다 보임)
vec4 dv_surface(vec2 frag, float t, float reach) {
	if (dv_on < 0.5) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}
	vec2 dv_c = dv_cell(frag);
	vec2 p = (dv_c + 0.5) * DV_PIXEL;
	// 시야 안쪽 절반은 노이즈가 밀어도 항상 다 보인다 (dv_seen: 흔들림 ≤ 0.3·WARP) — 노이즈 계산을 통째로 건너뛴다
	if (length(p - dv_eye) < dv_clear * reach * (1.0 - DV_BREATHE) * 0.5) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}
	float vis = dv_dither(dv_seen(p, dv_flow(p, t), t, reach), dv_c);
	if (vis >= 1.0) {
		return vec4(0.0, 0.0, 0.0, 1.0);
	}
	float accent = dv_dither(dv_accent(p, t), dv_c + vec2(1.0, 3.0));
	return vec4(dv_palette(1.0 - vis, accent, dv_c), vis);
}

// 표면용: 이 화면 픽셀의 디더된 가시도. 1 = 다 보임
float dv_visibility(vec2 frag, float t, float reach) {
	return dv_surface(frag, t, reach).w;
}

// 어둠 속 표면색: 앰비언트 성분 col 을 가시도만큼 남기고, 경계 띠에서만 명도를 그림자 팔레트로 색조 이동시킨다 (깊은 어둠은 검정).
// gain 은 CanvasModulate(앰비언트 ≈0.4)가 뒤에서 곱해지는 것을 보정한 배율.
vec3 dv_shade(vec3 col, vec4 sh, float keep) {
	float lum = dot(col, vec3(0.30, 0.59, 0.11));
	float dark = 1.0 - sh.w;
	// 빛에서 어둠으로 넘어가는 중간 띠에서만 색조가 옮겨 간다. 완전한 어둠에서는 0 — 광원 빛만 남는다
	float band = dark * (1.0 - smoothstep(0.3, 0.85, dark));
	vec3 shadow = sh.rgb * (0.2 + 1.6 * lum) * 1.4;
	return col * mix(keep, 1.0, sh.w) + shadow * band;
}
