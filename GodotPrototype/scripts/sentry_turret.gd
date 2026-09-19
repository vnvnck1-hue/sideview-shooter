class_name SentryTurret
extends Node2D
## 바닥 격납형 센트리건. 원점 = 바닥 설치 지점(해치 중심).
##
## 평소엔 바닥과 같은 높이의 해치(전개 시트 1프레임)로 묻혀 있다가, 플레이어가 옆에서 W/↑ 로 기동하면
## 8프레임 전개 애니(sentry_turret_deploy_direct_v1_sheet, 10fps)로 바닥에서 솟아오른다.
## 전개가 끝나면 마지막 프레임을 **머리(포신 어셈블리 + 급탄 호스)** 와 **받침(요동 실린더 · 기둥 · 해치 꽃잎)** 으로
## 갈라 둔 두 장(Tools/build_sentry_turret_parts.py)으로 바꿔 끼우고, 머리만 요동축(pivot)에서 부앙시킨다.
##   · 머리는 받침 **뒤**에 그린다 — 분리하며 생긴 단면이 요동 실린더·기둥에 가린다.
##   · 좌우 조준은 전체(_flip)를 x 반전 → 호스·급탄부가 항상 포신 반대쪽에 온다.
##   · 부앙각은 ±ELEV_MAX 로 제한한다 (그 이상 돌리면 호스가 받침에서 떨어져 보인다).
##
## 조종: Main 이 aim_target(마우스 월드 좌표)을 넣어 주고, 좌클릭을 누르는 동안 두 포신이 번갈아 발사된다.
## 사격 연출은 MuzzleBlast(화염·연기·불꽃·라이트) + 탄피 + 카메라 흔들림. 탄 자체는 Main 이 플레이어 사격과 같은 경로로 쏜다.
## 조종을 놓으면 천천히 좌우를 훑다가 IDLE_RETRACT 초 뒤 해치 안으로 다시 접힌다.

signal shoot_fired(muzzle_pos: Vector2, target_pos: Vector2)
signal shell_ejected(pos: Vector2, dir: int)
signal ammo_changed(ammo: int, belt: int, reloading: bool)
signal shake_requested(amount: float)
signal control_changed(active: bool)

const DIR := "res://assets/props/defense/sentry/"
const META := DIR + "sentry_turret.json"
const DEPLOY_FMT := DIR + "deploy/sentry_deploy_%02d.png"

const INTERACT_RANGE := 260.0       # 이 거리 안에서 W/↑ 로 기동·조종
const ELEV_MAX := 0.45              # 부앙 한계 (rad, ≈26°)
const AIM_SMOOTH := 16.0            # 포신 회전 보간 (플레이어 팔보다 묵직하게)
const FIRE_COOLDOWN := 0.11         # 초 (≈9발/초, 포신 2개가 번갈아)
const BELT := 48                    # 탄띠 한 벌
const RELOAD_TIME := 2.1            # 급탄 시간
const SPREAD := 0.016
const SHAKE_PER_SHOT := 5.2         # 플레이어(3.5)보다 묵직
const KICK_IMPULSE := 150.0         # 포신 후퇴 임펄스
const KICK_SPRING := Vector3(1500.0, 78.0, 0.0)
const KICK_PX := 16.0               # 포신이 뒤로 밀리는 최대 px
const IDLE_SCAN := 0.55             # 무인 상태에서 좌우를 훑는 속도
const IDLE_RETRACT := 14.0          # 조종을 놓고 이 시간이 지나면 격납
const OPTIC_LOCAL := Vector2(22, -146)   # 요동축 기준 광학 조준경 위치

enum State { STOWED, RISING, READY, RETRACTING }

var state: State = State.STOWED
var controlled := false
var aim_target := Vector2.ZERO
var facing := 1
var ammo := BELT
var reloading := false
var floor_y := 0.0

