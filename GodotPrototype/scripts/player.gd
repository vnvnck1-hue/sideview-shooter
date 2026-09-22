class_name Player
extends Node2D
## 붉은 후드 정비공. 위치는 바닥 월드 좌표(발 밑).
## 구조:  Player
##          BodyPivot (몸 중심, 구르기 회전축)
##            Body      AnimatedSprite2D  — idle / walk / run / crouch
##            HeadPivot (목 앵커, 마우스 방향으로 제한된 각도만큼 회전)
##              Head    Sprite2D  — 후드+마스크 (목이 원점, 몸 프레임에 맞춰 텍스처 교체)
##          ArmPivot   (어깨 앵커, 마우스 방향으로 실시간 회전)
##            Arm       Sprite2D  — 팔+총 (어깨가 원점)
##            Muzzle    Marker2D  — 총구
##            Flash     Sprite2D  — 총구 화염
## 상태 우선순위: Roll > Crouch > Run/Walk > Idle.
## 이동/사격 배타: Shift = 질주(RUN_SPEED). 질주 중엔 총을 쏠 수 없고, 사격 입력이 들어오면
## 질주가 즉시 풀려 걷기(WALK_SPEED)로 감속한다 — FIRE_MAX_SPEED 아래로 떨어져야 첫 발이 나간다.
## 버튼을 누르고 있으면 FIRE_COOLDOWN 간격으로 연사.
## 탄창: MAG_SIZE 발을 쏘면 자동 재장전(RELOAD_TIME, R 로 수동). 재장전 중엔 팔이 아래로 내려가 총을 흔든다.
## 반동은 팔·머리·몸통 세 개의 2차 스프링이 서로 다른 강도·감쇠·지연으로 받아 **절차적으로 따로** 흔들린다(팔 즉시 → 머리 → 몸통 순).
## 탄착점은 연사 열(_heat)에 비례한 산탄각으로 흔들린다(첫 발은 거의 정확, 길게 누르면 벌어짐).

signal shoot_fired(muzzle_pos: Vector2, target_pos: Vector2)
signal ammo_changed(ammo: int, mag: int, reloading: bool)
signal shell_ejected(pos: Vector2, dir: int)
signal request_front_door()

const FRAME_SIZE := 320
const SPLIT_DIR := "res://assets/character/Split/"
const ACTION_DIR := "res://assets/character/Action/"
const ACTION_FRAME_COUNT := 6
const CLIPS := {
	"idle":   {"fps": 1.0, "loop": true,  "frames": 1},
	"walk":   {"fps": 16.0, "loop": true,  "frames": 4},
	"run":    {"fps": 18.0, "loop": true,  "frames": 4},
	"crouch": {"fps": 12.0, "loop": false, "frames": 4},
}
const BODY_CENTER_Y := 150.0        # 발 밑 기준 몸 중심 높이
const ROLL_CENTER := Vector2(10.0, 103.0)   # 웅크린 프레임(crouch_04) 내용물 중심 (발 밑 기준, 오른쪽 방향)
const DEFAULT_SHOULDER := Vector2(39, -142)
const EJECT_LOCAL := Vector2(46, -14)     # 어깨 기준 탄피 배출구 (팔 로컬)

const WALK_SPEED := 380.0           # 기본 이동 = 걷기. 이 속도에서만 사격할 수 있다
const RUN_SPEED := 620.0            # Shift 질주. 사격 불가
const SPEED := RUN_SPEED             # 구르기 종료 관성의 기존 기준값
const RUN_CLIP_SPEED := WALK_SPEED * 1.05   # 이 속도를 넘어서야 run 클립으로 갈아탄다
const FIRE_MAX_SPEED := WALK_SPEED * 1.15   # 이보다 빠르면 아직 질주 중 — 사격 불가
const RUN_FIRE_LOCK := 0.22         # 사격 입력 뒤 이 시간 동안 질주 금지 (연사 중 걷기 유지)
const WALK_THRESHOLD := 30.0
const ACCEL := 5200.0               # 출발 가속 (px/s^2) - 약 0.16초에 최고속
const DECEL := 3600.0               # 정지 감속 - 약 0.23초에 멈춤, 살짝 미끄러짐
const TURN_DECEL := 7000.0          # 반대 방향으로 꺾을 때는 더 빨리 감속

# 숨쉬기 (Idle) - 발을 고정한 채 스케일 트위닝
const BREATH_PERIOD := 2.6
const BREATH_SCALE := Vector2(0.012, 0.028)   # x는 살짝 줄고 y는 늘어남

