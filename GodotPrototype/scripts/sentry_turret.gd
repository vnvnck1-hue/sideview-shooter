class_name SentryTurret
extends Node2D
## 바닥 격납형 센트리건. 원점 = 바닥 설치 지점(해치 중심).
##
## 평소엔 바닥과 같은 높이의 해치(전개 시트 1프레임)로 묻혀 있다가, 플레이어가 옆에서 W/↑ 로 기동하면
## 8프레임 전개 애니(sentry_turret_deploy_direct_v1_sheet, 10fps)로 바닥에서 솟아오른다.
## 전개가 끝나면 마지막 프레임을 **머리(포신 어셈블리 + 급탄 호스)** 와 **받침(요동 실린더 · 기둥 · 해치 꽃잎)** 으로
## 갈라 둔 두 장(Tools/build_sentry_turret_parts.py)으로 바꿔 끼우고, 머리만 요동축(pivot)에서 부앙시킨다.
##   · 머리는 받침 **뒤**에 그린다 — 분리하며 생긴 단면이 요동 실린더·기둥에 가린다.
##   · 좌우 조준은 측면→3/4→정면 헤드를 거쳐 전체(_flip)를 x 반전한다.
##   · 하향 조준 때 별도 신축 받침대가 머리 축을 들어 포신과 해치의 충돌을 피한다.
##
## 조종: Main 이 aim_target(마우스 월드 좌표)을 넣어 주고, 좌클릭을 누르는 동안 두 포신이 번갈아 발사된다.
## 탄약이 아니라 **총열 과열**이 자원이다 — 쏘면 열이 오르고, 1.0 에 닿으면 잠기며 HEAT_RESET 까지 식어야 다시 쏜다.
## 열이 오를수록 포신이 붉게 달아오르고(BarrelGlow) 총구에서 연기가 샌다.
## 사격 연출은 MuzzleBlast(화염·연기·불꽃·라이트) + 두 배 크기 탄피 + 카메라 흔들림. 탄 자체는 Main 이 플레이어 사격과
## 같은 경로로 쏘되 궤적은 TRACER_SCALE(2배) 로 굵게, 탄착·파편·몬스터 넉백은 SHOT_POWER(1.7배) 로 얹는다.
## 조종을 놓으면 천천히 좌우를 훑다가 IDLE_RETRACT 초 뒤 해치 안으로 다시 접힌다.

signal shoot_fired(muzzle_pos: Vector2, target_pos: Vector2)
signal shell_ejected(pos: Vector2, dir: int)
signal heat_changed(heat: float, overheated: bool)
signal shake_requested(amount: float)
signal control_changed(active: bool)

const DIR := "res://assets/props/defense/sentry/"
const META := DIR + "sentry_turret.json"
const DEPLOY_FMT := DIR + "deploy/sentry_deploy_%02d.png"

