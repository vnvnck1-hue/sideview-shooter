class_name Crawler
extends Node2D
## 독성 종양 크롤러 (ToxicTumorCrawler). 바닥을 기어다니는 몬스터. 위치는 발 밑 월드 좌표.
## 리소스: assets/character/ToxicTumorCrawler/<clip>/<clip>_NN.png (543×756 셀) + crawler_meta.json
##        (Tools/build_crawler_frames.py 가 만든 프레임별 발 밑 줄·내용 영역 — 클립마다 baseline 이 달라 보정 필수).
## 행동: 플레이어를 향해 기어가다(WALK) 사거리에 들면 독액을 뱉는다(ATTACK, attack_03 프레임에서 AcidGlob 발사).
##       걷는 중 가끔(JUMP_INTERVAL) 포물선 점프로 성큼 다가간다. 착지·공격 뒤엔 잠깐 멈칫한다(IDLE).
##       걷는 중 가끔(ROAR_INTERVAL) 멈춰 서서 포효한다(ROAR) — 입을 가장 크게 벌린 roar_03 에서 잠깐 머물며 몸을 떨고,
##       입에서 침(SparkBurst 재사용, 옅은 연두빛)이 튄다. 포효 중에도 맞으며, 가까이서 포효하면 카메라가 살짝 울린다(roared).
## 피격: 총알이 히트 박스(현재 프레임 내용 영역) 안에 닿으면 HP -1, 붉은 플래시(prop_surface) + 독액 방울 + 살짝 밀림
##       + 스케일 펀치(옆으로 눌리고 스프링으로 복귀) + 뒤 벽에 작은 체액 자국(BloodStain).
##       HP 0 → 죽음 클립 + 육편(ChunkDebris, 프레임 텍스처 조각)이 사방으로 튀고 초록 체액 분출, 벽에 큰 자국.
##       잔해로 남았다가 사라진다. 죽은 뒤엔 맞지 않는다(뒤의 벽이 맞음).
## 쫀득함: 발을 축으로 한 스케일 스프링(_squash). 걷기 바운스·점프 웅크림/늘어남/착지 눌림·공격 예비동작을 모두 여기로 표현한다.

signal died(pos: Vector2)
signal spat(glob: Node2D)
signal roared(pos: Vector2)

const DIR := "res://assets/character/ToxicTumorCrawler/"
const SCALE := 0.4                    # 원본(543×756 셀)의 40% — 60% 축소. 플레이어 무릎 높이 정도
const MAX_HP := 3                  # 6 → 절반
const WALK_SPEED := 270.0
const WALK_ANIM_SPEED := 135.0        # 걷기 애니 1배속 기준 속도 (빨라지면 다리도 그만큼 빨리)
const SPAWN_FADE := 0.35              # 스폰 직후 나타나는 시간
const TURN_TIME := 0.12               # 방향 바꿀 때 멈칫

const ATTACK_MIN := 150.0             # 이보다 가까우면 뒤로 물러나며 공격
const ATTACK_MAX := 720.0             # 사거리
const ATTACK_COOLDOWN := Vector2(1.5, 2.6)
const SPIT_FRAME := 2                 # attack_03 (0-based) 에서 독액 발사
const MOUTH_LOCAL := Vector2(208.0, -135.0)   # 발 밑 기준 입 위치 (셀 px, 오른쪽 방향, attack_03 의 독액 시작점). 월드는 ×SCALE

const JUMP_INTERVAL := Vector2(2.6, 5.2)      # 걷는 중 점프 시도 간격 (초)
const JUMP_MIN_DIST := 260.0          # 플레이어가 이보다 가까우면 점프 안 함
const JUMP_RANGE := Vector2(300.0, 560.0)     # 점프 수평 거리 (플레이어까지 거리로 클램프)
const JUMP_HEIGHT := 110.0            # 월드 px
const JUMP_AIR_TIME := 0.62
const JUMP_CROUCH := 0.14             # 도약 전 웅크림 (jump_01)
const JUMP_LAND := 0.18               # 착지 자세 유지 (jump_04)

