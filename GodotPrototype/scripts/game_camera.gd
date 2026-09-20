class_name GameCamera
extends Camera2D
## 플레이어를 따라가되 마우스 포인터·캐릭터 시선 방향으로 앞을 내다보는 동적 카메라.
##
## 목표 위치 = 플레이어 X
##            + 시선 리드   (facing 방향으로 고정 거리)
##            + 마우스 리드 (화면 중심 대비 포인터 오프셋 × 가중치, 상한 클램프)
## 실제 위치는 목표를 향해 매 프레임 지수 보간(follow_speed / look_speed).
## 사격 흔들림(offset)은 이 노드가 직접 관리한다.
##
## 감도 프리셋 3종은 PRESETS 에 정의. 1/2/3 키 또는 C 키(순환)로 전환, 저장은 안 함.

signal preset_changed(index: int, preset: Dictionary)

## 프리셋 값은 모두 월드 px (줌 0.5 → 화면 가시 폭 3200px 기준).
##   mouse_weight  : 포인터가 화면 중심에서 벗어난 거리 중 카메라가 따라가는 비율
##   mouse_max_x/y : 마우스 리드 상한
##   facing_lead   : 캐릭터가 바라보는 쪽으로 항상 밀어두는 거리
##   follow_speed  : 플레이어 추적 보간 속도 (클수록 즉각적)
##   look_speed    : 리드(마우스·시선) 보간 속도
##   deadzone      : 화면 중심 근처에서 마우스 리드를 무시하는 반경 (창 px, AppFlow.VIEW_SIZE 기준 — view_scale 로 뷰 px 변환)
const PRESETS := [
	{
		"id": "steady", "name": "안정형",
		"desc": "카메라가 거의 캐릭터에 붙어 있고 천천히 따라옴. 멀미 최소",
		"mouse_weight": 0.10, "mouse_max_x": 110.0, "mouse_max_y": 0.0,
		"facing_lead": 60.0, "follow_speed": 5.0, "look_speed": 2.5, "deadzone": 90.0,
	},
	{
		"id": "standard", "name": "표준",
		"desc": "포인터 쪽으로 화면 1/3 정도까지 내다봄. 기본 권장",
		"mouse_weight": 0.32, "mouse_max_x": 360.0, "mouse_max_y": 60.0,
		"facing_lead": 150.0, "follow_speed": 9.0, "look_speed": 6.0, "deadzone": 30.0,
	},
	{
		"id": "agile", "name": "민첩형",
		"desc": "포인터를 강하게 따라가 화면 절반 가까이 내다봄. 즉각적이고 공격적",
		"mouse_weight": 0.62, "mouse_max_x": 720.0, "mouse_max_y": 130.0,
		"facing_lead": 260.0, "follow_speed": 15.0, "look_speed": 12.0, "deadzone": 0.0,
	},
]
const DEFAULT_PRESET := 1            # 표준 (확정). 1/2/3·C 키는 개발용 비교 전환으로만 남긴다
const SHAKE_DECAY := 14.0

var target: Node2D                      # Player (position.x 와 facing 사용)
## 원격 조종(단말기 → 센트리건)처럼 플레이어가 아닌 지점을 잡아 둘 때. NAN 이면 평소대로 target 을 따라간다.
## 마우스 리드는 그대로 살아 있어 포탑에서도 포인터 쪽을 조금 내다본다.
var focus_x := NAN
var base_y := 0.0                       # 방의 세로 중심
var view_scale := 1.0                   # 창 px / 이 카메라 뷰포트 px (저해상도 SubViewport 면 2)
var preset_index := DEFAULT_PRESET
var preset: Dictionary = PRESETS[DEFAULT_PRESET]

## 마우스·시선 리드를 끈다. 대화처럼 **화면이 멈춰 있어야 하는 동안** 포인터를 따라
## 카메라가 흔들리지 않게. 끄면 _lead 가 look_speed 로 0 까지 부드럽게 빠진다(툭 끊기지 않는다).
var lead_enabled := true

var _follow_x := 0.0                    # 플레이어 추적 위치 (보간됨)
var _lead := Vector2.ZERO               # 마우스·시선 리드 (보간됨)
var _shake := 0.0
var _room_width := 0.0
var _side_pad := 0.0


func _ready() -> void:
	position_smoothing_enabled = false   # 보간은 직접 처리
	process_priority = 10                # 플레이어 이동 후에 갱신


func set_preset(index: int) -> void:
	preset_index = wrapi(index, 0, PRESETS.size())
	preset = PRESETS[preset_index]
	_apply_limits()
	preset_changed.emit(preset_index, preset)


func cycle_preset() -> void:
	set_preset(preset_index + 1)


