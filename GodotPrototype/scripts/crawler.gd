class_name Crawler
extends Node2D
## 독성 종양 크롤러 (ToxicTumorCrawler). 바닥을 기어다니는 몬스터. 위치는 발 밑 월드 좌표.
## 리소스: assets/character/ToxicTumorCrawler/<clip>/<clip>_NN.png (543×756 셀) + crawler_meta.json
##        (Tools/build_crawler_frames.py 가 만든 프레임별 발 밑 줄·내용 영역 — 클립마다 baseline 이 달라 보정 필수).
## 행동: 플레이어를 향해 기어가다(WALK) 사거리에 들면 독액을 뱉는다(ATTACK, attack_03 프레임에서 AcidGlob 발사).
##       걷는 중 가끔(JUMP_INTERVAL) 포물선 점프로 성큼 다가간다. 착지·공격 뒤엔 잠깐 멈칫한다(IDLE).
##       걷는 중 가끔(WALL_INTERVAL) 옆 벽으로 뛰어올라 붙고(WALL_JUMP), 벽을 타고 올라가(WALL) 안쪽 코너를 돌아(CORNER)
##       천장에 매달린다. 천장에서는 플레이어 머리 위까지 기어가 잠깐 노린 뒤 덮친다(FALL). 벽·천장에서도 맞으며,
##       맞으면 일정 확률로 떨어진다. **벽 동작은 전용 그림 없이 바닥 클립(walk·jump)을 스프라이트째 돌려서 만든다** —
##       도약 중에는 0°→±90° 로 넘어가고, 안쪽 코너에서는 ±90°→±180° 로 돌며, 그동안 다리는 계속 논다.
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

# 벽·천장 이동. **벽 전용 그림을 쓰지 않는다** — 접지점이 노드 원점이라 스프라이트를 그 점에서 돌리기만 하면
# 바닥 클립이 그대로 벽·천장 자세가 된다(오른쪽 벽 −90° · 왼쪽 벽 +90° · 천장 180°, 머리 방향은 flip_h).
# 도약·코너처럼 자세가 꺾이는 구간은 그 각도를 프레임마다 보간하고, 클립은 바닥과 똑같은 jump·walk 를 계속 돌린다.
# 덕분에 디테일·걷기 사이클·걷기 바운스·스케일 스프링·림이 바닥과 완전히 같다.
# (WallMotionV2 리소스는 다리 보행 사이클이 없는 5프레임 키포즈라 이 방식으로 대체했다. 자산은 남아 있다.)

const WALL_INTERVAL := Vector2(2.5, 5.5)      # 걷는 중 벽으로 뛰어오를 시도 간격 (초) — 일반 점프(2.6~5.2초)와 같은 빈도로 노린다
const WALL_REACH := Vector2(220.0, 1000.0)    # 벽까지 수평 거리가 이 범위여야 뛴다
const WALL_JUMP_TIME := 0.46
const WALL_JUMP_ARC := 150.0          # 도약 포물선의 추가 높이
const WALL_RISE := Vector2(300.0, 520.0)      # 벽에 붙는 높이 (바닥 위)
const WALL_SPEED := 200.0             # 벽·천장을 기어가는 속도
const WALL_CLEAR := 118.0             # 천장·코너에서 띄우는 여유 (몸 반길이 104 + 여백). 코너 회전 반지름이기도 하다
const WALL_CORNER_TIME := 0.5         # 안쪽 코너 전환 — 접지점이 코너를 90° 돌고 몸도 90° 넘어간다
const WALL_OVER_DIST := 70.0          # 천장에서 플레이어 머리 위 이 거리 안에 들면 덮칠 준비
const WALL_HOLD := Vector2(0.5, 1.1)  # 덮치기 직전 매달려 노리는 시간
const WALL_MAX_TIME := 11.0           # 안전장치 — 이만큼 붙어 있었으면 그냥 떨어진다
const WALL_KNOCK_OFF := 0.45          # 벽에 붙은 채 맞았을 때 떨어질 확률
const FALL_GRAVITY := 2400.0

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
const HIT_KNOCKBACK := 26.0           # 한 발당 밀리는 거리 (px, 위력 1.0 기준)
const KNOCK_TIME := 0.1               # 그 거리를 미는 데 걸리는 시간 (초) — 위력이 커도 시간은 같다
const HIT_CHUNK_POWER := 1.5          # 이 위력 이상이면 살아 있어도 살점이 뜯겨 날아간다
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