const ROAR_INTERVAL := Vector2(7.0, 14.0)     # 걷는 중 포효 시도 간격 (초)
const ROAR_MIN_DIST := 220.0          # 플레이어가 이보다 가까우면 포효 안 함 (코앞에서 멈추면 시시하다)
const ROAR_SPAWN_CHANCE := 0.45       # 스폰 페이드 직후 등장 포효 확률
const ROAR_HOLD := 0.38               # 입을 가장 크게 벌린 roar_03 에서 머무는 추가 시간
const ROAR_HOLD_FRAME := 2            # roar_03 (0-based)
const ROAR_TREMBLE := 0.035           # 포효 유지 중 스케일 떨림 진폭
const ROAR_SHAKE_RANGE := 900.0       # 이 거리 안이면 카메라 흔들림 (가까울수록 크게)
# 입 위치 (발 밑 기준 셀 px, 오른쪽 방향). 프레임마다 머리 높이가 달라 따로 잡는다. 월드는 ×SCALE
const ROAR_MOUTH := {1: Vector2(128.0, -190.0), 2: Vector2(124.0, -284.0)}
const SALIVA_DIR := {1: Vector2(1.0, -0.35), 2: Vector2(1.0, -0.75)}   # 벌린 입이 향하는 방향
const SALIVA_TRICKLE := 0.045         # 유지 중 침 방울이 새는 간격 (초)
const SALIVA_HOT := Color(0.96, 1.0, 0.92)    # 침 — 거의 흰색에 연두 기운 (독액보다 훨씬 덜 빛남)
const SALIVA_COLD := Color(0.70, 0.84, 0.62)
const SALIVA_GLOW := 0.45

const IDLE_TIME := Vector2(0.35, 0.9)
const HIT_KNOCKBACK := 26.0           # 한 발당 밀리는 거리 (px)
const HIT_FLASH_TIME := 0.12
const HIT_FLASH_RADIUS := 200.0       # 탄착점 주변만 붉게 (텍스처 px — 월드로는 ×SCALE)
const HIT_FLASH_PEAK := 0.55
const CORPSE_TIME := 7.0
const CORPSE_FADE := 1.2

const ACID_HOT := Color(0.96, 1.0, 0.62)
const ACID_COLD := Color(0.55, 0.72, 0.12)
const BLOOD_HOT := Color(0.62, 0.92, 0.30)     # 체액 (초록)
const BLOOD_COLD := Color(0.22, 0.45, 0.08)
const BLOOD_GLOW := 0.45                        # 체액 방울 발광 배율 (독액 1.0 대비 둔하게 — 형광기 제거)

# 스케일 스프링 (발 밑 축). 값은 배율 — (1,1) 로 돌아온다
const SQUASH_K := 210.0               # 스프링 강도
const SQUASH_DAMP := 13.0             # 감쇠
const HIT_PUNCH := Vector2(1.30, 0.72)        # 피격: 옆으로 눌림
const DEATH_PUNCH := Vector2(1.55, 0.55)
const JUMP_CROUCH_SQUASH := Vector2(1.18, 0.80)
const JUMP_STRETCH := Vector2(0.82, 1.24)     # 도약 순간 늘어남
const LAND_SQUASH := Vector2(1.34, 0.68)
const ATTACK_ANTICIPATION := Vector2(0.92, 1.10)
const ROAR_ANTICIPATION := Vector2(1.10, 0.90)   # 포효 시작: 살짝 웅크림
const ROAR_STRETCH := Vector2(0.90, 1.14)        # 입 벌리는 순간 위로 늘어남
const WALK_BOB := Vector2(0.05, 0.08)         # 걷기 바운스 진폭 (x 줄고 y 늘어남)
const CHUNK_CELL := 90.0              # 죽음 육편 조각 크기 (텍스처 px)
const CHUNK_COUNT := 9

enum State { IDLE, WALK, JUMP, ATTACK, ROAR, DEAD }

var room: Node2D                      # Room — player·바닥·경계 참조
var floor_y := 0.0
var min_x := 0.0
var max_x := 10000.0
var facing := 1
var hp := MAX_HP
var state: State = State.IDLE