var _meta := {}
var _pivot := Vector2(-30, -226)
var _flip: Node2D
var _deploy: AnimatedSprite2D
var _head_pivot: Node2D
var _recoil: Node2D                 # 포신 후퇴 (머리 안에서 x 로만 밀린다)
var _head: Sprite2D
var _base: Sprite2D
var _muzzles: Array = []            # Marker2D ×2 (위·아래 포신)
var _blasts: Array = []             # MuzzleBlast ×2
var _eject: Marker2D
var _optic: PointLight2D
var _dust: CPUParticles2D
var _fx_parent: Node2D              # 불꽃·탄피를 담을 월드 층 (Room)

var _angle := 0.0
var _kick := Vector2.ZERO           # (값, 속도) 2차 스프링 — 값 1.0 = 한 발 후퇴
var _fire_cd := 0.0
var _reload_t := 0.0
var _barrel := 0
var _idle_t := 0.0
var _scan_t := 0.0


## center_x = 바닥 설치 지점, floor_line = 바닥선, fx = 불꽃·연기를 담을 월드 층
func setup(center_x: float, floor_line: float, fx: Node2D) -> void:
	name = "SentryTurret"
	position = Vector2(center_x, floor_line)
	floor_y = floor_line
	_fx_parent = fx


func _ready() -> void:
	_load_meta()

	_flip = Node2D.new()
	_flip.name = "Flip"
	add_child(_flip)

	# 전개 애니 (STOWED·RISING·RETRACTING 동안만 보인다). 시트는 프레임마다 접지선·받침 중심을 맞춰 두었다.
	var anchor: Vector2 = _vec(_meta.get("anchor", [208, 440]))
	_deploy = AnimatedSprite2D.new()
	_deploy.name = "Deploy"
	_deploy.centered = false
	_deploy.offset = -anchor
	_deploy.sprite_frames = _build_deploy_frames()
	_deploy.material = Lighting.shader_material("prop_surface")
	_deploy.animation = "deploy"
	_deploy.frame = 0
	_deploy.animation_finished.connect(_on_deploy_finished)
	_flip.add_child(_deploy)

	# 머리 (받침보다 먼저 = 뒤에 그린다)
	_head_pivot = Node2D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = _pivot
	_head_pivot.visible = false
	_flip.add_child(_head_pivot)

	_recoil = Node2D.new()
	_recoil.name = "Recoil"
	_head_pivot.add_child(_recoil)

	_head = Sprite2D.new()
	_head.name = "Head"
	_head.centered = false
	_head.texture = Lighting.textured(DIR + "sentry_head.png")
	_head.offset = _vec(_meta.get("head_offset", [-105, -197]))
	_head.material = Lighting.shader_material("prop_surface")
	_recoil.add_child(_head)

	for m in _meta.get("muzzles", [[222, -96], [218, -62]]):
		var mk := Marker2D.new()
		mk.name = "Muzzle"
		mk.position = _vec(m)
		_recoil.add_child(mk)
		_muzzles.append(mk)
		var blast := MuzzleBlast.new()
		blast.name = "Blast"
		blast.position = mk.position
		blast.fx_parent = _fx_parent
		_recoil.add_child(blast)
		blast.setup(1.15, floor_y)
		_blasts.append(blast)

	_eject = Marker2D.new()
	_eject.name = "Eject"
	_eject.position = _vec(_meta.get("eject", [86, -20]))
	_recoil.add_child(_eject)

	# 광학 조준경의 호박색 눈 — 대기 중엔 약하게, 조종 중엔 밝게
	_optic = PointLight2D.new()
	_optic.name = "Optic"
	_optic.texture = Lighting.radial_texture()
	_optic.texture_scale = Lighting.scale_for_radius(150.0)
	_optic.color = Color(1.0, 0.68, 0.24)
	_optic.height = Lighting.FLASH_HEIGHT
	_optic.energy = 0.0
	_optic.position = OPTIC_LOCAL
	_recoil.add_child(_optic)

	# 받침 (머리 앞에 그려 분리 단면을 가린다)
	_base = Sprite2D.new()
	_base.name = "Base"
	_base.centered = false
	_base.texture = Lighting.textured(DIR + "sentry_base.png")
	_base.offset = _vec(_meta.get("base_offset", [-189, -244]))
	_base.material = Lighting.shader_material("prop_surface")
	_base.visible = false
	_flip.add_child(_base)

	_dust = _build_dust()
	add_child(_dust)


