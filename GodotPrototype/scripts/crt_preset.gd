class_name CrtPreset
extends RefCounted
## CRT 모니터 후처리 프리셋 표 (shaders/crt.gdshader 의 유니폼 값). 전역 오버레이 scripts/crt_overlay.gd(autoload "CrtFx")가 적용한다.
##   - 게임 안: F4 다음 프리셋 · Shift+F4 이전 프리셋 (모든 씬 공통, 화면 위 토스트로 이름 표시)
##   - 로비: "CRT 모니터" 드롭다운
##   - 선택은 user://crt.cfg 에 저장되고, 환경 변수 CRT_PRESET=<번호|id> 가 있으면 그것이 우선한다 (스크린샷 도구용)
##
## 화면 세로는 900, 아트 1px = 화면 2.5px 이므로 scanline_count 450 이 "아트 픽셀 한 행마다 주사선 한 줄"이다.
## mask_px 는 실제 화면 px 단위(창 크기에 따라 굵기가 달라짐) — 전체화면(1440p·4K)에서는 3~4 가 자연스럽다.

const DEFAULTS := {
	"curvature": 0.0, "corner_radius": 0.0, "vignette": 0.0,
	"scanline_strength": 0.0, "scanline_count": 450.0, "scanline_sharpness": 1.0,
	"mask_type": 0, "mask_strength": 0.0, "mask_px": 3.0,
	"aberration": 0.0, "bleed": 0.0, "halation": 0.0,
	"noise": 0.0, "flicker": 0.0, "rolling_bar": 0.0, "rolling_speed": 0.25,
	"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "tint": Color(1, 1, 1),
}

