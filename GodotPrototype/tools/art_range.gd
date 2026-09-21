extends SceneTree
## **그림 조각이 감당해야 하는 변형 범위**를 잰다 (헤드리스).
##   godot --headless --path . --script res://tools/art_range.gd [-- preset=N]
##
## 원화를 잘라 파츠로 쓰려면, 걸음 중에 각 조각이 얼마나 돌고 얼마나 늘어나는지를 먼저 알아야 한다.
## 회전만 하면 그림을 그대로 돌려 쓸 수 있고, 길이가 변하면 슬리브+로드로 쪼개야 한다.
## 여기서 나오는 숫자가 "이 원화를 그대로 쓸 수 있는가" 의 답이다.
##
## 재는 것 (다리별 · 절대 부호 아니라 실제 범위):
##   허벅지 스트럿 길이 / 각 · 정강이 각 · 몸통 기울기 · 포신 각
const STEP := 1.0 / 60.0
const Lab := preload("res://scripts/walker_lab.gd")
const FRAMES := 2600

var _lab: Node2D
var _walker: ProcWalker
var _frame := 0
var _preset := 0
var _stat := {}          # 이름 → 표본 배열 (분위수를 보려면 전부 들고 있어야 한다)
var _air_frames := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("preset="):
			_preset = int(a.split("=")[1])
	_lab = Lab.new()
	root.add_child(_lab)
	_lab.auto_drive = true


func _note(name: String, v: float) -> void:
	if not _stat.has(name):
		_stat[name] = PackedFloat32Array()
	_stat[name].append(v)


func _process(_d: float) -> bool:
	_frame += 1
	if _walker == null:
		for c in _lab.get_children():
			if c is ProcWalker:
				_walker = c
		if _walker == null:
			return _frame > 10
		if _preset > 0:
			var key: int = KEY_0 + _preset
			if Lab.PRESETS.has(key):
				for k in (Lab.PRESETS[key] as Dictionary).keys():
					if k != "name":
						_walker.tune[k] = Lab.PRESETS[key][k]
		return false

	# 왕복: 지형 끝까지 갔다가 돌아온다 (경사·턱·울퉁불퉁·낭떠러지를 다 지난다)
	_lab.auto_dir = 1.0 if _frame < FRAMES * 0.55 else -1.0

	# **공중 프레임은 뺀다.** 뜬 동안엔 다리를 접어 두므로(허벅지 길이 ~0) 극단값이 전부 거기서 나와
	# "그림이 감당해야 하는 범위" 를 잘못 부풀린다. 착지·점프 연출은 따로 볼 문제다.
	if _walker.airborne:
		_air_frames += 1
		return false

	for leg in _walker._legs:
		var hip: Vector2 = _walker._hip_world(leg)
		var foot: Vector2 = leg["foot"]
		var knee := ProcWalker.solve_knee_v(hip, foot, _walker._phi0(leg))
		# **딛은 다리와 뜬 다리를 나눠 잰다.** 눈에 오래 남는 것은 딛은 자세이고,
		# 뜬 동안의 극단값(허벅지가 거의 다 접히는 순간)은 가려 두거나 로드로 처리할 문제다.
		var nm: String = "%s %s" % [leg["name"], "뜸" if leg["stepping"] else "딛음"]
		# 허벅지(유압 스트럿) — 길이와 각. 각은 **몸통 기준**이다 (그림을 몸에 붙여 돌리므로)
		_note("%s 허벅지 길이" % nm, hip.distance_to(knee))
		# 각은 스트럿이 **의미 있는 길이일 때만** 잰다. 무릎이 고관절에 거의 닿으면 각이 마구 튀어
		# (길이 3px 에서의 각) 통계가 전부 그 프레임에 끌려간다 — 처음 재보고 한 번 속았다.
		# 각은 **수직 위 방향 기준**으로 잰다. 이 로봇은 무릎이 고관절보다 **위**에 있는 거미 구조라
		# 스트럿이 위-바깥을 향한다 — 월드 각(0=앞)으로 재면 뒷다리가 ±180 경계에 걸려 통계가
		# 한 바퀴로 벌어진다 (처음 두 번 그렇게 찍혔다).
		if hip.distance_to(knee) > 60.0:
			var up := wrapf((knee - hip).angle() + PI * 0.5 - _walker.rotation, -PI, PI)
			_note("%s 허벅지 각(위기준)" % nm, rad_to_deg(up))
		_note("%s 무릎−고관절 높이" % nm, hip.y - knee.y)   # 양수 = 무릎이 위
		# 정강이 — 수직에서 벗어난 각 (그림을 그대로 돌려 쓸 수 있는지)
		_note("%s 정강이 각" % nm, rad_to_deg(wrapf((foot - knee).angle() - PI * 0.5, -PI, PI)))
	_note("몸통 기울기", rad_to_deg(_walker.rotation))

	if _frame > FRAMES:
		_report()
		quit()
		return true
	return false


func _report() -> void:
	print("--- 그림 조각이 감당해야 하는 범위 (프리셋 %s · %d프레임 왕복) ---" % [
		"기본" if _preset == 0 else str(_preset), FRAMES,
	])
	print("  (공중 %d프레임 제외)" % _air_frames)
	print("  %-20s %19s   %19s" % ["", "전체 최소~최대", "2~98% 구간"])
	for k in _stat.keys():
		var a: Array = Array(_stat[k])
		a.sort()
		var n := a.size()
		print("  %-20s %8.1f ~ %8.1f   %8.1f ~ %8.1f" % [
			k, a[0], a[n - 1], a[int(n * 0.02)], a[int(n * 0.98)],
		])
