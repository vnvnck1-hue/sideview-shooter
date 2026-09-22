class_name SpaceLabData
extends RefCounted
## 공간 테스트 씬(scenes/SpaceLab.tscn)의 방 데이터. **본 맵(RoomData.ROOMS)에는 넣지 않는다** —
## RoomData.extra 에 얹어서 지도·탐색 카운트·tools/validate_map.gd 를 건드리지 않는다.
##
## 무엇을 보려는 씬인가
##   1. **넓이** — 기본 배경 타일(workshop, 본 맵에서 가장 많이 쓰는 테마)로 만들 수 있는 가장 큰 공간.
##      천장 9셀(= y −616, 본 맵 최대치)을 가진 대공동 둘을 양 끝에 둔다.
##   2. **길이** — 좌우로 계속 걸을 수 있는 20,000px 짜리 한 줄. 본 맵에서 가장 긴 방(격납고 4,096px)의 다섯 배다.
##   3. **거대종이 들어가는가** — 크롤러를 5배로 키운 변종(Crawler.make_giant)은 폭 1040 · 높이 614px 라
##      본 맵의 방 대부분에 안 들어간다. 여기는 천장 9셀 대공동이 둘이라 제대로 걸어 다닐 수 있고,
##      계단 천장 격납고에서는 **높은 쪽에 갇히는** 모습이(Room._giant_spans) 그대로 보인다.
##      크기 기준자로도 쓴다 — 플레이어(320px)·일반종(123px) 옆에 세워 두면 공간의 크기가 읽힌다.
##   4. **트랜지션 없는 방 사이** — 큰 방과 큰 방을 낮은 연결 통로(4셀)로 잇고, 통로 양 끝에 측벽문 문틀을 세운다.
##      문을 지나면 페이드 없이 바로 다음 방의 천장·조명·소품이 들어온다.
##      **한 개의 Room 으로 만든 이유**: 방을 여러 개 이어 붙이면 몬스터·탄·벽 기하가 저마다 다른 좌표계를 보게 된다
##      (Crawler 는 room-local, 탄·탄피는 world). 지금 보려는 것은 "이어진 공간의 감각" 이므로
##      열 프로필 하나로 여러 방을 이어 붙인 실루엣을 만들어 좌표계를 하나로 둔다.
##
## 셀 높이 → 천장 y :  4 → 24(낮은 통로) · 5 → −104 · 7 → −360 · 8 → −488 · 9 → −616(본 맵 최대)

const ROOM_ID := "space_lab"
const CELL := RoomTheme.CELL              # 128
const THEME := "workshop"                 # 본 맵에서 가장 많이 쓰는 기본 배경 타일
const DOOR_TEX := RoomData.CONNECTOR_DIR + "sidewall_shutter_open_frame_game_scale.png"
const DOOR_H := 480.0                     # 측벽문 문틀 높이 (fy 로 세운다)
const DOOR_INSET := 210.0                 # 통로 양 끝에서 문틀 중심까지

## 구획 — [셀 폭, 셀 높이] 묶음.
##   kind "room"  방
##   kind "link"  낮은 연결 통로. 그냥 뚫려 있어 **처음부터 양옆 방이 같이 보인다.**
##   kind "gate"  낮은 연결 통로인데 **끝에 닫힌 문**이 있다. 열기 전에는 그 너머가 전혀 보이지 않고,
##                열면 페이드 없이 저쪽 구역이 이쪽과 한 화면에 이어진다 (SectionGate).
## 두 종류를 번갈아 둔 이유: "그냥 이어진 공간" 과 "문을 열어 이어지는 공간" 을 한 씬에서 비교하기 위해서다.
## 앞쪽 네 방(대공동·정비 홀·격납고)은 문 없이 열려 있어 거대종·넓이를 바로 볼 수 있고,
## 뒤쪽 두 방은 문 뒤에 있다.
const CHAMBERS := [
	{"kind": "room", "name": "서쪽 대공동", "segs": [[3, 5], [24, 9], [3, 5]]},
	{"kind": "link", "name": "연결 통로 1", "segs": [[8, 4]]},
	{"kind": "room", "name": "정비 홀", "segs": [[3, 5], [16, 8], [3, 5]]},
	{"kind": "link", "name": "연결 통로 2", "segs": [[6, 4]]},
	{"kind": "room", "name": "계단 천장 격납고", "segs": [[5, 9], [5, 8], [6, 7], [5, 6], [5, 5]]},
	{"kind": "gate", "name": "봉쇄 통로 A", "segs": [[8, 4]]},
	{"kind": "room", "name": "작업 구역", "segs": [[3, 5], [14, 7], [3, 5]]},
	{"kind": "gate", "name": "봉쇄 통로 B", "segs": [[8, 4]]},
	{"kind": "room", "name": "동쪽 대공동", "segs": [[3, 5], [26, 9], [3, 5]]},
]


