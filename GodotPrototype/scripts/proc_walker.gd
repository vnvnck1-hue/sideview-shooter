class_name ProcWalker
extends Node2D
## 절차적 사족보행 로봇 (2026-09-21). **몸체만 움직이면 네 다리가 스스로 자리를 잡는다.**
##
## 구조(그레이박스): 몸체(청회색 상자) · 관절(보라 원) · 허벅지(핑크 막대) · 정강이(노랑 막대).
## 전용 그림이 없어도 되도록 전부 _draw 로 그린다 — 랩에서 보폭·관절 길이를 확정한 뒤에 그림을 자르기 위해서다.
## (먼저 그림을 뽑아 놓고 수치를 맞추면 이음매·길이가 안 맞아 다시 뽑게 된다. 센트리건 파츠 분리가 그 자리였다.)
##
## 세 덩어리로 되어 있다.
##   1) 다리 풀기 — **정강이(노랑)를 거의 수직으로 유지한다** (관절마다 자이로가 달린 것처럼).
##                 무릎은 발 바로 위에 두고, 남는 차이는 허벅지(핑크)가 길이를 바꿔 흡수한다 —
##                 유압 스트럿으로 그린다. 2본 IK 는 정강이 각이 크게 휘둘려 쓰지 않는다.
##   2) 지면 질의 — ground_at(x) → 그 x 의 바닥 y. 물리 레이캐스트를 쓰지 않는다.
##                 본편은 RoomSolid 가 열별 바닥선을 이미 들고 있으므로 그걸 그대로 물려 주면 된다.
##   3) 스텝 로직 — 발은 월드에 **박혀 있다가**, 몸에서 너무 멀어지면(또는 닿을 수 없게 되면) 새 자리로
##                 포물선을 그리며 옮겨 붙는다. 대각선 두 다리가 한 조로 움직이고(트롯),
##                 한 조가 떠 있는 동안 다른 조는 절대 뜨지 않는다 — 이것만 지키면 걸음이 무너지지 않는다.
##
## 측면뷰라 다리는 4개가 아니라 **먼 쌍 / 가까운 쌍 2세트**만 그린다(DepthLayers 규격대로 먼 쪽을 어둡게).
## 대각 조는 "앞·먼 + 뒤·가까" / "앞·가까 + 뒤·먼" 으로 묶인다 — 실제 사족의 대각보와 같다.
##
## 쓰는 쪽에서 할 일: ground_at 을 꽂고, 매 프레임 input_dir / running / drag_to 를 채운 뒤 tick(delta) 를 부른다.
## 입력을 직접 읽지 않는다 — 랩에서도 본편에서도 같은 코드를 쓰기 위해서다.

## ── 그림 규격 ────────────────────────────────────────────────────────────────
const BODY_HALF_W := 130.0        # 몸체 좌우 반폭
const BODY_TOP := -160.0          # 몸체 윗면 (원점 = 고관절 줄 한가운데)
const BODY_BOT := 62.0            # 몸체 아랫면
const BODY_SKIRT := 8.0           # 아랫면의 어두운 띠 시작 높이

## 다리는 2본 IK 가 아니다. **정강이(노랑)를 거의 수직으로 유지한다** — 관절마다 자이로가 달린 것처럼.
##
## IK 로 풀면 정강이 각이 걸음마다 크게 휘둘려 어색하다. 대신 이렇게 푼다:
##   1) 무릎 = 발에서 SHIN_LEN 위. 정강이는 **바깥으로 SHIN_SPLAY 만큼 벌린 각**을 기준으로 삼고
##      거기서 ±SHIN_TILT_MAX 안에서만 움직인다 (무릎보다 발이 바깥 — 거미 다리)
##   2) 허벅지(핑크) = 고관절~무릎. **길이가 변한다** — 유압 스트럿으로 그린다
##
## 왜 허벅지가 늘어나야 하는가: 무릎이 발 바로 위에 묶이면 무릎도 발을 따라 앞뒤로 움직인다.
## 두 마디가 모두 강체이면 다리의 자유도가 0 이 되어 발이 아예 못 움직인다.
## 즉 **정강이를 수직으로 묶는 순간 보폭은 허벅지 길이 변화가 흡수할 수밖에 없다.** 기하학적 결론이다.
## 정강이 기울기가 그 일부를 나눠 받는다 (±17° × 150 ≈ ±44px).
const SHIN_LEN := 150.0           # 노랑 막대 (무릎 → 발). 2026-09-21: 188 → 150 (20% 단축)
## 정강이의 **기준 각** — 수직에서 바깥쪽(몸 반대 방향)으로 이만큼 눕힌다. 무릎보다 발이 바깥으로 나가
## 거미처럼 벌린 다리가 된다. 0 이면 수직.
const SHIN_SPLAY := 0.26          # rad ≈ 15°
const SHIN_TILT_MAX := 0.20       # rad ≈ 11°. **기준 각에서** 더 벗어날 수 있는 폭
const THIGH_MIN := 34.0           # 스트럿이 줄어들 수 있는 최소 길이
const THIGH_MAX := 230.0          # 스트럿이 늘어날 수 있는 최대 길이 = **다리의 도달 한계**
const LEASH_SCAN := 320.0         # 닿는 발자리를 찾아 훑는 좌우 범위 (px)
const SLEEVE_LEN := 74.0          # 유압 슬리브(고정 길이 바깥통). 이 밖으로 나온 만큼이 로드다
const THIGH_W := 56.0
const SHIN_W := 50.0
const HIP_R := 26.0               # 고관절 원
const KNEE_R := 32.0              # 무릎 원
## 느슨한 상한 — 검증·공중 자세가 참고한다. 실제 한계는 THIGH_MAX 다
const MAX_REACH := THIGH_MAX + SHIN_LEN
## ── 비례 규칙 (여기를 어기면 걸음이 통째로 무너진다) ──────────────────────────
## 발이 몸통 기준으로 오가는 폭은 대략
##     rest_x - trigger + lead×v   ~   rest_x + lead×v      (v = 최고 속도)
## 이고, 그 끝에서의 고관절~발 거리가 MAX_REACH×0.97 을 넘으면 안 된다.
## 넘으면 정상 보폭 판정(trigger)보다 **도달 한계가 먼저 와서**, 걸음이 전부 "긴급 스텝" 으로 나고
## 접지 유지·대각 규칙 같은 제동이 죄다 무시된다 — 네 발이 늘 허둥대는 그 증상이다.
## (tools/validate_walker.gd 가 "걸음 계기: 정상 / 긴급" 으로 이걸 감시한다)
##
## **묶이는 쪽은 뒷다리의 뒤쪽 끝**이다. 뒷발의 뒤로 갈 수 있는 여유는
##     room = sqrt((MAX_REACH×0.97)² - 고관절높이²) - (|rest| - |hip|)
##     여유 = sqrt((MAX_REACH×0.97)² - (고관절높이 + bob)²) - (|rest|×stride - |hip|)
##     필요 = trigger + hold × 최고속도 + 잔여(약 10px)
## hold 를 빼먹으면 안 된다 — 접지 유지가 정상 스텝을 막는 동안에도 발은 계속 뒤로 밀리므로,
## 그만큼이 trigger 위에 얹힌다. (이걸 빠뜨려 두 번 헛짚었다.)
##
## 확정값(2026-09-21, 랩에서 직접 맞춘 값) 기준 — 빠른 트롯:
##   한 주기 = 2 × (0.05 + 0.15) = 0.40초 · 밀리는 거리 = 430 × 0.40 = 172
##   lead 0.20 = 주기의 절반 → 발이 오가는 구간이 rest 에 가운데로 맞는다 (여유 최대)
##   묶이는 곳: 앞·가까 다리 앞쪽 → 스트럿 151 < 230.  여유 79px — 넉넉하다.
##
## 선 자세에서 고관절~발 거리는 MAX_REACH 의 0.75~0.8 사이여야 한다.
##   0.85 이상 — 무릎이 거의 펴진 채라 몸이 조금만 앞서도 발이 도달 거리 밖으로 밀려난다
##   0.7 이하  — 무릎이 너무 접혀 허벅지가 옆으로 눕고, 다리가 게처럼 벌어진 실루엣이 된다
## 확정값: 먼 쌍 sqrt(135² + 132²) = 189 / 280 ≈ 0.68 — 아래 권장 범위보다 접힌 자세다.
## 랩에서 눈으로 고른 값이고 그쪽이 이 로봇답게 보여서 그대로 둔다 (허벅지가 옆으로 눕는 실루엣).

