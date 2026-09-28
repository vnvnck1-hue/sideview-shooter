extends Node2D
## 방 로딩·전환, 카메라, HUD 를 담당하는 플레이 씬. scenes/Main.tscn(테스트: 랜덤 방) 과 scenes/MainGame.tscn(main_game.gd, 전체 맵) 이 쓴다.

const LightMood := preload("res://scripts/light_mood.gd")
const MouseRecoil := preload("res://scripts/mouse_recoil.gd")
const PropShadow := preload("res://scripts/prop_shadow.gd")
const BugbotBattle := preload("res://scripts/bugbot_battle.gd")
const DarkVision := preload("res://scripts/dark_vision.gd")
var dark_vision: CanvasLayer
var bugbot_status: Label

const WALL_MARGIN := 110.0                   # 캡 타일 안쪽 벽까지의 여유
const DOOR_PASS_MARGIN := 60.0              # 열린 측벽문으로 들어갈 때 허용되는 초과 거리
const SIDE_PAD := 180.0                      # 카메라가 방 밖 어두운 여백을 보여주는 폭
const FADE_TIME := 0.11
## 렌더 확정 (2026-09-18, "베이크 자산 · 풀해상도"): 월드는 창과 같은 크기(AppFlow.VIEW_SIZE)의 SubViewport ×1 에 그리고 카메라 zoom 0.625 —
## 그림은 4px 블록 베이크 자산(아트 1px = 월드 4px = 화면 2.5px), 조명·파티클·이동은 부드럽게(스냅 없음).
## 저해상도 뷰포트(534×300 ×3 등)·계단형 광원·원본 자산 프리셋은 비교 후 폐기. 글로우·후처리는 SubViewport 안, HUD 는 바깥.
const VIEW_SIZE := AppFlow.VIEW_SIZE     # 디자인 캔버스 (창 좌표계). 값과 근거는 AppFlow.VIEW_SIZE 주석
const VIEW_SCALE := 1
## 줌 프리셋 (F3 순환, 2026-09-19). 자산이 4px 블록 베이크라 **아트 1px = 월드 4px** 이고,
## 화면 배율 = ART_CELL × zoom 이다. 이 값이 정수가 아니면 4px 블록이 화면에서 2px·3px 로 번갈아 떨어져
## 블록 크기가 들쭉날쭉해진다. 그래서 줌은 임의의 값이 아니라 **화면 배율 정수**에서만 고른다.
## 0.625(×2.5) 같은 중간값은 이 규칙을 깨므로 버렸다.
const ART_CELL := 4.0                   # 아트 1px 이 차지하는 월드 px (베이크 규칙)

## px = 아트 1px 이 화면에서 차지하는 px. zoom = px / ART_CELL.
## 2026-09-25: 캔버스가 창 비율을 따라 늘어나게(stretch aspect=expand) 바뀌면서 **표준 배율은 캔버스 높이로 정한다.**
## 고정 ×3 이면 세로가 긴 화면(예: 2400×1600)에서 보이는 월드가 2133px 로 늘어나 방이 검은 여백에 뜬다.
## 그래서 보이는 월드 높이가 VISIBLE_H_TARGET 에 가장 가까운 정수 배율을 고르고(최소 ×3), 프리셋은 표준에서 몇 단계인지로 적는다.
##   900 높이 → ×3 (보이는 월드 1200) · 1080 → ×3 (1440) · 1600 → ×4 (1600)
##   넓게 = 표준 −1 · 가깝게 = 표준 +1
const VISIBLE_H_TARGET := 1500.0
const STANDARD_PX_MIN := 3
const ZOOM_PRESETS := [
	{"id": "wide", "name": "넓게", "step": -1},
	{"id": "standard", "name": "표준", "step": 0},
	{"id": "close", "name": "가깝게", "step": 1},
]
const ZOOM_DEFAULT := 1

## 단말기 접속·대화는 기본 줌에서 몇 **단계**(화면 배율 +1 = zoom +0.25) 더 밀어 넣는가로 정한다.
## 고정 배수(×1.5 등)로 잡으면 정수 배율이 깨지므로 단계로 센다.
## ## 보행 기체에 접속한 동안의 화면 (2026-09-23)
## 기체의 눈으로 보는 화면은 **내 눈으로 보는 화면과 달라야 한다.** 셋을 함께 건다:
##   · CRT 프리셋이 한 단 낡아진다 (CrtPreset.DEFAULT 아케이드 모니터 → LINKED 가정용 TV — 굽음·색 번짐·잡음·흐르는 띠)
##   · 화면이 **천천히 조금 물러난다** (2초에 걸쳐. 기체가 사람보다 넓게 보는 눈을 가졌다는 뜻)
##   · 조종 내내 **가끔 지지직거린다** (LINK_GLITCH_GAP — 접속 중이라는 것을 계속 상기시킨다)
##
## 줌 배율만은 "화면 배율 정수" 규칙(아래 줌 절 참고)에서 **일부러 벗어난다.** 정수 단계로 끊으면
## 2초 줌아웃이 계단으로 튀어 연출이 죽는다. 대신 이 구간에는 가정용 TV 프리셋의 주사선·잡음이
## 얹혀 있어 픽셀 격자가 어긋나는 것이 눈에 띄지 않는다 — 그래서 둘을 **같이** 건다.
const LINK_ZOOM := 0.86                # 접속 중 줌 배율 (1 보다 작을수록 물러난다)
const LINK_ZOOM_TIME := 2.0            # 그만큼 물러나는 데 걸리는 시간
const LINK_ZOOM_BACK := 0.35           # 돌아올 때는 빠르게 (해제 글리치에 묻힌다)
const LINK_GLITCH_GAP := Vector2(4.5, 9.0)   # 조종 중 지지직 간격 (초, 이 범위에서 무작위)
const LINK_GLITCH_POWER := Vector2(0.18, 0.34)  # 그 지지직의 세기 범위 — 약하게, 거슬리지 않게

const TERMINAL_ZOOM_STEP := 2           # 접속하면 화면 배율 +2 (×3 → ×5)
const DIALOGUE_ZOOM_STEP := Vector2i(1, 3)   # 대화 줌이 오갈 수 있는 단계 범위 (기본 +1 ~ +3)


var zoom_index := ZOOM_DEFAULT
var zoom_label: Label                   # 우상단: 줌 프리셋 (F3)
var shadow_label: Label                 # 우상단 둘째 줄: 기본 그림자 프리셋 (F6)
var dyn_shadow_label: Label             # 우상단 셋째 줄: 동적 광원 그림자 프리셋 (F8)
var idle_label: Label                   # 우상단 넷째 줄: 아이들 모션 프리셋 (F5)
var mark_label: Label                   # 우상단 다섯째 줄: 탄흔 프리셋 (F9)
var hit_fx_label: Label                 # 우상단 여섯째 줄: 몬스터 피격 컬러 (숫자 1~4)
var fog_label: Label                    # 우상단 일곱째 줄: 바닥 안개 프리셋 (F2)

var world_vp: SubViewport                  # 월드 뷰포트
var world: Node2D                          # 방·플레이어·탄 등 월드 노드의 부모 (world_vp 안)
var current_room: Room
var player: Player
var camera: GameCamera
var bullets: Node2D
var fade: ColorRect
var title_label: Label
var hint_label: Label
var prompt_label: Label
var ammo_label: Label
var crosshair: Crosshair
var transitioning := false
const HEAT_BAR := Vector2(300, 20)      # 센트리건 과열 게이지 크기
var heat_bar_bg: ColorRect
var heat_bar_fill: ColorRect
## 조종 중인 **기계** (없으면 null) — 그동안 플레이어 입력은 꺼진다.
## 센트리건(SentryTurret)과 사족보행 기체(WalkerUnit) 둘 다 들어온다. 둘은 같은 창구
## (heat / overheated / aim_target / set_controlled / control_changed)를 내므로 여기서는 구분하지 않는다 —
## **조종 상태를 한 자리에서만 관리하기 위해서다.** 기계마다 변수를 따로 두면 하나를 놓친 순간
## 플레이어 입력이 영영 안 돌아온다.
var controlled_turret: Node2D
## 보행 기체 접속 연출 (walker_link.gd). 연출만 하고 무엇을 바꿀지는 모른다 — 콜백으로 받는다
var walker_link: WalkerLink
var _link_zoom := 1.0                   # 기체 접속 중 줌 배율 (_base_zoom 에 곱해진다)
var _link_zoom_tw: Tween
var _link_glitch_t := 0.0               # 다음 "접속 중" 지지직까지 남은 시간 (초)
## 단말기 접속 (Docs/TERMINAL_SYSTEM_CONCEPT.md). 화면 안은 TerminalScreen 이, 카메라·월드 교체는 여기가 맡는다.
const TERMINAL_PUSH := 0.45             # 카메라 밀어넣기/후퇴 시간 (초)
var terminal_screen: TerminalScreen
var active_terminal: AccessTerminal     # 지금 접속 중인 단말기 (원격으로 넘어가면 잠시 null 이 된다)
var terminal_busy := false              # 접속/종료 연출 중 — 입력을 받지 않는다
var remote_link := {}                   # 원격 조종 중 돌아갈 곳 {"room", "x", "facing", "terminal_id", "sentry_id"}
## NPC 대화. 말풍선 **안**(타자·떨림·선택지)은 DialogueBubble 이, 나무 걷기는 DialogueRuntime 이 맡고
## 여기는 **바깥**만 맡는다: 카메라를 말하는 사람 쪽으로 밀어 넣기 · 조작 잠그기 · HUD 감추기.
## 대화 줌은 고정값이 아니라 **두 사람 사이 거리**에서 나온다 — 나란히 선 둘이 늘 같은 크기로 잡히게.
## 화면에 담을 폭 = 두 사람 간격 + DIALOGUE_FRAME, 줌은 그 폭이 화면을 채우는 값 (한계 안으로 자른다).
const DIALOGUE_FRAME := 816.0           # 두 사람 바깥으로 남기는 여백 (월드 px)
const DIALOGUE_PUSH := 0.55             # 처음 밀어 넣는 시간 (초)
const DIALOGUE_PAN := 0.40              # 말하는 사람이 바뀔 때 옮겨 가는 시간
const DIALOGUE_BIAS := 0.42             # 두 사람 가운데에서 말하는 쪽으로 치우치는 비율
var dialogue: DialogueRuntime
var dialogue_bubble: DialogueBubble
var talking_npc: Npc                    # 지금 대화 중인 상대 (없으면 null)
var _mouse_before_talk := Vector2(-1.0, -1.0)   # 대화 직전 포인터 자리 — 끝나면 여기로 돌려준다
var _post_mat: ShaderMaterial
var _aberration := 0.0
var _recoil := MouseRecoil.new()          # 사격 반동 → 실제 마우스 포인터 이동

