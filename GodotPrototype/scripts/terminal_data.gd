class_name TerminalData
extends RefCounted
## 단말기 정의 — 역할 표 · 단말기별 내용(로그 · 배전 회로 · 관할 구역).
## 컨셉과 배치 근거는 Docs/TERMINAL_SYSTEM_CONCEPT.md.
##
## **배치**는 여기가 아니라 RoomData.ROOMS[*].props 가 단일 출처다:
##   {"type": "terminal", "id": "sec_workshop"}  ·  {"type": "sentry", "id": "sentry_workshop"}
## 여기서는 그 id 에 **무엇이 들어 있는지**(역할 · 이름 · 로그 · 관할)만 정한다.
## 그래서 방 배치를 바꿔도 이 파일은 손대지 않고, 내용을 바꿔도 맵 파일은 손대지 않는다.
##
## 역할 5종 — 단말기는 만능 기계가 아니라 **역할이 다른 다섯 종류의 기계**다.
##   link     세바스토링크 단말기   기록 열람 (음성 로그 · 메일)
##   security 보안 관제 단말기      방어 그리드 — 관할 구역의 센트리건 원격 접속 ★
##   rewire   리와이어 배전반       제한 전력 재분배 (벽걸이)
##   save     비상 저장 단말기      출입 카드를 꽂아 저장
##   survey   구역 현황 단말기      구역 지도 · 센서 판독 (낮은 바닥 콘솔)

const PROP_DIR := "res://assets/props/"

## 역할 표.
##   tex          월드에 서 있는 단말기 프랍 자산
##   wall         true 면 벽걸이 (바닥이 아니라 fy 높이에 붙는다)
##   screen       화면 발광 색 (PointLight2D) — 멀리서 역할을 알아보는 단서
##   screen_local 발광 지점 (프랍 원점 = 바닥 중심 기준. 벽걸이는 프랍 중심 기준)
##   crt          접속했을 때 밀어 넣을 CRT 프리셋 id (CrtPreset.PRESETS)
##   accent       UI 강조색
const ROLES := {
	"link": {
		"name": "세바스토링크 단말기", "short": "SevASTOLink",
		"tex": PROP_DIR + "industrial_access_terminal_v4.png", "wall": false,
		"screen": Color(0.18, 0.92, 0.96), "screen_local": Vector2(-10, -318), "screen_radius": 210.0,
		"crt": "green", "accent": Color(0.55, 1.0, 0.68),
		"boot": "SEVASTOLINK  //  개인 통신 · 기록 열람",
	},
	"security": {
		"name": "보안 관제 단말기", "short": "SecOps",
		"tex": PROP_DIR + "industrial_access_terminal_v1.png", "wall": false,
		"screen": Color(1.0, 0.72, 0.28), "screen_local": Vector2(0, -360), "screen_radius": 260.0,
		"crt": "green", "accent": Color(0.55, 1.0, 0.68),
		"boot": "SECOPS  //  구역 방어 그리드 관제",
	},
	"rewire": {
		"name": "리와이어 배전반", "short": "Rewire",
		"tex": PROP_DIR + "terminal_wall_access_v1.png", "wall": true,
		"screen": Color(1.0, 0.44, 0.30), "screen_local": Vector2(0, -20), "screen_radius": 170.0,
		"crt": "amber", "accent": Color(1.0, 0.76, 0.34),
		"boot": "REWIRE  //  제한 전력 재분배",
	},
	"save": {
		"name": "비상 저장 단말기", "short": "SaveStation",
		"tex": PROP_DIR + "industrial_access_terminal_v3.png", "wall": false,
		"screen": Color(0.78, 0.9, 1.0), "screen_local": Vector2(0, -322), "screen_radius": 200.0,
		"crt": "amber", "accent": Color(1.0, 0.76, 0.34),
		"boot": "EMERGENCY SAVE STATION  //  출입 카드 대기",
	},
	"survey": {
		"name": "구역 현황 단말기", "short": "Survey",
		"tex": PROP_DIR + "terminal_floor_console_v1.png", "wall": false,
		"screen": Color(0.42, 1.0, 0.52), "screen_local": Vector2(0, -180), "screen_radius": 190.0,
		"crt": "green", "accent": Color(0.55, 1.0, 0.68),
		"boot": "SURVEY  //  구역 센서 판독",
	},
}

## 배전 회로 — rewire 단말기가 공유한다. 총 전력 POWER_BUDGET 유닛을 나눠 켠다.
const POWER_BUDGET := 3
const CIRCUITS := [
	{"id": "purifier", "name": "공기 정화 장치", "cost": 1, "note": "구역 오염도가 천천히 내려간다"},
	{"id": "lighting", "name": "구역 조명", "cost": 1, "note": "꺼 두면 어두워지지만 눈에 덜 띈다"},
	{"id": "cameras", "name": "감시 카메라 · 경보", "cost": 1, "note": "꺼 두면 경보가 울리지 않는다"},
	{"id": "doorlock", "name": "격벽 잠금 해제", "cost": 2, "note": "잠긴 정면문이 열린다"},
]