# 사격 — 카타나 제로식 즉발·고속 연사
const FIRE_COOLDOWN := 0.09         # 초. 누르고 있으면 이 간격으로 연사 (≈11발/초)
const MAG_SIZE := 14                # 장탄수
const RELOAD_TIME := 1.15           # 재장전 시간 (초)
const FLASH_TIME := 0.03

# 산탄 — 연사 열(_heat, 0..1)이 오르면 탄착점이 더 흔들린다
const SPREAD_BASE := 0.012          # 첫 발 산탄각 (rad)
const SPREAD_HEAT := 0.055          # 열 1.0 에서 더해지는 산탄각
const HEAT_PER_SHOT := 0.16
const HEAT_DECAY := 2.2             # 초당

# 반동 — 팔 → 머리 → 몸통이 서로 다른 2차 스프링으로 연쇄 반응한다.
# 한 발 = 단 한 번의 펄스: 속도 임펄스를 주되 감쇠를 임계값(c = 2√k)으로 잡아 뒤로 밀렸다가 튕김 없이 제자리로 돌아온다.
#   spring : (k 강성, c 감쇠, 지연 초).  임계 감쇠에서 피크 변위 = imp/(√k·e) → imp = √k·e 면 피크 1.0, 피크 시각 1/√k
#   arm_px / arm_rad : 팔이 총 축을 따라 뒤로 밀리는 픽셀 / 회전 (최소)
#   head_px / head_rad : 머리 뒤로 밀림(목 기준 X) / 회전 (최소)
#   body_px : 상체가 뒤로 밀리는 픽셀 — 발은 고정(마찰)이고 몸이 발 위에서 기울어지는 전단(skew)으로 표현
#   body_squat : 반동 순간 몸이 눌리는 비율 (scale.y, 발 고정)
# 확정: "라이트 (단발 40px)". 미디엄(60px)·헤비(80px) 프리셋은 2026-09-18 비교 후 폐기.
const RECOIL := {"id": "light", "name": "라이트 (단발 40px)", "desc": "팔 40px·머리 10px·상체 16px 단발 펄스, 튕김 없음. 발 고정",
	"arm": Vector3(2600.0, 102.0, 0.0), "arm_imp": 139.0, "arm_px": 40.0, "arm_rad": 0.04,
	"head": Vector3(1400.0, 75.0, 0.02), "head_imp": 102.0, "head_rad": 0.02, "head_px": 10.0,
	"body": Vector3(900.0, 60.0, 0.04), "body_imp": 82.0, "body_px": 16.0, "body_squat": 0.03}
const RELOAD_ARM_DROP := 1.05       # 재장전 중 팔이 내려가는 각도 (rad)
const AIM_SMOOTH := 80.0            # 팔 회전 보간 속도 (클수록 즉각적)

# 머리 — 목을 축으로 조준 방향을 바라본다 (팔보다 느리고 각도 제한)
const HEAD_MAX_ANGLE := 0.42        # 최대 기울기 (rad, ≈24°)
const HEAD_SMOOTH := 26.0
const DEFAULT_NECK := Vector2(15, -148)

# 구르기 (Space) — 속도 = ROLL_PEAK × 가속(smoothstep 0~42%: 느리고 부드럽게 진입) × 감속(1 − 0.85·k^2.2). 이동 거리 ≈ 430px
const ROLL_TIME := 0.30
const ROLL_PEAK := 2720.0
const ROLL_ACCEL_PORTION := 0.42
const ROLL_DECEL := 0.85
const ROLL_DECEL_POW := 2.2
const ROLL_DISTANCE := 430.0        # 위 프로파일의 적분값 (회전 정규화용)
const ROLL_EXIT_SPEED := 0.85       # 구르기가 끝날 때 남는 관성 (SPEED 배율)
const ROLL_SLIDE_TIME := 0.4        # 그 뒤 이 시간 동안은 약한 감속으로 미끄러진다
const ROLL_SLIDE_DECEL := 1500.0

enum State { IDLE, WALK, RUN, CROUCH, UNCROUCH, ROLL }

var state: State = State.IDLE
var facing := 1                     # 1 = 오른쪽, -1 = 왼쪽 (조준 방향이 결정)
var velocity_x := 0.0
var input_enabled := true
var min_x := 0.0
var max_x := 10000.0
var aim_target := Vector2.ZERO      # 월드 좌표. Main 이 매 프레임 마우스 위치를 넣어준다

