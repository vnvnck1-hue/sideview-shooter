shader_type canvas_item;
#include "res://shaders/light_falloff.gdshaderinc"
// 몬스터 체액 — **젖은 유기물**. 예전에는 light_response 0.28 에 스페큘러가 없어 씬에서 제일 둔한 물질이었고,
// 그 탓에 어떤 표면 위에 붙어도 같은 톤의 평평한 초록 스티커로 읽혔다. 젖은 것은 반대다:
// 베이스는 어둡게 깔리고 **좁고 강한 하이라이트**가 맺혀야 두께와 곡면이 보인다.
//
// 자국이 프랍 위에 붙었으면 그 프랍의 노멀맵(host_normal)을 **프랍 로컬 좌표**로 샘플해 같은 굴곡으로 반짝인다
// → 표면 위에 얹힌 막처럼 보이고, 프랍이 가진 입체가 자국에서도 끊기지 않는다.
// 프랍이 아닌 곳(뒷벽·바닥)은 평면 노멀 + 고정 키 하이라이트만 쓴다. 대신 그쪽은 얇은 막(fluid_film, 곱연산)이
// 아래 표면의 명암을 그대로 비춰 주므로 평면감이 생기지 않는다.
//
// _draw 로 그린 사각형(버텍스 컬러)을 쓰므로 TEXTURE 는 샘플하지 않는다.

uniform float light_response : hint_range(0.0, 2.0) = 0.72;    // 1.0 = 기본 라이팅과 같음
uniform float saturation : hint_range(0.0, 1.5) = 0.82;        // 채도 눌러 형광기 제거
uniform float spec_strength : hint_range(0.0, 8.0) = 2.6;      // 젖음의 핵심 — 좁고 강한 하이라이트
uniform float spec_power : hint_range(2.0, 128.0) = 42.0;
uniform float key_wet : hint_range(0.0, 1.0) = 0.20;           // 광원이 없어도 우상단에서 맺히는 고정 젖은 기
uniform sampler2D host_normal : hint_normal, filter_nearest, repeat_disable;
uniform vec4 host_rect = vec4(0.0, 0.0, 1.0, 1.0);             // 숙주 프랍 텍스처의 로컬 사각형 (x, y, w, h)
uniform float host_flip = 0.0;                                 // 1 이면 좌우 뒤집힌 스프라이트
uniform float use_host_normal = 0.0;

varying vec2 v_local;                                          // 자국 노드의 로컬 좌표 = 숙주 프랍의 로컬 좌표

void vertex() {
	v_local = VERTEX;
}

// 자국이 앉은 표면의 노멀. 숙주 프랍이 있으면 그 노멀맵, 없으면 평면.
vec3 surface_normal() {
	if (use_host_normal < 0.5) {
		return vec3(0.0, 0.0, 1.0);
	}
	vec2 uv = (v_local - host_rect.xy) / max(host_rect.zw, vec2(1.0));
	if (host_flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec3 n = texture(host_normal, clamp(uv, vec2(0.002), vec2(0.998))).xyz * 2.0 - 1.0;
	n.y = -n.y;                                                // 캔버스 노멀맵 규약 (2D 는 +Y 가 아래)
	// 체액 막은 표면 굴곡을 약간 메운다 — 원본 노멀을 그대로 쓰지 않고 평면 쪽으로 조금 당긴다
	return normalize(mix(vec3(0.0, 0.0, 1.0), n, 0.8));
}

void fragment() {
	vec3 c = COLOR.rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, saturation);
	// 고정 키 하이라이트: 광원이 닿지 않는 자국도 젖어 보이게 (우상단에서 오는 약한 빛)
	vec3 N = surface_normal();
	float key = pow(max(dot(N, normalize(vec3(0.42, -0.70, 0.58))), 0.0), spec_power * 0.45);
	COLOR = vec4(c + key * key_wet, COLOR.a);
}

void light() {
	vec3 N = surface_normal();
	vec3 L = LIGHT_DIRECTION;
	float ndl = max(dot(N, L), 0.0);
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(N, H), 0.0), spec_power) * spec_strength;
	// 광원 색을 채도 낮게 섭취: 빛의 밝기는 받되 색이 물들지는 덜 하게
	vec3 lc = LIGHT_COLOR.rgb * LIGHT_ENERGY;
	float llum = dot(lc, vec3(0.299, 0.587, 0.114));
	lc = mix(vec3(llum), lc, 0.5);
	float at = diffuse_atten(LIGHT_COLOR.a);
	// 디퓨즈는 체액색으로, 스페큘러는 흰빛에 가깝게 (젖은 표면의 정반사)
	vec3 diff = COLOR.rgb * light_response * (0.35 + 0.65 * ndl);
	LIGHT = vec4(lc * at * (diff + spec * (0.55 + 0.45 * COLOR.rgb)), 1.0);
}