const C_BODY := Color(0.573, 0.737, 0.765)
const C_BODY_DARK := Color(0.408, 0.549, 0.588)
const C_JOINT := Color(0.518, 0.518, 0.878)
const C_THIGH := Color(0.902, 0.549, 0.784)
const C_THIGH_ROD := Color(0.70, 0.38, 0.60)   # 슬리브 밖으로 나온 로드 (조금 어둡게)
const C_SHIN := Color(0.851, 0.761, 0.369)
const FAR_MUL := 0.62             # 먼 쌍을 어둡게 (DepthLayers 의 층 분리와 같은 취지)
const FAR_RAISE := 16.0           # 먼 쌍의 발을 이만큼 위로 **그린다** (판정은 그대로).
                                  # 측면뷰에서 두 쌍이 같은 줄에 붙으면 다리가 둘로만 보인다

## ── 다리 배치 ────────────────────────────────────────────────────────────────
## hip  : 몸체 로컬 고관절 위치 (x 는 바라보는 쪽이 +). **몸통 양 끝**에 붙인다 —
##        가운데로 몰면 허벅지가 배를 가로질러, 다리가 배 밑에 매달린 벌레 같은 실루엣이 된다
## rest : 가만히 섰을 때 발이 놓이는 몸체 기준 x. **고관절 바로 아래에 가깝게** 둔다.
##        벌릴수록 보기에는 듬직하지만, 벌린 만큼 뒷발의 뒤쪽 여유가 그대로 깎인다 —
##        뒷발은 rest 가 이미 뒤에 있는데 몸이 앞서며 더 뒤로 밀려, 두 성분이 더해지기 때문이다.
##        (rest 를 ±258 로 벌렸을 때 걸음 106 개 중 101 개가 긴급 스텝으로 났다)
## group: 대각 조 (0 / 1)
const LEGS := [
	{"name": "뒤·먼", "hip": Vector2(-132.0, 40.0), "rest": -162.0, "near": false, "group": 1},
	{"name": "앞·먼", "hip": Vector2(132.0, 40.0), "rest": 162.0, "near": false, "group": 0},
	{"name": "뒤·가까", "hip": Vector2(-118.0, 50.0), "rest": -150.0, "near": true, "group": 0},
	{"name": "앞·가까", "hip": Vector2(118.0, 50.0), "rest": 150.0, "near": true, "group": 1},
]

## ── 기관총 (몸통 위 포탑) ────────────────────────────────────────────────────
## 센트리건(sentry_turret.gd)과 같은 규칙: 포인터를 **기계식 선회 속도로 늦게** 따라간다.
## 즉시 조준하면 기계 느낌이 죽고, 마우스를 휘두를 때 포신이 순간이동한다.
## 포탑은 바라보는 쪽 기준 ±TURRET_ARC 안에서만 돈다 — 그 밖을 겨누면 **몸이 돌아선다**(facing 전환).
const TURRET_PIVOT := Vector2(-14.0, -196.0)  # 몸체 로컬 요동축 — 몸통 **위**에 올려 둔다 (x 는 바라보는 쪽이 +)
const BARREL_LEN := 178.0
const BARREL_W := 46.0
const MOUNT_R := 42.0
const TURRET_ARC := 2.60                      # rad ≈ 149°. 바라보는 쪽 기준 위아래 한계.
                                              # 넓게 잡을수록 몸을 덜 돌려도 되고, 몸을 덜 돌릴수록 다리가 덜 꼬인다
const TURRET_RATE := 8.5                      # rad/s — 선회 속도 (작을수록 굼뜬 기계)
const FIRE_COOLDOWN := 0.11
const TURN_BEHIND := 160.0                    # 조준점이 몸보다 이만큼 뒤에 있어야 돌아선다 (경계에서 떨지 않게)
const TURN_COOLDOWN := 0.5                    # 한 번 돌아서면 이만큼은 다시 돌지 않는다.
                                              # 없으면 조준이 몸을 가로지를 때마다 뒤집히며 다리가 꼬여 주저앉는다
const RECOIL_BACK := 30.0                     # 포신이 뒤로 물러나는 최대 거리
const RECOIL_DECAY := 12.0
const RECOIL_PUSH := 7.0                      # 사격 반동으로 몸이 밀리는 거리 (다리가 받아낸다)
const FLASH_TIME := 0.05
const C_GUN := Color(0.30, 0.42, 0.46)
const C_GUN_LIT := Color(0.46, 0.60, 0.63)
const C_FLASH := Color(1.0, 0.93, 0.62)

## ── 이동 ────────────────────────────────────────────────────────────────────
## 이 로봇은 무겁다. 빠르면 발을 내려놓자마자 다시 떼야 해서 네 발이 다 붙는 순간이 사라지고
## 늘 두 발이 떠 있는 "허둥대는" 걸음이 된다 (첫 촬영에서 30 프레임 내내 그랬다).
## 최고 속도는 tune["speed"] 에 있다 — 걸음 타이밍(hold·step_time)과 한 몸이라 따로 둘 수 없다.
const RUN_MUL := 1.7
const ACCEL := 2200.0
const FRICTION := 2800.0
const JUMP_V := 900.0
const GRAVITY := 2200.0
const TURN_SPEED := 40.0          # 이 속도를 넘겨야 방향을 바꾼다 (제자리 떨림 방지)
const SPEED_CAP := 900.0          # 발 목표 예측(lead)에 쓰는 속도의 상한 — 마우스로 끌 때 폭주 방지
const GROUND_CLEAR := 60.0        # 몸체가 지면 위로 최소한 띄워야 하는 높이
const FALL_SLACK := 80.0          # 몸 밑 지면이 선 키보다 이만큼 더 아래면 떨어진다 (발판 이탈 판정)

