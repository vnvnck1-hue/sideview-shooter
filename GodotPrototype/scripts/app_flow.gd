class_name AppFlow
extends RefCounted
## 씬 간 흐름: 로비 → 메인 게임(에어록에서 시작, 전체 맵) / 테스트(저수조실에서 시작) / 맵 뷰어.

const LOBBY_SCENE := "res://scenes/Lobby.tscn"
const MAIN_GAME_SCENE := "res://scenes/MainGame.tscn"
const TEST_SCENE := "res://scenes/Main.tscn"
const MAP_VIEWER_SCENE := "res://scenes/MapViewer.tscn"
const DIALOGUE_LAB_SCENE := "res://scenes/DialogueLab.tscn"
const SHADOW_LAB_SCENE := "res://scenes/ShadowLab.tscn"

## 디자인 캔버스 = 창 기본 크기 = 스트레치 기준 (project.godot display/window/size 와 반드시 같은 값).
## HUD·CRT 오버레이·말풍선 등 창 좌표를 쓰는 모든 곳이 여기를 본다.
## 2026-09-19: 1600×900 → 2240×900. 세로는 그대로 두고 가로만 넓혔다 — 방(최대 4096 월드 px)이 화면보다 넓어
## 좌우가 잘렸는데, 창을 키워도 스트레치 기준이 1600 이라 보이는 범위가 늘지 않았다. 세로까지 같이 넓히면
## 방(높이 512~1152)이 검은 여백에 떠서 오히려 작아 보인다.
## scale_mode 는 integer 로 둔다 — 픽셀 규칙(아트 1px = 화면 정수 px)이 창 배율에서도 깨지지 않게.
## 대신 2240×900 보다 작은 창/모니터에서는 배율이 1 로 묶여 화면이 잘린다. 그때는 이 값을 낮춰야 한다.
const VIEW_SIZE := Vector2i(2240, 900)

## Main 이 처음 로드할 방 id (RoomData.ROOMS 키)
static var start_room := RoomData.START_ROOM
## 지정 위치에서 시작할 때 쓰는 상태 (로비의 "센트리건 테스트" 등). resume_x < 0 이면 무시.
static var resume_x := -1.0
static var resume_facing := 1
## 근경 랩 모드: Main 이 플레이어 입력·몬스터를 끄고 ForegroundLab(근경 편집 오버레이)을 올린다
static var lab_mode := false
## 앰비언스 랩 모드: Main 이 AmbienceLab 패널을 올린다. 근경 랩과 달리 플레이어는 그대로 움직인다 —
## 소리는 걸어 다니며 판단하는 것이라 방을 넘나드는 순간을 들어야 한다.
static var amb_lab := false
## 플레이어가 한 번이라도 들어간 방 (방 id → true). 단말기 지도(StationMap)의 안개를 걷는 근거다.
## 원격 조종으로 월드가 교체된 방도 포함한다 — 화면 너머로 봤어도 본 것은 본 것이다.
## static 이라 씬을 다시 로드해도 남고, 새 게임(start_main_game·start_test)에서만 비운다.
static var visited := {}


static func visit(room_id: String) -> void:
	visited[room_id] = true


static func go_lobby(tree: SceneTree) -> void:
	lab_mode = false
	amb_lab = false
	tree.change_scene_to_file(LOBBY_SCENE)


## 메인 게임: 에어록(RoomData.START_ROOM)에서 시작, 전체 맵을 탐색한다
static func start_main_game(tree: SceneTree) -> void:
	lab_mode = false
	amb_lab = false
	visited = {}
	start_room = RoomData.START_ROOM
	tree.change_scene_to_file(MAIN_GAME_SCENE)


## 테스트: 기본은 물이 고인 저수조실(RoomData.TEST_ROOM). room 을 주면 그 방에서 바로 시작하고,
## spawn_x >= 0 이면 그 위치에 선다 (센트리건 옆처럼 특정 연출 바로 앞에서 시작 — 로비 버튼이 쓴다).
static func start_test(tree: SceneTree, room := "", spawn_x := -1.0, facing := 1) -> void:
	lab_mode = false
	amb_lab = false
	visited = {}
	if RoomData.ROOMS.has(room):
		start_room = room
		resume_x = spawn_x
		resume_facing = facing
		tree.change_scene_to_file(TEST_SCENE)
		return
	start_room = RoomData.TEST_ROOM if RoomData.ROOMS.has(RoomData.TEST_ROOM) else RoomData.random_id()
	tree.change_scene_to_file(TEST_SCENE)


## 근경 랩: 실제 방·조명 위에서 근경 실루엣을 마우스로 배치하고 foreground/<방 id>.json 에 저장한다 ([ ] 로 방 전환)
static func start_foreground_lab(tree: SceneTree, room := "") -> void:
	lab_mode = true
	amb_lab = false
	start_room = room if RoomData.ROOMS.has(room) else RoomData.START_ROOM
	resume_x = -1.0
	tree.change_scene_to_file(TEST_SCENE)


## 앰비언스 랩: 에어록에서 시작해 실제로 걸어 다니며 방별 앰비언스를 듣고 수치를 고쳐 저장한다.
## 저장 파일(ambience/tuning.json)은 AudioManager 가 시작할 때 읽으므로 본편에도 그대로 적용된다.
static func start_ambience_lab(tree: SceneTree, room := "") -> void:
	lab_mode = false
	amb_lab = true
	visited = {}
	start_room = room if RoomData.ROOMS.has(room) else RoomData.START_ROOM
	resume_x = -1.0
	tree.change_scene_to_file(MAIN_GAME_SCENE)


## 대화 UI 랩: 실제 방·인물 위에서 대사 표시 방식 다섯 가지를 1~5 로 바꿔 가며 비교한다 (Docs/DIALOGUE_SYSTEM.md §3)
static func start_dialogue_lab(tree: SceneTree) -> void:
	lab_mode = false
	start_room = "airlock"                       # 첫 상대(에어록 관리인)가 있는 방 — 랩이 [ ] 로 옮겨 다닌다
	resume_x = -1.0
	tree.change_scene_to_file(DIALOGUE_LAB_SCENE)


## 조명·그림자 랩: 그레이박스 위에서 **마우스가 광원**이 되어 그림자 기하를 눈으로 맞춘다 (scripts/shadow_lab.gd)
static func start_shadow_lab(tree: SceneTree) -> void:
	lab_mode = false
	amb_lab = false
	tree.change_scene_to_file(SHADOW_LAB_SCENE)


## 맵 뷰어: 방을 게임 없이 조립해 자유 카메라로 본다 ([ ] 로 방 전환)
static func start_map_viewer(tree: SceneTree, room := "") -> void:
	start_room = room if RoomData.ROOMS.has(room) else RoomData.START_ROOM
	tree.change_scene_to_file(MAP_VIEWER_SCENE)
