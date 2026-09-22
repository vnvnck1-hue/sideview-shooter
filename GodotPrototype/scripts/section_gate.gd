class_name SectionGate
extends Node2D
## **구역 문** — 같은 방 안에서 다음 구역을 가려 두었다가, 열면 **트랜지션 없이 그대로 이어 붙는** 문.
##
## 기존 측벽문과 무엇이 다른가
##   측벽문(`main.gd _go_to_room`)은 방을 **갈아 끼운다** — 페이드가 끼고, 지나온 방은 시야에서 사라진다.
##   구역 문은 갈아 끼우지 않는다. 다음 구역은 **처음부터 같은 방 안에 이미 서 있고**, 그 위에
##   불투명한 장막(curtain)이 덮여 있을 뿐이다. 문을 열면 장막이 걷히면서 이쪽 구역과 저쪽 구역이
##   **한 화면에 같이** 보인다. 카메라도 플레이어도 끊기지 않는다.
##
## 구성
##   셔터   닫혀 있는 측벽문 스프라이트. 열 때 위로 말려 올라간다(scale.y → 0, 상단 고정).
##   장막   문 너머 구역 전체를 덮는 검은 사각형. 방 바깥 어둠과 같은 색이라 "저기는 벽" 으로 읽힌다.
##   표시등 문틀의 작은 등 — 닫힘 빨강 · 열림 초록. `Docs/NEXT_TASKS_ROOM_AND_LIGHTING.md` §2 의 "문에 자기 발광" 을 여기서 처음 쓴다.
##
## 규칙
##   - 한 번 열리면 닫히지 않는다 (감각을 보는 용도라 잠금·카드키는 넣지 않았다).
##   - 닫혀 있는 동안 플레이어는 문 앞에서 멈추고(`stop_x`), 몬스터는 저쪽에서 나오지도 넘어오지도 않는다
##     (`Room.section_walls` 에 이 문의 x 가 들어가 방이 구역으로 잘린다).

signal opened(gate: SectionGate)

const OPEN_TIME := 0.85               # 셔터가 말려 올라가고 장막이 걷히는 시간 (초)
const INTERACT_RANGE := 260.0         # 이 거리 안에서 W/↑ 로 연다
const STOP_MARGIN := 150.0            # 닫힌 문 앞에서 플레이어가 멈추는 거리
const LAMP_RADIUS := 150.0

var gate_x := 0.0
var section_name := ""
var is_open := false

var _shutter: Sprite2D
var _curtain: Polygon2D
var _lamp: PointLight2D
var _opening := false


## curtain: 이 문이 가리는 구역의 월드 사각형 (문 x 부터 그 구역 끝까지, 천장 위 ~ 바닥 타일 아래)
func setup(x: float, floor_y: float, curtain: Rect2, name_of_section: String) -> void:
	gate_x = x
	section_name = name_of_section
	position = Vector2.ZERO
	z_index = DepthLayers.Z_FOREGROUND + 2       # 벽 바깥 어둠(WallShadow, +1)보다도 위

	# 장막 — 방 바깥 어둠과 같은 완전 불투명 검정. 이 너머는 "아직 없는 공간" 이다.
	_curtain = Polygon2D.new()
	_curtain.name = "Curtain"
	_curtain.color = Color(0, 0, 0, 1)
	_curtain.polygon = PackedVector2Array([
		curtain.position, Vector2(curtain.end.x, curtain.position.y),
		curtain.end, Vector2(curtain.position.x, curtain.end.y),
	])
	add_child(_curtain)

	# 셔터 — 닫힌 측벽문 그림. 위 끝을 고정하고 scale.y 로 말아 올린다.
	var tex := Lighting.textured(RoomData.SIDE_DOOR_CLOSED_TEX)
	_shutter = Sprite2D.new()
	_shutter.name = "Shutter"
	_shutter.centered = false
	_shutter.texture = tex
	_shutter.position = Vector2(x - tex.get_width() * 0.5, floor_y - tex.get_height())
	_shutter.material = Lighting.lit_material()
	add_child(_shutter)

	# 표시등 — 닫힘 빨강. 문이 어디인지 어두운 통로 끝에서도 읽힌다.
	_lamp = PointLight2D.new()
	_lamp.name = "GateLamp"
	_lamp.texture = Lighting.radial_texture()
	_lamp.position = Vector2(x, floor_y - tex.get_height() * 0.72)
	_lamp.color = Color(1.0, 0.24, 0.18)
	LightTuning.apply_plain(_lamp, "fixture", LAMP_RADIUS)
	add_child(_lamp)


## 플레이어가 이 문을 열 수 있는 거리인가 (닫혀 있을 때만)
func can_interact(px: float) -> bool:
	return not is_open and not _opening and absf(px - gate_x) <= INTERACT_RANGE


func prompt_text() -> String:
	return "▲  W / ↑  —  %s%s 가는 문 열기" % [section_name, _euro(section_name)]


## 한글 조사 "으로 / 로" — 받침이 없거나 ㄹ 받침이면 "로". 안내 문구가 "작업 구역 으로" 처럼 어색해지지 않게.
static func _euro(word: String) -> String:
	if word.is_empty():
		return "으로 "
	var c := word.unicode_at(word.length() - 1)
	if c < 0xAC00 or c > 0xD7A3:
		return "으로 "
	var jong := (c - 0xAC00) % 28
	return "로 " if jong == 0 or jong == 8 else "으로 "


## 닫힌 문 앞에서 플레이어가 멈추는 x (열려 있으면 INF)
func stop_x() -> float:
	return INF if is_open else gate_x - STOP_MARGIN


func activate() -> void:
	if is_open or _opening:
		return
	_opening = true
	_lamp.color = Color(0.35, 1.0, 0.45)        # 열리는 순간 초록
	var tw := create_tween()
	tw.set_parallel(true)
	# 셔터가 위로 말려 올라간다 (상단 고정 — centered=false 라 scale.y 가 위쪽을 축으로 준다)
	tw.tween_property(_shutter, "scale:y", 0.02, OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# 장막이 걷히며 저쪽 구역이 드러난다 — **페이드 인이 아니라 가림막이 사라지는 것**이라
	# 이쪽 구역은 한 프레임도 어두워지지 않는다.
	tw.tween_property(_curtain, "color:a", 0.0, OPEN_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_lamp, "energy", _lamp.energy * 0.45, OPEN_TIME)
	tw.chain().tween_callback(func():
		_curtain.visible = false
		_shutter.visible = false
		is_open = true
		_opening = false
		opened.emit(self)
	)
