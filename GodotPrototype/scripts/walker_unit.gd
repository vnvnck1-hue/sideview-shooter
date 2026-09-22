class_name WalkerUnit
extends Node2D
## 본편에 놓이는 **사족보행 기체 한 대** (2026-09-22). 센트리건(sentry_turret.gd)과 같은 규칙으로 산다:
## 평소엔 꺼진 채 웅크리고 있고, 플레이어가 다가가 켜서 직접 몰거나 보안 단말기로 원격 접속해 몬다.
##
## 걸음·자세는 전부 ProcWalker 가 푼다 (랩에서 맞춘 그대로). 이 스크립트가 하는 일은 셋뿐이다.
##   1) 방 안에 **알맞은 크기로** 앉힌다 (SCALE)
##   2) 꺼짐 ↔ 켜짐 (웅크렸다가 일어선다)
##   3) 조종 입력·사격을 본편 배선(Main)에 맞춰 중계한다
##
## ## 왜 센트리건을 그대로 베끼는가
## 프롬프트·조종 전환·원격 접속이 전부 Main 한 곳에서 갈린다. 같은 창구(can_interact / prompt_text /
## activate / set_controlled / controlled / aim_target + 같은 시그널)를 내면 Main 이 둘을 같은 코드로
## 다룰 수 있다. 다르게 만들면 조종 상태가 두 벌이 되어 "플레이어 입력이 영영 안 돌아오는" 버그가 난다.
##
## ## 센트리건과 **다른** 점
## 포탑은 바닥에 박혀 있고 이 기체는 **걸어다닌다**. 그래서
##   · 위치가 매 프레임 바뀐다 → position 을 기체를 따라 움직인다 (프롬프트 거리·카메라가 이걸 본다)
##   · 방 밖으로 나가면 안 된다 → 방 좌우 끝에서 걸음을 막는다 (_clamp_span)
##   · 전개 애니메이션 시트가 없다 → **웅크렸다 일어서는 것도 절차적 보행이 푼다**
##     (ride 를 낮췄다 올리면 다리가 알아서 접혔다 펴진다. 시트를 굽지 않아도 되는 게 이 리그의 값어치다)

## 리그 로컬 → 월드 배율.
##
## ProcWalker 는 자기 단위로 키 342(= ride 182 + 몸통 위 160)짜리 기체다. 플레이어 스프라이트를
## 재 보면 캐릭터가 **160 × 267 월드px**(320 프레임 안에서)이고, 컨셉 목업에서 이 기체는 플레이어
## 키의 약 2/3 로 서 있다. 342 × 0.5 = 171 ≈ 267 × 0.64 — 목업 비율이 그대로 나온다.
##
## 조각은 **랩에서 쓰는 것 그대로**다 (cut_quadruped_rig_parts.py SCALE 0.34). 게임 눈금(4×4 블록)에
## 맞춰 굽지 않는다 — 한때 8배 거칠게 잘라 봤는데 원화가 40px 로 뭉개져 랩에서 맞춰 둔 그림과
## 다른 물건이 됐다. 크기는 **노드 배율로만** 줄인다.
const SCALE := 0.5

const INTERACT_RANGE := 250.0     # 센트리건과 같다 — 둘이 다르면 어느 쪽이 잡힐지 플레이어가 못 읽는다
const SLEEP_AFTER := 14.0         # 무인으로 이만큼 지나면 다시 웅크린다 (SentryTurret.IDLE_RETRACT 와 같은 값)
const WAKE_TIME := 0.85           # 일어서는 데 걸리는 시간
const SLEEP_TIME := 1.20          # 앉는 데 걸리는 시간 — 일어설 때보다 느긋하게 (힘이 빠지는 느낌)

## 꺼졌을 때의 몸 높이. 다리가 접혀 배가 바닥에 거의 닿는다.
## ProcWalker.THIGH_MIN(34) + SHIN_LEN(50) 보다는 높아야 다리가 한계에 걸려 떨지 않는다.
const SLEEP_RIDE := 96.0

## 꺼졌을 때의 색. 전원이 없어 발광부가 죽고 전체가 어둡게 가라앉는다
const SLEEP_TINT := Color(0.46, 0.50, 0.62)

