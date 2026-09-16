shader_type canvas_item;
// 프랍 표면: lit_surface + 파츠 마스크(깨진 셀 투명, 파단면 어둡게) + 붉은 피격 플래시(탄착점 주변만).
#include "res://shaders/lit_common.gdshaderinc"

uniform vec2 grid = vec2(1.0, 1.0);                     // 마스크 셀 수 (cols, rows)
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec2 hit_uv = vec2(0.5, 0.5);
uniform float radius_px = 64.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.42, 0.30);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
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

	float edge;
	vec2 edge_dir;
	vec4 lit = lit_fragment(TEXTURE, UV, TEXTURE_PIXEL_SIZE, c, edge, edge_dir);
	v_edge = edge;
	v_edge_dir = edge_dir;
	// 붉은 피격 플래시 — 탄착점 주변만 (거리 감쇠). 중심은 1.0 을 넘겨 글로우.
	float d = length((UV - hit_uv) / TEXTURE_PIXEL_SIZE);
	float k = flash * (1.0 - smoothstep(radius_px * 0.25, radius_px, d));
	lit.rgb = mix(lit.rgb, flash_color * 2.4, k);
	COLOR = lit;
}

void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_COLOR, LIGHT_ENERGY, COLOR.rgb);
}
