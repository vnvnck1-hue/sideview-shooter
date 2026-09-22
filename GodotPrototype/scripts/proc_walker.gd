class_name ProcWalker
extends Node2D
const GaitSettings = preload("res://scripts/walker_gait_settings.gd")
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
## ── 규격은 **원화에서 재어 넣는다** (2026-09-22) ─────────────────────────────
## quadruped_side_transparent_v1.png 을 0.34 배로 줄인 값이다. 조각을 자르는 도구가 같은 배율을
## 쓰므로(Tools/ImageProcessing/cut_quadruped_rig_parts.py 의 SCALE), 여기 수치와 그림이 맞는다.
## 이 수치를 고치면 그림이 관절에서 어긋난다 — 도구의 SCALE·상자와 **함께** 고쳐야 한다.
const BODY_HALF_W := 159.0        # 몸체 좌우 반폭 (원화 몸통 935px)
const BODY_TOP := -160.0          # 몸체 윗면 (원화 맨 위 후드까지, 원점 = 고관절 줄 한가운데)
const BODY_BOT := 60.0            # 몸체 아랫면. 원화의 **배·골반 프레임 아래**까지다 (반전 후 y=660) —
                                  # 49 로 뒀을 땐 그 선이 고관절 하우징 한가운데를 잘라, 원화 몸통을
                                  # 붙였을 때 다리가 허공에 매달렸다. 그리기에만 쓰는 값이라 걸음 예산과 무관하다.
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
## 정강이 = 원화의 **발목·발판** 한 마디다 (장갑판 아래의 짧은 조각). 원화를 재니 149px → 50.
## 150 에서 50 으로 줄면서 무릎이 고관절보다 **아래**로 내려왔다 — 원화의 다리가 실제로 그 모양이다
## (긴 유압판이 몸에서 내려오고 그 끝에 짧은 발). 도달 한계도 380 → 280 으로 줄지만,
## 여유 예산은 아래 계산대로 아직 넉넉하다.
const SHIN_LEN := 50.0            # 무릎 → 발 (원화 149px)
## 정강이의 **기준 각** — 수직에서 바깥쪽(몸 반대 방향)으로 이만큼 눕힌다. 무릎보다 발이 바깥으로 나가
## 거미처럼 벌린 다리가 된다. 0 이면 수직.
const SHIN_SPLAY := 0.26          # rad ≈ 15°
const SHIN_TILT_MAX := 0.20       # rad ≈ 11°. **기준 각에서** 더 벗어날 수 있는 폭
const THIGH_MIN := 34.0           # 스트럿이 줄어들 수 있는 최소 길이
## 스트럿이 늘어날 수 있는 최대 길이 = **다리의 도달 한계**.
## 정강이가 원화대로 50 으로 짧아지면서 다리 길이를 스트럿이 거의 혼자 감당하게 됐다 —
## 230 으로 두면 선 자세(172)에서 조금만 흔들려도 한계를 넘는다 (검증에서 250 까지 나왔다).
## 늘어난 만큼은 슬리브(128) 밖으로 나온 **가는 로드**로 보인다 — 유압다리의 그림 그대로다.
## 이 값을 바꿀 때는 로드 그림 길이(도구의 ROD_LEN)도 같이 바꿔야 한다.
const THIGH_MAX := 300.0
const LEASH_SCAN := 320.0         # 닿는 발자리를 찾아 훑는 좌우 범위 (px)
const SLEEVE_LEN := 137.0         # 유압 슬리브 = 원화의 초록 장갑판 (402px). 이 밖이 로드다.
                                  # 판 전체 길이와 같게 둔다 — 짧게 잡으면 판의 아래 테두리가 잘린다
const THIGH_W := 74.0             # 원화 장갑판 폭
const SHIN_W := 72.0              # 원화 발판 폭
const HIP_R := 25.0               # 고관절 원 (원화 실린더 50px)
const KNEE_R := 30.0              # 무릎 원
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

## ## 본편 기체의 걸음새 — **거미** (2026-09-22)
## 랩의 6번 프리셋과 **같은 값**이다. 예전엔 랩에만 있었는데, 본편 기체(walker_unit.gd)가 이걸 쓰면서
## 두 벌이 되면 "랩에서 맞춘 걸음과 게임 안의 걸음이 다른" 상황이 생긴다. 그래서 값은 여기 한 벌만 두고
## walker_lab.gd 의 PRESETS 가 이걸 가져다 이름만 붙인다.
##
## 한 발씩만 띄운다 — 늘 세 발이 땅에 붙어 있다. 아주 짧고 잦게 딛는다(스텝 0.06초).
## 한 발씩이면 한 주기가 두 배(4번 나눠 딛는다)라 같은 속도에서 발이 두 배 밀린다 —
## 그래서 속도를 430 → 340 으로 낮췄다 (달리기 ×1.7 까지 예산 안에 들도록).
## 몸은 낮게 깔고 거의 흔들지 않으며(진동 4) 발도 낮게 끈다 — 트롯처럼 통통 뛰지 않고 사각사각 기어간다.
const GAIT_SPIDER := {
	"speed": 340.0, "ride": 182.0, "stride": 0.90, "trigger": 30.0, "lift": 45.0,
	"step_time": 0.06, "hold": 0.03, "lead": 0.22, "tilt": 0.0, "bob": 4.0,
	"aim_lean": 0.5, "legs_up": 1.0,
}

const C_BODY := Color(0.573, 0.737, 0.765)
const C_BODY_DARK := Color(0.408, 0.549, 0.588)
const C_JOINT := Color(0.518, 0.518, 0.878)
const C_THIGH := Color(0.902, 0.549, 0.784)
const C_THIGH_ROD := Color(0.70, 0.38, 0.60)   # 슬리브 밖으로 나온 로드 (조금 어둡게)
const C_SHIN := Color(0.851, 0.761, 0.369)
const FAR_MUL := 0.62             # 먼 쌍을 어둡게 (DepthLayers 의 층 분리와 같은 취지)
const FAR_RAISE := 16.0           # 먼 쌍의 발을 이만큼 위로 **그린다** (판정은 그대로).
                                  # 측면뷰에서 두 쌍이 같은 줄에 붙으면 다리가 둘로만 보인다

## ── 사선(3/4) 시점 ──────────────────────────────────────────────────────────
## 컨셉 원화(quadruped_robot_faithful_detailed_pixel.png)는 완전 측면이 아니라 **살짝 사선**이다.
## 네 다리가 2×2 로 흩어져 보이고, 몸통·포신이 두께를 가진 상자로 읽힌다.
##
## **걸음 계산은 손대지 않는다.** 보행은 지금처럼 순수 1차원(x) 측면 문제로 두고,
## 깊이는 **그릴 때만** 화면 오프셋으로 얹는다 (오블리크/캐비닛 투영과 같은 방식):
##     화면 위치 = 측면 위치 + DEPTH × z          z: 0 = 가까운 쌍 · 1 = 먼 쌍
## 이렇게 하면 도달 한계·여유 예산·검증 도구(tools/validate_walker.gd)가 전부 그대로 성립한다.
## 깊이를 판정에 넣으면 스트럿 길이 계산이 3차원이 되고 위 문서의 예산 계산이 전부 무효가 된다.
##
## dx 는 **바라보는 쪽 기준**이다 (facing 을 곱한다 — 스프라이트를 뒤집는 것과 같은 관례).
## **양수 = 앞쪽 사선**(카메라가 로봇 앞에 있다. 원화처럼 앞면·포구가 보인다) · 음수 = 뒤쪽 사선.
##
## 부호를 거꾸로 잡아 한 번 헛디뎠다. 압출에서 **보이는 옆면은 밀린 방향(off) 쪽 변**이다 —
## 먼 쪽을 뒤로 밀면 드러나는 면이 뒷면이라 뒷모습 사선이 된다.
## 차를 떠올리면 쉽다: 오른쪽을 향한 차의 앞모습 사선에서는 **가까운 측면보다 먼 측면이 더 앞에 있어**
## 그 사이로 앞범퍼가 보인다. 즉 먼 쪽이 바라보는 쪽으로 밀려야 앞면이 드러난다.
const VIEW_DEFAULTS := {
	"oblique": 1.0,    # 0 = 예전 순수 측면 · 1 = 사선
	# dx·dy 는 **컨셉 원화에서 재고, 랩에서 눈으로 마무리한 값**이다 (2026-09-22).
	# 반전한 원화에서 가까운 앞다리와 먼 앞다리의 같은 지점을 재면
	#     고관절  (706,596) → (985,600)   = (279, 4) 원화px = (95, 1.4) 월드
	#     발      (720,1122) → (1065,1100) = (345,-22) 원화px = (117,-7.5) 월드
	# 여기서 다리 자체의 a 차이(앞·먼 132 − 앞·가까 118 = 14)를 빼면 두 표본 모두 dx ≈ 102~103.
	# 그 자리에서 랩으로 미세 조정해 97 / -12 로 굳혔다 (걷는 걸 보면서 맞춘 값이라 이쪽을 따른다).
	"dx": 97.0,        # 먼 쪽이 화면에서 밀리는 양 (바라보는 쪽 기준, 양수 = 앞으로 = 앞모습 사선)
	"dy": -12.0,       # 먼 쪽이 올라가는 양 (음수 = 위로). **카메라 높이**다 —
	                   # 원화는 거의 눈높이에서 본 그림이라 -28 이 아니라 -12 다. 두 쌍을 갈라 놓는
	                   # 일은 dx 가 하고, dy 는 지면이 멀어지며 올라가는 몫만 맡는다.
	                   # (-28 로 두면 먼 발이 땅보다 20px 떠서 다리 넷이 서로 다른 바닥을 딛는다)
	# 아래 둘은 **그레이박스 전용**이다. 원화 리그는 먼 다리를 줄여 그리지 않고
	# 원화가 그려 둔 먼 다리 조각(sleeve_far 등)을 쓰므로 이 값을 보지 않는다 (walker_rig.gd LIMB_FAR).
	"shrink": 0.54,    # 먼 쪽을 이만큼 가늘게 그린다 (원근)
	"thick": 1.0,      # 팔다리 자체의 두께 — 깊이 벡터의 이 비율만큼 밀어 상자로 만든다
}
const SIDE_MUL := 0.80            # 옆면(밀려 나온 면) 밝기
const TOP_MUL := 1.14             # 윗면 밝기 — 위에서 빛을 받는 면이라 살짝 밝게

