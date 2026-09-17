class_name AppFlow
extends RefCounted
## 씬 간 흐름: 로비 → 게임(시작 방 선택) / 타일 씬 보기. 타일맵 편집 자체는 Godot 에디터에서 scenes/rooms/<id>.tscn 을 연다.

const LOBBY_SCENE := "res://scenes/Lobby.tscn"
const MAIN_SCENE := "res://scenes/Main.tscn"
const TILE_VIEWER_SCENE := "res://scenes/TileViewer.tscn"

## Main 이 처음 로드할 방 id (RoomData.ROOMS 키)
static var start_room := "workshop"


static func go_lobby(tree: SceneTree) -> void:
	tree.change_scene_to_file(LOBBY_SCENE)


static func start_game(tree: SceneTree, room := "workshop") -> void:
	start_room = room
	tree.change_scene_to_file(MAIN_SCENE)


## 고른 방의 타일 씬(scenes/rooms/<id>.tscn)만 자유 카메라로 띄우는 뷰어
static func start_tile_viewer(tree: SceneTree, room: String) -> void:
	start_room = room
	tree.change_scene_to_file(TILE_VIEWER_SCENE)