enum State { IDLE, WALK, JUMP, ATTACK, ROAR, WALL_JUMP, WALL, CORNER, FALL, DEAD }
enum Surface { FLOOR, WALL, CEILING }       # 지금 어느 면에 붙어 있나 (WALL 은 _wall_side 쪽 수직면)

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
# 벽·천장
var _surface: Surface = Surface.FLOOR
var _wall_side := 1                   # +1 오른쪽 벽 · -1 왼쪽 벽
var _wall_timer := 0.0                # 다음 벽 도약까지
var _wall_t := 0.0                    # 붙어 있은 시간 (안전장치)
var _wall_to := Vector2.ZERO          # 도약 착점 (벽면 접지점)
var _wall_hold := 0.0                 # 천장에서 노리는 시간
var _wall_dir := 0.0                  # 천장에서 기어가는 방향 (+1 오른쪽)
var _wall_goal_y := 0.0               # 벽에서 올라갈 목표 높이
var _corner_t := 0.0
var _corner_pivot := Vector2.ZERO     # 코너 점 — 이 점을 중심으로 접지점이 90° 돈다
var _corner_from := Vector2.ZERO      # 코너 점 기준 시작 벡터
var _fall_vel := 0.0                  # 떨어지는 속도 (FALL · 벽에서 죽었을 때)
var _dead_falling := false            # 벽·천장에서 죽어 시체가 아직 떨어지는 중
var _spawn_t := -1.0                  # >= 0 이면 스폰 페이드 진행 중
var _knock_rate := HIT_KNOCKBACK / KNOCK_TIME   # 넉백 속도 (px/s)
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
	_wall_timer = randf_range(WALL_INTERVAL.x, WALL_INTERVAL.y) * 0.5
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


## 표면에서 몸 쪽으로 향하는 단위 법선 (바닥에 선 자세면 (0,-1)) — 스프라이트 회전이 곧 붙어 있는 면이다
func _pose_normal() -> Vector2:
	return Vector2(0, -1).rotated(_sprite.rotation)


## 머리가 향하는 단위 벡터 (표면을 따라가는 방향)
func _pose_facing() -> Vector2:
	return Vector2(-1.0 if _sprite.flip_h else 1.0, 0.0).rotated(_sprite.rotation)


## 접지점 기준 셀 px 좌표(오른쪽을 보는 자세 기준)를 월드 좌표로 — 뒤집기·회전·배율을 모두 적용한다
func _pose_point(local: Vector2) -> Vector2:
	var p := Vector2(-local.x if _sprite.flip_h else local.x, local.y) * SCALE
	return position + p.rotated(_sprite.rotation)


## 현재 프레임 내용 영역 (셀 로컬, 뒤집기 전)
func _bbox_cell() -> Rect2:
	return _frame_bbox.get(_frame_key(), Rect2(0, 0, _cell.x, _cell.y))


## 몸의 절반 길이 (머리-꼬리 축, 월드 px) — 천장에서 벽에 처박히지 않게 남길 여유
func _body_half_len() -> float:
	return _bbox_cell().size.x * SCALE * 0.5


## 프레임마다 접지 줄이 달라서, 그 줄이 노드 원점(= 붙어 있는 면과 닿는 점)에 오도록 오프셋을 다시 잡는다
func _apply_frame_offset() -> void:
	var feet: float = _frame_feet.get(_frame_key(), _cell.y)
	_sprite.offset = Vector2(-_cell.x * 0.5, -feet - _air_y / SCALE)


