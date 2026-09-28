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
##          ActionVisual AnimatedSprite2D — 전신 클립(구르기 · 점프 · 사다리). 켜지면 위 분리 파츠를 가린다
##          ReloadLegs / ReloadUpper Sprite2D — 재장전 합성: 재장전 원화의 허리 위 + 지금 걷는 다리
## 상태 우선순위: Roll > Climb > Jump > Crouch > Run/Walk > Idle.
## 점프·사다리는 **발 위치(position)를 바닥에 둔 채** 그림만 _air 만큼 들어 올린다 — 바닥선을 position.y 로 읽는
## 탄피·탄흔·규격 테스트 씬(발 높이를 직접 씀)이 그대로 돈다. 공중 높이가 필요한 판정은 air_height() 를 더한다.
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
signal health_changed(value: float)
signal incapacitated()
var health := 100.0

const FRAME_SIZE := 320             # 80² 네이티브 셀 × 4 — NPC 와 같은 규격 (2026-09-23 기준 확정, Docs/SCALE_CHARACTER_BASELINE.md)
const SPLIT_DIR := "res://assets/character/Split/"
const ACTION_DIR := "res://assets/character/Action/"
const ACTION_FRAME_COUNT := 6
const MOVE_DIR := "res://assets/character/Frames/"   # 전신 이동 클립 (점프 · 측면 사다리) — Assets/GameReady/Characters/HoodedMechanic/MOVEMENT_CLIPS.md
const MOVE_CLIPS := {"jump": 4, "climb": 4}
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

# 앉아 걷기 — 웅크린 채(crouch_04) 천천히 움직인다. 전용 클립이 없어 몸을 걸음마다 톡톡 들썩이고 좌우로 흔든다.
const CROUCH_SPEED := 150.0         # 걷기의 약 40%
const CROUCH_STRIDE := 58.0         # 한 걸음 거리 (px) — 걸음마다 한 번 들썩이고 발소리
const CROUCH_BOB := 5.0             # 들썩임 높이 (px, 1px 격자)
const CROUCH_WADDLE := 4.0          # 걸음마다 상체가 좌우로 실리는 양 (px)

# 점프 (W/↑ — 옆에 상호작용할 것이 없을 때). 원화 4장: 도약 준비 · 상승 · 정점 · 착지
const JUMP_SPEED := 1180.0          # 이륙 속도 (px/s) → 정점 ≈ v²/2g ≈ 200px, 체공 ≈ 0.69초
const JUMP_GRAVITY := 3450.0
const JUMP_ANTICIP := 0.07          # 도약 준비 (jump_01, 땅에 붙어 있음)
const JUMP_LAND := 0.13             # 착지 자세 유지 (jump_04)
const JUMP_APEX_BAND := 330.0       # 상승 속도가 이 아래로 떨어지면 정점 자세(jump_03)
const AIR_ACCEL := 2600.0           # 공중 좌우 조작 (지상 가속의 절반)

# 사다리 (측면). 원화는 오른쪽을 보고 손이 몸 중심보다 앞(+x)에 있다 — 사다리 축에 손이 오도록 몸을 뒤로 뺀다
const CLIMB_SPEED := 260.0          # px/s. 8fps 원화 기준 한 장당 32.5px ≈ 가로대 한 칸
const CLIMB_STEP := CLIMB_SPEED / 8.0
const CLIMB_HAND_X := 38.0          # 몸 중심 → 사다리 축 (바라보는 쪽)
const CLIMB_SNAP := 14.0            # 사다리 축으로 붙는 속도

# 아이들 모션 (Idle / Crouch) — 발을 바닥에 붙인 채 상체만 절차적으로 흔든다.
# idle 클립은 **한 장짜리 정지 프레임**이라 움직임은 전부 여기서 만들어진다. 레트로 게임의 과장된
# 대기 자세처럼 "가만히 서 있어도 계속 살아 있는" 실루엣이 목표. 채널은 넷:
#   squash : 세로로 늘고 가로로 줄어드는 스쿼시&스트레치 (scale, 발 고정이라 위치로 보정)
#   lean   : 상체에 좌우로 실리는 무게중심 (skew + 위치 보정, 발은 그대로)
#   head   : 목 위 머리가 head_lag 만큼 **늦게** 따라 흔들림 (px 상하 · rad 기울기)
#   arm    : 어깨(=팔 앵커)가 같이 들썩임 (px 상하)
# hz     : 주 파형 주파수. 옛 숨쉬기는 0.38Hz(2.6초) 였다 — 아래 프리셋은 전부 그보다 3~8배 빠르다
# pop    : 파형 샤프니스. 1 = 사인, <1 이면 사각파에 가까워져 톡톡 튀어 오르는 느낌
# steps  : 파형 **값**을 이 단계로 계단화 (0 = 끄기). 중간 자세가 사라져 포즈가 몇 개로 줄어든다
# frame_fps : 파형이 참조하는 **시간**을 이 fps 로 계단화 (0 = 끄기). 8 이면 1/8초마다 한 번만 자세가
#          바뀌고 그동안은 그대로 멈춰 있다 — 프레임 몇 장으로 돌리던 옛 픽셀 애니의 뚝뚝 끊기는 맛.
#          steps 가 자세의 **가짓수**를 줄인다면 이쪽은 자세가 **바뀌는 순간**을 띄엄띄엄 만든다
# snap_px: 머리·어깨·좌우 이동을 이 픽셀 격자에 맞춰 반올림 (0 = 끄기). 1 = 아트 1픽셀 단위로만 움직여
#          부드러운 미끄러짐이 사라진다. frame_fps 와 짝으로 써야 "클램프된 스프라이트" 처럼 보인다
# accent : accent_period 마다 한 번 터지는 강조 동작 (2차 스프링 임펄스 한 방, 부호는 매번 랜덤).
#          acc_* 값이 그 한 방을 각 채널에 얼마씩 나눠 준다. period 0 이면 강조 없음
const IDLE_PRESETS := [
	{"id": "bounce", "name": "통통 (Bounce)",
		"desc": "1.9Hz 스쿼시&스트레치. 머리·어깨가 한 박 늦게 따라온다 — 아케이드 대기 자세",
		"hz": 1.9, "squash": Vector2(0.060, 0.090), "pop": 0.62, "steps": 0,
		"lean_px": 3.0, "lean_hz": 0.95, "head_px": 8.0, "head_rad": 0.018, "head_lag": 0.14,
		"arm_px": 6.0, "crouch": 0.45, "accent_period": 0.0},
	{"id": "swagger", "name": "건들건들 (Swagger)",
		"desc": "1.2Hz 상하 + 0.6Hz 좌우 무게중심 이동. 머리는 반대로 기울고, 가끔 어깨를 한 번 턴다",
		"hz": 1.2, "squash": Vector2(0.030, 0.048), "pop": 1.0, "steps": 0,
		"lean_px": 16.0, "lean_hz": 0.6, "head_px": 5.0, "head_rad": 0.085, "head_lag": 0.20,
		"arm_px": 4.0, "crouch": 0.5,
		"accent_period": 3.6, "accent_jitter": 0.8, "accent_imp": 60.0, "accent": Vector3(520.0, 34.0, 0.0),
		"acc_squash": 0.020, "acc_lean_px": 7.0, "acc_head_rad": 0.05, "acc_head_px": 3.0, "acc_arm_px": 4.0},
	{"id": "twitch", "name": "안절부절 (Twitch)",
		"desc": "3.2Hz 계단형 잔떨림 + 0.9초마다 어깨·머리가 한 번 튀는 강조. 총 든 손이 근질거린다",
		"hz": 3.2, "squash": Vector2(0.048, 0.070), "pop": 0.30, "steps": 3,
		"lean_px": 7.0, "lean_hz": 1.6, "head_px": 8.0, "head_rad": 0.045, "head_lag": 0.25,
		"arm_px": 7.0, "crouch": 0.5,
		"accent_period": 0.9, "accent_jitter": 0.3, "accent_imp": 120.0, "accent": Vector3(1900.0, 62.0, 0.0),
		"acc_squash": 0.060, "acc_lean_px": 14.0, "acc_head_rad": 0.14, "acc_head_px": 10.0, "acc_arm_px": 12.0},
	{"id": "heavy", "name": "묵직 (Heavy)",
		"desc": "0.7Hz 느린 템포. 대신 한 번에 세로 8%씩 확실히 눌렀다 편다 — 차분하지만 분명한 상하",
		"hz": 0.7, "squash": Vector2(0.052, 0.080), "pop": 1.45, "steps": 0,
		"lean_px": 0.0, "lean_hz": 0.35, "head_px": 11.0, "head_rad": 0.012, "head_lag": 0.18,
		"arm_px": 7.0, "crouch": 0.55, "accent_period": 0.0},
	{"id": "stepped", "name": "뚝뚝 (Stepped)",
		"desc": "8fps 로 시간을 계단화하고 자세를 4단계로 클램프 · 픽셀 격자 스냅. 옛 스프라이트 애니처럼 딱딱 끊긴다",
		"hz": 1.0, "squash": Vector2(0.055, 0.085), "pop": 0.8, "steps": 2,
		"frame_fps": 8.0, "snap_px": 1.0,
		"lean_px": 9.0, "lean_hz": 0.5, "head_px": 10.0, "head_rad": 0.05, "head_lag": 0.25,
		"arm_px": 8.0, "crouch": 0.5,
		"accent_period": 2.4, "accent_jitter": 0.6, "accent_imp": 100.0, "accent": Vector3(1100.0, 56.0, 0.0),
		"acc_squash": 0.045, "acc_lean_px": 10.0, "acc_head_rad": 0.09, "acc_head_px": 8.0, "acc_arm_px": 8.0},
	{"id": "legacy", "name": "기존 숨쉬기 (비교용)",
		"desc": "0.38Hz · 세로 2.8%만 늘었다 줄었다. 앞 프리셋들과 A/B 하려고 남겨 둔 예전 값",
		"hz": 0.385, "squash": Vector2(0.006, 0.014), "pop": 1.0, "steps": 0,
		"lean_px": 0.0, "lean_hz": 0.0, "head_px": 0.0, "head_rad": 0.0, "head_lag": 0.0,
		"arm_px": 0.0, "crouch": 1.0, "accent_period": 0.0},
]
const IDLE_BLEND_IN := 7.0          # 멈춰 설 때 아이들 모션이 올라오는 속도
const IDLE_BLEND_OUT := 11.0        # 걷기 시작하면 이 속도로 빠르게 꺼진다