## 크기·접지 (2026-09-19 확정): 원본 자산은 플레이어(320px)보다 큰 468px 라 거치 화기로는 과했다.
## SCALE 로 전체를 줄이고(아트 1px = 월드 4×SCALE px), FLOOR_SINK 만큼 바닥선 아래로 내려 받침이 바닥에 파묻히게 한다.
const SCALE := 0.78                 # 전체 크기 78% (60% 에서 30% 키움 — 약 365px, 플레이어 320px 보다 살짝 크다)
const FLOOR_SINK := 16.0            # 접지 기준점을 바닥선보다 이만큼 아래로 (월드 px) — 꽃잎이 바닥에 딱 붙는다
const INTERACT_RANGE := 250.0       # 이 거리 안에서 W/↑ 로 기동·조종 (크기에 맞춰 조정)
## 부앙 한계: 위쪽은 경계 자세 그림으로 +75°, 아래쪽은 별도 신축 받침대가
## 머리 축을 들어 -65°까지 포신과 기존 받침이 겹치지 않게 한다.
const ELEV_UP := 1.31               # 위로 (rad, ≈75°)
const ELEV_DOWN := 1.13446          # 아래로 (rad, ≈65°) — 여유 받침대가 머리를 들어 올린다
const ELEV_MAX := ELEV_UP           # 조준점 레티클 등 외부 참조용 (가장 큰 가용 각)
const LIFT_BEGIN := 0.34907         # 하향 20°부터 여유 받침대 상승
const LIFT_END := ELEV_DOWN
const LIFT_HEIGHT := 176.0          # 원본 아트 px, -65°에서 총구·받침 겹침이 사라지는 높이
## 선회 (2026-09-19 확정): 마우스는 즉시 움직이지만 **기계식 포탑은 천천히 따라온다**.
## 지수 보간(예전 AIM_SMOOTH 16) 대신 **일정 각속도**로 돌려 서보처럼 보이게 한다 —
## 조준점이 앞서 가고 조준선(= 실제 조준 방향)이 뒤따라오는 시차가 생긴다.
const TURN_SPEED := 0.75            # 부앙 각속도 (rad/s — ±26° 전 구간을 훑는 데 약 1.2초)
const FLIP_DELAY := 0.30            # 측면→정면 회전에 쓰는 시간. 반대편 정착에 같은 시간 사용
## 머리는 30°·60°·정면 그림으로 돌아선 뒤 반대쪽 그림을 거울로 되짚는다.
## 포탑 바로 위(중심 ±이 폭) 에서는 방향을 바꾸지 않는다 — 카메라가 포인터를 따라 흔들릴 때
## 마운트가 좌우로 덜덜 떨며 뒤집히는 것을 막는 히스테리시스.
const FLIP_DEADZONE := 90.0
## 타격 위력 — 기준(플레이어 소총) 1.0 대비 증가분. 2.0(= +100%) 이 과했어서 증가분을 30% 줄여 1.7(= +70%) 로 확정.
## 궤적·탄두 두께는 여기서 분리해 TRACER_SCALE 로 2배를 유지한다 (탄은 굵게, 파편·넉백만 완화).
const SHOT_POWER := 1.7             # 탄착 플래시·파편·몬스터 넉백·체액·육편 (Crawler/HitProp/Bullet 탄착)
const TRACER_SCALE := 2.0           # 궤적·심·탄두 두께 (Bullet.width_scale)
const SHELL_SCALE := 1.4            # 탄피 크기 배율 (2.0 에서 30% 축소)
## 총구 화염 크기. 노드가 SCALE 배로 줄어드니 월드 기준을 맞추려 1/SCALE 을 곱하고,
## 0.8 = 노드 축소 보정(월드에서 예전의 80%), 뒤의 0.8 = 발사 효과 20% 감소분.
const BLAST_SIZE := 1.45 * 0.8 * 0.8
const BLAST_SPARKS := 7             # 화약 알갱이 (9 에서 20% 감소)
const BLAST_ENERGY := 0.8           # 총구 라이트 세기 배율 (20% 감소)
## 조준선 — **머리 위 광학 카메라**에서 나와 실제 탄착점(조준점)까지. 조종 중엔 밝게, 무인 대기 중엔
## 희미하게 포신 축을 훑는다. 예전엔 총구에서 포신 축으로 쐈는데, 탄은 조준점으로 날아가므로 선과
## 탄착이 어긋나 보였다 (부앙 한계·회전 지연이 있을 때 특히).
const LASER_WIDTH := 2.0            # 심 두께 (월드 px — 노드 스케일 보정은 아래에서). 3.0 에서 얇게
const LASER_RANGE := 6000.0
const LASER_IDLE := 0.45            # 무인 대기 중 세기
const FIRE_COOLDOWN := 0.055        # 초 (≈18발/초, 포신 2개가 번갈아 — 플레이어 소총의 두 배)
## 과열 — 탄창 대신 총열 열. 0 → 1 까지 약 95발(≈5.2초 연사), 잠기면 HEAT_RESET 까지 토해내고 풀린다.
## (2026-09-19: 과열까지 2.6초는 너무 짧아 한 발당 열을 절반으로 낮춰 연사 시간을 두 배로 늘렸다)
const HEAT_PER_SHOT := 0.0105
const HEAT_COOL := 0.30             # 사격을 멈췄을 때 초당 냉각
const HEAT_COOL_VENT := 0.44        # 과열 잠금 중 냉각 (연기를 뿜으며 더 빨리)
const HEAT_RESET := 0.32            # 잠금이 풀리는 열
const HEAT_SMOKE := 0.28            # 이 열부터 총구에서 연기가 샌다
const MAX_SHOTS_PER_FRAME := 3      # 프레임이 길어졌을 때 몰아 쏘는 상한
const SPREAD := 0.016
const SHAKE_PER_SHOT := 3.4         # 한 발당 (연사가 두 배라 발당은 낮추고 총량은 더 크다)
const KICK_IMPULSE := 150.0         # 포신 후퇴 임펄스
const KICK_SPRING := Vector3(1500.0, 78.0, 0.0)
const KICK_PX := 16.0               # 포신이 뒤로 밀리는 최대 px
const IDLE_SCAN := 0.55             # 무인 상태에서 좌우를 훑는 속도
const IDLE_RETRACT := 14.0          # 조종을 놓고 이 시간이 지나면 격납
const OPTIC_LOCAL := Vector2(22, -146)   # 요동축 기준 광학 조준경 위치
const LASER_LOCAL := Vector2(40, -140)   # 요동축 기준 조준선 출구 (광학 카메라 앞면)