var _fire_cd := 0.0
var _run_lock := 0.0                # >0 이면 사격 때문에 질주가 잠긴 상태
var _flash_t := 0.0
var _roll_t := 0.0
var _roll_dir := 1
var _roll_dist := 0.0               # 구르기 누적 이동 거리 (회전은 거리에 비례)
var _slide_t := 0.0                 # 구르기 뒤 미끄러짐 잔여 시간
var ammo := MAG_SIZE
var reloading := false
var _reload_t := 0.0
var _heat := 0.0                    # 연사 열 (산탄)
# 반동 스프링 상태: 각 Vector2(값, 속도). 값 1.0 = 한 발 반동 크기. pending: [{t, part}] 지연 임펄스
var _arm_rc := Vector2.ZERO
var _head_rc := Vector2.ZERO
var _body_rc := Vector2.ZERO
var _pending: Array = []
var _arm_angle := 0.0
var _breath_t := 0.0
var _breath := Vector2.ONE
var _meta := {}
var _shoulders := {}                # "walk_02" → 어깨 오프셋(바닥 중심 기준, 오른쪽 방향)
var _necks := {}                    # "walk_02" → 목 오프셋(바닥 중심 기준, 오른쪽 방향)
var _head_tex := {}                 # "walk_02" → 머리 텍스처
var _head_angle := 0.0

var body_pivot: Node2D
var body: AnimatedSprite2D
var head_pivot: Node2D
var head: Sprite2D
var arm_pivot: Node2D
var arm: Sprite2D
var muzzle: Marker2D
var flash: Sprite2D
var muzzle_light: PointLight2D
var action_visual: AnimatedSprite2D
var _action_clip := ""


func _ready() -> void:
	_load_meta()

	body_pivot = Node2D.new()
	body_pivot.name = "BodyPivot"
	body_pivot.position = Vector2(0, -BODY_CENTER_Y)
	add_child(body_pivot)

	body = AnimatedSprite2D.new()
	body.name = "Body"
	body.centered = false
	body.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE + BODY_CENTER_Y)   # 발 밑이 Player 원점
	body.sprite_frames = _build_frames()
	body.material = Lighting.character_material()      # 노멀맵 라이팅 + 캐릭터 림라이트 (CHAR_RIM_PRESETS)
	body_pivot.add_child(body)
	body.animation_finished.connect(_on_animation_finished)
	body.frame_changed.connect(_on_body_frame)
	body.play("idle")

	# 머리: 몸통과 같은 BodyPivot 아래 (숨쉬기 스케일·구르기 회전을 함께 받는다), 몸 위에 그려진다
	head_pivot = Node2D.new()
	head_pivot.name = "HeadPivot"
	body_pivot.add_child(head_pivot)
	head = Sprite2D.new()
	head.name = "Head"
	head.centered = false
	head.material = Lighting.character_material()
	head_pivot.add_child(head)
	_load_head_textures()

	arm_pivot = Node2D.new()
	arm_pivot.name = "ArmPivot"
	add_child(arm_pivot)

	var meta_arm: Dictionary = _meta.get("arm_gun", {})
	var sh: Array = meta_arm.get("shoulder_local", [0, 40])
	var mz: Array = meta_arm.get("muzzle_local", [83, 22])

	arm = Sprite2D.new()
	arm.name = "Arm"
	arm.centered = false
	arm.texture = Lighting.textured(SPLIT_DIR + "arm_gun.png")
	arm.material = Lighting.character_material()
	arm.offset = Vector2(-sh[0], -sh[1])          # 어깨가 원점
	arm_pivot.add_child(arm)

	muzzle = Marker2D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector2(mz[0] - sh[0], mz[1] - sh[1])
	arm_pivot.add_child(muzzle)

	flash = Sprite2D.new()
	flash.name = "Flash"
	flash.texture = load(SPLIT_DIR + "muzzle_flash.png")
	flash.centered = true
	flash.position = muzzle.position + Vector2(flash.texture.get_width() * 0.5 - 6, 0)
	flash.visible = false
	flash.modulate = Lighting.RED_EMISSIVE_SOFT      # 붉은 발광 → 글로우
	arm_pivot.add_child(flash)

	# 총구 화염 라이트 - 발사 순간만 켜진다
	muzzle_light = PointLight2D.new()
	muzzle_light.name = "MuzzleLight"
	muzzle_light.texture = Lighting.radial_texture()
	muzzle_light.texture_scale = Lighting.scale_for_radius(LightTuning.value("muzzle_hold", "radius", 563.0))
	muzzle_light.color = Lighting.GUN_LIGHT
	muzzle_light.energy = LightTuning.value("muzzle_hold", "energy", 1.8)
	muzzle_light.height = LightTuning.value("muzzle_hold", "height", Lighting.FLASH_HEIGHT)
	muzzle_light.position = muzzle.position
	muzzle_light.enabled = false
	arm_pivot.add_child(muzzle_light)
	Lighting.register_dynamic(muzzle_light, 1.6, "shot")     # 프랍 그림자가 총구 화염을 따라 확 뻗는다

	# 전신 액션 클립: 기존 분리형 몸통·머리·팔을 가리는 오버레이로만
	# 재장전/구르기 동안 사용한다. 판정·이동 로직은 기존 값을 유지한다.
	action_visual = AnimatedSprite2D.new()
	action_visual.name = "ActionVisual"
	action_visual.centered = false
	action_visual.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE)
	action_visual.sprite_frames = _build_action_frames()
	action_visual.material = Lighting.character_material()
	action_visual.z_index = 0
	action_visual.visible = false
	add_child(action_visual)

	_update_arm(0.0, true)