const SHAKE_PER_SHOT := 3.5
const PLAYER_HIT_KNOCKBACK := 480.0   # 독액에 맞았을 때 밀리는 속도 (px/s)
## 색수차 (화면 px = 뷰 px, 풀해상도)
const ABERRATION_PER_SHOT := 3.3
const ABERRATION_CAP := 9.0
const ABERRATION_PLAYER_HIT := 5.25
const ABERRATION_DECAY := 18.0


func _ready() -> void:
	var room_id := AppFlow.start_room if RoomData.has_room(AppFlow.start_room) else RoomData.START_ROOM
	Lighting.apply_light_range()
	_setup_input_map()
	_setup_view()
	_setup_environment()
	_setup_ui()
	terminal_screen = TerminalScreen.new()
	terminal_screen.name = "TerminalScreen"
	terminal_screen.link_requested.connect(_on_terminal_link)
	terminal_screen.unlink_requested.connect(_on_terminal_unlink)
	terminal_screen.close_requested.connect(_on_terminal_close)
	add_child(terminal_screen)

	dialogue_bubble = DialogueBubble.new()
	dialogue_bubble.name = "DialogueBubble"
	# 표시 방식은 "자막"으로 확정됐다. style_index 는 static 이라 대화 UI 랩을 들렀다 오면
	# 그 값이 따라오므로, 게임 화면은 들어올 때마다 확정값으로 되돌린다.
	dialogue_bubble.set_style(DialogueBubble.FIXED_STYLE)
	(get_node("UI") as CanvasLayer).add_child(dialogue_bubble)
	dialogue = DialogueRuntime.new()
	dialogue.name = "Dialogue"
	dialogue.setup(dialogue_bubble)
	dialogue.anchor_provider = _speaker_anchor
	dialogue.line_started.connect(_on_dialogue_line)
	dialogue.speaker_changed.connect(_on_dialogue_speaker)
	dialogue.finished.connect(_on_dialogue_finished)
	add_child(dialogue)

	player = Player.new()
	player.name = "Player"
	player.z_index = 5
	player.shoot_fired.connect(_on_player_shoot)
	player.shell_ejected.connect(_on_shell_ejected)
	player.request_front_door.connect(_on_front_door_requested)
	player.ammo_changed.connect(_on_ammo_changed)
	player.health_changed.connect(_on_obstacle_health_changed)
	player.incapacitated.connect(_on_obstacle_incapacitated)

	bullets = Node2D.new()
	bullets.name = "Bullets"
	bullets.z_index = 6

	camera = GameCamera.new()
	camera.name = "Camera"
	camera.zoom = Vector2(_base_zoom(), _base_zoom())
	camera.target = player
	camera.base_y = RoomData.TILE_HEIGHT * 0.5
	camera.view_scale = float(VIEW_SCALE)

	crosshair = Crosshair.new()
	crosshair.name = "Crosshair"
	crosshair.z_index = 20
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	Audio.attach_to_world(world)
	Audio.set_listener(player)
	world.add_child(player)
	_on_ammo_changed(player.ammo, player.magazine_size(), player.reloading)
	world.add_child(bullets)
	world.add_child(crosshair)
	world.add_child(camera)
	dark_vision = DarkVision.new()
	dark_vision.name = "DarkVision"
	dark_vision.game = self
	world_vp.add_child(dark_vision)
	# Keep the aiming reticle readable even when aiming into unseen space.
	var reticle_layer := CanvasLayer.new()
	reticle_layer.name = "Reticle"
	reticle_layer.layer = 11
	reticle_layer.follow_viewport_enabled = true
	world_vp.add_child(reticle_layer)
	crosshair.reparent(reticle_layer, false)
	var spawn_x := RoomData.room_width(room_id) * 0.5
	var face_dir := 1
	var cam_preset := GameCamera.DEFAULT_PRESET
	if AppFlow.resume_x >= 0.0:                 # 프리셋 전환(재로드) 뒤 이어서
		spawn_x = AppFlow.resume_x
		face_dir = AppFlow.resume_facing
		AppFlow.resume_x = -1.0
	_load_room(room_id, spawn_x, face_dir)
	camera.make_current()
	camera.set_preset(cam_preset)
	camera.snap()


## ── 줌 ─────────────────────────────────────────────────────────────────────
## 모든 줌 값은 "화면 배율 정수"에서 나온다. 여기를 거치지 않고 카메라 zoom 에 값을 직접 넣지 말 것.
func _zoom_of(px: int) -> float:
	return float(px) / ART_CELL


func _base_px() -> int:
	return _preset_px(zoom_index)


## 지금 캔버스에서 표준 프리셋의 화면 배율 (위 VISIBLE_H_TARGET 주석)
func _standard_px() -> int:
	return maxi(STANDARD_PX_MIN, roundi(_view_px().y * ART_CELL / VISIBLE_H_TARGET))


func _preset_px(i: int) -> int:
	return maxi(1, _standard_px() + int(ZOOM_PRESETS[i]["step"]))


## 월드가 그려지는 캔버스 크기 (창 px). 창 비율에 따라 늘어나므로 VIEW_SIZE(최소 보장 크기)가 아니라 이것을 쓴다.
func _view_px() -> Vector2:
	if world_vp != null:
		return Vector2(world_vp.size)
	return get_viewport().get_visible_rect().size


## 기본 줌. 기체에 접속한 동안에는 _link_zoom 이 곱해져 화면이 조금 물러나 있다
## (LINK_ZOOM 주석 참고 — 이 구간만 정수 배율 규칙에서 벗어난다).
func _base_zoom() -> float:
	return _zoom_of(_base_px()) * _link_zoom


func _terminal_zoom() -> float:
	return _zoom_of(_base_px() + TERMINAL_ZOOM_STEP)


func _cycle_zoom() -> void:
	zoom_index = (zoom_index + 1) % ZOOM_PRESETS.size()
	_update_zoom_label()
	if camera == null:
		return
	var to := _talk_zoom() if dialogue.active else (_terminal_zoom() if terminal_screen.is_open() else _base_zoom())
	var tw := create_tween()
	tw.tween_property(camera, "zoom", Vector2(to, to), 0.18) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_zoom_label() -> void:
	if zoom_label == null:
		return
	var p: Dictionary = ZOOM_PRESETS[zoom_index]
	var px := _base_px()
	zoom_label.text = "줌 (F3)  %s ×%d  ·  아트 1px = 화면 %dpx" % [p["name"], px, px]