## ── 튜닝값 (랩에서 키로 고친다. 확정되면 여기 기본값을 고쳐 적는다) ────────────
const DEFAULTS := {
	"speed": 430.0,       # 최고 걷기 속도(px/s). 달리기는 × RUN_MUL.
	                      # 걸음 타이밍이 정해지면 이 값도 따라 정해진다 — "여유 예산" 을 보고 맞출 것
	"ride": 135.0,        # 지면에서 몸체 원점까지 (다리를 얼마나 펴고 서는가)
	"stride": 1.18,       # **다리 벌림** — LEGS.rest 에 곱한다. 보폭이 아니다 (보폭은 trigger)
	"trigger": 40.0,      # 발이 제자리에서 이만큼 어긋나면 새 자리로 옮긴다 (= 한 걸음 거리)
	"lift": 80.0,        # 발을 드는 높이 (포물선 꼭대기)
	"step_time": 0.15,    # 한 걸음에 걸리는 시간 (속도가 붙으면 이보다 짧아진다)
	"lead": 0.20,         # 예측 — 속도 × 이 값만큼 앞쪽에 발을 내려놓는다. 0 이면 늘 뒤처져 보인다
	"tilt": 0.00,         # 앞뒤 발 높이차를 몸 기울기에 반영하는 정도 (0 = 경사에서도 몸통을 수평으로)
	"bob": 26.0,          # 걸을 때 몸이 오르내리는 폭. 이게 크면 고관절 높이가 그만큼 흔들려
	                      # 뒷발의 여유를 깎는다 — 위 "여유 예산" 에 들어가는 값이다
	"hold": 0.05,         # **네 발이 다 붙은 뒤 이만큼은 그대로 딛고 있는다.** 이게 0 이면 한 조가 내려앉는
	                      # 순간 다른 조가 곧바로 떠서, 네 발이 다 붙는 순간이 없는 허둥대는 걸음이 된다.
	                      # 닿을 수 없게 된 발은 이 규칙을 건너뛴다 — 빨리 달리면 자연히 트롯으로 넘어간다.
	"aim_lean": 0.12,     # 조준 각을 몸 기울기에 얼마나 옮기는가 (rad, 최대 부앙에서). 0 이면 몸통은 가만히 있는다
	"legs_up": 2.0,       # **한 번에 뜰 수 있는 발 수 (1 또는 2).** 걸음새를 가르는 진짜 손잡이다.
	                      #   2 — 대각 두 발이 함께 뜬다. 말처럼 통통 뛰는 트롯
	                      #   1 — 한 발씩만 뜬다. 늘 세 발이 땅에 붙어 있다 — 거미처럼 사각사각
	                      # (예전엔 "pair"(짝 따라뜨기 문턱)를 뒀는데, 같은 조 두 다리는 대칭이라
	                      #  늘 동시에 때가 되어 문턱과 무관하게 함께 떴다 — 측정해 보니 값을 0 으로 두든
	                      #  1 로 두든 두 발이 뜬 시간이 83~88% 로 같았다. 아무 일도 하지 않는 손잡이였다.)
}
const LEAN := 0.045       # 속도에 따라 몸이 진행 방향으로 기우는 양 (rad, 최대 속도에서)
## 몸이 기울 수 있는 한계(rad ≈ 20°). 너무 작게 잡으면 경사에서 몸이 수평을 고집하는 대신
## **다리가 그 각도 차이를 전부 떠안아** 뒷발이 도달 한계 밖으로 밀려난다 (0.23 일 때 그랬다).
## 반대로 한계가 없으면 급경사에서 넘어가는 그림이 된다.
const TILT_MAX := 0.35

## 지면 질의: func(x: float) -> float. 꽂지 않으면 y=0 평지.
var ground_at: Callable = func(_x: float) -> float: return 0.0

## 총을 쐈다. muzzle = 총구 월드 좌표 · dir = 발사 방향(단위 벡터). 탄·예광·피격은 쓰는 쪽이 만든다.
signal fired(muzzle: Vector2, dir: Vector2)

## 매 프레임 쓰는 쪽이 채워 넣는 값
var input_dir := 0.0              # -1 / 0 / +1
var running := false
var drag_to = null                # Vector2 를 넣으면 몸체를 그 자리로 끌고 간다 (마우스로 직접 잡기)
var aim_target = null             # Vector2(월드) 를 넣으면 그 점을 겨눈다. null 이면 정면을 본다
var firing := false               # true 인 동안 FIRE_COOLDOWN 간격으로 발사한다

var tune := DEFAULTS.duplicate()
var body_pos := Vector2.ZERO
var facing := 1
var speed := 0.0                  # 현재 수평 속도 (부호 있음)
var airborne := false

var _legs: Array = []
var _angle := 0.0
var _air_v := 0.0
var _walked := 0.0                # 누적 이동 거리 — 몸 상하 진동(bob)의 위상
var _all_down := 0.0              # 네 발이 모두 붙어 있은 시간 (초). tune.hold 가 이걸 본다
var _turret := 0.0                # 포신의 **월드** 각 (몸 기울기와 무관하게 절대각으로 관리한다)
var _recoil := 0.0
var _fire_cd := 0.0
var _flash := 0.0
var _aim_pitch := 0.0             # -1(아래) ~ +1(위) — 몸이 조준을 따라 젖히는 정도
var _turn_cd := 0.0               # 방향 전환 제동 (초)

## 진단용 집계 — 걸음이 무엇 때문에 났는가. urgent 가 대부분이면 다리 길이/보폭 비례가 잘못된 것이다
## (정상 판정(trigger)보다 도달 한계가 먼저 와서, 접지 유지 같은 제동이 전부 무시된다)
var steps_normal := 0
var steps_urgent := 0


func _ready() -> void:
	reset_stance()


## 현재 몸체 위치를 기준으로 네 발을 제자리에 내려놓는다 (씬 시작 · Z 초기화 · 착지 직후)
func reset_stance() -> void:
	_legs.clear()
	for d in LEGS:
		var leg := {
			"name": d["name"], "hip": d["hip"] as Vector2, "rest": d["rest"] as float,
			"near": d["near"] as bool, "group": d["group"] as int,
			"foot": Vector2.ZERO, "from": Vector2.ZERO, "to": Vector2.ZERO,
			"t": 0.0, "dur": 0.2, "stepping": false,
		}
		leg["foot"] = _desired(leg, 0.0)
		_legs.append(leg)
	_sync_body_to_feet(1.0)
	position = body_pos
	rotation = _angle
	queue_redraw()


func jump() -> void:
	if airborne:
		return
	airborne = true
	_air_v = -JUMP_V


## 한 프레임. 쓰는 쪽이 input_dir / running / drag_to 를 채운 뒤 부른다.
func tick(delta: float) -> void:
	_tick_turret(delta)                     # 몸이 움직이기 전에 — 조준이 방향 전환(facing)을 정한다
	_move_body(delta)
	_tick_legs(delta)
	if not airborne:
		_sync_body_to_feet(delta * 13.0)
	_leash_feet()                           # 몸 자세가 확정된 뒤에 — 그래야 한 박자 늦지 않는다
	position = body_pos
	rotation = _angle
	queue_redraw()