## 벽걸이 보안 패널 — 바닥에 480px 자리가 없는 좁은 방(복도·격납고 통로)의 보안 관제.
## 역할은 그대로 security 지만 자산과 설치 방식만 덮어쓴다.
const WALL_PANEL := {"tex": PROP_DIR + "terminal_wall_access_v1.png", "wall": true}

## 단말기 내용.
##   role      ROLES 의 키
##   title     화면 머리글에 뜨는 이름
##   callsign  호출부호 (구역-번호)
##   grid      관할 구역 이름(RoomData ZONE_*) 또는 방 id 목록. 역할에 따라 뜻이 다르다.
##             security — 원격으로 잡을 수 있는 포탑의 범위. 관할 밖 포탑은 지도에 뜨되 커서가 서지 않는다.
##             survey   — 지도에서 **실시간 판독**되는 범위. 관할 밖은 다녀온 방만 과거 기록으로 뜬다.
##   logs      link/survey 전용 — [{"from", "title", "body"}]
const TERMINALS := {
	# ── 정비 구역 ──────────────────────────────────────────────────────────
	"link_airlock": {
		"role": "link", "title": "에어록 통신 단말", "callsign": "SEV-A01",
		"tex": WALL_PANEL["tex"], "wall": true,
		"logs": [
			{"from": "정비반 K. 아마도리", "title": "재가압 절차 메모",
			 "body": "에어록 재가압은 3분이다. 그 3분 동안 문 두 짝이 다 잠긴다.\n밖에서 뭔가 두드려도 열 방법이 없다는 뜻이다.\n\n…어제 그걸 알았다."},
			{"from": "자동 발신", "title": "수신: 전 승무원 / 격리 3일차",
			 "body": "정비 구역 서쪽 통로에 화재. 진압 설비가 응답하지 않는다.\n해당 구역을 통과할 때는 방어포 그리드를 먼저 확인할 것.\n\n관제 권한은 각 구역 보안 단말기에 분산되어 있다."},
		],
	},
	"save_corr_west": {
		"role": "save", "title": "서쪽 통로 저장 지점", "callsign": "SAV-W2",
	},
	"sec_workshop": {
		"role": "security", "title": "정비 구역 방어 관제", "callsign": "SEC-W1",
		"grid": [RoomData.ZONE_WORKSHOP],
	},
	"save_corr_mid": {
		"role": "save", "title": "짧은 통로 저장 지점", "callsign": "SAV-M2",
	},
	"sec_hangar": {
		"role": "security", "title": "격납고 방어 관제", "callsign": "SEC-H3",
		"grid": [RoomData.ZONE_WORKSHOP, RoomData.ZONE_HYDRO],
		"tex": WALL_PANEL["tex"], "wall": true,
	},
	"survey_storage": {
		# 창고는 정면문으로 재배실 전실과 붙어 있다 — 그래서 수경재배 구역까지 센서가 닿는다.
		"role": "survey", "title": "창고 센서 판독", "callsign": "SRV-S4",
		"grid": [RoomData.ZONE_WORKSHOP, RoomData.ZONE_HYDRO],
		"tex": WALL_PANEL["tex"], "wall": true,
		"logs": [
			{"from": "센서 로그", "title": "창고 재고 대조 실패",
			 "body": "등록 품목 1,284 / 실측 1,109.\n차이 175. 대부분 의료품과 조명탄.\n\n누군가 가져갔다면, 아직 이 스테이션 안에 있다."},
		],
	},

	# ── 전력 구역 ──────────────────────────────────────────────────────────
	"survey_cable": {
		# 전력 간선을 타고 승무원 구역까지 읽는다. 창고 단말과 합치면 네 구역이 모두 덮인다.
		"role": "survey", "title": "케이블 덕트 센서 판독", "callsign": "SRV-P3",
		"grid": [RoomData.ZONE_POWER, RoomData.ZONE_CREW],
		"logs": [
			{"from": "센서 로그", "title": "간선 부하 이상",
			 "body": "덕트 3계통 부하가 정격의 0.4배로 떨어졌다.\n끊긴 것이 아니라 **어딘가로 새고 있다.**\n\n분기점 목록에 등록되지 않은 부하가 하나 잡힌다. 위치 추적 실패."},
		],
	},
	"rewire_relay": {
		"role": "rewire", "title": "릴레이실 배전반", "callsign": "RWR-P1",
	},

	# ── 승무원 구역 ────────────────────────────────────────────────────────
	"sec_quarters": {
		"role": "security", "title": "승무원·전력 방어 관제", "callsign": "SEC-C2",
		"grid": [RoomData.ZONE_CREW, RoomData.ZONE_POWER],
		"tex": WALL_PANEL["tex"], "wall": true,
	},
	"link_bunk_b": {
		"role": "link", "title": "침실 B 통신 단말", "callsign": "SEV-C1",
		"tex": WALL_PANEL["tex"], "wall": true,
		"logs": [
			{"from": "M. 리드", "title": "음성 로그 07",
			 "body": "방어포를 복도 쪽으로 돌려 놨다.\n관제는 복도 끝 패널에서 잡힌다. 내 방에서는 안 잡힌다.\n\n그러니까 문제가 생기면 복도까지 나가야 한다는 거다.\n…설계한 놈을 만나면 한 대 치겠다."},
			{"from": "M. 리드", "title": "음성 로그 08",
			 "body": "포탑은 사람도 쏜다. 켜 두고 자면 안 된다.\n\n그런데 꺼 두고 자는 것도 이제는 못 하겠다."},
		],
	},

	# ── 수경재배 구역 ──────────────────────────────────────────────────────
	"sec_pump": {
		"role": "security", "title": "수경재배 방어 관제", "callsign": "SEC-H2",
		"grid": [RoomData.ZONE_HYDRO, RoomData.ZONE_POWER],
		"tex": WALL_PANEL["tex"], "wall": true,
	},
	"link_tank": {
		"role": "link", "title": "저수조실 통신 단말", "callsign": "SEV-H5",
		"tex": WALL_PANEL["tex"], "wall": true,
		"logs": [
			{"from": "센서 로그", "title": "저수조 수위 이상",
			 "body": "수위 +410mm. 배수 밸브는 정상 응답.\n유입원 불명.\n\n수질 검사에서 단백질이 검출되었다. 재검 요망."},
			{"from": "수경반 T. 오카다", "title": "음성 로그 02",
			 "body": "재배실 방어포가 밤새 혼자 돌아갔다.\n아침에 보니 탄은 하나도 안 줄었다.\n\n뭔가를 계속 보고 있었다는 뜻이다."},
		],
	},
	"rewire_nursery": {
		"role": "rewire", "title": "육묘실 배전반", "callsign": "RWR-H1",
	},

	# ── 연구 구역 ──────────────────────────────────────────────────────────
	"save_decon": {
		"role": "save", "title": "멸균 전실 저장 지점", "callsign": "SAV-R1",
	},
	"link_isolation": {
		"role": "link", "title": "격리 병동 통신 단말", "callsign": "SEV-R2",
		"tex": WALL_PANEL["tex"], "wall": true,
		"logs": [
			{"from": "검역반", "title": "수신: 연구동 / 격리 1일차",
			 "body": "연구동 전체를 검역 등급 4로 올린다.\n정면 격벽 두 짝만 남기고 전부 봉쇄.\n\n안에 남은 인원은 멸균 전실을 거쳐서만 나온다. 예외 없음."},
			{"from": "간호 기록", "title": "격리 병상 3 / 경과",
			 "body": "체온 정상. 혈압 정상. 반응 정상.\n\n그런데 본인이 계속 \"안에서 뭔가 자란다\" 고 말한다.\n영상에는 아무것도 잡히지 않는다. 재검 요망."},
		],
	},
	"survey_research": {
		# 연구 통로 한가운데. 봉쇄된 연구동 안을 읽는 유일한 눈이다.
		"role": "survey", "title": "연구 통로 센서 판독", "callsign": "SRV-R3",
		"grid": [RoomData.ZONE_RESEARCH],
		"logs": [
			{"from": "센서 로그", "title": "검역 격벽 상태",
			 "body": "연구동 격벽 6짝 중 4짝이 잠금. 남은 둘은 정비 통로·급수 통로 쪽.\n\n잠금 명령은 연구동 안에서 내려졌다. 밖에서 가둔 것이 아니라,\n안에서 잠근 것이다."},
		],
	},
	"link_analysis": {
		"role": "link", "title": "분석실 통신 단말", "callsign": "SEV-R4",
		"tex": WALL_PANEL["tex"], "wall": true,
		"logs": [
			{"from": "선임 연구원 델", "title": "음성 로그 11",
			 "body": "저온고 검체 번호가 하나 비었다.\n반출 기록도, 폐기 기록도 없다.\n\n누가 꺼냈는지는 알 것 같다. 왜 꺼냈는지는 모르겠다."},
			{"from": "자동 기록", "title": "회수 우선순위 목록",
			 "body": "1. 저온고 검체 A-7\n2. 분석 기록 원본\n3. 연구동 잔류 인원\n\n…순서를 바꿔 달라고 세 번 요청했다. 세 번 다 반려."},
		],
	},
	"rewire_cold": {
		"role": "rewire", "title": "저온고 배전반", "callsign": "RWR-R5",
	},
	"sec_research": {
		# 연구동 안쪽 끝. 여기까지 와야 구역 방어포 셋이 모두 잡힌다.
		"role": "security", "title": "연구 구역 방어 관제", "callsign": "SEC-R6",
		"grid": [RoomData.ZONE_RESEARCH, RoomData.ZONE_HYDRO],
		"tex": WALL_PANEL["tex"], "wall": true,
	},
}


