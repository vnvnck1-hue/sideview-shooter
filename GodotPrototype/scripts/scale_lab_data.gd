class_name ScaleLabData
extends RefCounted
## 규격 비교 테스트 씬(scenes/ScaleLab.tscn)의 그레이박스 데이터와 세로 판정 규칙.
## 계획: Docs/SCALE_STANDARDIZATION_PLAN.md §2 · 기준자: Docs/SCALE_CHARACTER_BASELINE.md · 씬 설명: Docs/SCALE_TEST_SCENE.md
##
## **여기 있는 치수는 전부 후보다.** 확정 규격이 아니다. 플레이해 보고 채택·보류를 문서에 남긴다.
##
## 좌표 — 월드 px, 바닥선 FLOOR(486), 위가 −y. 높이·여유는 **바닥에서 위로 잰 값**(양수)으로 적는다.
## 1 아트 px = 4 월드 px, 타일 1칸 = 128, 보조 격자 32.
##
## 그레이박스 종류 (색으로 구별 — ScaleLabView.COLORS)
##   ground    바닥에 선 충돌 지형 (턱·상자·발판). 이동과 탄을 막는다. 턱 오르기 한계 이하이면 걸어 오른다.
##   overhead  천장에서 내려온 충돌 지형 (문 인방·낮은 통로·층고). 판정 높이가 여유보다 크면 들어가지 못한다.
##   backdrop  통과 가능한 배경 프랍. 막지 않는다 (캐릭터 뒤).
##   interact  상호작용 프랍 자리 (단말기·스위치). 막지 않는다.
##   occluder  전경 가림막 (캐릭터 앞). 막지 않는다. 얼마나 가리는지 본다.
##   art       기존 아트 스프라이트 (ScaleLabView 가 실제 불투명 영역을 재서 치수를 붙인다)
##   ghost     비교용 실루엣 외곽선 · 거리 표시 (충돌 없음)

const ROOM_ID := "scale_lab"
const CELL := RoomTheme.CELL                # 128
const SUB := 32                              # 보조 격자
const FLOOR := float(RoomData.FLOOR_Y)       # 486
const ROWS := 9                              # 그레이박스 구간의 열 높이 (셀) — 본 맵 최대치
const THEME := "workshop"                    # 타일 연결부 구역에만 보인다

## 9행 방의 열린 천장 (RoomSolid 의 천장 띠 아랫선) = 584 − 128×9
const TOP := 584.0 - 128.0 * ROWS            # −568
const CEIL_TOP := 536.0 - 128.0 * ROWS       # −616 (타일 실루엣 윗선)

## 타일 방 열 높이(셀) → 바닥에서 천장 띠 아랫선까지의 여유. 128h − 98.
static func tile_clearance(cells: int) -> float:
	return 128.0 * cells - 98.0


## 행 수 r 짜리 방에서 카메라가 잡는 세로 중심 (RoomData.room_rect 가운데) = 536 − 64r
static func room_center_y(rows: int) -> float:
	return 536.0 - 64.0 * rows


## ── 캐릭터 기준자 (SCALE_CHARACTER_BASELINE.md 측정값) ─────────────────────────
const STAND_H := 267.0          # 서기·걷기 외형 최대
const STAND_MAX := 270.0        # 웅크리기 첫 프레임까지 포함한 최대 외형
const IDLE_MAX := 291.0         # 아이들 '통통' 스쿼시 상한 (계산값)
const CROUCH_H := 207.0         # 웅크리기 유지 프레임
const ROLL_LOW := 179.0         # 구르기 가장 낮은 순간
const ROLL_EDGE := 263.0        # 구르기 시작·끝 프레임
const BODY_W := 168.0           # 서기 몸통+머리 폭
const HIT_W := 124.0            # 독액 피격 상자 폭
const HIT_H := 250.0            # 독액 피격 상자 높이
const HALF_W := 62.0            # 지형 판정 반폭 — 피격 상자와 같은 124 폭을 몸으로 본다
const MUZZLE_STAND := 160.0     # 서서 수평 조준 총구 높이
const MUZZLE_CROUCH := 94.0     # 웅크려 수평 조준 총구 높이 (가장 낮을 때)
const NPC_MIN := 252.0
const NPC_MAX := 272.0
const WALK_1S := 380.0
const RUN_1S := 620.0
const ROLL_DIST := 430.0
const ROLL_TOTAL := 523.0