func _load_meta() -> void:
	var f := FileAccess.open(META, FileAccess.READ)
	if f == null:
		push_warning("sentry_turret.json 을 읽을 수 없음 — 기본 앵커 사용")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_meta = parsed
		_pivot = _vec(_meta.get("pivot", [-30, -226]))


static func _vec(a) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO


func _build_deploy_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("deploy")
	sf.set_animation_speed("deploy", float(_meta.get("fps", 10)))
	sf.set_animation_loop("deploy", false)
	for i in range(int(_meta.get("frame_count", 8))):
		var path := DEPLOY_FMT % (i + 1)
		if ResourceLoader.exists(path):
			sf.add_frame("deploy", Lighting.textured(path))
		else:
			push_warning("센트리건 전개 프레임 없음: %s" % path)
	return sf


## 해치가 열리고 본체가 솟을 때 바닥에서 밀려 나오는 먼지
func _build_dust() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Dust"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = 22
	p.lifetime = 1.3
	p.local_coords = false
	p.texture = Lighting.smoke_canvas_texture()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(180, 6)
	p.direction = Vector2(0, -1)
	p.spread = 78.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, -40.0)
	p.damping_min = 160.0
	p.damping_max = 260.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.62, 0.60, 0.58, 0.5))
	grad.set_color(1, Color(0.38, 0.39, 0.44, 0.0))
	p.color_ramp = grad
	return p


# ── 상태 전환 ────────────────────────────────────────────────────────────────

## 플레이어가 이 센트리건을 기동할 수 있나 (거리 · 상태)
func can_interact(px: float) -> bool:
	return absf(px - position.x) <= INTERACT_RANGE and state != State.RISING


func prompt_text() -> String:
	if controlled:
		return "▲  W / ↑  —  센트리건 조종 해제"
	if state == State.READY:
		return "▲  W / ↑  —  센트리건 조종"
	return "▲  W / ↑  —  센트리건 전개"


## W/↑ 한 번: 접혀 있으면 전개(끝나면 자동으로 조종), 서 있으면 조종 잡기/놓기
func activate() -> void:
	match state:
		State.STOWED, State.RETRACTING:
			_start_deploy()
		State.READY:
			set_controlled(not controlled)
		_:
			pass


func set_controlled(active: bool) -> void:
	if controlled == active:
		return
	controlled = active
	_idle_t = 0.0
	if not active:
		reloading = false
		_reload_t = 0.0
	control_changed.emit(active)
	if active:
		ammo_changed.emit(ammo, BELT, reloading)


func _start_deploy() -> void:
	var resume := state == State.RETRACTING     # 접히던 중이면 그 프레임부터 도로 올라온다
	state = State.RISING
	_deploy.visible = true
	_base.visible = false
	_head_pivot.visible = false
	if not resume:
		_deploy.frame = 0
	_deploy.play("deploy")
	if resume:
		return
	# 해치가 열리며 바닥에서 먼지와 불꽃이 밀려 나온다
	_dust.restart()
	if _fx_parent != null:
		var sb := SparkBurst.spawn(_fx_parent, floor_y)
		sb.burst(global_position, 12, Vector2(0, -1), 1.1, Vector2(160, 520),
			Color(1.0, 0.9, 0.7), Color(1.0, 0.3, 0.1), Vector2(0.25, 0.7), 2200.0, 3.0)
	shake_requested.emit(6.0)