enum State { STOWED, RISING, READY, RETRACTING }

var turret_id := ""                 # 맵에서 유일한 id (RoomData props 의 "id"). 보안 단말기가 이걸로 지목한다
var state: State = State.STOWED
var controlled := false
var aim_target := Vector2.ZERO
var facing := 1
var heat := 0.0                     # 총열 과열 0..1
var overheated := false             # true 면 HEAT_RESET 까지 식을 때까지 잠긴다
var floor_y := 0.0

var _meta := {}
var _pivot := Vector2(-30, -226)
var _flip: Node2D
var _deploy: AnimatedSprite2D
var _head_pivot: Node2D
var _recoil: Node2D                 # 포신 후퇴 (머리 안에서 x 로만 밀린다)
var _head: Sprite2D
var _riser: Sprite2D                 # 하향 조준 시 올라오는 별도 신축 받침대
var _base: Sprite2D
var _muzzles: Array = []            # Marker2D ×2 (위·아래 포신)
var _blasts: Array = []             # MuzzleBlast ×2
var _eject: Marker2D
var _optic: PointLight2D
var _glow: BarrelGlow               # 달아오른 총열
var _hose: SentryHose               # 급탄 호스 (물리 체인)
var _hose_head := Vector2(-45, -47) # 머리 물림쇠 (요동축 기준)
var _hose_base := Vector2(-77, -196)# 받침 스터브 (설치 지점 기준)
var _laser: LaserSight              # 붉은 조준선
var _barrel_smoke: Array = []       # 총구에서 새는 연기 (포신마다 하나)
var _smoke_t := 0.0
var _dust: CPUParticles2D
var _fx_parent: Node2D              # 불꽃·탄피를 담을 월드 층 (Room)

var _angle := 0.0
var _kick := Vector2.ZERO           # (값, 속도) 2차 스프링 — 값 1.0 = 한 발 후퇴
var _fire_cd := 0.0
var _barrel := 0
var _idle_t := 0.0
var _scan_t := 0.0
var _flip_t := 0.0                  # 포인터가 반대쪽에 머문 시간 (좌우 반전 지연)
var _turn_recover_t := 0.0          # 정면을 지난 뒤 반대쪽 측면으로 돌아가는 시간
var _lift_height := 0.0
var _head_art := "sentry_head.png"


