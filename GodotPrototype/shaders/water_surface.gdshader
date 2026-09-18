shader_type canvas_item;
#include "res://shaders/light_falloff.gdshaderinc"
// 바닥에 고인 물 (사이드뷰 수면). 리서치 1번 기법: 스크린 텍스처 반사 + 굴절.
//  - 수면선(surface_y, 로컬 px) 아래 픽셀은 이미 그려진 화면을 수면선 기준으로 위아래 뒤집어 반사한다.
//    반사 대상은 이 노드보다 z 가 낮아야 하므로 WaterPool 은 인물 층(z5) 위에 올린다.
//  - 물속(뒤의 바닥·발)은 좌우로 1~2 뷰픽셀 흔들어 굴절시킨다.
//  - 저해상도 뷰포트(534×300)에 그리므로 프래그먼트 = 뷰 픽셀. 흔들림은 정수 뷰픽셀로 스냅해 격자가 뭉개지지 않는다.
//  - 수면선 → 화면 거리는 varying 의 dFdy 로 구해 카메라 줌·렌더 프리셋에 상관없이 맞는다.
//  - CanvasModulate 가 이미 적용된 화면을 다시 어둡게 그리므로 ambient_inv 로 반사상을 되살린다.
//  - 수면 높이(height_tex, 스프링 열)만큼 수면선이 올라가고(뷰픽셀로 스냅), 기울기가 반사를 좌우로 흔든다.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float surface_y = 0.0;                       // 수면선 (폴리곤 로컬 y, px) — 정지 수면
uniform sampler2D height_tex : filter_linear, repeat_disable;   // N×1 RF: 스프링 높이(px, 위가 +). WaterPool 이 매 스텝 갱신
uniform vec2 x_range = vec2(0.0, 1.0);               // height_tex 가 덮는 로컬 x 범위
uniform float slope_shift : hint_range(0.0, 6.0) = 1.2;    // 수면 기울기(px/px) → 반사 좌우 흔들림 (뷰픽셀)
uniform float depth_px = 100.0;                      // 수면선 ~ 폴리곤 바닥 (px)
uniform vec3 water_tint : source_color = vec3(0.22, 0.38, 0.55);
uniform vec3 ambient_inv = vec3(1.0, 1.0, 1.0);      // 1 / CanvasModulate — 반사상 밝기 복원
uniform float reflect_gain : hint_range(0.0, 1.5) = 0.9;   // 반사 복원 비율 (0 = 보정 없음, 1 = 완전 복원)
uniform float reflect_near : hint_range(0.0, 1.0) = 0.85;   // 수면선 바로 아래 반사 비율
uniform float reflect_far : hint_range(0.0, 1.0) = 0.30;    // 폴리곤 바닥(가까운 물)의 반사 비율
uniform float tint_near : hint_range(0.0, 1.0) = 0.25;      // 물색 섞임 (수면선)
uniform float tint_far : hint_range(0.0, 1.0) = 0.65;       // 물색 섞임 (바닥)
uniform float wave_px : hint_range(0.0, 4.0) = 1.5;         // 반사 좌우 흔들림 최대 (뷰픽셀)
uniform float wave_scale = 0.045;                           // 노이즈 밀도 (로컬 px 당)
uniform float wave_speed = 0.6;
uniform float squash : hint_range(0.5, 1.5) = 0.9;          // 반사상 세로 압축 (1 = 정확한 거울)
uniform float refract_px : hint_range(0.0, 3.0) = 1.0;      // 물속 굴절 (뷰픽셀)
uniform float surface_line : hint_range(0.0, 2.0) = 1.3;    // 수면 하이라이트 선 세기
uniform float sheen : hint_range(0.0, 2.0) = 0.55;          // 흐르는 결 (광원 스페큘러 마스크)
uniform float alpha_bottom : hint_range(0.0, 1.0) = 0.92;
uniform int levels = 4;                                     // 흔들림·결 포스터라이즈 단계

varying float v_local_y;
varying float v_local_x;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float posterize(float v, int n) { return floor(v * float(n) + 0.5) / float(n); }

void vertex() {
	v_local_y = VERTEX.y;
	v_local_x = VERTEX.x;
}

