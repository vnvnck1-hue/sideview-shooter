shader_type canvas_item;
render_mode blend_mul, unshaded;
// 얇은 체액 막 — **아래 표면을 곱해서 물들인다**. 벽돌 결·프랍 면의 명암·노멀 음영이 자국을 그대로 통과해
// "위에 붙은 스티커"가 아니라 "그 표면이 젖은 것"으로 읽힌다. 자국이 평면적으로 보이던 가장 큰 원인이
// 불투명한 덩어리(알파 0.82~0.97)로 아래 표면을 통째로 덮은 것이라, 얇은 부분은 전부 이 재질로 간다.
//
// blend_mul 은 알파를 쓰지 않으므로(결과 = 아래색 × 내색) 두께를 알파가 아니라 색에 직접 담는다:
//   두께 0 → 흰색(= 아래가 그대로),  두께 1 → 체액색(= 아래가 체액색으로 눌림).
// 빛은 아래 표면이 이미 받았으므로 unshaded — 이 층은 빛을 따로 받지 않는다.

uniform float saturation : hint_range(0.0, 1.5) = 0.85;
uniform float density : hint_range(0.0, 2.0) = 1.0;      // 막 전체 두께 배율 (깊이별로 Room 이 넣는다)

void fragment() {
	vec3 t = COLOR.rgb;
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	t = mix(vec3(lum), t, saturation);
	float thickness = clamp(COLOR.a * density, 0.0, 1.0);
	COLOR = vec4(mix(vec3(1.0), t, thickness), 1.0);
}
