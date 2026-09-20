shader_type canvas_item;
render_mode unshaded;
// 풀스크린 CRT 모니터 후처리. 루트 뷰포트 맨 위 CanvasLayer(scripts/crt_overlay.gd)의 ColorRect 에 걸려 월드·HUD·로비 전부에 적용된다.
// 모든 파라미터는 scripts/crt_preset.gd 의 프리셋 표가 채운다. 값이 0 인 효과는 분기·샘플을 건너뛴다.
//
//  화면 형태  : curvature(배럴 굽힘) · corner_radius(둥근 모서리) · vignette(가장자리 어둡게)
//  주사선     : scanline_strength · scanline_count(화면 높이당 줄 수 — 450 = 아트 1px 행마다 1줄) · scanline_sharpness
//  형광체 마스크: mask_type(0 없음 · 1 애퍼처 그릴 · 2 섀도 마스크 · 3 슬롯 마스크) · mask_strength · mask_px(삼색 한 묶음의 화면 px)
//  신호 열화  : aberration(색 분리 px) · bleed(가로 번짐 px) · halation(밝은 곳 주변 헐레이션) · noise · flicker · rolling_bar
//  색         : brightness · contrast · saturation · tint (saturation 0 + tint 로 단색 형광 모니터)
//  전환 연출  : collapse(전원 인가·차단 — 가로 한 줄로 수축) · flash(백색 섬광) · desync(채널 전환 — 행 찢김)
//               이 셋은 프리셋 표에 없다. scripts/crt_overlay.gd 가 단말기 접속 연출 중에만 직접 값을 넣는다 (평소 0).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float curvature : hint_range(0.0, 0.3) = 0.0;
uniform float corner_radius : hint_range(0.0, 0.3) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_count : hint_range(50.0, 1200.0) = 450.0;
uniform float scanline_sharpness : hint_range(0.2, 4.0) = 1.0;

uniform int mask_type : hint_range(0, 3) = 0;
uniform float mask_strength : hint_range(0.0, 1.0) = 0.0;
uniform float mask_px : hint_range(1.0, 12.0) = 3.0;

uniform float aberration : hint_range(0.0, 8.0) = 0.0;
uniform float bleed : hint_range(0.0, 6.0) = 0.0;
uniform float halation : hint_range(0.0, 1.0) = 0.0;
uniform float noise : hint_range(0.0, 0.5) = 0.0;
uniform float flicker : hint_range(0.0, 0.3) = 0.0;
uniform float rolling_bar : hint_range(0.0, 0.5) = 0.0;
uniform float rolling_speed : hint_range(0.0, 2.0) = 0.25;

uniform float brightness : hint_range(0.5, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform vec3 tint : source_color = vec3(1.0);

uniform float collapse : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 2.0) = 0.0;
uniform float desync : hint_range(0.0, 1.0) = 0.0;


float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// 배럴 굽힘: 중심은 그대로, 가장자리가 바깥으로 늘어나 모서리에 검은 베젤이 생긴다.
vec2 warp(vec2 uv) {
	vec2 c = uv * 2.0 - 1.0;
	c *= 1.0 + curvature * dot(c, c);
	c /= 1.0 + curvature * 0.5;                 // 화면 중앙 부분이 잘리지 않게 살짝 되돌림
	return c * 0.5 + 0.5;
}

// 둥근 사각 튜브 마스크 (1 = 화면 안, 0 = 베젤)
float tube_mask(vec2 uv, vec2 px) {
	if (curvature <= 0.0 && corner_radius <= 0.0) {
		return 1.0;                             // 평면·각진 화면: 가장자리 그대로
	}
	vec2 c = abs(uv * 2.0 - 1.0);
	float r = max(corner_radius, 0.0005);
	vec2 d = c - (1.0 - r);
	float dist = length(max(d, vec2(0.0))) - r;
	float aa = 2.0 * max(px.x, px.y) * 2.0;     // 2px 안티에일리어스 (정규화 좌표는 ×2)
	return 1.0 - smoothstep(-aa, aa, dist);
}

// 색 분리 + 가로 번짐을 한 번에: R 은 바깥, B 는 안쪽으로 밀리고 각 채널을 3점 가로 블러
vec3 sample_rgb(vec2 uv, vec2 dir, vec2 px) {
	vec2 off = dir * aberration * px;
	vec2 bx = vec2(bleed * px.x, 0.0);
	if (bleed <= 0.0) {
		return vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	}
	float r = texture(screen_tex, uv + off).r * 0.5 + texture(screen_tex, uv + off - bx).r * 0.25 + texture(screen_tex, uv + off + bx).r * 0.25;
	float g = texture(screen_tex, uv).g * 0.5 + texture(screen_tex, uv - bx).g * 0.25 + texture(screen_tex, uv + bx).g * 0.25;
	float b = texture(screen_tex, uv - off).b * 0.5 + texture(screen_tex, uv - off - bx).b * 0.25 + texture(screen_tex, uv - off + bx).b * 0.25;
	return vec3(r, g, b);
}

