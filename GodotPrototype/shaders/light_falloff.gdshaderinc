// 라이트 거리 감쇠 공용 코드 — light() 를 가진 셰이더(lit_common·foreground_rim·smoke·fluid·water_surface)가 include 한다.
//
// Godot 의 LIGHT_COLOR 는 (라이트 색, 라이트 텍스처 알파). 거리 감쇠는 rgb 가 아니라 .a 에 있다.
// (예전 코드는 rgb 의 max 를 감쇠로 읽어 rim_reach 가 사실상 무효였다 — 림이 디퓨즈와 같은 곡선으로 좁게 꺼졌다.)
//
// 림 도달 범위를 라이트 반경 밖까지 넓히기 위해 Lighting.scale_for_radius 가 모든 라이트 반경에 light_range_mul 을 곱한다.
// 디퓨즈·스페큘러는 여기서 원래 반경의 감쇠 곡선으로 되돌려(diffuse_atten) 광원 밝기·범위는 그대로 보이고,
// 림만 rim_atten 으로 커진 반경까지 완만하게 닿는다.
global uniform float light_range_mul;

// Lighting.radial_texture() 의 알파 그라데이션: 반지름 r(0~1) → 알파. 점 (0,1) (0.3,0.6) (0.65,0.18) (1,0)
float radial_grad(float r) {
	r = clamp(r, 0.0, 1.0);
	if (r < 0.3) return mix(1.0, 0.6, r / 0.3);
	if (r < 0.65) return mix(0.6, 0.18, (r - 0.3) / 0.35);
	return mix(0.18, 0.0, (r - 0.65) / 0.35);
}

// 역함수: 알파 → 반지름 r(0~1)
float radial_grad_inv(float a) {
	a = clamp(a, 0.0, 1.0);
	if (a > 0.6) return mix(0.3, 0.0, (a - 0.6) / 0.4);
	if (a > 0.18) return mix(0.65, 0.3, (a - 0.18) / 0.42);
	return mix(1.0, 0.65, a / 0.18);
}

// 텍스처 알파 → 반경 배율 1 이었을 때의 디퓨즈 감쇠 (배율 밖은 0)
float diffuse_atten(float a) {
	float k = max(light_range_mul, 1.0);
	if (k <= 1.001) return a;
	return radial_grad(radial_grad_inv(a) * k);
}

// 텍스처 알파 → 림 감쇠. reach = 커진 반경 안에서의 감쇠 지수 (1 선형, 작을수록 멀리까지 평평). reach<=0 이면 예전처럼 디퓨즈 곡선 그대로.
float rim_atten(float a, float reach) {
	if (reach <= 0.0) return a;
	float r = radial_grad_inv(a);
	return pow(clamp(1.0 - r, 0.0, 1.0), reach);
}