## 현재 프레임 내용 영역의 월드 히트 박스. 벽·천장에서는 스프라이트가 돌아가 있으므로 네 귀퉁이를 돌려 AABB 로 감싼다
func hit_rect() -> Rect2:
	var b := _bbox_cell()
	if _sprite.flip_h:
		b.position.x = _cell.x - b.end.x
	if _sprite.flip_v:
		b.position.y = _cell.y - b.end.y
	var lo := (_sprite.offset + b.position) * SCALE
	var hi := lo + b.size * SCALE
	if is_zero_approx(_sprite.rotation):
		return Rect2(position + lo, b.size * SCALE)
	var r := Rect2(position + lo.rotated(_sprite.rotation), Vector2.ZERO)
	for c in [Vector2(hi.x, lo.y), Vector2(lo.x, hi.y), hi]:
		r = r.expand(position + c.rotated(_sprite.rotation))
	return r


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
	# 벽·천장에서도 같은 walk 클립이라 바운스도 그대로다 — 스케일은 회전 전 로컬 축이라 몸을 따라 돈다
	if (state == State.WALK or state == State.WALL) and _sprite.is_playing():
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
		var step := minf(_knock, _knock_rate * delta)
		_knock -= step
		# 벽·천장에 붙어 있거나 공중인 동안은 밀리지 않는다 (면에서 미끄러져 나가면 자세가 깨진다)
		if not _off_floor():
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
		State.WALL_JUMP:
			_process_wall_jump(delta)
		State.WALL:
			_process_wall(delta)
		State.CORNER:
			_process_corner(delta)
		State.FALL:
			_process_fall(delta)
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
	_surface = Surface.FLOOR
	_idle_t = seconds
	_sprite.rotation = 0.0                # 벽에서 돌아왔을 수도 있으니 바닥 자세로 되돌린다
	_sprite.flip_v = false
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
	# 가끔 옆 벽으로 뛰어올라 붙는다 (벽이 손 닿는 거리에 있을 때만)
	_wall_timer -= delta
	if _wall_timer <= 0.0:
		_wall_timer = randf_range(WALL_INTERVAL.x, WALL_INTERVAL.y)
		if _try_wall_jump():
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


## 개발용: 지금 바로 옆 벽으로 뛰어오른다 (붙을 벽이 없으면 아무 일도 없다)
func force_wall() -> void:
	if state != State.IDLE and state != State.WALK:
		return
	_try_wall_jump()


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


# ─── 벽·천장 이동 ────────────────────────────────────────────────────────────
# 노드 위치(position)는 언제나 "지금 붙어 있는 면과 닿는 점" 이다 — 바닥에서는 발 밑, 벽에서는 옆구리,
# 천장에서는 등. 스프라이트 오프셋이 프레임 각도에 맞춰 그 점을 원점에 맞춘다(_apply_frame_offset).

func _solid() -> RoomSolid:
	var s = room.get("solid") if room else null
	return s if s is RoomSolid else RoomSolid.active


## 지금 붙어 있는 면에 맞춰 바닥 클립을 통째로 돌려 놓는다 (벽 = ±90° · 천장 = 180°).
## head: 표면을 따라 머리가 향할 방향 — 벽이면 -1 위 / +1 아래, 천장이면 -1 왼쪽 / +1 오른쪽.
func _set_surface_pose(head: float) -> void:
	_sprite.flip_v = false
	match _surface:
		Surface.WALL:
			# 오른쪽 벽(-90°) 은 안 뒤집으면 머리가 위, 왼쪽 벽(+90°) 은 안 뒤집으면 머리가 아래
			_sprite.rotation = -PI * 0.5 * float(_wall_side)
			_sprite.flip_h = (head > 0.0) if _wall_side > 0 else (head < 0.0)
		Surface.CEILING:
			_sprite.rotation = PI                  # 180° 자세는 안 뒤집으면 머리가 왼쪽
			_sprite.flip_h = head > 0.0
		_:
			_sprite.rotation = 0.0
			_sprite.flip_h = facing < 0
	_apply_frame_offset()


## 바닥에서 발이 떨어져 있는 상태인가 (넉백·사망 처리가 갈린다)
func _off_floor() -> bool:
	return state == State.WALL_JUMP or state == State.WALL or state == State.CORNER or state == State.FALL


