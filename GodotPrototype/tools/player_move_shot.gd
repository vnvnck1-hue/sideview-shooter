extends SceneTree
## 플레이어 이동 동작 검수 (2026-09-25): 점프 · 사다리(측면) · 걸으며 재장전 · 앉아 걷기 · 앉아 걸으며 재장전.
## 작업실(ladders: [520])에서 단계마다 플레이어를 정해진 x 로 옮겨 놓고 입력을 넣어 주변을 잘라 시트로 저장한다.
## 실행:  godot --path . --fixed-fps 60 --script res://tools/player_move_shot.gd
## 저장:  user://shots/player_move/<단계>.png + sheet.png
## 창을 띄운 채로 돈다(헤드리스 불가).

const CROP := Vector2i(560, 760)
const FOOT_MARGIN := 40
const SETTLE := 80
## [시작 프레임, 이름, 누를 입력들, 조준 방향(1/-1), 캡처 프레임 오프셋들, 시작 x]
## 한 번만 누르는 입력(interact·reload·roll)은 단계 첫 두 프레임에만 누른다 — 사다리 오르기는 "climb_up" 으로 계속 누른다.
const ONCE := ["interact", "reload", "roll"]
const STAGES := [
	[0, "jump", ["interact"], 1, [2, 8, 16, 24, 34, 44], 300.0],
	[70, "jump_run", ["interact", "move_right"], 1, [10, 24, 38], 300.0],
	[110, "stand_reload", ["reload"], 1, [10], 150.0],
	[130, "walk_reload", ["reload", "move_right"], 1, [10, 20, 30, 40, 50, 60], 150.0],
	[210, "crouch_walk", ["crouch", "move_right"], 1, [20, 26, 32, 38], 250.0],
	[270, "crouch_walk_reload", ["crouch", "reload", "move_right"], 1, [24, 36, 48, 60], 250.0],
	[350, "ladder_up", ["interact", "climb_up"], 1, [4, 20, 36, 52, 68, 100], 460.0],
	[460, "ladder_down", ["crouch"], 1, [10, 30], -1.0],
	[520, "ladder_left", ["interact", "climb_up"], -1, [30, 50], 580.0],
	[580, "ladder_drop", ["move_left"], -1, [4, 14, 24], -1.0],
]

var _f := 0
var _main: Node
var _shots: Array = []          # [name, Image]
var _out := "user://shots/player_move"


func _initialize() -> void:
	AppFlow.start_room = "workshop"
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
	if _f == SETTLE:
		_main.current_room.disable_monsters()
	var t := _f - SETTLE
	var stage = null
	for s in STAGES:
		if t >= s[0]:
			stage = s
	if stage == null:
		return false
	var local := t - int(stage[0])
	if local == 0 and float(stage[5]) >= 0.0:
		p.settle()
		p.position.x = float(stage[5])
		p.velocity_x = 0.0
		p.reloading = false
		if "reload" in stage[2]:
			p.ammo = 3                        # 탄창이 차 있으면 재장전이 안 걸린다
	for a in ["move_right", "move_left", "run", "crouch", "roll", "reload", "shoot", "interact"]:
		Input.action_release(a)
	for a in stage[2]:
		if a == "climb_up":
			if local > 1:
				Input.action_press("interact")      # 이미 잡았으니 누르고 있으면 오른다
			continue
		if a in ONCE and local > 1:
			continue
		Input.action_press(a)
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
		print(name, "  state=", p.state, " air=", snappedf(p.air_height(), 0.1), " x=", snappedf(p.position.x, 0.1), " body=", p.body.animation, ":", p.body.frame, " up=", p.reload_upper.visible, p.reload_upper.position, " legs=", p.reload_legs.region_rect)
	var last = STAGES[STAGES.size() - 1]
	if t > int(last[0]) + 30:
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