## center_x = 바닥 설치 지점, floor_line = 바닥선, fx = 불꽃·연기를 담을 월드 층
func setup(center_x: float, floor_line: float, fx: Node2D) -> void:
	name = "SentryTurret"
	# 접지 기준점은 바닥선보다 FLOOR_SINK 아래 — 해치·받침 꽃잎이 바닥 타일에 살짝 파묻혀 떠 보이지 않는다
	position = Vector2(center_x, floor_line + FLOOR_SINK)
	scale = Vector2(SCALE, SCALE)
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
	_deploy.material = _surface_material()
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
	_head.material = _surface_material()
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
		blast.spark_count = BLAST_SPARKS
		blast.energy_scale = BLAST_ENERGY
		blast.setup(BLAST_SIZE / SCALE, floor_y)
		_blasts.append(blast)

	# 달아오른 총열 (머리 스프라이트 위에 가산으로 덧그린다)
	_glow = BarrelGlow.new()
	_glow.name = "BarrelGlow"
	_recoil.add_child(_glow)
	var specs: Array = []
	for mk in _muzzles:
		specs.append({"back": Vector2(92.0, mk.position.y), "tip": mk.position, "w": 26.0})
	_glow.setup(specs)

	# 총구에서 새는 연기 (열이 HEAT_SMOKE 를 넘으면 번갈아 한 뭉치씩)
	for mk in _muzzles:
		var sm := _build_barrel_smoke()
		sm.position = mk.position
		_recoil.add_child(sm)
		_barrel_smoke.append(sm)

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

	# 머리 뒤에 들어가고 기존 받침 앞에 나타나는 신축 기둥.
	# 완전히 접히면 기존 받침 이미지 속으로 숨는다.
	_riser = Sprite2D.new()
	_riser.name = "AuxRiser"
	_riser.centered = false
	_riser.texture = Lighting.textured(DIR + "sentry_aux_riser_extended.png")
	_riser.offset = Vector2(-320, -320)
	_riser.position = _pivot + Vector2(0.0, LIFT_HEIGHT)
	_riser.material = _surface_material()
	_riser.visible = false
	_flip.add_child(_riser)

	# 받침 (머리 앞에 그려 분리 단면을 가린다)
	_base = Sprite2D.new()
	_base.name = "Base"
	_base.centered = false
	_base.texture = Lighting.textured(DIR + "sentry_base.png")
	_base.offset = _vec(_meta.get("base_offset", [-189, -244]))
	_base.material = _surface_material()
	_base.visible = false
	_flip.add_child(_base)

	# 붉은 조준선 (_flip 밖 = 좌우 반전·회전과 무관. 월드 좌표를 to_local 로 넣는다)
	_laser = LaserSight.new()
	_laser.name = "LaserSight"
	_laser.width = LASER_WIDTH / SCALE
	_laser.visible = false
	# 빛줄기는 프랍 층(z2~3)에 묻히면 안 된다 — 절대 z 7 로 올려 인물(5)·탄·몬스터 체액(6) 위에 그린다.
	# 근경 실루엣(z7)·벽 바깥 어둠(z8)은 나중에 붙는 층이라 여전히 조준선을 가린다 (원근은 유지).
	_laser.z_as_relative = false
	_laser.z_index = DepthPreset.Z_FOREGROUND
	add_child(_laser)

	# 급탄 호스 — 받침보다 앞(원본 그림처럼 기둥 왼쪽을 지나간다). 좌우 반전은 _flip 이 처리한다.
	_hose = SentryHose.new()
	_hose.name = "Hose"
	_hose.visible = false
	_flip.add_child(_hose)

	_dust = _build_dust()
	add_child(_dust)


## 프랍 표면 머티리얼. 노드가 SCALE 배로 줄어들면 림(텍스처 px 기준)도 그만큼 얇아지므로
## 폭을 1/SCALE 로 키워 다른 프랍과 화면상 림 두께를 맞춘다.
func _surface_material() -> ShaderMaterial:
	var m := Lighting.shader_material("prop_surface")
	m.set_shader_parameter("rim_width_px", float(Lighting.rim_preset()["width"]) / SCALE)
	return m