## ── 방향 전환 (yaw) ─────────────────────────────────────────────────────────
## **좌우를 뒤집지 않는다.** facing 을 ±1 로 홱 바꾸면 그림이 한 프레임에 거울처럼 뒤집혀
## 기계가 순간이동한 것으로 보인다. 대신 **몸이 실제로 돌아가는 각(yaw)** 을 들고 있는다.
##     yaw = 0     오른쪽을 본다 (완전 측면)
##     yaw = PI/2  **카메라를 정면으로** 본다 (돌아서는 중간)
##     yaw = PI    왼쪽을 본다
## 0 ↔ PI 사이를 단조롭게 지나가므로 전환은 늘 PI/2(정면)를 통과한다 — 앞모습을 스쳐 지나는 회전이다.
##
## 몸 로컬 좌표는 (a = 앞뒤 · u = 위아래 · s = 좌우 두께) 세 축으로 든다. s 는 **몸통 두께의 비율**로
## 오른쪽 면이 +0.5, 왼쪽 면이 -0.5 다. project() 가 이걸 화면 좌표로 옮긴다:
##     X = a·cos(yaw) + s·BODY_DEPTH·sin(yaw)
##     Z = (-a·sin(yaw))/BODY_DEPTH + s·cos(yaw)        (Z = 카메라에서 멀어지는 깊이, 두께 단위)
##     화면 = (X, u) + 깊이벡터 × Z
## yaw=0 을 넣으면 예전 그림과 정확히 같다 (X=a · Z=s → 먼 쌍과 가까운 쌍이 깊이벡터만큼 벌어진다).
## yaw=PI 에서는 X·Z 의 부호가 같이 뒤집힌다 — 좌우가 바뀌는 동시에 **먼 쌍과 가까운 쌍도 뒤바뀐다.**
## 그게 이 방식의 값어치다. 플립으로는 다리의 앞뒤 순서가 바뀌지 않는다.
const BODY_DEPTH := 150.0         # 몸통 두께(px). a 축 길이를 깊이 단위로 환산하는 자
const BODY_LEN := BODY_HALF_W * 2.0
## 돌아서는 데 걸리는 시간. 짧아야 한다 — 이 동안 실루엣이 납작해지므로.
const TURN_TIME := 0.26
## 측면 그림이 **너무 얇아지는 구간의 문턱**. fore_x() 의 절댓값이 이보다 작으면 측면 그림으로는
## 더 이상 기체를 설명할 수 없다 (그 각도에서 실제 실루엣의 폭은 몸통 두께 ÷ 길이 = 이 값이다).
## 그 구간을 **정면 전환 시트**로 덮는 것이 다음 단계다 — 지금은 문턱만 정해 두고 리그가 본다.
const SQUASH_MIN := BODY_DEPTH / BODY_LEN

## ── 다리 배치 ────────────────────────────────────────────────────────────────
## hip  : 몸체 로컬 고관절 위치 (x 는 바라보는 쪽이 +). **몸통 양 끝**에 붙인다 —
##        가운데로 몰면 허벅지가 배를 가로질러, 다리가 배 밑에 매달린 벌레 같은 실루엣이 된다
## rest : 가만히 섰을 때 발이 놓이는 몸체 기준 x. **고관절 바로 아래에 가깝게** 둔다.
##        벌릴수록 보기에는 듬직하지만, 벌린 만큼 뒷발의 뒤쪽 여유가 그대로 깎인다 —
##        뒷발은 rest 가 이미 뒤에 있는데 몸이 앞서며 더 뒤로 밀려, 두 성분이 더해지기 때문이다.
##        (rest 를 ±258 로 벌렸을 때 걸음 106 개 중 101 개가 긴급 스텝으로 났다)
## group: 대각 조 (0 / 1)
## side : 몸통 두께 축에서의 자리 (+0.5 = 오른쪽 면 · -0.5 = 왼쪽 면). 가운데를 0 으로 둔다 —
##        한쪽을 0 으로 잡으면 돌아설 때 회전 중심이 몸 한쪽 면에 걸려 몸이 휘청이며 돈다
const LEGS := [
	{"name": "뒤·먼", "hip": Vector2(-132.0, 40.0), "rest": -162.0, "near": false, "group": 1, "side": 0.5},
	{"name": "앞·먼", "hip": Vector2(132.0, 40.0), "rest": 162.0, "near": false, "group": 0, "side": 0.5},
	{"name": "뒤·가까", "hip": Vector2(-118.0, 50.0), "rest": -150.0, "near": true, "group": 0, "side": -0.5},
	{"name": "앞·가까", "hip": Vector2(118.0, 50.0), "rest": 150.0, "near": true, "group": 1, "side": -0.5},
]