## F3: 다음 프리셋. 방·대화·단말기 상태와 무관하게 기준 줌만 갈아 끼우고, 지금 카메라에 바로 반영한다.
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_fullscreen"):
		AppFlow.toggle_fullscreen(get_tree())

	# F1: 로비로
	if Input.is_action_just_pressed("to_lobby") and not transitioning:
		terminal_screen.force_close()        # 로비까지 녹색 프리셋이 따라가지 않게
		if dialogue.active:
			_lock_mouse(false)
		dialogue.stop()
		NpcState.reset()                     # 새 회차 — 들은 말과 약속을 지운다
		AppFlow.go_lobby(get_tree())
		return

	# 줌 프리셋 순환 (F3)
	if not transitioning and Input.is_action_just_pressed("zoom_cycle"):
		_cycle_zoom()
		return

	# 기본 그림자 프리셋 순환 (F6 다음 · Shift+F6 이전)
	if not transitioning and Input.is_action_just_pressed("shadow_cycle"):
		var step := -1 if Input.is_key_pressed(KEY_SHIFT) else 1
		set_prop_shadow(PropShadow.index + step)
		return

	# 동적 광원 그림자 프리셋 순환 (F8 다음 · Shift+F8 이전)
	if not transitioning and Input.is_action_just_pressed("shadow_dyn_cycle"):
		var dstep := -1 if Input.is_key_pressed(KEY_SHIFT) else 1
		set_dyn_shadow(PropShadow.dyn_index + dstep)
		return

	# 탄흔 프리셋 순환 (F9 다음 · Shift+F9 이전) — 새로 박히는 자국부터 바뀐다
	if not transitioning and Input.is_action_just_pressed("mark_cycle"):
		var mstep := -1 if Input.is_key_pressed(KEY_SHIFT) else 1
		set_mark_preset(BulletMark.preset_index + mstep)
		return

	# 바닥 안개 프리셋 순환 (F2 다음 · Shift+F2 이전) — 지금 방에 바로 반영된다
	if not transitioning and Input.is_action_just_pressed("fog_cycle"):
		var fstep := -1 if Input.is_key_pressed(KEY_SHIFT) else 1
		set_fog_preset(GroundFog.index + fstep)
		return

	# 아이들 모션 프리셋 순환 (F5 다음 · Shift+F5 이전) — 가만히 서서 바로 비교한다
	if not transitioning and Input.is_action_just_pressed("idle_cycle"):
		var istep := -1 if Input.is_key_pressed(KEY_SHIFT) else 1
		set_idle_preset(Player.idle_index + istep)
		return

	# 숫자 1~4: 모든 현재·이후 크롤러의 피격 컬러를 즉시 바꾸고 무피해 플래시로 확인한다.
	for i in range(4):
		if Input.is_action_just_pressed("hit_fx_%d" % (i + 1)):
			set_monster_hit_fx(i)
			return

	if current_room == null:
		return
	if bugbot_status != null:
		bugbot_status.visible = not dialogue.active and not terminal_screen.is_open()
		bugbot_status.text = current_room.bugbot_battle.status_text() if is_instance_valid(current_room.bugbot_battle) else "F10 버그봇 3대 소환 · 자동 사냥 전투"
	if Input.is_action_just_pressed("bugbot_battle") and not transitioning and not dialogue.active \
			and not terminal_busy and not terminal_screen.is_open() and controlled_turret == null and not walker_link.busy():
		_toggle_bugbot_battle()

	# 대화 중에는 **마우스가 아무것도 움직이지 못한다** — 포인터는 잡아 두고(MOUSE_MODE_CAPTURED),
	# 카메라 리드도 꺼 두고(camera.lead_enabled), 조준점·반동 계산 자체를 건너뛴다.
	# 말풍선 꼬리만 카메라를 따라 말하는 사람을 계속 가리킨다.
	if dialogue.active:
		dialogue_bubble.move_anchor(_speaker_anchor(dialogue.current_speaker))
		return

	# 사격 반동: 포인터를 실제로 밀어 올린다 (창 좌표 기준 — 루트 뷰포트)
	_recoil.tick(get_viewport(), _delta)

	# 조준: 마우스 포인터의 월드 좌표가 곧 탄착 지점
	var mouse_world := world.get_global_mouse_position()
	crosshair.position = mouse_world
	# 조준점: 소총 모드는 연사 열로 벌어지고, 센트리건 조종 중에는 총열 과열이 링으로 표시된다
	if controlled_turret != null:
		# 보행 기체는 연사할수록 산포가 커진다 (WalkerUnit.spread_ratio). 센트리건은 그 창구가 없어 0 이다.
		crosshair.heat = controlled_turret.spread_ratio() if controlled_turret.has_method("spread_ratio") else 0.0
		crosshair.sentry_heat = controlled_turret.heat
		crosshair.sentry_overheated = controlled_turret.overheated
	else:
		crosshair.heat = player.spread_ratio()
	if not transitioning:
		player.aim_target = mouse_world

	# 단말기 접속 중에는 월드 조작이 전부 멈춘다. 원격 조종일 때만 포신·조준점이 살아 있다.
	if terminal_busy or terminal_screen.is_open():
		if terminal_screen.in_remote() and controlled_turret != null:
			controlled_turret.aim_target = mouse_world
			terminal_screen.set_remote_heat(controlled_turret.heat, controlled_turret.overheated)
		return

	# 센트리건 조종 중: 마우스가 포신을 끌고, **S / Ctrl / ↓** 로 손을 뗀다 (플레이어 입력은 꺼져 있다).
	# 잡기(W/↑)와 놓기가 같은 키면 전개 직후 바로 풀리는 등 오작동이 잦아 키를 나눴다.
	if controlled_turret != null:
		controlled_turret.aim_target = mouse_world
		if not transitioning and Input.is_action_just_pressed("crouch"):
			# 보행 기체는 **접속을 끊는** 연출을 타고 내린다 (포탑은 손만 떼면 되므로 그대로).
			# 원격(단말기)일 때는 단말기가 제 글리치를 이미 내므로 여기서 또 겹치지 않는다.
			var machine := controlled_turret
			if machine is WalkerUnit and remote_link.is_empty():
				_set_world_hud(false)
				walker_link.link_out(func(): machine.set_controlled(false))
			else:
				machine.set_controlled(false)

	_tick_link_glitch(_delta)

	# 카메라 추적·마우스/시선 리드·흔들림은 GameCamera 가 스스로 처리한다
	# 사격 색수차: 흔들림과 같은 리듬으로 빠르게 빠진다
	_aberration = maxf(_aberration - ABERRATION_DECAY * _delta * maxf(_aberration, 0.4), 0.0)
	_post_mat.set_shader_parameter("aberration", _aberration)
	# 피격 열 잔광이 식는다 (벽·문·프랍 표면)
	HeatSurface.tick_all(_delta)

	if transitioning:
		return

	# 측벽문 통과 판정
	if current_room.right_door_open and player.position.x >= current_room.width - 10:
		_go_to_room(current_room.right_target, "left")
	elif current_room.left_door_open and player.position.x <= 10:
		_go_to_room(current_room.left_target, "right")

	# 머리 위 말걸기 표식은 거리만 보고 켠다 (안내 문구보다 먼저 — 가려져도 표식은 보여야 한다)
	var near_npc := current_room.npc_near(player.position.x)
	for n in current_room.npcs:
		n.set_in_range(n == near_npc and DialogueRuntime.has_dialogue(n.npc_id))
		n.player_x = player.position.x          # 어슬렁거리는 인물이 플레이어를 뚫고 지나가지 않게
		if n == near_npc:
			n.look_at_x(player.position.x)

	# 접속 연출이 도는 동안에는 안내 문구를 접는다 — 화면은 연출의 것이고, 이 블록은 매 프레임
	# 문구를 다시 켜므로 _set_world_hud(false) 한 번으로는 연출 위로 도로 올라온다 (실제로 그랬다).
	if walker_link.busy():
		prompt_label.visible = false
		return

	# 안내 문구: 센트리건·보행 기체가 먼저(같은 W/↑ 키를 쓴다), 그 다음 생존자·단말기, 없으면 정면문
	var turret := current_room.sentry_near(player.position.x)
	if turret != null:
		prompt_label.visible = true
		prompt_label.text = turret.prompt_text()
		return
	var unit := current_room.walker_near(player.position.x)
	if unit != null:
		prompt_label.visible = true
		prompt_label.text = unit.prompt_text()
		return
	if near_npc != null and DialogueRuntime.has_dialogue(near_npc.npc_id):
		prompt_label.visible = true
		prompt_label.text = near_npc.prompt_text()
		return
	var terminal := current_room.terminal_near(player.position.x)
	if terminal != null:
		prompt_label.visible = true
		prompt_label.text = terminal.prompt_text()
		return
	if player.is_climbing():
		prompt_label.visible = true
		prompt_label.text = "W / ↑  오르기   ·   S / ↓  내리기   ·   A / D  손 놓기"
		return
	if current_room.ladder_near(player.position.x) != null:
		prompt_label.visible = true
		prompt_label.text = "▲  W / ↑  —  사다리 오르기"
		return
	var fd := current_room.front_door_near(player.position.x)
	prompt_label.visible = not fd.is_empty()
	if fd.is_empty() and not player.is_airborne():
		# 가장 가까운 것(바라보는 쪽 우선) — 배열 순서대로 고르면 등 뒤 프랍 이름이 뜬다
		var best: ObstacleProp = null
		var best_gap := INF
		for obstacle in current_room.obstacles:
			if obstacle.destroyed:
				continue
			var dx: float = obstacle.position.x - player.position.x
			var gap: float = absf(dx) - obstacle.rect.size.x * 0.5
			if gap < 110.0:
				gap += 0.0 if signf(dx) == float(player.facing) else 90.0
				if gap < best_gap:
					best_gap = gap
					best = obstacle
		if best != null:
			prompt_label.visible = true
			prompt_label.text = "%s · %s" % [ObstacleProp.SPECS[best.kind].name, ObstacleProp.SPECS[best.kind].hint]
	if not fd.is_empty():
		prompt_label.text = "▲  W / ↑  —  %s 으로 들어가기" % RoomData.get_room(fd["target"])["title"]


func _load_room(id: String, spawn_x: float, face_dir: int) -> void:
	if controlled_turret != null:
		_on_turret_control(false, controlled_turret)     # 방을 떠나면 조종은 풀린다
	if current_room:
		current_room.queue_free()
	for b in bullets.get_children():
		b.queue_free()
	HeatSurface.clear_all()
	BulletMark.clear_all()

	AppFlow.visit(id)                                   # 단말기 지도(StationMap)의 안개를 걷는 기록
	current_room = Room.new()
	current_room.name = "Room_" + id
	current_room.build(id)
	if id == ObstaclePlaytest.ROOM_ID and current_room.foreground != null:
		current_room.foreground.visible = false
	current_room.player = player
	current_room.player_hit.connect(_on_player_hit)
	current_room.obstacle_exploded.connect(_on_obstacle_exploded)
	current_room.obstacle_broken.connect(_on_obstacle_broken)
	current_room.monster_roared.connect(_on_monster_roared)
	current_room.monster_slammed.connect(_on_monster_slammed)
	current_room.monster_died.connect(_on_monster_died)
	world.add_child(current_room)
	world.move_child(current_room, 0)
	Audio.set_room_ambience(id)
	for t in current_room.terminals:
		t.access_requested.connect(_on_terminal_access)
	for n in current_room.npcs:
		n.talk_requested.connect(_on_npc_talk)
	for t in current_room.sentries:
		t.shoot_fired.connect(_on_turret_shoot)
		t.shell_ejected.connect(_on_turret_shell)
		t.heat_changed.connect(_on_turret_heat)
		t.shake_requested.connect(camera.add_shake)
		t.control_changed.connect(_on_turret_control.bind(t))
	# 사족보행 기체도 **완전히 같은 배선**이다 — 사격까지 센트리건 경로를 그대로 탄다.
	# (연사력만 기체 쪽에서 낮다. 위력·궤적·탄피·흔들림은 WalkerUnit 이 SentryTurret 값을 그대로 쓴다)
	for w in current_room.walkers:
		w.shoot_fired.connect(_on_bugbot_shoot.bind(w))
		w.shell_ejected.connect(_on_turret_shell)
		w.heat_changed.connect(_on_turret_heat)
		w.shake_requested.connect(camera.add_shake)
		w.control_changed.connect(_on_turret_control.bind(w))

	# 이동 한계: 닫힌 쪽은 벽 앞에서 멈추고, 열린 쪽은 문을 지나갈 수 있게 조금 더 허용
	var left_limit := -DOOR_PASS_MARGIN if current_room.left_door_open else WALL_MARGIN
	var right_limit := current_room.width + DOOR_PASS_MARGIN if current_room.right_door_open else current_room.width - WALL_MARGIN
	player.settle()
	player.weapon_room = current_room
	player.position = Vector2(spawn_x, current_room.floor_y + 2)
	if player.health <= 0.0:
		player.restore_health()
	player.set_bounds(left_limit, right_limit)
	player.face(face_dir)

	_apply_camera_limits()
	var data := RoomData.get_room(id)
	title_label.text = "%s  ›  %s" % [data["zone"], data["title"]]


func _apply_camera_limits() -> void:
	# 세로는 바닥선 프레이밍(GameCamera.set_floor) — 바닥이 늘 화면 2/3 높이쯤에 선다.
	# base_y(방 세로 중심)는 바닥선 프레이밍을 끈 씬을 위한 예비값으로만 남긴다.
	var rect := RoomData.room_rect(current_room.room_id)
	camera.base_y = rect.get_center().y
	camera.set_floor(float(current_room.floor_y), rect.position.y)
	camera.set_room(float(current_room.width), SIDE_PAD)


## 측벽문으로 이동. enter_side = 목표 방에서 등장하는 쪽("left"/"right")
func _go_to_room(target: String, enter_side: String) -> void:
	var target_w := RoomData.room_width(target)
	var spawn_x := 120.0 if enter_side == "left" else target_w - 120.0
	var face_dir := 1 if enter_side == "left" else -1
	_transition(target, spawn_x, face_dir)


