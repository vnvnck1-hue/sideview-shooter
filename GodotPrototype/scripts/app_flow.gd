class_name AppFlow
extends RefCounted
## 씬 간 흐름: 로비 → 메인 게임(에어록에서 시작, 전체 맵) / 테스트(저수조실에서 시작) / 맵 뷰어.

const LOBBY_SCENE := "res://scenes/Lobby.tscn"
const MAIN_GAME_SCENE := "res://scenes/MainGame.tscn"
const TEST_SCENE := "res://scenes/Main.tscn"
const MAP_VIEWER_SCENE := "res://scenes/MapViewer.tscn"

## Main 이 처음 로드할 방 id (RoomData.ROOMS 키)
static var start_room := RoomData.START_ROOM
## 프리셋 전환(씬 재로드) 뒤 이어서 시작할 상태. resume_x < 0 이면 무시.
static var resume_x := -1.0
static var resume_facing := 1
static var resume_camera_preset := -1
## 근경 랩 모드: Main 이 플레이어 입력·몬스터를 끄고 ForegroundLab(근경 편집 오버레이)을 올린다
static var lab_mode := false


## 같은 방·플레이어 위치·카메라 프리셋으로 현재 씬을 다시 로드한다 (공간감 프리셋 A/B 전환용 — 방을 새로 조립해야 층 구성이 바뀐다)
static func reload_in_place(tree: SceneTree, room: String, x: float, facing: int, camera_preset: int) -> void:
	start_room = room
	resume_x = x
	resume_facing = facing
	resume_camera_preset = camera_preset
	tree.reload_current_scene()


static func go_lobby(tree: SceneTree) -> void:
	lab_mode = false
	tree.change_scene_to_file(LOBBY_SCENE)


## 메인 게임: 에어록(RoomData.START_ROOM)에서 시작, 전체 맵을 탐색한다
static func start_main_game(tree: SceneTree) -> void:
	lab_mode = false
	start_room = RoomData.START_ROOM
	tree.change_scene_to_file(MAIN_GAME_SCENE)


## 테스트: 물이 고인 저수조실(RoomData.TEST_ROOM)에서 바로 시작 (원버튼). 액체 셰이더 작업 중이라 고정.
static func start_test(tree: SceneTree) -> void:
	lab_mode = false
	start_room = RoomData.TEST_ROOM if RoomData.ROOMS.has(RoomData.TEST_ROOM) else RoomData.random_id()
	tree.change_scene_to_file(TEST_SCENE)


## 근경 랩: 실제 방·조명 위에서 근경 실루엣을 마우스로 배치하고 foreground/<방 id>.json 에 저장한다 ([ ] 로 방 전환)
static func start_foreground_lab(tree: SceneTree, room := "") -> void:
	lab_mode = true
	DepthPreset.index = 1                        # 근경은 "근경 분리" 프리셋에만 있다
	start_room = room if RoomData.ROOMS.has(room) else RoomData.START_ROOM
	resume_x = -1.0
	tree.change_scene_to_file(TEST_SCENE)


## 맵 뷰어: 방을 게임 없이 조립해 자유 카메라로 본다 ([ ] 로 방 전환)
static func start_map_viewer(tree: SceneTree, room := "") -> void:
	start_room = room if RoomData.ROOMS.has(room) else RoomData.START_ROOM
	tree.change_scene_to_file(MAP_VIEWER_SCENE)
