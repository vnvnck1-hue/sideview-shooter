extends "res://scripts/main.gd"
## 규격 비교 테스트 씬 (scenes/ScaleLab.tscn) — 캐릭터가 직접 움직이며 문·통로·턱·상자·층고·프랍 후보 치수를 비교한다.
## 계획: Docs/SCALE_STANDARDIZATION_PLAN.md §2~3 · 씬 설명과 판정 기록: Docs/SCALE_TEST_SCENE.md
##
## 본편과 **같은 플레이 루프**(이동·조준·사격·구르기·줌·카메라)를 그대로 돌린다. 여기서 더하는 것은 세 가지뿐이다.
##   1. 세로 판정 — 본편에는 없다. 몸 높이(자세·규칙 G)가 천장 여유보다 크면 들어가지 못하고,
##      이미 아래에 있으면 웅크린 자세가 강제된다(웅크린 채로는 Player.CROUCH_SPEED 로 천천히 걸어 빠져나올 수 있다).
##   2. 턱 오르기 — 한계(T) 이하의 단차는 걸어 오르고, 높으면 벽이다. 내려서는 것은 언제나 된다.
##   3. 탄 차단 — 그레이박스 충돌 지형(회색)은 탄을 막는다. 통과 배경(파랑)·상호작용(주황)·전경(보라)은 막지 않는다.
## 적은 나오지 않는다. 방 데이터는 RoomData.extra 에 얹어 본 맵·지도·validate_map 을 건드리지 않는다.
##
## 조작:  [ ] 구역 이동 · , . 후보 이동 · G 세로 판정 규칙 · T 턱 오르기 한계 · N 충돌 끄기
##        H 라벨 전체/간단/끄기 · B 그레이박스 배경 ↔ 실제 타일 · F3 줌

const FALL_GRAVITY := 2600.0        # 턱에서 내려설 때 떨어지는 가속 (px/s²) — 모양만, 낙하 판정은 없다
const BASE_Y_SPEED := 5.0           # 카메라 세로 중심이 구역을 따라 옮겨 가는 속도

var rule_index := ScaleLabData.RULE_DEFAULT
var step_index := ScaleLabData.STEP_DEFAULT
var noclip := false
var view: ScaleLabView
var g := 0.0                        # 지금 발이 딛고 있는 높이 (바닥 위 px)
var _vy := 0.0
var _blocked := false               # 이번 프레임 앞이나 뒤가 막혀 있다
var _forced := false                # 머리 위가 낮아 웅크림이 강제됐다
var _base_y := 0.0
var _info: Array = []               # HUD 라벨 네 줄
var _hud_font: Font
var _post: Node


func _ready() -> void:
	ScaleLabData.register()
	AppFlow.start_room = ScaleLabData.ROOM_ID
	AppFlow.resume_x = ScaleLabData.spawn_x()
	AppFlow.resume_facing = 1
	super()
	# 그레이박스는 밝고 평평하게 본다 — 방 조명(어두운 앰비언트)·근경 실루엣을 끈다
	if current_room._ambient:
		current_room._ambient.color = Color.WHITE
	if current_room.foreground:
		current_room.foreground.visible = false
	current_room.disable_monsters()
	# 그림자·아이들·탄흔 프리셋 표시는 이 씬의 정보 줄과 겹친다 — 줌 표시만 남긴다
	for l in [shadow_label, dyn_shadow_label, idle_label, mark_label]:
		if l:
			l.visible = false

	view = ScaleLabView.new()
	view.name = "ScaleLabView"
	add_child(view)
	view.player = player
	view.setup(current_room)
	view.set_rules(_rule(), _step())

	# 이동 뒤 발 높이 맞추기 — 플레이어(0) 다음, 카메라(10) 전에 돈다
	_post = preload("res://scripts/scale_lab_feet.gd").new()
	_post.name = "ScaleLabFeet"
	_post.process_priority = 5
	_post.lab = self
	add_child(_post)

	_hud_font = SystemFont.new()
	_hud_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	var layer := get_node("UI") as CanvasLayer
	var colors := [Color(0.85, 0.9, 1.0), Color(1.0, 0.86, 0.55), Color(0.62, 1.0, 0.7), Color(0.7, 0.85, 0.95), Color(0.8, 0.8, 0.85)]
	for i in range(colors.size()):
		_info.append(_hud_line(layer, 58 + 28 * i, colors[i]))
	hint_label.text = "F1 로비    A/D 이동    마우스 조준 · 좌클릭 사격    Space 구르기    Ctrl 앉기(+A/D 앉아 걷기)    W/↑ 점프    [ ] 구역    , . 후보    G 세로 판정    T 턱 한계    N 충돌 끄기    H 라벨    B 타일 배경    F3 줌    F11 전체화면"

	_base_y = ScaleLabData.room_center_y(ScaleLabData.rows_at(player.position.x))
	_teleport(player.position.x)