# 사격 — 카타나 제로식 즉발·고속 연사
const FIRE_COOLDOWN := 0.09         # 초. 누르고 있으면 이 간격으로 연사 (≈11발/초)
const MAG_SIZE := 14                # 장탄수
const RELOAD_TIME := 1.15           # 재장전 시간 (초)
const FLASH_TIME := 0.03
const MUZZLE_LIGHT_FADE := 0.1       # 총구 라이트가 식는 시간 — 화염(FLASH_TIME)보다 길게 남아 방을 붉게 물들인다

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
const SWAP_TIME := 0.2              # 무기 교체 — 팔이 아래로 떨어졌다 새 총을 들고 올라온다 (첫 발은 SWAP 뒤 _fire_cd)
const PUMP_DELAY := 0.13            # 불독 발사 → 펌프(두 번째 작은 반동 · 탄피 배출)
const CROUCH_KICKBACK := 0.45       # 앉아 쏠 때 뒤로 밀리는 배율
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

# 재장전 합성 — 재장전 원화(Action/reload)의 허리 위만 잘라 지금 몸 클립의 다리 위에 얹는다.
# 서 있을 때는 원화 그대로(다리 포함), 걷기·달리기에서는 그 클립 다리가 계속 걷는다.
# 앉은 자세는 서 있는 상체를 얹으면 허벅지를 덮어 실루엣이 무너진다 — 앉은 몸·머리를 그대로 두고
# 팔만 절차적으로 내려 흔든다(_update_arm 의 reloading 분기).
const RELOAD_CUT := 232             # 재장전 원화의 허리선 (셀 y) — 이 위가 상체
const RELOAD_LEG_CUT := 228         # 몸 클립에서 다리를 자르는 선 — 상체와 4px 겹쳐 틈이 안 보이게

enum State { IDLE, WALK, RUN, CROUCH, UNCROUCH, ROLL, JUMP, CLIMB }

var state: State = State.IDLE
var facing := 1                     # 1 = 오른쪽, -1 = 왼쪽 (조준 방향이 결정)
var velocity_x := 0.0
var input_enabled := true
## ## 대기 모드 — 기체에 접속해 **몸만 남은** 상태 (2026-09-23)
## 보행 기체를 조종하는 동안 이 몸은 여기 서 있을 뿐이다. 그 사실이 보여야 한다:
##   · 아이들 모션(숨·무게중심 흔들림)을 멈춘다 — 살아서 서 있는 것과 구분된다
##   · 고개를 **아래로 떨군다** — 조준을 놓고 접속에 빠진 자세
## input_enabled 만으로는 부족하다. 그건 "조작이 안 먹는다" 일 뿐이고, 몸은 여전히 숨 쉬며
## 마우스를 따라 고개를 돌린다 — 그러면 누가 기체를 모는지 화면에서 읽히지 않는다.
var standby := false
## 머리 위가 낮아 설 수 없는 곳에서 웅크린 자세를 강제한다 (규격 테스트 씬의 세로 판정 — ScaleLab).
## 웅크린 동안은 CROUCH_SPEED 로 천천히만 걷는다. 본편은 쓰지 않는다.
var force_crouch := false
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
var weapon_id := WeaponCatalog.BULLDOG
var weapon_room: Node2D
var _charge := 0.0
var _charge_sound: AudioStreamPlayer2D
var _weapon_ammo := {}
var _pump_t := -1.0                 # 불독 펌프까지 남은 시간 (<0 = 없음)
var _swap_t := 0.0                  # 무기 교체 몸짓 남은 시간 (팔을 내렸다 올린다)
var _eject_local := EJECT_LOCAL     # 어깨 기준 탄피 배출구 (무기마다 다르다)
var _charge_fx: Node2D              # 코일 충전 — 총구에 모이는 전하
var reloading := false
var _reload_t := 0.0
var _heat := 0.0                    # 연사 열 (산탄)
# 반동 스프링 상태: 각 Vector2(값, 속도). 값 1.0 = 한 발 반동 크기. pending: [{t, part}] 지연 임펄스
var _arm_rc := Vector2.ZERO
var _head_rc := Vector2.ZERO
var _body_rc := Vector2.ZERO
var _pending: Array = []
var _arm_angle := 0.0
var _idle_t := 0.0
var _idle_w := 0.0                  # 아이들 모션 가중치 0..1 (이동 중엔 0으로 빠진다)
var _idle_acc := Vector2.ZERO       # 강조 동작 스프링 (값, 속도)
var _idle_acc_t := 0.0              # 다음 강조까지 남은 시간
var _idle_frame := -1               # frame_fps 계단화용 현재 프레임 번호
var _idle_acc_q := 0.0              # 그 프레임에서 붙잡아 둔 강조 값
var _idle_head_off := Vector2.ZERO  # 머리에 얹는 추가 오프셋 (px)
var _idle_head_rot := 0.0
var _idle_arm_off := Vector2.ZERO
var _breath := Vector2.ONE          # 상체 스케일 (아이들 스쿼시 결과) — 어깨·목 앵커가 이걸 따라간다
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
var _muzzle_light_t := 0.0
var action_visual: AnimatedSprite2D
var _action_clip := ""
var reload_upper: Sprite2D
var reload_legs: Sprite2D
var _reload_frames: Array = []      # Action/reload 텍스처 6장
var _move_frames := {}              # "jump"/"climb" → [텍스처]
var _air := 0.0                     # 발이 바닥에서 떠 있는 높이 (px, 위가 +)
var _vy := 0.0                      # 세로 속도 (위가 +)
var _jump_phase := 0                # 0 도약 준비 · 1 공중 · 2 착지
var _jump_t := 0.0
var _climb_x := 0.0                 # 잡고 있는 사다리 축 x
var _climb_max := 0.0               # 오를 수 있는 최대 높이
var _climb_dist := 0.0              # 오르내린 누적 거리 (프레임 선택)
var _climb_frame := 0
var _cw_phase := 0.0                # 앉아 걷기 걸음 위상 (걸음 단위)
var _cw_w := 0.0                    # 앉아 걷기 가중치 0..1
var _cw_bob := 0.0                  # 이번 프레임 들썩임 (px, 위가 +)


