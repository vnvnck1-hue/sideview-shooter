extends "res://scripts/main.gd"
## 역광 테스트 씬 (scenes/BacklightLab.tscn) — 광원의 앞·뒤 깊이에 따라 인물이 받는 빛이 어떻게 달라지는지 본다.
##
## 지금까지는 뒷벽 램프도 인물을 **정면(순광)** 으로 비췄다 — 램프는 뒤에 그려지는데 빛은 카메라 쪽에서 오는 셈이다.
## 여기서는 그 빛을 **역광**으로 받는다 (DepthLayers.wall_backlight · LightMirror.backlit · lit_common.lit_light 의 L.z < 0 분기):
##   · 광원 앞에 선 인물은 몸 안쪽이 살짝 가라앉고 (노출이 뒤의 밝은 빛에 맞춰진 것처럼)
##   · 광원 쪽 실루엣 윤곽이 강하게 빛나 배경에서 떨어져 보인다.
## 반대로 **앞쪽 램프**(갓이 인물 앞 z7 에 매달림)는 인물을 순광으로 온전히 비추고 먼 뒷벽은 약하게 받는다 (Lighting.split_front).
##
## 방은 세 구역이다 (왼쪽 → 오른쪽):
##   A  뒤 램프 바로 앞에 선 인물 — 역광이 가장 세게 걸리는 자리
##   B  뒤 램프 옆으로 비켜 선 인물 — 한쪽 윤곽만 빛나는 측면 역광
##   C  앞쪽 램프 아래 인물 — 순광 (비교 기준)
## 본편과 같은 플레이 루프(이동·조준·사격)를 그대로 돌린다 (main.gd 상속). 플레이어가 직접 램프 앞을 지나가 보면 된다.
##
## 조작 (본편 + 여기만):
##   B 역광 켜기/끄기 (A/B 비교)   U/I 몸 정면 비율 −/+   K/L 노출 딥 −/+   O/P 윤곽 배율 −/+   0 기본값
##   M 크롤러 하나 (적이 램프 앞에서 읽히는지)   H 정보 숨기기

const ROOM_ID := "backlight_lab"
const SPAWN_X := 300.0
const LAMP_A := 760.0
const LAMP_B := 1800.0
const LAMP_C := 2900.0

## 역광 기본값 — project.godot [shader_globals] 와 같은 값
const BODY_DEFAULT := 0.3
const DIP_DEFAULT := 0.3
const RIM_DEFAULT := 1.8

var backlight_on := true
var body := BODY_DEFAULT
var dip := DIP_DEFAULT
var rim := RIM_DEFAULT
var hud_on := true
var _info: Label
var _hud_font: Font


static func room_data() -> Dictionary:
	return {
		"title": "역광 테스트 — 광원의 앞과 뒤",
		"zone": RoomData.ZONE_WORKSHOP, "theme": "workshop",
		"shape": [[30, 6]],
		"left_door": {"open": false}, "right_door": {"open": false},
		"front_doors": [],
		"props": [
			{"type": "npc", "id": "caretaker", "x": LAMP_A + 20.0, "facing": 1},       # A: 램프 바로 앞
			{"type": "npc", "id": "controller", "x": LAMP_B + 330.0, "facing": -1},    # B: 램프 오른쪽으로 비켜 섬
			{"type": "npc", "id": "keeper", "x": LAMP_C, "facing": -1},                # C: 앞쪽 램프 아래
		],
		"lamps": [LAMP_A, LAMP_B, {"x": LAMP_C, "depth": "front"}],
		"fixtures": [], "fx": [],
		"monsters": [], "spawn": {"max": 0, "interval": [9.0, 9.0]},
	}


func _ready() -> void:
	RoomData.register_extra(ROOM_ID, room_data())
	AppFlow.start_room = ROOM_ID
	AppFlow.resume_x = SPAWN_X
	AppFlow.resume_facing = 1
	DepthLayers.wall_backlight = backlight_on       # 방을 만들기 전에 — 새 거울 라이트가 이 값으로 생긴다
	Lighting.set_backlight(body, dip, rim)
	super()
	_build_hud()
	_build_station_labels()


