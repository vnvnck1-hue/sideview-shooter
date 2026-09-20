extends SceneTree
## NPC · 대화 시스템 확인용 자동 스크린샷.
##   기본      에어록 관리인에게 말을 걸어 말풍선 타자 → 선택지 → 화자 전환(카메라 팬)까지 찍는다
##   -- cast   다섯 인물이 서 있는 방을 돌며 한 장씩 찍는다 (스프라이트 접지·크기·조명 확인)
##   -- chain  인과관계를 끝까지 걸어 본다 (대사 나무만, 화면 없이)
##   -- revisit 관리인과 실제로 대화를 끝낸 뒤 관제원에게 가서 첫 마디가 바뀌는지 확인한다
##   -- styles  대사 표시 방식(DialogueBubble.STYLES) 다섯 가지를 같은 장면에서 한 장씩 찍는다
##
## 실행: godot --path . --script res://tools/npc_dialogue_shot.gd [-- cast|chain]   (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/npc_*.png  (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\)

const OUT := "user://shots/"

var main: Node2D
var t := 0.0
var step := 0
var steps: Array = []

## 말 걸기 → 첫 줄 → 선택지 → 고르기 → 화자 전환까지
const TALK_STEPS := [
	[0.40, "setup:caretaker:320"],
	[0.60, "shot:npc_00_prompt"],          # 머리 위 표식 + 하단 안내 문구
	[0.70, "interact"],
	[0.95, "shot:npc_01_typing"],          # 글자가 찍히는 중 + 카메라가 밀려 들어가는 중
	[1.30, "shot:npc_02_pushed_in"],
	[1.60, "adv"],                         # 타자 건너뛰기 (다 찍힌 상태)
	[1.75, "shot:npc_03_full_line"],
	[1.90, "adv"], [2.05, "adv"],          # hello2
	[2.20, "adv"], [2.35, "adv"],          # hello3 (선택지가 붙은 줄)
	[2.60, "shot:npc_04_choices"],
	[2.75, "pick_next"],
	[2.95, "shot:npc_05_choice_moved"],
	[3.10, "adv"],                         # 선택 확정 → 로봇이 말한다 (카메라가 플레이어 쪽으로)
	[3.30, "shot:npc_06_player_line"],
	[3.65, "shot:npc_07_camera_panned"],
	[3.80, "adv"], [3.95, "adv"],          # no_answer2
	[4.15, "shot:npc_08_reply"],
	[4.30, "adv"], [4.45, "adv"],          # shutter
	[4.60, "adv"], [4.75, "adv"],          # shutter2 — [shake]손으로[/shake]
	[4.90, "shot:npc_09_shake_tag"],
	[5.05, "adv"], [5.20, "adv"],          # shutter3
	[5.35, "adv"], [5.50, "adv"],          # shutter4 — 이름 색 강조
	[5.70, "shot:npc_10_accent_name"],
	[6.00, "flags"],
	[6.10, "quit"],
]

## 다섯 인물을 방마다 한 장씩
const CAST_STEPS := [
	[0.40, "goto:airlock:300"], [0.80, "shot:npc_cast_caretaker"],
	[1.00, "goto:corr_mid:380"], [1.40, "shot:npc_cast_controller"],
	[1.60, "goto:bunk_a:300"], [2.00, "shot:npc_cast_junior"],
	[2.20, "goto:hydro_lock:430"], [2.60, "shot:npc_cast_keeper"],
	[2.80, "goto:nursery:890"], [3.20, "shot:npc_cast_senior"],
	[3.30, "quit"],
]


