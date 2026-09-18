shader_type canvas_item;
#include "res://shaders/light_falloff.gdshaderinc"
// 근경 실루엣의 가장자리 띠(ForegroundLayer._rect 가 사각형 네 변에 4px 띠로 만든다)용 림 라이트.
// 몸체는 잉크색 그대로(unshaded 폴리곤, 라이트 제외)이고, 이 띠만 라이트를 받는다:
// 정점 색 rg 에 담긴 변의 바깥 법선이 광원을 향할 때만 그 광원 색으로 밝아진다 → 형체의 윤곽이 광원 쪽에서 읽힌다.
// CanvasModulate(앰비언트 ≈0.35)가 결과에 다시 곱해지므로 rim_strength 로 보정한다.

uniform vec4 ink : source_color = vec4(0.07, 0.07, 0.10, 1.0);
uniform float rim_strength : hint_range(0.0, 8.0) = 0.8;   // 2.6 은 너무 강했다 → 30%
uniform float rim_falloff : hint_range(0.5, 4.0) = 1.4;     // 법선·광원 방향 코사인의 지수 (클수록 정면 변에만)
uniform float rim_reach : hint_range(0.1, 1.0) = 0.55;      // 광원 감쇠를 pow 로 펴서 멀리서도 윤곽이 살짝 물든다

// 방 경계(방 로컬 px). 열별 천장은 계단형이라 배열로 받는다 — 방 밖(어둠)에 있는 띠와, 어둠 쪽을 향한 면은 림이 없어야 한다.
const int MAX_COLS = 32;
uniform float room_w = 1792.0;
uniform float room_bottom = 560.0;
uniform float cell_w = 128.0;
uniform int col_count = 0;
uniform float col_ceiling[32];
uniform float edge_fade : hint_range(0.0, 600.0) = 240.0;    // 이 거리 안에서 어둠 쪽을 향한 면의 림이 사라진다
uniform float void_fade : hint_range(0.0, 200.0) = 48.0;     // 방 경계를 넘어가면 이 거리 안에서 림 전체가 사라진다

varying vec2 edge_n;
varying vec2 local_px;

void vertex() {
	edge_n = COLOR.rg * 2.0 - 1.0;
	local_px = VERTEX;
}

// 이 지점의 천장 y (열별)
float ceiling_at(float x) {
	if (col_count <= 0) return -1e9;
	int c = clamp(int(floor(x / cell_w)), 0, col_count - 1);
	return col_ceiling[c];
}

// 어둠 쪽 억제: 방 밖이면 0, 방 안에서도 가까운 경계 방향을 향한 면은 그 경계에 가까울수록 0
float room_factor(vec2 p, vec2 n) {
	float cy = ceiling_at(p.x);
	float d_left = p.x;                 // 왼쪽 벽까지
	float d_right = room_w - p.x;
	float d_top = p.y - cy;             // 천장까지
	float d_bottom = room_bottom - p.y; // 바닥 밴드 하단까지
	float inside = min(min(d_left, d_right), min(d_top, d_bottom));
	float in_room = smoothstep(-void_fade, 0.0, inside);
	float dark = 0.0;
	dark = max(dark, max(-n.x, 0.0) * (1.0 - smoothstep(0.0, edge_fade, d_left)));
	dark = max(dark, max( n.x, 0.0) * (1.0 - smoothstep(0.0, edge_fade, d_right)));
	dark = max(dark, max(-n.y, 0.0) * (1.0 - smoothstep(0.0, edge_fade, d_top)));
	dark = max(dark, max( n.y, 0.0) * (1.0 - smoothstep(0.0, edge_fade, d_bottom)));
	return in_room * (1.0 - dark);
}

void fragment() {
	COLOR = ink;
}

void light() {
	vec2 L = LIGHT_DIRECTION.xy;
	float l2 = dot(L, L);
	vec2 n = normalize(edge_n);
	float f = l2 > 1e-6 ? max(dot(n, L / sqrt(l2)), 0.0) : 0.0;
	f = pow(f, rim_falloff);
	// LIGHT_COLOR = (라이트 색, 텍스처 알파 = 거리 감쇠). 감쇠만 rim_atten 으로 펴서 도달 범위를 넓힌다 (밝기 자체는 안 키움)
	float reach = rim_atten(LIGHT_COLOR.a, rim_reach);
	f *= room_factor(local_px, n);
	LIGHT = vec4(LIGHT_COLOR.rgb * reach * LIGHT_ENERGY * f * rim_strength, 1.0);
}
