shader_type canvas_item;
// 프랍 표면: lit_surface + 파츠 마스크(깨진 셀 투명, 파단면 어둡게) + 피격 컬러 피드백.
// hit_fx_preset 0은 프랍의 기존 국소 적색 플래시, 1~4는 크롤러용 비교 프리셋이다.
#include "res://shaders/lit_common.gdshaderinc"

uniform vec2 grid = vec2(1.0, 1.0);                     // 마스크 셀 수 (cols, rows)
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 hit_uv = vec2(0.5, 0.5);
uniform float radius_px = 64.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.42, 0.30);
uniform int hit_fx_preset : hint_range(0, 4, 1) = 0;
uniform float hit_fx_phase : hint_range(0.0, 1.0) = 0.0;

float hit_luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// 피격 컬러 피드백 (프리셋 0~4). 암흑 전 색·후 색에 똑같이 적용한다 — 플래시는 발광이라 어둠 속에서도 번쩍인다.
vec3 hit_fx(vec3 col, float edge, vec2 uv, vec2 px) {
	vec4 lit = vec4(col, 1.0);
	// 탄착점 거리 마스크. 프리셋 1~4는 전신 변화와 이 국소 마스크를 조합한다.
	float d = length((uv - hit_uv) / px);
	float local = 1.0 - smoothstep(radius_px * 0.25, radius_px, d);
	float k = flash * local;
	float p = clamp(hit_fx_phase, 0.0, 1.0);

	if (hit_fx_preset == 0) {
		// 프랍 호환: 종전의 국소 적색 플래시.
		lit.rgb = mix(lit.rgb, flash_color * 2.4, k);
	} else if (hit_fx_preset == 1) {
		// 1. WHITE SNAP — 메탈슬러그식 한 프레임 전신 백색 + 탄착점의 따뜻한 잔광.
		float snap = 1.0 - smoothstep(0.08, 0.38, p);
		float amount = clamp(snap * flash * 0.96 + k * 0.34, 0.0, 1.0);
		vec3 hot_white = vec3(2.75, 2.58, 2.24);
		lit.rgb = mix(lit.rgb, hot_white, amount);
	} else if (hit_fx_preset == 2) {
		// 2. COMPLEMENT PULSE — 원색을 남기면서 보색을 은은하게 얹는 부드러운 펄스.
		vec3 base = clamp(lit.rgb, vec3(0.0), vec3(1.0));
		vec3 complement = vec3(1.0) - base;
		float pulse = flash * (0.34 + 0.34 * local);
		vec3 cool_complement = complement * vec3(0.92, 1.16, 1.30) + vec3(0.03, 0.06, 0.12);
		lit.rgb = mix(lit.rgb, cool_complement, clamp(pulse, 0.0, 0.68));
	} else if (hit_fx_preset == 3) {
		// 3. TOXIC NEGATIVE — 명암을 두 톤으로 압축해 산성 녹색/보라 네거티브 실루엣으로 뒤집는다.
		float lum = hit_luma(clamp(lit.rgb, vec3(0.0), vec3(1.0)));
		float band = smoothstep(0.30, 0.68, lum);
		vec3 toxic = mix(vec3(0.24, 0.025, 0.34), vec3(1.18, 2.05, 0.28), band);
		toxic += vec3(0.78, 0.08, 0.72) * edge * 0.55;
		float amount = clamp(flash * (0.78 + 0.22 * local), 0.0, 1.0);
		lit.rgb = mix(lit.rgb, toxic, amount);
	} else {
		// 4. HEAT ECHO — 백열 충격 뒤 적열이 남고, 탄착점에서 주황색 링이 퍼진다.
		float ignition = 1.0 - smoothstep(0.02, 0.24, p);
		float ember = smoothstep(0.08, 0.28, p) * (1.0 - smoothstep(0.45, 1.0, p));
		float ring_radius = radius_px * mix(0.10, 0.88, p);
		float ring = 1.0 - smoothstep(5.0, 18.0, abs(d - ring_radius));
		vec3 ignition_color = vec3(3.0, 1.78, 0.42);
		vec3 ember_color = vec3(1.42, 0.075, 0.018);
		lit.rgb = mix(lit.rgb, ember_color, clamp(ember * (0.46 + 0.34 * local), 0.0, 0.74));
		lit.rgb = mix(lit.rgb, ignition_color, clamp(ignition * flash * (0.68 + 0.30 * local), 0.0, 0.98));
		lit.rgb += vec3(2.0, 0.52, 0.06) * ring * flash * 0.48;
	}
	return lit.rgb;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// 마스크가 없으면(mask_on 꺼짐 — 크롤러·보행 기체·센트리건) 전부 온전하고 깨진 이웃도 없다 → 아래는 곱하기 1 이다.
	if (mask_on) {
		float intact = step(0.5, texture(mask, UV).r);
		c.a *= intact;
		// 파단면: 이웃 셀이 깨졋으면 셀 가장자리를 어둡게 (찢긴 단면)
		vec2 cell = 1.0 / grid;
		float broken_n = 0.0;
		broken_n += 1.0 - step(0.5, texture(mask, UV + vec2(cell.x, 0.0)).r);
		broken_n += 1.0 - step(0.5, texture(mask, UV - vec2(cell.x, 0.0)).r);
		broken_n += 1.0 - step(0.5, texture(mask, UV + vec2(0.0, cell.y)).r);
		broken_n += 1.0 - step(0.5, texture(mask, UV - vec2(0.0, cell.y)).r);
		vec2 f = fract(UV * grid);
		float border = 1.0 - smoothstep(0.0, 0.22, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		c.rgb *= 1.0 - 0.55 * border * clamp(broken_n, 0.0, 1.0);
	}

	float edge;
	vec2 edge_dir;
	vec3 base;
	vec4 lit = lit_fragment(TEXTURE, UV, TEXTURE_PIXEL_SIZE, c, FRAGCOORD.xy, TIME, edge, edge_dir, base);
	v_edge = edge;
	v_edge_dir = edge_dir;
	v_base = hit_fx(base, edge, UV, TEXTURE_PIXEL_SIZE);
	lit.rgb = hit_fx(lit.rgb, edge, UV, TEXTURE_PIXEL_SIZE);
	COLOR = lit;
}

void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_COLOR, LIGHT_ENERGY, v_base);
}