func _on_front_door_requested() -> void:
	if transitioning or current_room == null:
		return
	# 공중(점프 중)에서는 사다리 잡기만 받는다 — 문·단말기는 땅에 서서 쓴다
	if player.is_airborne():
		_grab_ladder()
		return
	# 같은 키(W/↑)로 센트리건·보행 기체를 먼저 잡는다 — 옆에 서 있으면 전개·기동·조종
	var turret := current_room.sentry_near(player.position.x)
	if turret != null:
		turret.activate()
		return
	var unit := current_room.walker_near(player.position.x)
	if unit != null:
		# 기체는 **소프트웨어에 접속하듯** 탄다. 연출 한가운데(화면이 한 번 튀는 순간)에
		# 카메라 주체와 기동을 함께 넘긴다 — 그래야 "내가 지금 누구인가" 가 한 박자도 흐려지지 않는다.
		# 이미 조종 중이면 연출 없이 그대로 둔다 (activate 는 그 경우 아무 일도 하지 않는다).
		if unit.controlled or walker_link.busy():
			unit.activate()
			return
		# 연출이 도는 동안 플레이어가 걸어 나가지 않게 세워 둔다.
		# 조종이 실제로 넘어가면 _on_turret_control 이 이어받고, 어떤 이유로든 넘어가지 않으면
		# 연출이 끝날 때 _on_link_finished 가 조작을 돌려준다 — 어느 쪽이든 갇히지 않는다.
		player.input_enabled = false
		player.velocity_x = 0.0
		_set_world_hud(false)                      # 연출이 도는 동안 화면은 연출의 것이다
		walker_link.link_in(unit.display_name, func():
			_camera_subject(unit)
			unit.activate())
		return
	var person := current_room.npc_near(player.position.x)
	if person != null and DialogueRuntime.has_dialogue(person.npc_id):
		person.activate()
		return
	var terminal := current_room.terminal_near(player.position.x)
	if terminal != null:
		terminal.activate()
		return
	if _grab_ladder():
		return
	var fd := current_room.front_door_near(player.position.x)
	if fd.is_empty():
		# 같은 키의 마지막 순위 — 옆에 쓸 것이 아무것도 없으면 제자리 점프
		player.jump()
		return
	var target: String = fd["target"]
	var spawn_x := RoomData.front_door_center(target, int(fd["target_door"]))
	_transition(target, spawn_x, player.facing)


## 옆에 사다리가 있으면 잡는다 (잡았으면 true)
func _grab_ladder() -> bool:
	var ladder := current_room.ladder_near(player.position.x)
	if ladder == null:
		return false
	player.start_climb(ladder.position.x, ladder.climb_height())
	return player.is_climbing()


func _transition(target: String, spawn_x: float, face_dir: int) -> void:
	transitioning = true
	player.input_enabled = false
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, FADE_TIME)
	tw.tween_callback(func():
		_load_room(target, spawn_x, face_dir)
		camera.snap()
	)
	tw.tween_property(fade, "color:a", 0.0, FADE_TIME)
	tw.tween_callback(func():
		transitioning = false
		player.input_enabled = true
	)


## 플레이어 한 발. 기존 소총 경로(흔들림 · 색수차 · 조준점 벌어짐 · 마우스 반동)를 그대로 타고,
## 무기 수치(WeaponCatalog)만큼 세게 준다. 몬스터에 제대로 박히면(산탄 3알 이상 · 코일 관통 · 처치) 히트스톱.
func _on_player_shoot(muzzle_pos: Vector2, target_pos: Vector2) -> void:
	var id: String = player.weapon_id
	var d := WeaponCatalog.data(id)
	var aim := (target_pos - muzzle_pos).normalized()
	WeaponFx.spawn(bullets, id, "muzzle", muzzle_pos, aim, 1.0)
	var shot := WeaponProjectile.fire(bullets, current_room, id, muzzle_pos, target_pos, camera)
	camera.add_shake(float(d.shake))
	_aberration = minf(_aberration + ABERRATION_PER_SHOT * 1.8, ABERRATION_CAP)
	crosshair.kick()
	_recoil.kick(float(player.facing))
	if shot.kills > 0 or shot.total_hits >= 3 or (id == WeaponCatalog.COIL and shot.total_hits > 0):
		HitStop.apply(get_tree(), float(d.hitstop) * (1.35 if shot.kills > 0 else 1.0))


## 센트리건 사격 — 탄·탄착은 플레이어와 같은 경로지만 궤적은 2배 굵고(TRACER_SCALE) 탄착·피격 반응은
## 위력 1.7배(SHOT_POWER: 큰 탄착 · 멀리 튀는 파편 · 몬스터 넉백·체액·육편). 흔들림은 센트리건이 따로 요청한다.
func _on_turret_shoot(muzzle_pos: Vector2, target_pos: Vector2) -> void:
	_spawn_shot(muzzle_pos, target_pos, SentryTurret.SHOT_POWER, SentryTurret.TRACER_SCALE)
	Audio.turret_fire(muzzle_pos)
	_aberration = minf(_aberration + ABERRATION_PER_SHOT * 1.3, ABERRATION_CAP)
	crosshair.kick()


func _toggle_bugbot_battle() -> void:
	if is_instance_valid(current_room.bugbot_battle):
		current_room.bugbot_battle.stop()
		return
	var battle := BugbotBattle.new()
	current_room.bugbot_battle = battle
	current_room.add_child(battle)
	battle.start(current_room, player.position.x)
	for bot in battle.bots:
		bot.shoot_fired.connect(_on_bugbot_shoot.bind(bot))
		bot.shell_ejected.connect(_on_turret_shell)


func _on_bugbot_shoot(muzzle_pos: Vector2, target_pos: Vector2, bot: WalkerUnit) -> void:
	if bot.weapon_id == WeaponCatalog.ARC:
		WeaponProjectile.fire(bullets, current_room, WeaponCatalog.ARC, muzzle_pos, target_pos, camera)
		Audio.play_at("turret_crack", muzzle_pos, 2.0, 0.7)
		Audio.play_at("fire_sub", muzzle_pos, -2.0, 1.3)
		WeaponAudio.play(bullets, muzzle_pos, "arc", -3.0, randf_range(0.94, 1.06))
		if bot.controlled:
			_aberration = minf(_aberration + ABERRATION_PER_SHOT * 1.3, ABERRATION_CAP)
			crosshair.kick()
	else:
		_spawn_shot(muzzle_pos, target_pos, WalkerUnit.SHOT_POWER, WalkerUnit.TRACER_SCALE)
		Audio.turret_fire(muzzle_pos)


## 한 발이 방에 미치는 결과 — 탄 생성 · 탄착 반응 · 전선 튕김 (플레이어·센트리건·보행 기체 공용).
## power = 탄착·피격 반응 위력 배율 (1.0 플레이어 소총 · 1.7 센트리건),
## tracer = 궤적·탄두 두께 배율 (센트리건 2.0 — 탄은 굵게, 파편·넉백은 위력만큼만).
func _spawn_shot(muzzle_pos: Vector2, target_pos: Vector2, power := 1.0, tracer := 1.0) -> void:
	# 벽은 실제로 막혀 있다 — 조준점이 벽 너머(어둠·옆방)라도 탄은 벽면에서 멈춘다
	target_pos = current_room.clip_shot(muzzle_pos, target_pos)
	var b := Bullet.new()
	b.power = power
	b.width_scale = tracer
	b.setup(muzzle_pos, target_pos)
	b.floor_y = player.position.y
	# 무엇을 맞췃나: 램프·비상등은 깨지고(유리 파편·스파크), 프랍은 흔들리며 조각나고, 벽은 붉게 달아오른다
	var hit := current_room.hit_at(target_pos)
	# 고인 물 위의 바닥을 맞히면 착수 — 물기둥이 튀고 수면이 파인다 (벽 열 잔광은 없음)
	if (hit["kind"] == "wall" or hit["kind"] == "none") and current_room.water != null and current_room.water.contains(target_pos):
		hit = {"kind": "water", "node": current_room.water}
	match hit["kind"]:
		"water":
			hit["node"].bullet_splash(target_pos.x, signf(target_pos.x - muzzle_pos.x))
			b.impact_kind = Bullet.Impact.WATER
			camera.add_shake(1.0)
		"monster":
			hit["node"].hit(target_pos, signf(target_pos.x - muzzle_pos.x), power)
			b.impact_kind = Bullet.Impact.FLESH
			camera.add_shake(1.2 * power)
		"lamp":
			# 한 발에 깨지지 않는다 — 맞을 때마다 크게 흔들리고, 체력이 다하면 터진다
			var lamp_broke: bool = hit["node"].hit_lamp(target_pos, signf(target_pos.x - muzzle_pos.x))
			b.impact_kind = Bullet.Impact.GLASS
			camera.add_shake(3.0 if lamp_broke else 1.4)
		"beacon":
			hit["node"].break_light()
			b.impact_kind = Bullet.Impact.GLASS
			camera.add_shake(2.5)
		"wall", "none":
			pass                                            # 벽·뒷벽 — 자국은 아래에서 공통으로 남긴다
		"glass":
			hit["node"].crack(target_pos)
			b.impact_kind = Bullet.Impact.GLASS
			camera.add_shake(1.5)
		"prop":
			hit["node"].hit(signf(target_pos.x - muzzle_pos.x), target_pos.y, target_pos, power)
			b.impact_kind = hit["node"].impact_kind() if hit["node"].has_method("impact_kind") else Bullet.Impact.PROP
			camera.add_shake(0.8 * (power - 1.0) + (0.9 if hit["node"] is ObstacleProp else 0.0))
	bullets.add_child(b)
	_leave_mark(hit, target_pos, target_pos - muzzle_pos, power)
	current_room.notify_shot(muzzle_pos, target_pos)      # 전선 등 물리 반응


## 탄흔 — **어느 총이든** 박힌 자리에 고열 자국을 남긴다 (BulletMark). 몬스터(체액)·물(물보라)·
## 램프/비상등/유리(깨짐·금)는 각자 반응이 따로 있어 제외. 프랍은 맞은 셀이 부서져 뚫렸으면 뒤 벽에 남긴다.
func _leave_mark(hit: Dictionary, point: Vector2, dir: Vector2, power: float) -> void:
	var host: Node2D = null
	match hit["kind"]:
		"wall", "none":
			# 탄이 뚫고 지나가는 앞쪽 물체(단말기 등)의 앞면이면 그 물체에 붙인다 — 뒷벽에 깔면 물체에 가려진다
			for sp in current_room.stain_props():
				if is_instance_valid(sp) and sp.is_solid_at(point):
					host = sp
					break
		"prop":
			var pr = hit["node"]
			if is_instance_valid(pr) and pr.is_solid_at(point):
				host = pr
		_:
			return
	var on_floor: bool = point.y >= current_room.floor_y - BulletMark.CELL * 2.0
	BulletMark.spawn(current_room, point, dir, host, power, on_floor)


func _on_ammo_changed(ammo: int, mag: int, reloading: bool) -> void:
	if reloading:
		ammo_label.text = "재장전 중…   %d" % mag
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.4))
	else:
		ammo_label.text = "%d / %d" % [ammo, mag]
		var low := ammo <= mag / 4
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if low else Color(0.95, 0.9, 0.8))
	if is_instance_valid(player):
		ammo_label.text = "%s  ·  %s\nQ 무기 교체%s" % [WeaponCatalog.data(player.weapon_id).name, ammo_label.text, "  ·  길게 눌러 충전" if player.weapon_id == WeaponCatalog.COIL else ""]