## ── 세로 판정 규칙 후보 (G 로 순환) ────────────────────────────────────────────
## 본편에는 "통로가 낮아서 못 지나간다" 는 판정 자체가 없다(기준표 §3). 이 씬에서 방식을 정한다.
##   stand/crouch  서 있을 때 / 웅크렸을 때 몸 높이
##   roll          구르기 중 몸 높이
##   roll_edge     구르기 시작·끝 구간의 몸 높이 (roll_window 밖)
##   roll_window   구르기 진행률 중 roll 높이를 쓰는 구간
const RULES := [
	{"id": "art", "name": "외형 기준", "stand": STAND_MAX, "crouch": CROUCH_H, "roll": ROLL_LOW,
		"roll_edge": ROLL_LOW, "roll_window": [0.0, 1.0],
		"desc": "그림이 실제로 차지하는 높이. 구르기는 전 구간 최저 높이"},
	{"id": "art_margin", "name": "외형 + 아이들 여유", "stand": IDLE_MAX, "crouch": CROUCH_H, "roll": ROLL_LOW,
		"roll_edge": ROLL_EDGE, "roll_window": [0.2, 0.8],
		"desc": "아이들 스쿼시 상한까지 여유. 구르기는 가운데 60%만 낮다 (시작·끝 프레임은 263)"},
	{"id": "hitbox", "name": "판정 상자 기준 (관대)", "stand": HIT_H, "crouch": 190.0, "roll": 150.0,
		"roll_edge": 150.0, "roll_window": [0.0, 1.0],
		"desc": "그림보다 작은 판정. 머리카락·후드가 인방에 살짝 겹쳐도 지나간다"},
]
const RULE_DEFAULT := 0

## 턱 오르기 한계 후보 (T 로 순환). 0 = 점프·계단이 없는 현재 규칙 — 모든 턱이 벽이다.
const STEP_RULES := [0.0, 32.0, 64.0, 96.0]
const STEP_DEFAULT := 1

## 구역 [이름, 요약, 카메라가 흉내 내는 방 행 수]
const ZONES := [
	{"id": "ruler", "name": "0 · 평지와 기준 눈금", "rows": 5,
		"desc": "캐릭터 비율 · 이동 거리 · 바닥 접점. 기둥 눈금 32 / 128"},
	{"id": "doors", "name": "1 · 문 높이", "rows": 5,
		"desc": "두께 64 벽에 뚫린 문. 개구부 높이 후보를 나란히"},
	{"id": "tunnels", "name": "2 · 낮은 통로", "rows": 5,
		"desc": "높이 × 길이. 구르기로 빠져나갈 수 있는 길이를 본다"},
	{"id": "steps", "name": "3 · 턱과 계단", "rows": 5,
		"desc": "턱 오르기 한계(T) 에 따라 통과·차단되는 높이"},
	{"id": "cover", "name": "4 · 상자와 엄폐물", "rows": 5,
		"desc": "총구 높이 160(서기) · 94(웅크림) 대비. [ ] 대신 , . 로 칸을 옮긴다"},
	{"id": "ceiling", "name": "5 · 벽과 층고", "rows": 0,
		"desc": "타일 방 4~9셀과 같은 층고. 카메라도 그 방처럼 잡힌다"},
	{"id": "props", "name": "6 · 배경 프랍과 가림", "rows": 5,
		"desc": "파랑 = 통과 배경 · 주황 = 상호작용 · 보라 = 전경 가림"},
	{"id": "art", "name": "7 · 기존 아트 대조", "rows": 5,
		"desc": "지금 게임에 들어 있는 문·가구 스프라이트의 실제 크기"},
	{"id": "tiles", "name": "8 · 타일 연결부", "rows": 0,
		"desc": "실제 workshop 타일. 바닥·벽·모서리 맞물림과 열 높이 단차"},
]

## 기존 아트 대조 구역에 세울 스프라이트 [경로, 이름, 배치] — 배치 "floor" 는 불투명 하단을 바닥에,
## "front" 는 정면문 규칙(상단 = 바닥 − Room.FRONT_DOOR_LIFT)
const ART := [
	[RoomData.SIDE_DOOR_OPEN_TEX, "측벽문 (열림 문틀)", "floor"],
	[RoomData.SIDE_DOOR_CLOSED_TEX, "측벽문 (닫힘)", "floor"],
	[RoomData.FRONT_DOOR_TEX, "정면문", "front"],
	["res://assets/props/workshop_locker_game_scale.png", "사물함", "floor"],
	["res://assets/props/workshop_workbench_game_scale.png", "작업대", "floor"],
	["res://assets/props/workshop_armchair_game_scale.png", "안락의자", "floor"],
	["res://assets/props/industrial_access_terminal_v1.png", "단말기 v1", "floor"],
	["res://assets/props/hydroponics_growth_tank_tall.png", "재배 탱크 (높음)", "floor"],
	["res://assets/props/crew_bunk_left.png", "2층 침대", "floor"],
]