## ── 기관총 (몸통 위 포탑) ────────────────────────────────────────────────────
## 센트리건(sentry_turret.gd)과 같은 규칙: 포인터를 **기계식 선회 속도로 늦게** 따라간다.
## 즉시 조준하면 기계 느낌이 죽고, 마우스를 휘두를 때 포신이 순간이동한다.
## 상체는 조준 방향으로 돌고, 포신은 월드 절대각으로 360° 조준한다. 하체의 접지는 유지한다.
## 요동축. **원화의 포가(금색 링) 중심**이다 — 포신이 몸통 위가 아니라 몸통 **안**에 박혀 있다.
## x 는 **양수**다: 포가는 몸통 앞쪽에 있고 포신이 거기서 더 앞으로 뻗는다.
## 원화를 좌우 반전해 자르기 시작하면서(cut_quadruped_rig_parts.py) a 축 실측값의 부호가 전부
## 뒤집혔는데 여기만 -81 로 남아 있었다 — 포신이 몸 안에서 시작해 몸통 앞쪽 절반이
## 포신 함몰부(검은 소켓)로 뚫린 채 남았다. a 축에서 잰 값은 반전과 **함께** 뒤집어야 한다.
const TURRET_PIVOT := Vector2(81.0, -55.0)
const BARREL_LEN := 163.0         # 요동축 → 총구 (원화 480px)
const BARREL_W := 46.0
const MOUNT_R := 42.0
const TURRET_RATE := 8.5                      # rad/s — 선회 속도 (작을수록 굼뜬 기계)
## 연사 간격. 센트리건(0.055초 ≈ 18발/초)과 **같은 연출에 연사력만 낮춘** 값이다 —
## 버그봇은 포신이 하나이고 구경이 굵다. 0.08초 ≈ 12발/초.
## WalkerUnit.HEAT_PER_SHOT 이 이 값에 비례해 한 발당 열을 나누므로 초당 과열 속도는 그대로다.
const FIRE_COOLDOWN := 0.08
const RECOIL_BACK := 30.0                     # 포신이 뒤로 물러나는 최대 거리
## 한 발마다 몸통 전체를 뒤로 때리는 반동. 포신 후퇴(RECOIL_BACK)와 별개로 **기체가** 밀린다.
## 속도 임펄스라 한 발은 짧고 세게 때리고, 낮은 감쇠가 그 뒤로 앞뒤 흔들림을 남긴다.
## 반동은 두 겹이다.
##   _kick : 한 발의 짧고 센 충격. 진동수는 연사 간격(0.08초)보다 빨라야 한다 — 느리면 발이
##           겹쳐 몸이 뒤로 눌린 채 멈추고 한 발 한 발의 타격감이 사라진다 (3.4Hz 에서 그랬다).
##   _push : 쏠수록 쌓이는 뒤쪽 밀림. 앞다리가 펴지고 뒷다리가 접히는 자세를 만든다.
## 둘 다 **몸통만** 옮긴다. 발 목표는 recoil_shift() 를 빼고 잡으므로 발은 제자리를 지킨다.
const RECOIL_KICK := 1500.0                   # px/s — 한 발이 몸통에 싣는 뒤쪽 속도
const RECOIL_KICK_MAX := 52.0                 # px — 몸통이 밀릴 수 있는 최대 거리 (다리가 따라올 범위)
const RECOIL_KICK_FREQ := 7.5                 # Hz — 제자리로 되튀는 빠르기
const RECOIL_KICK_DAMP := 0.22                # 낮을수록 앞뒤로 여러 번 출렁인다
const RECOIL_PUSH := 6.0                      # px — 한 발이 더 밀어내는 거리 (쌓인다)
const RECOIL_PUSH_MAX := 34.0                 # px — 버티다 못해 자리를 내주는 한계
const RECOIL_PUSH_RECOVER := 26.0             # px/s — 사격을 멈추면 이 속도로 제자리를 되찾는다
const RECOIL_PUSH_LEAN := 0.0026              # rad/px — 밀린 만큼 몸통이 뒤로 젖혀진다
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
	## 아래 두 값은 **원화의 선 자세에서 거꾸로 계산한 값**이다 (2026-09-22).
	## 원화는 초록 유압판이 몸통에서 거의 **수직으로** 내려와 짧은 발에 닿는다. 그 그림이 나오려면
	##   ride  = 발에서 고관절까지(원화 505px → 172) + hip.u(40) = 212
	##   stride: 발이 고관절 **바로 아래**에 와야 하므로 rest×stride ≒ |hip| → 162×0.82 ≒ 133 ≒ 132
	## 예전 값(135 / 1.18)은 그레이박스 시절의 긴 정강이(150)에 맞춘 것으로, 그대로 두면
	## 유압판이 옆으로 누워 다리가 게처럼 벌어진다 (원화와 전혀 다른 실루엣이 나왔다).
	"ride": 212.0,        # 지면에서 몸체 원점까지 (다리를 얼마나 펴고 서는가)
	"stride": 0.82,       # **다리 벌림** — LEGS.rest 에 곱한다. 보폭이 아니다 (보폭은 trigger)
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
## 본편의 거미형 관절. 기존 실험 프리셋은 이 스위치를 켜지 않고 그대로 사용한다.
var spider_gait := false
var anatomy_path := "res://authoring/walker_motion.json"
var tuning_path := GaitSettings.DEFAULT_PATH
var tuning_error := ""
var _spider: RefCounted

## 그레이박스 그림을 그릴 것인가. 원화 파츠 리그(walker_rig.gd)가 붙으면 끈다.
var draw_greybox := true

var tune := DEFAULTS.duplicate()
var view := VIEW_DEFAULTS.duplicate()   # 그림 시점만 바꾼다 — 걸음 계산에는 들어가지 않는다
var body_pos := Vector2.ZERO
var facing := 1                   # 걸음 계산용 **이산** 방향. yaw 가 PI/2 를 지날 때 바뀐다
var yaw := 0.0                    # 몸이 실제로 돌아간 각 (0 = 오른쪽 · PI = 왼쪽). 그림은 이걸 쓴다
var _yaw_want := 0.0              # 목표 yaw (0 또는 PI)
var speed := 0.0                  # 현재 수평 속도 (부호 있음)
var airborne := false

var _legs: Array = []
var _angle := 0.0
var _body_velocity := 0.0         # 접지 높이에 매달린 서스펜션. 발은 그대로 두고 질량만 늦게 따라온다.
var _angle_velocity := 0.0
var _motion := 0.0               # 정지할 때 걸음 진동이 남지 않도록 속도를 부드럽게 섞는다.
var _acceleration := 0.0
var _idle_time := 0.0
var _jump_windup := 0.0
var _landing_compression := 0.0
const JUMP_WINDUP := 0.105
var _air_v := 0.0
var _walked := 0.0                # 누적 이동 거리 — 몸 상하 진동(bob)의 위상
var _all_down := 0.0              # 네 발이 모두 붙어 있은 시간 (초). tune.hold 가 이걸 본다
var _turret := 0.0                # 포신의 **월드** 각 (몸 기울기와 무관하게 절대각으로 관리한다)
var _recoil := 0.0
var _fire_cd := 0.0
var _flash := 0.0
var _aim_pitch := 0.0             # -1(아래) ~ +1(위) — 몸이 조준을 따라 젖히는 정도
## 하체 방향과 독립된 상체 선회. 조준으로 접지 발을 뒤집지 않는다.
var torso_yaw := 0.0
var _torso_want := 0.0
var _torso_from := 0.0
var _torso_time := 1.0
var _aim_velocity := 0.0
var _recoil_velocity := 0.0
var _kick := 0.0                  # 한 발의 짧은 충격으로 몸통이 밀려 있는 거리 (px, 월드 x)
var _kick_velocity := 0.0
var _push := 0.0                  # 연사가 쌓아 놓은 뒤쪽 밀림 (px, 월드 x). 부호는 뒤쪽이 양수다.
var _push_dir := 0.0              # 그 밀림의 방향 (마지막으로 쏜 방향의 반대)
var _shift := 0.0                 # 사격 반동 오프셋 (px). 프레임당 한 번 갱신한다.
var _shift_on := false            # 지금 body_pos 가 그 오프셋을 품고 있는가 (걸음 계산 중에는 false)

## 진단용 집계 — 걸음이 무엇 때문에 났는가. urgent 가 대부분이면 다리 길이/보폭 비례가 잘못된 것이다
## (정상 판정(trigger)보다 도달 한계가 먼저 와서, 접지 유지 같은 제동이 전부 무시된다)
var steps_normal := 0
var steps_urgent := 0


func _ready() -> void:
	reset_stance()


## 시작 시 한 번 읽는다. 파일이 없으면 기본값을 사용하며 저장 파일을 만들지 않는다.
## 피벗 문서는 별도의 anatomy_path에서 읽어 원본 좌표와 보행 수치를 분리한다.
func initialize_spider_tuning(path: String = GaitSettings.DEFAULT_PATH) -> Error:
	tuning_path = path
	var settings := GaitSettings.new()
	var error: Error = OK
	if FileAccess.file_exists(path):
		error = settings.load_file(path)
	spider_gait = true
	apply_spider_tuning(settings.values)
	tuning_error = settings.last_error
	if _spider == null:
		spider_ride_height()
	return error


## 모든 값을 먼저 검증한 다음 교체한다. 접점·스텝 진행률·바인드 길이는 유지된다.
func apply_spider_tuning(values: Dictionary) -> bool:
	if not GaitSettings.validate_values(values):
		tuning_error = "보행 설정의 항목 또는 값이 올바르지 않습니다."
		return false
	var next := tune.duplicate(true)
	next.merge(values, true)
	tune = next
	if spider_gait and _spider != null and not _legs.is_empty():
		_spider.solve(self)
		queue_redraw()
	tuning_error = ""
	return true


func spider_ride_height() -> float:
	if _spider == null:
		_spider = preload("res://scripts/walker_spider_adapter.gd").new()
		_spider.configure(anatomy_path)
	return float(_spider.standing_height)