static func has(id: String) -> bool:
	return TERMINALS.has(id)


static func get_terminal(id: String) -> Dictionary:
	return TERMINALS.get(id, {})


## 벽걸이인가 — 역할의 기본값을 단말기 정의가 덮어쓸 수 있다 (좁은 방의 벽걸이 보안 패널 등).
## Room 의 배치와 AccessTerminal 의 그리기가 **같은 답**을 내야 하므로 판정은 여기 한 곳에만 둔다.
static func is_wall(id: String) -> bool:
	return bool(get_terminal(id).get("wall", role_of(id)["wall"]))


## 이 단말기가 실제로 쓰는 자산 (역할 기본값 + 단말기 정의의 덮어쓰기)
static func texture_of(id: String) -> String:
	return str(get_terminal(id).get("tex", role_of(id)["tex"]))


static func role_of(id: String) -> Dictionary:
	var t := get_terminal(id)
	return ROLES.get(t.get("role", "link"), ROLES["link"])


## 보안 단말기가 원격으로 잡을 수 있는 **기계 종류**. props 의 "type" → 화면에 붙일 꼬리표.
## 여기에 한 줄 더하면 방어 그리드에 그 기계가 저절로 올라온다 (Main 의 _switch_to_remote 도 같이 볼 것).
const MACHINE_KINDS := {"sentry": "포탑", "walker": "보행 기체"}