func _hud_line(layer: CanvasLayer, y: float, color: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(24, y)
	l.size = Vector2(1600, 28)
	l.add_theme_font_override("font", _hud_font)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	layer.add_child(l)
	return l


func _rule() -> Dictionary:
	return ScaleLabData.RULES[rule_index]


func _step() -> float:
	return float(ScaleLabData.STEP_RULES[step_index])


# ── 세로 판정 ──────────────────────────────────────────────────────────────────

## 지금 자세의 몸 높이
func body_height() -> float:
	var r := _rule()
	var p: float = player.roll_progress()
	if p >= 0.0:
		return ScaleLabData.roll_height(r, p)
	if player.is_crouching():
		return float(r["crouch"])
	return float(r["stand"])


## 이동 전: 앞뒤로 막는 지형을 찾아 이동 한계를 정하고, 머리 위가 낮으면 웅크림을 강제한다
func _judge_before_move() -> void:
	var left := WALL_MARGIN
	var right := float(current_room.width) - WALL_MARGIN
	var px := player.position.x
	var h := body_height()
	var stand := float(_rule()["stand"])
	var need_crouch := false
	_blocked = false
	if not noclip:
		for it in ScaleLabData.items():
			var k: String = it["kind"]
			if k != "ground" and k != "overhead":
				continue
			var r: Rect2 = it["rect"]
			var blocks := false
			var inside := r.position.x < px + ScaleLabData.HALF_W - 2.0 and r.end.x > px - ScaleLabData.HALF_W + 2.0
			if k == "ground":
				blocks = (ScaleLabData.FLOOR - r.position.y) - g > _step() + 0.5
			else:
				var room := (ScaleLabData.FLOOR - r.end.y) - g
				blocks = room < h - 0.5
				if inside and room < stand - 0.5:
					need_crouch = true
			if not blocks or inside:
				continue
			if r.position.x >= px:
				right = minf(right, maxf(px, r.position.x - ScaleLabData.HALF_W))
			else:
				left = maxf(left, minf(px, r.end.x + ScaleLabData.HALF_W))
		_blocked = px >= right - 1.0 or px <= left + 1.0
	_forced = need_crouch and not player.is_rolling()
	player.force_crouch = _forced
	player.set_bounds(left, right)


## 이동 뒤 (ScaleLabFeet 가 부른다): 발을 딛는 높이로 맞춘다. 오르막은 즉시, 내리막은 떨어진다.
func settle_feet(delta: float) -> void:
	var want := 0.0 if noclip else ScaleLabData.ground_at(player.position.x)
	if want >= g:
		g = want
		_vy = 0.0
	else:
		_vy += FALL_GRAVITY * delta
		g = maxf(want, g - _vy * delta)
	player.position.y = current_room.floor_y + 2.0 - g
	view.update_judge({"h": body_height(), "blocked": _blocked, "forced": _forced})


func _teleport(x: float) -> void:
	if controlled_turret != null:
		controlled_turret.set_controlled(false)
	player.set_bounds(WALL_MARGIN, float(current_room.width) - WALL_MARGIN)
	player.position.x = clampf(x, WALL_MARGIN, float(current_room.width) - WALL_MARGIN)
	player.velocity_x = 0.0
	g = 0.0 if noclip else ScaleLabData.ground_at(player.position.x)
	_vy = 0.0
	player.position.y = current_room.floor_y + 2.0 - g
	player.face(1)
	_base_y = ScaleLabData.room_center_y(ScaleLabData.rows_at(player.position.x))
	camera.floor_y = NAN                  # 이 씬은 층고 구역마다 세로 중심을 스스로 잡는다 (바닥선 프레이밍 끔)
	camera.base_y = _base_y
	camera._apply_limits()
	camera.snap()


## 그레이박스 충돌 지형도 탄을 막는다 (본편 벽 클리핑보다 먼저)
func _spawn_shot(muzzle_pos: Vector2, target_pos: Vector2, power := 1.0, tracer := 1.0) -> void:
	super(muzzle_pos, ScaleLabData.clip_shot(muzzle_pos, target_pos), power, tracer)


# ── 루프 ────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if current_room != null and player != null and not transitioning:
		_judge_before_move()
		# 카메라 세로 중심 — 층고 구역에서는 그 층고의 방처럼 잡는다
		var want := ScaleLabData.room_center_y(ScaleLabData.rows_at(player.position.x))
		_base_y = lerpf(_base_y, want, 1.0 - exp(-BASE_Y_SPEED * delta))
		if not is_finite(camera.focus_x):
			camera.floor_y = NAN
			camera.base_y = _base_y
			camera._apply_limits()
	super(delta)
	_update_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	if transitioning or current_room == null or dialogue.active or terminal_screen.is_open():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var back := key.shift_pressed
	match key.keycode:
		KEY_BRACKETRIGHT, KEY_BRACKETLEFT:
			var zi := ScaleLabData.zone_at(player.position.x)
			zi = clampi(zi + (1 if key.keycode == KEY_BRACKETRIGHT else -1), 0, ScaleLabData.ZONES.size() - 1)
			_teleport(float(ScaleLabData.zone_spans()[zi][0]) + 300.0)
		KEY_PERIOD, KEY_COMMA:
			_jump_candidate(1 if key.keycode == KEY_PERIOD else -1)
		KEY_G:
			rule_index = wrapi(rule_index + (-1 if back else 1), 0, ScaleLabData.RULES.size())
			view.set_rules(_rule(), _step())
		KEY_T:
			step_index = wrapi(step_index + (-1 if back else 1), 0, ScaleLabData.STEP_RULES.size())
			view.set_rules(_rule(), _step())
		KEY_N:
			noclip = not noclip
			if not noclip:
				_teleport(player.position.x)
		KEY_H:
			view.set_label_mode((view.label_mode + 1) % 3)
		KEY_B:
			view.set_backdrop(not view.backdrop_on())
		_:
			return
	get_viewport().set_input_as_handled()


func _jump_candidate(step: int) -> void:
	var list := ScaleLabData.candidates()
	var px := player.position.x
	var target := -1
	if step > 0:
		for i in range(list.size()):
			if float(list[i]["stand_x"]) > px + 20.0:
				target = i
				break
	else:
		for i in range(list.size() - 1, -1, -1):
			if float(list[i]["stand_x"]) < px - 20.0:
				target = i
				break
	if target >= 0:
		_teleport(float(list[target]["stand_x"]))


## 플레이어 앞(바라보는 쪽)에서 가장 가까운 후보
func _nearest_candidate() -> Dictionary:
	var best := {}
	var bd := INF
	for it in ScaleLabData.candidates():
		var r: Rect2 = it["rect"]
		var d := absf(r.get_center().x - player.position.x)
		if d < bd:
			bd = d
			best = it
	return best if bd < 900.0 else {}


func _state_name() -> String:
	if player.is_rolling():
		return "구르기 %d%%" % int(player.roll_progress() * 100.0)
	if player.is_crouching():
		return "웅크림 (강제)" if _forced else "웅크림"
	return "서기·이동"


## 몸 위로 가장 가까운 천장 아랫면까지의 여유
func _headroom() -> float:
	var px := player.position.x
	var top := ScaleLabData.FLOOR - float(current_room.solid.open_top_at(px)) if current_room.solid else 9999.0
	for it in ScaleLabData.items():
		if it["kind"] != "overhead":
			continue
		var r: Rect2 = it["rect"]
		if r.position.x < px + ScaleLabData.HALF_W and r.end.x > px - ScaleLabData.HALF_W:
			top = minf(top, ScaleLabData.FLOOR - r.end.y)
	return top - g - body_height()


func _update_hud() -> void:
	if _info.is_empty() or player == null:
		return
	var zi := ScaleLabData.zone_at(player.position.x)
	var z: Dictionary = ScaleLabData.ZONES[zi]
	var r := _rule()
	_info[0].text = "%s  —  %s" % [z["name"], z["desc"]]
	_info[1].text = "세로 판정 (G)  %s: 서기 %d · 웅크림 %d · 구르기 %d%s    턱 오르기 한계 (T)  %d    충돌 (N)  %s" % [
		r["name"], int(r["stand"]), int(r["crouch"]), int(r["roll"]),
		"" if float(r["roll_edge"]) == float(r["roll"]) else " (시작·끝 %d)" % int(r["roll_edge"]),
		int(_step()), "끔 — 자유 이동" if noclip else "켬"]
	_info[2].text = "지금  %s · 몸 높이 %d · 발 높이 %d · 머리 위 여유 %+d · x %d%s" % [
		_state_name(), int(body_height()), int(g), int(_headroom()), int(player.position.x),
		"  · 막힘" if _blocked else ""]
	var px_scale := _base_px()
	var vis: Vector2 = _view_px() / (float(px_scale) / ART_CELL)
	var rows := ScaleLabData.rows_at(player.position.x)
	_info[3].text = "카메라  화면 배율 ×%d · 보이는 월드 %d × %d · 세로 중심 y %d (%d행 방) · 서기 267 = 화면 세로 %d%%" % [
		px_scale, int(vis.x), int(vis.y), int(camera.base_y), rows, int(round(ScaleLabData.STAND_H / vis.y * 100.0))]
	var c := _nearest_candidate()
	var txt := ""
	if not c.is_empty():
		txt = "가까운 후보  %s" % c.get("id", c["label"])
		if c["kind"] == "overhead":
			txt += "  →  " + ScaleLabData.pass_verdict(float(c["clear"]), float(c["length"]), r)["text"]
		elif c.has("cover"):
			txt += "  →  " + ScaleLabData.cover_verdict(float(c["cover"])).replace("\n", " · ")
		elif c.has("step"):
			txt += "  →  " + ScaleLabData.step_verdict(float(c["step"]), _step())["text"]
	_info[4].text = txt


func _set_world_hud(shown: bool) -> void:
	super(shown)
	for l in _info:
		l.visible = shown