func _load_meta() -> void:
	var f := FileAccess.open(SPLIT_DIR + "split_meta.json", FileAccess.READ)
	if f == null:
		push_warning("split_meta.json 을 읽을 수 없음 — 기본 어깨 위치 사용")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_meta = parsed
	for key in _meta.get("frames", {}).keys():
		var v: Array = _meta["frames"][key]["shoulder_from_pivot"]
		_shoulders[key] = Vector2(v[0], v[1])
		if _meta["frames"][key].has("neck_from_pivot"):
			var nk: Array = _meta["frames"][key]["neck_from_pivot"]
			_necks[key] = Vector2(nk[0], nk[1])


func _load_head_textures() -> void:
	for clip_name in CLIPS.keys():
		for i in range(1, CLIPS[clip_name]["frames"] + 1):
			var key := "%s_%02d" % [clip_name, i]
			var path := "%shead/%s/%s.png" % [SPLIT_DIR, clip_name, key]
			if ResourceLoader.exists(path):
				_head_tex[key] = Lighting.textured(path)


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for clip_name in CLIPS.keys():
		var cfg: Dictionary = CLIPS[clip_name]
		sf.add_animation(clip_name)
		sf.set_animation_speed(clip_name, cfg["fps"])
		sf.set_animation_loop(clip_name, cfg["loop"])
		for i in range(1, cfg["frames"] + 1):
			sf.add_frame(clip_name, Lighting.textured("%sbody/%s/%s_%02d.png" % [SPLIT_DIR, clip_name, clip_name, i]))
	return sf


func _build_action_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var durations := {"reload": RELOAD_TIME, "roll": ROLL_TIME}
	for clip_name in durations.keys():
		sf.add_animation(clip_name)
		sf.set_animation_speed(clip_name, float(ACTION_FRAME_COUNT) / float(durations[clip_name]))
		sf.set_animation_loop(clip_name, false)
		for i in range(1, ACTION_FRAME_COUNT + 1):
			var path := "%s%s/%s_%02d.png" % [ACTION_DIR, clip_name, clip_name, i]
			if ResourceLoader.exists(path):
				sf.add_frame(clip_name, Lighting.textured(path))
			else:
				push_warning("액션 프레임을 찾을 수 없음: %s" % path)
	return sf


func _show_action_clip(clip_name: String, frame_index := 0, should_play := true) -> void:
	if action_visual == null or action_visual.sprite_frames == null:
		return
	if not action_visual.sprite_frames.has_animation(clip_name):
		return
	_action_clip = clip_name
	action_visual.flip_h = facing < 0
	action_visual.animation = clip_name
	action_visual.frame = clampi(frame_index, 0, ACTION_FRAME_COUNT - 1)
	action_visual.visible = true
	if should_play:
		action_visual.play()
	else:
		action_visual.pause()
	body.visible = false
	head.visible = false
	arm_pivot.visible = false


func _hide_action_clip() -> void:
	_action_clip = ""
	if action_visual == null:
		return
	action_visual.stop()
	action_visual.visible = false
	body.visible = true
	head.visible = true
	arm_pivot.visible = true


func _resume_reload_action() -> void:
	if not reloading:
		return
	var progress := clampf(_reload_t / RELOAD_TIME, 0.0, 0.999)
	var frame_index := mini(int(progress * ACTION_FRAME_COUNT), ACTION_FRAME_COUNT - 1)
	_show_action_clip("reload", frame_index, true)


static func recoil_preset() -> Dictionary:
	return RECOIL


