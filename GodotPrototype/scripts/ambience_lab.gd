class_name AmbienceLab
extends CanvasLayer
## 앰비언스 랩 — 실제로 방을 돌아다니면서 그 방에 지금 무엇이 울리고 있는지 보고,
## 그 자리에서 수치를 돌려 보고, 마음에 들면 방별로 저장하는 편집 오버레이.
##
## 근경 랩과 달리 **플레이어 입력을 끄지 않는다.** 소리는 걸어 다니면서 판단하는 것이라
## 문을 넘나들며 베드가 바뀌는 순간을 들어야 하기 때문이다. 그래서 조작 키도
## 이동(A/D·W/S·Space·Shift·Ctrl·R·E·J)과 겹치지 않는 것만 골랐다.
##
##  Tab              : 편집 대상 순환 (BED → TEX 0 → TEX 1)
##  - / =            : 선택 대상 음량 ∓0.5dB   (Shift 와 함께 ∓2.0dB)
##  , / .            : 선택 슬롯의 파일 순환 (AudioManager.AMB_FILES)
##  Backspace        : 선택한 텍스처 슬롯 비우기
##  Ctrl+S           : ambience/tuning.json 저장 (지금까지 만진 방 전부)
##  Ctrl+R           : 이 방 보정만 지우고 기본값으로
##  F5               : 패널 접기/펴기
##
## 저장 파일은 AudioManager 가 시작할 때 읽어 기본값을 덮는다 — 랩에서만 들리는 값이 아니라
## 게임 본편에도 그대로 적용된다.

const ROW_BED := 0
const STEP := 0.5
const STEP_BIG := 2.0
const DB_MIN := -60.0
const DB_MAX := 6.0

var _panel: PanelContainer
var _text: Label
var _toast := ""
var _toast_t := 0.0
var _room := ""
var _plan := {}
var _row := 0                       # 0 = BED, 1.. = 텍스처 슬롯
var _folded := false


func _ready() -> void:
	layer = 20
	_build()
	Audio.ambience_changed.connect(_on_ambience_changed)
	_room = Audio.current_room_id()
	if _room != "":
		_plan = Audio.plan_for(_room)
	_refresh()