## ── 사격 — **센트리건과 같게 한다** ──────────────────────────────────────────
## 처음엔 여기서 따로 굴렸다가 두 가지가 어긋났다.
##   · 탄이 조준점이 아니라 포신 방향으로 4000px 날아갔다 → 마우스가 탄착점이 되지 않았다
##   · 총구 화염이 아예 없고 대신 탄착·궤적만 크게 잡아 놔서 효과가 엉뚱하게 커 보였다
## 그래서 sentry_turret.gd 의 사격을 그대로 가져왔다 — 탄착점 계산(_impact_point) · 산포(SPREAD) ·
## 총구 화염(MuzzleBlast) · 위력/궤적/탄피 배율 · 발당 흔들림까지 같은 값이다.
##
## **연사력만 다르다.** 이 기체는 포신이 하나에 구경이 굵다 (ProcWalker.FIRE_COOLDOWN 0.08 ≈ 초당 12발.
## 센트리건은 0.055 ≈ 18발). 그래서 발당 열만 그 비율로 올려 **과열까지 걸리는 시간**을 맞춘다 —
## 센트리건과 같은 값을 쓰면 이 기체는 영영 과열되지 않는다.
## 센트리건의 절반. 탄착 플래시·파편·몬스터 넉백·체액이 그만큼 작아진다.
## (한 발이 깎는 체력은 power 와 무관하게 1 이다 — 처치에 필요한 발 수는 그대로다.)
const SHOT_POWER := SentryTurret.SHOT_POWER * 0.5  # 탄착 플래시·파편·넉백
const TRACER_SCALE := SentryTurret.TRACER_SCALE   # 궤적·탄두 두께
const SHELL_SCALE := SentryTurret.SHELL_SCALE     # 탄피 크기
## ── 집탄 ────────────────────────────────────────────────────────────────────
## 첫 발은 센트리건과 같은 산포(SPREAD)로 정확하고, **붙잡고 쏠수록 벌어진다.**
## 플레이어 소총(Player.SPREAD_BASE / SPREAD_HEAT)과 같은 규칙이다 — 긴 연사에 값을 치르게 해서
## 끊어 쏘기를 유도한다. 열(heat)과는 **다른 눈금**이다: 집탄은 1.3초면 한계에 닿았다가 1초면
## 회복하고, 과열은 5초를 쏴야 잠기고 한참을 식힌다. 같은 값으로 묶으면 둘 중 하나가 무의미해진다.
const SPREAD := SentryTurret.SPREAD               # 첫 발 산포 (rad)
const SPREAD_HEAT := 0.060                        # 집탄 열 1.0 에서 **더해지는** 산포 (rad)
const SPREAD_PER_SHOT := 0.13                     # 한 발이 올리는 집탄 열 (연사 12발/초 → 초당 1.6)
const SPREAD_DECAY := 0.85                        # 초당 회복 (쏘는 중에도 빠진다 — 순증은 초당 0.78)
const SHAKE_PER_SHOT := SentryTurret.SHAKE_PER_SHOT
const LASER_RANGE := SentryTurret.LASER_RANGE     # 무인일 때 탄착점을 잡는 기준 거리
const MIN_SHOT_RANGE := 40.0                      # 조종 중 탄착점의 최소 거리 (총구 기준)
const HEAT_COOL := SentryTurret.HEAT_COOL
const HEAT_RESET := SentryTurret.HEAT_RESET
const HEAT_SMOKE := SentryTurret.HEAT_SMOKE       # 이 열부터 총구에서 연기가 샌다
## 발당 열 = 센트리건 값 × 연사 간격 비 (0.08 / 0.055). 과열까지 약 5초로 같아진다
const HEAT_PER_SHOT := SentryTurret.HEAT_PER_SHOT * (ProcWalker.FIRE_COOLDOWN / SentryTurret.FIRE_COOLDOWN)

## 총구 화염 크기. 센트리건 값을 기체 크기 비(SCALE 0.5 ÷ 센트리건 0.78)로 줄인다 —
## 같은 값을 그대로 쓰면 절반 크기 기체에 포탑만 한 화염이 붙어 혼자 커 보인다.
const BLAST_SIZE := SentryTurret.BLAST_SIZE * 0.66
const BLAST_SPARKS := SentryTurret.BLAST_SPARKS
const BLAST_ENERGY := SentryTurret.BLAST_ENERGY

