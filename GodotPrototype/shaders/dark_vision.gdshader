shader_type canvas_item;
render_mode unshaded;
// 암흑 시야의 화면 마스크 (DarkVision). 본체 암흑은 표면 셰이더가 앰비언트만 가라앉히는 방식(dark_common)이고,
// 이 마스크는 그 바깥의 안전망이다 — 조명을 받지 않는 요소(데칼·입자·배경 그림 등)까지 먼 어둠 속에서 확실히 지운다.
//   · 관찰자 둘레: 표면 암흑보다 한참 바깥(reach 배)에서 시작해 부드럽게 검어진다.
//   · 광원: 씬의 모든 켜진 PointLight2D(램프·비상등·불·총구 화염·탄환·탄착·탄흔 잔열…)가 제 밝기·반경만큼 마스크를 걷어낸다.
//     그래서 총을 쏘거나 발광 탄이 지나가면 그 빛이 닿는 자리의 림·반사광이 어둠 속에 드러난다.
//   · 표면 암흑과 같은 흐르는 결·Bayer 디더를 써서 두 층의 경계가 이질감 없이 겹친다.
//   · 색: 검정이 아니라 방 테마의 그림자 팔레트(경계색 → 심연색 + 흐르는 액센트, dark_common.dv_palette).
//     팔레트 색은 아래 장면의 명도에 비례해 입힌다 — 물체가 있는 곳은 색조가 옮겨 간 그림자로 은은하게 남고,
//     방 바깥 허공(명도 0)은 검정 그대로라 방의 실루엣이 흐려지지 않는다 (픽셀아트식 hue-shift 그림자).
//     광원 둘레에는 그 빛의 색이 어둠 속으로 옅게 번져(빛무리) 광원 색이 공간의 분위기를 물들인다.

#include "res://shaders/dark_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float scene_gain = 1.5;      // 장면 명도 → 그림자색 세기
uniform float tint_floor = 0.6;      // 명도 0 에서 남는 그림자색 (허공이 완전히 죽지 않을 만큼만)
uniform float reach = 1.3;           // 관찰자 둘레 반경 배율 (표면 암흑 대비)
uniform float light_reach = 1.25;    // 광원 반경 배율
uniform float halo = 0.18;           // 광원 색이 어둠에 번지는 세기
uniform float halo_reach = 1.9;      // 빛무리가 닿는 반경 (광원 반경 대비)

const int MAX_LIGHTS = 32;
uniform int light_count = 0;
uniform vec2 lights[32];             // 월드 px
uniform float light_power[32];       // 0..1 (에너지 × 색 밝기)
uniform float light_radius[32];
uniform vec3 light_hue[32];          // 광원 색 (최대 성분 1 로 정규화)

void fragment() {
	float t = TIME;
	vec2 cell = dv_cell(FRAGCOORD.xy);
	vec2 p = (cell + 0.5) * DV_PIXEL;
	float n = dv_flow(p, t);
	float seen = dv_seen(p, n, t, reach);
	vec3 glow = vec3(0.0);
	for (int i = 0; i < light_count; i++) {
		float rad = light_radius[i] * light_reach;
		float ld = length(p - lights[i]) + n * rad * 0.2;
		float fall = 1.0 - smoothstep(rad * 0.45, rad, ld);
		seen = max(seen, fall * light_power[i]);
		float h = 1.0 - smoothstep(rad * 0.5, rad * halo_reach, ld);
		glow += light_hue[i] * h * h * light_power[i];
	}
	float a = dv_on > 0.5 ? 1.0 - dv_dither(seen, cell) : 0.0;
	float accent = dv_dither(dv_accent(p, t), cell + vec2(1.0, 3.0));
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(scene, vec3(0.30, 0.59, 0.11));
	float presence = clamp(lum * 30.0, 0.0, 1.0);   // 방 바깥 허공(명도 0)은 색도 빛무리도 입히지 않는다
	vec3 col = dv_palette(1.0 - seen, accent, cell) * (tint_floor * presence + scene_gain * lum);
	// 빛무리도 어둠과 같은 계단 + Bayer 로 끊어 픽셀아트 조명처럼
	glow = vec3(dv_dither(glow.r, cell), dv_dither(glow.g, cell), dv_dither(glow.b, cell));
	COLOR = vec4(col + glow * halo * presence, a);
}