func _ready() -> void:
	add_to_group("readability_actors")
	set_meta("readability_bounds", Rect2(-90, -280, 180, 285))
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
	muzzle_light.texture_scale = Lighting.scale_for_radius(LightTuning.value("muzzle_hold", "radius", 1000.0))
	muzzle_light.color = Lighting.GUN_LIGHT
	muzzle_light.energy = LightTuning.value("muzzle_hold", "energy", 4.5)
	muzzle_light.height = LightTuning.value("muzzle_hold", "height", Lighting.FLASH_HEIGHT)
	muzzle_light.position = muzzle.position
	muzzle_light.enabled = false
	arm_pivot.add_child(muzzle_light)
	Lighting.register_dynamic(muzzle_light, 0.64, "shot")    # 프랍 그림자가 총구 화염을 따라 확 뻗는다 (세기 1.8→4.5 만큼 가중치를 낮춰 그림자 세기는 그대로)

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

	# 재장전 합성 — 다리(몸 클립의 허리 아래)를 먼저, 상체(재장전 원화의 허리 위)를 그 위에.
	# 재장전 원화(Action/reload)는 **옛 권총**을 들고 있다. 새 무기(불독·코일)는 원화가 없으므로 원화를 읽지 않고
	# 앉은 자세와 같은 절차 재장전(분리 몸통은 그대로 걷고, 팔+총만 내려 흔든다)을 모든 자세에 쓴다.
	# 원화가 생기면 여기서 무기별 경로를 읽으면 합성이 그대로 되살아난다.
	reload_legs = _make_reload_sprite("ReloadLegs")
	reload_upper = _make_reload_sprite("ReloadUpper")
	reload_upper.region_rect = Rect2(0, 0, FRAME_SIZE, RELOAD_CUT)

	_charge_fx = Node2D.new()
	_charge_fx.name = "ChargeFx"
	_charge_fx.z_index = 1
	var cmat := CanvasItemMaterial.new()
	cmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	cmat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_charge_fx.material = cmat
	_charge_fx.draw.connect(_draw_charge)
	arm_pivot.add_child(_charge_fx)

	for id in [WeaponCatalog.BULLDOG, WeaponCatalog.COIL]:
		_weapon_ammo[id] = int(WeaponCatalog.data(id).mag)
	_apply_weapon_visual()
	ammo = magazine_size()
	_update_arm(0.0, true)


## 무기 원화(컨셉 시트 EQUIPPED 에서 뽑은 총+팔 레이어)를 **기존 팔 자리**에 끼운다.
## 몸통·머리·전신 클립(걷기·달리기·앉기·구르기·점프·사다리)은 원래 손그림 그대로 두고, 팔 스프라이트만 바꾼다 —
## 어깨를 축으로 조준하고 반동 스프링(팔→머리→몸통)을 받는 것도 원래 소총과 같다.
## 원화의 어깨점(json "shoulder")이 팔 스프라이트 원점, "muzzle" 이 총구다. 배율은 gun_scale.
func _apply_weapon_visual() -> void:
	var path := "res://assets/weapons/%s.json" % weapon_id
	var wm = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if typeof(wm) != TYPE_DICTIONARY:
		return
	var d := WeaponCatalog.data(weapon_id)
	var gs := float(d.gun_scale)
	var sh := Vector2(wm.shoulder[0], wm.shoulder[1])
	var mz := Vector2(wm.muzzle[0], wm.muzzle[1])
	arm.texture = Lighting.textured("res://assets/weapons/%s_gun.png" % weapon_id)
	arm.scale = Vector2(gs, gs)
	arm.offset = -sh
	muzzle.position = (mz - sh) * gs
	_eject_local = Vector2((mz.x - sh.x) * 0.42 * gs, 6.0)
	var fl := float(d.flash)
	flash.position = muzzle.position + Vector2(flash.texture.get_width() * 0.5 * fl - 10.0, 0)
	flash.modulate = Lighting.RED_EMISSIVE_SOFT if weapon_id == WeaponCatalog.BULLDOG else Color(0.55, 1.9, 2.4)
	muzzle_light.position = muzzle.position
	muzzle_light.color = Lighting.GUN_LIGHT if weapon_id == WeaponCatalog.BULLDOG else Color(d.color)
	_charge_fx.position = muzzle.position


func magazine_size() -> int:
	return int(WeaponCatalog.data(weapon_id).mag)


func reload_duration() -> float:
	return float(WeaponCatalog.data(weapon_id).reload)


func charge_time() -> float:
	return maxf(float(WeaponCatalog.data(weapon_id).charge), 0.001)


func charge_ratio() -> float:
	return clampf(_charge / charge_time(), 0.0, 1.0)


func cancel_charge() -> void:
	_charge = 0.0
	if is_instance_valid(_charge_sound):
		_charge_sound.queue_free()
	_charge_sound = null


func equip_weapon(id: String) -> void:
	if id not in [WeaponCatalog.BULLDOG, WeaponCatalog.COIL] or id == weapon_id:
		return
	_weapon_ammo[weapon_id] = ammo
	cancel_charge()
	reloading = false
	_reload_t = 0.0
	weapon_id = id
	ammo = int(_weapon_ammo[id])
	_fire_cd = 0.16
	_pump_t = -1.0
	_swap_t = SWAP_TIME
	_apply_weapon_visual()
	Audio.play_at("cloth", global_position, 0.0)
	WeaponAudio.play(get_parent(), global_position, "pump", -12.0, 0.8 if id == WeaponCatalog.BULLDOG else 1.35)
	ammo_changed.emit(ammo, magazine_size(), false)


func _unhandled_key_input(event: InputEvent) -> void:
	if input_enabled and not standby and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q:
		equip_weapon(WeaponCatalog.COIL if weapon_id == WeaponCatalog.BULLDOG else WeaponCatalog.BULLDOG)
		get_viewport().set_input_as_handled()


