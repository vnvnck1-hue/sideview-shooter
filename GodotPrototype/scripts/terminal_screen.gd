class_name TerminalScreen
extends CanvasLayer
## 단말기에 접속했을 때 시야를 채우는 CRT 화면 UI.
##
## 이 노드는 **화면 안**만 담당한다 — 카메라 밀어넣기 · 원격 방 교체 · 포탑 조종은 Main 이 한다.
## 화면 밖 연출(프리셋 교체 · 전원 인가/차단 · 채널 전환 글리치)은 CrtFx(scripts/crt_overlay.gd) 에 맡긴다.
##
## 화면 색은 일부러 **거의 무채색**으로 그린다 — CRT 프리셋이 saturation 0 + tint 로 단색 형광을 입히므로,
## 같은 UI 가 green 프리셋에서는 녹색 터미널로, amber 프리셋에서는 호박색 터미널로 그대로 바뀐다.
##
## 상태 흐름 (컨셉: Docs/TERMINAL_SYSTEM_CONCEPT.md §2)
##   BOOT → MENU ┬─ LOGS → LOG        기록 열람
##               ├─ REWIRE            배전 (전력 3유닛 배분)
##               ├─ SAVE              카드 삽입 연출
##               ├─ MAP               구역 지도 (survey — 스테이션 개략도 판독)
##               └─ GRID → (링크) → REMOTE   방어 그리드 → 센트리건 원격 조종
##
## MAP·GRID 는 글자가 아니라 **지도**(StationMap)를 그린다. 두 상태는 같은 지도를 쓰고
## 커서가 무엇 위를 도는지만 다르다 — MAP 은 방, GRID 는 관할 포탑. 자세한 것은 Docs/STATION_MAP.md.
##   REMOTE 에서는 얇은 머리글/꼬리글만 남기고 화면 가운데를 비운다 (월드가 보여야 한다).

signal link_requested(sentry: Dictionary)   ## 방어 그리드에서 포탑을 골랐다 — Main 이 원격 방으로 넘어간다
signal unlink_requested()                    ## 원격 조종 중 ESC — 그리드 목록으로 돌아간다
signal close_requested()                     ## 루트 메뉴에서 ESC — 접속 종료

enum State { CLOSED, BOOT, MENU, LOGS, LOG, REWIRE, SAVE, MAP, GRID, REMOTE }

const LAYER := 12
const SCREEN := Vector2(AppFlow.VIEW_SIZE)   # 디자인 캔버스 (창 좌표계)
const MARGIN := Vector2(112.0, 74.0)        # 화면 위아래 여백. 가로 여백은 PANEL_W 가 대신 정한다
## 본문 폭은 캔버스가 넓어져도 1376 으로 묶고 가운데 정렬한다 — 2240 을 꽉 채우면 글줄이 너무 길어 읽기 나쁘다.
const PANEL_W := 1376.0
const PANEL_X := (SCREEN.x - PANEL_W) * 0.5
const PLATE_ALPHA := 0.94
const BOOT_LINE_TIME := 0.055               # 부팅 한 줄당
const TYPE_SPEED := 90.0                    # 본문 타이핑 (글자/초)
const CURSOR_BLINK := 0.5

## 목록 한 줄은 제목 + 설명 + 빈 줄 = 3행(117px). 본문은 y 138~758 이고 머리말이 3행을 먹으므로 4줄이 한계다.
## 그보다 길면 선택한 줄 주위로 창을 잘라 보여 주고 위아래에 남은 개수를 표시한다.
const MAX_ROWS := 4

const TEXT := Color(0.86, 0.89, 0.86)
const DIM := Color(0.46, 0.50, 0.47)
const BRIGHT := Color(1.0, 1.0, 1.0)
const LOCKED := Color(0.34, 0.36, 0.34)