enum State { DORMANT, WAKING, READY, SLEEPING }

signal shoot_fired(muzzle_pos: Vector2, target_pos: Vector2)
signal shell_ejected(pos: Vector2, dir: int)
signal heat_changed(heat: float, overheated: bool)
signal shake_requested(amount: float)
signal control_changed(active: bool)

## 맵에서 유일한 id (room_data.gd 의 props 가 준다). 단말기 원격 접속이 이걸로 찾는다
var walker_id := ""
var state: State = State.DORMANT
var controlled := false
var aim_target := Vector2.ZERO    # 월드 마우스 — Main 이 매 프레임 채운다
var heat := 0.0
var overheated := false
var floor_y := 0.0
## 테스트 장면과 본편 모두 이 파일을 생성 시 읽는다. 테스트는 별도 경로를 주입한다.
var tuning_path := ProcWalker.GaitSettings.DEFAULT_PATH
var tuning_load_error: Error = OK

var _walker: ProcWalker
var _rig: WalkerRig
var _scaler: Node2D               # 리그를 SCALE 배로 얹는 그릇 (아래 _build 주석)
var _room: Node2D                 # 사격 클리핑(clip_shot)을 맡는 방
var _power := 0.0                 # 0 = 완전히 웅크림 · 1 = 다 일어섬
var _idle := 0.0                  # 무인으로 서 있은 시간
var _span := Vector2(-1e9, 1e9)   # 걸어다닐 수 있는 방 안의 좌우 끝 (월드 x)
var _tune: Dictionary = {}        # 저장한 선 자세 설정. 전원 전환 중 ride와 분리해 보존한다.
var _blast: MuzzleBlast           # 총구 화염 — 센트리건과 같은 연출 (한 발마다 총구로 옮겨 터뜨린다)
var _barrel_smoke: CPUParticles2D # 달아오른 총구에서 새는 연기 (센트리건 _barrel_smoke 와 같은 규격)
var _smoke_t := 0.0               # 다음 연기 뭉치까지 남은 시간
var _spread_heat := 0.0           # 집탄 열 0..1 — 쏠수록 오르고 쉬면 빠진다 (spread_ratio)


## 방이 부른다. center_x = 처음 놓이는 자리 · floor_line = 바닥선 · fx = 방(Room)
func setup(center_x: float, floor_line: float, fx: Node2D) -> void:
	floor_y = floor_line
	_room = fx
	position = Vector2(center_x, floor_line)
	_build(center_x, fx)


## 리그는 **크기를 바꾼 그릇 안**에서 산다.
##
## ProcWalker 는 자기 단위(키 342)로 걸음을 풀고 그 단위로 발·고관절을 들고 있다. 그 노드를 직접
## 줄이면 body_pos 는 줄지 않고 그림만 줄어 걸음과 그림이 어긋난다. 그래서 **그릇을 줄이고 그 안에
## 통째로** 넣는다 — 그릇 안에서는 모든 게 예전 그대로이고, 밖에서 보면 0.5 배다.
##
## 그릇의 position 을 이 노드의 position 의 **반대로** 둔다. 그러면 이 노드가 기체를 따라
## 어디로 움직이든 그릇의 원점은 항상 방 원점에 붙어 있어, 워커 좌표 = 방 좌표 ÷ SCALE 로 고정된다.
## (이렇게 해 두지 않으면 position 을 옮길 때마다 기체가 같이 순간이동한다)
func _build(center_x: float, fx: Node2D) -> void:
	_scaler = Node2D.new()
	_scaler.name = "Scale"
	_scaler.scale = Vector2(SCALE, SCALE)
	add_child(_scaler)

	_walker = ProcWalker.new()
	_walker.ground_at = _ground_at
	_walker.draw_greybox = false
	tuning_load_error = _walker.initialize_spider_tuning(tuning_path)
	_tune = _walker.tune.duplicate(true)
	_walker.tune["ride"] = SLEEP_RIDE            # 꺼진 채로 태어난다
	_walker.body_pos = Vector2(center_x / SCALE, _ground_at(0.0) - SLEEP_RIDE)
	_scaler.add_child(_walker)

	_rig = WalkerRig.new()
	_rig.walker = _walker
	_walker.add_child(_rig)

	# 총구 화염. 센트리건은 총구가 고정이라 마커 자리에 붙여 두지만, 이 기체는 포신이 돌고
	# 몸도 걸어다녀 총구가 매 프레임 움직인다 — 그래서 **이 노드에 달아 두고 쏠 때마다 옮긴다.**
	# 이 노드는 배율이 1 이므로(줄이는 것은 안쪽 그릇이다) 화염이 월드 크기 그대로 나온다.
	_blast = MuzzleBlast.new()
	_blast.name = "Blast"
	_blast.fx_parent = fx if fx is Node2D else null
	_blast.spark_count = BLAST_SPARKS
	_blast.energy_scale = BLAST_ENERGY
	add_child(_blast)
	_blast.setup(BLAST_SIZE, floor_y)

	# 총구에서 새는 연기. 화염과 같은 이유로 **이 노드**(배율 1)에 달아 월드 크기로 뽑고,
	# 매 프레임 총구로 옮긴다 (_sync_blast). local_coords 를 끄므로 뱉어진 연기는 제자리에 남는다.
	_barrel_smoke = _build_barrel_smoke()
	add_child(_barrel_smoke)

	_walker.fired.connect(_on_fired)
	_walker.reset_stance()          # 꺼진 높이(SLEEP_RIDE)에 맞춰 네 발을 제자리에 내려놓는다
	_sync_node()


