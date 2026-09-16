class_name Player
extends Node2D
## 붉은 후드 정비공. 위치는 바닥 월드 좌표(발 밑).
## 구조:  Player
##          BodyPivot (몸 중심, 구르기 회전축)
##            Body      AnimatedSprite2D  — idle(조준 자세 1프레임) / walk(다리만 애니) / crouch
##          ArmPivot   (어깨 앵커, 마우스 방향으로 실시간 회전)
##            Arm       Sprite2D  — 팔+총 (어깨가 원점)
##            Muzzle    Marker2D  — 총구
##            Flash     Sprite2D  — 총구 화염
## 상태 우선순위: Roll > Crouch > Walk > Idle. 사격은 Roll 이 아닐 때 언제나 가능(즉발).

signal shoot_fired(muzzle_pos: Vector2, target_pos: Vector2)
signal shell_ejected(pos: Vector2, dir: int)
signal request_front_door()

const FRAME_SIZE := 320
const SPLIT_DIR := "res://assets/character/Split/"
const CLIPS := {
	"idle":   {"fps": 1.0, "loop": true,  "frames": 1},
	"walk":   {"fps": 16.0, "loop": true,  "frames": 4},
	"crouch": {"fps": 12.0, "loop": false, "frames": 4},
}
const BODY_CENTER_Y := 150.0        # 발 밑 기준 몸 중심 높이
const ROLL_CENTER := Vector2(10.0, 103.0)   # 웅크린 프레임(crouch_04) 내용물 중심 (발 밑 기준, 오른쪽 방향)
const DEFAULT_SHOULDER := Vector2(39, -142)
const EJECT_LOCAL := Vector2(46, -14)     # 어깨 기준 탄피 배출구 (팔 로컬)

const SPEED := 840.0
const WALK_THRESHOLD := 30.0
const ACCEL := 5200.0               # 출발 가속 (px/s^2) - 약 0.16초에 최고속
const DECEL := 3600.0               # 정지 감속 - 약 0.23초에 멈춤, 살짝 미끄러짐
const TURN_DECEL := 7000.0          # 반대 방향으로 꺾을 때는 더 빨리 감속

# 숨쉬기 (Idle) - 발을 고정한 채 스케일 트위닝
const BREATH_PERIOD := 2.6
const BREATH_SCALE := Vector2(0.012, 0.028)   # x는 살짝 줄고 y는 늘어남

# 사격 — 카타나 제로식 즉발·고속 연사
const FIRE_COOLDOWN := 0.09         # 초. 한 발씩(클릭마다) 발사, 최소 간격
const RECOIL_KICK := 14.0           # 팔이 뒤로 밀리는 픽셀
const RECOIL_ANGLE := 0.14          # 팔이 위로 튀는 라디안
const RECOIL_RETURN := 44.0         # 복귀 속도
const FLASH_TIME := 0.03
const AIM_SMOOTH := 80.0            # 팔 회전 보간 속도 (클수록 즉각적)

# 구르기 (Space)
const ROLL_TIME := 0.18             # 2배 템포
const ROLL_SPEED := 3150.0          # 1050 ×2(템포) ×1.5(거리 +50%)

enum State { IDLE, WALK, CROUCH, UNCROUCH, ROLL }

var state: State = State.IDLE
var facing := 1                     # 1 = 오른쪽, -1 = 왼쪽 (조준 방향이 결정)
var velocity_x := 0.0
var input_enabled := true
var min_x := 0.0
var max_x := 10000.0
var aim_target := Vector2.ZERO      # 월드 좌표. Main 이 매 프레임 마우스 위치를 넣어준다

var _fire_cd := 0.0
var _recoil := 0.0                  # 1 → 0 감쇠
var _flash_t := 0.0
var _roll_t := 0.0
var _roll_dir := 1
var _arm_angle := 0.0
var _breath_t := 0.0
var _breath := Vector2.ONE
var _meta := {}
var _shoulders := {}                # "walk_02" → 어깨 오프셋(바닥 중심 기준, 오른쪽 방향)

var body_pivot: Node2D
var body: AnimatedSprite2D
var arm_pivot: Node2D
var arm: Sprite2D
var muzzle: Marker2D
var flash: Sprite2D
var muzzle_light: PointLight2D


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
	body.material = Lighting.lit_material()            # 노멀맵 라이팅 + 림라이트
	body_pivot.add_child(body)
	body.animation_finished.connect(_on_animation_finished)
	body.play("idle")

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
	arm.material = Lighting.lit_material()
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
	muzzle_light.texture_scale = 2.2
	muzzle_light.color = Lighting.GUN_LIGHT
	muzzle_light.energy = 1.8
	muzzle_light.height = Lighting.FLASH_HEIGHT
	muzzle_light.position = muzzle.position
	muzzle_light.enabled = false
	arm_pivot.add_child(muzzle_light)

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