var _meta := {}
var _cell := Vector2(543, 756)
var _frame_feet := {}                 # "walk_02" → 발 밑 줄 (셀 상단 기준)
var _frame_bbox := {}                 # "walk_02" → Rect2 (셀 로컬)
var _sprite: AnimatedSprite2D
var _mat: ShaderMaterial
var _flash := 0.0
var _idle_t := 0.0
var _turn_t := 0.0
var _attack_cd := 1.0
var _jump_timer := 0.0
var _roar_timer := 0.0
var _roar_hold := 0.0                 # >0 이면 roar_03 에서 멈춰 있는 중
var _roar_held := false               # 이번 포효에서 유지 구간을 이미 지났나
var _roar_last_frame := -1            # 침 분출을 프레임 전환마다 한 번만
var _saliva_t := 0.0
var _roar_pending := false            # 스폰 페이드가 끝나면 등장 포효
var _spat := false
var _knock := 0.0
var _knock_dir := 0.0
var _corpse_t := 0.0
var _sparks: SparkBurst
# 점프
var _jump_t := 0.0
var _jump_from := Vector2.ZERO
var _jump_dx := 0.0
var _jump_phase := 0                  # 0 웅크림 · 1 공중 · 2 착지
var _air_y := 0.0                     # 공중에서 발이 바닥 위로 뜬 높이 (월드 px)
var _spawn_t := -1.0                  # >= 0 이면 스폰 페이드 진행 중
var _squash := Vector2.ONE            # 스케일 스프링 현재값
var _squash_vel := Vector2.ZERO
var _bob_phase := 0.0                 # 걷기 바운스 위상
var _bob := Vector2.ONE


func setup(room_node: Node2D, x: float, floor_line: float, left: float, right: float, face_dir := -1) -> void:
	room = room_node
	floor_y = floor_line
	min_x = left
	max_x = right
	position = Vector2(clampf(x, min_x, max_x), floor_y)
	facing = face_dir
	_jump_timer = randf_range(JUMP_INTERVAL.x, JUMP_INTERVAL.y) * 0.6
	_roar_timer = randf_range(ROAR_INTERVAL.x, ROAR_INTERVAL.y) * 0.5
	_attack_cd = randf_range(0.8, 1.6)


func _ready() -> void:
	_load_meta()
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Body"
	_sprite.centered = false
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.sprite_frames = _build_frames()
	_mat = Lighting.character_material("prop_surface", SCALE)   # lit_surface + 피격 플래시 (파츠 마스크는 흰색 그대로) + 캐릭터 림 프리셋 (폭은 0.4 배 스케일 보정)
	_mat.set_shader_parameter("grid", Vector2(1, 1))
	_sprite.material = _mat
	_sprite.frame_changed.connect(_apply_frame_offset)
	_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_sprite)
	_sprite.flip_h = facing < 0
	_sprite.play("walk")
	_sprite.pause()
	_apply_frame_offset()
	_enter_idle(randf_range(0.2, 0.7))


func _load_meta() -> void:
	var f := FileAccess.open(DIR + "crawler_meta.json", FileAccess.READ)
	if f == null:
		push_warning("crawler_meta.json 을 읽을 수 없음 — Tools/build_crawler_frames.py 를 먼저 실행")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_meta = parsed
	var c: Array = _meta.get("cell", [543, 756])
	_cell = Vector2(c[0], c[1])
	for key in _meta.get("frames", {}).keys():
		var fr: Dictionary = _meta["frames"][key]
		_frame_feet[key] = float(fr["feet_y"])
		var b: Array = fr["bbox"]
		_frame_bbox[key] = Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var clips: Dictionary = _meta.get("clips", {
		"walk": {"fps": 8, "loop": true, "frames": 4}, "jump": {"fps": 8, "loop": false, "frames": 4},
		"death": {"fps": 10, "loop": false, "frames": 4}, "attack": {"fps": 10, "loop": false, "frames": 4},
		"roar": {"fps": 8, "loop": false, "frames": 4},
	})
	for clip_name in clips.keys():
		var cfg: Dictionary = clips[clip_name]
		sf.add_animation(clip_name)
		sf.set_animation_speed(clip_name, float(cfg["fps"]))
		sf.set_animation_loop(clip_name, bool(cfg["loop"]))
		for i in range(1, int(cfg["frames"]) + 1):
			sf.add_frame(clip_name, Lighting.textured("%s%s/%s_%02d.png" % [DIR, clip_name, clip_name, i]))
	return sf


func _frame_key() -> String:
	return "%s_%02d" % [_sprite.animation, _sprite.frame + 1]