var state: State = State.CLOSED
## 접속한 단말기의 **사본**을 들고 있는다 — 원격 조종으로 넘어가면 월드가 다른 방으로 교체되면서
## AccessTerminal 노드가 사라지기 때문이다. 화면이 노드를 붙들고 있으면 그 순간 무효 참조가 된다.
var terminal_id := ""
var terminal_room := ""
var role_id := "link"
var role: Dictionary = TerminalData.ROLES["link"]
var data: Dictionary = {}

var _plate: ColorRect
var _map: StationMap                        # MAP·GRID 상태에서 본문 자리에 그려지는 개략도
var _head: RichTextLabel
var _body: RichTextLabel
var _foot: RichTextLabel
var _rule_top: ColorRect
var _rule_bottom: ColorRect
var _font: Font

var _rows: Array = []                       # 지금 화면의 선택 가능한 줄 [{"label", "note", "enabled", "act"}]
var _sel := 0
var _boot_lines: PackedStringArray = []
var _boot_shown := 0
var _boot_t := 0.0
var _cursor_t := 0.0
var _cursor_on := true
var _type_t := 0.0                          # 본문 타이핑 진행 (0..1 은 visible_ratio 로)
var _typing := false
var _power: Dictionary = {}                 # rewire 회로 on/off
var _grid: Array = []                       # 방어 그리드 목록 (TerminalData.grid_entries)
var _remote: Dictionary = {}                # 지금 원격 조종 중인 포탑 항목
var _remote_heat := 0.0
var _remote_overheated := false
var _status := ""                           # 화면 아래 한 줄 알림 (저장 완료 등)
var _status_t := 0.0
## 전역 CRT 오버레이(autoload "CrtFx")를 **노드로** 잡아 둔다.
## 자동 로드 이름을 코드에 그대로 쓰면 커스텀 MainLoop 로 도는 --script 도구(tools/*_shot.gd)에서
## 컴파일 단계에 이름이 풀리지 않아 Main 전체가 로드되지 않는다. 그래서 여기서만 한 번 찾아 쓴다.
var _crt: Node


func _ready() -> void:
	layer = LAYER
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crt = get_tree().root.get_node_or_null("CrtFx")
	if _crt == null:
		push_warning("CrtFx 자동 로드를 찾지 못했습니다 — 단말기 화면이 CRT 없이 그려집니다")

	# 등폭 글꼴 — 없으면 시스템 한글 글꼴로 떨어진다 (목록 정렬이 조금 흐트러질 뿐 읽기에는 문제없다)
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Consolas", "D2Coding", "NanumGothicCoding", "Courier New", "Malgun Gothic", "맑은 고딕"])
	_font = f

	_plate = ColorRect.new()
	_plate.name = "Plate"
	_plate.color = Color(0.015, 0.03, 0.02, 0.0)
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)

	# 지도는 본문(_body) 의 캡션 두 줄 아래에 얹는다 — 글자는 _body 가, 그림은 StationMap 이 그린다
	_map = StationMap.new()
	_map.name = "StationMap"
	_map.visible = false
	_map.position = Vector2(PANEL_X, MARGIN.y + 162.0)
	_map.size = Vector2(PANEL_W, SCREEN.y - MARGIN.y * 2.0 - 236.0)
	add_child(_map)

	_head = _make_label(MARGIN.y, 40.0, 24)
	_rule_top = _make_rule(MARGIN.y + 44.0)
	_body = _make_label(MARGIN.y + 64.0, SCREEN.y - MARGIN.y * 2.0 - 132.0, 24)
	_rule_bottom = _make_rule(SCREEN.y - MARGIN.y - 40.0)
	_foot = _make_label(SCREEN.y - MARGIN.y - 30.0, 34.0, 20)
	_foot.add_theme_color_override("default_color", DIM)


