extends "res://scripts/main.gd"
## 조명·면 랩 (scenes/FaceLab.tscn · 2026-09-22).
##
## **실제 게임 그대로** 돌아간다 — main.gd 를 상속해서 플레이어·총·몬스터·카메라·조명이 전부 본편과 같다.
## 별도의 실험용 광원을 만들지 않는 것이 요점이다: 여기서 보이는 그림이 곧 인게임 그림이라야
## 여기서 맞춘 수치를 믿을 수 있다 (대화 UI 랩·근경 랩과 같은 생각).
##
## 두 가지를 고친다.
##   1. **조명** — 방 안의 광원을 우클릭으로 고르고 세기·반경·높이를 슬라이더로 움직인다.
##      총구·탄착처럼 쏠 때만 켜지는 것은 화면에서 클릭할 수 없으므로 G 로 순환해 고른다.
##      [저장] 하면 `lighting/tuning.json` 에 쓰이고, 게임이 시작할 때 읽으므로 **본편에 그대로 적용된다**.
##      수치의 원본과 규약은 scripts/light_tuning.gd.
##   2. **면 맵** — 프랍을 우클릭으로 고르고 기울기·디테일·번짐을 움직인다 (scripts/face_normal.gd).
##      확정한 뒤 실제 자산에 굽는 것은 여전히 `tools/bake_face_normals.gd`.
##
## 조작 (게임 조작은 본편과 동일: A/D 이동 · 마우스 조준 · 좌클릭 사격 · R 재장전 · Space 구르기)
##   F5            편집 패널 접기/펴기
##   우클릭        화면에서 고르기 — 가까운 광원, 없으면 커서 아래 프랍
##   Tab / Shift+Tab  광원 종류 순환          G / Shift+G  총 계열만 순환 (클릭이 안 되므로)
##   P             **마우스 광원** 켜기/끄기 — 포인터가 곧 광원이 된다 (Shift+P 그 자리에 고정)
##                 켤 때 천장 램프와 같은 수치로 시작한다. 휠 반경 · Shift+휠 세기 · Ctrl+휠 높이
##                 방에 붙박인 광원이 아니라 **랩 전용 탐침**이다 — 저장되지 않는다
##   F10           조명 수치 저장 (패널의 [저장] 버튼과 같다)
##   N             면 노멀 ↔ 기존 자동 노멀 A/B          M  면 맵 겹쳐 보기
##   F12           면 맵 다시 읽고 다시 굽기 (그림 고치고 저장한 뒤)
##   F1 로비 · F3 줌 · F6/F8 그림자 · F11 전체화면 — 본편과 동일

const FaceLabPanelWidth := 540.0          # 이름이 긴 광원(총구 화염 …)에서도 값 칸이 잘리지 않을 폭
const PICK_RANGE := 260.0                 # 우클릭으로 광원을 집는 거리 (월드 px)

var _panel: PanelContainer
var _font: Font
var _syncing := false                     # 슬라이더를 코드로 맞추는 중 (값 변경 콜백을 무시)

# ── 조명
var _light_id := "lamp"
var _light_title: Label
var _light_hint: Label
var _light_rows := {}                     # key → {"slider", "value", "row"}
var _light_status: Label

# ── 면 맵
var _face_targets: Array = []             # [{"path", "nodes", "name"}]
var _face_sel := 0
var _faces_on := true
var _overlay := false
var _auto_normal := {}
var _face_normal := {}
var _face_tune := {}
var _face_title: Label
var _face_rows := {}
var _face_status: Label

var _input_block := false
var _input_was := true

## 마우스 광원 — 면·재질을 훑어볼 때 쓰는 랩 전용 탐침. 방에 붙박인 광원이 아니라 저장되지 않는다.
## 켤 때 천장 램프(LightTuning "lamp")와 같은 수치에서 시작하므로, 휠로 벌린 만큼이 곧
## "실제 램프와 얼마나 다른 빛인가" 가 된다.
var _probe: PointLight2D
var _probe_on := false
var _probe_frozen := false
var _probe_pos := Vector2.ZERO
var _probe_radius := 560.0
var _probe_energy := 1.0
var _probe_height := 140.0
var _probe_row: Label