## 구획별 [x0, x1] (px). CHAMBERS 와 같은 순서.
static func spans() -> Array:
	var out: Array = []
	var x := 0
	for ch in CHAMBERS:
		var w := 0
		for seg in ch["segs"]:
			w += int(seg[0]) * CELL
		out.append([float(x), float(x + w)])
		x += w
	return out


## 닫힌 문이 서는 x — 통로의 **끝쪽**이다. 통로에는 걸어 들어갈 수 있고 그 끝에서 막힌다.
static func gate_x(i: int) -> float:
	return spans()[i][1] - DOOR_INSET


static func is_gate(i: int) -> bool:
	return CHAMBERS[i]["kind"] == "gate"


## 닫힌 문 구획의 번호 목록
static func gate_indices() -> Array:
	var out: Array = []
	for i in range(CHAMBERS.size()):
		if is_gate(i):
			out.append(i)
	return out


## 문 i 를 열었을 때 드러나는 구역 [x0, x1] — 다음 문까지, 없으면 방 끝까지
static func gate_reveal(i: int) -> Array:
	var x0 := gate_x(i)
	for j in range(i + 1, CHAMBERS.size()):
		if is_gate(j):
			return [x0, gate_x(j)]
	return [x0, float(total_width())]


## 문 i 너머 첫 방의 이름 (안내 문구용)
static func next_room_name(i: int) -> String:
	for j in range(i + 1, CHAMBERS.size()):
		if CHAMBERS[j]["kind"] == "room":
			return str(CHAMBERS[j]["name"])
	return "다음 구역"


static func total_width() -> int:
	var sp := spans()
	return int(sp[sp.size() - 1][1])


## 방 하나를 만들어 RoomData.extra 에 등록한다. Main 계열 씬은 이 id 를 평소 방처럼 쓴다.
static func register() -> String:
	RoomData.register_extra(ROOM_ID, build())
	return ROOM_ID


