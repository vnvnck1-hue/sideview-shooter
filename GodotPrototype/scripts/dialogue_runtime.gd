class_name DialogueRuntime
extends Node
## 대사 나무를 실제로 걸어 다니는 부분 — npc_data.gd(내용)와 dialogue_bubble.gd(연출) 사이.
##
## 한 노드 = 말풍선 한 줄. 줄이 다 찍히면
##   선택지가 있으면 → 선택지를 띄우고 기다린다
##   없으면          → 확인 키를 기다렸다 branch → next 순으로 다음 노드
## 플래그(NpcState)는 노드에 들어가는 순간과 선택지를 고르는 순간에 세워진다.
##
## 말풍선이 붙을 화면 좌표와 카메라는 Main 이 맡는다: anchor_provider 로 좌표를 받고,
## 말하는 사람이 바뀔 때마다 speaker_changed 로 알린다.

signal line_started(who: String)        # 말풍선 한 줄이 시작됐다 (끄덕임 같은 몸짓을 맞추는 시점)
signal speaker_changed(who: String)     # "player" 또는 CAST 의 id
signal finished()

var bubble: DialogueBubble
## Main 이 넣어 준다: func(who: String) -> Vector2 (말하는 사람 머리 꼭대기의 창 좌표)
var anchor_provider: Callable

var npc_id := ""
var current_speaker := ""
var active := false

var _node_id := ""
var _choices: Array = []                # 조건을 통과해 지금 화면에 뜬 선택지들


func setup(b: DialogueBubble) -> void:
	bubble = b
	bubble.line_completed.connect(_on_line_completed)
	bubble.advanced.connect(_on_advanced)
	bubble.choice_picked.connect(_on_choice_picked)


## 지금 상태에서 이 NPC 와 나눌 대화가 있는가 (없으면 말 걸기 자체를 막는다)
static func has_dialogue(id: String) -> bool:
	return NpcData.entry_node(id) != ""


func start(id: String) -> bool:
	if active:
		return false
	var entry := NpcData.entry_node(id)
	if entry == "":
		return false
	npc_id = id
	active = true
	_enter(entry)
	return true


func stop() -> void:
	if not active:
		return
	active = false
	_node_id = ""
	_choices.clear()
	current_speaker = ""
	bubble.close()
	finished.emit()


func anchor_for(who: String) -> Vector2:
	if anchor_provider.is_valid():
		return anchor_provider.call(who)
	return get_viewport().get_visible_rect().size * Vector2(0.5, 0.45)


# ── 나무 걷기 ───────────────────────────────────────────────────────────────

func _enter(node_id: String) -> void:
	if node_id == "":
		stop()
		return
	var n := NpcData.node(npc_id, node_id)
	if n.is_empty():
		push_warning("대사 노드 '%s/%s' 가 없습니다" % [npc_id, node_id])
		stop()
		return
	_node_id = node_id
	_choices.clear()
	NpcState.set_all(n.get("set", []))
	NpcState.mark_seen("%s/%s" % [npc_id, node_id])

	var text := str(n.get("text", ""))
	if text == "":                                   # 플래그만 세우고 지나가는 노드
		_advance_from(n)
		return
	var who := str(n.get("who", npc_id))
	if who != current_speaker:
		current_speaker = who
		speaker_changed.emit(who)
	line_started.emit(who)
	bubble.show_line(NpcData.get_cast(who), text, anchor_for(who))


func _on_line_completed() -> void:
	if not active:
		return
	var n := NpcData.node(npc_id, _node_id)
	_choices = _visible_choices(n)
	if _choices.is_empty():
		return                                        # 확인 키를 기다린다
	var texts: Array = []
	for c in _choices:
		texts.append(str(c.get("text", "")))
	bubble.show_choices(texts)


func _on_advanced() -> void:
	if not active or not _choices.is_empty():
		return
	_advance_from(NpcData.node(npc_id, _node_id))


func _on_choice_picked(index: int) -> void:
	if not active or index < 0 or index >= _choices.size():
		return
	var c: Dictionary = _choices[index]
	NpcState.set_all(c.get("set", []))
	_enter(str(c.get("to", "")))


## branch 가 먼저다 — 그 사이에 세워진 플래그를 반영해 갈래를 고른다. 없으면 next.
func _advance_from(n: Dictionary) -> void:
	for pair in n.get("branch", []):
		if NpcState.test(str(pair[0])):
			_enter(str(pair[1]))
			return
	_enter(str(n.get("next", "")))


func _visible_choices(n: Dictionary) -> Array:
	var out: Array = []
	for c in n.get("choices", []):
		if NpcState.test(str(c.get("if", ""))):
			out.append(c)
	return out