func _ready() -> void:
	super()
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	_build_panel()
	title_label.text += "   ·   조명·면 랩 (F5 패널)"
	_refresh_faces()
	_sync_light()
	_sync_face()
	_sync_probe_row()


# ----------------------------------------------------------------------------- 패널

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "LabPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.93)
	sb.border_color = Color(0.32, 0.35, 0.44)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(VIEW_SIZE.x - FaceLabPanelWidth - 20, 124)   # 우상단 HUD(줌·그림자 프리셋) 아래
	_panel.custom_minimum_size = Vector2(FaceLabPanelWidth, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	(get_node("UI") as CanvasLayer).add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)

	# ── 조명
	box.add_child(_head("조명  —  우클릭으로 고르기 · Tab 순환 · G 총 계열"))
	_light_title = _text(22, Color(1.0, 0.88, 0.45))
	box.add_child(_light_title)
	for key in ["energy", "radius", "height"]:
		_light_rows[key] = _slider_row(box, {"energy": "세기", "radius": "반경", "height": "높이"}[key],
			func(v: float): _on_light_changed(key, v))
	_light_hint = _text(15, Color(0.62, 0.66, 0.76))
	_light_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_light_hint.custom_minimum_size = Vector2(0, 40)
	box.add_child(_light_hint)

	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 6)
	box.add_child(lrow)
	lrow.add_child(_button("저장  →  lighting/tuning.json", _save_lights, true))
	lrow.add_child(_button("이 조명 기본값", func(): LightTuning.reset(_light_id); _apply_lights(); _sync_light()))
	_light_status = _text(15, Color(0.70, 0.85, 0.70))
	box.add_child(_light_status)
	_probe_row = _text(15, Color(0.80, 0.78, 0.62))
	box.add_child(_probe_row)

	box.add_child(_sep())

	# ── 면 맵
	box.add_child(_head("면 맵  —  우클릭으로 프랍 고르기"))
	_face_title = _text(22, Color(0.70, 0.90, 1.0))
	box.add_child(_face_title)
	for key in ["tilt", "detail", "soft"]:
		_face_rows[key] = _slider_row(box, {"tilt": "기울기", "detail": "디테일", "soft": "번짐"}[key],
			func(v: float): _on_face_changed(key, v))
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 6)
	box.add_child(frow)
	frow.add_child(_button("면↔자동 (N)", func(): _toggle_faces()))
	frow.add_child(_button("겹쳐 보기 (M)", func(): _toggle_overlay()))
	frow.add_child(_button("다시 읽기 (F12)", func(): _refresh_faces(true)))
	var frow2 := HBoxContainer.new()
	frow2.add_theme_constant_override("separation", 6)
	box.add_child(frow2)
	frow2.add_child(_button("면 수치 저장", _save_face, true))
	frow2.add_child(_button("템플릿 만들기", func(): _make_template()))
	_face_status = _text(15, Color(0.70, 0.85, 0.70))
	box.add_child(_face_status)


func _head(t: String) -> Label:
	var l := _text(17, Color(0.55, 0.60, 0.72))
	l.text = t
	return l


func _text(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _sep() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.3, 0.33, 0.4, 0.5)
	c.custom_minimum_size = Vector2(0, 1)
	return c


func _button(t: String, cb: Callable, strong := false) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 16)
	if strong:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.30, 0.22)
		sb.border_color = Color(0.45, 0.75, 0.50)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override("normal", sb)
	b.focus_mode = Control.FOCUS_NONE       # Tab 이 광원 순환이라 UI 포커스가 가로채면 안 된다
	b.pressed.connect(cb)
	return b


