extends SceneTree
## 아이들 모션 프리셋 비교 필름: 플레이어를 가만히 세워 두고 프리셋마다 한 사이클 이상을 연속 캡처한다.
## 실행:  godot --path . --fixed-fps 60 --script res://tools/idle_film.gd -- [방 id=workshop] [장수=40] [간격 프레임=2]
## 저장:  user://shots/idle_film/<프리셋 id>/f%02d.png  (--fixed-fps 60 · 간격 2 → 30fps 필름)
## 창을 띄운 채로 돈다(헤드리스 불가). 잘라 내는 곳은 월드 뷰포트(UI·CRT 제외)의 플레이어 주변.

const CROP := Vector2i(300, 300)         # 잘라 낼 크기 (발 밑 기준 위쪽) — 캐릭터만 꽉 차게
const FOOT_MARGIN := 34                  # 발 아래로 남길 여백
const SETTLE := 70                       # 방·조명이 자리를 잡을 때까지 기다리는 프레임
const BLEND := 24                        # 프리셋을 바꾼 뒤 모션이 올라올 때까지

var _room := "workshop"
var _count := 40
var _every := 2
var _main: Node
var _stage := 0                          # 프리셋 인덱스
var _shot := 0
var _f := 0
var _t0 := 0
var _rect := Rect2i()                    # 첫 프리셋에서 한 번 정하고 끝까지 고정 (배경이 흔들리면 비교가 안 된다)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_room = args[0]
	if args.size() > 1:
		_count = maxi(2, int(args[1]))
	if args.size() > 2:
		_every = maxi(1, int(args[2]))
	if not RoomData.ROOMS.has(_room):
		push_error("unknown room id: " + _room)
		quit(1)
		return
	AppFlow.start_test(self, _room, -1.0, 1)


func _process(_delta: float) -> bool:
	_f += 1
	if _main == null:
		var scene := current_scene
		if scene == null or not scene.has_method("_load_room"):
			return _f > 600
		_main = scene
		_t0 = _f
		print("[idle_film] main scene ready at frame ", _f)
		return false
	var player = _main.get("player")
	if player == null:
		if _f % 60 == 0:
			print("[idle_film] waiting for player... f=", _f)
		return false
	# 가만히 서 있게 못 박는다 — 입력을 끄고, 조준점도 정면 고정 (머리가 마우스를 따라 흔들리지 않게)
	player.input_enabled = false
	player.aim_target = player.position + Vector2(600, -150)
	if _f - _t0 < SETTLE:
		return false
	if _f - _t0 == SETTLE:
		print("[idle_film] settled, first preset")
		_freeze_camera()
		_clear_monsters()
		_arm_preset()
		return false
	if _f - _t0 < SETTLE + BLEND:
		return false
	if (_f - _t0 - SETTLE - BLEND) % _every != 0:
		return false

	var vp := _main.get("world_vp") as SubViewport
	var img := vp.get_texture().get_image()
	if _rect.size == Vector2i.ZERO:
		var foot: Vector2 = vp.get_canvas_transform() * player.global_position
		_rect = Rect2i(int(foot.x) - CROP.x / 2, int(foot.y) + FOOT_MARGIN - CROP.y, CROP.x, CROP.y)
		_rect.position.x = clampi(_rect.position.x, 0, img.get_width() - CROP.x)
		_rect.position.y = clampi(_rect.position.y, 0, img.get_height() - CROP.y)
	var preset: Dictionary = player.idle_presets()[_stage]
	var dir := "user://shots/idle_film/%s/" % preset["id"]
	img.get_region(_rect).save_png(dir + "f%02d.png" % _shot)
	_shot += 1
	if _shot < _count:
		return false
	print("FILM %s -> %s (%d장)" % [preset["id"], ProjectSettings.globalize_path(dir), _shot])
	_stage += 1
	if _stage >= player.idle_presets().size():
		print("--- done: ", ProjectSettings.globalize_path("user://shots/idle_film/"), " ---")
		return true
	_shot = 0
	_t0 = _f - SETTLE            # 다음 프리셋은 블렌드 시간만 기다린다
	_arm_preset()
	return false


## 몬스터를 치운다 — 프리셋이 여섯이라 필름이 길어지면서 크롤러가 화면에 들어와 비교를 방해했다.
func _clear_monsters() -> void:
	var room = _main.get("current_room")
	if room != null and room.has_method("disable_monsters"):
		room.disable_monsters()


## 카메라를 그 자리에 못 박는다 — 리드(마우스 추종)·흔들림이 남으면 배경이 계속 흘러 모션 비교가 안 된다.
func _freeze_camera() -> void:
	var cam = _main.get("camera")
	if cam == null:
		return
	cam.lead_enabled = false
	cam.snap()
	cam.set_process(false)
	cam.set_physics_process(false)
	cam.offset = Vector2.ZERO


## 다음 프리셋으로 갈아 끼우고, 위상·강조 스프링을 0 에서 다시 시작시킨다 (프리셋마다 같은 지점에서 출발).
func _arm_preset() -> void:
	seed(20260922)
	var player = _main.get("player")
	player.use_idle_preset(_stage)
	var preset: Dictionary = player.idle_presets()[_stage]
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://shots/idle_film/%s/" % preset["id"]))