## 2차 스프링 한 스텝: s = (값, 속도), p = (k, 감쇠, _)
static func _spring(s: Vector2, p: Vector3, delta: float) -> Vector2:
	s.y += -s.x * p.x * delta
	s.y *= exp(-p.y * delta)
	s.x += s.y * delta
	return s


func _update_recoil(delta: float) -> void:
	# 지연 임펄스 전달 (팔 → 머리 → 몸통 순으로 조금씩 늦게 받는다)
	var rp := recoil_preset()
	var i := 0
	while i < _pending.size():
		_pending[i]["t"] -= delta
		if _pending[i]["t"] <= 0.0:
			match _pending[i]["part"]:
				"head": _head_rc.y += float(rp["head_imp"])
				"body": _body_rc.y += float(rp["body_imp"])
			_pending.remove_at(i)
		else:
			i += 1
	_arm_rc = _spring(_arm_rc, rp["arm"], delta)
	_head_rc = _spring(_head_rc, rp["head"], delta)
	_body_rc = _spring(_body_rc, rp["body"], delta)
	_heat = maxf(_heat - HEAT_DECAY * delta, 0.0)


func _update_reload(delta: float) -> void:
	if not reloading:
		return
	_reload_t += delta
	if _reload_t >= RELOAD_TIME:
		reloading = false
		ammo = MAG_SIZE
		ammo_changed.emit(ammo, MAG_SIZE, false)
		if state != State.ROLL:
			_hide_action_clip()


func start_reload() -> void:
	if reloading or ammo >= MAG_SIZE:
		return
	reloading = true
	_reload_t = 0.0
	Audio.play_at("cloth", global_position, -3.0)
	_body_rc.y -= 6.0          # 탄창 빼는 몸짓 — 살짝 앞으로 숙임
	ammo_changed.emit(ammo, MAG_SIZE, true)
	_show_action_clip("reload")


func _process(delta: float) -> void:
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_run_lock = maxf(_run_lock - delta, 0.0)
	_update_recoil(delta)
	_update_reload(delta)
	if input_enabled and Input.is_action_just_pressed("reload"):
		start_reload()
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			flash.visible = false
			muzzle_light.enabled = false

	var axis := 0.0
	var crouch_held := false
	var run_held := false
	var shoot_pressed := false
	if input_enabled:
		axis = Input.get_axis("move_left", "move_right")
		crouch_held = Input.is_action_pressed("crouch")
		run_held = Input.is_action_pressed("run")
		shoot_pressed = Input.is_action_pressed("shoot")      # 홀드 = 연사
		if Input.is_action_just_pressed("roll") and state != State.ROLL:
			_start_roll(int(signf(axis)) if absf(axis) > 0.1 else facing)
		if Input.is_action_just_pressed("interact") and state != State.ROLL:
			request_front_door.emit()

	if state == State.ROLL:
		_process_roll(delta)
		_update_arm(delta)
		_update_head(delta)
		return

	# 조준 방향이 바라보는 방향을 결정 (구르기 중 제외)
	facing = 1 if aim_target.x >= position.x else -1
	body.flip_h = facing < 0

	# 숙이기 진입/해제
	if crouch_held and state != State.CROUCH:
		state = State.CROUCH
		body.speed_scale = 1.0
		body.play("crouch")
		Audio.play_at("cloth", global_position)
	elif not crouch_held and state == State.CROUCH:
		state = State.UNCROUCH
		body.play_backwards("crouch")
		Audio.play_at("cloth", global_position, -2.0)

	# 사격이 질주를 이긴다: 쏘는 동안(과 그 직후 RUN_FIRE_LOCK)은 Shift 를 눌러도 걷기로 내려온다
	if shoot_pressed:
		_run_lock = RUN_FIRE_LOCK
	var running := run_held and _run_lock <= 0.0

	# 이동 - 가속/감속 이징 (숙인 동안은 감속만)
	var target_speed := RUN_SPEED if running else WALK_SPEED
	var target_v := axis * target_speed if (state != State.CROUCH and state != State.UNCROUCH) else 0.0
	var rate := ACCEL
	_slide_t = maxf(_slide_t - delta, 0.0)
	if absf(target_v) < 1.0:
		# 구르기 직후엔 약하게 감속해 살짝 더 미끄러진다
		rate = ROLL_SLIDE_DECEL if _slide_t > 0.0 else DECEL
	elif signf(target_v) != signf(velocity_x) and absf(velocity_x) > 1.0:
		rate = TURN_DECEL
	velocity_x = move_toward(velocity_x, target_v, rate * delta)
	var moving := absf(velocity_x) > WALK_THRESHOLD
	if absf(velocity_x) > 0.5:
		position.x = clampf(position.x + velocity_x * delta, min_x, max_x)

	# 걷기/달리기 포즈를 별도 클립으로 재생한다. 조준 반대 방향은 역재생.
	if state == State.IDLE or state == State.WALK or state == State.RUN:
		var want: State = State.IDLE
		if moving:
			want = State.RUN if running and absf(velocity_x) > RUN_CLIP_SPEED else State.WALK
		if want != state:
			state = want
			body.play("run" if state == State.RUN else ("walk" if state == State.WALK else "idle"))
		if state == State.WALK or state == State.RUN:
			var backwards := signf(velocity_x) != signf(float(facing))
			var clip_speed := RUN_SPEED if state == State.RUN else WALK_SPEED
			var k := clampf(absf(velocity_x) / clip_speed, 0.35, 1.0)
			body.speed_scale = -k if backwards else k
		else:
			body.speed_scale = 1.0

	_update_breath(delta)

	# 사격 - 누르고 있는 동안 쿨다운마다 한 발 (첫 발 즉발). 탄창이 비면 자동 재장전.
	# 질주 속도가 남아 있는 동안은 발사되지 않는다 — 위에서 이미 걷기로 감속을 시작했으므로
	# 브레이크를 밟듯 아주 짧게 늦춰졌다가 나간다.
	if shoot_pressed and _fire_cd <= 0.0 and not reloading and absf(velocity_x) <= FIRE_MAX_SPEED:
		if ammo > 0:
			_fire()
		else:
			start_reload()

	_update_arm(delta)
	_update_head(delta)