## 센트리건 총열 과열 (조종 중일 때만 HUD 를 가져간다). 탄약 대신 열이 자원이다 —
## 게이지가 차면 잠기고, 잠긴 동안엔 붉게 깜빡이는 문구로 알린다.
func _on_turret_heat(heat: float, overheated: bool) -> void:
	if controlled_turret == null:
		return
	var k := clampf(heat, 0.0, 1.0)
	heat_bar_fill.size.x = (HEAT_BAR.x - 4.0) * k
	heat_bar_fill.color = Color(1.0, 0.62, 0.26).lerp(Color(1.0, 0.24, 0.16), smoothstep(0.35, 1.0, k))
	if overheated:
		ammo_label.text = "과열!  냉각 중…"
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.28))
	else:
		ammo_label.text = "총열  %d%%" % int(k * 100.0)
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.36) if k > 0.6 else Color(0.95, 0.9, 0.8))


## 조종 시작/해제 — 조종 중엔 플레이어가 움직이지도 쏘지도 않는다(같은 마우스로 포신을 돌린다)
## 접속 연출이 끝났다. 조종이 넘어가지 않았다면(기체가 사라졌다거나) 조작을 도로 준다 —
## 연출 때문에 플레이어가 영영 못 움직이는 일만은 없어야 한다.
func _on_link_finished() -> void:
	if not terminal_screen.is_open() and not terminal_busy:
		_set_world_hud(true)
	if controlled_turret == null:
		_player_input_back()


## 기체의 눈으로 보는 화면을 켜고 끈다 — CRT 프리셋 한 단 + 천천히 물러나는 줌.
## 둘 다 여기 한 곳에서만 바뀌므로, 어떤 경로로 조종이 풀리든(방 이동·강제 해제) 원래 화면으로 돌아온다.
func _set_linked_screen(on: bool) -> void:
	var crt := get_node_or_null("/root/CrtFx")
	if crt != null:
		if on:
			crt.push_preset(CrtPreset.get_preset(CrtPreset.LINKED)["id"])
		else:
			crt.pop_preset()
	_link_glitch_t = randf_range(LINK_GLITCH_GAP.x, LINK_GLITCH_GAP.y)
	if _link_zoom_tw != null and _link_zoom_tw.is_valid():
		_link_zoom_tw.kill()
	_link_zoom_tw = create_tween()
	_link_zoom_tw.tween_method(_apply_link_zoom, _link_zoom, 1.0 if not on else LINK_ZOOM,
		LINK_ZOOM_TIME if on else LINK_ZOOM_BACK).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 줌 배율 한 걸음. 카메라에 직접 넣지 않고 _base_zoom 을 거친다 — 단말기·대화 줌과 섞이지 않게.
func _apply_link_zoom(k: float) -> void:
	_link_zoom = k
	if camera == null or terminal_screen.is_open() or dialogue.active:
		return
	var z := _base_zoom()
	camera.zoom = Vector2(z, z)


## 조종 중 **가끔** 한 번씩 지지직. 접속해 있다는 것을 계속 상기시키는 장치다 —
## 너무 잦으면 거슬리고 너무 뜸하면 잊어버린다. 연출이 도는 동안에는 건드리지 않는다.
func _tick_link_glitch(delta: float) -> void:
	if not (controlled_turret is WalkerUnit) or walker_link.busy() or terminal_screen.is_open():
		return
	_link_glitch_t -= delta
	if _link_glitch_t > 0.0:
		return
	_link_glitch_t = randf_range(LINK_GLITCH_GAP.x, LINK_GLITCH_GAP.y)
	var crt := get_node_or_null("/root/CrtFx")
	if crt != null:
		crt.channel_glitch(Callable(), 0.34, randf_range(LINK_GLITCH_POWER.x, LINK_GLITCH_POWER.y))


## 플레이어에게 조작을 돌려준다 — **돌려줘도 되는 상황일 때만.**
## 단말기 화면이 떠 있거나 방을 갈아 끼우는 중이면 그쪽이 조작을 쥐고 있어야 한다.
## 조종 해제와 접속 연출이 같은 조건을 봐야 해서 한 곳으로 모았다 (한쪽만 고치면 조작이 영영 안 돌아온다).
func _player_input_back() -> void:
	if not transitioning and not terminal_screen.is_open() and not terminal_busy:
		player.input_enabled = true


## 카메라가 **누구를 주체로 따라갈 것인가**를 정한다.
##
## 보행 기체를 조종하는 동안에는 기체가 곧 플레이어다 — 플레이어 본체는 제자리에 서 있으므로
## 그대로 두면 기체만 화면 밖으로 걸어 나간다 (포탑은 제자리에 박혀 있어 이 문제가 없었다).
## focus_at 으로 한 점을 잡는 방식도 안 된다: 그건 **고정점**이라 걸어가는 기체를 따라가지 못한다.
## 그래서 카메라의 target 자체를 갈아 끼우고 잡아 둔 초점은 푼다.
##
## 주체가 바뀌는 순간은 접속 연출(WalkerLink) 한가운데라 snap 해도 보이지 않는다.
func _camera_subject(node: Node2D) -> void:
	if node == null or camera.target == node:
		return
	camera.target = node
	if current_room != null:
		camera.clear_focus(RoomData.room_rect(current_room.room_id).get_center().y)
	camera.snap()


## 조종을 잡고 놓는 **유일한 자리.** 센트리건·보행 기체가 같이 쓴다.
func _on_turret_control(active: bool, turret: Node2D) -> void:
	if active:
		if controlled_turret != null and controlled_turret != turret:
			controlled_turret.set_controlled(false)
		controlled_turret = turret
		player.input_enabled = false
		player.velocity_x = 0.0
		heat_bar_bg.visible = remote_link.is_empty()   # 원격일 땐 단말기 머리글이 열을 보여 준다
		crosshair.set_sentry(true)                 # 조준점이 센트리건 레티클로 바뀐다
		if turret is WalkerUnit:
			_camera_subject(turret)                # 걸어다니므로 카메라가 기체를 따라간다
			_set_linked_screen(true)
			player.standby = true                  # 몸은 고개를 떨군 채 대기 상태로 남는다
		_on_turret_heat(turret.heat, turret.overheated)
	elif controlled_turret == turret:
		controlled_turret = null
		heat_bar_bg.visible = false
		crosshair.set_sentry(false)
		if turret is WalkerUnit:
			_set_linked_screen(false)
			player.standby = false
		_camera_subject(player)                    # 주체를 플레이어로 되돌린다 (방 이동·강제 해제 포함)
		_player_input_back()
		_on_ammo_changed(player.ammo, player.magazine_size(), player.reloading)


# ── 단말기 접속 ──────────────────────────────────────────────────────────────
# 흐름과 연출 근거는 Docs/TERMINAL_SYSTEM_CONCEPT.md §2. 여기는 **화면 밖**만 맡는다:
# 카메라 밀어넣기 · 월드를 원격 방으로 교체 · 플레이어 감추기 · 포탑 넘겨주기.
# 화면 안(부팅·메뉴·로그·방어 그리드)은 TerminalScreen 이 전부 처리한다.

## 단말기 옆에서 W/↑ — 카메라가 화면으로 밀려 들어가고, 그 중간쯤에서 CRT 가 켜진다
func _on_terminal_access(t: AccessTerminal) -> void:
	if terminal_busy or terminal_screen.is_open() or transitioning:
		return
	terminal_busy = true
	Audio.play("ui_tick")
	active_terminal = t
	t.set_connected(true)
	player.input_enabled = false
	player.velocity_x = 0.0
	crosshair.visible = false
	_set_world_hud(false)
	_push_camera(t.screen_point(), _terminal_zoom(), TERMINAL_PUSH)
	# 카메라가 거의 다 붙었을 때 전원이 들어온다 — 화면이 먼저 켜지면 "다가가는" 느낌이 사라진다
	await get_tree().create_timer(TERMINAL_PUSH * 0.62).timeout
	if active_terminal != t:
		return
	terminal_screen.open(t, current_room.room_id)
	terminal_busy = false


## 루트 메뉴에서 ESC — CRT 전원 차단 뒤 카메라가 물러나고 조작이 돌아온다
func _on_terminal_close() -> void:
	if terminal_busy:
		return
	terminal_busy = true
	terminal_screen.close(_finish_disconnect)


## CRT 전원이 완전히 꺼진 뒤 — 카메라가 물러나고 절반쯤 왔을 때 조작을 돌려준다
func _finish_disconnect() -> void:
	if active_terminal != null:
		active_terminal.set_connected(false)
	_release_camera(TERMINAL_PUSH)
	await get_tree().create_timer(TERMINAL_PUSH * 0.5).timeout
	active_terminal = null
	terminal_busy = false
	crosshair.visible = true
	_set_world_hud(true)
	if not transitioning:
		player.input_enabled = true


## 방어 그리드에서 기계 선택(포탑·보행 기체) — 채널 전환 글리치가 가장 어지러운 순간에 월드를 갈아 끼운다
func _on_terminal_link(entry: Dictionary) -> void:
	if terminal_busy or active_terminal == null:
		return
	terminal_busy = true
	remote_link = {
		"room": current_room.room_id, "x": player.position.x, "facing": player.facing,
		"terminal_id": active_terminal.terminal_id, "sentry_id": str(entry["id"]),
		"kind": str(entry.get("kind", "sentry")),
	}
	terminal_screen.glitch(func(): _switch_to_remote(entry))


func _switch_to_remote(entry: Dictionary) -> void:
	var target_room := str(entry["room"])
	var turret_x := float(entry["x"])
	if target_room != current_room.room_id:
		active_terminal = null                      # 이 방과 함께 사라진다 — 돌아올 때 id 로 다시 찾는다
		_load_room(target_room, turret_x, 1)
	# 포탑이냐 보행 기체냐는 entry["kind"] 가 알려 준다 (TerminalData.MACHINE_KINDS).
	# 나머지 흐름은 완전히 같다 — 둘 다 activate()/set_controlled() 을 내므로 여기서 갈리지 않는다.
	var kind := str(entry.get("kind", "sentry"))
	var turret: Node2D = current_room.walker_by_id(str(entry["id"])) if kind == "walker" 		else current_room.sentry_by_id(str(entry["id"]))
	if turret == null:
		push_warning("기계 '%s'(%s) 을(를) 찾지 못했습니다 — 링크를 되돌립니다" % [entry["id"], kind])
		_return_from_remote()
		return
	# 플레이어는 숨은 채 포탑 자리에 선다 — 몬스터가 플레이어를 쫓으므로 자연히 포탑으로 몰려온다
	player.visible = false
	player.input_enabled = false
	player.velocity_x = 0.0
	player.position.x = turret.position.x
	camera.zoom = Vector2(_base_zoom(), _base_zoom())
	camera.focus_at(Vector2(turret.position.x, _released_y()))   # 평소와 같은 바닥선 높이로 포탑을 잡는다
	camera.snap()
	turret.activate()                               # 격납 상태면 전개하고, 끝나면 스스로 조종으로 넘어온다
	crosshair.visible = true
	terminal_screen.enter_remote(entry)
	terminal_busy = false


