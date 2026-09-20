extends "res://scripts/main.gd"
## 메인 게임 씬 (scenes/MainGame.tscn): Main 과 같은 플레이 루프에 전체 맵 탐색 HUD 를 더한다.
##   - 에어록(RoomData.START_ROOM)에서 시작 (AppFlow.start_main_game)
##   - 우상단: 현재 구역 · 방 위험도 · 탐색한 방 수 / 전체
##   - 좌하단 힌트에 문 종류 안내

var visited := {}
var explore_label: Label
var _hud_font: Font


func _ready() -> void:
	super()
	_hud_font = SystemFont.new()
	_hud_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	var layer := get_node("UI") as CanvasLayer
	explore_label = Label.new()
	explore_label.position = Vector2(AppFlow.VIEW_SIZE.x - 24 - 700, 84)
	explore_label.size = Vector2(700, 60)
	explore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	explore_label.add_theme_font_override("font", _hud_font)
	explore_label.add_theme_font_size_override("font_size", 22)
	explore_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.7))
	layer.add_child(explore_label)
	hint_label.text = "F1 로비    A/D 이동    마우스 조준 · 좌클릭 사격    Space 구르기    Ctrl 앉기    W/↑ 정면문 진입 · 생존자에게 말 걸기    대화 중 Space/E 넘기기 · ↑/↓ 선택    측벽문(초록등)은 걸어서 통과    R 재장전    F3 줌    F4 CRT 모니터    F11 전체화면"
	_note_room()


func _load_room(id: String, spawn_x: float, face_dir: int) -> void:
	super(id, spawn_x, face_dir)
	if explore_label:
		_note_room()


## 단말기 화면이 시야를 채우는 동안은 탐색 라벨도 같이 숨는다
func _set_world_hud(shown: bool) -> void:
	super(shown)
	if explore_label:
		explore_label.visible = shown


func _note_room() -> void:
	if current_room == null:
		return
	visited[current_room.room_id] = true
	var data := RoomData.get_room(current_room.room_id)
	var danger := RoomData.danger(current_room.room_id)
	var danger_color := Color(0.6, 0.9, 0.65)
	if danger == "적음":
		danger_color = Color(1.0, 0.85, 0.4)
	elif danger == "위험":
		danger_color = Color(1.0, 0.45, 0.35)
	explore_label.text = "%s  ·  몬스터 %s  ·  탐색 %d / %d" % [data["zone"], danger, visited.size(), RoomData.ROOMS.size()]
	explore_label.add_theme_color_override("font_color", danger_color)