func _make_reload_sprite(node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.centered = false
	s.region_enabled = true
	s.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE)
	s.material = Lighting.character_material()
	s.visible = false
	add_child(s)
	return s


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
	# 점프·사다리는 재생하지 않고 프레임을 직접 고른다 (세로 속도 · 오른 거리에 묶음)
	for clip_name in MOVE_CLIPS.keys():
		sf.add_animation(clip_name)
		sf.set_animation_loop(clip_name, false)
		var texs: Array = []
		for i in range(1, int(MOVE_CLIPS[clip_name]) + 1):
			var path := "%s%s/%s_%02d.png" % [MOVE_DIR, clip_name, clip_name, i]
			if ResourceLoader.exists(path):
				var t := Lighting.textured(path)
				sf.add_frame(clip_name, t)
				texs.append(t)
			else:
				push_warning("이동 프레임을 찾을 수 없음: %s" % path)
		_move_frames[clip_name] = texs
	return sf


func _show_action_clip(clip_name: String, frame_index := 0, should_play := true) -> void:
	if action_visual == null or action_visual.sprite_frames == null:
		return
	if not action_visual.sprite_frames.has_animation(clip_name):
		return
	_action_clip = clip_name
	action_visual.flip_h = facing < 0
	action_visual.animation = clip_name
	action_visual.frame = clampi(frame_index, 0, action_visual.sprite_frames.get_frame_count(clip_name) - 1)
	action_visual.position = Vector2(0, -_air)
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


## 재장전 합성 그림을 지금 상태에 맞춘다. 전신 클립(구르기·점프·사다리)이 떠 있으면 그쪽이 이긴다.
##   서 있음(IDLE)     → 재장전 원화 한 장 그대로 (원화의 선 자세 다리)
##   걷기 · 달리기     → 원화의 허리 위 + 몸 클립의 허리 아래 (다리가 계속 걷는다)
##   앉기 · 앉아 걷기  → 합성하지 않는다 (분리 파츠 + 팔 절차 재장전)
func _sync_reload_visual() -> void:
	var standing := state == State.IDLE or state == State.WALK or state == State.RUN
	var on := reloading and standing and _reload_frames.size() > 0 and not action_visual.visible
	reload_upper.visible = on
	reload_legs.visible = on
	if not action_visual.visible:
		body.visible = not on
	if not on:
		return
	var progress := clampf(_reload_t / reload_duration(), 0.0, 0.999)
	var fi := mini(int(progress * _reload_frames.size()), _reload_frames.size() - 1)
	var tex: Texture2D = _reload_frames[fi]
	var flip := facing < 0
	reload_upper.texture = tex
	reload_upper.flip_h = flip
	reload_legs.flip_h = flip
	if state == State.IDLE:
		# 원화 통째로: 상체 + 같은 장의 다리
		reload_legs.texture = tex
		reload_legs.region_rect = Rect2(0, RELOAD_CUT, FRAME_SIZE, FRAME_SIZE - RELOAD_CUT)
		reload_legs.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE + RELOAD_CUT)
	else:
		var cut := RELOAD_LEG_CUT
		reload_legs.texture = body.sprite_frames.get_frame_texture(body.animation, body.frame)
		reload_legs.region_rect = Rect2(0, cut, FRAME_SIZE, FRAME_SIZE - cut)
		reload_legs.offset = Vector2(-FRAME_SIZE * 0.5, -FRAME_SIZE + cut)


func _resume_reload_action() -> void:
	_sync_reload_visual()


static func recoil_preset() -> Dictionary:
	return RECOIL


## 지금 쓰는 아이들 프리셋. 본편에서 F5 로 순환하며 비교한다 (Shift+F5 = 이전).
static var idle_index := 0

static func idle_preset() -> Dictionary:
	return IDLE_PRESETS[wrapi(idle_index, 0, IDLE_PRESETS.size())]


## 인스턴스 경유 창구 — 촬영 도구처럼 **Player 를 이름으로 못 부르는** 곳(autoload 가 아직 없는
## --script 실행 시점)에서 프리셋을 갈아 끼우기 위한 것.
func idle_presets() -> Array:
	return IDLE_PRESETS


## 프리셋을 바꾸고 아이들 모션을 위상 0 에서 다시 시작한다 (프리셋 비교용 · 같은 지점에서 출발).
func use_idle_preset(i: int) -> void:
	idle_index = wrapi(i, 0, IDLE_PRESETS.size())
	_idle_t = 0.0
	_idle_w = 0.0
	_idle_acc = Vector2.ZERO
	_idle_acc_t = 0.0
	_idle_frame = -1
	_idle_acc_q = 0.0


## 픽셀 격자 스냅 (grid<=0 이면 그대로). 아트 1픽셀 = 월드 1단위라 grid 1.0 이 곧 한 픽셀이다.
static func _snap(v: float, grid: float) -> float:
	return v if grid <= 0.0 else roundf(v / grid) * grid


## 아이들 파형: 위상 p(사이클 단위) → -1..1.
## pop<1 이면 사각파 쪽으로 붙어 정점에 오래 머물고(톡 튀는 느낌), steps>0 이면 그 단계로 계단화한다.
static func _wave(p: float, pop: float, steps: int) -> float:
	var s := sin(TAU * p)
	var v: float = signf(s) * pow(absf(s), pop)
	if steps > 0:
		v = roundf(v * float(steps)) / float(steps)
	return v


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
				"head": _head_rc.y += float(rp["head_imp"]) * float(_pending[i].get("k", 1.0))
				"body": _body_rc.y += float(rp["body_imp"]) * float(_pending[i].get("k", 1.0))
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
	if _reload_t >= reload_duration():
		reloading = false
		ammo = magazine_size()
		ammo_changed.emit(ammo, magazine_size(), false)


func start_reload() -> void:
	if reloading or ammo >= magazine_size():
		return
	cancel_charge()
	reloading = true
	_reload_t = 0.0
	Audio.play_at("cloth", global_position, -3.0)
	_body_rc.y -= 6.0          # 탄창 빼는 몸짓 — 살짝 앞으로 숙임
	ammo_changed.emit(ammo, magazine_size(), true)