static func build() -> Dictionary:
	var shape: Array = []
	for ch in CHAMBERS:
		for seg in ch["segs"]:
			shape.append([int(seg[0]), int(seg[1])])

	var sp := spans()
	var props: Array = []
	var lamps: Array = []
	var fixtures: Array = []
	var fx: Array = []
	var monsters: Array = []

	# ── 연결 통로: 양 끝에 측벽문 문틀 + 형광등 한 줄 ───────────────────────────────
	# 문틀은 벽걸이 스프라이트(fy)로 세운다. 부술 수 있는 프랍이 아니라 **건축물**이고,
	# 프랍 층(z2)에 있으므로 플레이어·몬스터가 그 앞을 지나간다 — 문을 통과하는 그림이 된다.
	for i in range(CHAMBERS.size()):
		if CHAMBERS[i]["kind"] == "room":
			continue
		var x0: float = sp[i][0]
		var x1: float = sp[i][1]
		# 문틀 스프라이트는 **오른쪽 문설주** 한 짝이다 (방 오른쪽 끝에 쓰라고 그린 그림).
		# 통로 왼쪽 입구 = 앞 방의 오른쪽 문설주라 그대로, 오른쪽 입구 = 다음 방의 왼쪽 문설주라 뒤집는다.
		props.append({"tex": DOOR_TEX, "x": x0 + DOOR_INSET, "fy": DOOR_H})
		props.append({"tex": DOOR_TEX, "x": x1 - DOOR_INSET, "fy": DOOR_H, "flip": true})
		fixtures.append({"file": "fluorescent_lamp", "x": (x0 + x1) * 0.5, "cy": 52, "radius": 280})
		fx.append({"type": "wire", "x": x0 + (x1 - x0) * 0.35, "cy": 44, "length": 170.0})

	# ── 방 다섯 개 — 각자 다른 성격을 준다 (조명 색·소품 밀도·몬스터 수) ──────────────
	_fill_west_hall(sp[0], props, lamps, fixtures, fx, monsters)
	_fill_assembly(sp[2], props, lamps, fixtures, fx, monsters)
	_fill_hangar(sp[4], props, lamps, fixtures, fx, monsters)
	_fill_workshop(sp[6], props, lamps, fixtures, fx, monsters)
	_fill_east_hall(sp[8], props, lamps, fixtures, fx, monsters)

	return {
		"title": "공간 테스트 — 이어진 대공간 (%d px)" % total_width(),
		"zone": RoomData.ZONE_WORKSHOP, "theme": THEME,
		"shape": shape,
		"left_door": {"open": false}, "right_door": {"open": false},
		"front_doors": [],
		"props": props,
		"lamps": lamps,
		"fixtures": fixtures,
		"fx": fx,
		"monsters": monsters,
		# 방이 20,000px 이라 방 전체에 흩뿌리면 밀도가 0 에 가까워진다 → band 로 플레이어 주변에서만.
		# 쉬지 않고 한 마리씩 새어 나오면 넓이를 볼 틈이 없고 프레임도 계속 깎인다 → **웨이브**로 묶는다.
		#   30초마다 4~7마리가 0.45초 간격으로 몰려나오고, 그 사이는 조용하다. 첫 웨이브는 12초 뒤.
		# max 는 Room.MONSTER_HARD_CAP(14) 아래로 둔다 — 거대종 한 마리가 일반종 여럿만큼 무겁다.
		# giant: 지속 스폰에 거대종이 섞이는 확률. 설 자리가 없는 구간이 뽑히면 일반종으로 되돌아간다.
		"spawn": {
			"max": 10, "interval": [1.6, 2.8], "band": 3000.0, "giant": 0.12,
			"wave": {"interval": 30.0, "size": [4, 7], "gap": 0.45, "first": 12.0},
		},
	}


# ── 방별 배치 ────────────────────────────────────────────────────────────────────
# 좌표는 전부 "구획 왼쪽 끝에서 얼마" 로 적는다. 구획 폭을 바꿔도 안쪽에 남는다.
#
# 거대종은 크롤러에 **더한 게 아니라 한 마리와 바꿨다.** 시작 마리 수가 스폰 상한
# (Room.spawn_cap → MONSTER_HARD_CAP)을 넘으면 몇 마리 죽을 때까지 지속 스폰이 아예 멈춘다 —
# 이 씬에서 보려는 것은 "계속 나오는 공간" 이라 그 순간 씬의 목적이 깨진다. 시작 10마리를 유지한다.