## 원격 조종 중 ESC — 되돌아가는 것도 같은 글리치를 탄다
func _on_terminal_unlink() -> void:
	if terminal_busy or remote_link.is_empty():
		return
	terminal_busy = true
	if controlled_turret != null:
		controlled_turret.set_controlled(false)     # 포탑은 무인 대기로 남는다 (곧 스스로 격납된다)
	crosshair.visible = false
	terminal_screen.glitch(func(): _return_from_remote())


func _return_from_remote() -> void:
	if remote_link.is_empty():
		return
	var back := remote_link
	remote_link = {}
	if str(back["room"]) != current_room.room_id:
		_load_room(str(back["room"]), float(back["x"]), int(back["facing"]))
	player.visible = true
	player.input_enabled = false                    # 아직 단말기 앞에 서 있다
	player.position.x = float(back["x"])
	player.face(int(back["facing"]))
	active_terminal = current_room.terminal_by_id(str(back["terminal_id"]))
	if active_terminal != null:
		active_terminal.set_connected(true)
		camera.focus_at(active_terminal.screen_point())
	camera.zoom = Vector2(_terminal_zoom(), _terminal_zoom())
	camera.snap()
	terminal_screen.leave_remote()
	terminal_busy = false


# ── NPC 대화 ────────────────────────────────────────────────────────────────
# 말풍선 **안**(한 자씩 튀는 글자·떨림·선택지)은 dialogue_bubble.gd 가 전부 처리한다.
# 여기는 바깥만 맡는다: 조작 잠그기 · HUD 감추기 · 카메라를 **말하는 사람 쪽으로** 밀어 넣기.

## 생존자 옆에서 W/↑ — 플레이어와 상대가 서로를 보고, 카메라가 둘 사이로 밀려 들어간다
func _on_npc_talk(n: Npc) -> void:
	if dialogue.active or terminal_busy or terminal_screen.is_open() or transitioning:
		return
	if not DialogueRuntime.has_dialogue(n.npc_id):
		return
	talking_npc = n
	n.look_at_x(player.position.x)
	n.set_talking(true)
	player.input_enabled = false
	player.velocity_x = 0.0
	player.face(1 if n.position.x > player.position.x else -1)
	crosshair.visible = false
	_set_world_hud(false)
	_lock_mouse(true)
	if not dialogue.start(n.npc_id):           # 할 말이 없다 — 시작 전에 되돌린다
		_on_dialogue_finished()


## 줄이 시작될 때마다 — 말하는 쪽이 한 번 끄덕인다 (걷기 프레임이 없으니 몸짓은 전부 절차적)
func _on_dialogue_line(who: String) -> void:
	Audio.play("ui_tick")
	if talking_npc != null and who == talking_npc.npc_id:
		talking_npc.talk_beat()


## 말하는 사람이 바뀔 때만 카메라를 옮긴다. 첫 진입은 길게 밀어 넣고(DIALOGUE_PUSH),
## 그 뒤 주고받는 동안은 짧게 스쳐 간다(DIALOGUE_PAN) — 매 줄 출렁이면 멀미가 난다.
func _on_dialogue_speaker(who: String) -> void:
	if talking_npc == null:
		return
	var zoom := _talk_zoom()
	var first := absf(camera.zoom.x - zoom) > 0.02
	_push_camera(_talk_focus(who), zoom, DIALOGUE_PUSH if first else DIALOGUE_PAN)


## 두 사람이 늘 비슷한 크기로 잡히는 줌 배율. 멀리 떨어져 말을 걸면 덜 당기고, 바짝 붙어 있으면 더 당긴다.
## 계산값은 연속이지만 **화면 배율 정수 단계로 내림**해서 쓴다 — 대화 중에는 화면이 멈춰 있어
## 블록이 들쭉날쭉한 게 그대로 보인다. 내림이라 두 사람이 프레임 밖으로 밀리지 않는다.
func _talk_zoom() -> float:
	var gap := absf(talking_npc.position.x - player.position.x)
	var want := _view_px().x / (gap + DIALOGUE_FRAME)
	var px := int(floor(want * ART_CELL))
	return _zoom_of(clampi(px, _base_px() + DIALOGUE_ZOOM_STEP.x, _base_px() + DIALOGUE_ZOOM_STEP.y))


## 카메라가 잡는 점 — 두 사람 가운데에서 말하는 쪽으로 DIALOGUE_BIAS 만큼 치우친다.
## 둘 다 화면에 남으면서 "지금 누가 말하는가" 가 구도로도 읽힌다.
func _talk_focus(who: String) -> Vector2:
	var npc_p := talking_npc.focus_point()
	var player_p := player.position + Vector2(0.0, -_player_head() * 0.62)
	var to := player_p if who == "player" else npc_p
	var focus := ((npc_p + player_p) * 0.5).lerp(to, DIALOGUE_BIAS)
	# 화면보다 좁은 방에서는 두 사람이 어차피 다 보인다. 그런데도 화자 쪽으로 밀면
	# 방 밖 어둠만 더 드러나므로, 여유가 없는 만큼 방 가운데로 되돌린다.
	var room_w := float(current_room.width)
	var visible_w := _view_px().x / _talk_zoom()
	var slack := maxf((room_w + SIDE_PAD * 2.0 - visible_w) * 0.5, 0.0)
	var center := room_w * 0.5
	focus.x = clampf(focus.x, center - slack, center + slack)
	return focus


## 대화 동안 마우스를 묶는다.
##   포인터 잡기  MOUSE_MODE_CAPTURED — 창 안에 갇히고 절대 좌표가 움직이지 않는다.
##                풀 때 원래 자리로 되돌려 주므로 대화가 끝나도 조준점이 튀지 않는다.
##   카메라 리드  끈다. 안 끄면 대화 중에도 카메라가 포인터 쪽으로 계속 흘러 화면이 가만히 있지 않는다.
func _lock_mouse(on: bool) -> void:
	camera.lead_enabled = not on
	if on:
		_mouse_before_talk = get_viewport().get_mouse_position()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if _mouse_before_talk.x >= 0.0:
		get_viewport().warp_mouse(_mouse_before_talk)
		_mouse_before_talk = Vector2(-1.0, -1.0)


## 플레이어 머리 꼭대기 높이 — NPC 와 같은 표(NpcData.CAST)에서 읽는다
func _player_head() -> float:
	return float(NpcData.get_cast("player")["head"])


## 말풍선 꼬리가 가리킬 창 좌표 (말하는 사람 머리 꼭대기)
func _speaker_anchor(who: String) -> Vector2:
	var p := player.position + Vector2(0.0, -_player_head())
	if who != "player" and talking_npc != null and talking_npc.npc_id == who:
		p = talking_npc.head_point()
	return world_to_screen(p)


## 대사 나무가 끝났다 — 카메라가 물러나고 절반쯤 왔을 때 조작이 돌아온다 (단말기 종료와 같은 결)
func _on_dialogue_finished() -> void:
	if talking_npc != null:
		talking_npc.set_talking(false)
	talking_npc = null
	_lock_mouse(false)
	_release_camera(DIALOGUE_PUSH)
	await get_tree().create_timer(DIALOGUE_PUSH * 0.5).timeout
	if dialogue.active:                         # 물러나는 사이에 다시 말을 걸었다면 되돌리지 않는다
		return
	crosshair.visible = true
	_set_world_hud(true)
	if not transitioning and controlled_turret == null 			and not terminal_screen.is_open() and not terminal_busy:
		player.input_enabled = true


## 카메라를 한 지점으로 밀어 넣는다 (줌 + 중심 이동을 같은 곡선으로)
func _push_camera(to: Vector2, zoom: float, time: float) -> void:
	var from := Vector2(camera.focus_x if is_finite(camera.focus_x) else player.position.x, camera.framed_y())
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(p: Vector2): camera.focus_at(p), from, to, time) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(camera, "zoom", Vector2(zoom, zoom), time) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 밀어 넣었던 카메라를 플레이어에게 돌려준다
func _release_camera(time: float) -> void:
	var room_center_y := RoomData.room_rect(current_room.room_id).get_center().y
	var from := Vector2(camera.focus_x if is_finite(camera.focus_x) else player.position.x, camera.framed_y())
	var to := Vector2(player.position.x, _released_y())
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(p: Vector2): camera.focus_at(p), from, to, time) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "zoom", Vector2(_base_zoom(), _base_zoom()), time) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func(): camera.clear_focus(room_center_y))


## 초점을 풀었을 때 카메라가 설 세로 위치 (기본 줌에서의 바닥선 프레이밍).
## 돌아오는 트윈이 여기로 도착해야 초점이 풀리는 순간 화면이 튀지 않는다.
func _released_y() -> float:
	var keep := camera.focus_x
	camera.focus_x = NAN
	var y := camera.framed_y(_base_zoom())
	camera.focus_x = keep
	return y


## 월드 HUD 표시/숨김 — 단말기 화면이 시야를 채우는 동안은 방 이름·탄창·힌트가 남아 있으면 안 된다.
## MainGame 이 탐색 라벨을 더해 덮어쓴다.
func _set_world_hud(shown: bool) -> void:
	title_label.visible = shown
	hint_label.visible = shown
	zoom_label.visible = shown
	ammo_label.visible = shown
	prompt_label.visible = false
	if not shown:
		heat_bar_bg.visible = false


## 몬스터 독액에 맞음: 카메라 흔들림 + 색수차 + 플레이어 밀림 (체력은 아직 없음)
func _on_player_hit(_point: Vector2, dir: float) -> void:
	camera.add_shake(7.0)
	_aberration = minf(_aberration + ABERRATION_PLAYER_HIT, ABERRATION_CAP)
	if remote_link.is_empty():
		player.knockback(dir * PLAYER_HIT_KNOCKBACK)   # 원격 조종 중이면 맞는 것은 포탑이다 — 몸은 밀리지 않는다

var _obstacle_health_label: Label

func _on_obstacle_health_changed(value: float) -> void:
	if _obstacle_health_label == null:
		_obstacle_health_label = Label.new()
		_obstacle_health_label.position = Vector2(48,92)
		_obstacle_health_label.add_theme_font_size_override("font_size",20)
		_obstacle_health_label.add_theme_color_override("font_color",Color(1.0,0.65,0.3))
		get_node("UI").add_child(_obstacle_health_label)
	_obstacle_health_label.text = "체력 %d / 100 · 가스통 폭발 주의" % int(value)
	_obstacle_health_label.visible = value < 100.0