## 타일 연결부 구역의 열 프로필 — 그레이박스(9행) 뒤에 이어 붙인다
const TILE_SEGS := [[4, 5], [3, 4], [4, 7], [2, 5], [3, 9], [4, 6]]


static var _items: Array = []
static var _zone_spans: Array = []
static var _greybox_cells := 0


## 방을 RoomData.extra 에 등록한다 (본 맵·지도·validate_map 은 건드리지 않는다)
static func register() -> String:
	_ensure()
	RoomData.register_extra(ROOM_ID, _room_dict())
	return ROOM_ID


static func items() -> Array:
	_ensure()
	return _items


## 구역별 [x0, x1]
static func zone_spans() -> Array:
	_ensure()
	return _zone_spans


static func zone_at(x: float) -> int:
	var sp := zone_spans()
	for i in range(sp.size()):
		if x < float(sp[i][1]):
			return i
	return sp.size() - 1


static func greybox_end() -> float:
	_ensure()
	return float(_greybox_cells * CELL)


static func total_width() -> float:
	_ensure()
	var w := _greybox_cells
	for s in TILE_SEGS:
		w += int(s[0])
	return float(w * CELL)


static func spawn_x() -> float:
	return 520.0


## 비교 후보 (, . 로 옮겨 다니는 대상) — stand_x 순
static func candidates() -> Array:
	var out: Array = []
	for it in items():
		if it.has("stand_x"):
			out.append(it)
	out.sort_custom(func(a, b): return float(a["stand_x"]) < float(b["stand_x"]))
	return out


## x 에서 카메라가 흉내 낼 방 행 수
static func rows_at(x: float) -> int:
	var z: Dictionary = ZONES[zone_at(x)]
	if int(z["rows"]) > 0:
		return int(z["rows"])
	for it in items():
		if it.has("rows") and it["rect"].position.x <= x and x < it["rect"].end.x:
			return int(it["rows"])
	return 5


# ── 판정 ─────────────────────────────────────────────────────────────────────

## 규칙 r 에서 구르기 진행률 p 의 몸 높이
static func roll_height(rule: Dictionary, p: float) -> float:
	var win: Array = rule["roll_window"]
	return float(rule["roll"]) if p >= float(win[0]) and p <= float(win[1]) else float(rule["roll_edge"])


## 규칙 r 에서 구르기의 낮은 구간 동안 나아가는 거리 (Player 의 구르기 속도 프로파일 적분)
static func roll_low_distance(rule: Dictionary) -> float:
	var win: Array = rule["roll_window"]
	var d := 0.0
	var n := 300
	for i in range(n):
		var k := (float(i) + 0.5) / n
		if k >= float(win[0]) and k <= float(win[1]):
			d += Player._roll_speed(k) * Player.ROLL_TIME / n
	return d


## 한 번 구르기로 통째로 빠져나가는 통로 길이의 상한 = 낮은 구간 이동 거리 − 판정 폭.
## (시작 위치를 딱 맞췄을 때의 이론값. 실측 툴은 선 자리에서 출발하므로 한 번 더 구를 수 있다)
static func roll_one_pass_length(rule: Dictionary) -> float:
	return maxf(0.0, roll_low_distance(rule) - HALF_W * 2.0)


## 여유 c(바닥에서 천장 아랫면까지)인 곳을 지나가는 방법. → {"verdict", "color", "text"}
## verdict: stand(서서) · roll(웅크려 걷기 또는 구르기로만) · none(불가)
static func pass_verdict(c: float, length: float, rule: Dictionary) -> Dictionary:
	var stand := float(rule["stand"])
	var crouch := float(rule["crouch"])
	var roll := float(rule["roll"])
	if c >= stand:
		return {"verdict": "stand", "text": "서서 통과  여유 %+d" % int(c - stand)}
	if c >= crouch:
		# 2026-09-25 부터 웅크린 채 천천히 걸을 수 있다 (Player.CROUCH_SPEED) — 길이와 상관없이 빠져나간다
		return {"verdict": "roll", "text": "웅크려 걷기 · 구르기  여유 %+d" % int(c - crouch)}
	if c >= roll:
		# 낮은 구간만으로 몸 전체가 빠져나가지 못하면 안에서 끊긴다 → 웅크려 버티고 다시 구른다
		# 한 번 구르기의 낮은 구간 동안 몸(판정 폭)이 통째로 빠져나갈 수 있는 최대 통로 길이
		var one := roll_one_pass_length(rule)
		if length <= one:
			return {"verdict": "roll", "text": "구르기로만  · 한 번에 통과 (한계 길이 %d)" % int(one)}
		return {"verdict": "roll", "text": "구르기로만  · 이어 구르기 (한 번 한계 %d · 안에서 끼임)" % int(one)}
	return {"verdict": "none", "text": "통과 불가  (구르기 %d > %d)" % [int(roll), int(c)]}