static func _fill_west_hall(span: Array, props: Array, lamps: Array, fixtures: Array, fx: Array, monsters: Array) -> void:
	var x: float = span[0]
	for d in [700, 1300, 1900, 2500, 3100]:
		lamps.append(x + d)
	fixtures.append({"file": "wall_lamp", "x": x + 200, "cy": 150, "radius": 190})
	fixtures.append({"file": "wall_lamp", "x": x + 3640, "cy": 150, "radius": 190})
	fixtures.append({"file": "ceiling_lamp", "x": x + 2200, "cy": 120, "radius": 300})
	props.append({"tex": "workshop_locker_game_scale", "x": x + 300})
	props.append({"tex": "workshop_workbench_game_scale", "x": x + 980})
	props.append({"type": "walker", "id": "space_walker_west", "name": "서쪽 대공동 보행 기체", "x": x + 1600})
	props.append({"type": "capacitor", "x": x + 2200})
	props.append({"type": "sentry", "id": "space_sentry_west", "name": "서쪽 대공동 방어포", "x": x + 2860})
	props.append({"tex": "workshop_armchair_game_scale", "x": x + 3460})
	fx.append({"type": "beacon", "x": x + 480, "cy": 96})
	fx.append({"type": "fire", "x": x + 760, "size": Vector2(190.0, 240.0)})
	fx.append({"type": "wire", "x": x + 1300, "cy": 48, "length": 560.0})
	fx.append({"type": "leak", "x": x + 2500, "cy": 170, "dir": Vector2(0.4, 1.0), "pressure": 1.0})
	fx.append({"type": "beacon", "x": x + 3400, "cy": 96})
	monsters.append({"type": "crawler", "x": x + 3000, "facing": -1})
	# 9셀 천장(1102px) 한가운데 — 거대종이 좌우로 넉넉히 걷고 내려찍기까지 다 되는 자리
	monsters.append({"type": "giant", "x": x + 1500, "facing": -1})


static func _fill_assembly(span: Array, props: Array, lamps: Array, fixtures: Array, fx: Array, monsters: Array) -> void:
	var x: float = span[0]
	for d in [640, 1200, 1760, 2320]:
		lamps.append(x + d)
	fixtures.append({"file": "wall_lamp", "x": x + 180, "cy": 150, "radius": 190})
	fixtures.append({"file": "dangling_lamp", "x": x + 1480, "cy": 210, "radius": 260})
	fixtures.append({"file": "wall_lamp", "x": x + 2640, "cy": 150, "radius": 190})
	props.append({"type": "cabinet", "x": x + 420})
	props.append({"tex": "workshop_workbench_game_scale", "x": x + 1000})
	props.append({"tex": "workshop_locker_game_scale", "x": x + 1500})
	props.append({"type": "cart", "x": x + 2000})
	props.append({"tex": "workshop_armchair_game_scale", "x": x + 2500})
	props.append({"type": "breaker", "x": x + 2760, "fy": 340})
	fx.append({"type": "power_cable", "x": x + 860, "cy": 46, "length": 300.0})
	fx.append({"type": "beacon", "x": x + 1780, "cy": 88})
	fx.append({"type": "leak", "x": x + 2200, "cy": 150, "dir": Vector2(-0.35, 1.0), "pressure": 0.8})
	monsters.append({"type": "crawler", "x": x + 2300, "facing": -1})


static func _fill_hangar(span: Array, props: Array, lamps: Array, fixtures: Array, fx: Array, monsters: Array) -> void:
	# 천장이 9 → 5 로 계단처럼 내려간다. 계단마다 램프를 하나씩 걸어 단차를 읽히게 한다.
	var x: float = span[0]
	for d in [320, 960, 1600, 2240, 2880]:
		lamps.append(x + d)
	fixtures.append({"file": "indicator_beacon", "x": x + 640, "cy": 110, "radius": 170})
	fixtures.append({"file": "floor_work_light", "x": x + 1900, "fy": 70, "radius": 240})
	props.append({"type": "sentry", "id": "space_sentry_hangar", "name": "격납고 방어포", "x": x + 700})
	props.append({"type": "capacitor", "x": x + 1340})
	props.append({"tex": "workshop_locker_game_scale", "x": x + 2400})
	props.append({"type": "cart", "x": x + 2900})
	fx.append({"type": "wire", "x": x + 1000, "cy": 48, "length": 620.0})
	fx.append({"type": "fire", "x": x + 2050, "size": Vector2(170.0, 210.0)})
	fx.append({"type": "beacon", "x": x + 2600, "cy": 80})
	# 고인 물 — 방 하나에 하나만 둘 수 있다. 계단 천장 아래 낮은 쪽에 깔아 반사를 본다.
	fx.append({"type": "water", "level": 26.0, "x0": x + 2150, "x1": x + 3200})
	monsters.append({"type": "crawler", "x": x + 2700, "facing": -1})
	# 계단 천장의 높은 쪽(왼쪽)에만 설 수 있다 — 오른쪽 낮은 칸으로는 넘어오지 못한다.
	# 거대종을 가두는 Room._giant_spans 가 실제로 어떻게 잘리는지 보는 자리다.
	monsters.append({"type": "giant", "x": x + 700, "facing": 1})