func _build() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "D2Coding", "Malgun Gothic", "Segoe UI"])

	_panel = PanelContainer.new()
	_panel.position = Vector2(AppFlow.VIEW_SIZE.x - 24 - 720, 150)   # 줌(y18)·탐색(y84) 라벨 아래
	_panel.custom_minimum_size = Vector2(720, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.05, 0.86)
	sb.border_color = Color(0.30, 0.62, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	_text = Label.new()
	_text.add_theme_font_override("font", font)
	_text.add_theme_font_size_override("font_size", 19)
	_text.add_theme_color_override("font_color", Color(0.82, 0.93, 0.87))
	_panel.add_child(_text)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast = ""
			_refresh()


func _on_ambience_changed(room_id: String, plan: Dictionary) -> void:
	_room = room_id
	_plan = plan.duplicate(true)
	_row = mini(_row, Audio.TEX_SLOTS)
	_refresh()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := e as InputEventKey
	var big := k.shift_pressed
	match k.keycode:
		KEY_F5:
			_folded = not _folded
		KEY_TAB:
			_row = (_row + 1) % (Audio.TEX_SLOTS + 1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_nudge(-(STEP_BIG if big else STEP))
		KEY_EQUAL, KEY_KP_ADD:
			_nudge(STEP_BIG if big else STEP)
		KEY_COMMA:
			_cycle_file(-1)
		KEY_PERIOD:
			_cycle_file(1)
		KEY_BACKSPACE:
			_clear_slot()
		KEY_S:
			if not k.ctrl_pressed:
				return
			var path := Audio.save_tuning()
			_flash("저장됨 — 방 %d개  ·  %s" % [Audio.tuned_rooms(), path])
		KEY_R:
			if not k.ctrl_pressed:
				return
			Audio.reset_room(_room)
			_plan = Audio.plan_for(_room)
			_flash("이 방 보정을 지웠습니다 (기본값)")
		_:
			return
	get_viewport().set_input_as_handled()
	_refresh()


## 선택한 줄의 음량을 올리고 내린다. 슬롯이 비어 있으면 할 일이 없다.
func _nudge(d: float) -> void:
	if _plan.is_empty():
		return
	if _row == ROW_BED:
		_plan["bed_db"] = clampf(float(_plan["bed_db"]) + d, DB_MIN, DB_MAX)
	else:
		var i := _row - 1
		if i >= _plan["tex"].size():
			return
		_plan["tex"][i]["db"] = clampf(float(_plan["tex"][i]["db"]) + d, DB_MIN, DB_MAX)
	Audio.apply_plan(_room, _plan)


## 선택한 줄에 다른 파일을 끼운다. 텍스처 슬롯은 목록 끝에서 "(없음)" 으로 한 번 더 돈다.
func _cycle_file(dir: int) -> void:
	if _plan.is_empty():
		return
	var files: Array = Audio.AMB_FILES
	if _row == ROW_BED:
		var at := files.find(String(_plan["bed"]))
		_plan["bed"] = String(files[wrapi(at + dir, 0, files.size())])
	else:
		var i := _row - 1
		var cur := String(_plan["tex"][i]["file"]) if i < _plan["tex"].size() else ""
		# -1 = 없음, 0.. = files 인덱스
		var at := files.find(cur) if cur != "" else -1
		var next := wrapi(at + dir + 1, 0, files.size() + 1) - 1
		while _plan["tex"].size() <= i:
			_plan["tex"].append({"file": "", "db": Audio.TEX_DB})
		if next < 0:
			_plan["tex"][i]["file"] = ""
		else:
			var rel := String(files[next])
			_plan["tex"][i]["file"] = rel
			_plan["tex"][i]["db"] = Audio.TEX_DB + float(Audio.TEX_TRIM.get(rel, 0.0))
	Audio.apply_plan(_room, _plan)


func _clear_slot() -> void:
	if _plan.is_empty() or _row == ROW_BED:
		return
	var i := _row - 1
	if i < _plan["tex"].size():
		_plan["tex"][i]["file"] = ""
		Audio.apply_plan(_room, _plan)


func _flash(msg: String) -> void:
	_toast = msg
	_toast_t = 3.5


func _refresh() -> void:
	if _text == null:
		return
	if _folded:
		_text.text = "앰비언스 랩 (F5 펴기)"
		return
	if _plan.is_empty():
		_text.text = "앰비언스 랩 — 방 정보 없음"
		return

	var zone := String(RoomData.ROOMS.get(_room, {}).get("zone", "?"))
	var title := String(RoomData.ROOMS.get(_room, {}).get("title", _room))
	var lines := PackedStringArray()
	lines.append("♪  앰비언스 랩      %s  ·  %s" % [zone, title])
	lines.append("   방 id  %s%s" % [_room, "   [보정 있음]" if Audio.has_tuning(_room) else ""])
	lines.append("")
	lines.append(_row_text(ROW_BED, "BED   ", String(_plan["bed"]), float(_plan["bed_db"])))
	for i in range(Audio.TEX_SLOTS):
		var f := ""
		var db := 0.0
		if i < _plan["tex"].size():
			f = String(_plan["tex"][i]["file"])
			db = float(_plan["tex"][i]["db"])
		lines.append(_row_text(i + 1, "TEX %d " % i, f, db))
	lines.append("")
	var amb := AudioServer.get_bus_index(Audio.BUS_AMB)
	lines.append("   버스 %.1fdB   ·   로우패스 %dHz   ·   실효 = 파일 RMS + 위 dB + 버스" % [
		AudioServer.get_bus_volume_db(amb), int(_lpf_hz(amb))])
	lines.append("")
	lines.append("   Tab 대상   - / = 음량(Shift 크게)   , / . 파일   Backspace 비우기")
	lines.append("   Ctrl+S 저장   Ctrl+R 이 방 초기화   F5 접기   F1 로비")
	if _toast != "":
		lines.append("")
		lines.append("   ▸ " + _toast)
	_text.text = "\n".join(lines)


func _row_text(row: int, tag: String, file: String, db: float) -> String:
	var mark := "▶" if row == _row else " "
	var label := file.get_file().replace(".ogg", "") if file != "" else "(없음)"
	if file == "":
		return "%s  %s %-26s" % [mark, tag, label]
	return "%s  %s %-26s %+6.1f dB" % [mark, tag, label, db]


func _lpf_hz(bus: int) -> float:
	for i in range(AudioServer.get_bus_effect_count(bus)):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectLowPassFilter:
			return (fx as AudioEffectLowPassFilter).cutoff_hz
	return 0.0