# ── 기관총 ───────────────────────────────────────────────────────────────────

## 요동축의 월드 좌표. 몸 기울기를 같이 받는다.
func turret_pivot() -> Vector2:
	return body_pos + Vector2(TURRET_PIVOT.x * float(facing), TURRET_PIVOT.y).rotated(_angle)


## 총구의 월드 좌표 (반동만큼 물러난 위치)
func muzzle() -> Vector2:
	return turret_pivot() + Vector2.RIGHT.rotated(_turret) * (BARREL_LEN - _recoil)


func aim_dir() -> Vector2:
	return Vector2.RIGHT.rotated(_turret)


func _tick_turret(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, RECOIL_DECAY * RECOIL_BACK * delta)
	_flash = maxf(_flash - delta, 0.0)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_turn_cd = maxf(_turn_cd - delta, 0.0)

	var pivot := turret_pivot()
	var want := 0.0 if facing > 0 else PI
	if aim_target != null:
		var to: Vector2 = (aim_target as Vector2) - pivot
		if to.length() > 1.0:
			want = to.angle()
			# 포탑이 닿지 않는 뒤쪽을 겨누면 **몸이 돌아선다**. 경계에서 떨지 않게 여유와 제동을 둔다.
			var behind: float = (aim_target as Vector2).x - body_pos.x
			var want_face := 1 if behind > 0.0 else -1
			if absf(behind) > TURN_BEHIND and want_face != facing and _turn_cd <= 0.0:
				facing = want_face
				_turn_cd = TURN_COOLDOWN
				_all_down = tune["hold"]     # 돌아선 직후엔 접지 유지를 건너뛴다 — 네 발이 빨리 제자리를 찾게
	# 바라보는 쪽 기준 ±TURRET_ARC 로 묶는다
	var base := 0.0 if facing > 0 else PI
	var off := wrapf(want - base, -PI, PI)
	want = base + clampf(off, -TURRET_ARC * 0.5, TURRET_ARC * 0.5)
	_turret = _rotate_toward(_turret, want, TURRET_RATE * delta)

	# 몸이 조준을 따라 젖힌다 — 위를 겨누면 앞이 들리고, 아래를 겨누면 앞이 숙는다.
	# 다리가 이 변화를 받아내는 것이 절차적 보행의 값어치가 드러나는 자리다.
	var elev := wrapf(_turret - base, -PI, PI) * float(facing)
	_aim_pitch = clampf(elev / (TURRET_ARC * 0.5), -1.0, 1.0)

	if firing and _fire_cd <= 0.0:
		_fire_cd = FIRE_COOLDOWN
		_recoil = RECOIL_BACK
		_flash = FLASH_TIME
		var d := aim_dir()
		body_pos -= d * RECOIL_PUSH        # 반동으로 밀린다. 다리가 알아서 자리를 다시 잡는다
		fired.emit(muzzle(), d)


