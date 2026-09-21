extends SceneTree
## **돌아서는 동작**만 연속 촬영한다 (헤드리스 금지 — 렌더가 필요하다).
##   godot --path . --script res://tools/walker_turn_film.gd
##   저장: user://shots/turn/t_NN.png
##
## 방향 전환은 한 장짜리 스크린샷으로는 판단할 수 없다. 플립이면 두 프레임 사이에 좌우가 뒤집히고,
## 제대로 돌면 여러 프레임에 걸쳐 실루엣이 납작해졌다가 반대쪽으로 펴진다 — 그걸 눈으로 보려고 만든 것이다.
const OUT := "user://shots/turn/"
const Lab := preload("res://scripts/walker_lab.gd")
## **물리를 직접 돌린다.** 랩의 _physics_process 를 끄고 한 프레임에 한 번씩 우리가 부른다 —
## 안 그러면 PNG 저장이 느려 물리 틱이 밀렸다가 한 프레임에 여러 번 돌고, 전환이 4프레임 만에
## 끝난 것처럼 찍힌다 (실제로는 16프레임이다. 처음 찍은 필름이 그래서 못 쓰게 됐다).
const STEP := 1.0 / 60.0
const WALK := 110         # 오른쪽으로 걷는 물리 프레임 수 (가속 + 몇 걸음)
const COUNT := 22         # 장수 (전환 시작 2프레임 전부터 매 프레임)

var _lab: Node2D
var _walker: ProcWalker
var _frame := 0
var _shots := 0
var _pending := -1


func _initialize() -> void:
	_lab = Lab.new()
	root.add_child(_lab)
	_lab.auto_drive = true


func _process(_d: float) -> bool:
	_frame += 1
	if _walker == null:
		for c in _lab.get_children():
			if c is ProcWalker:
				_walker = c
		if _walker == null:
			return _frame > 10
		DirAccess.make_dir_recursive_absolute(OUT)
		_lab.set_physics_process(false)
		return false

	_lab.auto_dir = 1.0 if _frame < WALK else -1.0      # WALK 프레임에 반대로 꺾는다
	_lab._physics_process(STEP)                         # 한 프레임 = 한 틱 (위 주석 참고)

	if _pending == _frame:
		var img := root.get_texture().get_image()
		img.save_png(OUT + "t_%02d.png" % _shots)
		print("  t_%02d  yaw=%5.2f  facing=%+d  속도 %6.1f" % [
			_shots, _walker.yaw, _walker.facing, _walker.speed,
		])
		_shots += 1
		_pending = -1
		if _shots >= COUNT:
			print("--- %d 장 저장: %s ---" % [_shots, ProjectSettings.globalize_path(OUT)])
			quit()
			return true

	if _frame >= WALK - 2 and _pending < 0:
		_pending = _frame + 1

	if _frame > 1200:
		print("시간 초과")
		quit(1)
		return true
	return false
