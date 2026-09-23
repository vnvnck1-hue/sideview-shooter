extends SceneTree
## 플레이어 동작 검수: 작업실에서 조준·걷기·질주·앉기·구르기·재장전·좌향을 차례로 입력하고
## 플레이어 주변을 잘라 한 장의 시트로 저장한다. (2026-09-23 고화질 원화 교체 검수용)
## 실행:  godot --path . --fixed-fps 60 --script res://tools/player_pose_shot.gd -- [방 id=workshop]
## 저장:  user://shots/player_pose/<단계>.png + sheet.png
## 창을 띄운 채로 돈다(헤드리스 불가).

const CROP := Vector2i(560, 520)
const FOOT_MARGIN := 40
const SETTLE := 80
## [시작 프레임, 이름, 누를 입력들, 조준 방향(1/-1), 캡처 프레임 오프셋들]
const STAGES := [
	[0, "idle", [], 1, [30]],
	[60, "walk", ["move_right"], 1, [20, 24, 28, 32]],
	[120, "run", ["move_right", "run"], 1, [20, 23, 26, 29]],
	[180, "crouch", ["crouch"], 1, [2, 5, 9, 30]],
	[240, "roll", ["roll"], 1, [1, 4, 7, 10, 13, 16]],
	[300, "reload", ["reload"], 1, [6, 18, 30, 42, 54, 64]],
	[380, "left_walk", ["move_left"], -1, [20, 26]],
	[440, "shoot", ["shoot"], 1, [1, 3, 5]],
]

var _f := 0
var _main: Node
var _shots: Array = []          # [name, Image]
var _out := "user://shots/player_pose"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	AppFlow.start_room = args[0] if args.size() > 0 else "workshop"
	change_scene_to_file(AppFlow.TEST_SCENE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))


func _player() -> Node2D:
	if _main == null:
		_main = current_scene
	if _main == null or not ("player" in _main):
		return null
	return _main.player


func _process(_delta: float) -> bool:
	_f += 1
	var p := _player()
	if p == null or _f < SETTLE:
		return false
	var t := _f - SETTLE
	var stage = null
	for s in STAGES:
		if t >= s[0]:
			stage = s
	if stage == null:
		return false
	var local := t - int(stage[0])
	# 입력: 단계 시작 프레임에 누르고, 다음 단계 직전에 뗀다 (구르기·재장전은 한 번 누르면 끝)
	for a in ["move_right", "move_left", "run", "crouch", "roll", "reload", "shoot"]:
		Input.action_release(a)
	for a in stage[2]:
		if a in ["roll", "reload"] and local > 1:
			continue
		Input.action_press(a)
	# 조준: 마우스를 플레이어 앞쪽 어깨 높이로
	var scr: Vector2 = p.get_global_transform_with_canvas().origin
	Input.warp_mouse(scr + Vector2(420.0 * float(stage[3]), -150.0))
	if local in stage[4]:
		var img := p.get_viewport().get_texture().get_image()
		var r := Rect2i(Vector2i(int(scr.x) - CROP.x / 2, int(scr.y) - CROP.y + FOOT_MARGIN), CROP)
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var name := "%s_%02d" % [stage[1], (stage[4] as Array).find(local) + 1]
		var sub := img.get_region(r)
		sub.save_png("%s/%s.png" % [_out, name])
		_shots.append([name, sub])
	var last = STAGES[STAGES.size() - 1]
	if t > int(last[0]) + 10:
		_save_sheet()
		return true
	return false


func _save_sheet() -> void:
	var cols := 6
	var rows := int(ceil(_shots.size() / float(cols)))
	var sheet := Image.create(CROP.x * cols, CROP.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.12))
	for i in _shots.size():
		var im: Image = _shots[i][1]
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i((i % cols) * CROP.x, (i / cols) * CROP.y))
	sheet.save_png(_out + "/sheet.png")
	print("SHEET -> ", ProjectSettings.globalize_path(_out + "/sheet.png"), " (", _shots.size(), " shots)")