## 높이 y 에서 _wall_side 쪽 벽면의 x. 계단형 방이라 높이마다 다르다
func _wall_face_x(y: float) -> float:
	var s := _solid()
	if s == null:
		return position.x
	var span := s.open_span_at(position.x - float(_wall_side) * 20.0, y)
	if span.x >= span.y:
		return position.x
	return span.y if _wall_side > 0 else span.x


## 이 벽에서 올라갈 수 있는 가장 높은 접지점 (천장에서 WALL_CLEAR 만큼 아래)
func _wall_top_y() -> float:
	var s := _solid()
	if s == null:
		return position.y
	return s.open_top_at(position.x - float(_wall_side) * 20.0) + WALL_CLEAR


## 가까운 쪽 벽부터 붙을 자리를 찾는다. 찾으면 도약 시작하고 true
func _try_wall_jump() -> bool:
	var s := _solid()
	if s == null:
		return false
	var rise := randf_range(WALL_RISE.x, WALL_RISE.y)
	var span := s.open_span_at(position.x, floor_y - rise)
	if span.y - span.x < WALL_CLEAR * 3.0:
		return false                                  # 이 높이에 붙을 만한 열린 폭이 없다
	var near_right := (span.y - position.x) <= (position.x - span.x)
	for side in ([1, -1] if near_right else [-1, 1]):
		var wx: float = span.y if side > 0 else span.x
		var d := absf(wx - position.x)
		if d < WALL_REACH.x or d > WALL_REACH.y:
			continue
		var to_y := minf(floor_y - rise, floor_y - WALL_RISE.x)
		to_y = maxf(to_y, s.open_top_at(wx - float(side) * 20.0) + WALL_CLEAR)
		if to_y > floor_y - WALL_RISE.x * 0.6:
			continue                                  # 천장이 너무 낮아 붙을 높이가 안 나온다
		_start_wall_jump(side, Vector2(wx, to_y))
		return true
	return false


func _start_wall_jump(side: int, to: Vector2) -> void:
	state = State.WALL_JUMP
	_wall_side = side
	_wall_to = to
	_jump_from = position
	_jump_t = 0.0
	_jump_phase = 0
	_wall_t = 0.0
	facing = side
	# 일반 점프와 같은 클립·같은 뒤집기 — 도약 방향을 보고 뛴다. 그 자세 그대로 벽으로 넘어간다
	# (벽에서 머리가 위를 보는 자세의 flip 과 여기가 정확히 같아서, 붙는 순간 뒤집기가 튀지 않는다)
	_sprite.speed_scale = 1.0
	_sprite.rotation = 0.0
	_sprite.play("jump")
	_sprite.pause()
	_sprite.frame = 0                                 # jump_01 웅크림
	_sprite.flip_h = side < 0
	_sprite.flip_v = false
	_apply_frame_offset()
	_punch(JUMP_CROUCH_SQUASH)


## 웅크렸다가 포물선으로 날아 벽면에 붙는다. 나는 동안 몸이 0° → ±90° 로 넘어간다(뒤로 갈수록 빠르게 — 벽에
## 닿기 직전에 발을 착 붙이는 느낌). 그림은 바닥 점프 클립 그대로다.
func _process_wall_jump(delta: float) -> void:
	_jump_t += delta
	if _jump_phase == 0:
		if _jump_t >= JUMP_CROUCH:
			_jump_phase = 1
			_jump_t = 0.0
			_punch(JUMP_STRETCH)
			_sprite.frame = 1
		return
	var k := clampf(_jump_t / WALL_JUMP_TIME, 0.0, 1.0)
	position = _jump_from.lerp(_wall_to, k) + Vector2(0.0, -WALL_JUMP_ARC * 4.0 * k * (1.0 - k))
	_sprite.rotation = -PI * 0.5 * float(_wall_side) * k * k
	_sprite.frame = 1 if k < 0.55 else 2              # jump_02/03 공중 자세
	_apply_frame_offset()
	if k >= 1.0:
		_attach_wall()