## 라벨 + 슬라이더 + 값 표시 한 줄
func _slider_row(parent: Control, label: String, on_change: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name_label := _text(17, Color(0.82, 0.86, 0.94))
	name_label.text = label
	name_label.custom_minimum_size = Vector2(56, 0)
	row.add_child(name_label)
	var s := HSlider.new()
	s.focus_mode = Control.FOCUS_NONE       # 위와 같은 이유
	s.custom_minimum_size = Vector2(250, 22)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float):
		if not _syncing:
			on_change.call(v))
	row.add_child(s)
	var v := _text(17, Color(1.0, 0.95, 0.80))
	v.custom_minimum_size = Vector2(76, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return {"row": row, "slider": s, "value": v}


# ----------------------------------------------------------------------------- 조명

func _light_kinds(group := "") -> Array:
	var out := []
	for id in LightTuning.ids():
		if group == "" or String(LightTuning.meta(id).get("group", "")) == group:
			out.append(id)
	return out


func _step_light(d: int, group := "") -> void:
	var list := _light_kinds(group)
	var i := list.find(_light_id)
	if i < 0:
		i = 0 if d > 0 else list.size() - 1
	else:
		i = wrapi(i + d, 0, list.size())
	_light_id = list[i]
	_sync_light()


func _on_light_changed(key: String, v: float) -> void:
	LightTuning.set_value(_light_id, key, v)
	_apply_lights()
	_sync_light_values()


## 값이 바뀌면 살아 있는 광원에 바로 먹인다. 앰비언트는 방의 CanvasModulate 라 따로 갈아 준다.
func _apply_lights() -> void:
	LightTuning.apply_all()
	if current_room and current_room._ambient:
		current_room._ambient.color = Lighting.ambient_color()
	# 벽등은 방 데이터가 반경을 정하므로 배율을 다시 곱해 준다
	for e in LightTuning.live():
		if e["id"] == "fixture" and e["node"] is PointLight2D and e["node"].has_meta("base_radius"):
			LightTuning.apply_plain(e["node"], "fixture", float(e["node"].get_meta("base_radius")))


func _sync_light() -> void:
	var m := LightTuning.meta(_light_id)
	var live := 0
	for e in LightTuning.live():
		if e["id"] == _light_id:
			live += 1
	var group := String(m.get("group", ""))
	_light_title.text = "%s   %s" % [String(m.get("name", _light_id)),
		"· 이 방에 %d개" % live if group != "gun" else "· 총 계열 (쏠 때만 · G 로 순환)"]
	_light_hint.text = String(m.get("hint", ""))
	var keys: Array = m.get("keys", [])
	_syncing = true
	for key in _light_rows:
		var on: bool = key in keys
		_light_rows[key]["row"].visible = on
		if not on:
			continue
		var r: Array = LightTuning.range_of(_light_id, key)
		var s: HSlider = _light_rows[key]["slider"]
		s.min_value = r[0]
		s.max_value = r[1]
		s.step = 0.01 if (key != "radius" or LightTuning.is_mul(_light_id, key)) else 1.0
		s.value = LightTuning.value(_light_id, key)
	_syncing = false
	_sync_light_values()


func _sync_light_values() -> void:
	for key in _light_rows:
		if not _light_rows[key]["row"].visible:
			continue
		var v: float = LightTuning.value(_light_id, key)
		var d: float = LightTuning.default_of(_light_id, key)
		var mul := LightTuning.is_mul(_light_id, key)
		var txt := ("×%.2f" % v) if mul else (("%.0f" % v) if key == "radius" else ("%.2f" % v))
		_light_rows[key]["value"].text = txt
		_light_rows[key]["value"].add_theme_color_override("font_color",
			Color(1.0, 0.95, 0.80) if absf(v - d) < 0.0005 else Color(1.0, 0.72, 0.35))


func _save_lights() -> void:
	var ok := LightTuning.save()
	var ch := LightTuning.changes()
	_light_status.text = "%s — %s (기본값과 다른 항목 %d)" % [
		"저장됨" if ok else "저장 실패", LightTuning.PATH, ch.size()]
	if ok:
		print("[조명 랩] 저장 → %s" % ProjectSettings.globalize_path(LightTuning.PATH))
		for c in ch:
			print("   " + c)


# ----------------------------------------------------------------------------- 마우스 광원 (탐침)

func _toggle_probe() -> void:
	_probe_on = not _probe_on
	if _probe == null:
		_probe = PointLight2D.new()
		_probe.name = "ProbeLight"
		_probe.texture = Lighting.radial_texture()
		_probe.color = LampLight.COLOR
		_probe.shadow_enabled = false
		_probe.z_index = 90
		world.add_child(_probe)        # 월드 안 — 방·프랍과 같은 좌표계에서 비춘다
	if _probe_on:
		# 켤 때마다 천장 램프와 같은 값에서 시작한다 (랩에서 본 것이 인게임과 얼마나 다른지가 분명해지게)
		_probe_radius = LightTuning.value("lamp", "radius", 560.0)
		_probe_energy = LightTuning.value("lamp", "energy", 1.0)
		_probe_height = LightTuning.value("lamp", "height", 140.0)
		_probe_frozen = false
		_probe_pos = world.get_global_mouse_position()
	_probe.enabled = _probe_on
	_probe.visible = _probe_on
	_apply_probe()
	_light_status.text = "마우스 광원 켬 — 휠 반경 · Shift+휠 세기 · Ctrl+휠 높이 · Shift+P 고정" if _probe_on \
		else "마우스 광원 끔"


func _apply_probe() -> void:
	if _probe == null:
		return
	_probe.texture_scale = Lighting.scale_for_radius(_probe_radius)
	_probe.energy = _probe_energy
	_probe.height = _probe_height
	_probe.position = _probe_pos
	_sync_probe_row()


func _sync_probe_row() -> void:
	if _probe_row == null:
		return
	if not _probe_on:
		_probe_row.text = "마우스 광원: 끔  (P 로 켜기)"
		return
	var lamp_r: float = LightTuning.value("lamp", "radius", 560.0)
	var lamp_e: float = LightTuning.value("lamp", "energy", 1.0)
	var same := absf(_probe_radius - lamp_r) < 1.0 and absf(_probe_energy - lamp_e) < 0.005
	_probe_row.text = "마우스 광원: 반경 %.0f · 세기 %.2f · 높이 %.0f%s%s" % [
		_probe_radius, _probe_energy, _probe_height,
		"  (천장 램프와 같음)" if same else "  (램프와 다름)",
		"  [고정]" if _probe_frozen else ""]


## 휠로 조절. 프로브가 꺼져 있으면 휠을 건드리지 않는다 (다른 조작에 양보).
func _probe_wheel(event: InputEventMouseButton) -> bool:
	if not _probe_on:
		return false
	var s := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
	if event.shift_pressed:
		_probe_energy = clampf(_probe_energy + s * 0.08, 0.0, 8.0)
	elif event.ctrl_pressed:
		_probe_height = clampf(_probe_height + s * 10.0, 0.0, 400.0)
	else:
		_probe_radius = clampf(_probe_radius + s * 40.0, 60.0, 2600.0)
	_apply_probe()
	return true


# ----------------------------------------------------------------------------- 면 맵

func _refresh_faces(reload := false) -> void:
	if current_room == null:
		return
	_face_targets.clear()
	if reload:
		_face_normal.clear()
	_collect_faces(current_room)
	_face_targets.sort_custom(func(a, b): return String(a["name"]) < String(b["name"]))
	if reload:
		_face_tune.clear()
	_face_sel = clampi(_face_sel, 0, maxi(_face_targets.size() - 1, 0))
	for i in range(_face_targets.size()):
		if reload or not FaceNormal.has_face_map(_face_targets[_face_sel]["path"]):
			if FaceNormal.has_face_map(_face_targets[i]["path"]):
				_face_sel = i
				break
	_rebuild_faces()


func _collect_faces(node: Node) -> void:
	if node is Sprite2D and (node as Sprite2D).visible:
		var tex = (node as Sprite2D).texture
		if tex is CanvasTexture:
			var path := Lighting.path_of(tex)
			if path != "":
				var found := false
				for t in _face_targets:
					if t["path"] == path:
						t["nodes"].append(node)
						found = true
						break
				if not found:
					_face_targets.append({"path": path, "nodes": [node], "name": path.get_file().get_basename()})
				if not _auto_normal.has(path):
					_auto_normal[path] = (tex as CanvasTexture).normal_texture
	for c in node.get_children():
		_collect_faces(c)


func _face_tune_of(path: String) -> Dictionary:
	if not _face_tune.has(path):
		_face_tune[path] = FaceNormal.tuning_for(path)
	return _face_tune[path]


func _face_sel_target() -> Dictionary:
	return _face_targets[_face_sel] if _face_sel < _face_targets.size() else {}


func _rebuild_faces() -> void:
	for t in _face_targets:
		var path: String = t["path"]
		if not FaceNormal.has_face_map(path) or _face_normal.has(path):
			continue
		var tn := _face_tune_of(path)
		var tex := FaceNormal.build(path, tn["tilt"], tn["detail"], tn["soft"])
		if tex:
			_face_normal[path] = tex
	_apply_face_normals()
	_sync_face()


func _rebuild_face_selected() -> void:
	var t := _face_sel_target()
	if t.is_empty() or not FaceNormal.has_face_map(t["path"]):
		return
	var tn := _face_tune_of(t["path"])
	var tex := FaceNormal.build(t["path"], tn["tilt"], tn["detail"], tn["soft"])
	if tex:
		_face_normal[t["path"]] = tex
	_apply_face_normals()


func _apply_face_normals() -> void:
	for path in _face_normal:
		Lighting.set_normal(path, _face_normal[path] if _faces_on else _auto_normal.get(path))


func _on_face_changed(key: String, v: float) -> void:
	var t := _face_sel_target()
	if t.is_empty():
		return
	_face_tune_of(t["path"])[key] = v
	_rebuild_face_selected()
	_sync_face_values()


func _sync_face() -> void:
	var t := _face_sel_target()
	var has := not t.is_empty() and FaceNormal.has_face_map(t["path"])
	_face_title.text = "%s   %s" % [String(t.get("name", "(없음)")),
		"· 면 맵 있음" if has else "· 면 맵 없음 (템플릿을 만들어 칠하세요)"]
	var tn: Dictionary = _face_tune_of(t["path"]) if not t.is_empty() else FaceNormal.DEFAULT.duplicate()
	var ranges := {"tilt": [0.0, 85.0, 1.0], "detail": [0.0, 1.0, 0.01], "soft": [0.0, 80.0, 1.0]}
	_syncing = true
	for key in _face_rows:
		var s: HSlider = _face_rows[key]["slider"]
		s.min_value = ranges[key][0]
		s.max_value = ranges[key][1]
		s.step = ranges[key][2]
		s.value = tn[key]
		_face_rows[key]["row"].visible = has
	_syncing = false
	_sync_face_values()


func _sync_face_values() -> void:
	var t := _face_sel_target()
	var tn: Dictionary = _face_tune_of(t["path"]) if not t.is_empty() else FaceNormal.DEFAULT.duplicate()
	_face_rows["tilt"]["value"].text = "%.0f°" % tn["tilt"]
	_face_rows["detail"]["value"].text = "%.2f" % tn["detail"]
	_face_rows["soft"]["value"].text = "%.0f px" % tn["soft"]


func _toggle_faces() -> void:
	_faces_on = not _faces_on
	_apply_face_normals()
	_face_status.text = "면 노멀 (내가 나눈 면)" if _faces_on else "자동 노멀 (밝기+베벨) — 비교 중"


func _toggle_overlay() -> void:
	_overlay = not _overlay
	_clear_overlay(current_room)
	if not _overlay:
		return
	var t := _face_sel_target()
	if t.is_empty():
		return
	var img := FaceNormal.load_png(FaceNormal.face_path(t["path"]))
	if img == null:
		_face_status.text = "면 맵이 없어 겹쳐 볼 것이 없다"
		return
	var tex := ImageTexture.create_from_image(img)
	for n in t["nodes"]:
		if not is_instance_valid(n) or not (n is Sprite2D):
			continue
		var sp := n as Sprite2D
		var ov := Sprite2D.new()
		ov.name = "_FaceOverlay"
		ov.texture = tex
		ov.centered = sp.centered
		ov.offset = sp.offset
		ov.flip_h = sp.flip_h
		ov.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ov.light_mask = 0
		ov.z_index = 30
		ov.modulate = Color(2.4, 2.4, 2.4, 0.62)
		sp.add_child(ov)


func _clear_overlay(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		if c.name == "_FaceOverlay":
			c.queue_free()
		else:
			_clear_overlay(c)


func _make_template() -> void:
	var t := _face_sel_target()
	if t.is_empty():
		return
	var dst := FaceNormal.write_template(t["path"], Input.is_key_pressed(KEY_SHIFT))
	if dst == "":
		_face_status.text = "이미 면 맵이 있다 (Shift 누른 채 누르면 덮어씀)"
		return
	print("[면 랩] 템플릿 → %s" % ProjectSettings.globalize_path(dst))
	_face_status.text = "템플릿 생성 → %s" % dst
	_refresh_faces(true)


func _save_face() -> void:
	var t := _face_sel_target()
	if t.is_empty():
		return
	var tn := _face_tune_of(t["path"])
	var ok := FaceNormal.save_tuning(tn["tilt"], tn["detail"], tn["soft"], t["path"])
	_face_status.text = "%s — faces/tuning.json (%s).  자산에 굽기: tools/bake_face_normals.gd" % [
		"저장됨" if ok else "저장 실패", String(t["name"])]


# ----------------------------------------------------------------------------- 고르기 · 입력

## 우클릭: 가까운 광원을 집고, 없으면 커서 아래 프랍을 집는다.
func _pick_at(p: Vector2) -> void:
	var best := ""
	var best_d := PICK_RANGE
	for e in LightTuning.live():
		var n = e["node"]
		if not (n is Node2D):
			continue
		var d: float = (n as Node2D).global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = e["id"]
	if best != "":
		_light_id = best
		_sync_light()
		_light_status.text = "화면에서 고름: %s" % String(LightTuning.meta(best).get("name", best))
		return
	for i in range(_face_targets.size()):
		for n in _face_targets[i]["nodes"]:
			if not is_instance_valid(n) or not (n is Sprite2D):
				continue
			var sp := n as Sprite2D
			if (sp.get_global_transform() * sp.get_rect()).has_point(p):
				_face_sel = i
				if _overlay:
					_overlay = false
					_toggle_overlay()
				_sync_face()
				_face_status.text = "프랍 고름: %s" % String(_face_targets[i]["name"])
				return
	_light_status.text = "가까운 광원·프랍이 없다 (우클릭은 %.0fpx 안의 광원을 집는다)" % PICK_RANGE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_pick_at(world.get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _probe_wheel(event):
			get_viewport().set_input_as_handled()
			return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F5:
			_panel.visible = not _panel.visible
		KEY_TAB:
			_step_light(-1 if event.shift_pressed else 1)
		KEY_G:
			_step_light(-1 if event.shift_pressed else 1, "gun")
		KEY_P:
			if event.shift_pressed and _probe_on:
				_probe_frozen = not _probe_frozen
				_light_status.text = "마우스 광원 고정" if _probe_frozen else "마우스 광원 따라다님"
				_sync_probe_row()
			else:
				_toggle_probe()
		KEY_F10:
			_save_lights()
		KEY_N:
			_toggle_faces()
		KEY_M:
			_toggle_overlay()
		KEY_F12:
			_refresh_faces(true)
			_face_status.text = "면 맵 다시 읽음"
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	super(delta)
	if _probe_on and not _probe_frozen and _probe != null:
		_probe_pos = world.get_global_mouse_position()
		_probe.position = _probe_pos
	# 패널 위에 커서가 있는 동안에는 사격·이동이 먹지 않게 한다 (사격은 액션 폴링이라 UI 가 막아 주지 않는다)
	var over := _panel != null and _panel.visible \
		and _panel.get_global_rect().has_point(get_viewport().get_mouse_position())
	if over != _input_block:
		_input_block = over
		if player:
			if over:
				_input_was = player.input_enabled
				player.input_enabled = false
			else:
				player.input_enabled = _input_was


## 방을 옮기면 광원·프랍 목록이 통째로 바뀐다
func _load_room(id: String, spawn_x: float, face_dir: int) -> void:
	super(id, spawn_x, face_dir)
	_face_normal.clear()
	_auto_normal.clear()
	_overlay = false
	if _panel:
		_apply_lights()
		_refresh_faces()
		_sync_light()