static func step_verdict(h: float, step_max: float) -> Dictionary:
	if h <= step_max:
		return {"verdict": "stand", "text": "걸어 오름"}
	return {"verdict": "none", "text": "막힘 (한계 %d)" % int(step_max)}


static func cover_verdict(h: float) -> String:
	var s := "서서 수평 사격 %s · 웅크려 %s" % [
		"넘김" if MUZZLE_STAND > h else "막힘", "넘김" if MUZZLE_CROUCH > h else "막힘"]
	return "%s\n웅크린 몸 %d%% 가림 · 선 몸 %d%%" % [s, int(minf(h / CROUCH_H, 1.0) * 100.0), int(minf(h / STAND_H, 1.0) * 100.0)]


## 바닥 x 에서 발이 딛는 높이 (ground 상자 윗면. 없으면 0) — 발 폭 ±foot 안의 가장 높은 것
static func ground_at(x: float, foot := 20.0) -> float:
	var g := 0.0
	for it in items():
		if it["kind"] != "ground":
			continue
		var r: Rect2 = it["rect"]
		if x + foot > r.position.x and x - foot < r.end.x:
			g = maxf(g, FLOOR - r.position.y)
	return g


## 선분 from→to 가 그레이박스 충돌 지형에 처음 닿는 점 (없으면 to). 총구가 이미 안이면 그 상자는 무시.
static func clip_shot(from: Vector2, to: Vector2) -> Vector2:
	var best := 1.0
	var d := to - from
	for it in items():
		if it["kind"] != "ground" and it["kind"] != "overhead":
			continue
		var r: Rect2 = it["rect"]
		if r.has_point(from):
			continue
		var t := _seg_rect(from, d, r)
		if t >= 0.0 and t < best:
			best = t
	return from + d * best


## Liang–Barsky: 선분이 사각형에 들어가는 t (0..1), 없으면 −1
static func _seg_rect(p: Vector2, d: Vector2, r: Rect2) -> float:
	var t0 := 0.0
	var t1 := 1.0
	var pp := [-d.x, d.x, -d.y, d.y]
	var qq := [p.x - r.position.x, r.end.x - p.x, p.y - r.position.y, r.end.y - p.y]
	for i in range(4):
		if absf(pp[i]) < 0.000001:
			if qq[i] < 0.0:
				return -1.0
			continue
		var t: float = qq[i] / pp[i]
		if pp[i] < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return -1.0
	return t0


# ── 배치 ─────────────────────────────────────────────────────────────────────

static func _ensure() -> void:
	if not _items.is_empty():
		return
	var x := 0.0
	for zi in range(ZONES.size()):
		var x0 := x
		match ZONES[zi]["id"]:
			"ruler": x = _zone_ruler(zi, x)
			"doors": x = _zone_doors(zi, x)
			"tunnels": x = _zone_tunnels(zi, x)
			"steps": x = _zone_steps(zi, x)
			"cover": x = _zone_cover(zi, x)
			"ceiling": x = _zone_ceiling(zi, x)
			"props": x = _zone_props(zi, x)
			"art": x = _zone_art(zi, x)
			"tiles": x = _zone_tiles(zi, x)
		x = ceilf(x / CELL) * CELL
		_zone_spans.append([x0, x])


static func _add(zi: int, kind: String, rect: Rect2, label: String, extra := {}) -> Dictionary:
	var it := {"zone": zi, "kind": kind, "rect": rect, "label": label}
	it.merge(extra)
	_items.append(it)
	return it


## 바닥에 선 상자 [x, 폭, 높이]
static func _floor_rect(x: float, w: float, h: float) -> Rect2:
	return Rect2(x, FLOOR - h, w, h)