## 현재 몸체 위치를 기준으로 네 발을 제자리에 내려놓는다 (씬 시작 · Z 초기화 · 착지 직후)
func reset_stance() -> void:
	_legs.clear()
	_body_velocity = 0.0
	_angle_velocity = 0.0
	_release_recoil()
	_shift = 0.0
	_kick = 0.0
	_kick_velocity = 0.0
	_push = 0.0
	_acceleration = 0.0
	_motion = 0.0
	_jump_windup = 0.0
	_landing_compression = 0.0
	if spider_gait:
		if _spider == null:
			spider_ride_height()
		_spider.reset(self)
		position = body_pos
		rotation = _angle
		queue_redraw()
		return
	for d in LEGS:
		var leg := {
			"name": d["name"], "hip": d["hip"] as Vector2, "rest": d["rest"] as float,
			"near": d["near"] as bool, "group": d["group"] as int, "side": d["side"] as float,
			"foot": Vector2.ZERO, "from": Vector2.ZERO, "to": Vector2.ZERO,
			"t": 0.0, "dur": 0.2, "stepping": false, "lift": 0.0, "roll": 0.0,
		}
		leg["foot"] = _desired(leg, 0.0)
		_legs.append(leg)
	_sync_body_to_feet(0.0, true)
	position = body_pos
	rotation = _angle
	queue_redraw()


func jump() -> void:
	if airborne or _jump_windup > 0.0:
		return
	# 짧게 체중을 싣고 튀어 오른다. 이동 입력은 계속 반응한다.
	_jump_windup = JUMP_WINDUP
	_body_velocity += 90.0


## 한 프레임. 쓰는 쪽이 input_dir / running / drag_to 를 채운 뒤 부른다.
func tick(delta: float) -> void:
	if spider_gait:
		if _spider == null:
			reset_stance()
		# Contact switches use the same small integration interval at 30/60/120 Hz.
		var count := maxi(1, ceili(delta * 120.0 - 0.000001))
		_release_recoil()
		for iteration in count:
			# 그림용 관절 풀이는 마지막 서브스텝에서 한 번만 — 중간 자세는 그려지지 않는다.
			_tick_spider_step(delta / float(count), iteration == count - 1)
		_apply_recoil(delta)
		if not is_zero_approx(_shift):
			_hold_recoil()
			_spider.solve(self)             # 밀린 몸통에 맞춰 다리 각도만 다시 푼다 (발은 그대로)
			position = body_pos
		queue_redraw()
		return
	_idle_time += delta
	_landing_compression *= exp(-delta * 9.0)
	_release_recoil()
	_tick_yaw(delta)                        # 먼저 몸을 돌린다 — facing 이 여기서 바뀐다
	_move_body(delta)
	_tick_legs(delta)
	if not airborne:
		_sync_body_to_feet(delta)
	_leash_feet()                           # 몸 자세가 확정된 뒤에 — 그래야 한 박자 늦지 않는다
	_apply_recoil(delta)
	_hold_recoil()
	position = body_pos
	rotation = _angle
	_tick_turret(delta)                     # 최종 자세에서 조준·발사해야 그려진 총구와 탄이 일치한다
	queue_redraw()


func _tick_spider_step(delta: float, draw := true) -> void:
	_idle_time += delta
	_landing_compression *= exp(-delta * 9.0)
	var previous := body_pos
	var previous_angle := _angle
	_move_body(delta)
	if not airborne:
		_sync_body_to_feet(delta)
	_spider.tick(self, delta, previous, previous_angle, draw)
	# 조준·발사는 그려지는 자리에서 한다 — 그래야 총구와 탄이 그림과 같은 자리에서 나간다.
	_hold_recoil()
	position = body_pos
	rotation = _angle
	_tick_turret(delta)
	_release_recoil()


# ── 기관총 ───────────────────────────────────────────────────────────────────

## 요동축의 월드 좌표. 몸 기울기를 같이 받는다.
func turret_pivot() -> Vector2:
	return body_pos + body_project(TURRET_PIVOT.x, TURRET_PIVOT.y, 0.0).rotated(_angle)


## 반동까지 반영한 총구 위치. 상체 포가를 따라가되 총열 길이와 월드 조준 방향을 유지한다.
func muzzle() -> Vector2:
	return _barrel_tip(BARREL_LEN - _recoil)


## 포신·탄·예광이 공유하는 월드 방향.
func aim_dir() -> Vector2:
	return Vector2.RIGHT.rotated(_turret)


## 요동축에서 포신 방향으로 len 만큼 간 점 — **몸통 원점 기준 화면 좌표**.
## 요동축은 상체를 따르고 포신 방향은 몸 기울기를 상쇄한다.
func _turret_local(len: float) -> Vector2:
	# 조준은 월드 절대각이다. 상체가 돌아가거나 기울어도 포신/탄도가 같이 보정된다.
	return body_project(TURRET_PIVOT.x, TURRET_PIVOT.y, 0.0) + aim_dir().rotated(-_angle) * len


## 같은 점의 월드 좌표
func _barrel_tip(len: float) -> Vector2:
	return body_pos + _turret_local(len).rotated(_angle)


## 각속도를 부드럽게 가감속하며 최단 각도로 조준한다. 이동 방향과 상체 회전에는 제약을 주지 않는다.
func _tick_turret(delta: float) -> void:
	# 빠른 타격 뒤 천천히 복원되는 임계 감쇠. 프레임 속도와 무관하게 같은 반동을 낸다.
	var decay := exp(-22.0 * delta)
	var recoil_j := _recoil_velocity + 22.0 * _recoil
	_recoil = (_recoil + recoil_j * delta) * decay
	_recoil_velocity = (_recoil_velocity - 22.0 * recoil_j * delta) * decay
	_flash = maxf(_flash - delta, 0.0)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_tick_torso(delta)
	var want := 0.0 if cos(torso_yaw) >= 0.0 else PI
	if aim_target != null:
		var to: Vector2 = (aim_target as Vector2) - turret_pivot()
		if to.length() > 1.0:
			want = to.angle()
		else:
			want = _turret # 포인터가 요동축에 겹치면 마지막 방향을 유지한다.
	var error := wrapf(want - _turret, -PI, PI)
	var desired_velocity := clampf(error * 20.0, -TURRET_RATE, TURRET_RATE)
	_aim_velocity = lerpf(_aim_velocity, desired_velocity, 1.0 - exp(-28.0 * delta))
	var advance := _aim_velocity * delta
	if signf(advance) == signf(error) and absf(advance) >= absf(error):
		_turret = want
		_aim_velocity = 0.0
	else:
		_turret = wrapf(_turret + advance, -PI, PI)
	# 기존 자세 입력은 하체 facing을 곱한다. 조준 방향은 화면 기준으로 보상한다.
	_aim_pitch = -sin(_turret) * cos(_turret) * float(facing)

	if firing and _fire_cd <= 0.0:
		_fire_cd = FIRE_COOLDOWN
		_recoil = RECOIL_BACK
		_recoil_velocity = 0.0
		_flash = FLASH_TIME
		var d := aim_dir()
		recoil_impulse(d)
		fired.emit(muzzle(), d)


## 상체만 회전한다. 고관절·발의 yaw는 독립되어 뒷걸음질 중에도 제자리를 지킨다.
func _tick_torso(delta: float) -> void:
	var target := _yaw_want
	if aim_target != null:
		target = _torso_want
		var dx: float = (aim_target as Vector2).x - body_pos.x
		# 바로 위/아래에서 마우스가 몇 픽셀 흔들려도 상체가 좌우로 떨리지 않는다.
		if absf(dx) > 36.0:
			target = 0.0 if dx > 0.0 else PI
	if not is_equal_approx(target, _torso_want):
		_torso_from = torso_yaw
		_torso_want = target
		_torso_time = 0.0
	_torso_time = minf(_torso_time + delta / 0.34, 1.0)
	var t := _torso_time
	var eased := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	torso_yaw = lerpf(_torso_from, _torso_want, eased)


# ── 몸체 ─────────────────────────────────────────────────────────────────────

## 반동 오프셋은 이동 계산에 섞지 않는다. 걷어내고 계산한 뒤 다시 얹는다 —
## 그래야 speed·_walked·드래그 이동이 총을 쏘는 동안에도 평소와 똑같이 나온다.
## 걸음 계산은 반동을 걷어낸 몸통으로 한다. 반동이 speed 에 섞이면 로봇이 총을 쏘며 걸어 나간다
## (실제로 2초 연사에 87px 이 밀려 나갔다 — 지지 판정이 반동 이동을 걸음 속도로 되돌려 놓았다).
func _release_recoil() -> void:
	if not _shift_on:
		return
	body_pos.x -= _shift
	_shift_on = false


## 그려지는 자리(= 총구가 있는 자리)로 몸통을 옮긴다.
func _hold_recoil() -> void:
	if _shift_on or is_zero_approx(_shift):
		return
	body_pos.x += _shift
	_shift_on = true