static func _rotate_toward(from: float, to: float, step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if absf(diff) <= step:
		return to
	return from + signf(diff) * step


# ── 몸체 ─────────────────────────────────────────────────────────────────────

func _move_body(delta: float) -> void:
	if drag_to != null:
		# 마우스로 직접 잡아끄는 중 — 속도는 실제 이동량에서 뽑는다 (예측 발 놓기가 그대로 동작하도록)
		var target: Vector2 = drag_to
		var prev := body_pos
		body_pos = body_pos.lerp(target, clampf(delta * 22.0, 0.0, 1.0))
		# 몸을 지면 밑으로는 끌고 갈 수 없다 (마우스를 바닥 아래로 내려도 다리가 땅을 뚫지 않게)
		body_pos.y = minf(body_pos.y, ground_at.call(body_pos.x) - GROUND_CLEAR)
		# 속도는 **제한한다**. 마우스를 휘두르면 한 프레임 이동량이 수천 px 이 되고,
		# 그 값이 lead(예측)에 그대로 곱해져 발 목표가 화면 밖으로 날아간다.
		speed = clampf((body_pos.x - prev.x) / maxf(delta, 0.0001), -SPEED_CAP, SPEED_CAP)
		airborne = false
		_air_v = 0.0
		_walked += absf(body_pos.x - prev.x)
		_update_facing()
		return

	var top: float = tune["speed"] * (RUN_MUL if running else 1.0)
	if absf(input_dir) > 0.01:
		speed = move_toward(speed, top * signf(input_dir), ACCEL * delta)
	else:
		speed = move_toward(speed, 0.0, FRICTION * delta)
	body_pos.x += speed * delta
	_walked += absf(speed) * delta
	_update_facing()

	# **발판 끝을 넘어서면 떨어진다.** 몸 높이는 발에서 뽑기 때문에, 뒷발이 아직 단 위에 붙어 있으면
	# 몸이 허공으로 걸어 나가도 그대로 떠 있었다 — 그 상태에서는 앞다리가 닿을 지면이 없어
	# "스트럿이 한계를 넘었다" 로만 잡혔다 (절벽 위에서 프레임마다 7px 씩 늘어났다).
	# 몸 밑 지면이 선 키보다 한참 아래면 그냥 떨어뜨린다. 착지는 기존 경로가 받는다.
	if not airborne and ground_at.call(body_pos.x) - body_pos.y > tune["ride"] + FALL_SLACK:
		airborne = true
		_air_v = 0.0

	if airborne:
		_air_v += GRAVITY * delta
		body_pos.y += _air_v * delta
		# 착지 판정은 **몸 밑의 지면**으로 본다. 뜬 동안 다리를 접으므로 발 평균 높이(_support_y)를
		# 쓰면 접힌 발 높이만큼 공중에서 멈춰 버린다.
		var land: float = ground_at.call(body_pos.x) - tune["ride"]
		if _air_v > 0.0 and body_pos.y >= land:
			body_pos.y = land
			airborne = false
			_air_v = 0.0
			_plant_feet()


## 착지 순간 네 발을 **그 자리 지면에 바로 박는다.**
## 뜬 동안엔 다리를 접어 두는데(_tuck_feet), 착지를 일반 스텝 규칙에 맡기면 접지 유지·대각 규칙에 걸려
## 다리가 펴지기까지 몇 프레임이 걸린다 — 그동안 로봇이 공중에 선 것처럼 보인다.
## 착지는 한 순간에 쿵 하고 끝나야 하므로 여기서만 예외로 네 발을 동시에 놓는다.
func _plant_feet() -> void:
	for leg in _legs:
		var want := _reachable(leg, _desired(leg, speed))
		want.y = ground_at.call(want.x)
		# _reachable 은 **발을 내려놓을 시점의** 고관절로 검사한다 (스윙에 시간이 걸리므로).
		# 착지 배치는 그 자리에서 끝나므로 **지금의** 고관절로 다시 잘라야 한다 —
		# 안 그러면 빠를수록 예측한 만큼 어긋나 착지 직후 몇 프레임 스트럿이 넘친다.
		var hip := _hip_world(leg)
		var p0 := _phi0(leg)
		var guard := 0
		while strut_for(hip, want, p0) > THIGH_MAX * 0.93 and guard < 60:
			want.x = move_toward(want.x, hip.x, 6.0)
			want.y = ground_at.call(want.x)
			guard += 1
		leg["foot"] = want
		leg["stepping"] = false
		leg["t"] = 0.0
	_all_down = 0.0


func _update_facing() -> void:
	if speed > TURN_SPEED:
		facing = 1
	elif speed < -TURN_SPEED:
		facing = -1


## 딛고 있는 발들의 평균 높이 (없으면 네 발 평균)
func _support_y() -> float:
	var sum := 0.0
	var n := 0
	for leg in _legs:
		if not leg["stepping"]:
			sum += (leg["foot"] as Vector2).y
			n += 1
	if n == 0:
		for leg in _legs:
			sum += (leg["foot"] as Vector2).y
			n += 1
	return sum / float(n)


## 몸체 높이·기울기를 발 위치에서 뽑는다. 다리가 몸을 따라가는 게 아니라 **몸이 발을 따라간다**.
func _sync_body_to_feet(w: float) -> void:
	var k := clampf(w, 0.0, 1.0)
	var bob: float = sin(_walked / maxf(tune["stride"] * 210.0, 1.0) * TAU) * tune["bob"]
	body_pos.y = lerpf(body_pos.y, _support_y() - tune["ride"] + bob, k)
	# 몸 높이는 발에서 뽑지만, 발이 뒤처진 급경사에서는 그 값이 몸 밑 지면보다 낮아진다 (빠를수록 심하다).
	# 몸체가 바닥을 뚫는 그림은 어떤 경우에도 안 되므로 여기서 잘라 둔다.
	body_pos.y = minf(body_pos.y, ground_at.call(body_pos.x) - GROUND_CLEAR)

	# 앞발들과 뒷발들의 무게중심을 이은 선 — 경사에서 몸이 지면을 따라 눕는다.
	# **딛고 있는 발만** 센다. 든 발은 lift 만큼 떠 있어서 같이 세면 걸음마다 몸이 들썩인다.
	var fs := Vector2.ZERO
	var fn := 0
	var bs := Vector2.ZERO
	var bn := 0
	for leg in _legs:
		if leg["stepping"]:
			continue
		var f: Vector2 = leg["foot"]
		if (leg["rest"] as float) * float(facing) > 0.0:
			fs += f
			fn += 1
		else:
			bs += f
			bn += 1
	var slope := 0.0
	if fn > 0 and bn > 0:
		var fc := fs / float(fn)
		var bc := bs / float(bn)
		# 앞뒤 무게중심이 충분히 벌어져 있을 때만 각을 잰다. 방향을 바꾸는 순간엔 앞뒤 역할이 뒤바뀌며
		# 이 간격이 0 에 가까워지는데, 그때 atan2 를 쓰면 기울기가 한 번에 튄다 (전환 때 몸이 홱 꺾였다).
		if absf(fc.x - bc.x) > 80.0:
			slope = atan2(fc.y - bc.y, fc.x - bc.x) if facing > 0 else atan2(bc.y - fc.y, bc.x - fc.x)
		else:
			slope = _angle
	else:
		slope = _angle                       # 한쪽이 다 떠 있는 순간엔 각을 흔들지 않고 그대로 둔다
	var lean: float = clampf(speed / maxf(tune["speed"], 1.0), -1.5, 1.5) * LEAN
	# 조준 방향으로 몸을 젖힌다 (위를 겨누면 앞이 들린다). facing 을 곱해 좌우가 뒤집히지 않게.
	var aim_lean: float = -_aim_pitch * tune["aim_lean"] * float(facing)
	var want := clampf(slope * tune["tilt"] + lean + aim_lean, -TILT_MAX, TILT_MAX)
	_angle = lerp_angle(_angle, want, k)


# ── 다리 ─────────────────────────────────────────────────────────────────────

## 이 다리가 지금 놓여야 할 자리 (몸체 위치 + 벌어짐 + 예측) 를 지면에 붙인 값
func _desired(leg: Dictionary, vel: float) -> Vector2:
	var x: float = body_pos.x + (leg["rest"] as float) * tune["stride"] * float(facing) + vel * tune["lead"]
	return Vector2(x, ground_at.call(x))


func _tick_legs(delta: float) -> void:
	for leg in _legs:
		if leg["stepping"]:
			leg["t"] = (leg["t"] as float) + delta / maxf(leg["dur"] as float, 0.01)
			if (leg["t"] as float) >= 1.0:
				leg["foot"] = leg["to"]
				leg["stepping"] = false
			else:
				var t: float = leg["t"]
				var e := t * t * (3.0 - 2.0 * t)                 # 부드럽게 출발·착지
				var p: Vector2 = (leg["from"] as Vector2).lerp(leg["to"] as Vector2, e)
				p.y -= sin(t * PI) * tune["lift"]                # 포물선으로 들어 올린다
				leg["foot"] = p

	if airborne:
		_air_legs(delta)                                         # 올라갈 땐 접고, 내려올 땐 착지 자리로 뻗는다
		_all_down = 0.0
		return

	# 네 발이 다 붙어 있은 시간 — 걸음을 가라앉히는 근거
	var flying := 0
	for leg in _legs:
		if leg["stepping"]:
			flying += 1
	_all_down = _all_down + delta if flying == 0 else 0.0

	# 어긋남이 가장 큰 다리부터 검사한다 — 가장 급한 발이 먼저 나간다
	var order: Array = []
	for i in range(_legs.size()):
		if not _legs[i]["stepping"]:
			# 닿을 수 없게 된 발은 어긋남과 무관하게 맨 앞으로 — 이 발을 미루면 다리가 땅에서 떨어져 보인다
			var urgent := 100000.0 if _out_of_reach(_legs[i]) else 0.0
			order.append({"i": i, "err": _error(_legs[i]) + urgent})
	order.sort_custom(func(a, b): return a["err"] > b["err"])

	for o in order:
		var leg: Dictionary = _legs[o["i"]]
		var urgent := _out_of_reach(leg)                         # 닿지 않는 발은 모든 제동을 무시한다
		if (o["err"] as float) < tune["trigger"] and not urgent:
			continue
		if _all_down < tune["hold"] and not urgent:
			continue                                             # 방금 내려앉았다 — 잠깐 딛고 있는다
		if not _can_step(leg):
			continue
		if urgent:
			steps_urgent += 1
		else:
			steps_normal += 1
		_begin_step(leg, 0.0)
		_all_down = 0.0
		# 두 발까지 허용하는 걸음새(트롯)에서는 대각 짝을 같이 띄운다.
		# 한 발씩(legs_up 1)이면 띄우지 않는다 — 그게 거미 걸음의 핵심이다.
		if tune["legs_up"] >= 1.5:
			for other in _legs:
				if other == leg or other["group"] != leg["group"] or other["stepping"]:
					continue
				_begin_step(other, 0.0)


## 공중에 뜬 동안의 다리. **올라갈 때와 내려올 때가 다르다.**
##   올라갈 때 — 접는다. 발을 땅에 박아 둔 채 두면 몸이 올라가는 만큼 다리가 늘어나 떨어져 보인다.
##   내려올 때 — **착지할 자리를 향해 뻗는다.** 접은 채로 내려오면 몸이 선 높이에서 멈추는 순간
##               발이 아직 공중에 남아 있어, 땅이 아니라 허공에 착지한 것처럼 보인다
##               (측정: 착지 직전 프레임에 발이 지면 58px 위에 있었다).
func _air_legs(delta: float) -> void:
	var rising := _air_v < 0.0
	var k := clampf(delta * (7.0 if rising else 12.0), 0.0, 1.0)
	for leg in _legs:
		var hip := _hip_world(leg)
		var p0 := _phi0(leg)
		var target: Vector2
		if rising:
			# 접은 자세 — 발을 고관절 바로 아래 정강이 길이쯤에 둔다 (정강이는 그대로 수직)
			var side := signf(leg["rest"] as float) * float(facing)
			target = hip + Vector2(side * 40.0, SHIN_LEN * 0.9).rotated(_angle)
		else:
			var spot := _desired(leg, speed)
			spot.y = ground_at.call(spot.x)
			var guard := 0
			while strut_for(hip, spot, p0) > THIGH_MAX * 0.97 and guard < 60:
				spot = spot.lerp(hip + Vector2(0.0, SHIN_LEN), 0.06)
				guard += 1
			target = spot
		var f := (leg["foot"] as Vector2).lerp(target, k)
		# 두 가지를 **순서대로** 지킨다: ① 스트럿 한계 ② 지형 관통 금지.
		# 순서를 섞으면 서로를 깬다 — 지면으로 올리면 스트럿이 터지고, 스트럿을 맞추면 지면을 뚫는다.
		var g3 := 0
		while strut_for(hip, f, p0) > THIGH_MAX * 0.985 and g3 < 40:
			f = f.lerp(hip + Vector2(0.0, SHIN_LEN), 0.08)
			g3 += 1
		var gy: float = ground_at.call(f.x)
		if f.y > gy and strut_for(hip, Vector2(f.x, gy), p0) <= THIGH_MAX * 0.985:
			f.y = gy
		leg["foot"] = f
		leg["stepping"] = false


## 마지막 안전장치. 대각 규칙 때문에 차례가 밀리거나 몸이 급히 움직여 도달 거리를 넘어선 발을 끌어당긴다.
## 발이 조금 미끄러지는 편이, 다리가 땅에서 떨어져 허공에 뜨는 것보다 낫다.
##   딛고 있는 발 — 지면을 따라 고관절 쪽으로 민다 (발이 공중에 뜨지 않게)
##   뜬 발       — 반경 안으로 곧장 당긴다 (어차피 공중이라 지면에 붙일 필요가 없다)
func _leash_feet() -> void:
	var limit := THIGH_MAX * 0.985
	for leg in _legs:
		var hip := _hip_world(leg)
		var p0 := _phi0(leg)
		var foot: Vector2 = leg["foot"]

		if airborne:
			continue        # 몸이 떠 있는 동안의 다리는 _air_legs 가 단독으로 책임진다 (여기서 또 만지면 서로 깬다)

		if leg["stepping"]:
			# 스윙 중인 발 — 궤적을 따라가되 스트럿 한계 안으로만 당긴다 (공중이라 지면에 붙일 필요가 없다)
			var g2 := 0
			while strut_for(hip, foot, p0) > limit and g2 < 40:
				foot = foot.lerp(hip + Vector2(0.0, SHIN_LEN), 0.08)
				g2 += 1
			leg["foot"] = foot
			continue

		# 딛은 발은 **반드시 지면 위에** 있어야 한다. 그래서 먼저 지면에 붙이고,
		# 스트럿이 모자라면 지면을 따라 고관절 쪽으로 밀며 닿는 자리를 찾는다.
		# (예전엔 닿지 않을 때 발을 고관절 쪽으로 곧장 당겼는데, 절벽 옆에서 그 발이
		#  바위 속에 박힌 채 남았다 — 지면보다 141px 아래에 있었다.)
		foot.y = ground_at.call(foot.x)
		if strut_for(hip, foot, p0) > limit:
			# 닿는 자리를 **주변 전체에서 찾는다.** 한 칸씩 좋아지는 쪽으로 미는 방식은
			# 절벽 위 고원처럼 평평한 구간에서 국소 최저점에 갇힌다 (어느 쪽으로 8px 가도 똑같다).
			# 현재 위치에서 가장 가까운, 닿을 수 있는 지면을 고른다.
			var best_x := INF
			var x := foot.x - LEASH_SCAN
			while x <= foot.x + LEASH_SCAN:
				var c := Vector2(x, ground_at.call(x))
				if strut_for(hip, c, p0) <= limit and absf(x - foot.x) < absf(best_x - foot.x):
					best_x = x
				x += 10.0
			if best_x < INF:
				foot = Vector2(best_x, ground_at.call(best_x))
			# 못 찾으면 그대로 둔다 — 다음 프레임에 "닿지 않는 발" 로 잡혀 스텝 규칙이 옮긴다
		leg["foot"] = foot


## 제자리에서 얼마나 어긋났는가 (수평 + 높이차)
func _error(leg: Dictionary) -> float:
	var want := _desired(leg, speed)
	var f: Vector2 = leg["foot"]
	return absf(want.x - f.x) + absf(want.y - f.y) * 0.65


## 몸이 멀어져 다리가 더는 닿지 않는 상태 — 어긋남이 작아도 무조건 발을 옮겨야 한다
func _out_of_reach(leg: Dictionary) -> bool:
	var hip := _hip_world(leg)
	return strut_for(hip, leg["foot"], _phi0(leg)) > THIGH_MAX * 0.99


## 걸음이 무너지지 않게 하는 규칙: **동시에 뜨는 발은 legs_up 개까지, 두 발이면 반드시 대각.**
## 어느 쪽이든 남은 발들이 늘 몸을 받친다 (두 발이면 2개, 한 발씩이면 3개).
func _can_step(leg: Dictionary) -> bool:
	var cap := 1 if tune["legs_up"] < 1.5 else 2
	var air := 0
	for other in _legs:
		if not other["stepping"]:
			continue
		air += 1
		# 두 발까지 허용할 때만 "같은 대각 조" 를 따진다. 한 발씩이면 애초에 겹치지 않는다.
		if cap >= 2 and other["group"] != leg["group"]:
			return false
	return air < cap


func _begin_step(leg: Dictionary, extra: float) -> void:
	leg["from"] = leg["foot"]
	leg["to"] = _reachable(leg, _desired(leg, speed))
	leg["t"] = 0.0
	leg["stepping"] = true
	# 빠를수록 짧게 — 안 그러면 몸이 발을 앞질러 다리가 뒤로 질질 끌린다
	var dist: float = (leg["to"] as Vector2).distance_to(leg["from"] as Vector2)
	var v := maxf(absf(speed), 1.0)
	leg["dur"] = clampf(minf(tune["step_time"], dist / v * 0.55), 0.11, 0.45) + extra


## 고관절의 월드 좌표. 노드 트랜스폼(to_global)은 tick 끝에서야 갱신되므로 **쓰지 않는다** —
## 틱 도중에 부르면 한 프레임 전 자리를 줘서, 발을 끌어당기는 안전장치가 항상 한 박자 늦는다.
## 착지 목표를 **발을 내려놓을 시점의** 고관절에서 닿는 자리로 당긴다.
## 그냥 _desired 를 쓰면 경사·낭떠러지에서 목표가 도달 거리 밖에 잡혀, 스윙 도중 다리가 떨어져 보인다.
func _reachable(leg: Dictionary, want: Vector2) -> Vector2:
	var hip_land := _hip_world(leg) + Vector2(speed * tune["step_time"] * 0.8, 0.0)
	var out := want
	var guard := 0
	while strut_for(hip_land, out, _phi0(leg)) > THIGH_MAX * 0.93 and guard < 80:
		out.x = move_toward(out.x, hip_land.x, 6.0)
		out.y = ground_at.call(out.x)
		guard += 1
	return out


func _hip_world(leg: Dictionary) -> Vector2:
	var h: Vector2 = leg["hip"]
	return body_pos + Vector2(h.x * float(facing), h.y).rotated(_angle)


## 이 다리의 기준 정강이 각. 바깥쪽(몸 중심 반대편)으로 SHIN_SPLAY 만큼 눕힌다.
## rest 의 부호 × facing 이 곧 그 다리가 뻗은 세계 방향이다.
func _phi0(leg: Dictionary) -> float:
	return -SHIN_SPLAY * signf((leg["rest"] as float) * float(facing))


## 무릎 자리 — 발에서 SHIN_LEN 위, 수직에서 φ 만큼 기운 점.
static func _knee_at(foot: Vector2, phi: float) -> Vector2:
	return foot + Vector2(0.0, -SHIN_LEN).rotated(phi)


## 이 발자리를 딛으려면 허벅지 스트럿이 **최소** 얼마나 길어야 하는가.
## 무릎은 발을 중심으로 반지름 SHIN_LEN, 기준 각 ±SHIN_TILT_MAX 인 호 위에 있다.
## 그 호에서 고관절에 가장 가까운 점이 답이고, 그 점은 "고관절 방향" 을 허용 범위로 자른 각이다.
## (샘플을 훑던 예전 방식은 한 번에 25번씩 재느라 검증이 분 단위로 느려졌다. 이건 O(1) 이다.)
func strut_for(hip: Vector2, foot: Vector2, phi0: float) -> float:
	var off := wrapf((hip - foot).angle() + PI * 0.5, -PI, PI)
	return hip.distance_to(_knee_at(foot, clampf(off, phi0 - SHIN_TILT_MAX, phi0 + SHIN_TILT_MAX)))


## 실제로 그릴 자세 — **되도록 기준 각(바깥으로 벌린 각)으로** 둔다.
## 기준 각으로 스트럿이 한계 안에 들면 그대로 쓰고, 넘칠 때만 고관절 쪽으로 **필요한 만큼만** 더 기운다.
static func solve_knee_v(hip: Vector2, foot: Vector2, phi0: float) -> Vector2:
	if hip.distance_to(_knee_at(foot, phi0)) <= THIGH_MAX:
		return _knee_at(foot, phi0)                           # 기준 자세로 닿는다 — 그대로 쓴다
	var off := wrapf((hip - foot).angle() + PI * 0.5, -PI, PI)
	var hi := clampf(off, phi0 - SHIN_TILT_MAX, phi0 + SHIN_TILT_MAX)
	if hip.distance_to(_knee_at(foot, hi)) > THIGH_MAX:
		return _knee_at(foot, hi)                             # 그래도 모자란다 — 최대한 기울여 둔다
	var lo := phi0
	for _i in range(12):                                      # 한계에 드는 **가장 작은** 기울기를 찾는다
		var mid := (lo + hi) * 0.5
		if hip.distance_to(_knee_at(foot, mid)) <= THIGH_MAX:
			hi = mid
		else:
			lo = mid
	return _knee_at(foot, hi)


# ── 그리기 ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	for leg in _legs:
		if not leg["near"]:
			_draw_leg(leg, FAR_MUL)
	_draw_body()
	_draw_turret()
	for leg in _legs:
		if leg["near"]:
			_draw_leg(leg, 1.0)


func _draw_leg(leg: Dictionary, mul: float) -> void:
	var f := float(facing)
	var h: Vector2 = leg["hip"]
	var hip := Vector2(h.x * f, h.y)
	var foot := to_local(leg["foot"])
	if not leg["near"]:
		foot.y -= FAR_RAISE
	var knee := solve_knee_v(hip, foot, _phi0(leg))

	# 정강이 — 거의 수직으로 유지되는 강체
	_limb(knee, foot, SHIN_W, _dim(C_SHIN, mul))
	# 허벅지 — 길이가 변하는 유압 스트럿. 가는 로드를 전 구간에 깔고 그 위에 **고정 길이 슬리브**를 덮어,
	# 길이 변화가 고무줄이 아니라 "실린더에서 로드가 나온다" 로 읽히게 한다.
	var d := knee - hip
	var span := d.length()
	if span > 1.0:
		var n := d / span
		_limb(hip, knee, THIGH_W - 18.0, _dim(C_THIGH_ROD, mul))
		_limb(hip, hip + n * minf(SLEEVE_LEN, span), THIGH_W, _dim(C_THIGH, mul))
	draw_circle(knee, KNEE_R, _dim(C_JOINT, mul))
	draw_circle(hip, HIP_R, _dim(C_JOINT, mul))


func _draw_body() -> void:
	var f := float(facing)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-BODY_HALF_W, BODY_TOP), Vector2(BODY_HALF_W, BODY_TOP),
		Vector2(BODY_HALF_W, BODY_BOT), Vector2(-BODY_HALF_W, BODY_BOT),
	]), C_BODY)
	# 아랫면 어두운 띠 — 다리가 몸에 파묻히는 자리를 정리한다
	draw_colored_polygon(PackedVector2Array([
		Vector2(-BODY_HALF_W, BODY_SKIRT), Vector2(BODY_HALF_W, BODY_SKIRT),
		Vector2(BODY_HALF_W, BODY_BOT), Vector2(-BODY_HALF_W, BODY_BOT),
	]), C_BODY_DARK)
	# 바라보는 쪽 앞머리를 조금 내밀어 방향을 읽게 한다 (포신은 이제 따로 있는 포탑이다)
	var nose := (BODY_HALF_W + 34.0) * f
	draw_colored_polygon(PackedVector2Array([
		Vector2(BODY_HALF_W * f, -128.0), Vector2(nose, -112.0),
		Vector2(nose, -58.0), Vector2(BODY_HALF_W * f, -44.0),
	]), C_BODY)