static func _fill_workshop(span: Array, props: Array, lamps: Array, fixtures: Array, fx: Array, monsters: Array) -> void:
	var x: float = span[0]
	for d in [560, 1120, 1680, 2140]:
		lamps.append(x + d)
	fixtures.append({"file": "wall_lamp", "x": x + 170, "cy": 150, "radius": 190})
	fixtures.append({"file": "wall_lamp", "x": x + 2390, "cy": 150, "radius": 190})
	props.append({"tex": "workshop_locker_game_scale", "x": x + 300})
	props.append({"tex": "workshop_workbench_game_scale", "x": x + 820})
	props.append({"type": "walker", "id": "space_walker_mid", "name": "작업 구역 보행 기체", "x": x + 1400})
	props.append({"tex": "workshop_armchair_game_scale", "x": x + 2000})
	props.append({"type": "cabinet", "x": x + 2300})
	fx.append({"type": "beacon", "x": x + 640, "cy": 92})
	fx.append({"type": "wire", "x": x + 1760, "cy": 46, "length": 340.0})
	fx.append({"type": "leak", "x": x + 1120, "cy": 150, "dir": Vector2(0.3, 1.0), "pressure": 0.7})
	monsters.append({"type": "crawler", "x": x + 1800, "facing": -1})
	# 7셀 천장(846px) — 걷기·포효는 들어가지만 내려찍기 자세(900px)는 안 들어간다.
	# 이 자리의 거대종은 산탄만 쓴다 (Crawler._slam_headroom).
	monsters.append({"type": "giant", "x": x + 1200, "facing": -1})


static func _fill_east_hall(span: Array, props: Array, lamps: Array, fixtures: Array, fx: Array, monsters: Array) -> void:
	var x: float = span[0]
	for d in [700, 1300, 1900, 2500, 3100, 3700]:
		lamps.append(x + d)
	fixtures.append({"file": "wall_lamp", "x": x + 200, "cy": 150, "radius": 190})
	fixtures.append({"file": "ceiling_lamp", "x": x + 2000, "cy": 120, "radius": 300})
	fixtures.append({"file": "dangling_lamp", "x": x + 3000, "cy": 230, "radius": 260})
	fixtures.append({"file": "wall_lamp", "x": x + 3900, "cy": 150, "radius": 190})
	props.append({"type": "cart", "x": x + 340})
	props.append({"tex": "workshop_workbench_game_scale", "x": x + 900})
	props.append({"type": "sentry", "id": "space_sentry_east", "name": "동쪽 대공동 방어포", "x": x + 1560})
	props.append({"type": "capacitor", "x": x + 2200})
	props.append({"type": "walker", "id": "space_walker_east", "name": "동쪽 대공동 보행 기체", "x": x + 2800})
	props.append({"tex": "workshop_locker_game_scale", "x": x + 3400})
	props.append({"tex": "workshop_armchair_game_scale", "x": x + 3900})
	fx.append({"type": "beacon", "x": x + 520, "cy": 96})
	fx.append({"type": "wire", "x": x + 1200, "cy": 48, "length": 600.0})
	fx.append({"type": "fire", "x": x + 2450, "size": Vector2(200.0, 250.0)})
	fx.append({"type": "leak", "x": x + 3200, "cy": 170, "dir": Vector2(-0.4, 1.0), "pressure": 1.0})
	fx.append({"type": "beacon", "x": x + 3720, "cy": 96})
	monsters.append({"type": "crawler", "x": x + 2600, "facing": -1})
	monsters.append({"type": "crawler", "x": x + 3600, "facing": -1})
	# 맵에서 가장 넓은 9셀 구간 — 거대종이 가장 멀리까지 걸어 다니는 자리
	monsters.append({"type": "giant", "x": x + 2000, "facing": -1})