## 프레임마다 발 밑 줄이 달라서, 그 줄이 노드 원점(바닥)에 오도록 오프셋을 다시 잡는다
func _apply_frame_offset() -> void:
	var feet: float = _frame_feet.get(_frame_key(), _cell.y)
	_sprite.offset = Vector2(-_cell.x * 0.5, -feet - _air_y / SCALE)


## 현재 프레임 내용 영역의 월드 히트 박스
func hit_rect() -> Rect2:
	var b: Rect2 = _frame_bbox.get(_frame_key(), Rect2(0, 0, _cell.x, _cell.y))
	if _sprite.flip_h:
		b.position.x = _cell.x - b.end.x
	return Rect2(position + (_sprite.offset + b.position) * SCALE, b.size * SCALE)


func is_hit(point: Vector2) -> bool:
	return state != State.DEAD and hit_rect().has_point(point)


func hit_center() -> Vector2:
	return hit_rect().get_center()


func is_dead() -> bool:
	return state == State.DEAD


func _target() -> Node2D:
	return room.get("player") if room else null


## 스포너가 만든 개체: 독액 방울과 함께 스르륵 나타난다
func spawn_in() -> void:
	_spawn_t = 0.0
	modulate.a = 0.0
	_roar_pending = randf() < ROAR_SPAWN_CHANCE
	if is_inside_tree():
		_spawn_burst()
	else:
		ready.connect(_spawn_burst, CONNECT_ONE_SHOT)


func _spawn_burst() -> void:
	var sb := _burst_node()
	sb.burst(position, 10, Vector2(0, -1), 1.0, Vector2(100, 300), ACID_HOT, ACID_COLD,
		Vector2(0.3, 0.6), 2000.0, 3.5, false)


## 스케일 스프링 갱신 + 걷기 바운스 → 스프라이트 스케일 (발 밑이 축)
func _update_squash(delta: float) -> void:
	_squash_vel += (Vector2.ONE - _squash) * SQUASH_K * delta
	_squash_vel *= exp(-SQUASH_DAMP * delta)
	_squash += _squash_vel * delta
	var want_bob := Vector2.ONE
	if state == State.WALK and _sprite.is_playing():
		# 걷기 프레임 2장마다 한 번 튕긴다 (8fps × speed_scale)
		_bob_phase += delta * absf(_sprite.speed_scale) * 8.0 / 2.0 * TAU
		var w := 0.5 - 0.5 * cos(_bob_phase)
		want_bob = Vector2(1.0 - WALK_BOB.x * w, 1.0 + WALK_BOB.y * w)
	else:
		_bob_phase = 0.0
	_bob = _bob.lerp(want_bob, minf(1.0, 14.0 * delta))
	_sprite.scale = Vector2(SCALE, SCALE) * _squash * _bob


## 스케일 펀치: 즉시 그 배율로 튀고 스프링이 (1,1) 로 되돌린다
func _punch(s: Vector2) -> void:
	_squash = s
	_squash_vel = Vector2.ZERO


func _process(delta: float) -> void:
	_update_squash(delta)
	if _spawn_t >= 0.0:
		_spawn_t += delta
		modulate.a = clampf(_spawn_t / SPAWN_FADE, 0.0, 1.0)
		if _spawn_t >= SPAWN_FADE:
			_spawn_t = -1.0
			if _roar_pending and (state == State.IDLE or state == State.WALK):
				_start_roar()          # 등장 포효
			_roar_pending = false
	if _flash > 0.0:
		_flash = maxf(_flash - delta / HIT_FLASH_TIME, 0.0)
		_mat.set_shader_parameter("flash", HIT_FLASH_PEAK * _flash * _flash)
	if _knock > 0.0:
		var step := minf(_knock, HIT_KNOCKBACK * delta / 0.1)
		_knock -= step
		position.x = clampf(position.x + step * _knock_dir, min_x, max_x)

	match state:
		State.DEAD:
			_process_dead(delta)
		State.IDLE:
			_idle_t -= delta
			_attack_cd = maxf(_attack_cd - delta, 0.0)     # 멈칫하는 동안에도 쿨다운은 돈다 (플레이어 앞에서 굳지 않게)
			_face_target()
			if _idle_t <= 0.0:
				_decide()
		State.WALK:
			_process_walk(delta)
		State.JUMP:
			_process_jump(delta)
		State.ATTACK:
			_attack_cd = maxf(_attack_cd - delta, 0.0)
			if not _spat and _sprite.frame >= SPIT_FRAME:
				_spit()
		State.ROAR:
			_attack_cd = maxf(_attack_cd - delta, 0.0)
			_process_roar(delta)