## 벽에 닿는 순간 점프 클립 → 걷기 클립. 각도는 이미 ±90° 라 자세가 튀지 않는다
func _attach_wall() -> void:
	state = State.WALL
	_surface = Surface.WALL
	position = _wall_to
	_wall_t = 0.0
	_sprite.speed_scale = WALL_SPEED / WALK_ANIM_SPEED
	_sprite.play("walk")
	_set_surface_pose(-1.0)                           # 머리 위
	_punch(LAND_SQUASH)                               # 벽 쪽으로 찰싹 (로컬 y = 벽면 방향)
	_wall_dust()


## 벽·천장 공통 진행
func _process_wall(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_wall_t += delta
	if _surface == Surface.WALL:
		_climb(delta)
	else:
		_crawl_ceiling(delta)
	if state == State.WALL and _wall_t >= WALL_MAX_TIME:
		_start_fall()


## 벽을 타고 천장 밑까지 올라간 뒤 안쪽 코너로 넘어간다
func _climb(delta: float) -> void:
	var s := _solid()
	if s == null:
		_start_fall()
		return
	_wall_goal_y = _wall_top_y()
	if position.y > _wall_goal_y + 4.0:
		if not _sprite.is_playing():
			_sprite.play("walk")
		_set_surface_pose(-1.0)                      # 머리 위로 기어오른다
		position.y = maxf(position.y - WALL_SPEED * delta, _wall_goal_y)
		position.x = _wall_face_x(position.y)         # 계단으로 물러난 벽면도 따라간다
		return
	var ceil_y := s.open_top_at(position.x - float(_wall_side) * 20.0)
	var span := s.open_span_at(position.x - float(_wall_side) * 20.0, ceil_y + WALL_CLEAR)
	if span.y - span.x >= WALL_CLEAR * 2.5:
		_start_corner(ceil_y)
	else:
		_start_fall()


## 안쪽 코너: 접지점이 코너 점을 중심으로 방 안쪽으로 90° 돌고, 동시에 몸도 ±90° → ±180° 로 넘어간다.
## (오목한 코너라 접지점이 도는 방향과 몸이 도는 방향이 반대다 — 머리가 먼저 천장 밑으로 넘어가기 때문)
## 클립은 계속 walk — 코너를 도는 동안에도 다리는 논다.
func _start_corner(ceil_y: float) -> void:
	state = State.CORNER
	_corner_t = 0.0
	_corner_pivot = Vector2(position.x, ceil_y)
	_corner_from = position - _corner_pivot
	if not _sprite.is_playing():
		_sprite.play("walk")


func _process_corner(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_wall_t += delta
	_corner_t += delta
	var k := clampf(_corner_t / WALL_CORNER_TIME, 0.0, 1.0)
	position = _corner_pivot + _corner_from.rotated(float(_wall_side) * k * PI * 0.5)
	_sprite.rotation = -PI * 0.5 * float(_wall_side) * (1.0 + k)
	_apply_frame_offset()
	if k >= 1.0:
		_attach_ceiling()


## 코너를 다 돌면 그대로 180° 자세로 천장에 매달린다 (클립도 각도도 이어진다)
func _attach_ceiling() -> void:
	state = State.WALL
	_surface = Surface.CEILING
	_wall_hold = 0.0
	_wall_dir = -float(_wall_side)                    # 코너를 돌면 방 안쪽을 향한다
	_sprite.speed_scale = WALL_SPEED / WALK_ANIM_SPEED
	_sprite.play("walk")
	_set_surface_pose(_wall_dir)
	_punch(LAND_SQUASH)                               # 천장 쪽으로 눌림


## 천장을 기어 플레이어 머리 위까지 간 뒤 잠깐 노리다 덮친다. 가는 동안에도 사거리 안이면 아래로 뱉는다
func _crawl_ceiling(delta: float) -> void:
	var s := _solid()
	var t := _target()
	if s == null or t == null:
		_start_fall()
		return
	position.y = s.open_top_at(position.x)
	if _wall_hold > 0.0:
		_wall_hold -= delta
		_sprite.pause()                              # 발을 멈추고 노린다
		_squash += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * ROAR_TREMBLE * 0.6   # 덮치기 직전 떨림
		if _wall_hold <= 0.0:
			_start_fall()
		return
	if not _sprite.is_playing():
		_sprite.play("walk")
	var span := s.open_span_at(position.x, position.y + WALL_CLEAR)
	var half := _body_half_len()
	var lo := span.x + half
	var hi := span.y - half
	var dx := t.position.x - position.x
	if absf(dx) <= WALL_OVER_DIST or hi <= lo:
		_wall_hold = randf_range(WALL_HOLD.x, WALL_HOLD.y)
		_punch(Vector2(1.16, 0.86))
		return
	_wall_dir = signf(dx)
	_set_surface_pose(_wall_dir)
	var was := position.x
	position.x = clampf(position.x + _wall_dir * WALL_SPEED * delta, lo, hi)
	if absf(position.x - was) < WALL_SPEED * delta * 0.5:
		# 천장 단차에 막혀 더 못 간다 — 여기서 노리다 떨어진다
		_wall_hold = randf_range(WALL_HOLD.x, WALL_HOLD.y)
		_punch(Vector2(1.16, 0.86))
		return
	if _attack_cd <= 0.0 and absf(dx) <= ATTACK_MAX:
		_spit_from_wall(t)


## 벽·천장에 붙은 채로 뱉기 — 그 자세의 공격 그림이 없어 애니메이션 대신 반동만 준다
func _spit_from_wall(t: Node2D) -> void:
	_attack_cd = randf_range(ATTACK_COOLDOWN.x, ATTACK_COOLDOWN.y)
	_punch(Vector2(1.14, 0.90))
	var mouth := _pose_point(MOUTH_LOCAL)             # 바닥 자세와 같은 입 위치를 그대로 돌려 쓴다
	var glob := AcidGlob.new()
	glob.setup(mouth, t, floor_y, room)
	spat.emit(glob)


## 면에서 떨어져 나와 바닥까지 자유 낙하 — 바닥 클립(jump 공중 자세)으로 돌아온다
func _start_fall() -> void:
	state = State.FALL
	_surface = Surface.FLOOR
	_fall_vel = 0.0
	_air_y = 0.0
	_wall_timer = randf_range(WALL_INTERVAL.x, WALL_INTERVAL.y)
	var t := _target()
	facing = 1 if (t != null and t.position.x >= position.x) else -1
	_sprite.speed_scale = 1.0
	_sprite.play("jump")
	_sprite.pause()
	_sprite.frame = 2                                 # 공중 자세
	_sprite.rotation = 0.0
	_sprite.flip_h = facing < 0
	_sprite.flip_v = false
	_apply_frame_offset()
	_punch(Vector2(0.86, 1.18))


func _process_fall(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_fall_vel += FALL_GRAVITY * delta
	position.y += _fall_vel * delta
	if position.y < floor_y:
		return
	position.y = floor_y
	position.x = clampf(position.x, min_x, max_x)
	# 착지 뒤처리는 일반 점프와 같다 (jump_04 자세 유지 → IDLE)
	state = State.JUMP
	_jump_phase = 2
	_jump_t = 0.0
	_sprite.frame = 3
	_apply_frame_offset()
	_punch(LAND_SQUASH)
	_land_dust()


## 벽에 붙는 순간 벽면에서 튀는 먼지
func _wall_dust() -> void:
	var sb := _burst_node()
	sb.burst(position, 8, _pose_normal(), 0.7, Vector2(120, 300),
		Color(0.55, 0.52, 0.48), Color(0.35, 0.33, 0.3), Vector2(0.25, 0.5), 1800.0, 4.0, false)


func _burst_node() -> SparkBurst:
	if _sparks == null or not is_instance_valid(_sparks):
		_sparks = SparkBurst.spawn(get_parent(), floor_y, true)
		_sparks.z_index = 1
	return _sparks


## 총알 피격. point: 탄착 월드 좌표, dir: 탄 진행 방향(+1 왼→오),
## power: 위력 배율(1.0 플레이어 소총 · 2.0 센트리건) — 넉백·눌림·체액·육편이 모두 이 값에 비례한다.
func hit(point: Vector2, dir: float, power := 1.0) -> void:
	if state == State.DEAD:
		return
	hp -= 1
	_flash = 1.0
	_mat.set_shader_parameter("flash", HIT_FLASH_PEAK)
	_mat.set_shader_parameter("radius_px", HIT_FLASH_RADIUS)
	# 셰이더 UV 는 셀 전체 기준 (벽·천장이면 스프라이트 회전을 먼저 되돌리고, 뒤집힌 축은 반전)
	var cell_uv := ((point - position).rotated(-_sprite.rotation) / SCALE - _sprite.offset) / _cell
	if _sprite.flip_h:
		cell_uv.x = 1.0 - cell_uv.x
	if _sprite.flip_v:
		cell_uv.y = 1.0 - cell_uv.y
	_mat.set_shader_parameter("hit_uv", cell_uv.clamp(Vector2.ZERO, Vector2.ONE))
	_knock = HIT_KNOCKBACK * power
	_knock_rate = HIT_KNOCKBACK * power / KNOCK_TIME        # 세게 밀려도 같은 시간 안에 밀린다
	_knock_dir = signf(dir) if dir != 0.0 else -float(facing)
	# 스케일 펀치: 탄이 온 쪽이 눌리듯 옆으로 퍼진다 (위력이 크면 더 깊게)
	_punch(Vector2.ONE.lerp(HIT_PUNCH, power))
	# 독액 방울: 탄 진행 방향 뒤쪽 원뿔로 튄다 + 체액이 탄 방향으로 벽에 튄다
	var sb := _burst_node()
	sb.burst(point, int(9 * power), Vector2(-signf(dir), -0.6), 0.9, Vector2(140, 420) * power, ACID_HOT, ACID_COLD,
		Vector2(0.3, 0.7), 2000.0, 4.5 * (0.7 + 0.3 * power), false)
	sb.burst(point, int(7 * power), Vector2(signf(dir), -0.3), 0.7, Vector2(200, 520) * power, BLOOD_HOT, BLOOD_COLD,
		Vector2(0.25, 0.6), 2200.0, 3.5 * (0.7 + 0.3 * power), false, BLOOD_GLOW)
	# 큰 위력에는 살아 있어도 살점이 뜯겨 날아간다
	if power >= HIT_CHUNK_POWER:
		_spawn_chunks(point, dir, int(power), power)
	if room and room.has_method("add_stain"):
		room.add_stain(point + Vector2(signf(dir) * 30.0, 0.0), Vector2(signf(dir), -0.15), int(6 * power), 40.0 * power)
		# 가끔(35%, 위력에 비례) 체액이 탄 방향 벽면으로 부채꼴로 흩뿌려진다 — 덩어리가 순차적으로 찍히고 흘러내림
		if randf() < 0.35 * power and room.has_method("add_spray"):
			room.add_spray(point, Vector2(signf(dir), randf_range(-0.7, 0.1)), int(14 * power), 160.0 * power, 0.9)
	if hp <= 0:
		_die(dir, power)
	elif _off_floor():
		if state != State.FALL and randf() < WALL_KNOCK_OFF:
			_start_fall()                  # 벽에 붙은 채 맞으면 가끔 떨어진다
	elif state == State.IDLE:
		_idle_t = minf(_idle_t, 0.12)      # 맞으면 멈칫 시간을 줄여 바로 반응


func _die(dir: float, power := 1.0) -> void:
	# 벽·천장에서 죽으면 시체가 떨어진다 (죽음 클립은 바닥 자세뿐이라 바닥 스프라이트로 돌려놓는다)
	_dead_falling = _off_floor() and position.y < floor_y
	if not is_zero_approx(_sprite.rotation):
		var f := _pose_facing()                       # 돌아 있던 자세에서 바닥 기준 방향을 되찾는다
		if absf(f.x) > 0.3:
			facing = 1 if f.x > 0.0 else -1
		_sprite.rotation = 0.0
		_sprite.flip_h = facing < 0
	state = State.DEAD
	_surface = Surface.FLOOR
	_air_y = 0.0
	_fall_vel = 0.0
	_sprite.flip_v = false
	if _dead_falling:
		_knock = 0.0
	else:
		_knock = HIT_KNOCKBACK * 1.5 * power
		_knock_rate = _knock / KNOCK_TIME
	_corpse_t = 0.0
	_sprite.speed_scale = 1.0
	_sprite.play("death")
	_apply_frame_offset()
	_punch(Vector2.ONE.lerp(DEATH_PUNCH, power))
	var sb := _burst_node()
	var c := hit_center()
	# 독액 + 초록 체액이 사방으로 분출 (체액은 더 많이·굵게·오래)
	sb.burst(c, int(22 * power), Vector2(-signf(dir) * 0.4, -1.0), 1.1, Vector2(160, 560) * power, ACID_HOT, ACID_COLD,
		Vector2(0.45, 1.1), 2000.0, 5.0 * (0.7 + 0.3 * power), true)
	sb.burst(c, int(34 * power), Vector2(signf(dir) * 0.3, -0.8), PI, Vector2(220, 760) * power, BLOOD_HOT, BLOOD_COLD,
		Vector2(0.5, 1.3), 2300.0, 6.0 * (0.7 + 0.3 * power), false, BLOOD_GLOW)
	# 육편: 현재 프레임 텍스처를 조각내 사방으로 날린다
	_spawn_chunks(c, dir, CHUNK_COUNT, power)
	# 벽에 큰 체액 자국 (탄 방향으로 길게) + 바닥 쪽 작은 자국
	if room and room.has_method("add_stain"):
		room.add_stain(c + Vector2(signf(dir) * 40.0, -10.0), Vector2(signf(dir), -0.2), int(22 * power), 110.0 * power)
		room.add_stain(Vector2(position.x, floor_y - 6.0), Vector2(signf(dir), 0.0), int(8 * power), 70.0 * power)
		# 죽을 때는 대개(75%) 넓게 분사 — 탄 방향으로 위쪽 부채꼴, 멀리까지
		if randf() < 0.75 * power and room.has_method("add_spray"):
			room.add_spray(c, Vector2(signf(dir), -0.35), int(26 * power), 280.0 * power, 1.3)
	died.emit(position)


## 현재 프레임의 내용 영역을 CHUNK_CELL 격자로 나눠 그중 count 조각을 ChunkDebris 로 날린다 (power 만큼 더 멀리)
func _spawn_chunks(center: Vector2, dir: float, count := CHUNK_COUNT, power := 1.0) -> void:
	var b := _bbox_cell()
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
	for i in range(mini(count, cells.size())):
		var region: Rect2 = cells[i]
		# 조각의 월드 위치 (뒤집힌 축은 셀 중심 기준 반전)
		var local := region.get_center()
		if _sprite.flip_h:
			local.x = _cell.x - local.x
		if _sprite.flip_v:
			local.y = _cell.y - local.y
		var world := position + ((_sprite.offset + local) * SCALE).rotated(_sprite.rotation)
		# 피격당한 쪽 반대편(탄 진행 방향)으로 튄다 — 부채꼴로 조금 퍼지고, 위로도 솟는다
		var fwd := Vector2(signf(dir), 0.0).rotated(randf_range(-0.55, 0.55))
		var away := (world - center)
		away = away.normalized() if away.length() > 1.0 else Vector2(0, -1)
		var vel := fwd * randf_range(380.0, 820.0) + away * randf_range(40.0, 140.0) \
			+ Vector2(0, -randf_range(200.0, 560.0))
		var chunk := ChunkDebris.new()
		chunk.setup(tex, region, world, vel, floor_y)
		chunk.scale = Vector2(SCALE, SCALE)
		chunk.rotation = _sprite.rotation             # 몸에 붙어 있던 방향 그대로 떨어져 나간다
		chunk.flip_h = _sprite.flip_h
		chunk.z_index = 1
		parent.add_child(chunk)


func _process_dead(delta: float) -> void:
	if _dead_falling:
		_fall_vel += FALL_GRAVITY * delta
		position.y += _fall_vel * delta
		if position.y >= floor_y:
			position.y = floor_y
			position.x = clampf(position.x, min_x, max_x)
			_dead_falling = false
			_punch(LAND_SQUASH)
			_land_dust()
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