func _load_meta() -> void:
	var f := FileAccess.open(META, FileAccess.READ)
	if f == null:
		push_warning("sentry_turret.json 을 읽을 수 없음 — 기본 앵커 사용")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_meta = parsed
		_pivot = _vec(_meta.get("pivot", [-30, -226]))
	_hose_head = _vec(_meta.get("hose_head", [-45, -47]))
	_hose_base = _vec(_meta.get("hose_base", [-77, -196]))


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
	p.emission_rect_extents = Vector2(180, 6)          # 로컬 — SCALE 이 곱해져 월드 ±108px
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


## 달아오른 총구에서 천천히 피어오르는 연기 (한 번에 한 뭉치씩 restart)
func _build_barrel_smoke() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "BarrelSmoke"
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 4
	p.lifetime = 2.0
	p.local_coords = false
	p.texture = Lighting.smoke_canvas_texture()
	p.direction = Vector2(0.25, -1.0)
	p.spread = 22.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, -55.0)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1.0, 1.8))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(0.76, 0.74, 0.72, 0.5))
	grad.set_color(1, Color(0.40, 0.41, 0.46, 0.0))
	p.color_ramp = grad
	return p


# ── 상태 전환 ────────────────────────────────────────────────────────────────

## 플레이어가 이 센트리건을 기동할 수 있나 (거리 · 상태)
func can_interact(px: float) -> bool:
	return absf(px - position.x) <= INTERACT_RANGE and state != State.RISING


func prompt_text() -> String:
	if controlled:
		return "▼  S / Ctrl / ↓  —  센트리건에서 손 떼기"
	if state == State.READY:
		return "▲  W / ↑  —  센트리건 조종"
	return "▲  W / ↑  —  센트리건 전개"


## W/↑ 한 번: 접혀 있으면 전개(끝나면 자동으로 조종), 서 있으면 조종을 **잡는다**.
## 놓는 것은 S/Ctrl/↓ (Main 이 crouch 입력으로 처리) — 잡기·놓기가 같은 키면 한 번 누를 때
## 전개 직후 바로 놓아지는 등 오작동이 잦아 2026-09-19 에 분리했다.
func activate() -> void:
	match state:
		State.STOWED, State.RETRACTING:
			_start_deploy()
		State.READY:
			set_controlled(true)
		_:
			pass


func set_controlled(active: bool) -> void:
	if controlled == active:
		return
	controlled = active
	_idle_t = 0.0
	control_changed.emit(active)
	if active:
		heat_changed.emit(heat, overheated)


func _start_deploy() -> void:
	var resume := state == State.RETRACTING     # 접히던 중이면 그 프레임부터 도로 올라온다
	state = State.RISING
	_deploy.visible = true
	_base.visible = false
	_riser.visible = false
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
	_riser.visible = false
	heat = 0.0
	overheated = false
	_angle = 0.0
	_lift_height = 0.0
	_flip_t = 0.0
	_turn_recover_t = 0.0
	_head_pivot.position = _pivot
	_head_pivot.rotation = 0.0
	_riser.position = _pivot + Vector2(0.0, LIFT_HEIGHT)
	shake_requested.emit(3.5)                # 마지막으로 '쿵' 하고 자리를 잡는다
	set_controlled(true)                      # 기동시킨 사람이 그대로 잡는다
	_update_head(0.0, true)                   # 조종을 잡은 뒤 스냅 — 전개 직후 조준점 쪽을 보고 시작한다
	_hose.visible = true
	_hose.reset(_hose.to_local(_recoil.to_global(_hose_head)),
		_hose_base + Vector2(0.0, -_lift_height))