## 걸음이 다 정해진 뒤 몸통에 얹을 양을 정한다. **딛고 있는 발이 버틸 수 있는 만큼만** 얹으므로
## 뼈가 늘어나거나 발이 끌리지 않는다. 남는 힘은 그냥 버린다 — 그게 "버틴다" 는 그림이다.
## 프레임당 한 번만 부른다 — 서브스텝마다 부르면 지지 판정과 IK 재계산이 그만큼 배로 돈다
## (달리며 쏠 때 틱당 5ms 까지 올라갔고, 그 지연이 다시 걸음을 망가뜨렸다).
func _apply_recoil(delta: float) -> void:
	var spring := _spring(_kick, _kick_velocity, 0.0, RECOIL_KICK_FREQ, RECOIL_KICK_DAMP, delta)
	_kick = clampf(spring.x, -RECOIL_KICK_MAX, RECOIL_KICK_MAX)
	_kick_velocity = spring.y
	# 쌓인 밀림은 사격이 끊기면 천천히 제자리로 돌아온다. 걸으면 발이 다시 자리를 잡으므로 더 빨리 푼다.
	var recover := RECOIL_PUSH_RECOVER * (1.0 + 2.0 * clampf(_motion, 0.0, 1.0))
	_push = maxf(_push - recover * delta, 0.0)
	var want := _wanted_shift()
	if is_zero_approx(want):
		_shift = 0.0
		return
	if spider_gait and _spider != null:
		var base := body_pos
		if not _spider.supports_at(self, base + Vector2(want, 0.0), _angle):
			var lower := 0.0
			var upper := 1.0
			for iteration in 5:
				var fraction := (lower + upper) * .5
				if _spider.supports_at(self, base + Vector2(want * fraction, 0.0), _angle):
					lower = fraction
				else:
					upper = fraction
			want *= lower
	_shift = want


func _move_body(delta: float) -> void:
	var previous_speed := speed
	if drag_to != null:
		# 마우스로 직접 잡아끄는 중 — 속도는 실제 이동량에서 뽑는다 (예측 발 놓기가 그대로 동작하도록)
		var target: Vector2 = drag_to
		var prev := body_pos
		body_pos = body_pos.lerp(target, 1.0 - exp(-delta * 22.0))
		# 몸을 지면 밑으로는 끌고 갈 수 없다 (마우스를 바닥 아래로 내려도 다리가 땅을 뚫지 않게)
		body_pos.y = minf(body_pos.y, ground_at.call(body_pos.x) - GROUND_CLEAR)
		# 속도는 **제한한다**. 마우스를 휘두르면 한 프레임 이동량이 수천 px 이 되고,
		# 그 값이 lead(예측)에 그대로 곱해져 발 목표가 화면 밖으로 날아간다.
		speed = clampf((body_pos.x - prev.x) / maxf(delta, 0.0001), -SPEED_CAP, SPEED_CAP)
		airborne = false
		_air_v = 0.0
		_jump_windup = 0.0
		_body_velocity = 0.0
		_walked += absf(body_pos.x - prev.x)
		_update_motion(previous_speed, delta)
		_update_facing()
		return

	var top: float = tune["speed"] * (RUN_MUL if running else 1.0)
	if absf(input_dir) > 0.01:
		speed = move_toward(speed, top * signf(input_dir), ACCEL * delta)
	else:
		speed = move_toward(speed, 0.0, FRICTION * delta)
	body_pos.x += speed * delta
	_walked += absf(speed) * delta
	_update_motion(previous_speed, delta)
	_update_facing()
	if _jump_windup > 0.0:
		_jump_windup = maxf(_jump_windup - delta, 0.0)
		if _jump_windup <= 0.0:
			airborne = true
			_air_v = -JUMP_V
			_body_velocity = 0.0

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
			var impact := _air_v
			body_pos.y = land
			airborne = false
			_air_v = 0.0
			_plant_feet()
			# 발은 그 자리에 잠그고 질량만 눌렸다 복원된다. 낙하 높이에 비례하지만 도달 예산은 지킨다.
			_body_velocity = minf(impact * 0.19, 190.0)
			_landing_compression = minf(impact / JUMP_V, 1.0)
			_angle_velocity += clampf(speed / maxf(tune["speed"], 1.0), -1.0, 1.0) * 0.30
	if airborne:
		# 공중에서는 진행 방향으로 가볍게 접혔다가 착지 전에 자세를 편다.
		var target_angle := clampf(speed / maxf(tune["speed"], 1.0), -1.0, 1.0) * 0.045
		target_angle += clampf(_air_v / JUMP_V, -1.0, 1.0) * 0.028 * float(facing)
		var air_spring := _spring(_angle, _angle_velocity, target_angle, 2.4, 0.78, delta)
		_angle = air_spring.x
		_angle_velocity = air_spring.y


func _update_motion(previous_speed: float, delta: float) -> void:
	var blend := 1.0 - exp(-delta * 10.0)
	_motion = lerpf(_motion, clampf(absf(speed) / maxf(tune["speed"], 1.0), 0.0, 1.5), blend)
	var force := clampf((speed - previous_speed) / maxf(delta * ACCEL, 0.001), -1.4, 1.4)
	_acceleration = lerpf(_acceleration, force, 1.0 - exp(-delta * 14.0))


## 착지 순간 네 발을 **그 자리 지면에 바로 박는다.**
## 뜬 동안엔 다리를 접어 두는데(_tuck_feet), 착지를 일반 스텝 규칙에 맡기면 접지 유지·대각 규칙에 걸려
## 다리가 펴지기까지 몇 프레임이 걸린다 — 그동안 로봇이 공중에 선 것처럼 보인다.
## 착지는 한 순간에 쿵 하고 끝나야 하므로 여기서만 예외로 네 발을 동시에 놓는다.
func _plant_feet() -> void:
	if spider_gait and _spider != null:
		_spider.plant(self)
		return
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
		leg["roll"] = 0.0
	_all_down = 0.0


func _update_facing() -> void:
	if spider_gait:
		return # 다리의 사선 시점은 고정이다. 이동·후진은 접지를 바꾸고, 조준은 상체만 돌린다.
	if aim_target != null:
		return # 조준 중에는 하체 방향을 유지하고 앞/뒤로 그대로 걸어간다.
	if speed > TURN_SPEED:
		face(1)
	elif speed < -TURN_SPEED:
		face(-1)


## 이쪽을 보게 한다. **즉시 뒤집지 않는다** — 목표 yaw 만 정해 두고 _tick_yaw 가 돌린다.
func face(want: int) -> void:
	_yaw_want = 0.0 if want > 0 else PI


## 몸을 목표 방향으로 돌린다. facing(걸음 계산용)은 **정면(PI/2)을 지나는 순간** 바뀐다 —
## 전환의 가운데에서 바뀌므로, 다리는 몸이 반쯤 돌아간 시점부터 새 자리를 찾아 나선다.
func _tick_yaw(delta: float) -> void:
	if is_equal_approx(yaw, _yaw_want):
		return
	yaw = move_toward(yaw, _yaw_want, PI / TURN_TIME * delta)
	var want := 1 if yaw < PI * 0.5 else -1
	if want != facing:
		facing = want
		_all_down = tune["hold"]     # 돌아선 순간엔 접지 유지를 건너뛴다 — 네 발이 빨리 제자리를 찾게


## 딛고 있는 발들의 평균 높이 (없으면 네 발 평균)
func _support_y() -> float:
	var sum := 0.0
	var n := 0
	for leg in _legs:
		if not leg["stepping"]:
			sum += (leg["foot"] as Vector2).y - float(leg.get("ground_depth", 0.0))
			n += 1
	if n == 0:
		for leg in _legs:
			sum += (leg["foot"] as Vector2).y - float(leg.get("ground_depth", 0.0))
			n += 1
	return sum / float(n)