func _on_obstacle_incapacitated() -> void:
	if transitioning:
		player.restore_health()
		return
	var id := current_room.room_id
	var spawn_x := 120.0 if player.position.x < current_room.width*0.5 else current_room.width-120.0
	_transition(id, spawn_x, 1 if spawn_x<current_room.width*0.5 else -1)

## 가스통 폭발: 히트스톱으로 섬광 프레임을 붙잡고, 거리에 따라 크게 흔들고, 색수차·화면 섬광을 얹는다.
## 연쇄 폭발은 매번 다시 걸려 "쾅-쾅" 박자가 된다.
func _on_obstacle_exploded(point: Vector2) -> void:
	var distance := player.position.distance_to(point)
	var near := clampf(1.0 - distance / 2000.0, 0.0, 1.0)
	if near > 0.0:
		camera.add_shake(18.0 * near, 18.0)
		_aberration = minf(_aberration + 7.0 * near, ABERRATION_CAP)
		_screen_flash(0.55 * near)
	HitStop.apply(get_tree(), 0.09)


## 상자·콘크리트가 무너진 순간: 짧은 히트스톱 + 흔들림 (가까울수록 크게)
func _on_obstacle_broken(point: Vector2, shake: float, stop: float) -> void:
	var near := clampf(1.0 - player.position.distance_to(point) / 1800.0, 0.3, 1.0)
	camera.add_shake(shake * near, 12.0)
	HitStop.apply(get_tree(), stop)


var _flash_rect: ColorRect
var _flash_tween: Tween

## 화면 전체 주황 섬광 (폭발 첫 순간). 가산 합성이라 어두운 방에서도 밝게 번쩍인다.
func _screen_flash(amount: float) -> void:
	if _flash_rect == null:
		_flash_rect = ColorRect.new()
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.color = Color(1.0, 0.78, 0.5, 0.0)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_flash_rect.material = mat
		get_node("UI").add_child(_flash_rect)
		get_node("UI").move_child(_flash_rect, 0)
	if _flash_tween:
		_flash_tween.kill()
	_flash_rect.color.a = maxf(_flash_rect.color.a, amount)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## 몬스터 포효: 가까울수록 카메라가 낮게 울린다 (플레이어 피격 7 대비 최대 2.2).
## power 는 덩치 배율 — 거대종은 더 멀리서, 더 크게 울린다.
func _on_monster_roared(pos: Vector2, power := 1.0) -> void:
	var reach := Crawler.ROAR_SHAKE_RANGE * power
	var d := absf(pos.x - player.position.x)
	if d < reach:
		camera.add_shake(lerpf(2.2 * power, 0.4, d / reach))


## 거대종 내려찍기: 바닥을 때린 충격이 방 전체로 퍼진다. 플레이어 피격(7)보다 크게 잡되,
## 충격파에 실제로 맞았다면 _on_player_hit 의 7 이 여기에 더해져 add_shake 의 상한(10)에 붙는다.
## 체액 비산(GoreBurst)에 맞춘 짧은 흔들림 — 피격 흔들림(1.2×위력)에 살짝 얹는 정도
func _on_monster_died(_pos: Vector2, power := 1.0) -> void:
	camera.add_shake(1.3 * clampf(power, 1.0, 2.0))


func _on_monster_slammed(pos: Vector2) -> void:
	var d := absf(pos.x - player.position.x)
	var reach := Crawler.SLAM_SHOCK_RANGE * 3.0      # 맞지 않아도 발밑이 울리는 범위
	if d < reach:
		camera.add_shake(lerpf(9.0, 1.2, d / reach))


## 불 스타일 (확정: 잉걸·검은 연기). 개발용 호출만 남긴다.
func set_fire_style(index: int) -> void:
	FireSource.style_index = wrapi(index, 0, FireSource.STYLES.size())
	if current_room:
		for f in current_room.fires:
			f.apply_style(FireSource.style_index)


func set_monster_hit_fx(index: int) -> void:
	Crawler.default_hit_fx_preset = clampi(index, 0, Crawler.HIT_FX_PRESETS.size() - 1)
	if current_room:
		for monster in current_room.monsters:
			if is_instance_valid(monster) and monster is Crawler:
				monster.set_hit_fx_preset(Crawler.default_hit_fx_preset)
				monster.preview_hit_fx()
	_update_hit_fx_label()


func _update_hit_fx_label() -> void:
	if hit_fx_label == null:
		return
	var i: int = Crawler.default_hit_fx_preset
	hit_fx_label.text = "몬스터 피격 (1~4)  %d/4  %s" % [int(i + 1), str(Crawler.HIT_FX_PRESETS[i]["name"])]


## 프랍 그림자 프리셋 (F6 순환 — PropShadow.PRESETS). 방을 다시 만들지 않고 그림자 층만 갈아 끼운다.
func set_prop_shadow(i: int) -> void:
	PropShadow.index = wrapi(i, 0, PropShadow.BASE_PRESETS.size())
	if current_room:
		current_room.apply_prop_shadow(PropShadow.index)
	_update_shadow_label()


## 동적 광원(총구 화염·탄착·불·아크·비상등) 그림자 프리셋 (F8 순환)
func set_dyn_shadow(i: int) -> void:
	PropShadow.dyn_index = wrapi(i, 0, PropShadow.DYN_PRESETS.size())
	if current_room:
		current_room.apply_dyn_shadow(PropShadow.dyn_index)
	_update_shadow_label()


## 플레이어 아이들 모션 프리셋 (F5 순환)
func set_idle_preset(i: int) -> void:
	Player.idle_index = wrapi(i, 0, Player.IDLE_PRESETS.size())
	_update_idle_label()


func set_mark_preset(i: int) -> void:
	BulletMark.set_preset(i)
	_update_mark_label()


func set_fog_preset(i: int) -> void:
	GroundFog.set_preset(i)
	if current_room:
		current_room.apply_fog(GroundFog.index)
	_update_fog_label()


func _update_fog_label() -> void:
	if fog_label == null:
		return
	var p := GroundFog.preset()
	fog_label.text = "바닥 안개 (F2)  %d/%d  %s — %s" % [
		GroundFog.index + 1, GroundFog.PRESETS.size(), p["name"], p["desc"]]


func _update_mark_label() -> void:
	if mark_label == null:
		return
	var p := BulletMark.preset()
	mark_label.text = "탄흔 (F9)  %d/%d  %s — %s" % [
		BulletMark.preset_index + 1, BulletMark.PRESETS.size(), p["name"], p["desc"]]


func _update_idle_label() -> void:
	if idle_label == null:
		return
	var p := Player.idle_preset()
	idle_label.text = "아이들 모션 (F5)  %d/%d  %s — %s" % [
		Player.idle_index + 1, Player.IDLE_PRESETS.size(), p["name"], p["desc"]]


func _update_shadow_label() -> void:
	if shadow_label == null:
		return
	var p: Dictionary = PropShadow.BASE_PRESETS[PropShadow.index]
	shadow_label.text = "기본 그림자 (F6)  %d/%d  %s — %s" % [
		PropShadow.index + 1, PropShadow.BASE_PRESETS.size(), p["name"], p["desc"]]
	var d: Dictionary = PropShadow.DYN_PRESETS[PropShadow.dyn_index]
	dyn_shadow_label.text = "동적 광원 그림자 (F8)  %d/%d  %s — %s" % [
		PropShadow.dyn_index + 1, PropShadow.DYN_PRESETS.size(), d["name"], d["desc"]]


## 배경 라이팅 무드 (확정: 그라데이션 필). 개발용 호출만 남긴다.
func set_light_mood(index: int) -> void:
	LightMood.index = wrapi(index, 0, LightMood.PRESETS.size())
	if current_room:
		current_room.apply_mood(LightMood.index)


func _on_shell_ejected(pos: Vector2, dir: int) -> void:
	var sc := ShellCasing.new()
	sc.setup(pos, dir, player.position.y)
	bullets.add_child(sc)


## 센트리건 탄피 — 두 배 크기로 더 멀리 튄다
func _on_turret_shell(pos: Vector2, dir: int) -> void:
	var sc := ShellCasing.new()
	sc.setup(pos, dir, current_room.floor_y, SentryTurret.SHELL_SCALE)
	bullets.add_child(sc)


## 월드 뷰포트. 창을 꽉 채우는 SubViewportContainer 안의 SubViewport(×1) — 글로우 환경·후처리를 월드에만 걸기 위해 분리한다.
## 컨테이너는 창(루트 캔버스) 크기를 그대로 따라가고(stretch) SubViewport 크기가 그 뒤를 따른다.
## 부모가 Node2D 라 앵커가 먹지 않으므로 크기를 직접 넣는다 (_fit_view). 창 크기가 바뀌면 _on_view_resized.
## 컨테이너가 마우스 이벤트를 그대로 넘겨주므로 world 안의 노드는 get_global_mouse_position() 을 그대로 쓴다.
func _setup_view() -> void:
	var container := SubViewportContainer.new()
	container.name = "View"
	container.stretch = true
	container.stretch_shrink = VIEW_SCALE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.position = Vector2.ZERO
	container.size = get_viewport().get_visible_rect().size
	add_child(container)
	get_viewport().size_changed.connect(_fit_view)

	world_vp = SubViewport.new()
	world_vp.name = "World"
	world_vp.size = Vector2i(get_viewport().get_visible_rect().size) / VIEW_SCALE
	world_vp.disable_3d = true
	world_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_vp.snap_2d_transforms_to_pixel = false                     # 이동·조명은 부드럽게 (그림만 픽셀)
	world_vp.use_hdr_2d = ProjectSettings.get_setting("rendering/viewport/hdr_2d", false)
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(world_vp)

	world = Node2D.new()
	world.name = "Stage"
	world_vp.add_child(world)
	world_vp.size_changed.connect(_on_view_resized)


func _fit_view() -> void:
	var container := get_node_or_null("View") as SubViewportContainer
	if container != null:
		container.size = get_viewport().get_visible_rect().size


## 창 크기가 바뀌었다 (F11 · 창 끌기). 표준 배율이 캔버스 높이에 매여 있으므로 기본 줌을 다시 고른다.
## 대화·단말기처럼 카메라를 밀어 넣은 동안은 건드리지 않는다 — 그 연출이 끝나며 새 기본 줌으로 돌아온다.
func _on_view_resized() -> void:
	if camera == null:
		return
	_update_zoom_label()
	if (dialogue != null and dialogue.active) or (terminal_screen != null and terminal_screen.is_open()):
		return
	var z := _base_zoom()
	camera.zoom = Vector2(z, z)
	camera.snap()


## 월드 좌표 → 창(루트 뷰포트) 좌표. AutoTest 의 마우스 워프 등에 쓴다.
func world_to_screen(p: Vector2) -> Vector2:
	var container := world_vp.get_parent() as Control
	return Vector2(world_vp.get_canvas_transform() * p) * float(VIEW_SCALE) + container.position