func _start_retract() -> void:
	state = State.RETRACTING
	set_controlled(false)
	_deploy.visible = true
	_base.visible = false
	_riser.visible = false
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
		if heat > 0.0:
			_tick_heat(delta, false)        # 접힌 뒤에도 총열은 식는다 (연기는 READY 에서만)
		_laser.visible = false
		_hose.visible = false               # 전개 애니 프레임에는 호스가 그려져 있다
		return
	_update_head(delta)

	# 쿨다운은 남은 시간을 그대로 이어받는다(0 에서 자르지 않는다) — 프레임 길이에 발사 간격이 끌려가지 않게.
	# 한 프레임에 여러 발이 밀리면 몰아서 쏜다 (초당 1/FIRE_COOLDOWN 발을 정확히 유지).
	_fire_cd = maxf(_fire_cd - delta, -FIRE_COOLDOWN)
	var firing := controlled and Input.is_action_pressed("shoot") and not overheated and not _is_turning()
	_tick_heat(delta, firing)

	if controlled:
		_idle_t = 0.0
		if Input.is_action_pressed("shoot") and not _is_turning():
			var shots := 0
			while _fire_cd < 0.0 and not overheated and shots < MAX_SHOTS_PER_FRAME:
				_try_fire()
				shots += 1
	else:
		# 무인 대기: 천천히 좌우를 훑다가 격납
		_scan_t += delta
		_idle_t += delta
		if _idle_t >= IDLE_RETRACT:
			_start_retract()
			return
	_update_laser()
	_hose.visible = true
	_hose.update_chain(_hose.to_local(_recoil.to_global(_hose_head)),
		_hose_base + Vector2(0.0, -_lift_height), delta)


## 총열 열: 쏘지 않는 동안 식고, 잠긴 동안엔 연기를 뿜으며 더 빨리 식는다.
## 열에 맞춰 포신 발광과 총구 연기도 여기서 갱신한다.
func _tick_heat(delta: float, firing: bool) -> void:
	var before := heat
	if overheated:
		heat = maxf(heat - HEAT_COOL_VENT * delta, 0.0)
		if heat <= HEAT_RESET:
			overheated = false
			heat_changed.emit(heat, overheated)
	elif not firing:
		heat = maxf(heat - HEAT_COOL * delta, 0.0)
	# 조금이라도 바뀌면 바로 알린다 — 예전엔 0.004 이상만 알려서 프레임이 짧은(고주사율) 환경에서
	# 한 프레임 냉각량이 임계값에 못 미쳐 게이지가 멈춘 것처럼 보였다.
	if heat != before:
		heat_changed.emit(heat, overheated)
	_glow.heat = heat

	# 달아오른 총구에서 연기가 샌다 — 뜨거울수록 자주, 과열 잠금 중엔 계속
	if state != State.READY or heat < HEAT_SMOKE or _barrel_smoke.is_empty():
		return
	_smoke_t -= delta
	if _smoke_t > 0.0:
		return
	var k := clampf((heat - HEAT_SMOKE) / (1.0 - HEAT_SMOKE), 0.0, 1.0)
	_smoke_t = lerpf(0.42, 0.10, k)
	var sm: CPUParticles2D = _barrel_smoke[_barrel % _barrel_smoke.size()]
	sm.restart()


## 지금 포신이 실제로 겨누는 지점 — **탄과 조준선이 공유**한다.
## 포탑이 천천히 도는 동안 조준점(마우스)은 앞서 가고, 탄과 조준선은 이 점으로 함께 간다.
## 거리는 조준점까지의 거리를 쓰고(가까이 겨누면 가까이 맞는다), 벽은 Room.clip_shot 으로 자른다.
func _impact_point() -> Vector2:
	var tip: Vector2 = (_muzzles[0].global_position + _muzzles[-1].global_position) * 0.5
	var dist := LASER_RANGE
	if controlled:
		dist = maxf(tip.distance_to(aim_target), 400.0)
	var far := tip + _barrel_dir() * dist
	if _fx_parent != null and _fx_parent.has_method("clip_shot"):
		far = _fx_parent.clip_shot(tip, far)
	return far