## 실행 중 조정할 때도 선 자세 목표를 보존한다. 전원 애니메이션이 저장값을 덮지 않는다.
func apply_spider_tuning(values: Dictionary) -> bool:
	if _walker == null or not _walker.apply_spider_tuning(values):
		return false
	_tune.merge(values, true)
	_walker.tune["ride"] = lerpf(SLEEP_RIDE, float(_tune["ride"]), _power)
	return true


## 지면 질의 — 워커 좌표계다 (방 좌표 ÷ SCALE). 본편의 방은 바닥이 한 줄로 평평하다
## (RoomData.FLOOR_Y). 계단형 방이 생기면 여기서 RoomSolid 의 열별 바닥선을 물려 주면 된다.
func _ground_at(_x: float) -> float:
	return floor_y / SCALE


## 방 안에서 걸어다닐 수 있는 좌우 끝을 잡아 둔다 (벽을 뚫고 나가지 않게).
## 기체 몸통 반폭만큼 안쪽으로 물린다.
func set_span(left: float, right: float) -> void:
	var half := ProcWalker.BODY_HALF_W * SCALE
	_span = Vector2(left + half, right - half)


# ── 센트리건과 같은 창구 ──────────────────────────────────────────────────────

func can_interact(px: float) -> bool:
	return absf(px - position.x) <= INTERACT_RANGE and state != State.WAKING


func prompt_text() -> String:
	if controlled:
		return "▼ S/Ctrl/↓ — 기체에서 내리기"
	if state == State.READY:
		return "▲ W/↑ — 보행 기체 조종"
	return "▲ W/↑ — 보행 기체 기동"


## 켠다. 꺼져 있으면 일으켜 세우고(다 서면 자동으로 조종으로 넘어간다), 이미 서 있으면 바로 잡는다.
func activate() -> void:
	match state:
		State.DORMANT, State.SLEEPING:
			state = State.WAKING
		State.READY:
			set_controlled(true)
		_:
			pass


func set_controlled(active: bool) -> void:
	if controlled == active:
		return
	controlled = active
	_idle = 0.0
	if not active:
		_walker.input_dir = 0.0
		_walker.running = false
		_walker.firing = false
		_walker.aim_target = null
	control_changed.emit(active)


# ── 매 프레임 ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tick_power(delta)
	_tick_input()
	_tick_heat(delta)
	_tick_spread(delta)
	_walker.tick(delta)
	_clamp_span()
	_sync_node()
	_sync_blast()


