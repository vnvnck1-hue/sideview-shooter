extends "res://scripts/main.gd"
## 공간 테스트 씬 (scenes/SpaceLab.tscn) — "이 스테이션은 얼마나 넓게 느껴지는가" 만 보는 랩.
##
## 본편과 **같은 플레이 루프**(이동·조준·사격·구르기·센트리건·보행 기체)를 그대로 돌리고,
## 방만 SpaceLabData 가 만든 20,000px 짜리 한 줄로 바꾼다. 방 데이터는 RoomData.extra 에 얹으므로
## 본 맵(RoomData.ROOMS)·지도·탐색 카운트·tools/validate_map.gd 는 전혀 건드리지 않는다.
##
## 보는 것
##   - 기본 배경 타일(workshop)로 세울 수 있는 가장 큰 방의 체감 크기 (천장 9셀 = 1,152px)
##   - 좌우로 계속 걷는 이동감 — 끝에서 끝까지 20,000px
##   - **이어지는 방식 두 가지를 나란히**
##       · 그냥 뚫린 통로 — 처음부터 양옆 방이 같이 보인다
##       · **구역 문(SectionGate)** — 닫혀 있는 동안 그 너머가 전혀 안 보이다가, 열면 페이드 없이
##         저쪽 구역이 이쪽과 한 화면에 이어진다. 방을 갈아 끼우지 않으므로 지나온 방이 사라지지 않는다.
##   - 그 공간 안의 몬스터(웨이브)·센트리건·보행 기체·프랍·조명이 넓이에 눌리지 않는지
##
## 조작은 본편과 같고, 여기만:  [ ] 열린 구획 사이 건너뛰기 · W/↑ 로 구역 문 열기

## 시작 줌은 본편과 같은 기본값(Main.ZOOM_DEFAULT, 표준 ×3)을 쓴다 (2026-09-23). 예전엔 넓이를 본다고
## ×2 로 덮어써서 이 씬만 화면이 달랐다 — 넓게 보고 싶으면 F3 으로 바꾼다.
const GATE_STOP_PAD := 40.0   # 닫힌 문 앞에서 플레이어가 멈추는 여유

var space_label: Label
var wave_label: Label
var _hud_font: Font
var _spans: Array = []
var _gates: Array = []        # SectionGate — 왼쪽부터
var _streamer: RoomStreamer


func _ready() -> void:
	# 방 데이터는 super() 의 _load_room 보다 **먼저** 올라가야 한다
	SpaceLabData.register()
	AppFlow.start_room = SpaceLabData.ROOM_ID
	super()
	_spans = SpaceLabData.spans()
	_build_gates()
	_build_streamer()
	_apply_player_bounds()

	_hud_font = SystemFont.new()
	_hud_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	var layer := get_node("UI") as CanvasLayer
	# 우상단은 줌·그림자·아이들 라벨이 이미 세 줄 쓰고 있다. 이 라벨들은 제목 아래(좌상단)에 둔다.
	space_label = _hud_line(layer, 58, Color(0.85, 0.9, 1.0))
	wave_label = _hud_line(layer, 86, Color(1.0, 0.78, 0.55))

	hint_label.text = "F1 로비    A/D 이동    마우스 조준 · 좌클릭 사격    Space 구르기    Ctrl 앉기    W/↑ 센트리건·보행 기체 조종 · 구역 문 열기    R 재장전    [ ] 구획 건너뛰기    F3 줌    F11 전체화면"