func _process(delta: float) -> void:
	_update_obstacle_support()
	if not input_enabled or state in [State.ROLL, State.CLIMB, State.JUMP] or reloading:
		cancel_charge()
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_run_lock = maxf(_run_lock - delta, 0.0)
	_swap_t = maxf(_swap_t - delta, 0.0)
	if _pump_t >= 0.0:
		_pump_t -= delta
		if _pump_t < 0.0:
			_pump()
	_update_recoil(delta)
	_update_reload(delta)
	if input_enabled and Input.is_action_just_pressed("reload"):
		start_reload()
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			flash.visible = false
	# 총구 라이트는 화염보다 오래 — MUZZLE_LIGHT_FADE 초에 걸쳐 식으며 주변을 붉게 물들인다
	if _charge > 0.0 and _muzzle_light_t <= 0.0:
		# 충전 중: 총구 라이트가 전하만큼 차오른다 (청록) — 쏘기 직전 주변 벽이 먼저 물든다
		var ck := charge_ratio()
		muzzle_light.enabled = true
		muzzle_light.energy = LightTuning.value("muzzle_hold", "energy", 4.5) * 0.55 * ck * ck
	elif muzzle_light.enabled:
		_muzzle_light_t -= delta
		var mk := clampf(_muzzle_light_t / (MUZZLE_LIGHT_FADE * 1.4), 0.0, 1.0)
		muzzle_light.energy = LightTuning.value("muzzle_hold", "energy", 4.5) * float(WeaponCatalog.data(weapon_id).light) * mk * mk
		if _muzzle_light_t <= 0.0:
			muzzle_light.enabled = false

	var axis := 0.0
	var crouch_held := false
	var run_held := false
	var shoot_pressed := false
	if input_enabled:
		axis = Input.get_axis("move_left", "move_right")
		crouch_held = Input.is_action_pressed("crouch") or force_crouch
		run_held = Input.is_action_pressed("run")
		shoot_pressed = Input.is_action_pressed("shoot")      # 홀드 = 연사
		if Input.is_action_just_pressed("roll") and _can_roll():
			_start_roll(int(signf(axis)) if absf(axis) > 0.1 else facing)
		# 사다리 위에서는 W/↑ 가 오르기다. 공중에서는 Main 이 사다리 잡기만 받는다
		if Input.is_action_just_pressed("interact") and state != State.ROLL and state != State.CLIMB:
			request_front_door.emit()

	if state == State.ROLL:
		_process_roll(delta)
		_sync_reload_visual()
		_update_arm(delta)
		_update_head(delta)
		return
	if state == State.CLIMB:
		_process_climb(delta, axis)
		_sync_reload_visual()
		return
	if state == State.JUMP:
		_process_jump(delta, axis, run_held and _run_lock <= 0.0)
		_update_idle(delta)
		_sync_reload_visual()
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

	# 이동 - 가속/감속 이징. 앉은 동안은 CROUCH_SPEED 로 천천히 (일어서는 중엔 감속만)
	var target_speed := RUN_SPEED if running else WALK_SPEED
	if state == State.CROUCH:
		target_speed = CROUCH_SPEED
	var target_v := axis * target_speed if state != State.UNCROUCH else 0.0
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
		_move_obstacle_x(velocity_x * delta)

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
	_update_crouch_walk(delta)

	_update_idle(delta)

	# 사격 - 누르고 있는 동안 쿨다운마다 한 발 (첫 발 즉발). 탄창이 비면 자동 재장전.
	# 질주 속도가 남아 있는 동안은 발사되지 않는다 — 위에서 이미 걷기로 감속을 시작했으므로
	# 브레이크를 밟듯 아주 짧게 늦춰졌다가 나간다.
	var fire_ready := shoot_pressed and _fire_cd <= 0.0 and _swap_t <= 0.0 and not reloading and absf(velocity_x) <= FIRE_MAX_SPEED
	if float(WeaponCatalog.data(weapon_id).charge) > 0.0 and fire_ready and ammo > 0:
		# 충전식: 누르고 있으면 charge 초 만에 **저절로** 나간다 (놓으면 취소). 계속 누르면 충전→발사가 반복된다
		if _charge == 0.0:
			_charge_sound = WeaponAudio.play(get_parent(), muzzle.global_position, "charge", -8.0)
		_charge += delta
		fire_ready = _charge >= charge_time()
	elif not shoot_pressed or not fire_ready:
		cancel_charge()
	_charge_fx.queue_redraw()
	if fire_ready:
		if ammo > 0:
			_fire()
		else:
			start_reload()

	_sync_reload_visual()
	_update_arm(delta)
	_update_head(delta)


## 앉아 걷기: 걸은 거리로 걸음 위상을 돌려 걸음마다 몸을 한 번 톡 들어 올리고(1px 격자) 좌우로 싣는다.
## 멈추면 가중치가 빠르게 빠져 아이들 모션(앉은 숨쉬기)으로 넘어간다.
func _update_crouch_walk(delta: float) -> void:
	var walking := state == State.CROUCH and absf(velocity_x) > WALK_THRESHOLD
	_cw_w = move_toward(_cw_w, 1.0 if walking else 0.0, delta * (10.0 if walking else 8.0))
	if walking:
		var prev := _cw_phase
		_cw_phase += absf(velocity_x) * delta / CROUCH_STRIDE
		if floorf(_cw_phase) != floorf(prev):
			Audio.play_at("footstep", global_position, -11.0)
	elif _cw_w <= 0.0:
		_cw_phase = 0.0
	# 위상 0.5 에서 정점 — 걸음 한 번에 한 번 튀어 오른다 (sin² 을 2단 계단화)
	var s := sin(PI * fposmod(_cw_phase, 1.0))
	_cw_bob = roundf(s * s * 2.0) * 0.5 * CROUCH_BOB * _cw_w
	_cw_bob = roundf(_cw_bob)


## 앉아 걷기 들썩임을 발 고정 세로 스케일로 — 웅크린 실루엣 꼭대기(바닥 위 ≈135px)가 _cw_bob 만큼 오른다
func _cw_scale() -> float:
	return 1.0 + _cw_bob / 135.0


## 앉아 걷기 좌우 실림 (px, 걸음마다 좌우 교대)
func _cw_waddle_x() -> float:
	return roundf(sin(PI * _cw_phase) * CROUCH_WADDLE * _cw_w)


func _can_roll() -> bool:
	return state != State.ROLL and state != State.JUMP and state != State.CLIMB


## ── 점프 ─────────────────────────────────────────────────────────────
func can_jump() -> bool:
	return input_enabled and (state == State.IDLE or state == State.WALK or state == State.RUN)


func jump() -> void:
	if not can_jump():
		return
	state = State.JUMP
	_jump_phase = 0
	_jump_t = 0.0
	_air = maxf(0.0, _obstacle_floor() - position.y)
	position.y = _obstacle_floor()
	_vy = 0.0
	body.speed_scale = 1.0
	Audio.play_at("cloth", global_position, -1.0)
	_show_action_clip("jump", 0, false)


func _process_jump(delta: float, axis: float, running: bool) -> void:
	_jump_t += delta
	facing = 1 if aim_target.x >= position.x else -1
	body.flip_h = facing < 0
	var frame := 0
	match _jump_phase:
		0:
			# 도약 준비 — 발이 붙어 있어 살짝 제동
			velocity_x = move_toward(velocity_x, 0.0, DECEL * 0.4 * delta)
			if _jump_t >= JUMP_ANTICIP:
				_jump_phase = 1
				_jump_t = 0.0
				_vy = JUMP_SPEED
		1:
			var target_v := axis * (RUN_SPEED if running else WALK_SPEED)
			velocity_x = move_toward(velocity_x, target_v, AIR_ACCEL * delta)
			var old_feet := position.y-_air
			_vy -= JUMP_GRAVITY * delta
			_air += _vy * delta
			frame = 1 if _vy > JUMP_APEX_BAND else 2
			var landing := _obstacle_floor()
			if is_instance_valid(weapon_room) and weapon_room.has_method("obstacle_landing"):
				landing = weapon_room.obstacle_landing(position.x, old_feet, position.y-_air)
			if position.y-_air >= landing and _vy < 0.0:
				position.y = landing
				_land()
				frame = 3
		2:
			frame = 3
			velocity_x = move_toward(velocity_x, axis * WALK_SPEED * 0.5, DECEL * delta)
			if _jump_t >= JUMP_LAND:
				_end_air()
				return
	if absf(velocity_x) > 0.5:
		_move_obstacle_x(velocity_x * delta)
	_show_action_clip("jump", frame, false)


func _land() -> void:
	_air = 0.0
	_vy = 0.0
	_jump_phase = 2
	_jump_t = 0.0
	Audio.play_at("land", global_position, -2.0)
	_body_rc.y -= 4.0