## 웅크렸다 일어서기. **애니메이션 시트가 없다** — ride(몸 높이)를 옮기면 절차적 보행이
## 다리를 접었다 펴서 그걸 그려 준다. 다 서면 곧바로 조종으로 넘긴다
## (센트리건이 RISING 끝에서 set_controlled(true) 하는 것과 같은 흐름).
func _tick_power(delta: float) -> void:
	match state:
		State.WAKING:
			_power = minf(_power + delta / WAKE_TIME, 1.0)
			if _power >= 1.0:
				state = State.READY
				set_controlled(true)
		State.SLEEPING:
			_power = maxf(_power - delta / SLEEP_TIME, 0.0)
			if _power <= 0.0:
				state = State.DORMANT
		State.READY:
			if not controlled:
				_idle += delta
				if _idle >= SLEEP_AFTER:
					state = State.SLEEPING
		_:
			pass
	_walker.tune["ride"] = lerpf(SLEEP_RIDE, float(_tune["ride"]), _power)
	var lit: float = _power
	_rig.modulate = SLEEP_TINT.lerp(Color.WHITE, lit)


## 조종 입력. 센트리건과 같이 **여기서 직접 읽는다** — Main 은 조준점만 넣어 준다.
## (Main 이 전부 읽으면 기체가 늘어날 때마다 Main 이 커진다. 포탑이 이미 그렇게 하고 있다)
func _tick_input() -> void:
	if not controlled or state != State.READY:
		_walker.input_dir = 0.0
		_walker.running = false
		_walker.firing = false
		_walker.aim_target = null
		return
	_walker.input_dir = Input.get_axis("move_left", "move_right")
	_walker.running = Input.is_action_pressed("run")
	# 조준점(월드)을 그릇 안 좌표로 옮겨 준다 — 배율만 나누면 위쪽 변환을 놓친다
	_walker.aim_target = _scaler.global_transform.affine_inverse() * aim_target
	_walker.firing = Input.is_action_pressed("shoot") and not overheated
	# 뛰어오르기는 본편의 **구르기 키(Space)** 에 붙인다 — 랩의 "jump" 액션은 게임 InputMap 에 없다
	# (붙여 놓고 콘솔에 "action 'jump' doesn't exist" 가 쏟아져서 알았다).
	if Input.is_action_just_pressed("roll"):
		_walker.jump()


## 열 — 센트리건 _tick_heat() 과 같은 규칙이다. 과열 잠금 중에는 더 빨리 토해낸다.
##
## **쏘는 동안에는 식지 않는다.** 예전엔 매 프레임 무조건 냉각(0.30/초)을 깎았는데, 연사로 오르는
## 열은 초당 0.19(발당 0.0153 × 12.5발) 라 **냉각이 언제나 더 커서 게이지가 2% 언저리에 붙어 있었다** —
## 과열이 이론상 불가능했다. 센트리건은 처음부터 `elif not firing` 이었고, 그걸 옮기다 빠뜨린 조건이다.
## 이제 쏘는 동안에는 초당 0.19 씩 올라 약 5.2초에 잠기고, 손을 떼면 0.30/초(잠금 중엔 0.44/초)로 식는다.
func _tick_heat(delta: float) -> void:
	var was := heat
	var was_over := overheated
	if overheated:
		heat = maxf(heat - SentryTurret.HEAT_COOL_VENT * delta, 0.0)
		if heat <= HEAT_RESET:
			overheated = false
	elif not _walker.firing:
		heat = maxf(heat - HEAT_COOL * delta, 0.0)
	# 조금이라도 바뀌면 바로 알린다 — is_equal_approx 로 걸러 두면 고주사율에서 한 프레임 냉각량이
	# 임계에 못 미쳐 게이지가 멈춘 것처럼 보인다 (센트리건이 같은 이유로 == 비교를 쓴다).
	if heat != was or overheated != was_over:
		heat_changed.emit(heat, overheated)
	_rig.heat = heat
	_tick_barrel_smoke(delta)


## 집탄 열 — 쏘는 중에도 계속 빠진다. 한 발이 SPREAD_PER_SHOT 씩 올리므로 연사 중에는 순증이다.
func _tick_spread(delta: float) -> void:
	_spread_heat = maxf(_spread_heat - SPREAD_DECAY * delta, 0.0)


## 지금 산포가 얼마나 벌어져 있는가 (0..1). Main 이 조준점을 벌리는 데 쓴다 —
## 플레이어 소총의 Player.spread_ratio() 와 같은 창구다.
func spread_ratio() -> float:
	return _spread_heat