## 플레이어와의 거리로 다음 행동을 고른다
func _decide() -> void:
	var t := _target()
	if t == null:
		_enter_idle(randf_range(IDLE_TIME.x, IDLE_TIME.y))
		return
	var dx := absf(t.position.x - position.x)
	if dx <= ATTACK_MAX and _attack_cd <= 0.0:
		_start_attack()
	else:
		state = State.WALK
		_sprite.play("walk")


func _face_target() -> void:
	var t := _target()
	if t == null:
		return
	var want := 1 if t.position.x >= position.x else -1
	if want != facing:
		facing = want
		_sprite.flip_h = facing < 0
		_turn_t = TURN_TIME


func _enter_idle(seconds: float) -> void:
	state = State.IDLE
	_idle_t = seconds
	_sprite.play("walk")
	_sprite.frame = 0
	_sprite.pause()
	_apply_frame_offset()


func _process_walk(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	var t := _target()
	if t == null:
		_enter_idle(0.5)
		return
	_face_target()
	if _turn_t > 0.0:
		_turn_t -= delta
		_sprite.pause()
		return
	if not _sprite.is_playing():
		_sprite.play("walk")

	var dx := t.position.x - position.x
	var dist := absf(dx)
	# 사거리 안이고 쿨다운이 끝났으면 뱉는다
	if dist <= ATTACK_MAX and _attack_cd <= 0.0:
		_start_attack()
		return
	# 가끔 멈춰 서서 포효한다 (플레이어가 코앞이면 건너뛴다)
	_roar_timer -= delta
	if _roar_timer <= 0.0:
		_roar_timer = randf_range(ROAR_INTERVAL.x, ROAR_INTERVAL.y)
		if dist >= ROAR_MIN_DIST:
			_start_roar()
			return
	# 가끔 점프로 성큼 다가간다
	_jump_timer -= delta
	if _jump_timer <= 0.0:
		_jump_timer = randf_range(JUMP_INTERVAL.x, JUMP_INTERVAL.y)
		if dist >= JUMP_MIN_DIST:
			_start_jump(signf(dx) * clampf(dist - 120.0, JUMP_RANGE.x, JUMP_RANGE.y))
			return
	# 너무 가까우면 조금 물러나고, 아니면 다가간다 (플레이어 앞 ATTACK_MIN 거리에서 멈춘다)
	var move_dir := 0.0
	if dist > ATTACK_MIN + 40.0:
		move_dir = signf(dx)
	elif dist < ATTACK_MIN - 40.0:
		move_dir = -signf(dx)
	if move_dir == 0.0:
		_enter_idle(randf_range(IDLE_TIME.x, IDLE_TIME.y) * 0.6)
		return
	var forward := move_dir == signf(float(facing))
	var v := WALK_SPEED * (1.0 if forward else 0.6)
	position.x = clampf(position.x + move_dir * v * delta, min_x, max_x)
	# 뒷걸음이면 역재생
	_sprite.speed_scale = (v / WALK_ANIM_SPEED) * (1.0 if forward else -1.0)


func _start_attack() -> void:
	state = State.ATTACK
	_face_target()
	_punch(ATTACK_ANTICIPATION)
	_spat = false
	_sprite.speed_scale = 1.0
	_sprite.play("attack")
	_apply_frame_offset()


func _spit() -> void:
	_spat = true
	_attack_cd = randf_range(ATTACK_COOLDOWN.x, ATTACK_COOLDOWN.y)
	var t := _target()
	if t == null:
		return
	_punch(Vector2(1.12, 0.92))                 # 뱉는 반동
	var mouth := position + Vector2(MOUTH_LOCAL.x * facing, MOUTH_LOCAL.y) * SCALE
	var glob := AcidGlob.new()
	glob.setup(mouth, t, floor_y, room)
	spat.emit(glob)


func _start_roar() -> void:
	state = State.ROAR
	_face_target()
	_roar_hold = 0.0
	_roar_held = false
	_roar_last_frame = -1
	_saliva_t = 0.0
	_punch(ROAR_ANTICIPATION)
	_sprite.speed_scale = 1.0
	_sprite.play("roar")
	_apply_frame_offset()


## 포효 진행: roar_02·03 으로 넘어갈 때 침을 한 움큼 뿜고, roar_03 에서는 ROAR_HOLD 동안 멈춰 몸을 떨며 침이 샌다
func _process_roar(delta: float) -> void:
	var f := _sprite.frame
	if f != _roar_last_frame:
		_roar_last_frame = f
		if ROAR_MOUTH.has(f):
			_spit_saliva(f, 7 if f == ROAR_HOLD_FRAME else 4, 1.0)
		if f == ROAR_HOLD_FRAME and not _roar_held:
			_roar_held = true
			_roar_hold = ROAR_HOLD
			_sprite.pause()
			_punch(ROAR_STRETCH)
			roared.emit(position)
	if _roar_hold > 0.0:
		_roar_hold -= delta
		# 몸 떨림: 스프링 목표는 그대로 두고 현재값만 살짝 흔든다
		_squash += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * ROAR_TREMBLE
		_saliva_t -= delta
		if _saliva_t <= 0.0:
			_saliva_t = SALIVA_TRICKLE
			_spit_saliva(ROAR_HOLD_FRAME, 1, 0.55)
		if _roar_hold <= 0.0:
			_sprite.play("roar")          # 멈춘 자리(roar_03)에서 이어서 재생


## 입에서 침 방울. frame: 입 위치 기준 프레임, strength: 속도·크기 배율 (트리클은 약하게)
func _spit_saliva(frame: int, count: int, strength: float) -> void:
	var local: Vector2 = ROAR_MOUTH.get(frame, ROAR_MOUTH[ROAR_HOLD_FRAME])
	var mouth := position + Vector2(local.x * facing, local.y - _air_y / SCALE) * SCALE
	var dir: Vector2 = SALIVA_DIR.get(frame, SALIVA_DIR[ROAR_HOLD_FRAME])
	dir.x *= facing
	var sb := _burst_node()
	sb.burst(mouth, count, dir, 0.55, Vector2(90, 260) * strength, SALIVA_HOT, SALIVA_COLD,
		Vector2(0.35, 0.8), 1500.0, 3.0 * lerpf(0.8, 1.0, strength), false, SALIVA_GLOW)


## 개발용: 지금 바로 포효 (공격 중이면 끊고 포효 — 스크린샷 타이밍이 스폰 난수에 흔들리지 않게)
func force_roar() -> void:
	if state == State.DEAD or state == State.JUMP or state == State.ROAR:
		return
	_start_roar()


## 개발용: 지금 바로 독액 공격
func force_attack() -> void:
	if state == State.DEAD or state == State.JUMP or state == State.ATTACK or state == State.ROAR:
		return
	_start_attack()


## 개발용: 지금 바로 플레이어 쪽으로 점프
func force_jump() -> void:
	if state == State.DEAD or state == State.JUMP:
		return
	var t := _target()
	var dx := (t.position.x - position.x) if t else float(facing) * JUMP_RANGE.y
	_start_jump(signf(dx) * clampf(absf(dx) - 120.0, JUMP_RANGE.x, JUMP_RANGE.y))


func _start_jump(dx: float) -> void:
	state = State.JUMP
	_jump_t = 0.0
	_jump_phase = 0
	_jump_from = position
	# 경계를 넘지 않게 잘라낸다
	var to_x := clampf(position.x + dx, min_x, max_x)
	_jump_dx = to_x - position.x
	facing = 1 if _jump_dx >= 0.0 else -1
	_sprite.flip_h = facing < 0
	_sprite.speed_scale = 1.0
	_sprite.play("jump")
	_sprite.pause()
	_sprite.frame = 0
	_apply_frame_offset()
	_punch(JUMP_CROUCH_SQUASH)


func _process_jump(delta: float) -> void:
	_jump_t += delta
	match _jump_phase:
		0:   # 웅크림
			if _jump_t >= JUMP_CROUCH:
				_jump_phase = 1
				_jump_t = 0.0
				_punch(JUMP_STRETCH)
		1:   # 공중 — 포물선. 노드는 바닥에 두고 스프라이트만 띄운다(히트 박스도 함께 뜬다)
			var k := clampf(_jump_t / JUMP_AIR_TIME, 0.0, 1.0)
			position.x = _jump_from.x + _jump_dx * k
			_air_y = 4.0 * JUMP_HEIGHT * k * (1.0 - k)
			_sprite.frame = 1 if k < 0.38 else 2
			_apply_frame_offset()
			if k >= 1.0:
				_air_y = 0.0
				_jump_phase = 2
				_jump_t = 0.0
				_sprite.frame = 3
				_apply_frame_offset()
				_punch(LAND_SQUASH)
				_land_dust()
		2:   # 착지 자세
			if _jump_t >= JUMP_LAND:
				_enter_idle(randf_range(IDLE_TIME.x, IDLE_TIME.y) * 0.7)


## 착지 먼지 — 바닥에서 양옆으로 낮게 퍼지는 회색 알갱이
func _land_dust() -> void:
	var sb := _burst_node()
	var dust := Color(0.55, 0.52, 0.48)
	var dark := Color(0.35, 0.33, 0.3)
	sb.burst(position + Vector2(-90 * SCALE, 0), 7, Vector2(-1, -0.25), 0.35, Vector2(120, 260),
		dust, dark, Vector2(0.3, 0.55), 1800.0, 4.0, false)
	sb.burst(position + Vector2(90 * SCALE, 0), 7, Vector2(1, -0.25), 0.35, Vector2(120, 260),
		dust, dark, Vector2(0.3, 0.55), 1800.0, 4.0, false)


func _burst_node() -> SparkBurst:
	if _sparks == null or not is_instance_valid(_sparks):
		_sparks = SparkBurst.spawn(get_parent(), floor_y, true)
		_sparks.z_index = 1
	return _sparks


## 총알 피격. point: 탄착 월드 좌표, dir: 탄 진행 방향(+1 왼→오)
func hit(point: Vector2, dir: float) -> void:
	if state == State.DEAD:
		return
	hp -= 1
	_flash = 1.0
	_mat.set_shader_parameter("flash", HIT_FLASH_PEAK)
	_mat.set_shader_parameter("radius_px", HIT_FLASH_RADIUS)
	# 셰이더 UV 는 셀 전체 기준 (flip_h 면 x 반전)
	var cell_uv := ((point - position) / SCALE - _sprite.offset) / _cell
	if _sprite.flip_h:
		cell_uv.x = 1.0 - cell_uv.x
	_mat.set_shader_parameter("hit_uv", cell_uv.clamp(Vector2.ZERO, Vector2.ONE))
	_knock = HIT_KNOCKBACK
	_knock_dir = signf(dir) if dir != 0.0 else -float(facing)
	# 스케일 펀치: 탄이 온 쪽이 눌리듯 옆으로 퍼진다
	_punch(HIT_PUNCH)
	# 독액 방울: 탄 진행 방향 뒤쪽 원뿔로 튄다 + 체액이 탄 방향으로 벽에 튄다
	var sb := _burst_node()
	sb.burst(point, 9, Vector2(-signf(dir), -0.6), 0.9, Vector2(140, 420), ACID_HOT, ACID_COLD,
		Vector2(0.3, 0.7), 2000.0, 4.5, false)
	sb.burst(point, 7, Vector2(signf(dir), -0.3), 0.7, Vector2(200, 520), BLOOD_HOT, BLOOD_COLD,
		Vector2(0.25, 0.6), 2200.0, 3.5, false, BLOOD_GLOW)
	if room and room.has_method("add_stain"):
		room.add_stain(point + Vector2(signf(dir) * 30.0, 0.0), Vector2(signf(dir), -0.15), 6, 40.0)
		# 가끔(35%) 체액이 탄 방향 벽면으로 부채꼴로 흩뿌려진다 — 덩어리가 순차적으로 찍히고 흘러내림
		if randf() < 0.35 and room.has_method("add_spray"):
			room.add_spray(point, Vector2(signf(dir), randf_range(-0.7, 0.1)), 14, 160.0, 0.9)
	if hp <= 0:
		_die(dir)
	elif state == State.IDLE:
		_idle_t = minf(_idle_t, 0.12)      # 맞으면 멈칫 시간을 줄여 바로 반응


func _die(dir: float) -> void:
	state = State.DEAD
	_air_y = 0.0
	_knock = HIT_KNOCKBACK * 1.5
	_corpse_t = 0.0
	_sprite.speed_scale = 1.0
	_sprite.play("death")
	_apply_frame_offset()
	_punch(DEATH_PUNCH)
	var sb := _burst_node()
	var c := hit_center()
	# 독액 + 초록 체액이 사방으로 분출 (체액은 더 많이·굵게·오래)
	sb.burst(c, 22, Vector2(-signf(dir) * 0.4, -1.0), 1.1, Vector2(160, 560), ACID_HOT, ACID_COLD,
		Vector2(0.45, 1.1), 2000.0, 5.0, true)
	sb.burst(c, 34, Vector2(signf(dir) * 0.3, -0.8), PI, Vector2(220, 760), BLOOD_HOT, BLOOD_COLD,
		Vector2(0.5, 1.3), 2300.0, 6.0, false, BLOOD_GLOW)
	# 육편: 현재 프레임 텍스처를 조각내 사방으로 날린다
	_spawn_chunks(c, dir)
	# 벽에 큰 체액 자국 (탄 방향으로 길게) + 바닥 쪽 작은 자국
	if room and room.has_method("add_stain"):
		room.add_stain(c + Vector2(signf(dir) * 40.0, -10.0), Vector2(signf(dir), -0.2), 22, 110.0)
		room.add_stain(Vector2(position.x, floor_y - 6.0), Vector2(signf(dir), 0.0), 8, 70.0)
		# 죽을 때는 대개(75%) 넓게 분사 — 탄 방향으로 위쪽 부채꼴, 멀리까지
		if randf() < 0.75 and room.has_method("add_spray"):
			room.add_spray(c, Vector2(signf(dir), -0.35), 26, 280.0, 1.3)
	died.emit(position)


## 현재 프레임의 내용 영역을 CHUNK_CELL 격자로 나눠 그중 CHUNK_COUNT 조각을 ChunkDebris 로 날린다
func _spawn_chunks(center: Vector2, dir: float) -> void:
	var b: Rect2 = _frame_bbox.get(_frame_key(), Rect2(0, 0, _cell.x, _cell.y))
	var tex: Texture2D = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	var cells: Array = []
	var y := b.position.y
	while y < b.end.y:
		var x := b.position.x
		while x < b.end.x:
			cells.append(Rect2(x, y, minf(CHUNK_CELL, b.end.x - x), minf(CHUNK_CELL, b.end.y - y)))
			x += CHUNK_CELL
		y += CHUNK_CELL
	cells.shuffle()
	var parent := get_parent()
	for i in range(mini(CHUNK_COUNT, cells.size())):
		var region: Rect2 = cells[i]
		# 조각의 월드 위치 (flip_h 면 셀 중심 기준 반전)
		var local := region.get_center()
		if _sprite.flip_h:
			local.x = _cell.x - local.x
		var world := position + (_sprite.offset + local) * SCALE
		# 피격당한 쪽 반대편(탄 진행 방향)으로 튄다 — 부채꼴로 조금 퍼지고, 위로도 솟는다
		var fwd := Vector2(signf(dir), 0.0).rotated(randf_range(-0.55, 0.55))
		var away := (world - center)
		away = away.normalized() if away.length() > 1.0 else Vector2(0, -1)
		var vel := fwd * randf_range(380.0, 820.0) + away * randf_range(40.0, 140.0) \
			+ Vector2(0, -randf_range(200.0, 560.0))
		var chunk := ChunkDebris.new()
		chunk.setup(tex, region, world, vel, floor_y)
		chunk.scale = Vector2(SCALE, SCALE)
		chunk.flip_h = _sprite.flip_h
		chunk.z_index = 1
		parent.add_child(chunk)


func _process_dead(delta: float) -> void:
	_corpse_t += delta
	if _corpse_t > CORPSE_TIME - CORPSE_FADE:
		modulate.a = clampf((CORPSE_TIME - _corpse_t) / CORPSE_FADE, 0.0, 1.0)
	if _corpse_t >= CORPSE_TIME:
		if _sparks and is_instance_valid(_sparks):
			_sparks.persistent = false
		queue_free()


func _on_animation_finished() -> void:
	match state:
		State.ATTACK:
			if not _spat:
				_spit()
			_enter_idle(randf_range(IDLE_TIME.x, IDLE_TIME.y))
		State.ROAR:
			_enter_idle(randf_range(IDLE_TIME.x, IDLE_TIME.y) * 0.8)
		State.DEAD:
			pass      # 마지막 프레임(잔해) 유지