// 형광체 마스크: 화면 px 단위로 R·G·B 세로 줄. 섀도 마스크는 한 행 걸러 반 칸 어긋나고, 슬롯 마스크는 세로로 끊긴다.
vec3 phosphor_mask(vec2 frag) {
	if (mask_type == 0 || mask_strength <= 0.0) {
		return vec3(1.0);
	}
	float cell = mask_px / 3.0;
	float x = frag.x;
	float dim = 1.0 - mask_strength;
	if (mask_type == 2) {
		float row = floor(frag.y / mask_px);
		x += mod(row, 2.0) * mask_px * 0.5;
	}
	int idx = int(mod(floor(x / cell), 3.0));
	vec3 m = vec3(dim);
	if (idx == 0) { m.r = 1.0; } else if (idx == 1) { m.g = 1.0; } else { m.b = 1.0; }
	if (mask_type == 3) {
		// 슬롯: 세로 mask_px×2 주기에서 위쪽 1/4 만 어둡게, 열마다 반 주기 어긋남
		float col = floor(x / mask_px);
		float y = frag.y + mod(col, 2.0) * mask_px;
		float slot = step(mask_px * 0.5, mod(y, mask_px * 2.0));
		m *= mix(dim, 1.0, slot);
	}
	return m;
}

// 전원 인가·차단: 화면 전체가 가운데 가로 한 줄로 빨려 들어간다 (세로로 눌리고 가로로 늘어난다).
// 띠 바깥은 검게 잘라낸다. 반환값 < 0 이면 이 픽셀은 띠 밖 (검정).
float collapse_uv(inout vec2 uv) {
	if (collapse <= 0.0) {
		return 1.0;
	}
	float h = max(1.0 - collapse, 0.0008);          // 남은 띠 높이 (정규화)
	float y = (uv.y - 0.5) / h + 0.5;
	if (y < 0.0 || y > 1.0) {
		return -1.0;
	}
	uv.y = y;
	uv.x = 0.5 + (uv.x - 0.5) / (1.0 + collapse * 0.35);   // 가로로 늘어난 것처럼 보이게 안쪽만 샘플
	return 1.0;
}

// 채널 전환 글리치: 주사선 행 단위로 가로가 찢겨 흔들리고, 화면 전체가 세로로 조금 밀린다.
void desync_uv(inout vec2 uv) {
	if (desync <= 0.0) {
		return;
	}
	float t = floor(TIME * 26.0);
	float row = floor(uv.y * 240.0);
	float n = hash12(vec2(row, t));
	float torn = step(1.0 - desync * 0.75, n);              // 일부 행만 찢긴다 (desync 가 클수록 많이)
	uv.x += (hash12(vec2(row, t + 7.3)) - 0.5) * desync * 0.22 * torn;
	uv.y = fract(uv.y + (hash12(vec2(t, 11.1)) - 0.5) * desync * 0.06);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	if (curvature > 0.0) {
		uv = warp(uv);
	}
	float band = collapse_uv(uv);
	desync_uv(uv);
	float inside = tube_mask(uv, px) * step(0.0, band);
	if (inside <= 0.0) {
		COLOR = vec4(vec3(flash), 1.0);        // 베젤·수축 바깥도 섬광은 덮는다 (전 화면이 한 번 하얘진다)
	} else {
		vec2 cuv = clamp(uv, px * 0.5, 1.0 - px * 0.5);
		vec2 dir = cuv - vec2(0.5);
		float r = length(dir);
		vec2 ndir = dir / max(r, 1e-4) * r * 2.0;   // 가장자리에서 aberration px 만큼
		vec3 col = sample_rgb(cuv, ndir, px);

		// 헐레이션: 밝은 곳이 주변으로 부드럽게 퍼진 빛 (넓은 4점 샘플)
		if (halation > 0.0) {
			vec2 h = px * 6.0;
			vec3 glow = texture(screen_tex, cuv + vec2(h.x, 0.0)).rgb + texture(screen_tex, cuv - vec2(h.x, 0.0)).rgb
				+ texture(screen_tex, cuv + vec2(0.0, h.y)).rgb + texture(screen_tex, cuv - vec2(0.0, h.y)).rgb;
			glow *= 0.25;
			col += glow * glow * halation;
		}

		// 색 보정 (단색 모니터는 saturation 0 + tint)
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(luma), col, saturation);
		col = (col - 0.5) * contrast + 0.5;
		col *= tint * brightness;

		// 주사선: 밝은 픽셀은 빔이 굵어져 줄이 얕아진다
		if (scanline_strength > 0.0) {
			float s = abs(sin(cuv.y * scanline_count * PI));
			s = pow(s, scanline_sharpness);
			float beam = mix(1.0 - scanline_strength, 1.0, s);
			beam = mix(beam, 1.0, clamp(luma, 0.0, 1.0) * 0.45);
			col *= beam;
		}

		// 형광체 마스크 (실제 화면 px 기준)
		col *= phosphor_mask(FRAGCOORD.xy);

		// 신호 잡음 · 깜빡임 · 위에서 아래로 흐르는 밝기 띠
		if (noise > 0.0) {
			float n = hash12(FRAGCOORD.xy + fract(TIME * 61.7) * 1000.0);
			col += (n - 0.5) * noise;
		}
		if (flicker > 0.0) {
			col *= 1.0 - flicker * hash12(vec2(floor(TIME * 60.0), 3.7));
		}
		if (rolling_bar > 0.0) {
			float bar = fract(cuv.y + TIME * rolling_speed);
			col *= 1.0 - rolling_bar * (smoothstep(0.0, 0.12, bar) * (1.0 - smoothstep(0.12, 0.3, bar)));
		}

		// 비네트 + 베젤 경계
		if (vignette > 0.0) {
			col *= 1.0 - vignette * smoothstep(0.35, 1.0, r * 1.35);
		}
		col *= inside;
		// 수축할수록 남은 띠가 타들어가듯 밝아진다 (빔 에너지가 한 줄에 몰린다)
		if (collapse > 0.0) {
			col *= 1.0 + collapse * collapse * 3.0;
		}
		COLOR = vec4(max(col + vec3(flash), vec3(0.0)), 1.0);
	}
}