## 맵 전체의 **원격 조종 가능한 기계** 목록 — RoomData.ROOMS 의 props 를 훑어 모은다
## (배치는 맵 파일이 단일 출처). [{"id", "kind", "room", "x", "zone", "room_title", "name"}] · 구역 → 방 순서.
static func machines() -> Array:
	var out: Array = []
	for room_id in RoomData.ROOMS:
		var data: Dictionary = RoomData.ROOMS[room_id]
		for p in data.get("props", []):
			var kind := str(p.get("type", ""))
			if not MACHINE_KINDS.has(kind):
				continue
			var sid := str(p.get("id", ""))
			if sid == "":
				continue
			out.append({
				"id": sid, "kind": kind, "room": room_id, "x": float(p["x"]),
				"zone": str(data.get("zone", "")), "room_title": str(data.get("title", room_id)),
				"name": str(p.get("name", data.get("title", room_id))),
			})
	return out


## 센트리건만 (예전 이름 — 포탑만 세는 곳이 쓴다)
static func sentries() -> Array:
	return machines().filter(func(m): return m["kind"] == "sentry")


## 이 단말기의 관할 목록 (구역 이름 또는 방 id). security 는 접속 권한, survey 는 실시간 판독 범위.
static func grid_of(terminal_id: String) -> Array:
	return get_terminal(terminal_id).get("grid", [])


## 이 단말기가 실제로 잡을 수 있나 — grid 에 방 id 또는 그 방의 구역 이름이 들어 있으면 된다.
## (포탑이든 보행 기체든 같은 관할 규칙이다 — 구역을 쥐면 그 구역의 기계를 다 쥔다)
static func in_grid(terminal_id: String, sentry: Dictionary) -> bool:
	var grid := grid_of(terminal_id)
	return grid.has(sentry["room"]) or grid.has(sentry["zone"])


## 방어 그리드 목록 — 관할 안이 먼저, 관할 밖은 뒤에 "권한 없음" 으로.
## 각 항목에 "authorized"(잡을 수 있나) 와 "local"(단말기와 같은 방인가) 을 덧붙인다.
## 포탑과 보행 기체가 한 목록에 섞인다 — 플레이어에게는 "이 구역에서 내가 쓸 수 있는 기계" 하나의 개념이다.
static func grid_entries(terminal_id: String, terminal_room: String) -> Array:
	var authorized: Array = []
	var locked: Array = []
	for s in machines():
		var e: Dictionary = s.duplicate()
		e["authorized"] = in_grid(terminal_id, s)
		e["local"] = s["room"] == terminal_room
		if e["authorized"]:
			authorized.append(e)
		else:
			locked.append(e)
	return authorized + locked
