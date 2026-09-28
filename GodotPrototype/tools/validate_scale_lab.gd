extends SceneTree
## 규격 테스트 씬(ScaleLab) 실측 — 실제 플레이 루프에서 입력을 흉내 내 후보마다 통과 여부를 잰다.
## 실행:  godot --path . --headless --fixed-fps 60 --script res://tools/validate_scale_lab.gd
## 결과:  표준 출력 + Docs/SCALE_TEST_RESULTS.md (다시 돌리면 덮어쓴다)
##
## 재는 것
##   문·통로  규칙(G) 3종 × 후보 — ① 걸어서 2초 ② 구르기 반복(최대 8회). 몸 전체가 반대편으로 나가면 통과.
##            분석값(D.pass_verdict)과 실측이 어긋나면 오류로 센다.
##   턱·계단  한계(T) 4종 × 후보 — 걸어서 3초 뒤 반대편에 있는가.
##   엄폐 상자  서서/웅크려 수평 사격이 상자에 막히는가 (D.clip_shot)
##   탄 차단 · 배경 통과 · 웅크림 강제 같은 규칙 자체의 확인

const FPS := 60
const WALK_FRAMES := 120
const STEP_FRAMES := 180
const ROLL_GAP := 22                 # 구르기 사이 프레임 (구르기 18프레임 + 여유)
const MAX_ROLLS := 8

var lab: Node
## ScaleLabData — Player(→ 오토로드 Audio)에 기대므로 컴파일 시점이 아니라 씬이 뜬 뒤에 불러온다
var D
var _jobs: Array = []
var _job: Dictionary = {}
var _f := 0
var _rolls := 0
var _results: Array = []
var _errors: Array = []
var _started := false
var _wait := 0


func _initialize() -> void:
	change_scene_to_file("res://scenes/ScaleLab.tscn")


func _process(_delta: float) -> bool:
	if not _started:
		_wait += 1
		if _wait < 10:
			return false
		lab = current_scene
		if lab == null or lab.get("player") == null:
			return false
		_started = true
		D = load("res://scripts/scale_lab_data.gd")
		_plan()
		_static_checks()
	return _tick()


func _plan() -> void:
	for ri in range(D.RULES.size()):
		for it in D.candidates():
			if it["kind"] == "overhead":
				_jobs.append({"type": "walk", "rule": ri, "item": it})
				_jobs.append({"type": "roll", "rule": ri, "item": it})
	for si in range(D.STEP_RULES.size()):
		for it in D.candidates():
			if it["kind"] == "ground":
				_jobs.append({"type": "step", "step": si, "item": it})


func _begin(job: Dictionary) -> void:
	_job = job
	_f = 0
	_rolls = 0
	Input.action_release("move_right")
	Input.action_release("crouch")
	lab.rule_index = int(job.get("rule", D.RULE_DEFAULT))
	lab.step_index = int(job.get("step", D.STEP_DEFAULT))
	lab.noclip = false
	lab.player.force_crouch = false
	lab.player.state = 0
	lab._teleport(float(job["item"]["stand_x"]))
	Input.action_press("move_right")


func _tick() -> bool:
	if _job.is_empty():
		if _jobs.is_empty():
			_finish()
			return true
		_begin(_jobs.pop_front())
		return false
	_f += 1
	var it: Dictionary = _job["item"]
	var r: Rect2 = it["rect"]
	var px: float = lab.player.position.x
	var passed: bool = px - D.HALF_W > r.end.x + 1.0
	match _job["type"]:
		"walk":
			if passed or _f >= WALK_FRAMES:
				_record(passed, 0)
		"roll":
			if passed:
				_record(true, _rolls)
			elif _f % ROLL_GAP == 1 and not lab.player.is_rolling():
				if _rolls >= MAX_ROLLS:
					_record(false, _rolls)
				else:
					lab.player._start_roll(1)
					_rolls += 1
			elif _f > ROLL_GAP * (MAX_ROLLS + 2):
				_record(false, _rolls)
		"step":
			if passed or _f >= STEP_FRAMES:
				_record(passed, 0)
	return false


func _record(passed: bool, rolls: int) -> void:
	var j := _job
	j["passed"] = passed
	j["rolls"] = rolls
	j["x"] = lab.player.position.x
	_results.append(j)
	_job = {}
	Input.action_release("move_right")


# ── 정적 확인 ────────────────────────────────────────────────────────────────