func _set_ready() -> void:
	state = State.READY
	_deploy.visible = false
	_base.visible = true
	_head_pivot.visible = true
	ammo = BELT
	reloading = false
	_reload_t = 0.0
	_angle = 0.0
	_update_head(0.0, true)
	shake_requested.emit(3.5)                # 마지막으로 '쿵' 하고 자리를 잡는다
	set_controlled(true)                      # 기동시킨 사람이 그대로 잡는다


func _start_retract() -> void:
	state = State.RETRACTING
	set_controlled(false)
	_deploy.visible = true
	_base.visible = false
	_head_pivot.visible = false
	_deploy.frame = _deploy.sprite_frames.get_frame_count("deploy") - 1
	_deploy.play_backwards("deploy")
	_dust.restart()


func _on_deploy_finished() -> void:
	match state:
		State.RISING:
			_set_ready()
		State.RETRACTING:
			state = State.STOWED
			_deploy.frame = 0
			_deploy.stop()


# ── 매 프레임 ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_kick = _spring(_kick, KICK_SPRING, delta)
	_recoil.position.x = -KICK_PX * _kick.x
	_optic.energy = lerpf(_optic.energy, _optic_target(), minf(1.0, 6.0 * delta))

	if state != State.READY:
		return

	_fire_cd = maxf(_fire_cd - delta, 0.0)
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			reloading = false
			ammo = BELT
			ammo_changed.emit(ammo, BELT, false)

	if controlled:
		_idle_t = 0.0
		if Input.is_action_pressed("shoot"):
			_try_fire()
	else:
		# 무인 대기: 천천히 좌우를 훑다가 격납
		_scan_t += delta
		_idle_t += delta
		if _idle_t >= IDLE_RETRACT:
			_start_retract()
			return
	_update_head(delta)


func _optic_target() -> float:
	if state != State.READY:
		return 0.0
	return 1.5 if controlled else 0.45


static func _spring(s: Vector2, p: Vector3, delta: float) -> Vector2:
	s.y += -s.x * p.x * delta
	s.y *= exp(-p.y * delta)
	s.x += s.y * delta
	return s


## 포신 방향. 조종 중이면 마우스를, 무인이면 천천히 훑는 각도를 향한다.
func _update_head(delta: float, snap := false) -> void:
	var want := 0.0
	if controlled:
		var to := aim_target - _head_pivot.global_position
		facing = 1 if to.x >= 0.0 else -1
		_flip.scale.x = float(facing)
		# 좌우 반전 층 안에서는 로컬 회전이 거울로 보인다 — 왼쪽을 볼 때 PI − θ 가 실제 포신 방향
		var theta := to.angle()
		want = angle_difference(0.0, theta if facing > 0 else PI - theta)
	else:
		want = sin(_scan_t * IDLE_SCAN) * ELEV_MAX * 0.5
	want = clampf(want, -ELEV_MAX, ELEV_MAX)
	if snap or delta <= 0.0:
		_angle = want
	else:
		_angle = lerp_angle(_angle, want, minf(1.0, AIM_SMOOTH * delta))
	_head_pivot.rotation = _angle


func _try_fire() -> void:
	if reloading or _fire_cd > 0.0:
		return
	if ammo <= 0:
		_start_reload()
		return
	_fire_cd = FIRE_COOLDOWN
	ammo -= 1
	var i := _barrel
	_barrel = (_barrel + 1) % _muzzles.size()
	var mz: Marker2D = _muzzles[i]
	var from: Vector2 = mz.global_position
	var to: Vector2 = from + (aim_target - from).rotated(randf_range(-SPREAD, SPREAD))
	_blasts[i].fire(randf_range(0.9, 1.15), (to - from).normalized())
	_kick.y += KICK_IMPULSE
	shoot_fired.emit(from, to)
	shell_ejected.emit(_eject.global_position, facing)
	shake_requested.emit(SHAKE_PER_SHOT)
	ammo_changed.emit(ammo, BELT, false)
	if ammo <= 0:
		_start_reload()


func _start_reload() -> void:
	if reloading:
		return
	reloading = true
	_reload_t = RELOAD_TIME
	ammo_changed.emit(ammo, BELT, true)