## 머리 위치·회전 갱신. 몸 프레임에 맞는 머리 텍스처를 고르고 목 앵커에 붙인 뒤,
## 조준 방향으로 HEAD_MAX_ANGLE 안에서만 기울인다. 구르기 중엔 기울이지 않는다(몸과 함께 회전).
func _update_head(delta: float, snap := false) -> void:
	if action_visual != null and action_visual.visible:
		head.visible = false
		action_visual.flip_h = facing < 0
		return
	var key := "%s_%02d" % [body.animation, body.frame + 1]
	var tex: Texture2D = _head_tex.get(key)
	head.visible = tex != null
	if tex == null:
		return
	head.texture = tex
	var neck: Vector2 = _necks.get(key, DEFAULT_NECK)
	# 머리 텍스처는 320 셀 그대로 — 목 픽셀이 원점에 오도록 오프셋
	head.offset = -(neck + Vector2(FRAME_SIZE * 0.5, FRAME_SIZE))
	# 목 앵커: 몸 스프라이트 로컬(=BodyPivot 로컬)에서 목 픽셀 위치. flip_h 는 셀 중심 기준 반전이므로 x 부호만 뒤집는다.
	head_pivot.position = body.offset + Vector2(FRAME_SIZE * 0.5, FRAME_SIZE) + Vector2(neck.x * facing, neck.y)

	var base := 0.0 if facing > 0 else PI
	var rel := 0.0
	if state != State.ROLL:
		var to_target := aim_target - head_pivot.global_position
		rel = clampf(angle_difference(base, to_target.angle()), -HEAD_MAX_ANGLE, HEAD_MAX_ANGLE)
	var target_angle := base + rel
	if snap or delta <= 0.0:
		_head_angle = target_angle
	else:
		_head_angle = lerp_angle(_head_angle, target_angle, minf(1.0, HEAD_SMOOTH * delta))
	# 왼쪽을 볼 때는 팔과 같은 방식으로 y 반전 + π 회전 → 좌우 반전
	head_pivot.scale = Vector2(1, -1) if facing < 0 else Vector2(1, 1)
	# 반동: 머리가 뒤로 젖혀지며(위) 조금 밀린다 — 몸통과 다른 스프링이라 따로 흔들린다
	var rp := recoil_preset()
	var head_k := _head_rc.x
	head_pivot.rotation = _head_angle + float(rp["head_rad"]) * head_k * (-1.0 if facing > 0 else 1.0)
	head_pivot.position.x += -facing * float(rp["head_px"]) * head_k
	head_pivot.skew = -body_pivot.skew         # 몸통 전단이 머리 스프라이트를 찌그러뜨리지 않게 상쇄