## 마스크 종류: 0 없음 · 1 애퍼처 그릴(세로 RGB 줄, 트리니트론) · 2 섀도 마스크(어긋난 RGB 점) · 3 슬롯 마스크(끊어진 세로 줄)
const PRESETS := [
	{
		"id": "off", "name": "끄기",
		"desc": "후처리 없음 — 원본 픽셀 그대로",
		"params": {},
	},
	{
		"id": "subtle", "name": "은은한 주사선",
		"desc": "평면 화면 · 아트 픽셀 행마다 얕은 주사선 · 아주 약한 RGB 그릴 · 비네트 — 픽셀 아트를 거의 건드리지 않는다",
		"params": {
			"scanline_strength": 0.2, "scanline_count": 450.0, "scanline_sharpness": 1.2,
			"mask_type": 1, "mask_strength": 0.08, "mask_px": 3.0,
			"vignette": 0.14, "brightness": 1.06,
		},
	},
	{
		"id": "arcade", "name": "아케이드 모니터",
		"desc": "약한 굽힘 · 둥근 모서리 · 선명한 주사선 · 애퍼처 그릴(트리니트론) · 밝은 곳 헐레이션 — 업소용 캐비닛 모니터",
		"params": {
			"curvature": 0.03, "corner_radius": 0.03, "vignette": 0.24,
			"scanline_strength": 0.36, "scanline_count": 450.0, "scanline_sharpness": 1.6,
			"mask_type": 1, "mask_strength": 0.22, "mask_px": 3.0,
			"aberration": 0.6, "halation": 0.14,
			"brightness": 1.18, "contrast": 1.06, "saturation": 1.08,
		},
	},
	{
		"id": "tv", "name": "가정용 TV (컴포지트)",
		"desc": "굽은 화면 · 굵은 주사선(300줄) · 섀도 마스크 · 가로 색 번짐 · 신호 잡음과 느리게 흐르는 밝기 띠 — 90년대 브라운관 TV",
		"params": {
			"curvature": 0.08, "corner_radius": 0.06, "vignette": 0.34,
			"scanline_strength": 0.3, "scanline_count": 300.0, "scanline_sharpness": 1.0,
			"mask_type": 2, "mask_strength": 0.18, "mask_px": 4.0,
			"aberration": 1.6, "bleed": 1.5, "halation": 0.1,
			"noise": 0.03, "flicker": 0.015, "rolling_bar": 0.05, "rolling_speed": 0.18,
			"brightness": 1.14, "contrast": 1.04, "saturation": 1.18,
		},
	},
	{
		"id": "worn", "name": "낡은 모니터",
		"desc": "심한 굽힘 · 깊은 주사선 · 슬롯 마스크 · 강한 색 분리와 번짐 · 잡음·깜빡임·흐르는 띠 · 탈색 — 방치된 공장 감시 모니터",
		"params": {
			"curvature": 0.12, "corner_radius": 0.08, "vignette": 0.5,
			"scanline_strength": 0.46, "scanline_count": 300.0, "scanline_sharpness": 1.3,
			"mask_type": 3, "mask_strength": 0.26, "mask_px": 4.0,
			"aberration": 2.6, "bleed": 2.5, "halation": 0.18,
			"noise": 0.08, "flicker": 0.05, "rolling_bar": 0.12, "rolling_speed": 0.3,
			"brightness": 1.22, "contrast": 1.1, "saturation": 0.82, "tint": Color(0.94, 1.0, 0.95),
		},
	},
	{
		"id": "green", "name": "녹색 단색 형광",
		"desc": "채도 0 + 녹색 형광체 · 굽은 화면 · 주사선 · 헐레이션 · 약한 깜빡임 — P1 형광 터미널",
		"params": {
			"curvature": 0.06, "corner_radius": 0.05, "vignette": 0.4,
			"scanline_strength": 0.4, "scanline_count": 450.0, "scanline_sharpness": 1.4,
			"bleed": 1.0, "halation": 0.26,
			"noise": 0.035, "flicker": 0.03,
			"brightness": 1.3, "contrast": 1.12, "saturation": 0.0, "tint": Color(0.36, 1.0, 0.46),
		},
	},
	{
		"id": "amber", "name": "호박색 단색 형광",
		"desc": "채도 0 + 호박색 형광체 · 굽은 화면 · 주사선 · 헐레이션 — P3 형광 터미널",
		"params": {
			"curvature": 0.06, "corner_radius": 0.05, "vignette": 0.4,
			"scanline_strength": 0.38, "scanline_count": 450.0, "scanline_sharpness": 1.4,
			"bleed": 1.0, "halation": 0.24,
			"noise": 0.03, "flicker": 0.02,
			"brightness": 1.3, "contrast": 1.1, "saturation": 0.0, "tint": Color(1.0, 0.7, 0.22),
		},
	},
]
## **게임 전체의 고정 프리셋** (2026-09-23). 인덱스는 PRESETS 배열 기준(0부터) — 2 = "아케이드 모니터".
## F4 로 바꾼 값이 저장돼 사람마다·씬마다 화면이 달랐다 — 연출을 맞출 기준이 없어서 고정했다.
## 보행 기체(버그봇)에 접속하면 여기서 LINKED(3, 가정용 TV)로 한 단 떨어진다.
## (README·토스트는 1부터 센다: 아케이드 = 3번, 가정용 TV = 4번. 한때 둘을 섞어 적어 한 칸씩 밀려 있었다)
const DEFAULT := 2
## 기체에 접속해 **그 기체의 눈으로 볼 때**의 프리셋. 굽음·색 번짐·잡음·흐르는 띠가 붙는다.
const LINKED := 3


static func count() -> int:
	return PRESETS.size()


static func get_preset(i: int) -> Dictionary:
	return PRESETS[wrapi(i, 0, PRESETS.size())]


## id 문자열("arcade") 또는 번호 문자열("2") → 인덱스. 모르면 -1.
static func find(key: String) -> int:
	if key.is_valid_int():
		var n := int(key)
		return n if n >= 0 and n < PRESETS.size() else -1
	for i in PRESETS.size():
		if PRESETS[i]["id"] == key:
			return i
	return -1


## 프리셋의 모든 유니폼 값(기본값 + 덮어쓴 값)
static func params(i: int) -> Dictionary:
	var out := DEFAULTS.duplicate()
	for k in get_preset(i)["params"]:
		out[k] = get_preset(i)["params"][k]
	return out


## 머티리얼에 프리셋을 적용한다
static func apply(mat: ShaderMaterial, i: int) -> void:
	var p := params(i)
	for k in p:
		var v = p[k]
		if v is Color:
			v = Vector3(v.r, v.g, v.b)
		mat.set_shader_parameter(k, v)


## 토스트/HUD 한 줄: " 1 끄기   [3 아케이드 모니터]   4 가정용 TV ..."
static func hud_line(index: int) -> String:
	var parts := PackedStringArray()
	for i in PRESETS.size():
		var n: String = PRESETS[i]["name"]
		parts.append(("[%d %s]" if i == index else " %d %s ") % [i + 1, n])
	return "  ".join(parts)