func _static_checks() -> void:
	# 1. 엄폐 상자 — 서서/웅크려 수평 사격
	for it in D.candidates():
		if not it.has("cover"):
			continue
		var r: Rect2 = it["rect"]
		var x0: float = float(it["stand_x"]) + 122.0
		for m in [D.MUZZLE_STAND, D.MUZZLE_CROUCH]:
			var y: float = D.FLOOR - float(m)
			var hit: Vector2 = D.clip_shot(Vector2(x0, y), Vector2(x0 + 900.0, y))
			var blocked: bool = hit.x < r.end.x
			var want: bool = float(it["cover"]) >= float(m)
			it["shot_%d" % int(m)] = blocked
			if blocked != want:
				_errors.append("엄폐 %s: 총구 %d 사격이 %s" % [it["id"], int(m), "막혔다" if blocked else "넘어갔다"])
	# 2. 통과 배경·상호작용·전경은 탄을 막지 않는다
	for it in D.items():
		if it["kind"] in ["backdrop", "interact", "occluder"]:
			var r2: Rect2 = it["rect"]
			var y2: float = r2.get_center().y
			var a := Vector2(r2.position.x - 50.0, y2)
			var b := Vector2(r2.end.x + 50.0, y2)
			if D.clip_shot(a, b) != b:
				_errors.append("통과 프랍 %s 이 탄을 막는다" % it["id"])
	# 3. 문 인방은 막는다 — 문 위쪽으로 쏘면 벽에 걸린다
	for it in D.candidates():
		if it["kind"] == "overhead" and str(it["id"]).begins_with("D"):
			var r3: Rect2 = it["rect"]
			var y3: float = r3.end.y - 20.0
			var hit3: Vector2 = D.clip_shot(Vector2(r3.position.x - 200.0, y3), Vector2(r3.end.x + 200.0, y3))
			if absf(hit3.x - r3.position.x) > 1.0:
				_errors.append("문 %s 인방이 탄을 막지 않는다" % it["id"])
	# 4. 후보 사이 간격 — 선 자리가 옆 지형과 겹치지 않는다
	for it in D.candidates():
		var sx: float = float(it["stand_x"])
		for o in D.items():
			if o["kind"] != "ground" and o["kind"] != "overhead":
				continue
			var ro: Rect2 = o["rect"]
			if sx + D.HALF_W > ro.position.x and sx - D.HALF_W < ro.end.x and o["kind"] == "overhead" and D.FLOOR - ro.end.y < D.IDLE_MAX:
				_errors.append("후보 %s 의 선 자리(x %d)가 낮은 천장 아래" % [it["id"], int(sx)])


# ── 결과 ────────────────────────────────────────────────────────────────────

