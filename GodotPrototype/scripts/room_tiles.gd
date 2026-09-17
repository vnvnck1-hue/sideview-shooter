@tool
class_name RoomTiles
extends Node2D
## 방 하나의 모듈러 타일맵 씬 루트 (scenes/rooms/<방 id>.tscn).
## 자식으로 TileMapLayer 두 개를 둔다: "Background"(배경 채움) 와 "Frame"(외곽선 오버레이).
## Godot 에디터에서 이 씬을 열고 TileMap 하단 패널의 [Terrains] 탭으로 찍는다 — 모서리·변은 자동으로 붙는다.
##   배경 채움 터레인 : Background 레이어에 방 전체 영역을 채운다 (6종 무늬가 랜덤으로 섞인다)
##   프레임 터레인   : Frame 레이어에 같은 영역을 채운다 (테두리 셀만 그려지고 안쪽은 투명)
## 이 노드의 position 이 격자 원점이다. 기본 (0, 24): 4행이 방 높이(560) 안에 들고
## 3번째 행 바닥 프레임의 밟는 띠 윗선이 바닥선(486)에 온다.
## Room.build 가 방 id 와 같은 이름의 씬이 있으면 인스턴스해서 배경 타일 위에 올린다.

## true 면 옛 560px 가로 스트립 타일을 숨기고 이 타일맵만 배경으로 쓴다
@export var hide_legacy_tiles := false


static func scene_path(room_id: String) -> String:
	return "res://scenes/rooms/%s.tscn" % room_id


static func exists(room_id: String) -> bool:
	return ResourceLoader.exists(scene_path(room_id))


## 게임 라이팅 머티리얼을 두 레이어에 입힌다 (배경 타일: 실루엣 림 없음)
func apply_lit_material() -> void:
	for child in get_children():
		if child is TileMapLayer:
			var m := Lighting.lit_material()
			m.set_shader_parameter("rim_ambient_strength", 0.0)
			m.set_meta("rim_ambient_fixed", true)
			child.material = m