## 글로우(WorldEnvironment) + 풀스크린 후처리(색수차·비네트). 둘 다 저해상도 월드 뷰포트 안에 둔다.
## 2D 는 project.godot 의 hdr_2d 가 켜져야 글로우가 잡힌다.
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.85      # LDR 2D: 거의 흰 픽셀(전구·총구·스파크)만 번진다
	env.glow_hdr_scale = 2.0
	env.glow_hdr_luminance_cap = 2.0        # 총구처럼 아주 밝은 곳이 거대한 광구로 번지지 않게 상한
	# 픽셀이 뭉개지지 않게 작은 레벨은 끄고 중간~큰 번짐만
	for i in range(7):
		env.set_glow_level(i, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.7)
	env.set_glow_level(4, 0.35)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	world_vp.add_child(we)

	var post_layer := CanvasLayer.new()
	post_layer.name = "PostFX"
	post_layer.layer = 9
	world_vp.add_child(post_layer)
	var post := ColorRect.new()
	post.name = "PostRect"
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = Lighting.shader_material("post_fx")
	post.material = _post_mat
	post_layer.add_child(post)


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.layer = 10
	add_child(layer)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Segoe UI", "Noto Sans CJK KR"])

	title_label = Label.new()
	title_label.position = Vector2(24, 18)
	title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	layer.add_child(title_label)

	hint_label = Label.new()
	hint_label.text = "F1 로비    A/D ←/→ 이동    마우스 조준 · 좌클릭 사격    Space 구르기    Ctrl 앉기(+A/D 앉아 걷기)    W/↑ 정면문 · 말 걸기 · 사다리 · 없으면 점프    대화 중 Space/E 넘기기 · ↑/↓ 선택    R 재장전    1~4 몬스터 피격색    F2 안개    F3 줌    F11 전체화면"
	_pin(hint_label, Vector2(0, 1), Vector2(24, -40), Vector2.ZERO)
	hint_label.add_theme_font_override("font", font)
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
	layer.add_child(hint_label)
	bugbot_status = Label.new()
	_pin(bugbot_status, Vector2(0, 1), Vector2(24, -104), Vector2.ZERO)
	bugbot_status.add_theme_font_override("font", font)
	bugbot_status.add_theme_font_size_override("font_size", 20)
	bugbot_status.add_theme_color_override("font_color", Color(0.4, 0.95, 0.88))
	layer.add_child(bugbot_status)

	# 줌 프리셋 표시 — 우상단 맨 위. 공간감 라벨이 있던 자리(y18)로 올렸다.
	zoom_label = Label.new()
	_pin(zoom_label, Vector2(1, 0), Vector2(-24 - 700, 18), Vector2(700, 30))
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	zoom_label.add_theme_font_override("font", font)
	zoom_label.add_theme_font_size_override("font_size", 20)
	zoom_label.add_theme_color_override("font_color", Color(0.62, 0.84, 0.86))
	layer.add_child(zoom_label)
	_update_zoom_label()

	# 프랍 그림자 프리셋 표시 — 줌 라벨 바로 아래 (F6 으로 비교하는 동안만 쓰는 개발용 표시)
	shadow_label = Label.new()
	_pin(shadow_label, Vector2(1, 0), Vector2(-24 - 900, 52), Vector2(900, 30))
	shadow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shadow_label.add_theme_font_override("font", font)
	shadow_label.add_theme_font_size_override("font_size", 20)
	shadow_label.add_theme_color_override("font_color", Color(0.80, 0.76, 0.62))
	layer.add_child(shadow_label)

	# 동적 광원 그림자 — 그 아래 한 줄 더
	dyn_shadow_label = Label.new()
	_pin(dyn_shadow_label, Vector2(1, 0), Vector2(-24 - 900, 78), Vector2(900, 30))
	dyn_shadow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dyn_shadow_label.add_theme_font_override("font", font)
	dyn_shadow_label.add_theme_font_size_override("font_size", 20)
	dyn_shadow_label.add_theme_color_override("font_color", Color(0.86, 0.66, 0.52))
	layer.add_child(dyn_shadow_label)
	_update_shadow_label()

	# 아이들 모션 프리셋 — 그 아래 한 줄 더 (F5 로 비교하는 동안 쓰는 개발용 표시)
	idle_label = Label.new()
	_pin(idle_label, Vector2(1, 0), Vector2(-24 - 1100, 104), Vector2(1100, 30))
	idle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	idle_label.add_theme_font_override("font", font)
	idle_label.add_theme_font_size_override("font_size", 20)
	idle_label.add_theme_color_override("font_color", Color(0.72, 0.86, 0.68))
	layer.add_child(idle_label)
	_update_idle_label()

	mark_label = Label.new()
	_pin(mark_label, Vector2(1, 0), Vector2(-24 - 1100, 132), Vector2(1100, 30))
	mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mark_label.add_theme_font_override("font", font)
	mark_label.add_theme_font_size_override("font_size", 20)
	mark_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.46))
	layer.add_child(mark_label)
	_update_mark_label()

	hit_fx_label = Label.new()
	_pin(hit_fx_label, Vector2(1, 0), Vector2(-24 - 1100, 160), Vector2(1100, 30))
	hit_fx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hit_fx_label.add_theme_font_override("font", font)
	hit_fx_label.add_theme_font_size_override("font_size", 20)
	hit_fx_label.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0))
	layer.add_child(hit_fx_label)
	_update_hit_fx_label()

	fog_label = Label.new()
	_pin(fog_label, Vector2(1, 0), Vector2(-24 - 1100, 188), Vector2(1100, 30))
	fog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fog_label.add_theme_font_override("font", font)
	fog_label.add_theme_font_size_override("font_size", 20)
	fog_label.add_theme_color_override("font_color", Color(0.74, 0.80, 0.90))
	layer.add_child(fog_label)
	_update_fog_label()

	# 정면문 안내: 화면 하단 중앙(힌트 바로 위) — 우상단 디버그 라벨과 겹치지 않게
	# 보행 기체 접속 연출. 안내 문구·조준점보다 위에 떠야 하므로 UI 층 맨 끝에 붙인다
	walker_link = WalkerLink.new()
	walker_link.name = "WalkerLink"
	walker_link.finished.connect(_on_link_finished)
	layer.add_child(walker_link)

	prompt_label = Label.new()
	prompt_label.anchor_right = 1.0                  # 가로는 창 폭 전체, 세로는 바닥에서 100px 위
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_top = -100.0
	prompt_label.offset_bottom = -60.0
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_override("font", font)
	prompt_label.add_theme_font_size_override("font_size", 26)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	prompt_label.visible = false
	layer.add_child(prompt_label)



	# 우하단: 탄창
	ammo_label = Label.new()
	_pin(ammo_label, Vector2(1, 1), Vector2(-24 - 720, -58 - 94), Vector2(720, 94))   # 하단 힌트 줄 위
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	ammo_label.add_theme_font_override("font", font)
	ammo_label.add_theme_font_size_override("font_size", 28)
	ammo_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	layer.add_child(ammo_label)
	ammo_label.text = ""

	# 센트리건 총열 과열 게이지 (탄창 라벨 위). 조종 중에만 보인다.
	heat_bar_bg = ColorRect.new()
	heat_bar_bg.color = Color(0.10, 0.10, 0.13, 0.75)
	_pin(heat_bar_bg, Vector2(1, 1), Vector2(-24 - HEAT_BAR.x, -58 - 60 - HEAT_BAR.y - 6), HEAT_BAR)
	heat_bar_bg.visible = false
	layer.add_child(heat_bar_bg)
	heat_bar_fill = ColorRect.new()
	heat_bar_fill.color = Color(1.0, 0.6, 0.25)
	heat_bar_fill.position = Vector2(2, 2)
	heat_bar_fill.size = Vector2(0, HEAT_BAR.y - 4)
	heat_bar_bg.add_child(heat_bar_fill)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)


## HUD 조각을 창의 한 모서리(anchor: 0/1)에 붙인다. pos 는 그 모서리 기준 오프셋, size 0 이면 내용만큼.
## 캔버스가 창 비율을 따라 늘어나므로 절대 좌표 대신 이것으로 배치한다.
static func _pin(c: Control, anchor: Vector2, pos: Vector2, size: Vector2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + size.x
	c.offset_bottom = pos.y + size.y


func _setup_input_map() -> void:
	_add_action("bugbot_battle", [KEY_F10])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("run", [KEY_SHIFT])
	_add_action("interact", [KEY_W, KEY_UP])
	_add_action("crouch", [KEY_CTRL, KEY_S, KEY_DOWN])
	_add_action("shoot", [KEY_J])
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)
	_add_action("roll", [KEY_SPACE])
	_add_action("toggle_fullscreen", [KEY_F11])
	_add_action("reload", [KEY_R])
	_add_action("to_lobby", [KEY_F1])
	_add_action("fog_cycle", [KEY_F2])      # 바닥 안개 프리셋 순환 (Shift 동시 = 이전)
	_add_action("zoom_cycle", [KEY_F3])     # 줌 프리셋 ×2 → ×3 → ×4 순환
	_add_action("shadow_cycle", [KEY_F6])   # 기본(붙박이 광원) 그림자 프리셋 순환 (Shift 동시 = 이전)
	_add_action("shadow_dyn_cycle", [KEY_F8])  # 동적 광원 그림자 프리셋 순환 (Shift 동시 = 이전)
	_add_action("idle_cycle", [KEY_F5])     # 플레이어 아이들 모션 프리셋 순환 (Shift 동시 = 이전)
	_add_action("mark_cycle", [KEY_F9])     # 탄흔 프리셋 순환 (Shift 동시 = 이전)
	_add_action("dialogue_style", [KEY_F7])  # 대사 표시 방식 순환 — 대화 UI 랩 전용 (게임은 "자막" 고정)
	_add_action("hit_fx_1", [KEY_1, KEY_KP_1])
	_add_action("hit_fx_2", [KEY_2, KEY_KP_2])
	_add_action("hit_fx_3", [KEY_3, KEY_KP_3])
	_add_action("hit_fx_4", [KEY_4, KEY_KP_4])
	# 대화: 넘기기/확인 · 선택지 이동. W/↑(interact)는 말을 **거는** 키라 확인에는 넣지 않는다
	# — 한 번 누른 키가 말을 걸면서 첫 줄까지 넘겨 버리지 않게.
	_add_action("dlg_advance", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E])
	_add_mouse_action("dlg_advance", MOUSE_BUTTON_LEFT)
	_add_action("dlg_prev", [KEY_UP, KEY_W])
	_add_action("dlg_next", [KEY_DOWN, KEY_S])


func _add_mouse_action(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