## 몸체 높이·기울기를 발 위치에서 뽑는다. 다리가 몸을 따라가는 게 아니라 **몸이 발을 따라간다**.
func _sync_body_to_feet(delta: float, snap := false) -> void:
	var phase: float = _walked / maxf(tune["stride"] * 210.0, 1.0) * TAU
	var moving := clampf(_motion, 0.0, 1.0)
	var bob: float = sin(phase) * tune["bob"] * 0.65 * moving
	# 저속 호흡은 보행 진동과 독립적이다. 서면 진동은 끝나고 아주 작은 생동감만 남는다.
	var breathe := sin(_idle_time * 1.8) * 1.7 * (1.0 - moving)
	var anticipation := sin((1.0 - _jump_windup / JUMP_WINDUP) * PI * 0.85) * 14.0 if _jump_windup > 0.0 else 0.0
	var height: float = _support_y() - tune["ride"] + bob + breathe + anticipation
	if snap:
		body_pos.y = height
		_body_velocity = 0.0
	else:
		var suspension := _spring(body_pos.y, _body_velocity, height, 3.3, 0.68, delta)
		body_pos.y = suspension.x
		_body_velocity = suspension.y
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
	# 출발 때는 관성으로 뒤로, 감속 때는 앞으로 무게가 실렸다가 한 번 따라 흔들린다.
	lean -= _acceleration * 0.055
	# 뒤로 밀린 만큼 몸통이 젖혀진다 — 앞다리가 펴지고 뒷다리가 접히는 자세가 그림으로도 읽힌다.
	lean += _push * _push_dir * RECOIL_PUSH_LEAN * float(facing)
	lean += sin(_idle_time * 1.35 + 0.7) * 0.0035 * (1.0 - moving)
	# 조준 방향으로 몸을 젖힌다 (위를 겨누면 앞이 들린다). facing 을 곱해 좌우가 뒤집히지 않게.
	var aim_lean: float = -_aim_pitch * tune["aim_lean"] * float(facing)
	var want := clampf(slope * tune["tilt"] + lean + aim_lean, -TILT_MAX, TILT_MAX)
	if snap:
		_angle = want
		_angle_velocity = 0.0
	else:
		var pitch := _spring(_angle, _angle_velocity, want, 2.8, 0.65, delta)
		_angle = clampf(pitch.x, -TILT_MAX, TILT_MAX)
		_angle_velocity = pitch.y


## 고정 목표에 대한 감쇠 스프링의 해석해. 프레임률이 바뀌어도 같은 탄성과 복원 시간을 갖는다.
static func _spring(value: float, velocity: float, target: float, frequency: float, damping: float, delta: float) -> Vector2:
	var omega := TAU * frequency
	var decay := damping * omega
	var oscillation := omega * sqrt(maxf(1.0 - damping * damping, 0.001))
	var distance := value - target
	var sine := sin(oscillation * delta)
	var cosine := cos(oscillation * delta)
	var envelope := exp(-decay * delta)
	var next_value := target + envelope * (distance * cosine + (velocity + decay * distance) / oscillation * sine)
	var next_velocity := envelope * (velocity * cosine - (decay * velocity + omega * omega * distance) / oscillation * sine)
	return Vector2(next_value, next_velocity)


## 리그와 총구가 같은 변환을 쓰게 한다. 발은 늘 월드 접지를 유지하며 상체만 3% 이내로 눌린다.
func presentation_scale() -> Vector2:
	var compression := clampf(_body_velocity / 1100.0 + _landing_compression * 0.018, -0.022, 0.032)
	if airborne:
		compression = -0.015 * clampf(-_air_v / JUMP_V, 0.0, 1.0)
	return Vector2(1.0 + compression * 0.42, 1.0 - compression)


func motion_amount() -> float:
	return _motion


## 사격은 발·위치를 순간 이동시키지 않고 서스펜션으로 전달한다.
## 앞뒤 반동은 걸음 속도(speed)에 섞지 않는다 — 섞으면 발 예측 위치가 총을 쏠 때마다 튄다.
## 대신 _kick 이 몸통만 뒤로 밀고, 다리는 늘 그랬듯 제 발 위치에서 IK 로 따라온다.
func recoil_impulse(direction: Vector2) -> void:
	# 위아래 충격은 작게 둔다. 크면 몸이 들썩이며 접지 높이가 흔들리고 발이 종종거린다.
	_body_velocity = clampf(_body_velocity - direction.y * 9.0, -210.0, 210.0)
	_angle_velocity = clampf(_angle_velocity + direction.x * 0.48, -2.2, 2.2)
	_kick_velocity = clampf(_kick_velocity - direction.x * RECOIL_KICK, -1500.0, 1500.0)
	_push_dir = -signf(direction.x) if absf(direction.x) > 0.01 else _push_dir
	_push = minf(_push + RECOIL_PUSH, RECOIL_PUSH_MAX)


## 지금 몸통에 얹혀 있는 반동 오프셋. 발 목표를 잡을 때 이걸 빼면 **발은 제자리를 지키고
## 몸통만** 움직인다 — 총을 쏘는 동안 다리가 종종거리지 않는다.
## 걸음 계산은 반동을 걷어낸 몸통으로 도므로(_release_recoil) 그 동안 이 값은 0 이다.
func recoil_shift() -> float:
	return _shift if _shift_on else 0.0


## 스프링이 원하는 반동량. 다리가 버틸 수 있는 만큼만 _apply_recoil 이 실제로 얹는다.
func _wanted_shift() -> float:
	return _kick + _push * _push_dir


# ── 다리 ─────────────────────────────────────────────────────────────────────

## 이 다리가 지금 놓여야 할 자리 (몸체 위치 + 벌어짐 + 예측) 를 지면에 붙인 값
## 이 다리가 지금 놓여야 할 자리. **rest 도 yaw 를 통과한다** —
## 돌아서는 동안 네 발의 목표가 몸 가운데로 모였다가 반대쪽으로 벌어지므로,
## 다리가 제자리에서 종종거리며 방향을 바꾼다 (facing 만 뒤집으면 목표가 한 프레임에 건너뛰고,
## 네 발이 동시에 긴급 스텝을 내며 주저앉았다).
func _desired(leg: Dictionary, vel: float) -> Vector2:
	var rest: float = (leg["rest"] as float) * tune["stride"]
	# 반동으로 밀린 몸통은 발 목표를 끌고 가지 않는다 — 발은 버티고 다리 각도만 벌어진다.
	var x: float = body_pos.x - recoil_shift() + project(rest, 0.0, leg["side"] as float).x + vel * tune["lead"]
	return Vector2(x, ground_at.call(x))


func _tick_legs(delta: float) -> void:
	for leg in _legs:
		if leg["stepping"]:
			leg["t"] = (leg["t"] as float) + delta / maxf(leg["dur"] as float, 0.01)
			if (leg["t"] as float) >= 1.0:
				leg["foot"] = leg["to"]
				leg["stepping"] = false
				leg["roll"] = 0.0
				# 작게 발을 고쳐 놓을 때와 전력으로 딛을 때의 충격이 같지 않다.
				var weight: float = clampf((leg["lift"] as float) / 70.0, 0.12, 1.0)
				_body_velocity += 11.0 * weight
				_angle_velocity += signf((leg["foot"] as Vector2).x - body_pos.x) * 0.035 * weight
			else:
				var t: float = leg["t"]
				var e := _ease_foot(t)                          # 양 끝 속도·가속도가 모두 0인 최소 저크 궤적
				var p: Vector2 = (leg["from"] as Vector2).lerp(leg["to"] as Vector2, e)
				# 먼저 빠르게 발끝을 떼고, 긴 호를 따라 내려와 접지한다. 좌우 대칭 사인파의 기계감을 없앤다.
				var lift_phase := t / 0.38 if t < 0.38 else (1.0 - t) / 0.62
				p.y -= _ease_foot(clampf(lift_phase, 0.0, 1.0)) * (leg["lift"] as float)
				var travel: float = signf((leg["to"] as Vector2).x - (leg["from"] as Vector2).x)
				leg["roll"] = -travel * sin(t * TAU) * 0.09
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
		# 멈추면 끝 걸음을 작게 정리한다. trigger 아래에 걸린 어색한 벌림 자세로 영원히 얼지 않는다.
		var settling := absf(speed) < 15.0 and absf(input_dir) < 0.01 and drag_to == null
		var threshold: float = minf(tune["trigger"], 9.0) if settling else tune["trigger"]
		if (o["err"] as float) < threshold and not urgent:
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
				if settling and _error(other) < threshold:
					continue
				_begin_step(other, 0.0)


static func _ease_foot(t: float) -> float:
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## 공중에 뜬 동안의 다리. **올라갈 때와 내려올 때가 다르다.**
##   올라갈 때 — 접는다. 발을 땅에 박아 둔 채 두면 몸이 올라가는 만큼 다리가 늘어나 떨어져 보인다.
##   내려올 때 — **착지할 자리를 향해 뻗는다.** 접은 채로 내려오면 몸이 선 높이에서 멈추는 순간
##               발이 아직 공중에 남아 있어, 땅이 아니라 허공에 착지한 것처럼 보인다
##               (측정: 착지 직전 프레임에 발이 지면 58px 위에 있었다).
func _air_legs(delta: float) -> void:
	var rising := _air_v < 0.0
	var k := 1.0 - exp(-delta * (8.0 if rising else 15.0))
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
		leg["roll"] = lerpf(leg.get("roll", 0.0), (-0.10 if rising else 0.04) * float(facing), k)


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
	# 매우 짧은 거미 걸음도 설정한 시간을 존중한다. 기존 0.11 하한은 0.06 프리셋을 두 배 늘렸다.
	var shortest: float = minf(0.11, tune["step_time"])
	leg["dur"] = clampf(minf(tune["step_time"], dist / v * 0.55), shortest, 0.45) + extra
	var short_step := clampf(dist / 95.0, 0.18, 1.0)
	leg["lift"] = tune["lift"] * short_step
	if absf(speed) < 15.0:
		leg["dur"] = maxf(leg["dur"], 0.16)
		leg["lift"] = minf(leg["lift"], 23.0)


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


