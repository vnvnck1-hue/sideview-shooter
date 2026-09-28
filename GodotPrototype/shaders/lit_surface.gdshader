shader_type canvas_item;
// 타일·문·캐릭터·파편 공용 표면 셰이더: 강한 노멀맵 반응 + 림라이트 + 피격 열 잔광 + 암흑 시야.
#include "res://shaders/lit_common.gdshaderinc"

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (mask_on) {
		c.a *= step(0.5, texture(mask, UV).r);
	}
	float edge;
	vec2 edge_dir;
	vec3 base;
	COLOR = lit_fragment(TEXTURE, UV, TEXTURE_PIXEL_SIZE, c, FRAGCOORD.xy, TIME, edge, edge_dir, base);
	v_base = base;
	v_edge = edge;
	v_edge_dir = edge_dir;
}

void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_COLOR, LIGHT_ENERGY, v_base);
}