func _process(delta: float) -> void:
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_recoil = maxf(_recoil - RECOIL_RETURN * delta * maxf(_recoil, 0.15), 0.0)
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			flash.visible = false
			muzzle_light.enabled = false

	var axis := 0.0
	var crouch_held := false
	var shoot_pressed := false
	if input_enabled:
		axis = Input.get_axis("move_left", "move_right")
		crouch_held = Input.is_action_pressed("crouch")
		shoot_pressed = Input.is_action_just_pressed("shoot")
		if Input.is_action_just_pressed("roll") and state != State.ROLL:
			_start_roll(int(signf(axis)) if absf(axis) > 0.1 else facing)
		if Input.is_action_just_pressed("interact") and state != State.ROLL:
			request_front_door.emit()

	if state == State.ROLL:
		_process_roll(delta)
		_update_arm(delta)
		return

	# 조준 방향이 바라보는 방향을 결정 (구르기 중 제외)
	facing = 1 if aim_target.x >= position.x else -1
	body.flip_h = facing < 0

	# 숙이기 진입/해제
	if crouch_held and state != State.CROUCH:
		state = State.CROUCH
		body.speed_scale = 1.0
		body.play("crouch")
	elif not crouch_held and state == State.CROUCH:
		state = State.UNCROUCH
		body.play_backwards("crouch")

	# 이동 - 가속/감속 이징 (숙인 동안은 감속만)
	var target_v := axis * SPEED if (state != State.CROUCH and state != State.UNCROUCH) else 0.0
	var rate := ACCEL
	if absf(target_v) < 1.0:
		rate = DECEL
	elif signf(target_v) != signf(velocity_x) and absf(velocity_x) > 1.0:
		rate = TURN_DECEL
	velocity_x = move_toward(velocity_x, target_v, rate * delta)
	var moving := absf(velocity_x) > WALK_THRESHOLD
	if absf(velocity_x) > 0.5:
		position.x = clampf(position.x + velocity_x * delta, min_x, max_x)

	# Idle / Walk 결정. 조준 반대 방향으로 걸으면 역재생(뒷걸음)
	if state == State.IDLE or state == State.WALK:
		var want: State = State.WALK if moving else State.IDLE
		if want != state:
			state = want
			body.play("walk" if moving else "idle")
		if state == State.WALK:
			# 걷기 애니 속도는 실제 속도에 비례, 조준 반대 방향이면 역재생(뒷걸음)
			var backwards := signf(velocity_x) != signf(float(facing))
			var k := clampf(absf(velocity_x) / SPEED, 0.35, 1.0)
			body.speed_scale = -k if backwards else k
		else:
			body.speed_scale = 1.0

	_update_breath(delta)

	# 사격 - 클릭마다 한 발 (즉발)
	if shoot_pressed and _fire_cd <= 0.0:
		_fire()

	_update_arm(delta)


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
	body_pivot.scale = _breath
	body_pivot.position = Vector2(0, -BODY_CENTER_Y * _breath.y)


func _fire() -> void:
	_fire_cd = FIRE_COOLDOWN
	_recoil = 1.0
	_flash_t = FLASH_TIME
	flash.visible = true
	muzzle_light.enabled = true
	flash.rotation = randf_range(-0.3, 0.3)
	flash.scale = Vector2.ONE * randf_range(0.85, 1.25)
	_update_arm(0.0, true)
	shoot_fired.emit(muzzle.global_position, aim_target)
	shell_ejected.emit(arm_pivot.to_global(EJECT_LOCAL), facing)


## 어깨 위치·팔 회전 갱신. 몸 애니 프레임에 맞춰 어깨 앵커를 따라간다.
func _update_arm(delta: float, snap := false) -> void:
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
	if snap or delta <= 0.0:
		_arm_angle = target_angle
	else:
		_arm_angle = lerp_angle(_arm_angle, target_angle, minf(1.0, AIM_SMOOTH * delta))

	# 왼쪽을 볼 때는 팔 축 기준으로 상하 반전해서 총이 뒤집히지 않게 한다.
	# scale.y = -1 이면 로컬 회전의 시각적 방향도 반전되므로 반동 각도 부호를 보정한다.
	arm_pivot.scale = Vector2(1, -1) if facing < 0 else Vector2(1, 1)
	var kick_angle := RECOIL_ANGLE * _recoil * (-1.0 if facing > 0 else 1.0)
	arm_pivot.rotation = _arm_angle + kick_angle
	arm.position = Vector2(-RECOIL_KICK * _recoil, 0)


func _start_roll(dir: int) -> void:
	state = State.ROLL
	_roll_t = 0.0
	_roll_dir = dir if dir != 0 else facing
	facing = _roll_dir
	body.flip_h = facing < 0
	body.speed_scale = 1.0
	body.play("crouch")
	body.frame = 3                   # 웅크린 프레임으로 구른다
	body.pause()
	# 회전축을 웅크린 실루엣의 중심으로 옮긴다 (발 밑 원점은 유지)
	_breath = Vector2.ONE
	body_pivot.scale = Vector2.ONE
	body_pivot.position = Vector2(ROLL_CENTER.x * facing, -ROLL_CENTER.y)
	body.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE) - body_pivot.position


func _process_roll(delta: float) -> void:
	_roll_t += delta
	var t := clampf(_roll_t / ROLL_TIME, 0.0, 1.0)
	var speed := ROLL_SPEED * (1.0 - 0.55 * t)       # 감속
	position.x = clampf(position.x + _roll_dir * speed * delta, min_x, max_x)
	body_pivot.rotation = TAU * t * _roll_dir
	if _roll_t >= ROLL_TIME:
		state = State.IDLE
		body_pivot.rotation = 0.0
		body_pivot.position = Vector2(0, -BODY_CENTER_Y)
		body.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE + BODY_CENTER_Y)
		velocity_x = _roll_dir * SPEED * 0.6      # 구르기 끝에 관성이 남아 자연스럽게 이어진다
		body.play("idle")


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


func is_rolling() -> bool:
	return state == State.ROLL