func _hud_line(layer: CanvasLayer, y: float, color: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(24, y)
	l.size = Vector2(1400, 30)
	l.add_theme_font_override("font", _hud_font)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	layer.add_child(l)
	return l


# ── 구역 문 ──────────────────────────────────────────────────────────────────────

## 닫힌 문과 그 너머를 덮는 장막을 세운다. 저쪽 구역은 **이미 지어져 있고** 장막에 가려져 있을 뿐이다.
func _build_gates() -> void:
	var rect := RoomData.room_rect(SpaceLabData.ROOM_ID)
	for i in SpaceLabData.gate_indices():
		var reveal: Array = SpaceLabData.gate_reveal(i)
		var gate := SectionGate.new()
		gate.name = "SectionGate_%d" % i
		current_room.add_child(gate)
		gate.setup(SpaceLabData.gate_x(i), current_room.floor_y,
			Rect2(float(reveal[0]), rect.position.y, float(reveal[1]) - float(reveal[0]), rect.size.y),
			SpaceLabData.next_room_name(i))
		gate.opened.connect(_on_gate_opened)
		_gates.append(gate)
	_sync_sections()


## 닫힌 문 = 방을 자르는 벽. 몬스터는 자기 구역 밖으로 못 나가고, 지속 스폰도 플레이어 구역 안에서만 나온다.
func _sync_sections() -> void:
	var walls: Array = []
	for g in _gates:
		if not g.is_open:
			walls.append(g.gate_x)
	current_room.section_walls = walls
	current_room.refresh_sections()


func _on_gate_opened(_gate: SectionGate) -> void:
	_sync_sections()
	_apply_player_bounds()


## 플레이어는 닫힌 문 앞에서 멈춘다 (문 너머는 아직 "없는" 공간이다)
func _apply_player_bounds() -> void:
	var right := float(current_room.width) - WALL_MARGIN
	for g in _gates:
		if not g.is_open:
			right = minf(right, g.stop_x() - GATE_STOP_PAD)
	player.set_bounds(WALL_MARGIN, maxf(WALL_MARGIN + 100.0, right))


## 플레이어가 지금 열 수 있는 문 (없으면 null)
func _gate_near() -> SectionGate:
	for g in _gates:
		if g.can_interact(player.position.x):
			return g
	return null


# ── 멀리 있는 연출은 돌리지 않는다 ──────────────────────────────────────────────

func _build_streamer() -> void:
	_streamer = RoomStreamer.new()
	_streamer.name = "RoomStreamer"
	add_child(_streamer)
	_streamer.setup(current_room, camera)


# ── 루프 ────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	super(delta)
	_update_labels()
	# 구역 문 안내는 다른 안내(센트리건·보행 기체)보다 뒤에 온다 — 같은 W/↑ 라도 옆에 기계가 있으면 그쪽이 먼저다.
	if not prompt_label.visible:
		var g := _gate_near()
		if g != null:
			prompt_label.visible = true
			prompt_label.text = g.prompt_text()


## W/↑ — 옆에 기계가 없으면 구역 문을 연다 (main 의 정면문 처리 앞에 끼워 넣는다)
func _on_front_door_requested() -> void:
	if transitioning or current_room == null:
		return
	if current_room.sentry_near(player.position.x) == null and current_room.walker_near(player.position.x) == null:
		var g := _gate_near()
		if g != null:
			g.activate()
			return
	super()


## [ ] — 이전·다음 구획의 가운데로 건너뛴다. **닫힌 문은 넘지 않는다.**
func _unhandled_key_input(event: InputEvent) -> void:
	if transitioning or current_room == null or dialogue.active or terminal_screen.is_open():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var step := 0
	if key.keycode == KEY_BRACKETRIGHT:
		step = 1
	elif key.keycode == KEY_BRACKETLEFT:
		step = -1
	if step == 0:
		return
	if controlled_turret != null:
		controlled_turret.set_controlled(false)
	var i := clampi(_chamber_index(player.position.x) + step, 0, _spans.size() - 1)
	var target := (float(_spans[i][0]) + float(_spans[i][1])) * 0.5
	var limit := float(current_room.width)
	for g in _gates:
		if not g.is_open:
			limit = minf(limit, g.stop_x() - GATE_STOP_PAD)
	player.position.x = clampf(target, WALL_MARGIN, maxf(WALL_MARGIN + 100.0, limit))
	player.face(step)
	camera.snap()
	get_viewport().set_input_as_handled()


func _chamber_index(x: float) -> int:
	for i in range(_spans.size()):
		if x < float(_spans[i][1]):
			return i
	return _spans.size() - 1


func _update_labels() -> void:
	if space_label == null or current_room == null:
		return
	var i := _chamber_index(player.position.x)
	var ch: Dictionary = SpaceLabData.CHAMBERS[i]
	# Dictionary.get() 은 Variant 를 돌려준다 — := 로 받으면 추론 경고가 오류로 잡혀 스크립트가 안 뜬다
	var kind: String = {"room": "방", "link": "통로", "gate": "봉쇄 통로"}.get(ch["kind"], "구획")
	var head := float(current_room.ceiling_at(player.position.x))
	space_label.text = "%s (%s %d/%d)  ·  천장 %dpx  ·  x %d / %d  ·  돌아가는 연출 %d" % [
		ch["name"], kind, i + 1, _spans.size(), int(current_room.floor_y - head),
		int(player.position.x), current_room.width,
		_streamer.awake_count() if _streamer else 0]

	var closed := 0
	for g in _gates:
		if not g.is_open:
			closed += 1
	var left := current_room.wave_countdown()
	var wave_txt := "쏟아지는 중 (%d 남음)" % current_room.wave_pending() if left < 0.0 else "다음 웨이브 %0.0f초" % left
	# 몬스터 수는 **이 구역** 기준이다 — 스폰 상한을 재는 값과 같은 것을 보여 줘야 HUD 가 거짓말을 하지 않는다
	wave_label.text = "웨이브 %d  ·  %s  ·  몬스터 %d / %d (방 전체 %d)  ·  닫힌 문 %d" % [
		current_room.wave_index, wave_txt,
		current_room.alive_in_section(player.position.x), current_room.spawn_cap(),
		current_room.alive_monsters(), closed]


## 단말기 화면이 시야를 채우는 동안은 이 라벨들도 같이 숨는다 (main_game.gd 와 같은 규칙)
func _set_world_hud(shown: bool) -> void:
	super(shown)
	if space_label:
		space_label.visible = shown
	if wave_label:
		wave_label.visible = shown