## 공중·사다리에서 땅으로 돌아와 평소 상태로
func _end_air() -> void:
	_air = 0.0
	_vy = 0.0
	state = State.IDLE
	body.play("idle")
	body.speed_scale = 1.0
	_hide_action_clip()
	_update_arm(0.0, true)
	_update_head(0.0, true)


## 공중에 떠서 떨어지기 시작한다 (사다리에서 손을 놓았을 때)
func _start_fall() -> void:
	state = State.JUMP
	_jump_phase = 1
	_jump_t = 0.0
	_vy = 0.0
	_show_action_clip("jump", 2, false)


## ── 사다리 ───────────────────────────────────────────────────────────
## ladder_x: 사다리 축 월드 x · max_h: 발이 올라갈 수 있는 최대 높이(바닥 위 px)
## 공중(점프 중)에서도 잡을 수 있다 — 그때는 지금 높이에서 매달린다.
func start_climb(ladder_x: float, max_h: float) -> void:
	if state == State.ROLL or state == State.CLIMB or not input_enabled:
		return
	state = State.CLIMB
	_climb_x = ladder_x
	_climb_max = maxf(max_h, 0.0)
	_air = clampf(_air, 0.0, _climb_max)
	_vy = 0.0
	_climb_dist = 0.0
	_climb_frame = 0
	velocity_x = 0.0
	# 사다리가 몸 어느 쪽에 있든 사다리를 마주 본다 (원화는 오른쪽을 보는 측면 자세)
	facing = 1 if ladder_x >= position.x else -1
	body.flip_h = facing < 0
	Audio.play_at("cloth", global_position, -2.0)
	_show_action_clip("climb", 0, false)


func _process_climb(delta: float, axis: float) -> void:
	var up := Input.is_action_pressed("interact") if input_enabled else false
	var down := Input.is_action_pressed("crouch") if input_enabled else false
	# 몸을 사다리 축 뒤로 붙인다 (손이 축에 오도록)
	var want_x := _climb_x - facing * CLIMB_HAND_X
	position.x = clampf(lerpf(position.x, want_x, minf(1.0, CLIMB_SNAP * delta)), min_x, max_x)
	var dir := (1.0 if up else 0.0) - (1.0 if down else 0.0)
	var dh := dir * CLIMB_SPEED * delta
	var prev := _air
	_air = clampf(_air + dh, 0.0, _climb_max)
	_climb_dist += _air - prev
	var f := int(floorf(_climb_dist / CLIMB_STEP))
	var n: int = maxi(1, (_move_frames.get("climb", []) as Array).size())
	var frame := posmod(f, n)
	if frame != _climb_frame:
		_climb_frame = frame
		if frame == 0 or frame == 2:
			Audio.play_at("footstep", global_position, -12.0)
	# 바닥에서 아래를 누르면 내려선다 · 좌우를 누르면 손을 놓는다 (높으면 떨어진다)
	if _air <= 0.0 and down:
		_end_air()
		return
	if absf(axis) > 0.5:
		velocity_x = axis * WALK_SPEED * 0.4
		if _air > 0.0:
			_start_fall()
		else:
			_end_air()
		return
	_show_action_clip("climb", _climb_frame, false)


## 머리 위치·회전 갱신. 몸 프레임에 맞는 머리 텍스처를 고르고 목 앵커에 붙인 뒤,
## 조준 방향으로 HEAD_MAX_ANGLE 안에서만 기울인다. 구르기 중엔 기울이지 않는다(몸과 함께 회전).
func _update_head(delta: float, snap := false) -> void:
	if action_visual != null and action_visual.visible:
		head.visible = false
		action_visual.flip_h = facing < 0
		return
	if reload_upper != null and reload_upper.visible:
		head.visible = false
		return
	var key := "%s_%02d" % [body.animation, body.frame + 1]
	var tex: Texture2D = _head_tex.get(key)
	head.visible = tex != null
	if tex == null:
		return
	head.texture = tex
	var neck: Vector2 = _necks.get(key, DEFAULT_NECK)
	# 머리 텍스처는 몸통 셀 그대로 — 목 픽셀이 원점에 오도록 오프셋
	head.offset = -(neck + Vector2(FRAME_SIZE * 0.5, FRAME_SIZE))
	# 목 앵커: 몸 스프라이트 로컬(=BodyPivot 로컬)에서 목 픽셀 위치. flip_h 는 셀 중심 기준 반전이므로 x 부호만 뒤집는다.
	head_pivot.position = body.offset + Vector2(FRAME_SIZE * 0.5, FRAME_SIZE) + Vector2(neck.x * facing, neck.y)

	var base := 0.0 if facing > 0 else PI
	var rel := 0.0
	if state != State.ROLL:
		# 대기 모드면 조준점 대신 **발치**를 본다. 각도를 직접 넣지 않고 바라볼 점만 바꾸는 이유는,
		# 좌우 반전(head_pivot.scale.y = -1)과 각도 한계(HEAD_MAX_ANGLE)를 이미 아래 식이 다루기 때문이다.
		var look: Vector2 = aim_target
		if standby:
			look = head_pivot.global_position + Vector2(float(facing) * 40.0, 260.0)
		var to_target := look - head_pivot.global_position
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
	head_pivot.rotation = _head_angle + float(rp["head_rad"]) * head_k * (-1.0 if facing > 0 else 1.0) 		+ _idle_head_rot * (1.0 if facing > 0 else -1.0)   # HeadPivot 은 좌향일 때 y 반전이라 부호를 되돌린다
	head_pivot.position.x += -facing * float(rp["head_px"]) * head_k
	head_pivot.position += _idle_head_off                 # 아이들: 머리가 몸보다 한 박 늦게 오르내린다
	head_pivot.skew = -body_pivot.skew         # 몸통 전단이 머리 스프라이트를 찌그러뜨리지 않게 상쇄


