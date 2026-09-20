extends "res://scripts/main.gd"
## 대화 UI 랩 (scenes/DialogueLab.tscn) — **표시 방식 다섯 가지를 같은 대사로 나란히 비교**하는 씬.
##
## 실제 방·조명·인물 위에서 돌아간다. 스크린샷으로 비교하면 결국 "이 게임 화면에서 어떻게 보이나"
## 가 답이므로, 별도의 빈 씬이 아니라 진짜 게임 화면을 그대로 쓴다 (근경 랩과 같은 생각).
##
##   1~5        표시 방식 직접 고르기 (DialogueBubble.STYLES).
##              단 "누적 로그" 방식에서 선택지가 떠 있는 동안에는 숫자가 선택지 단축키라 Tab 을 쓴다
##   Tab / F7   다음 표시 방식 (게임 본편은 "자막"으로 확정됐다 — 바꿔 볼 수 있는 곳은 이 랩뿐이다)
##   V / Shift+V 다음 · 이전 **음성 방식** (DialogueVoice.PRESETS — 아직 고르는 중이다)
##   [ / ]      말 거는 상대 바꾸기 (그 인물이 있는 방으로 바로 옮겨 간다)
##   R          지금 대화를 처음부터 다시
##   0          인과관계 플래그 초기화 (첫 만남 대사로 되돌린다)
##   F1         로비
##
## 방식을 바꾸면 보고 있던 줄을 **처음부터 다시 찍는다** — 타자 연출까지 봐야 비교가 되므로.

const TALK_GAP := 300.0                 # 플레이어가 상대에게서 떨어져 서는 거리

var _cast: Array = []                   # [{id, room, x, facing}] — RoomData 에서 훑어 온다
var _cast_index := 0
var _style_label: Label
var _keys_label: Label


func _ready() -> void:
	_cast = _find_cast()
	NpcState.reset()
	super()
	var layer := get_node("UI") as CanvasLayer

	_style_label = _lab_label(Vector2(24, 18), 30, Color(0.95, 0.92, 0.85))
	layer.add_child(_style_label)
	_keys_label = _lab_label(Vector2(24, 60), 20, Color(0.66, 0.70, 0.78))
	_keys_label.size = Vector2(1560, 170)
	_keys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_keys_label)

	_goto_cast(0)


func _lab_label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	l.position = pos
	l.size = Vector2(1400, 44)
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.z_index = 60
	return l


## RoomData 를 훑어 배치된 생존자를 찾는다 (배치의 단일 출처는 여기라 표를 따로 들지 않는다)
func _find_cast() -> Array:
	var out: Array = []
	for room_id in RoomData.ids():
		for p in RoomData.get_room(room_id).get("props", []):
			if str(p.get("type", "")) != "npc":
				continue
			out.append({
				"id": str(p.get("id", "")), "room": room_id,
				"x": float(p.get("x", 0.0)), "facing": int(p.get("facing", -1)),
			})
	return out


# ── 랩 조작 ─────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_9:
		var i := k.keycode - KEY_1
		if i < DialogueBubble.STYLES.size():
			_set_style(i)
			get_viewport().set_input_as_handled()
		return
	match k.keycode:
		KEY_TAB:
			_set_style(DialogueBubble.style_index + 1)
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT:
			_goto_cast(_cast_index - 1)
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT:
			_goto_cast(_cast_index + 1)
			get_viewport().set_input_as_handled()
		KEY_V:
			# 음성 방식은 **줄을 다시 찍어야** 비교가 된다 (줄머리 한마디·웅얼거림은 줄 시작에 붙는다)
			DialogueVoice.cycle(-1 if k.shift_pressed else 1)
			_begin_talk()
			_update_labels()
			get_viewport().set_input_as_handled()
		KEY_R:
			_begin_talk()
			get_viewport().set_input_as_handled()
		KEY_0, KEY_KP_0:
			NpcState.reset()
			_begin_talk()
			get_viewport().set_input_as_handled()


## F7 은 **이 랩에서만** 산다. 게임 쪽 Main 은 "자막"(DialogueBubble.FIXED_STYLE)으로 고정이다.
func _process(delta: float) -> void:
	super(delta)
	if Input.is_action_just_pressed("dialogue_style"):
		_set_style(DialogueBubble.style_index + 1)


func _set_style(i: int) -> void:
	dialogue_bubble.set_style(i)
	_update_labels()


## 그 인물이 있는 방으로 옮겨 가 바로 말을 건다
func _goto_cast(i: int) -> void:
	if _cast.is_empty():
		return
	_cast_index = wrapi(i, 0, _cast.size())
	var entry: Dictionary = _cast[_cast_index]
	if dialogue.active:
		dialogue.stop()
	if current_room == null or current_room.room_id != str(entry["room"]):
		_load_room(str(entry["room"]), float(entry["x"]) + TALK_GAP, -1)
	_begin_talk()


## 상대 옆에 다시 서서 처음부터 말을 건다 (플래그는 그대로 — 0 으로 지운다)
func _begin_talk() -> void:
	if current_room == null or current_room.npcs.is_empty():
		return
	var npc: Npc = current_room.npcs[0]
	for n in current_room.npcs:
		if n.npc_id == str(_cast[_cast_index]["id"]):
			npc = n
	if dialogue.active:
		dialogue.stop()
	player.position.x = npc.position.x + TALK_GAP
	player.face(-1)
	camera.snap()
	_update_labels()
	# stop() 의 카메라 복귀 트윈이 끝나기를 한 프레임 기다렸다 새로 밀어 넣는다
	await get_tree().process_frame
	_on_npc_talk(npc)


## 대사가 끝나도 랩에서는 안내가 남아야 한다 (게임에서는 HUD 와 함께 사라진다)
func _set_world_hud(shown: bool) -> void:
	super(shown)
	if _style_label:
		_style_label.visible = true
		_keys_label.visible = true


func _update_labels() -> void:
	if _style_label == null:
		return
	var st := DialogueBubble.style_of(DialogueBubble.style_index)
	var names := PackedStringArray()
	for i in DialogueBubble.STYLES.size():
		var n: String = DialogueBubble.STYLES[i]["name"]
		names.append("[%d %s]" % [i + 1, n] if i == DialogueBubble.style_index else " %d %s " % [i + 1, n])
	var voice := DialogueVoice.preset()
	_style_label.text = "대화 UI 랩   ·   %s   ·   음성 %d/%d %s" % [
		"  ".join(names), DialogueVoice.preset_index + 1, DialogueVoice.PRESETS.size(), voice["name"]]
	var who: String = NpcData.get_cast(str(_cast[_cast_index]["id"])).get("short", "?") if not _cast.is_empty() else "?"
	_keys_label.text = "표시: %s\n음성: %s\n상대: %s (%d/%d)    ·    1~5 표시 방식  ·  Tab 다음  ·  V / Shift+V 음성 방식  ·  [ ] 상대 바꾸기  ·  R 대화 다시  ·  0 플래그 초기화  ·  F1 로비" % [
		st["desc"], voice["desc"], who, _cast_index + 1, _cast.size()]