## 고관절의 월드 좌표. **yaw 를 통과한 자리**다 — 돌아서는 동안 고관절이 몸 가운데로 모였다가
## 반대쪽으로 벌어지고, 발은 월드에 박혀 있으므로 다리가 그 차이를 받아낸다. 그게 회전의 그림이다.
func _hip_world(leg: Dictionary) -> Vector2:
	if spider_gait and not leg.get("pose", {}).is_empty():
		return leg["pose"]["hip"]
	var h: Vector2 = leg["hip"]
	return body_pos + project(h.x, h.y, leg["side"] as float).rotated(_angle)


## 이 다리의 기준 정강이 각. 바깥쪽(몸 중심 반대편)으로 SHIN_SPLAY 만큼 눕힌다.
## rest 의 부호 × facing 이 곧 그 다리가 뻗은 세계 방향이다.
func _phi0(leg: Dictionary) -> float:
	# yaw 중앙에서 정강이가 한 프레임에 반전하지 않도록 기준각도 연속적으로 넘긴다.
	return -SHIN_SPLAY * signf(leg["rest"] as float) * cos(yaw) + float(leg.get("roll", 0.0))


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


# ── 파츠 리그가 쓰는 공개 창구 ────────────────────────────────────────────────
## 그림(스프라이트) 쪽에서 필요한 값만 내보낸다. 내부 상태를 직접 뒤지지 않게 —
## 나중에 본편에서 이 로봇을 쓸 때 리그가 유일한 소비자가 된다.

func legs() -> Array:
	return _legs


## 이 다리의 고관절 월드 좌표 (yaw 를 통과한 자리)
func hip_world(leg: Dictionary) -> Vector2:
	return _hip_world(leg)


## 이 다리의 기준 정강이 각
func phi0(leg: Dictionary) -> float:
	return _phi0(leg)


## 요동축에서 포신 방향으로 len 만큼 간 점 (몸통 원점 기준 화면 좌표)
func turret_local(len: float) -> Vector2:
	return _turret_local(len)


# ── 그리기 ───────────────────────────────────────────────────────────────────

## 그레이박스. 원화 파츠 리그(walker_rig.gd)를 붙이면 draw_greybox 를 꺼서 이 그림을 지운다.
## 리그가 붙기 전까지 이게 기준 그림이고, 리그가 붙은 뒤에도 자리맞춤 확인용으로 남긴다.
func _draw() -> void:
	if not draw_greybox:
		return
	# **깊이 순으로 그린다.** 몸통보다 먼 다리를 먼저, 가까운 다리를 나중에 —
	# 돌아서는 동안 어느 쌍이 먼 쪽인지가 바뀌므로 near 플래그로는 안 된다 (플립의 흔적이다)
	var order: Array = []
	for leg in _legs:
		order.append({"leg": leg, "z": leg_depth(leg)})
	order.sort_custom(func(a, b): return a["z"] > b["z"])
	for o in order:
		if o["z"] > 0.0:
			_draw_leg(o["leg"])
	_draw_body()
	_draw_turret()
	for o in order:
		if o["z"] <= 0.0:
			_draw_leg(o["leg"])


## 깊이 한 칸(두께 1)이 화면에서 밀리는 벡터. **yaw 를 곱하지 않는다** — 카메라는 고정이고,
## 몸이 돌아가면 Z 값 자체가 바뀌기 때문이다 (예전처럼 facing 을 곱하면 이중으로 뒤집힌다).
func depth_vec() -> Vector2:
	if not oblique():
		return Vector2(0.0, -FAR_RAISE)
	return Vector2(float(view["dx"]), float(view["dy"]))


## 깊이 z (두께 단위) → 화면 오프셋
func _depth_off(z: float) -> Vector2:
	return depth_vec() * z


## 몸 로컬 (a = 앞뒤 · u = 위아래 · s = 좌우 두께 비율) → **몸통 원점 기준 화면 좌표**.
## 몸 기울기(_angle)는 포함하지 않는다 — 노드 회전이 그걸 처리한다.
func project(a: float, u: float, s: float) -> Vector2:
	return Vector2(a * fore_x(), u + a * fore_y()) + extrude_vec() * s


## 상체와 포가의 공용 사영. 하체 project()는 접지/IK에 계속 사용한다.
func body_project(a: float, u: float, s: float) -> Vector2:
	return (Vector2(a * body_fore_x(), u + a * body_fore_y()) + body_extrude_vec() * s) * presentation_scale()


func body_fore_x() -> float:
	# 0을 연속적으로 통과해야 포가가 좌우로 순간 이동하지 않는다.
	return cos(torso_yaw) - depth_vec().x * sin(torso_yaw) / BODY_DEPTH


func body_fore_y() -> float:
	return -depth_vec().y * sin(torso_yaw) / BODY_DEPTH


func body_extrude_vec() -> Vector2:
	return Vector2(BODY_DEPTH * sin(torso_yaw), 0.0) + depth_vec() * cos(torso_yaw)


func recoil_distance() -> float:
	return _recoil


## 앞뒤 축(a)이 화면에서 차지하는 **가로 배율**. cos 만이 아니다 —
## 깊이 오프셋의 가로 성분이 같이 들어간다 (몸이 카메라 쪽으로 돌면 깊이로도 옆으로 밀리므로).
##
## **하한을 두지 않는다.** 예전엔 |배율| 의 하한(SQUASH_MIN)을 뒀는데, 이 값은 yaw≈58° 에서
## 0 을 지나며 부호가 바뀌므로 하한이 그 자리에서 **+0.58 → -0.58 로 튀었다** — 이름만 다른 플립이다.
## 0 을 그냥 지나가게 두면 측면 그림이 한두 프레임 얇아졌다 반대로 펴진다 (문이 닫히듯).
## 다리·포신은 따로 그려지므로 그 순간에도 사라지지 않는다.
## 그 구간을 정면 시트로 덮는 것이 다음 단계다 (walker_rig.gd 의 turn sheet 자리).
func fore_x() -> float:
	return cos(yaw) - depth_vec().x * sin(yaw) / BODY_DEPTH


## 앞뒤 축이 화면에서 **위아래로** 밀리는 양 (기울어 보이게 만드는 성분)
func fore_y() -> float:
	return -depth_vec().y * sin(yaw) / BODY_DEPTH


## 그 점의 깊이 Z (두께 단위, 클수록 멀다). 밝기·그리는 순서가 이걸 본다 — 위치에는 쓰지 않는다.
func depth_of(a: float, s: float) -> float:
	return (-a * sin(yaw)) / BODY_DEPTH + s * cos(yaw)


func oblique() -> bool:
	return float(view["oblique"]) > 0.5


## 깊이에 따른 밝기·굵기. 사선일 때만 가늘어진다 (측면에서는 예전처럼 어둡기만 했다)
func _depth_mul(z: float) -> float:
	return lerpf(1.0, FAR_MUL, z)


func _depth_scale(z: float) -> float:
	return 1.0 - (float(view["shrink"]) if oblique() else 0.0) * z


## 이 다리의 깊이 Z (두께 단위). 양수 = 몸통보다 멀다
func leg_depth(leg: Dictionary) -> float:
	if spider_gait:
		return 0.5 if bool(leg["far"]) else -0.5
	return depth_of((leg["hip"] as Vector2).x, leg["side"] as float)