## Idle 숨쉬기: 발 위치를 고정한 채 BodyPivot 스케일을 잔잔하게 트위닝
func _update_breath(delta: float) -> void:
	var want := Vector2.ONE
	if state == State.IDLE or state == State.CROUCH:
		_breath_t += delta
		var w := 0.5 - 0.5 * cos(TAU * _breath_t / BREATH_PERIOD)   # 0..1 부드러운 왕복
		want = Vector2(1.0 - BREATH_SCALE.x * w, 1.0 + BREATH_SCALE.y * w)
	else:
		_breath_t = 0.0
	_breath = _breath.lerp(want, minf(1.0, 6.0 * delta))
	# 반동: 발은 고정(마찰)하고 상체만 뒤로 밀린다 — 전단(skew) + 발 위치 보정, 여기에 눌림(scale.y)
	var rp := recoil_preset()
	var body_k := _body_rc.x
	var lean := -facing * float(rp["body_px"]) * body_k            # 머리 높이에서의 X 이동량
	var sy := _breath.y * (1.0 - float(rp.get("body_squat", 0.0)) * absf(body_k))
	body_pivot.scale = Vector2(_breath.x, sy)
	# skew: 로컬 y 에 비례해 x 가 -sin(skew)·y 만큼 밀린다. 머리(y=-C) 는 +sin·C, 발(y=+C) 은 -sin·C 로 반대 →
	# 반씩 나눠 skew 로 만들고 나머지 반은 위치로 보정하면 발 0 · 머리 lean
	var half := clampf(lean * 0.5 / BODY_CENTER_Y, -0.6, 0.6)
	body_pivot.skew = asin(half)
	body_pivot.position = Vector2(lean * 0.5, -BODY_CENTER_Y * sy)
	body_pivot.rotation = 0.0


func _fire() -> void:
	_fire_cd = FIRE_COOLDOWN
	ammo -= 1
	_flash_t = FLASH_TIME
	flash.visible = true
	muzzle_light.enabled = true
	flash.rotation = randf_range(-0.3, 0.3)
	flash.scale = Vector2.ONE * randf_range(0.85, 1.25)
	# 반동 임펄스: 팔은 즉시 속도 임펄스(뒤로 확 → 앞으로 되튐), 머리·몸통은 지연 뒤 (절차적 연쇄)
	var rp := recoil_preset()
	Audio.fire(muzzle.global_position)
	_arm_rc.y += float(rp["arm_imp"])
	_pending.append({"t": rp["arm"].z + rp["head"].z, "part": "head"})
	_pending.append({"t": rp["arm"].z + rp["body"].z, "part": "body"})
	# 산탄: 조준점을 총구 기준 각도로 흔든다 (열이 오를수록 크게)
	var to_aim := aim_target - muzzle.global_position
	var spread := SPREAD_BASE + SPREAD_HEAT * _heat
	var target := muzzle.global_position + to_aim.rotated(randf_range(-spread, spread) * randf_range(0.4, 1.0))
	_heat = minf(_heat + HEAT_PER_SHOT, 1.0)
	_update_arm(0.0, true)
	shoot_fired.emit(muzzle.global_position, target)
	shell_ejected.emit(arm_pivot.to_global(EJECT_LOCAL), facing)
	ammo_changed.emit(ammo, MAG_SIZE, false)
	if ammo <= 0:
		start_reload()


func spread_ratio() -> float:
	return _heat


## 어깨 위치·팔 회전 갱신. 몸 애니 프레임에 맞춰 어깨 앵커를 따라간다.
func _update_arm(delta: float, snap := false) -> void:
	if action_visual != null and action_visual.visible:
		arm_pivot.visible = false
		action_visual.flip_h = facing < 0
		return
	if state == State.ROLL:
		arm_pivot.visible = false
		return
	arm_pivot.visible = true

	var key := "%s_%02d" % [body.animation, body.frame + 1]
	var shoulder: Vector2 = _shoulders.get(key, DEFAULT_SHOULDER)
	shoulder.x *= facing
	arm_pivot.position = shoulder * _breath      # 숨쉬기 스케일에 맞춰 어깨도 따라감

	var to_target := aim_target - arm_pivot.global_position
	var target_angle := to_target.angle()
	if reloading:
		# 재장전: 팔이 아래로 내려가 총을 두 번 흔든다 (빼기·끼우기)
		var k := clampf(_reload_t / RELOAD_TIME, 0.0, 1.0)
		var drop := sin(k * PI)                                   # 0 → 1 → 0
		var jiggle := sin(k * TAU * 2.0) * 0.12 * drop
		var base := 0.0 if facing > 0 else PI
		target_angle = base + (RELOAD_ARM_DROP * drop + jiggle) * (1.0 if facing > 0 else -1.0)
	if snap or delta <= 0.0:
		_arm_angle = target_angle
	else:
		var sm := AIM_SMOOTH if not reloading else 14.0
		_arm_angle = lerp_angle(_arm_angle, target_angle, minf(1.0, sm * delta))

	# 왼쪽을 볼 때는 팔 축 기준으로 상하 반전해서 총이 뒤집히지 않게 한다.
	# scale.y = -1 이면 로컬 회전의 시각적 방향도 반전되므로 반동 각도 부호를 보정한다.
	arm_pivot.scale = Vector2(1, -1) if facing < 0 else Vector2(1, 1)
	var rp := recoil_preset()
	var arm_k := _arm_rc.x
	var kick_angle := float(rp["arm_rad"]) * arm_k * (-1.0 if facing > 0 else 1.0)
	arm_pivot.rotation = _arm_angle + kick_angle
	arm.position = Vector2(-float(rp["arm_px"]) * arm_k, 0)