## 달아오른 총구에서 연기가 샌다 — 뜨거울수록 자주, 과열 잠금 중엔 계속 (센트리건과 같은 값).
func _tick_barrel_smoke(delta: float) -> void:
	if _barrel_smoke == null or state != State.READY or heat < HEAT_SMOKE:
		return
	_smoke_t -= delta
	if _smoke_t > 0.0:
		return
	var k := clampf((heat - HEAT_SMOKE) / (1.0 - HEAT_SMOKE), 0.0, 1.0)
	_smoke_t = lerpf(0.42, 0.10, k)
	_barrel_smoke.restart()


## 과열 잠금: 총구에서 증기가 한꺼번에 터져 나오고 화면이 한 번 울린다 (센트리건 _overheat 과 같다)
func _overheat() -> void:
	overheated = true
	_walker.firing = false
	if _barrel_smoke != null:
		_barrel_smoke.restart()
	if _room != null:
		var sb := SparkBurst.spawn(_room, floor_y)
		sb.burst(_blast.global_position, 6, Vector2(0, -1), 0.9, Vector2(70, 220),
			Color(1.0, 0.86, 0.66), Color(1.0, 0.32, 0.10), Vector2(0.2, 0.55), 1500.0, 3.0, false)
	shake_requested.emit(3.0)


## 총구 연기 — 센트리건 _build_barrel_smoke() 와 같은 규격을 기체 크기(SCALE)로 줄인 것.
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
	p.initial_velocity_min = 30.0 * SCALE
	p.initial_velocity_max = 90.0 * SCALE
	p.gravity = Vector2(0, -55.0 * SCALE)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 1.0 * SCALE
	p.scale_amount_max = 2.2 * SCALE
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


## 방 밖으로 걸어 나가지 않게. 걸음 계산을 건드리지 않고 **결과만** 잘라낸다 —
## 여기서 속도까지 손대면 발이 이미 잡은 자리와 어긋나 다리가 꼬인다.
func _clamp_span() -> void:
	var x: float = _walker.body_pos.x * SCALE
	var c := clampf(x, _span.x, _span.y)
	if not is_equal_approx(x, c):
		_walker.body_pos.x = c / SCALE
		_walker.position.x = _walker.body_pos.x
		if _walker.spider_gait:
			_walker._spider.solve(_walker)


## 이 노드를 기체 자리로 옮긴다. 프롬프트 거리·카메라·원격 접속이 전부 position 을 본다.
## 그릇은 그만큼 반대로 밀어 워커 좌표계를 방에 고정한다 (_build 주석 참고).
func _sync_node() -> void:
	position = Vector2(_walker.body_pos.x * SCALE, floor_y)
	_scaler.position = -position


## 총구 화염을 **매 프레임** 총구에 다시 붙인다 (자리 + 포신 방향).
##
## 예전엔 쏘는 순간 자리만 옮기고 **회전을 아예 주지 않았다.** MuzzleBlast 는 로컬 +x 를 포신
## 방향으로 삼아 그리는 노드라, 이 노드의 회전이 0 이면 화염이 늘 화면 오른쪽으로 뻗는다 —
## 왼쪽을 보고 쏘면 화염이 총구가 아니라 **기체 뒤쪽으로** 터져 나왔다 (랩 walker_lab.gd 은
## 쏠 때 rotation 을 주고 있어서 이 증상이 랩에서는 보이지 않았다).
##
## 자리·방향을 한 발 터뜨릴 때 한 번만 잡으면 안 된다. 화염이 보이는 동안(MuzzleBlast.LIFE)에도
## 포탑은 계속 선회하고 기체는 걸어다니며 포신은 반동으로 물러난다 — 매 프레임 다시 잡아야
## 화염이 총부리에 붙어 있고 총부리가 가리키는 쪽으로만 뻗는다.
func _sync_blast() -> void:
	if _blast == null or _walker == null:
		return
	# 워커가 주는 값은 그릇 안 좌표다. `* SCALE` 로 어림하지 않고 그릇의 변환으로 옮긴다.
	var xf := _scaler.global_transform
	_blast.global_position = xf * _walker.muzzle()
	var world_dir := xf.basis_xform(_walker.aim_dir()).normalized()
	if world_dir.length_squared() <= 0.0:
		return
	# 위쪽 층이 좌우로 뒤집혀 있어도 맞도록 **부모 공간으로 되돌려** 각을 잡는다
	# (global_rotation 은 반전된 층 안에서 믿을 수 없다 — MuzzleBlast 주석과 같은 이유).
	_blast.rotation = global_transform.affine_inverse().basis_xform(world_dir).angle()
	if _barrel_smoke != null:
		_barrel_smoke.position = _blast.position


