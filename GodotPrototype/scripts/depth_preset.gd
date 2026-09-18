class_name DepthPreset
extends RefCounted
## 공간감(층 분리) 프리셋 — 이번 작업 전/후를 실행 중에 A/B 로 비교하기 위한 표. F2 로 전환(같은 방·위치에서 Main 재로드).
##
##  0 이전 (평면)   : 먼지 레이어가 캐릭터 위(z6)에 덮이고, 모든 층이 같은 라이트를 같은 세기로 받는다. 근경 없음.
##  1 근경 분리     : 먼지·빛 기둥은 벽과 인물 사이(z3~4), 벽 램프·채광·비상등은 배경 층(z≤4)만 정면으로 비추고
##                    인물 층(z5~6)은 55%(바닥 풀·바닥 라이트는 75%) 의 거울 라이트(LightMirror)가 비춘다.
##                    근경 실루엣 층(ForegroundLayer, z7)은 몸체는 라이트를 받지 않고 윤곽 띠만 림으로 반응하며 플레이어 이동의 1.045배로 움직인다.
##
## 환경 변수 DEPTH_PRESET=<0|1> 로 시작 프리셋을 고정할 수 있다 (tools/depth_ab_shot.gd 비교 스크린샷용).

const PRESETS := [
	{
		"id": "flat", "name": "이전 (평면)",
		"desc": "먼지가 캐릭터 위에 덮이고 모든 층이 같은 조명 · 근경 없음 — 층 분리 작업 전 모습",
	},
	{
		"id": "layered", "name": "근경 분리",
		"desc": "먼지·빛 기둥은 벽↔인물 사이 · 인물 층은 램프 빛 55% · 근경 실루엣(z7, 패럴랙스 1.045×)은 몸체 검정 + 윤곽 림만",
	},
]
const DEFAULT := 1
static var index := DEFAULT

## 층 번호 (Room 이 정하는 z_index 와 맞춘다)
const Z_BACK_MAX := 4        # 배경 층: 타일 0 · 뒷벽 문 1 · 프랍 2 · 먼지 3 · 빛 기둥/환경 연출 4
const Z_ACTOR_MIN := 5       # 인물 층: 플레이어·몬스터 5 · 탄·탄피 6
const Z_ACTOR_MAX := 6
const Z_FOREGROUND := 7      # 근경 실루엣

## 인물 층이 받는 벽 조명 비율 (배경 층 = 1.0)
const ACTOR_LIGHT_RATIO := 0.55
const ACTOR_FLOOR_LIGHT_RATIO := 0.75


## Main 시작 시 호출. 환경 변수가 있으면 우선.
static func activate() -> Dictionary:
	var env := OS.get_environment("DEPTH_PRESET")
	if env != "" and env.is_valid_int():
		index = wrapi(int(env), 0, PRESETS.size())
	return current()


static func current() -> Dictionary:
	return PRESETS[wrapi(index, 0, PRESETS.size())]


static func enabled() -> bool:
	return index == 1


static func toggle_index() -> int:
	return 0 if index == 1 else 1


## HUD 한 줄: " 1 이전 (평면)   [2 근경 분리]"
static func hud_line() -> String:
	var names := PackedStringArray()
	for i in range(PRESETS.size()):
		var n: String = PRESETS[i]["name"]
		names.append(("[%d %s]" if i == index else " %d %s ") % [i + 1, n])
	return "  ".join(names)
