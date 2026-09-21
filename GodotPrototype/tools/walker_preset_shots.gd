extends SceneTree
## 걸음새 프리셋 비교용 스크린샷. 프리셋마다 **선 자세 한 장 + 걷는 중 한 장**을 남긴다.
## 실행: godot --path . --script res://tools/walker_preset_shots.gd   (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/preset/p<N>_stand.png · p<N>_walk.png

const OUT := "user://shots/preset/"
const Lab := preload("res://scripts/walker_lab.gd")
const STAND_FRAMES := 70           # 프리셋을 적용하고 자세가 가라앉을 때까지
const WALK_FRAMES := 150           # 걷기 시작 후 (걸음 주기가 느린 프리셋도 한 걸음은 지나도록)

var _lab: Node2D
var _walker: ProcWalker
var _preset := 1
var _frame := 0
var _shot := 0                     # 0 선 자세 대기 · 1 걷기 대기 · 2 다음 프리셋
var _pending := -1


func _initialize() -> void:
	_lab = Lab.new()
	root.add_child(_lab)
	_lab.auto_drive = true          # _ready 전에 — 첫 프레임의 엉뚱한 마우스 좌표를 조준점으로 삼지 않게


func _process(_delta: float) -> bool:
	_frame += 1
	if _walker == null:
		for c in _lab.get_children():
			if c is ProcWalker:
				_walker = c
		if _walker == null:
			return _frame > 10
		DirAccess.make_dir_recursive_absolute(OUT)
		_apply(_preset)
		return false

	if _pending == _frame:
		_save("p%d_%s" % [_preset, "stand" if _shot == 0 else "walk"])
		_shot += 1
		_pending = -1
		if _shot >= 2:
			_preset += 1
			if _preset > 6:
				print("--- 프리셋 스크린샷 저장: %s ---" % ProjectSettings.globalize_path(OUT))
				quit()
				return true
			_apply(_preset)
			return false

	_lab.auto_dir = 0.0 if _shot == 0 else 1.0
	if _pending < 0:
		var want: int = STAND_FRAMES if _shot == 0 else WALK_FRAMES
		if _frame - _start >= want:
			_pending = _frame + 1

	if _frame > 4000:
		print("시간 초과")
		quit(1)
		return true
	return false


var _start := 0


## 프리셋을 적용하고 그 자리에서 자세를 다시 잡는다 (몸 높이가 크게 달라지므로)
func _apply(n: int) -> void:
	var pset: Dictionary = Lab.PRESETS[KEY_0 + n]
	for k in pset.keys():
		if k != "name":
			_walker.tune[k] = pset[k]
	_walker.body_pos = Vector2(-1800.0, _lab.ground_at(-1800.0) - (_walker.tune["ride"] as float))
	_walker.reset_stance()
	_shot = 0
	_start = _frame
	print("  [%d] %s" % [n, pset["name"]])


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
