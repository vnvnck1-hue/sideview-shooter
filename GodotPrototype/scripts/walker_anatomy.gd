class_name WalkerAnatomy
extends RefCounted
## 첨부 원화(1536×1024)의 투영 좌표. 기준 포즈/편집은 이 점을 그대로 쓴다.
## 보행은 SpiderLegIK에서 별도의 깊이를 부여한 뒤 화면으로 투영한다.
## 보이는 부품의 기준점이며, 가려진 축의 기계적 해석은 검토할 수 있도록 별도로 표시한다.

const SOURCE_SHA256 := "198caf260a0f20dd7bee454172fdbdd9be42f549548aa0657c8ac0304faebcc8"
const SOURCE_PATH := "res://assets/reference/walker_original.png"
const SOURCE_SIZE := Vector2(1536, 1024)
const SCALE := 0.42
const ORIGIN := Vector2(815, 610)
const BODY_ROOT := ORIGIN
const TORSO_PIVOT := Vector2(826, 548)
const UPPER_CENTER := Vector2(887, 394)
const GUN_PIVOT := Vector2(756, 519)
const BARREL_ANCHOR := Vector2(735, 382)
const MUZZLE := Vector2(414, 376)

const LEGS := [
	{
		"id": "FF", "label": "먼 앞 · 왼쪽 좁은 다리", "far": true, "inferred": false,
		"mount": Vector2(617, 586), "hip": Vector2(506, 632), "knee": Vector2(365, 700),
		"ankle": Vector2(245, 848), "toe": Vector2(246, 921),
		"uncertain": ["mount", "hip"], "group": 0,
	},
	{
		"id": "FR", "label": "먼 뒤 · 접힌 다리 (추정)", "far": true, "inferred": true,
		"mount": Vector2(780, 582), "hip": Vector2(671, 590), "knee": Vector2(528, 642),
		"ankle": Vector2(460, 756), "toe": Vector2(479, 806),
		# 원화에서는 이 부분이 접혀 들려 있다. 기준 자세는 원본 그대로,
		# 보행에서는 몸 아래의 별도 접지 목표로 내린다. 원화의 들린 발을 가짜 바닥으로 삼지 않는다.
		"ground_toe": Vector2(665, 908), "uncertain": ["mount", "hip", "knee", "ankle", "toe"], "group": 1,
	},
	{
		"id": "NF", "label": "가까운 앞 · 중앙 큰 장갑", "far": false, "inferred": false,
		"mount": Vector2(746, 594), "hip": Vector2(583, 752), "knee": Vector2(739, 632),
		"ankle": Vector2(738, 877), "toe": Vector2(735, 936),
		"uncertain": ["mount", "knee"], "group": 1,
	},
	{
		"id": "NR", "label": "가까운 뒤 · 오른쪽 꺾인 다리", "far": false, "inferred": false,
		"mount": Vector2(1044, 578), "hip": Vector2(1073, 774), "knee": Vector2(1193, 710),
		"ankle": Vector2(1294, 856), "toe": Vector2(1290, 921),
		"uncertain": ["mount", "knee"], "group": 0,
	},
]

const COLORS := {
	"chassis": Color("f4c66a"), "torso": Color("b08cff"), "gun": Color("7ddcf9"),
	"upper": Color("f28b73"), "lower": Color("83c984"), "foot": Color("78aef9"),
}


static func local_point(raw: Vector2) -> Vector2:
	return (raw - ORIGIN) * SCALE


static func ground_level() -> float:
	var lowest := -INF
	for leg in LEGS:
		var toe: Vector2 = leg.get("ground_toe", leg["toe"])
		lowest = maxf(lowest, toe.y)
	return (lowest - ORIGIN.y) * SCALE