## 아이들 모션: 발 위치를 고정한 채 상체를 스쿼시&스트레치 + 좌우 무게중심으로 흔든다.
## 결과는 네 곳으로 나간다 — BodyPivot(스케일·전단), 머리(_idle_head_*), 어깨(_idle_arm_off),
## 그리고 _breath 를 통해 어깨·목 앵커. 이동 중에는 _idle_w 가 빠지며 자연스럽게 꺼진다.
func _update_idle(delta: float) -> void:
	var p := idle_preset()
	# 대기 모드에서는 아이들을 끈다. 플래그로 즉시 0 을 넣지 않고 active 만 내려 두면
	# _idle_w 가 IDLE_BLEND_OUT 로 부드럽게 빠진다 — 숨이 잦아들듯 멈춘다.
	var active := (state == State.IDLE or (state == State.CROUCH and _cw_w < 0.5)) and not standby
	_idle_w = move_toward(_idle_w, 1.0 if active else 0.0,
		delta * (IDLE_BLEND_IN if active else IDLE_BLEND_OUT))
	if active:
		_idle_t += delta
	elif _idle_w <= 0.0:
		_idle_t = 0.0

	# 강조 동작: 주기마다 스프링에 임펄스 한 방. 부호를 매번 뒤집어 같은 동작이 반복돼 보이지 않게 한다.
	var period := float(p.get("accent_period", 0.0))
	if active and period > 0.0:
		_idle_acc_t -= delta
		if _idle_acc_t <= 0.0:
			_idle_acc_t = period + randf_range(-1.0, 1.0) * float(p.get("accent_jitter", 0.0))
			_idle_acc.y += float(p.get("accent_imp", 0.0)) * (1.0 if randf() < 0.5 else -1.0)
	else:
		_idle_acc_t = 0.0
	_idle_acc = _spring(_idle_acc, p.get("accent", Vector3(900.0, 44.0, 0.0)), delta)

	var w := _idle_w * (float(p.get("crouch", 0.5)) if state == State.CROUCH else 1.0)
	var pop := float(p["pop"])
	var steps := int(p.get("steps", 0))
	# 시간을 frame_fps 로 계단화한다. 자세를 만드는 모든 값이 **같은 순간**을 보게 해야
	# 머리·어깨·좌우가 따로 놀지 않고 한 장의 그림처럼 통째로 바뀐다 (강조 스프링까지 포함).
	var fps := float(p.get("frame_fps", 0.0))
	var qt: float = floor(_idle_t * fps) / fps if fps > 0.0 else _idle_t
	var phase := qt * float(p["hz"])
	var main := _wave(phase, pop, steps)
	var lag := _wave(phase - float(p.get("head_lag", 0.0)), pop, steps)   # 머리·어깨는 한 박 늦게
	var sway := sin(TAU * qt * float(p.get("lean_hz", 0.0)))
	if fps > 0.0:
		var frame := int(floor(_idle_t * fps))
		if frame != _idle_frame:
			_idle_frame = frame
			_idle_acc_q = _idle_acc.x        # 강조도 프레임이 바뀔 때만 새로 읽는다
	else:
		_idle_frame = -1
		_idle_acc_q = _idle_acc.x
	var acc := _idle_acc_q
	var acc_sq := float(p.get("acc_squash", 0.0)) * acc
	var sq: Vector2 = p["squash"]
	# 세로로 늘면 가로는 줄어든다 (부피 보존 흉내). 발은 아래 위치 보정으로 고정된다.
	_breath = Vector2(1.0 - (sq.x * main + acc_sq * 0.7) * w, 1.0 + (sq.y * main + acc_sq) * w)
	var snap := float(p.get("snap_px", 0.0))
	_idle_head_off = Vector2(0, _snap(-(float(p.get("head_px", 0.0)) * lag + float(p.get("acc_head_px", 0.0)) * acc) * w, snap))
	_idle_head_rot = (float(p.get("head_rad", 0.0)) * sway + float(p.get("acc_head_rad", 0.0)) * acc) * w * float(facing)
	_idle_arm_off = Vector2(0, _snap(-(float(p.get("arm_px", 0.0)) * lag + float(p.get("acc_arm_px", 0.0)) * acc) * w, snap))
	var idle_lean := _snap((float(p.get("lean_px", 0.0)) * sway + float(p.get("acc_lean_px", 0.0)) * acc) * w * float(facing), snap)

	# 반동: 발은 고정(마찰)하고 상체만 뒤로 밀린다 — 전단(skew) + 발 위치 보정, 여기에 눌림(scale.y)
	var rp := recoil_preset()
	var body_k := _body_rc.x
	var lean := -facing * float(rp["body_px"]) * body_k + idle_lean + _cw_waddle_x()   # 머리 높이에서의 X 이동량
	var sy := _breath.y * (1.0 - float(rp.get("body_squat", 0.0)) * absf(body_k)) * _cw_scale()
	body_pivot.scale = Vector2(_breath.x, sy)
	# skew: 로컬 y 에 비례해 x 가 -sin(skew)·y 만큼 밀린다. 머리(y=-C) 는 +sin·C, 발(y=+C) 은 -sin·C 로 반대 →
	# 반씩 나눠 skew 로 만들고 나머지 반은 위치로 보정하면 발 0 · 머리 lean
	var half := clampf(lean * 0.5 / BODY_CENTER_Y, -0.6, 0.6)
	body_pivot.skew = asin(half)
	body_pivot.position = Vector2(lean * 0.5, -BODY_CENTER_Y * sy)
	body_pivot.rotation = 0.0


func _fire() -> void:
	var d := WeaponCatalog.data(weapon_id)
	var k := float(d.recoil)
	_fire_cd = float(d.cooldown)
	ammo -= 1
	cancel_charge()
	_update_arm(0.0, true)
	var shot_origin := muzzle.global_position
	# 총구 화염 + 라이트 — 기존 소총과 같은 스프라이트·라이트를 무기 배율로 키운다
	_flash_t = FLASH_TIME * (1.8 if weapon_id == WeaponCatalog.BULLDOG else 1.4)
	flash.visible = true
	flash.rotation = randf_range(-0.3, 0.3)
	flash.scale = Vector2.ONE * randf_range(0.85, 1.25) * float(d.flash)
	muzzle_light.enabled = true
	muzzle_light.energy = LightTuning.value("muzzle_hold", "energy", 4.5) * float(d.light)
	_muzzle_light_t = MUZZLE_LIGHT_FADE * 1.4
	# 반동 임펄스: 팔은 즉시 속도 임펄스(뒤로 확 → 앞으로 되튐), 머리·몸통은 지연 뒤 (절차적 연쇄) — 무기 배율 k
	var rp := recoil_preset()
	_arm_rc.y += float(rp["arm_imp"]) * k
	_pending.append({"t": rp["arm"].z + rp["head"].z, "part": "head", "k": k})
	_pending.append({"t": rp["arm"].z + rp["body"].z, "part": "body", "k": k})
	# 몸이 뒤로 밀린다 (발이 미끄러진다). 구르기·점프·사다리 중엔 쏘지 않으므로 지상 상태만 온다
	var kick := float(d.kickback) * (CROUCH_KICKBACK if state == State.CROUCH else 1.0)
	velocity_x -= float(facing) * kick
	_slide_t = maxf(_slide_t, 0.08)
	var target := aim_target
	_heat = minf(_heat + HEAT_PER_SHOT, 1.0)
	# 발사음 — 기존 소총 4레이어(보디·두께·어택·저역)를 뼈대로 무기별 층을 얹는다
	match weapon_id:
		WeaponCatalog.BULLDOG:
			Audio.fire(shot_origin, 1.5)
			Audio.play_at("fire_body", shot_origin, 1.0, 0.74)
			Audio.play_at("fire_sub", shot_origin, 3.0, 0.8)
			WeaponAudio.play(get_parent(), shot_origin, "thump", -2.0)
			_pump_t = PUMP_DELAY
		WeaponCatalog.COIL:
			Audio.play_at("fire_attack", shot_origin, 4.0, 1.35)
			Audio.play_at("fire_sub", shot_origin, 2.0, 1.1)
			Audio.play_at("turret_crack", shot_origin, 4.0, 0.8)
			WeaponAudio.play(get_parent(), shot_origin, "coil", -1.0, randf_range(0.96, 1.04))
	shoot_fired.emit(shot_origin, target)
	ammo_changed.emit(ammo, magazine_size(), false)
	if ammo <= 0:
		start_reload()


## 불독 펌프 — 발사 PUMP_DELAY 뒤 총을 한 번 더 짧게 당기며 탄피를 뱉는다 ("쾅 — 척칵")
func _pump() -> void:
	if weapon_id != WeaponCatalog.BULLDOG:
		return
	_arm_rc.y += float(recoil_preset()["arm_imp"]) * 0.45
	WeaponAudio.play(get_parent(), muzzle.global_position, "pump", -7.0)
	shell_ejected.emit(arm_pivot.to_global(_eject_local), facing)