## 한 발 — **센트리건의 _try_fire 와 같은 순서**다 (sentry_turret.gd).
## ProcWalker 는 총구 자리와 포신 방향만 준다. 탄착점·산포·화염·탄피·흔들림·열은 여기서 포탑과
## 똑같이 만든다. 탄 자체는 Main 의 공용 사격 경로가 처리한다.
func _on_fired(muzzle: Vector2, dir: Vector2) -> void:
	# 센트리건은 총구를 **글로벌** 좌표로 넘긴다 (mz.global_position) — Main 의 사격 경로가 그걸 기대한다.
	# 워커가 주는 값은 그릇 안 좌표이므로 그릇의 글로벌 변환으로 옮긴다. `* SCALE` 로 어림하면
	# 지금은 맞지만 위쪽 노드에 변환이 하나만 끼어도 조용히 어긋난다 (다리가 사라졌던 것과 같은 함정).
	var xf := _scaler.global_transform
	var from: Vector2 = xf * muzzle
	var aim_dir := (xf.basis_xform(dir)).normalized()
	var to := _impact_point(from, aim_dir)
	# 산포는 **집탄 열에 비례해** 벌어진다. 안쪽 randf 를 한 번 더 곱해 가운데가 촘촘한 분포를 만든다
	# (플레이어 소총과 같은 식 — 균등 분포로 두면 늘 가장자리에 맞는 것처럼 보인다).
	var spread := SPREAD + SPREAD_HEAT * _spread_heat
	to = from + (to - from).rotated(randf_range(-spread, spread) * randf_range(0.4, 1.0))
	_spread_heat = minf(_spread_heat + SPREAD_PER_SHOT, 1.0)
	# 화염은 **포신이 겨눈 방향**으로 터뜨린다 — 산포(SPREAD)는 탄에만 준다.
	# 산포 방향으로 돌리면 한 발마다 화염이 총구에서 조금씩 어긋나 붙는다.
	_sync_blast()
	_blast.fire(randf_range(0.9, 1.15), aim_dir)
	shoot_fired.emit(from, to)
	shell_ejected.emit(from - aim_dir * 40.0, -1 if aim_dir.x > 0.0 else 1)
	shake_requested.emit(SHAKE_PER_SHOT)
	heat = minf(heat + HEAT_PER_SHOT, 1.0)
	if heat >= 1.0 and not overheated:
		_overheat()
	heat_changed.emit(heat, overheated)


## 탄이 닿을 자리. 센트리건 _impact_point() 를 그대로 옮겼다.
##
## **조준점으로 바로 쏘지 않는다.** 포신이 겨누는 **방향**으로, 조준점까지의 **거리**만큼 나간다.
## 포신은 기계식 선회 속도로 마우스를 늦게 따라가므로, 조준점으로 바로 쏘면 그려진 포신과 탄도가
## 어긋나 총이 휘어 쏘는 것처럼 보인다. 이렇게 두면 포신이 마우스를 따라잡는 순간 탄착점도
## 정확히 마우스에 얹힌다 — 따라잡는 동안의 시차는 그 자체로 기계의 굼뜸으로 읽힌다.
## 마지막에 방의 벽으로 잘라 벽 뒤로 새지 않게 한다.
func _impact_point(from: Vector2, dir: Vector2) -> Vector2:
	var dist := LASER_RANGE
	if controlled:
		# 최소 사거리. 센트리건은 400px 이지만 버그봇은 조종석이 포신 바로 뒤라 그 값이면
		# 코앞을 겨눠도 탄이 머리 한참 너머에 떨어졌다. 총구 코앞도 맞을 수 있게 줄인다.
		dist = maxf(from.distance_to(aim_target), MIN_SHOT_RANGE)
	var far := from + dir * dist
	if _room != null and _room.has_method("clip_shot"):
		far = _room.clip_shot(from, far)
	return far