## 인과관계를 **실제 플레이로** 확인한다: 관리인 대화를 끝까지 넘기면 lockdown 이 서고,
## 관제원의 entry 가 hello → accuse 로 바뀌어야 한다.
const REVISIT_STEPS := [
	[0.30, "setup:caretaker:320"],
	[0.40, "interact"],
	[0.50, "adv"], [0.60, "adv"], [0.70, "adv"], [0.80, "adv"],
	[0.90, "adv"], [1.00, "adv"],                      # hello → hello2 → hello3(선택지)
	[1.10, "adv"],                                     # 첫 선택지 확정
	[1.20, "adv"], [1.30, "adv"], [1.40, "adv"], [1.50, "adv"],
	[1.60, "adv"], [1.70, "adv"], [1.80, "adv"], [1.90, "adv"],
	[2.00, "adv"], [2.10, "adv"], [2.20, "adv"], [2.30, "adv"],
	[2.40, "adv"], [2.50, "adv"], [2.60, "adv"], [2.70, "adv"],
	[2.85, "flags"],
	[2.95, "shot:npc_revisit_00_after_caretaker"],
	[3.15, "goto:corr_mid:180"],                       # 관제원(x=500) 왼쪽에 선다
	[3.55, "interact"],
	[3.95, "shot:npc_revisit_01_controller"],
	[4.10, "quit"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var args := OS.get_cmdline_user_args()
	if args.has("cast"):
		steps = CAST_STEPS
	elif args.has("styles"):
		steps = _style_steps()
	elif args.has("revisit"):
		steps = REVISIT_STEPS
	elif args.has("chain"):
		steps = _chain_steps()
	else:
		steps = TALK_STEPS
	AppFlow.start_room = "airlock"
	change_scene_to_file(AppFlow.TEST_SCENE)


## 표시 방식마다 같은 장면(선택지가 붙은 줄)을 한 장씩. 방식을 바꿀 때마다 대화를 처음부터 다시 돌린다 —
## "누적 로그" 방식은 지난 줄이 쌓여 있어야 제 모습이 나오기 때문이다.
func _style_steps() -> Array:
	var out: Array = [[0.30, "setup:caretaker:320"]]
	var t := 0.45
	for i in DialogueBubble.STYLES.size():
		out.append([t, "style:%d" % i])
		out.append([t + 0.05, "reset"])
		out.append([t + 0.10, "restart"])
		for k in 4:
			out.append([t + 0.35 + k * 0.14, "adv"])      # hello → hello2 → hello3(선택지가 붙은 줄)
		out.append([t + 1.15, "shot:npc_style_%d_%s" % [i + 1, DialogueBubble.STYLES[i]["id"]]])
		t += 1.50
	out.append([t, "quit"])
	return out


## 인과관계를 손으로 걸어 본다 — 각 NPC 의 entry 가 상태에 따라 다른 노드를 고르는지만 본다
func _chain_steps() -> Array:
	return [[0.40, "chain"], [0.60, "shot:npc_chain"], [0.70, "quit"]]


func _process(delta: float) -> bool:
	if main == null:
		main = current_scene as Node2D
		if main == null or main.get("player") == null:
			return false
	t += delta
	while step < steps.size() and t >= steps[step][0]:
		var cmd: String = steps[step][1]
		step += 1
		if _do(cmd):
			return true
	return false


func _do(cmd: String) -> bool:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			var npc: Npc = main.current_room.npc_near(-99999.0)
			for n in main.current_room.npcs:
				if n.npc_id == parts[1]:
					npc = n
			main.player.position.x = npc.position.x + float(parts[2])
			main.player.face(-1)
			Input.warp_mouse(main.get_viewport().get_visible_rect().size * 0.5)   # 마우스 리드를 0 으로 — 구도를 재현 가능하게
			main.camera.snap()
		"goto":
			main._transition(parts[1], float(parts[2]), -1)
		"interact":
			main._on_front_door_requested()                  # 플레이어의 W/↑ 와 같은 경로
		"adv":
			_send("dlg_advance")
		"pick_next":
			_send("dlg_next")
		"chain":
			_walk_chain()
		"flags":
			print("FLAGS ", NpcState.flags)
		"shot":
			var img := root.get_viewport().get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			img.save_png(OUT + parts[1] + ".png")
			var d = main.dialogue
			print("SHOT %-26s active=%s speaker=%-10s node=%s typing=%s choices=%s zoom=%.2f" % [
				parts[1], d.active, d.current_speaker, d._node_id,
				main.dialogue_bubble.is_typing(), main.dialogue_bubble.has_choices(), main.camera.zoom.x])
		"quit":
			print("NPC SHOT DONE")
			return true
	return false


## InputEventAction 으로 보낸다 — Input.action_press 는 폴링 상태만 바꿔서 _unhandled_input 에 닿지 않는다
func _send(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


## 대사 나무를 실제로 걸어 인과관계가 이어지는지 확인한다 (화면 없이 플래그만)
func _walk_chain() -> void:
	NpcState.reset()
	var order := ["caretaker", "controller", "keeper", "junior", "senior", "caretaker", "controller"]
	for id in order:
		print("  %-12s entry=%-10s (flags: %s)" % [id, NpcData.entry_node(id), ", ".join(NpcState.flags.keys())])
		_run_tree(id)
	print("FINAL FLAGS ", NpcState.flags)


## 선택지는 늘 첫 번째를 고르며 한 나무를 끝까지 따라간다 (무한 고리 방지: 200 걸음)
func _run_tree(id: String) -> void:
	var node_id := NpcData.entry_node(id)
	var guard := 0
	while node_id != "" and guard < 200:
		guard += 1
		var n := NpcData.node(id, node_id)
		if n.is_empty():
			print("    !! 없는 노드 %s/%s" % [id, node_id])
			return
		NpcState.set_all(n.get("set", []))
		NpcState.mark_seen("%s/%s" % [id, node_id])
		var picked := ""
		for c in n.get("choices", []):
			if NpcState.test(str(c.get("if", ""))):
				NpcState.set_all(c.get("set", []))
				picked = str(c.get("to", ""))
				break
		if picked != "":
			node_id = picked
			continue
		var jumped := false
		for pair in n.get("branch", []):
			if NpcState.test(str(pair[0])):
				node_id = str(pair[1])
				jumped = true
				break
		if not jumped:
			node_id = str(n.get("next", ""))
