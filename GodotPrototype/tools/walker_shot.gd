extends SceneTree
## 사족보행 랩 확인용 자동 스크린샷. 로봇을 지형 위로 걷게 하면서 자세가 바뀌는 자리마다 한 장씩 남긴다.
## 실행: godot --path . --script res://tools/walker_shot.gd   (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/walker_*.png  (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\)
##
## 랩을 **평소 경로 그대로** 돌린다 (WalkerLab.auto_drive 로 방향만 넣는다). 여기서 워커를 직접 tick 하면
## 랩의 _physics_process 와 이중으로 돌아 화면과 상태가 어긋난다 — 한 번 그 함정에 빠졌던 자리다.

const OUT := "user://shots/"
const Lab := preload("res://scripts/walker_lab.gd")

## [지나갈 x, 파일 이름] — 그 x 를 넘을 때 한 장 찍는다
const MARKS := [
	[-1.0, "walker_00_standing"],       # 출발 전 정지 자세
	[420.0, "walker_01_flat"],          # 평지 보행
	[1150.0, "walker_02_slope_up"],     # 오르막 — 몸이 지면을 따라 눕는가
	[1500.0, "walker_03_ledge"],        # 턱을 딛고 올라선 직후
	[1900.0, "walker_04_step_down"],    # 단을 내려선 직후
	[2600.0, "walker_05_bumpy"],        # 울퉁불퉁 — 네 발 높이가 다 다른 자리
	[3000.0, "walker_06_bumpy_b"],
	[4000.0, "walker_07_steep"],        # 급경사
	[4720.0, "walker_08_cliff"],        # 낭떠러지를 막 내려선 자리
]

var _lab: Node2D
var _walker: ProcWalker
var _mark := 0
var _frame := 0
var _shot_at := -1
var _jumped := false


func _initialize() -> void:
	_lab = Lab.new()
	root.add_child(_lab)
	# _ready 전에 켜 둔다 — 첫 물리 프레임에 읽힌 엉뚱한 마우스 좌표를 조준점으로 삼아
	# 로봇이 반대로 돌아선 채 촬영되는 일을 막는다
	_lab.auto_drive = true   # _ready 전에


func _process(_delta: float) -> bool:
	_frame += 1
	if _walker == null:
		for c in _lab.get_children():
			if c is ProcWalker:
				_walker = c
		if _walker == null:
			return _frame > 10
		_lab.auto_drive = true
		DirAccess.make_dir_recursive_absolute(OUT)
		return false

	# 스크린샷은 그린 **다음** 프레임에 떠야 화면에 반영된 그림이 나온다
	if _shot_at == _frame:
		_save(MARKS[_mark][1])
		_mark += 1
		if _mark >= MARKS.size():
			print("--- 스크린샷 %d 장 저장: %s ---" % [MARKS.size(), ProjectSettings.globalize_path(OUT)])
			quit()
			return true
		_shot_at = -1

	_lab.auto_dir = 0.0 if _mark == 0 else 1.0
	# 공중 자세도 한 장 남긴다 — 다리를 접는지 확인
	if not _jumped and _walker.body_pos.x > 700.0:
		_jumped = true
		_walker.jump()

	if _shot_at < 0:
		var want: float = MARKS[_mark][0]
		if want < 0.0:
			if _frame > 30:
				_shot_at = _frame + 1
		elif _walker.body_pos.x >= want:
			_shot_at = _frame + 1

	if _frame > 6000:
		print("시간 초과 — %d 장까지 저장" % _mark)
		quit(1)
		return true
	return false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("  %s  (x=%.0f · y=%.0f · rot=%.3f)" % [
		name, _walker.body_pos.x, _walker.body_pos.y, _walker.rotation,
	])