func _make_label(y: float, h: float, size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.fit_content = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(PANEL_X, y)
	r.size = Vector2(PANEL_W, h)
	r.add_theme_font_override("normal_font", _font)
	r.add_theme_font_override("bold_font", _font)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_constant_override("line_separation", 8)
	r.add_theme_color_override("default_color", TEXT)
	add_child(r)
	return r


func _make_rule(y: float) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.55, 0.6, 0.55, 0.5)
	c.position = Vector2(PANEL_X, y)
	c.size = Vector2(PANEL_W, 2.0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


# ── 열기 / 닫기 ──────────────────────────────────────────────────────────────

## 접속 시작. CRT 프리셋 교체 · 전원 인가 연출까지 여기서 건다 (카메라는 Main 이 이미 밀어 넣는 중).
func open(t: AccessTerminal, room_id: String) -> void:
	terminal_id = t.terminal_id
	terminal_room = room_id
	role_id = t.role_id
	role = t.role
	data = t.data
	_power = {}
	for c in TerminalData.CIRCUITS:
		_power[c["id"]] = false
	_status = ""
	_status_t = 0.0
	visible = true
	_set_plate(PLATE_ALPHA, 0.22)
	if _crt != null:
		_crt.push_preset(str(role["crt"]))
		_crt.power_on()
	_start_boot()


## 채널 전환 글리치. Main 이 원격 방을 갈아 끼울 때 쓴다 (on_switch 가 가장 어지러운 순간에 불린다).
## CRT 오버레이가 없으면 연출 없이 즉시 전환한다.
func glitch(on_switch: Callable) -> void:
	if _crt == null:
		if on_switch.is_valid():
			on_switch.call()
		return
	_crt.channel_glitch(on_switch)


## 접속 종료 연출 — 전원 차단 뒤 스스로 숨는다. 끝나면 done 을 부른다.
func close(done: Callable = Callable()) -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	_rows = []
	_map.visible = false
	var off_time := 0.26
	if _crt != null:
		off_time = float(_crt.POWER_OFF_TIME)
		_crt.power_off()
	_set_plate(0.0, off_time * 0.8)
	var tw := create_tween()
	tw.tween_interval(off_time)
	tw.tween_callback(func():
		visible = false
		if _crt != null:
			_crt.pop_preset()
			_crt.set_fx(0.0, 0.0, 0.0)
		if done.is_valid():
			done.call())


func is_open() -> bool:
	return state != State.CLOSED


func in_remote() -> bool:
	return state == State.REMOTE


## 연출 없이 즉시 끊는다 (F1 로비 등 씬을 떠날 때). 프리셋을 되돌리지 않으면 로비까지 녹색으로 남는다.
func force_close() -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	_rows = []
	_map.visible = false
	visible = false
	_plate.color.a = 0.0
	if _crt != null:
		_crt.pop_preset()
		_crt.set_fx(0.0, 0.0, 0.0)


func _set_plate(alpha: float, time: float) -> void:
	create_tween().tween_property(_plate, "color:a", alpha, time)


# ── 부팅 ─────────────────────────────────────────────────────────────────────

func _start_boot() -> void:
	state = State.BOOT
	var title := str(data.get("title", role["name"]))
	var callsign := str(data.get("callsign", "SEV-000"))
	_boot_lines = PackedStringArray([
		"SEVASTOPOL STATION  ·  ONBOARD SYSTEMS",
		"",
		"  링크 확립 …… [b]확인[/b]",
		"  단말 식별 …… [b]%s[/b]" % callsign,
		"  계통 점검 …… [b]%s[/b]" % role["short"],
		"  권한 확인 …… [b]승인[/b]",
		"",
		"[color=#ffffff]%s[/color]" % role["boot"],
		"",
		"  %s" % title,
	])
	_boot_shown = 0
	_boot_t = 0.0
	# 타이핑 중이던 페이지(로그 본문·저장 연출)에서 접속을 끊으면 이 깃발이 남는다 —
	# 그대로 두면 다음 단말기의 첫 ENTER 가 "타이핑 건너뛰기" 로 먹힌다.
	_typing = false
	_head.text = ""
	_foot.text = ""
	_rule_top.visible = false
	_rule_bottom.visible = false
	_body.text = ""
	_body.visible_ratio = 1.0


func _tick_boot(delta: float) -> void:
	_boot_t += delta
	while _boot_shown < _boot_lines.size() and _boot_t >= BOOT_LINE_TIME:
		_boot_t -= BOOT_LINE_TIME
		_boot_shown += 1
		_body.text = "\n".join(_boot_lines.slice(0, _boot_shown))
	if _boot_shown >= _boot_lines.size() and _boot_t > 0.35:
		_open_menu()


# ── 루트 메뉴 ────────────────────────────────────────────────────────────────

func _open_menu() -> void:
	state = State.MENU
	_rows = []
	match role_id:
		"link":
			_rows.append(_row("기록 열람", "음성 로그 · 수신 메일 %d건" % _logs().size(), true, "logs"))
			_rows.append(_row("격벽 · 환기구 개방", "이 단말에서 여는 문이 없습니다", false, ""))
		"security":
			_grid = TerminalData.grid_entries(terminal_id, terminal_room)
			var n := 0
			for e in _grid:
				if e["authorized"]:
					n += 1
			_rows.append(_row("방어 그리드", "구역 지도에서 선택 — 관할 %d기 / 탐지 %d기" % [n, _grid.size()], n > 0, "grid"))
			_rows.append(_row("구역 경보 상태", "경보 없음 — 수동 발령 권한 없음", false, ""))
		"rewire":
			_rows.append(_row("전력 재분배", "가용 %d유닛" % TerminalData.POWER_BUDGET, true, "rewire"))
		"save":
			_rows.append(_row("출입 카드 삽입", "현재 지점을 기록합니다", true, "save"))
		"survey":
			var zones := TerminalData.grid_of(terminal_id)
			var scope := "관할 구역 없음 — 다녀온 방만 표시"
			if not zones.is_empty():
				scope = " · ".join(PackedStringArray(zones))
			_rows.append(_row("구역 지도", "스테이션 개략도 — 실시간 판독: %s" % scope, true, "map"))
			_rows.append(_row("센서 판독", "기록 %d건" % _logs().size(), _logs().size() > 0, "logs"))
	_sel = _first_enabled()
	_render()


func _row(label: String, note: String, enabled: bool, act: String) -> Dictionary:
	return {"label": label, "note": note, "enabled": enabled, "act": act}


func _logs() -> Array:
	return data.get("logs", [])


func _first_enabled() -> int:
	for i in _rows.size():
		if _rows[i]["enabled"]:
			return i
	return 0


# ── 각 페이지 ────────────────────────────────────────────────────────────────

func _open_logs() -> void:
	state = State.LOGS
	_rows = []
	for i in _logs().size():
		var l: Dictionary = _logs()[i]
		_rows.append(_row(str(l["title"]), str(l["from"]), true, "log:%d" % i))
	_sel = 0
	_render()


func _open_log(i: int) -> void:
	state = State.LOG
	_rows = []
	_sel = i
	_typing = true
	_body.visible_ratio = 0.0
	_render()


func _open_rewire() -> void:
	state = State.REWIRE
	_rows = []
	for c in TerminalData.CIRCUITS:
		_rows.append(_row(str(c["name"]), str(c["note"]), true, "circuit:%s" % c["id"]))
	_sel = 0
	_render()


func _open_save() -> void:
	state = State.SAVE
	_rows = []
	_typing = true
	_body.visible_ratio = 0.0
	_render()


## 구역 지도 (survey) — 커서가 방 위를 돈다. 실시간 판독 범위는 이 단말기의 grid.
func _open_map() -> void:
	state = State.MAP
	_rows = []
	_map.setup_survey(TerminalData.grid_of(terminal_id), terminal_room)
	_render()


## 방어 그리드 (security) — 같은 지도 위에서 **관할 포탑**을 고른다.
## 목록이 아니라 지도인 이유: "어느 방의 포탑인가" 가 곧 선택의 근거이기 때문이다.
func _open_grid() -> void:
	state = State.GRID
	_grid = TerminalData.grid_entries(terminal_id, terminal_room)
	_rows = []
	_map.setup_grid(_grid, TerminalData.grid_of(terminal_id), terminal_room)
	_render()


## Main 이 원격 방으로 넘어간 뒤 부른다 — 화면 가운데를 비우고 얇은 관제 HUD 만 남긴다
func enter_remote(entry: Dictionary) -> void:
	state = State.REMOTE
	_remote = entry
	_rows = []
	_set_plate(0.0, 0.2)
	_render()


## 원격 조종 중 총열 과열 표시 (Main 이 매 프레임 넣어 준다)
func set_remote_heat(heat: float, overheated: bool) -> void:
	_remote_heat = heat
	_remote_overheated = overheated
	if state == State.REMOTE:
		_render_remote()


## 링크 해제 — 다시 방어 그리드 지도로. 커서는 방금 잡고 있던 포탑 위에 그대로 둔다.
func leave_remote() -> void:
	var was := str(_remote.get("id", ""))
	_remote = {}
	_set_plate(PLATE_ALPHA, 0.2)
	_open_grid()
	if was != "":
		_map.select_sentry(was)


# ── 그리기 ───────────────────────────────────────────────────────────────────

func _render() -> void:
	_map.visible = state == State.MAP or state == State.GRID
	if state == State.REMOTE:
		_render_remote()
		return
	_rule_top.visible = true
	_rule_bottom.visible = true
	_head.text = _header_text()
	_body.text = _body_text()
	# 타이핑 중인 페이지(로그 본문·저장 연출)는 0 글자에서 시작해 _process 가 채운다
	if _typing:
		_body.visible_characters = 0
	else:
		_body.visible_ratio = 1.0
	_foot.text = _footer_text()


func _header_text() -> String:
	var t := Time.get_time_dict_from_system()
	return "[color=#ffffff]%s[/color]   %s      %s      %02d:%02d:%02d" % [
		data.get("callsign", "SEV-000"), data.get("title", role["name"]),
		role["short"], t["hour"], t["minute"], t["second"]]


func _footer_text() -> String:
	var keys := "↑↓ / W S  선택      ENTER  실행      ESC  "
	if state == State.MAP:
		keys = "↑↓←→ / WASD  구역 이동      ESC  뒤로"
	elif state == State.GRID:
		keys = "↑↓←→ / WASD  포탑 선택      ENTER  채널 연결      ESC  뒤로"
	else:
		keys += "종료" if state == State.MENU else "뒤로"
	if _status_t > 0.0:
		return "[color=#ffffff]%s[/color]        %s" % [_status, keys]
	return keys


func _body_text() -> String:
	match state:
		State.LOG:
			var l: Dictionary = _logs()[_sel]
			return "[color=#ffffff]%s[/color]\n%s\n\n%s" % [l["title"], _hr(), l["body"]]
		State.SAVE:
			return "%s\n\n  카드 판독 …… 승인\n  좌표 기록 …… %s\n  기록 시각 …… %s\n\n%s\n\n[color=#ffffff]  기록되었습니다.[/color]\n  (연출만 — 실제 저장 데이터는 아직 없습니다)" % [
				_hr(), RoomData.get_room(terminal_room)["title"], Time.get_datetime_string_from_system(false, true), _hr()]
		State.REWIRE:
			return _list_text("사용 중 %d / 가용 %d 유닛" % [_power_used(), TerminalData.POWER_BUDGET])
		State.MAP:
			return _map_caption("스테이션 개략도 — 밝은 방이 실시간 판독, 흐린 방은 다녀온 기록, 빈 윤곽은 미판독 구역")
		State.GRID:
			return _map_caption("방어 그리드 — 관할 포탑만 잡힙니다. 어두운 ▲ 는 탐지되었으나 권한 밖입니다")
		State.LOGS:
			return _list_text("기록 %d건" % _rows.size())
		_:
			return _list_text("")


## 지도 페이지의 본문은 캡션 두 줄뿐이다 — 그 아래는 StationMap 이 직접 그린다
func _map_caption(caption: String) -> String:
	return "[color=#8f978f]%s[/color]
%s" % [caption, _hr()]


func _hr() -> String:
	return "[color=#5a625c]%s[/color]" % "─".repeat(58)


## 지금 그릴 줄 범위 [시작, 끝) — 선택한 줄이 항상 창 안에 들어오게 민다
func _window() -> Vector2i:
	if _rows.size() <= MAX_ROWS:
		return Vector2i(0, _rows.size())
	var start := clampi(_sel - MAX_ROWS / 2, 0, _rows.size() - MAX_ROWS)
	return Vector2i(start, start + MAX_ROWS)


## 목록 페이지 공통 그리기 — 선택된 줄에 ▶ 와 반전 배경, 잠긴 줄은 어둡게
func _list_text(caption: String) -> String:
	var out := ""
	if caption != "":
		out += "[color=#8f978f]%s[/color]\n%s\n\n" % [caption, _hr()]
	var win := _window()
	if win.x > 0:
		out += "  [color=#6d746e]▲  위로 %d개 더[/color]\n" % win.x
	for i in range(win.x, win.y):
		var r: Dictionary = _rows[i]
		var mark := "  "
		var label := str(r["label"])
		var note := str(r["note"])
		if state == State.REWIRE:
			var cid := str(r["act"]).split(":")[1]
			label = "[%s]  %s" % ["●" if _power.get(cid, false) else "○", label]
		if not r["enabled"]:
			out += "  [color=#565a56]■  %s[/color]\n      [color=#454945]%s[/color]\n\n" % [label, note]
			continue
		if i == _sel:
			mark = "[color=#ffffff]▶[/color] "
			out += "%s[bgcolor=#2a3a2e][color=#ffffff] %s [/color][/bgcolor]\n      [color=#9aa39a]%s[/color]\n\n" % [mark, label, note]
		else:
			out += "%s[color=#b6bcb6]%s[/color]\n      [color=#6d746e]%s[/color]\n\n" % [mark, label, note]
	if win.y < _rows.size():
		out += "  [color=#6d746e]▼  아래로 %d개 더[/color]" % (_rows.size() - win.y)
	return out


## 원격 조종 중: 월드를 가리면 안 되므로 위아래 한 줄씩만 남긴다
func _render_remote() -> void:
	_rule_top.visible = true
	_rule_bottom.visible = true
	var heat_pct := int(clampf(_remote_heat, 0.0, 1.0) * 100.0)
	var bars := int(round(clampf(_remote_heat, 0.0, 1.0) * 24.0))
	var heat_bar := "█".repeat(bars) + "·".repeat(24 - bars)
	var heat_line := "총열 [%s] %3d%%" % [heat_bar, heat_pct]
	if _remote_overheated:
		heat_line = "[color=#ffffff]과열 — 냉각 중  [%s][/color]" % heat_bar
	# 머리글에는 신원만, 게이지는 꼬리글에 — 한 줄에 다 넣으면 본문 폭(1376px)을 넘어 게이지가 잘린다
	_head.text = "[color=#ffffff]● REMOTE LINK[/color]   %s   %s  ·  %s" % [
		data.get("callsign", "SEV-000"), _remote.get("name", "?"), _remote.get("room_title", "?")]
	_body.text = ""
	_foot.text = "%s        마우스 조준  ·  좌클릭 사격  ·  [color=#ffffff]ESC[/color] 링크 해제" % heat_line


# ── 입력 ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if state == State.CLOSED:
		return
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0:
			_render()
	if state == State.BOOT:
		_tick_boot(delta)
		return
	if state == State.REMOTE:
		return
	# 머리글의 시계와 커서는 계속 돈다
	_cursor_t += delta
	if _cursor_t >= CURSOR_BLINK:
		_cursor_t -= CURSOR_BLINK
		_cursor_on = not _cursor_on
		_head.text = _header_text() + ("  [color=#ffffff]_[/color]" if _cursor_on else "   ")
	if _typing:
		_body.visible_ratio = minf(_body.visible_ratio + TYPE_SPEED * delta / maxf(float(_body.get_total_character_count()), 1.0), 1.0)
		if _body.visible_ratio >= 1.0:
			_typing = false


func _input(event: InputEvent) -> void:
	if state == State.CLOSED or state == State.BOOT:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode

	if state == State.REMOTE:
		# 원격 조종 중에는 ESC 만 가로챈다 — 마우스·사격은 포탑으로 그대로 간다
		if key == KEY_ESCAPE:
			unlink_requested.emit()
			get_viewport().set_input_as_handled()
		return

	if state == State.MAP or state == State.GRID:
		_map_input(key)
		get_viewport().set_input_as_handled()
		return

	match key:
		KEY_UP, KEY_W:
			_move_sel(-1)
		KEY_DOWN, KEY_S:
			_move_sel(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activate()
		KEY_ESCAPE, KEY_Q:
			_back()
		_:
			return
	get_viewport().set_input_as_handled()


## 지도 위 커서 — 상하좌우로 방(또는 포탑)을 옮겨 다닌다
func _map_input(key: Key) -> void:
	match key:
		KEY_LEFT, KEY_A:
			_map.move(Vector2i(-1, 0))
		KEY_RIGHT, KEY_D:
			_map.move(Vector2i(1, 0))
		KEY_UP, KEY_W:
			_map.move(Vector2i(0, -1))
		KEY_DOWN, KEY_S:
			_map.move(Vector2i(0, 1))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if state == State.GRID:
				_request_link(_map.selected_entry())
		KEY_ESCAPE, KEY_Q:
			_back()


func _move_sel(step: int) -> void:
	if _rows.is_empty():
		return
	var i := _sel
	for _n in _rows.size():
		i = wrapi(i + step, 0, _rows.size())
		if _rows[i]["enabled"]:
			_sel = i
			_render()
			return


func _activate() -> void:
	if _typing:                       # 타이핑 중 확인 = 즉시 전부 표시
		_body.visible_ratio = 1.0
		_typing = false
		return
	if state == State.SAVE or state == State.LOG:
		_back()
		return
	if _rows.is_empty() or not _rows[_sel]["enabled"]:
		return
	var act := str(_rows[_sel]["act"])
	if act == "":
		return
	var head := act.split(":")[0]
	match head:
		"logs": _open_logs()
		"rewire": _open_rewire()
		"save": _open_save()
		"grid": _open_grid()
		"map": _open_map()
		"log": _open_log(int(act.split(":")[1]))
		"circuit": _toggle_circuit(act.split(":")[1])
		"link": _request_link(int(act.split(":")[1]))


func _back() -> void:
	match state:
		State.MENU:
			close_requested.emit()
		State.LOG:
			_open_logs()
		State.LOGS, State.REWIRE, State.SAVE, State.MAP, State.GRID:
			_open_menu()
		_:
			close_requested.emit()


func _toggle_circuit(cid: String) -> void:
	var cost := 1
	for c in TerminalData.CIRCUITS:
		if c["id"] == cid:
			cost = int(c["cost"])
	if _power.get(cid, false):
		_power[cid] = false
	elif _power_used() + cost <= TerminalData.POWER_BUDGET:
		_power[cid] = true
	else:
		_notify("전력이 모자랍니다 — 다른 회로를 먼저 내리십시오")
		return
	_render()


func _power_used() -> int:
	var used := 0
	for c in TerminalData.CIRCUITS:
		if _power.get(c["id"], false):
			used += int(c["cost"])
	return used


func _notify(msg: String) -> void:
	_status = msg
	_status_t = 2.4
	_foot.text = _footer_text()


func _request_link(i: int) -> void:
	if i < 0 or i >= _grid.size():
		return
	var e: Dictionary = _grid[i]
	if not e["authorized"]:
		return
	_body.text = "%s\n\n  대상 …… [color=#ffffff]%s[/color]\n  경로 …… %s\n\n  [color=#ffffff]LINKING …[/color]" % [
		_hr(), e["name"], e["room_title"]]
	_foot.text = "채널 전환 중 …"
	link_requested.emit(e)