func _exit_tree() -> void:
	DepthLayers.wall_backlight = false              # 로비로 나가면 본편 기본값으로
	Lighting.set_backlight(BODY_DEFAULT, DIP_DEFAULT, RIM_DEFAULT)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or current_room == null:
		return
	if dialogue.active or terminal_screen.is_open():
		return
	match key.keycode:
		KEY_B:
			backlight_on = not backlight_on
			DepthLayers.wall_backlight = backlight_on
			Lighting.set_wall_backlight(current_room, backlight_on)
		KEY_U:
			body = clampf(body - 0.05, 0.0, 1.0)
		KEY_I:
			body = clampf(body + 0.05, 0.0, 1.0)
		KEY_K:
			dip = clampf(dip - 0.05, 0.0, 1.0)
		KEY_L:
			dip = clampf(dip + 0.05, 0.0, 1.0)
		KEY_O:
			rim = clampf(rim - 0.1, 0.0, 4.0)
		KEY_P:
			rim = clampf(rim + 0.1, 0.0, 4.0)
		KEY_0, KEY_KP_0:
			body = BODY_DEFAULT
			dip = DIP_DEFAULT
			rim = RIM_DEFAULT
		KEY_M:
			var dir := player.facing
			var x := clampf(player.position.x + 700.0 * dir, 300.0, current_room.width - 300.0)
			current_room._add_crawler(x, -dir)
		KEY_H:
			hud_on = not hud_on
			_info.visible = hud_on
		_:
			return
	Lighting.set_backlight(body, dip, rim)
	_update_hud()
	get_viewport().set_input_as_handled()


# ── 정보 표시 ──────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud_font = SystemFont.new()
	_hud_font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])
	var layer := get_node("UI") as CanvasLayer
	_info = Label.new()
	_info.position = Vector2(24, 58)
	_info.add_theme_font_override("font", _hud_font)
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 6)
	layer.add_child(_info)
	for l in [shadow_label, dyn_shadow_label, idle_label, mark_label]:
		if l:
			l.visible = false               # 본편 프리셋 표시는 이 씬의 정보와 겹친다
	hint_label.text = "F1 로비   A/D 이동 · 좌클릭 사격   B 역광 켜기/끄기   U/I 몸 정면   K/L 노출 딥   O/P 윤곽   0 기본값   M 크롤러   H 정보   F3 줌"
	_update_hud()


func _update_hud() -> void:
	if _info == null:
		return
	var state := "역광  ON   (뒷벽 램프를 인물이 등진다)" if backlight_on else "역광  OFF  (예전 방식 — 뒷벽 램프도 정면에서 비춘다)"
	_info.text = "\n".join([
		state,
		"몸 정면 비율 %.2f   (U/I)   역광일 때 몸 앞면이 받는 빛" % body,
		"노출 딥 %.2f   (K/L)   광원을 등지면 몸 안쪽이 가라앉는 정도" % dip,
		"윤곽 배율 %.1f   (O/P)   광원 쪽 실루엣 윤곽" % rim,
	])


## 구역 표지 — 월드 공간, 천장 아래
func _build_station_labels() -> void:
	var marks := [
		[LAMP_A, "A · 뒤 램프 — 바로 앞에 선 인물"],
		[LAMP_B + 160.0, "B · 뒤 램프 — 옆으로 비켜 선 인물"],
		[LAMP_C, "C · 앞 램프 — 순광 (비교 기준)"],
	]
	for m in marks:
		var l := Label.new()
		l.text = m[1]
		l.add_theme_font_override("font", _hud_font)
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.85))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 6)
		l.z_index = 20
		l.size = Vector2(600, 40)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(float(m[0]) - 300.0, current_room.floor_y - 560.0)
		world.add_child(l)                  # 방이 다시 지어져도(R·사망) 남는다