void fragment() {
	// 로컬 px → 뷰 px 배율 (선형 varying 이라 삼각형 안에서 상수)
	float dl = max(abs(dFdy(v_local_y)), 1e-4);          // 뷰 1px 당 로컬 px
	// 스프링 수면 높이: 뷰픽셀로 스냅해 계단이 살아 있게. 기울기는 이웃 텍셀 차이.
	float u = (v_local_x - x_range.x) / max(x_range.y - x_range.x, 1.0);
	float tw = 1.0 / float(textureSize(height_tex, 0).x);
	float h = texture(height_tex, vec2(u, 0.5)).r;
	float hl = texture(height_tex, vec2(u - tw, 0.5)).r;
	float hr = texture(height_tex, vec2(u + tw, 0.5)).r;
	h = floor(h / dl + 0.5) * dl;
	float slope = (hr - hl) / (2.0 * tw * (x_range.y - x_range.x));   // px 당 px
	float depth_local = v_local_y - (surface_y - h);      // 수면선 아래 깊이 (로컬 px)
	if (depth_local < 0.0) {
		discard;
	}
	float t = clamp(depth_local / max(depth_px, 1.0), 0.0, 1.0);
	vec2 px = SCREEN_PIXEL_SIZE;

	// 물결 노이즈: 두 층, 아래로 흐름. 결과는 정수 뷰픽셀로 스냅.
	vec2 np = vec2(v_local_x, depth_local) * wave_scale;
	float n1 = vnoise(np * vec2(1.0, 2.2) + vec2(TIME * wave_speed * 0.35, -TIME * wave_speed));
	float n2 = vnoise(np * vec2(2.3, 4.0) + vec2(-TIME * wave_speed * 0.5, -TIME * wave_speed * 1.7));
	float w = (n1 * 0.65 + n2 * 0.35) * 2.0 - 1.0;                // -1 ~ 1
	w = posterize(w, levels);
	float amp = wave_px * (0.35 + 0.65 * t);                      // 가까운 물일수록 크게 흔들림
	float shift_px = floor(w * amp + slope * slope_shift * 4.0 + 0.5);

	// 반사: 수면선 기준으로 뒤집기. depth(로컬) → 뷰픽셀 → 스크린 UV
	float depth_scr = depth_local / dl;                           // 뷰픽셀
	float refl_y = SCREEN_UV.y - (depth_scr * (1.0 + squash)) * px.y;
	// 폴리곤 자기 영역(수면선 아래)을 다시 샘플하지 않도록 수면선 위에서 멈춤
	float surface_scr_y = SCREEN_UV.y - depth_scr * px.y;
	refl_y = min(refl_y, surface_scr_y - px.y);
	vec2 refl_uv = vec2(SCREEN_UV.x + shift_px * px.x, refl_y);
	vec3 refl = texture(screen_tex, clamp(refl_uv, vec2(0.0), vec2(1.0))).rgb;
	float off_screen = step(refl_y, 0.0);                         // 화면 위로 벗어나면 물색만
	refl *= mix(vec3(1.0), ambient_inv, reflect_gain);

	// 굴절: 물속 배경(바닥·발)을 살짝 흔든다
	float r = posterize(vnoise(np * 3.1 + vec2(TIME * 0.4, TIME * 0.9)) * 2.0 - 1.0, levels);
	vec2 bg_uv = SCREEN_UV + vec2(floor(r * refract_px + 0.5) * px.x, 0.0);
	vec3 bg = texture(screen_tex, clamp(bg_uv, vec2(0.0), vec2(1.0))).rgb;

	// 합성: 수면선 근처는 반사, 아래로 갈수록 물색+바닥
	float k_refl = mix(reflect_near, reflect_far, t) * (1.0 - off_screen);
	float k_tint = mix(tint_near, tint_far, t);
	vec3 body = mix(bg, water_tint, k_tint);
	vec3 col = mix(body, refl, k_refl);

	// 흐르는 결 (밝은 줄) — 광원 스페큘러 마스크로도 쓴다
	float s = vnoise(vec2(v_local_x * 0.02 + TIME * 0.25, depth_local * 0.08 - TIME * 0.15));
	s = posterize(smoothstep(0.62, 0.9, s), 3);
	col += water_tint * s * sheen * 0.6;

	// 수면선 1 뷰픽셀 하이라이트 (군데군데 끊김)
	float line = step(depth_scr, 1.0) * step(0.35, vnoise(vec2(v_local_x * 0.05 + TIME * 0.7, 0.0)));
	col += vec3(0.85, 0.95, 1.0) * line * surface_line;

	float a = mix(0.7, alpha_bottom, t);
	COLOR = vec4(col, a);
}

void light() {
	// 광원(램프·비상등·불·총구)이 수면에 길게 비친다: 기본 디퓨즈 약하게 + 결 마스크로 스페큘러 줄무늬
	float dl = max(abs(dFdy(v_local_y)), 1e-4);
	float u = (v_local_x - x_range.x) / max(x_range.y - x_range.x, 1.0);
	float depth_local = v_local_y - (surface_y - texture(height_tex, vec2(u, 0.5)).r);
	float s = vnoise(vec2(v_local_x * 0.02 + TIME * 0.25, depth_local * 0.08 - TIME * 0.15));
	s = posterize(smoothstep(0.55, 0.9, s), 3);
	vec3 lc = LIGHT_COLOR.rgb * LIGHT_ENERGY;
	LIGHT = vec4(lc * (COLOR.rgb * 0.6 + vec3(0.35) * s * sheen), diffuse_atten(LIGHT_COLOR.a));
}