## 포탑. _turret 은 월드 각이므로 그릴 때 몸 회전을 빼서 로컬 각으로 바꾼다.
func _draw_turret() -> void:
	var f := float(facing)
	var pivot := Vector2(TURRET_PIVOT.x * f, TURRET_PIVOT.y)
	var a := _turret - rotation
	var dir := Vector2.RIGHT.rotated(a)
	var tip := pivot + dir * (BARREL_LEN - _recoil)

	# 요동축을 몸통 윗면에 잇는 받침 — 포신을 들어도 공중에 뜨지 않게
	_limb(pivot + Vector2(0.0, 70.0), pivot, 70.0, C_BODY_DARK)
	# 약실(요동축 뒤로 튀어나온 덩어리) → 포신 → 총구 블록
	_limb(pivot - dir * 62.0, pivot + dir * 20.0, BARREL_W + 22.0, C_GUN)
	_limb(pivot, tip, BARREL_W, C_GUN)
	_limb(tip - dir * 30.0, tip + dir * 8.0, BARREL_W + 16.0, C_GUN_LIT)
	draw_circle(pivot, MOUNT_R, C_JOINT)

	if _flash > 0.0:
		# 총구 화염 — 앞으로 뻗는 마름모 + 옆으로 퍼지는 짧은 날개
		var n := Vector2(-dir.y, dir.x)
		var m := tip + dir * 8.0
		var k := _flash / FLASH_TIME
		draw_colored_polygon(PackedVector2Array([
			m, m + dir * (86.0 * k) + n * 8.0, m + dir * (34.0 * k) + n * (30.0 * k),
			m - dir * 6.0, m + dir * (34.0 * k) - n * (30.0 * k), m + dir * (86.0 * k) - n * 8.0,
		]), Color(C_FLASH.r, C_FLASH.g, C_FLASH.b, 0.92))