## 코일 충전 — 총구 앞으로 사방에서 전하 조각이 빨려 들어가고 가운데 심이 커진다. 다 차면 번쩍.
## ChargeFx 는 팔 아래(무기 배율이 없는 층)라 월드 px 로 그린다.
func _draw_charge() -> void:
	var ck := charge_ratio() if _charge > 0.0 else 0.0
	if ck <= 0.0:
		return
	var c: Color = WeaponCatalog.data(weapon_id).color
	var t := Time.get_ticks_msec() * 0.001
	for i in range(10):
		var a := float(i) * TAU / 10.0 + t * 7.0 + float(i % 3)
		var r := (1.0 - fposmod(ck * 1.7 + float(i) * 0.13, 1.0)) * 110.0 + 10.0
		var p := (Vector2.from_angle(a) * r / 4.0).round() * 4.0
		_charge_fx.draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4) * (1.0 + ck)), Color(c.lightened(0.3), 0.4 + 0.6 * ck))
	var core := roundf((8.0 + ck * 28.0) / 4.0) * 4.0
	_charge_fx.draw_rect(Rect2(Vector2(-core, -core) * 0.5, Vector2(core, core)), Color(c, 0.5 + 0.5 * ck))
	_charge_fx.draw_rect(Rect2(Vector2(-core, -core) * 0.25, Vector2(core, core) * 0.5), Color(0.9, 1, 1, ck))
	if ck > 0.85:
		var h := 36.0 * (ck - 0.85) / 0.15
		_charge_fx.draw_line(Vector2(0, -h), Vector2(0, h), Color(0.9, 1, 1, 0.8), 4.0)
		_charge_fx.draw_line(Vector2(-h * 1.6, 0), Vector2(h * 1.6, 0), Color(c, 0.8), 4.0)


func spread_ratio() -> float:
	return _heat


## 어깨 위치·팔 회전 갱신. 몸 애니 프레임에 맞춰 어깨 앵커를 따라간다.
func _update_arm(delta: float, snap := false) -> void:
	if action_visual != null and action_visual.visible:
		arm_pivot.visible = false
		action_visual.flip_h = facing < 0
		return
	if reload_upper != null and reload_upper.visible:
		arm_pivot.visible = false
		return
	if state == State.ROLL:
		arm_pivot.visible = false
		return
	arm_pivot.visible = true

	var key := "%s_%02d" % [body.animation, body.frame + 1]
	var shoulder: Vector2 = _shoulders.get(key, DEFAULT_SHOULDER)
	shoulder.x *= facing
	arm_pivot.position = shoulder * _breath + _idle_arm_off   # 아이들 스케일에 맞춰 어깨도 따라가고, 들썩임이 더해진다
	# 앉아 걷기: 몸통과 같은 눌림·실림을 어깨 높이만큼 받는다 (발 고정 스케일·전단이라 높이에 비례)
	var h := -shoulder.y
	arm_pivot.position += Vector2(_cw_waddle_x() * h / (2.0 * BODY_CENTER_Y), -h * (_cw_scale() - 1.0))

	var to_target := aim_target - arm_pivot.global_position
	var target_angle := to_target.angle()
	if reloading:
		# 재장전: 팔이 아래로 내려가 총을 두 번 흔든다 (빼기·끼우기)
		var k := clampf(_reload_t / reload_duration(), 0.0, 1.0)
		var drop := sin(k * PI)                                   # 0 → 1 → 0
		var jiggle := sin(k * TAU * 2.0) * 0.12 * drop
		var base := 0.0 if facing > 0 else PI
		target_angle = base + (RELOAD_ARM_DROP * drop + jiggle) * (1.0 if facing > 0 else -1.0)
	elif _swap_t > 0.0:
		# 무기 교체: 총구가 아래로 떨어졌다가 새 총이 조준선으로 튀어 올라온다
		var sk := sin(_swap_t / SWAP_TIME * PI)
		target_angle += 0.9 * sk * (1.0 if facing > 0 else -1.0)
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
	var climb := float(WeaponCatalog.data(weapon_id).climb)
	var kick_angle := float(rp["arm_rad"]) * climb * arm_k * (-1.0 if facing > 0 else 1.0)
	# 충전 중 떨림 — 다 찰수록 총이 부르르 떤다 (1px 단위로 튄다)
	var tremble := Vector2.ZERO
	if _charge > 0.0:
		var ck := charge_ratio()
		tremble = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).round() * (1.0 + 3.0 * ck * ck)
	arm_pivot.rotation = _arm_angle + kick_angle
	arm.position = Vector2(-float(rp["arm_px"]) * arm_k * 0.8, 0) + tremble


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
	_idle_w = 0.0
	_idle_t = 0.0
	_idle_acc = Vector2.ZERO
	_idle_head_off = Vector2.ZERO
	_idle_head_rot = 0.0
	_idle_arm_off = Vector2.ZERO
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
	_move_obstacle_x(_roll_dir * step)
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


## 구르기 진행률 0..1 (구르는 중이 아니면 -1). 규격 테스트 씬이 구르기 중 판정 높이를 고를 때 쓴다.
func roll_progress() -> float:
	return clampf(_roll_t / ROLL_TIME, 0.0, 1.0) if state == State.ROLL else -1.0


## 웅크린 자세인가 (앉는 중·일어서는 중 포함)
func is_crouching() -> bool:
	return state == State.CROUCH or state == State.UNCROUCH


## 외부 충격(몬스터 독액)으로 밀린다. 구르기 중엔 무시(회피).
func knockback(vx: float) -> void:
	if state == State.ROLL or state == State.CLIMB:
		return
	velocity_x = vx


## 발이 바닥에서 떠 있는 높이 (점프·사다리, px). 몸 판정은 position.y - air_height() 를 발로 본다.
func air_height() -> float:
	return _air

func _obstacle_floor() -> float:
	return float(weapon_room.floor_y)+2.0 if is_instance_valid(weapon_room) and weapon_room.has_method("obstacle_support") else position.y

func _move_obstacle_x(amount: float) -> void:
	var next := clampf(position.x+amount,min_x,max_x)
	if is_instance_valid(weapon_room) and weapon_room.has_method("obstacle_move_x"):
		var stopped: float = weapon_room.obstacle_move_x(position.x,next,position.y-_air,120.0 if is_rolling() or is_crouching() else 210.0)
		if absf(stopped-next)>0.01:
			velocity_x = 0.0
		next = stopped
	position.x = next
	_update_obstacle_support()

func _update_obstacle_support() -> void:
	if not is_instance_valid(weapon_room) or not weapon_room.has_method("obstacle_support"):
		return
	if state == State.CLIMB or (state == State.JUMP and _jump_phase != 2):
		return
	var support: float = weapon_room.obstacle_support(position.x,position.y)
	if support > position.y+3.0:
		_air = _obstacle_floor()-position.y
		position.y = _obstacle_floor()
		_start_fall()

func receive_explosion_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0,health-maxf(amount,0.0))
	health_changed.emit(health)
	if health <= 0.0:
		incapacitated.emit()

func restore_health() -> void:
	health = 100.0
	health_changed.emit(health)


## 점프 중이거나 사다리에 매달려 있다
func is_airborne() -> bool:
	return state == State.JUMP or state == State.CLIMB


func is_climbing() -> bool:
	return state == State.CLIMB


## 방을 옮기는 등 위치를 바깥에서 새로 잡을 때 — 공중·사다리 상태를 끊고 바닥에 세운다
func settle() -> void:
	cancel_charge()
	if state == State.JUMP or state == State.CLIMB:
		_end_air()