## 조준선: **머리 위 광학 카메라**에서 나와 _impact_point() 까지. 즉 조준점이 아니라 **지금 겨누는 곳**을
## 가리키므로, 포탑이 마우스를 따라 도는 시차가 조준선으로 그대로 보인다 (탄착점과는 항상 일치).
func _update_laser() -> void:
	if _is_turning():
		_laser.visible = false
		return
	var origin: Vector2 = _recoil.to_global(LASER_LOCAL)
	_laser.visible = true
	_laser.from = to_local(origin)
	_laser.to = to_local(_impact_point())
	if overheated:
		# 잠긴 동안엔 깜빡인다 (_scan_t 는 무인일 때만 도니 실시간 시계를 쓴다)
		var ph := float(Time.get_ticks_msec()) * 0.001
		_laser.intensity = 0.35 + 0.35 * absf(sin(ph * 9.0))
	else:
		_laser.intensity = 1.0 if controlled else LASER_IDLE


## 포신이 실제로 가리키는 월드 방향 (좌우 반전·부앙·후퇴가 모두 반영된다)
func _barrel_dir() -> Vector2:
	var mk: Marker2D = _muzzles[0]
	var back := _recoil.to_global(Vector2(92.0, mk.position.y))
	var d := mk.global_position - back
	return d.normalized() if d.length_squared() > 0.01 else Vector2(float(facing), 0.0)


func _optic_target() -> float:
	if state != State.READY:
		return 0.0
	return 1.5 if controlled else 0.45


static func _spring(s: Vector2, p: Vector3, delta: float) -> Vector2:
	s.y += -s.x * p.x * delta
	s.y *= exp(-p.y * delta)
	s.x += s.y * delta
	return s