func _limb(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var n := d.normalized()
	var p := Vector2(-n.y, n.x) * (w * 0.5)
	var a2 := a - n * (w * 0.35)                                  # 관절 원 밑으로 조금 물려 이음매를 메운다
	var b2 := b + n * (w * 0.2)
	draw_colored_polygon(PackedVector2Array([a2 + p, b2 + p, b2 - p, a2 - p]), col)


## Color × float 는 알파까지 깎는다 — 색만 어둡게 한다
static func _dim(c: Color, mul: float) -> Color:
	return Color(c.r * mul, c.g * mul, c.b * mul, c.a)


# ── 디버그 (랩이 켠다) ────────────────────────────────────────────────────────

## 발 자리·목표·도달 반경을 월드 좌표로 그려 준다. 랩의 디버그 노드가 불러 쓴다.
func debug_draw(on: CanvasItem) -> void:
	for leg in _legs:
		var hip := _hip_world(leg)
		var foot: Vector2 = leg["foot"]
		var lit: bool = leg["stepping"]
		on.draw_line(hip, foot, Color(1, 1, 1, 0.22), 2.0)
		on.draw_arc(hip, THIGH_MAX, 0.0, TAU, 48, Color(1, 1, 1, 0.07), 1.0)   # 무릎이 갈 수 있는 한계
		var want := _desired(leg, speed)
		on.draw_line(want + Vector2(0, -26), want + Vector2(0, 26), Color(0.4, 1.0, 0.5, 0.5), 2.0)
		on.draw_circle(foot, 7.0, Color(1.0, 0.85, 0.3, 0.95) if lit else Color(0.5, 0.8, 1.0, 0.75))
		if lit:
			on.draw_line(leg["from"], leg["to"], Color(1.0, 0.85, 0.3, 0.35), 2.0)


## 여유를 실제 수치로 계산한다. 랩 HUD 가 이걸 띄운다.
##
## 정강이가 수직이므로 무릎은 발 바로 위에 있고, **묶이는 것은 허벅지 스트럿 길이** 하나다.
##     스트럿 = sqrt(수평거리² + (고관절높이 - SHIN_LEN)²)  ≤ THIGH_MAX
##
## **발이 뒤로 밀리는 거리는 보폭(trigger)이 아니라 한 주기 시간이 정한다.** 한 조가 날고, 접지 유지하고,
## 다른 조가 날고, 다시 접지 유지 — 그 한 바퀴 동안 몸이 나간 거리를 그 발이 한 걸음에 만회해야 하므로
##     한 주기 = 2 × (hold + step_time)  ·  밀리는 거리 = 속도 × 한 주기
## 이다. trigger 가 이보다 작으면 아무 역할도 못 한다.
##
## 발이 오가는 구간은 [rest + lead×v - 밀리는거리, rest + lead×v] 이고 그 **양 끝** 을 다 본다.
## lead 는 이 구간을 앞뒤로 미는 손잡이라, 구간을 rest 에 가운데 맞추는 값(= hold + step_time)이 가장 여유롭다.
func reach_budget() -> Dictionary:
	var v: float = tune["speed"]
	# 한 주기에 몇 번 나눠 딛는가. 두 발씩이면 2번, 한 발씩이면 4번이다.
	# 이걸 빼먹으면 한 발씩 걷는 걸음새에서 발이 밀리는 거리를 절반으로 잘못 본다.
	var waves: float = 2.0 if tune["legs_up"] >= 1.5 else 4.0
	var cycle: float = waves * (tune["hold"] + tune["step_time"])
	var sweep: float = maxf(v * cycle, tune["trigger"] + tune["hold"] * v)
	var lead_px: float = tune["lead"] * v
	var worst := 0.0
	var who := ""
	for leg in _legs:
		var hip: Vector2 = leg["hip"]
		var dy: float = (tune["ride"] - hip.y + tune["bob"]) - SHIN_LEN
		var rest: float = (leg["rest"] as float) * tune["stride"]
		var ends := [
			[absf(rest + lead_px - hip.x), "앞쪽"],
			[absf(rest + lead_px - sweep - hip.x), "뒤쪽"],
		]
		for e in ends:
			var dx: float = e[0]
			var strut := sqrt(dx * dx + dy * dy)
			if strut > worst:
				worst = strut
				who = "%s 다리 %s" % [leg["name"], e[1]]
	return {"limit": THIGH_MAX, "worst": worst, "who": who, "sweep": sweep, "best_lead": cycle * 0.5}


## 지금 떠 있는 발 수## 지금 떠 있는 발 수 (랩의 상태 표시용)
func air_count() -> int:
	var n := 0
	for leg in _legs:
		if leg["stepping"]:
			n += 1
	return n


## 현재 수치를 코드에 적기 좋은 꼴로
func tune_text() -> String:
	return "ride %.0f · stride %.2f · trigger %.0f · lift %.0f · step %.2fs · lead %.2f · tilt %.2f · bob %.0f · hold %.2fs · 동시 %d발" % [
		tune["ride"], tune["stride"], tune["trigger"], tune["lift"],
		tune["step_time"], tune["lead"], tune["tilt"], tune["bob"], tune["hold"], int(tune["legs_up"]),
	]