func _start_roll(dir: int) -> void:
	state = State.ROLL
	_roll_t = 0.0
	_roll_dist = 0.0
	_roll_dir = dir if dir != 0 else facing
	facing = _roll_dir
	body.flip_h = facing < 0
	body.speed_scale = 1.0
	Audio.play_at("cloth", global_position, 2.0)
	_show_action_clip("roll")
	body.play("crouch")
	body.frame = 3                   # 웅크린 프레임으로 구른다
	body.pause()
	# 회전축을 웅크린 실루엣의 중심으로 옮긴다 (발 밑 원점은 유지)
	_breath = Vector2.ONE
	body_pivot.scale = Vector2.ONE
	body_pivot.skew = 0.0
	head_pivot.skew = 0.0
	body_pivot.position = Vector2(ROLL_CENTER.x * facing, -ROLL_CENTER.y)
	body.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE) - body_pivot.position


## 구르기 속도 프로파일 (k = 0..1): 짧게 가속해 정점을 찍고 뒤로 갈수록 점점 느려진다
static func _roll_speed(k: float) -> float:
	var accel := smoothstep(0.0, ROLL_ACCEL_PORTION, k)
	var decel := 1.0 - ROLL_DECEL * pow(k, ROLL_DECEL_POW)
	return ROLL_PEAK * accel * decel


func _process_roll(delta: float) -> void:
	_roll_t += delta
	var t := clampf(_roll_t / ROLL_TIME, 0.0, 1.0)
	var step := _roll_speed(t) * delta
	_roll_dist += step
	position.x = clampf(position.x + _roll_dir * step, min_x, max_x)
	# 회전은 시간이 아니라 이동 거리에 비례 — 빠를 때 빨리 돌고 멈출 때 천천히 돈다
	body_pivot.rotation = TAU * clampf(_roll_dist / ROLL_DISTANCE, 0.0, 1.0) * _roll_dir
	if _roll_t >= ROLL_TIME:
		state = State.IDLE
		body_pivot.rotation = 0.0
		body_pivot.position = Vector2(0, -BODY_CENTER_Y)
		body.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE + BODY_CENTER_Y)
		Audio.play_at("land", global_position)
		velocity_x = _roll_dir * SPEED * ROLL_EXIT_SPEED    # 구르기 끝에 관성이 남아 미끄러지며 이어진다
		_slide_t = ROLL_SLIDE_TIME
		body.play("idle")
		_hide_action_clip()
		_resume_reload_action()


## 걷기·달리기 클립의 접지 프레임에서만 발소리를 낸다.
## 타이머가 아니라 프레임에 묶여 있어 speed_scale(속도 비례)에 자동으로 따라간다.
func _on_body_frame() -> void:
	if state != State.WALK and state != State.RUN:
		return
	if body.frame != 0 and body.frame != 2:
		return
	Audio.play_at("footstep", global_position, 0.0 if state == State.RUN else -3.5)


func _on_animation_finished() -> void:
	match state:
		State.UNCROUCH:
			state = State.IDLE
			body.play("idle")
		State.CROUCH:
			pass   # 마지막 프레임 유지


func set_bounds(left: float, right: float) -> void:
	min_x = left
	max_x = right
	position.x = clampf(position.x, min_x, max_x)


func face(dir: int) -> void:
	facing = dir
	body.flip_h = facing < 0
	aim_target = position + Vector2(400 * dir, -140)
	if arm_pivot:
		_update_arm(0.0, true)
	if head_pivot:
		_update_head(0.0, true)


func is_rolling() -> bool:
	return state == State.ROLL


## 외부 충격(몬스터 독액)으로 밀린다. 구르기 중엔 무시(회피).
func knockback(vx: float) -> void:
	if state == State.ROLL:
		return
	velocity_x = vx
