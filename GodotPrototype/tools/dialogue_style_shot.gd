extends SceneTree
## 대사 표시 방식(DialogueBubble.STYLES) 다섯 가지를 **월드 없이** 한 장씩 찍는다.
##
## 방·인물·조명을 띄우지 않으므로 세계가 깨져 있어도(다른 스크립트가 편집 중이어도) 돌아간다.
## "게임 화면 위에서 어떻게 보이나" 는 대화 UI 랩(scenes/DialogueLab.tscn)이나
## tools/npc_dialogue_shot.gd -- styles 로 봐야 하고, 이 도구는 **배치·그리기 코드 검사**용이다.
##
## 실행: godot --path . --script res://tools/dialogue_style_shot.gd   (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/dlgstyle_*.png

const OUT := "user://shots/"
## 실제 대사에서 가져온 표본 — 짧은 줄 · 긴 줄 · 태그 · 선택지까지 한 장에 들어간다
const SAMPLE := "그래서, [p=0.2]너 사람 꺼내러 온 거냐 [p=0.2]물건 꺼내러 온 거냐. [p=0.3]격벽은 [shake]손으로[/shake] 내렸어."
const CHOICES := ["구조 프로토콜로 기동했다.", "답할 권한이 없다.", "대답하지 않는다."]
## 로그 방식이 제 모습을 내려면 지나간 줄이 있어야 한다
const PRELUDE := [
	["caretaker", "…어. [p=0.3]진짜 걸어 들어오네."],
	["player", "구조 프로토콜. [p=0.2]생존자가 우선이다."],
	["caretaker", "사흘 만이다. [p=0.3]멀쩡하게 움직이는 거 보는 게."],
]

var bubble: DialogueBubble
var t := 0.0
var step := 0
var steps: Array = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.content_scale_size = AppFlow.VIEW_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	# 게임 화면과 비슷한 어두운 바탕 — 대비를 보려는 것이라 방을 조립하지는 않는다
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.062, 0.078)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var floor_line := ColorRect.new()
	floor_line.color = Color(0.10, 0.11, 0.135)
	floor_line.position = Vector2(0, AppFlow.VIEW_SIZE.y * 0.72)
	floor_line.size = Vector2(AppFlow.VIEW_SIZE.x, AppFlow.VIEW_SIZE.y * 0.28)
	root.add_child(floor_line)

	bubble = DialogueBubble.new()
	root.add_child(bubble)

	for i in DialogueBubble.STYLES.size():
		var base := 0.20 + i * 0.60
		steps.append([base, "style:%d" % i])
		for k in PRELUDE.size():
			steps.append([base + 0.06 + k * 0.05, "line:%d" % k])
		steps.append([base + 0.26, "sample"])
		steps.append([base + 0.32, "choices"])
		steps.append([base + 0.50, "shot:dlgstyle_%d_%s" % [i + 1, DialogueBubble.STYLES[i]["id"]]])
	steps.append([0.20 + DialogueBubble.STYLES.size() * 0.60, "quit"])


func _process(delta: float) -> bool:
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
		"style":
			bubble.set_style(int(parts[1]))
		"line":
			var e: Array = PRELUDE[int(parts[1])]
			bubble.show_line(NpcData.get_cast(str(e[0])), str(e[1]), _anchor(str(e[0])))
			bubble.skip_typing()
		"sample":
			bubble.show_line(NpcData.get_cast("caretaker"), SAMPLE, _anchor("caretaker"))
			bubble.skip_typing()
		"choices":
			bubble.show_choices(CHOICES)
		"shot":
			var img := root.get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			img.save_png(OUT + parts[1] + ".png")
			var st := bubble.style()
			print("SHOT %-22s place=%-7s panel=%-6s name=%-7s choices=%-9s log=%d" % [
				parts[1], st["place"], st["panel"], st["name_mode"], st["choices"], st["log"]])
		"quit":
			print("DIALOGUE STYLE SHOT DONE")
			return true
	return false


## 머리 위 방식이 가리킬 지점 — 화면 왼쪽 아래를 NPC, 오른쪽 아래를 플레이어라고 친다
func _anchor(who: String) -> Vector2:
	var v := Vector2(AppFlow.VIEW_SIZE)
	return Vector2(v.x * (0.68 if who == "player" else 0.36), v.y * 0.60)