## 방 전환 직후 등 — 보간 없이 목표 위치로 즉시 이동
func snap() -> void:
	if target == null:
		return
	_follow_x = _follow_target_x()
	_lead = _desired_lead()
	_shake = 0.0
	offset = Vector2.ZERO
	position = Vector2(_follow_x + _lead.x, base_y + _lead.y)
	reset_smoothing()


## 플레이어가 아닌 지점을 잡는다 (단말기 화면 · 원격 조종 중인 포탑).
## 세로 중심까지 옮기므로 한계를 다시 잡아 준다 — 안 그러면 새 중심이 이전 한계에 걸려 잘린다.
func focus_at(pos: Vector2) -> void:
	focus_x = pos.x
	base_y = pos.y
	_apply_limits()


func clear_focus(restore_base_y: float) -> void:
	focus_x = NAN
	base_y = restore_base_y
	_apply_limits()


func add_shake(amount: float, cap := 10.0) -> void:
	_shake = minf(_shake + amount, cap)


## 방 크기에 맞춰 카메라 한계를 정한다. side_pad = 방 밖 어두운 여백 폭.
## 화면보다 넓은 방: 방 양끝 + 여백까지. 좁은 방: 가운데 기준으로 프리셋의 리드 범위만큼만 움직일 수 있게 한다.
## 세로: 방 중심 ± 화면 반높이 + 프리셋의 세로 리드 여유.
func set_room(room_width: float, side_pad: float) -> void:
	_room_width = room_width
	_side_pad = side_pad
	_apply_limits()


func _apply_limits() -> void:
	if _room_width <= 0.0:
		return
	var vp := get_viewport_rect().size / zoom          # 줌을 반영한 실제 월드 가시 크기
	var left := -_side_pad
	var right := _room_width + _side_pad
	if _is_narrow_room():
		var cx := focus_x if is_finite(focus_x) else _room_width * 0.5
		var slack := float(preset["mouse_max_x"]) + float(preset["facing_lead"])
		left = cx - vp.x * 0.5 - slack
		right = cx + vp.x * 0.5 + slack
	limit_left = int(left)
	limit_right = int(right)
	var extra := float(preset["mouse_max_y"])
	limit_top = int(base_y - vp.y * 0.5 - extra)
	limit_bottom = int(base_y + vp.y * 0.5 + extra)


func _process(delta: float) -> void:
	if target == null:
		return
	var follow_k := 1.0 - exp(-float(preset["follow_speed"]) * delta)
	var look_k := 1.0 - exp(-float(preset["look_speed"]) * delta)
	_follow_x = lerpf(_follow_x, _follow_target_x(), follow_k)
	_lead = _lead.lerp(_desired_lead(), look_k)
	position = Vector2(_follow_x + _lead.x, base_y + _lead.y)

	_shake = maxf(_shake - SHAKE_DECAY * delta * maxf(_shake, 0.5), 0.0)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


## 추적 기준점. 화면보다 좁은 방은 방 가운데를 기준으로 두고 리드만 움직인다 (플레이어가 벽 쪽에 있어도 방이 한쪽으로 쏠리지 않게).
## 단, focus_at 으로 잡아 둔 지점은 그 규칙보다 앞선다 — 단말기 화면·대화 상대를 화면 가운데로 가져오려고 잡은 것이므로.
func _follow_target_x() -> float:
	if is_finite(focus_x):
		return focus_x                       # 잡아 둔 지점이 있으면 방 크기와 상관없이 그쪽
	if _is_narrow_room():
		return _room_width * 0.5
	return target.position.x


func _is_narrow_room() -> bool:
	if _room_width <= 0.0:
		return false
	var vp := get_viewport_rect().size / zoom
	return _room_width + _side_pad * 2.0 < vp.x


## 마우스 리드 + 시선 리드 (월드 px)
func _desired_lead() -> Vector2:
	if not lead_enabled:
		return Vector2.ZERO
	var vp := get_viewport_rect().size
	var mouse_screen := get_viewport().get_mouse_position()
	var rel := mouse_screen - vp * 0.5                       # 화면 중심 기준 포인터 오프셋 (화면 px)
	var dz := float(preset["deadzone"]) / view_scale
	var len := rel.length()
	if len <= dz:
		rel = Vector2.ZERO
	else:
		rel = rel.normalized() * (len - dz)
	var world_rel := rel / zoom                               # 화면 px → 월드 px
	var lead := world_rel * float(preset["mouse_weight"])
	lead.x = clampf(lead.x, -float(preset["mouse_max_x"]), float(preset["mouse_max_x"]))
	lead.y = clampf(lead.y, -float(preset["mouse_max_y"]), float(preset["mouse_max_y"]))
	var facing := 0.0                                         # 고정 지점을 볼 때는 시선 리드가 없다
	if not is_finite(focus_x) and "facing" in target:
		facing = float(target.facing)
	lead.x += facing * float(preset["facing_lead"])
	return lead