## 포신 방향. 조종 중이면 마우스 쪽으로, 무인이면 천천히 훑는 각도로 **일정 각속도**로 돌아간다.
## 좌우 반전은 30°·60°·정면 자세를 지나 중앙에서 일어난다.
func _update_head(delta: float, snap := false) -> void:
	var want := 0.0
	if controlled:
		# 각도는 **총구 기준**으로 잡는다 — 요동축 기준으로 잡으면 총구가 축보다 앞에 있어(≈170px)
		# 다 돌아선 뒤에도 탄착이 조준점에서 수십 px 비껴간다. 총구가 돌면서 같이 움직이므로
		# 프레임마다 다시 계산되는 고정점 반복이 되고, 몇 프레임 안에 정확히 조준점을 지나간다.
		# 아주 가까운 표적(350px 미만)에서는 이 반복이 흔들릴 수 있어 요동축 기준으로 되돌린다.
		var muzzle_mid: Vector2 = (_muzzles[0].global_position + _muzzles[-1].global_position) * 0.5
		var ref := muzzle_mid if muzzle_mid.distance_to(aim_target) > 350.0 else _head_pivot.global_position
		var to := aim_target - ref
		var want_face := facing
		if absf(to.x) > FLIP_DEADZONE:
			want_face = 1 if to.x >= 0.0 else -1
		if want_face == facing:
			_flip_t = maxf(0.0, _flip_t - delta)
			_turn_recover_t = maxf(0.0, _turn_recover_t - delta)
		else:
			if _turn_recover_t > 0.0:
				_flip_t = _turn_recover_t
				_turn_recover_t = 0.0
			_flip_t += delta
			if _flip_t >= FLIP_DELAY or snap:
				facing = want_face
				_flip_t = 0.0
				_turn_recover_t = 0.0 if snap else FLIP_DELAY
		# 좌우 전환 도중에도 고도는 목표의 수직 기울기만 따른다.
		# 방향별 각도를 쓰면 아직 반전되기 전 왼쪽 목표가 PI 근처로 계산되어
		# 머리가 아래로 꺾이고 받침대가 불필요하게 솟는다.
		want = atan2(to.y, absf(to.x))
	else:
		want = -0.10 + sin(_scan_t * IDLE_SCAN) * 0.22      # 무인 대기: 수평 근처를 얕게 훑는다
		_flip_t = maxf(0.0, _flip_t - delta)
		_turn_recover_t = maxf(0.0, _turn_recover_t - delta)

	_flip.scale.x = float(facing)

	want = clampf(want, -ELEV_UP, ELEV_DOWN)      # 화면 y 는 아래가 +, 즉 음수가 "위로"
	if snap or delta <= 0.0:
		_angle = want
	else:
		_angle = move_toward(_angle, want, TURN_SPEED * delta)
	_head_pivot.rotation = _angle
	# 아래로 기울수록 별도 신축 받침대와 머리 축이 함께 올라간다.
	var t := clampf((_angle - LIFT_BEGIN) / (LIFT_END - LIFT_BEGIN), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	_lift_height = LIFT_HEIGHT * t
	_head_pivot.position = _pivot + Vector2(0.0, -_lift_height)
	_riser.position = _pivot + Vector2(0.0, LIFT_HEIGHT - _lift_height)
	_riser.visible = state == State.READY and _lift_height > 1.0
	_update_head_art()


func _is_turning() -> bool:
	return _flip_t > 0.005 or _turn_recover_t > 0.005


## 0° 측면 → 30° → 60° → 정면 → (거울) 60° → 30° → 측면.
## 그림의 총열 길이가 실제로 짧아져 보이므로 좌우 반전 순간의 납작한 뒤집힘이 없다.
func _update_head_art() -> void:
	var yaw := maxf(_flip_t, _turn_recover_t) / FLIP_DELAY
	var file := "sentry_head.png"
	var baked_angle := 0.0
	if yaw >= 0.80:
		file = "sentry_head_yaw_90.png"
	elif yaw >= 0.47:
		file = "sentry_head_yaw_60.png"
	elif yaw >= 0.12:
		file = "sentry_head_yaw_30.png"
	elif _angle <= -0.61087: # +35° 위로
		file = "sentry_head_elev_p60.png"
		baked_angle = -1.04720
	elif _angle >= 0.26180: # -15° 아래로
		file = "sentry_head_elev_m40.png"
		baked_angle = 0.69813
	if file != _head_art:
		_head_art = file
		_head.texture = Lighting.textured(DIR + file)
		_head.offset = _vec(_meta.get("head_offset", [-89, -197])) if file == "sentry_head.png" else Vector2(-320, -320)
	_head.rotation = -baked_angle
	_glow.visible = not _is_turning()


func _try_fire() -> void:
	if overheated or _fire_cd >= 0.0 or _is_turning():
		return
	_fire_cd += FIRE_COOLDOWN
	heat = minf(heat + HEAT_PER_SHOT, 1.0)
	if heat >= 1.0:
		_overheat()
	var i := _barrel
	_barrel = (_barrel + 1) % _muzzles.size()
	var mz: Marker2D = _muzzles[i]
	var from: Vector2 = mz.global_position
	# 탄은 조준점이 아니라 **포신이 겨누는 곳**으로 나간다 — 조준선·탄착이 어긋나지 않는다
	var to: Vector2 = from + (_impact_point() - from).rotated(randf_range(-SPREAD, SPREAD))
	_blasts[i].fire(randf_range(0.9, 1.15), (to - from).normalized())
	_kick.y += KICK_IMPULSE
	_hose.kick(Vector2(float(facing) * 0.9, -0.5))      # 반동에 호스가 출렁인다
	shoot_fired.emit(from, to)
	shell_ejected.emit(_eject.global_position, facing)
	shake_requested.emit(SHAKE_PER_SHOT)
	heat_changed.emit(heat, overheated)


## 과열 잠금: 양쪽 총구에서 증기가 한꺼번에 터져 나오고 화면이 한 번 울린다
func _overheat() -> void:
	overheated = true
	_fire_cd = maxf(_fire_cd, 0.25)
	for sm in _barrel_smoke:
		sm.restart()
	if _fx_parent != null:
		var sb := SparkBurst.spawn(_fx_parent, floor_y)
		for mk in _muzzles:
			sb.burst(mk.global_position, 7, Vector2(0, -1), 0.9, Vector2(90, 280),
				Color(1.0, 0.86, 0.66), Color(1.0, 0.32, 0.10), Vector2(0.2, 0.55), 1500.0, 3.0, false)
	shake_requested.emit(4.0)
	heat_changed.emit(heat, overheated)