func _draw_leg(leg: Dictionary) -> void:
	if spider_gait:
		var pose: Dictionary = leg["pose"]
		var keys := ["mount", "hip", "knee", "ankle", "toe"]
		var colors := [C_JOINT, C_THIGH, C_BODY, C_SHIN]
		for i in 4:
			var a: Vector2 = transform.affine_inverse() * pose[keys[i]]
			var b: Vector2 = transform.affine_inverse() * pose[keys[i + 1]]
			_limb(a, b, 18.0 if i < 2 else 29.0, colors[i])
		return
	var z := leg_depth(leg)
	var hip := to_local(_hip_world(leg))
	var foot := to_local(leg["foot"]) + _depth_off(z)
	# 발은 월드에 박혀 있다 — 깊이 오프셋만 얹어 그 다리의 평면으로 옮긴다.
	# 고관절은 project 를 통과한 자리라, 돌아서는 동안 둘의 간격이 벌어지고 다리가 그걸 받아낸다
	var knee := solve_knee_v(hip, foot, _phi0(leg))
	var mul := _depth_mul(maxf(z, 0.0) * 2.0)
	var s := _depth_scale(maxf(z, 0.0) * 2.0)
	# 팔다리 자체의 두께 — 깊이 벡터를 조금만 써서 상자로 만든다 (다리 하나가 납작한 판으로 보이지 않게)
	var t := _depth_off(1.0) * (float(view["thick"]) if oblique() else 0.0)

	# 정강이 — 거의 수직으로 유지되는 강체
	_limb3(knee, foot, SHIN_W * s, _dim(C_SHIN, mul), t)
	# 허벅지 — 길이가 변하는 유압 스트럿. 가는 로드를 전 구간에 깔고 그 위에 **고정 길이 슬리브**를 덮어,
	# 길이 변화가 고무줄이 아니라 "실린더에서 로드가 나온다" 로 읽히게 한다.
	var d := knee - hip
	var span := d.length()
	if span > 1.0:
		var n := d / span
		_limb3(hip, knee, (THIGH_W - 18.0) * s, _dim(C_THIGH_ROD, mul), t)
		_limb3(hip, hip + n * minf(SLEEVE_LEN, span), THIGH_W * s, _dim(C_THIGH, mul), t)
	draw_circle(knee, KNEE_R * s, _dim(C_JOINT, mul))
	draw_circle(hip, HIP_R * s, _dim(C_JOINT, mul))


## 몸통. **가까운 면(s=-0.5)의 폴리곤을 그리고 두께만큼 밀어** 상자로 만든다.
## 폴리곤 점을 전부 project 로 통과시키므로, 돌아서는 동안 상자가 비스듬한 평행사변형으로 눕는다 —
## 좌우를 뒤집는 대신 **실제로 돌아가는** 그림이 나오는 자리다.
func _draw_body() -> void:
	var nose := BODY_HALF_W + 34.0
	_extrude([
		{"pts": _face([
			Vector2(-BODY_HALF_W, BODY_TOP), Vector2(BODY_HALF_W, BODY_TOP),
			Vector2(BODY_HALF_W, BODY_BOT), Vector2(-BODY_HALF_W, BODY_BOT),
		]), "col": C_BODY},
		# 바라보는 쪽 앞머리 (a 가 + 인 쪽이 늘 앞이다 — facing 을 곱하지 않는다)
		{"pts": _face([
			Vector2(BODY_HALF_W, -128.0), Vector2(nose, -112.0),
			Vector2(nose, -58.0), Vector2(BODY_HALF_W, -44.0),
		]), "col": C_BODY},
	], body_extrude_vec() * presentation_scale())
	# 아랫면 어두운 띠 — 다리가 몸에 파묻히는 자리를 정리한다. 가까운 면에만 얹는 무늬다
	draw_colored_polygon(_face([
		Vector2(-BODY_HALF_W, BODY_SKIRT), Vector2(BODY_HALF_W, BODY_SKIRT),
		Vector2(BODY_HALF_W, BODY_BOT), Vector2(-BODY_HALF_W, BODY_BOT),
	]), C_BODY_DARK)


## (a, u) 점들을 가까운 면(s = -0.5)의 화면 좌표로
func _face(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(body_project((v as Vector2).x, (v as Vector2).y, -0.5))
	return out


## 두께 한 칸(가까운 면 → 먼 면)이 화면에서 밀리는 벡터.
## yaw=0 이면 깊이벡터 그대로, yaw=PI/2 면 몸통 두께만큼 가로로, yaw=PI 면 반대쪽으로 — 연속이다.
func extrude_vec() -> Vector2:
	return Vector2(BODY_DEPTH * sin(yaw), 0.0) + depth_vec() * cos(yaw)


## 포탑. 요동축·포신 모두 project 를 통과한 점으로 그린다.
func _draw_turret() -> void:
	var pivot := _turret_local(0.0)
	var tip := _turret_local(BARREL_LEN - _recoil)
	var d := tip - pivot
	var dir := d.normalized() if d.length() > 0.001 else Vector2.RIGHT
	var ex := body_extrude_vec() * 0.72

	# 요동축을 몸통 윗면에 잇는 받침 — 포신을 들어도 공중에 뜨지 않게
	var mount_foot := body_project(TURRET_PIVOT.x, TURRET_PIVOT.y + 70.0, 0.0)
	_extrude([
		{"pts": _limb_pts(mount_foot, pivot, 70.0), "col": C_BODY_DARK},
		# 약실(요동축 뒤로 튀어나온 덩어리) → 포신 → 총구 블록
		{"pts": _limb_pts(_turret_local(-62.0), _turret_local(20.0), BARREL_W + 22.0), "col": C_GUN},
		{"pts": _limb_pts(pivot, tip, BARREL_W), "col": C_GUN},
		{"pts": _limb_pts(tip - dir * 30.0, tip + dir * 8.0, BARREL_W + 16.0), "col": C_GUN_LIT},
	], ex)
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
	var pts := _limb_pts(a, b, w)
	if pts.size() > 0:
		draw_colored_polygon(pts, col)


## 막대 하나의 네 점 (이음매를 메우려 양 끝을 조금 늘린 사각형)
func _limb_pts(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var d := b - a
	if d.length() < 0.01:
		return PackedVector2Array()
	var n := d.normalized()
	var p := Vector2(-n.y, n.x) * (w * 0.5)
	var a2 := a - n * (w * 0.35)                                  # 관절 원 밑으로 조금 물려 이음매를 메운다
	var b2 := b + n * (w * 0.2)
	return PackedVector2Array([a2 + p, b2 + p, b2 - p, a2 - p])


## 막대 하나를 상자로 (다리용)
func _limb3(a: Vector2, b: Vector2, w: float, col: Color, off: Vector2) -> void:
	var pts := _limb_pts(a, b, w)
	if pts.size() > 0:
		_extrude([{"pts": pts, "col": col}], off)


## 볼록 다각형 여러 장을 off 만큼 밀어 **상자**로 만든다.
## parts = [{"pts": PackedVector2Array, "col": Color}, ...] — 앞면 기준 좌표.
##
## 순서가 전부다: 뒷면 전부 → 옆면 전부 → 앞면 전부.
## 파츠별로 (뒷·옆·앞) 을 한 묶음씩 그리면, 뒤에 그려진 파츠의 **뒷면**이 이미 그린 파츠의
## 앞면 위에 얹힌다 (앞머리를 밀면 몸통 앞면 위로 넘어온다 — 실제로 그렇게 보였다).
##
## 옆면 색은 그 변이 위를 향하는지로 가른다. 위를 향하는 변 = 윗면이라 밝게,
## 나머지 = 측면이라 어둡게. 이것만으로 상자의 세 면이 구분된다.
func _extrude(parts: Array, off: Vector2) -> void:
	if off.length() < 0.5:                                        # 사선을 끈 상태 — 예전처럼 납작하게
		for part in parts:
			draw_colored_polygon(part["pts"], part["col"])
		return

	for part in parts:
		var pts: PackedVector2Array = part["pts"]
		var back := PackedVector2Array()
		for p in pts:
			back.append(p + off)
		draw_colored_polygon(back, _dim(part["col"], FAR_MUL))

	for part in parts:
		var pts: PackedVector2Array = part["pts"]
		var c: Vector2 = Vector2.ZERO
		for p in pts:
			c += p
		c /= float(pts.size())
		for i in range(pts.size()):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			var up := ((a + b) * 0.5 - c).y < 0.0                 # 이 변이 덩어리의 위쪽인가
			var col: Color = _dim(part["col"], TOP_MUL if up else SIDE_MUL)
			draw_colored_polygon(PackedVector2Array([a, b, b + off, a + off]), col)

	for part in parts:
		draw_colored_polygon(part["pts"], part["col"])


## Color × float 는 알파까지 깎는다 — 색만 어둡게 한다
static func _dim(c: Color, mul: float) -> Color:
	return Color(minf(c.r * mul, 1.0), minf(c.g * mul, 1.0), minf(c.b * mul, 1.0), c.a)


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


## 시점 수치 (사선 시점) — HUD·콘솔 출력용
func view_text() -> String:
	if not oblique():
		return "시점 측면 (사선 끔)"
	return "시점 사선 — 깊이 x %.0f · y %.0f · 원근 %.2f · 두께 %.2f" % [
		view["dx"], view["dy"], view["shrink"], view["thick"],
	]