## 천장에서 내려와 바닥 위 여유 c 에서 끝나는 상자
static func _over_rect(x: float, w: float, c: float) -> Rect2:
	return Rect2(x, CEIL_TOP, w, FLOOR - c - CEIL_TOP)


static func _zone_ruler(zi: int, x: float) -> float:
	# 높이 기둥 (눈금은 View 가 그린다)
	_add(zi, "pole", Rect2(x + 250.0, FLOOR - 1024.0, 16.0, 1024.0), "높이 눈금")
	# 비교 실루엣 — 바닥 중심 x, 폭, 높이
	var gx := x + 820.0
	var ghosts := [
		["서기 외형", BODY_W, STAND_H],
		["아이들 상한", BODY_W, IDLE_MAX],
		["웅크리기", 192.0, CROUCH_H],
		["구르기 최저", 248.0, ROLL_LOW],
		["피격 상자", HIT_W, HIT_H],
		["NPC 범위", 140.0, NPC_MAX],
	]
	for g in ghosts:
		var w: float = g[1]
		_add(zi, "ghost", _floor_rect(gx - w * 0.5, w, g[2]), "%s\n%d × %d" % [g[0], int(w), int(g[2])])
		gx += 290.0
	# 이동 거리 띠 — 출발선에서
	var sx := gx + 120.0
	_add(zi, "start", Rect2(sx, FLOOR - 40.0, 4.0, 40.0), "출발선")
	for d in [[WALK_1S, "걷기 1초 380"], [ROLL_DIST, "구르기 430"], [ROLL_TOTAL, "구르기+미끄럼 523"], [RUN_1S, "달리기 1초 620"]]:
		_add(zi, "distance", Rect2(sx, FLOOR, float(d[0]), 1.0), str(d[1]))
	return sx + RUN_1S + 520.0


static func _zone_doors(zi: int, x: float) -> float:
	x += 512.0
	for c in [384.0, 352.0, 320.0, 288.0, 256.0, 224.0, 192.0]:
		_add(zi, "overhead", _over_rect(x, 64.0, c), "문 D%d" % int(c),
			{"clear": c, "length": 64.0, "stand_x": x - 240.0, "id": "D%d" % int(c)})
		x += 64.0 + 576.0
	return x


static func _zone_tunnels(zi: int, x: float) -> float:
	x += 512.0
	for t in [[256.0, 384.0], [224.0, 256.0], [224.0, 512.0], [224.0, 768.0], [192.0, 384.0], [160.0, 256.0]]:
		var c: float = t[0]
		var l: float = t[1]
		_add(zi, "overhead", _over_rect(x, l, c), "통로 T%d×%d" % [int(c), int(l)],
			{"clear": c, "length": l, "stand_x": x - 300.0, "id": "T%dx%d" % [int(c), int(l)]})
		x += l + 640.0
	return x


static func _zone_steps(zi: int, x: float) -> float:
	x += 512.0
	for h in [16.0, 32.0, 48.0, 64.0, 96.0, 128.0]:
		_add(zi, "ground", _floor_rect(x, 256.0, h), "턱 S%d" % int(h),
			{"step": h, "stand_x": x - 220.0, "id": "S%d" % int(h)})
		x += 256.0 + 448.0
	# 계단 — 단 높이 32 · 디딤 128 × 6단 → 층계참 192, 그 뒤 한 번에 내려선다 (내리막은 언제나 된다)
	var sx := x
	for i in range(6):
		var h := 32.0 * (i + 1)
		_add(zi, "ground", _floor_rect(x, 128.0, h), "" if i < 5 else "계단 32×128 · 6단",
			{"step": 32.0, "stair": true})
		x += 128.0
	_add(zi, "ground", _floor_rect(x, 384.0, 192.0), "층계참 192", {"step": 32.0, "stair": true})
	_items[-7]["stand_x"] = sx - 220.0
	_items[-7]["id"] = "STAIR32"
	x += 384.0
	# 단 64 계단 3단 → 192
	x += 320.0
	var sx2 := x
	for i in range(3):
		_add(zi, "ground", _floor_rect(x, 128.0, 64.0 * (i + 1)), "" if i < 2 else "계단 64×128 · 3단",
			{"step": 64.0, "stair": true})
		x += 128.0
	_items[-3]["stand_x"] = sx2 - 220.0
	_items[-3]["id"] = "STAIR64"
	_add(zi, "ground", _floor_rect(x, 256.0, 192.0), "", {"step": 64.0, "stair": true})
	return x + 256.0 + 448.0