func _finish() -> void:
	Input.action_release("move_right")
	var md: Array = []
	md.append("# 규격 테스트 씬 실측 결과")
	md.append("")
	md.append("`tools/validate_scale_lab.gd` 가 자동으로 만든 문서다. 손으로 고치지 말고 툴을 다시 돌린다.")
	md.append("")
	md.append("- 실행: `godot --path . --headless --fixed-fps 60 --script res://tools/validate_scale_lab.gd`")
	md.append("- 방식: 실제 ScaleLab 플레이 루프에서 오른쪽 이동 입력을 넣고, 구르기는 %d프레임마다 다시 누른다 (최대 %d회)." % [ROLL_GAP, MAX_ROLLS])
	md.append("- 통과 = 판정 상자(폭 %d) 전체가 지형 반대편으로 나감. 수치는 모두 **후보**다." % int(D.HALF_W * 2.0))
	md.append("- 해석과 채택 여부: [`SCALE_TEST_SCENE.md`](SCALE_TEST_SCENE.md)")
	md.append("")

	md.append("## 1. 문·낮은 통로 — 세로 판정 규칙별")
	md.append("")
	var head := "| 후보 | 여유 | 길이 |"
	var sep := "|---|---|---|"
	for r in D.RULES:
		head += " %s |" % r["name"]
		sep += "---|"
	md.append(head)
	md.append(sep)
	for it in D.candidates():
		if it["kind"] != "overhead":
			continue
		var row := "| %s | %d | %d |" % [it["id"], int(it["clear"]), int(it["length"])]
		for ri in range(D.RULES.size()):
			var walk := _find("walk", ri, it)
			var roll := _find("roll", ri, it)
			var cell := ""
			if walk.get("passed", false):
				cell = "서서 통과"
			elif roll.get("passed", false):
				cell = "구르기 %d회" % int(roll["rolls"])
			else:
				cell = "불가"
			# 분석값과 대조
			var v: Dictionary = D.pass_verdict(float(it["clear"]), float(it["length"]), D.RULES[ri])
			var actual := "stand" if walk.get("passed", false) else ("roll" if roll.get("passed", false) else "none")
			if actual != v["verdict"]:
				_errors.append("%s · %s: 분석 %s ↔ 실측 %s" % [it["id"], D.RULES[ri]["name"], v["verdict"], actual])
				cell += " ⚠"
			row += " %s |" % cell
		md.append(row)
	md.append("")
	md.append("구르기 횟수는 후보의 선 자리(문 앞 240 · 통로 앞 300)에서 출발했을 때의 실측이다. 한 번에 빠질 수 있는 통로 길이 한계(이론값): " + ", ".join(D.RULES.map(func(r): return "%s %d" % [r["name"], int(D.roll_one_pass_length(r))])) + ".")
	md.append("")
	md.append("규칙: " + " · ".join(D.RULES.map(func(r): return "**%s** 서기 %d / 웅크림 %d / 구르기 %d%s" % [
		r["name"], int(r["stand"]), int(r["crouch"]), int(r["roll"]),
		"" if float(r["roll_edge"]) == float(r["roll"]) else " (시작·끝 %d)" % int(r["roll_edge"])])))
	md.append("")

	md.append("## 2. 턱·계단 — 턱 오르기 한계별 (걸어서 3초)")
	md.append("")
	var head2 := "| 후보 | 단 높이 |"
	var sep2 := "|---|---|"
	for s in D.STEP_RULES:
		head2 += " 한계 %d |" % int(s)
		sep2 += "---|"
	md.append(head2)
	md.append(sep2)
	for it in D.candidates():
		if it["kind"] != "ground":
			continue
		var row2 := "| %s | %d |" % [it["id"], int(it["step"])]
		for si in range(D.STEP_RULES.size()):
			var st := _find("step", si, it)
			var ok: bool = st.get("passed", false)
			var want: bool = float(it["step"]) <= float(D.STEP_RULES[si])
			var cell2 := "통과" if ok else "막힘"
			if ok != want:
				_errors.append("%s · 한계 %d: 기대 %s ↔ 실측 %s" % [it["id"], int(D.STEP_RULES[si]), want, ok])
				cell2 += " ⚠"
			row2 += " %s |" % cell2
		md.append(row2)
	md.append("")

	md.append("## 3. 엄폐 상자 — 수평 사격")
	md.append("")
	md.append("| 후보 | 높이 | 서서 (총구 160) | 웅크려 (총구 94) | 웅크린 몸 가림 | 선 몸 가림 |")
	md.append("|---|---|---|---|---|---|")
	for it in D.candidates():
		if not it.has("cover"):
			continue
		var h: float = float(it["cover"])
		md.append("| %s | %d | %s | %s | %d%% | %d%% |" % [it["id"], int(h),
			"막힘" if it.get("shot_160", false) else "넘김", "막힘" if it.get("shot_94", false) else "넘김",
			int(minf(h / D.CROUCH_H, 1.0) * 100.0), int(minf(h / D.STAND_H, 1.0) * 100.0)])
	md.append("")

	md.append("## 4. 확인 결과")
	md.append("")
	if _errors.is_empty():
		md.append("- 오류 없음 — 분석 판정과 실측이 모두 일치하고, 탄 차단·배경 통과 규칙이 지켜진다.")
	else:
		for e in _errors:
			md.append("- ⚠ " + e)
	md.append("")

	var text := "\n".join(md)
	print(text)
	var out := ProjectSettings.globalize_path("res://").path_join("../Docs/SCALE_TEST_RESULTS.md").simplify_path()
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
		print("\n→ %s" % out)
	print("오류 %d건" % _errors.size())
	quit(1 if not _errors.is_empty() else 0)


func _find(type: String, idx: int, it: Dictionary) -> Dictionary:
	for r in _results:
		if r["type"] != type or r["item"] != it:
			continue
		if type == "step" and int(r["step"]) == idx:
			return r
		if type != "step" and int(r["rule"]) == idx:
			return r
	return {}