static func _zone_cover(zi: int, x: float) -> float:
	x += 640.0
	for c in [[64.0, 128.0], [96.0, 128.0], [128.0, 128.0], [160.0, 128.0], [192.0, 192.0], [256.0, 192.0]]:
		var h: float = c[0]
		_add(zi, "ground", _floor_rect(x, c[1], h), "상자 C%d" % int(h),
			{"cover": h, "step": h, "stand_x": x - 190.0, "id": "C%d" % int(h)})
		x += float(c[1]) + 704.0
	return x


static func _zone_ceiling(zi: int, x: float) -> float:
	x += 384.0
	for cells in [4, 5, 6, 7, 8, 9]:
		var c := tile_clearance(cells)
		var w := 896.0
		if cells < ROWS:
			_add(zi, "overhead", _over_rect(x, w, c), "", {"clear": c, "length": w, "rows": cells})
		_add(zi, "room", Rect2(x, FLOOR - c, w, c), "층고 %d셀 방 · 여유 %d" % [cells, int(c)],
			{"rows": cells, "clear": c, "stand_x": x + w * 0.5 - 200.0, "id": "H%d" % cells})
		x += w
	return x + 384.0


static func _zone_props(zi: int, x: float) -> float:
	x += 512.0
	var list := [
		["backdrop", "사물함", 128.0, 256.0, 0.0],
		["backdrop", "작업대", 256.0, 112.0, 0.0],
		["backdrop", "의자", 96.0, 128.0, 0.0],
		["interact", "콘솔 단말기", 192.0, 176.0, 0.0],
		["interact", "벽 단말기", 128.0, 160.0, 140.0],
		["backdrop", "기둥", 128.0, 542.0, 0.0],
		["backdrop", "배관 설비", 384.0, 320.0, 0.0],
		["backdrop", "대형 탱크", 256.0, 448.0, 0.0],
		["occluder", "전경 기둥 96", 96.0, 542.0, 0.0],
		["occluder", "전경 기둥 192", 192.0, 542.0, 0.0],
		["occluder", "전경 설비 320", 320.0, 240.0, 0.0],
	]
	for p in list:
		var w: float = p[2]
		var h: float = p[3]
		var lift: float = p[4]
		var r := Rect2(x, FLOOR - lift - h, w, h)
		_add(zi, p[0], r, "%s\n%d × %d%s" % [p[1], int(w), int(h), "" if lift <= 0.0 else " · 바닥 +%d" % int(lift)],
			{"stand_x": x + w * 0.5 - 160.0, "id": str(p[1])})
		x += w + 224.0
	return x + 288.0


static func _zone_art(zi: int, x: float) -> float:
	x += 448.0
	for a in ART:
		# 폭은 View 가 텍스처를 읽어 정한다. 여기서는 자리만 넉넉히 (최대 폭 가정 448)
		var tex := load(a[0]) as Texture2D
		var w := 256.0 if tex == null else float(tex.get_width())
		_add(zi, "art", Rect2(x, FLOOR - 1.0, w, 1.0), str(a[1]), {"path": a[0], "place": a[2],
			"stand_x": x + w * 0.5 - 160.0, "id": str(a[1])})
		x += w + 192.0
	return x + 256.0


static func _zone_tiles(zi: int, x: float) -> float:
	# 그레이박스는 여기서 끝난다 — 이 뒤는 실제 타일 열
	_greybox_cells = int(ceilf(x / CELL))
	var tx := float(_greybox_cells * CELL)
	for s in TILE_SEGS:
		var w := float(s[0]) * CELL
		var c := tile_clearance(int(s[1]))
		_add(zi, "tilecol", Rect2(tx, FLOOR - c, w, c), "%d셀 · 여유 %d" % [int(s[1]), int(c)],
			{"rows": int(s[1]), "stand_x": tx + w * 0.5 - 160.0, "id": "타일 %d셀" % int(s[1])})
		tx += w
	return tx


static func _room_dict() -> Dictionary:
	var shape: Array = [[_greybox_cells, ROWS]]
	for s in TILE_SEGS:
		shape.append([int(s[0]), int(s[1])])
	return {
		"title": "규격 비교 테스트 (그레이박스)", "zone": "규격 정립", "theme": THEME,
		"shape": shape,
		"left_door": {"open": false}, "right_door": {"open": false},
		"front_doors": [], "props": [], "lamps": [], "fixtures": [], "fx": [],
		"monsters": [], "spawn": {"max": 0, "interval": [9999.0, 9999.0]},
	}
