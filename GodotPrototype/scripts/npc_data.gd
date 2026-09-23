class_name NpcData
extends RefCounted
## NPC 정의 — 등장 인물 표 · 대사 나무 · 인물 사이의 인과관계.
##
## **배치**는 여기가 아니라 RoomData.ROOMS[*].props 가 단일 출처다 (단말기·센트리건과 같은 규칙):
##   {"type": "npc", "id": "caretaker", "x": 370, "facing": -1}
## 여기서는 그 id 가 **누구이고 무슨 말을 하는지**만 정한다.
##
## ── 대사 나무 ──────────────────────────────────────────────────────────────
## LINES[<npc id>] 은 노드 사전이다. 노드 하나 = 말풍선 하나.
##   who      말하는 사람 (생략 = 그 NPC, "player" = 로봇 자신). CAST 의 다른 id 도 된다.
##   text     대사. 연출 태그는 dialogue_bubble.gd 참고 — [shake] [wave] [c=#rrggbb] [p=0.4] [s=0.6]
##   set      이 말풍선이 뜨는 순간 세우는 플래그 (Array[String])
##   branch   [[조건, 노드 id], ...] — next 보다 먼저, 조건이 맞는 첫 줄로 간다
##   next     다음 노드 id (없으면 대화 종료)
##   choices  [{"text", "to", "if"(선택), "set"(선택)}] — 줄이 다 찍힌 뒤 뜬다
## entry 는 **말을 걸 때마다** 위에서부터 평가해 첫 번째로 맞는 노드에서 시작한다.
## 조건식 문법은 NpcState.test() 참고 ("a & !b", "seen:노드키").
##
## ── 인과관계 (이 표의 핵심) ────────────────────────────────────────────────
##   관리인 ──lockdown──▶ 관제원 추궁 가능
##   관제원 ──power_cut──▶ 수경재배사에게 전할 수 있다  (+ promised: 함구 약속)
##   수경재배사 ──told_keeper──▶ keeper_bitter ──▶ 관제원 재방문 인사가 바뀐다
##                              (promised 를 해 놓고 전했으면 broke_promise)
##   젊은 연구원 ──junior_secret──▶ 선임에게 보고 가능 (+ kept_secret: 함구 약속)
##   선임 연구원 ──told_senior──▶ 젊은 연구원 재방문이 차가워진다
##                              (kept_secret 을 해 놓고 보고했으면 broke_junior — 더 차갑다)
##   선임 연구원 ──priority_list──▶ 관리인·수경재배사·관제원 대사가 모두 바뀐다
## 어느 쪽을 골라도 무언가를 잃는다 (AI_Robot_Base_Narrative_Design_Notes §6).

const NPC_DIR := "res://assets/character/npc/"

## 플래그 뜻 — 조건식에 쓰이는 이름은 전부 여기 적는다 (오타 검사는 tools/validate_map.gd)
const FLAGS := {
	"lockdown": "서쪽 격벽 봉쇄가 사고가 아니라 명령이었다는 것을 관리인에게서 들었다",
	"power_cut": "관제원이 재배실 생명유지 전력을 방어 그리드로 돌렸다고 인정했다",
	"promised": "관제원에게 함구를 약속했다",
	"told_keeper": "수경재배사에게 전력 차단 사실을 알렸다",
	"keeper_bitter": "수경재배사가 관제원을 원망하게 되었다",
	"broke_promise": "함구를 약속해 놓고 전했다",
	"junior_secret": "젊은 연구원이 검역 밖으로 시료를 꺼냈다는 것을 안다",
	"kept_secret": "젊은 연구원에게 함구를 약속했다",
	"told_senior": "선임 연구원에게 시료 반출을 보고했다",
	"broke_junior": "유나에게 함구를 약속해 놓고 보고했다",
	"priority_list": "회수 우선순위 목록의 1순위가 사람이 아니라 시료라는 것을 안다",
}

## 등장 인물.
##   name/short  말풍선 이름표 / 다른 사람이 부를 때의 짧은 이름
##   tex         한 장짜리 idle 스프라이트 (320×320, 발이 셀 바닥 — Tools/build_npc_sprites.py)
##   head        발 밑에서 머리 꼭대기까지 높이(월드 px) — 말풍선 꼬리가 여기에 붙는다
##   body        실제 몸 폭(월드 px, 320 셀이 아니라 불투명 화소 기준) — 배치 검사가 벽 여유를 볼 때 쓴다
##   accent      이름표·말풍선 테두리 색. 인물마다 다른 색이 곧 "누가 말하는가" 의 단서
##   voice       말풍선 글자가 찍히는 속도와 **말소리**(dialogue_bubble.gd VOICES · assets/audio/sfx/voice)
##   tone        그 말투 안에서의 개인차 — 말소리 음높이 배율. 1.0 이 기준, 낮을수록 낮고 크게 들린다.
##               같은 "slow" 를 쓰는 아르카디와 델 박사가 같은 목소리면 안 되므로 여기서 가른다
##   anim        프레임 클립 폴더 id (assets/character/npc/<id>/animations). 있으면 숨쉬기·기록·듣기·걷기를
##               실제 그림으로 재생하고, 방 배치에 roam 을 주면 걸어 다닌다. 없으면 한 장짜리 tex 로 서 있는다.
const CAST := {
	"caretaker": {
		"name": "에어록 관리인 · 아르카디", "short": "아르카디",
		"tex": NPC_DIR + "airlock_caretaker/idle_01.png", "head": 256.0, "body": 156.0,
		"accent": Color(0.93, 0.74, 0.38), "voice": "slow", "tone": 0.90,
	},
	"controller": {
		"name": "방어망 관제원 · 세린", "short": "세린",
		"tex": NPC_DIR + "security_controller/idle_01.png", "head": 268.0, "body": 104.0,
		"accent": Color(0.55, 0.78, 1.0), "voice": "clipped", "tone": 1.02,
	},
	"keeper": {
		"name": "수경재배사 · 미나", "short": "미나",
		"tex": NPC_DIR + "hydroponics_keeper/idle_01.png", "head": 252.0, "body": 140.0,
		"accent": Color(0.62, 0.95, 0.72), "voice": "soft", "tone": 1.0,
	},
	"junior": {
		"name": "연구원 · 유나", "short": "유나",
		"tex": NPC_DIR + "researcher_junior/idle_01.png", "anim": "researcher_junior", "head": 248.0, "body": 108.0,
		"accent": Color(0.95, 0.72, 0.82), "voice": "quick", "tone": 1.05,
	},
	"senior": {
		"name": "선임 연구원 · 델 박사", "short": "델 박사",
		"tex": NPC_DIR + "researcher_senior/idle_01.png", "head": 256.0, "body": 136.0,
		"accent": Color(0.82, 0.80, 0.90), "voice": "slow", "tone": 1.06,
	},
	## 아직 대사가 없는 인물 — 말 걸기 표식도 뜨지 않는다 (LINES 에 "staff" 가 생기면 그때부터 말을 건다).
	## 이름은 자리표시자다. 대사를 쓸 때 다른 인물처럼 고유 이름을 붙일 것.
	"staff": {
		"name": "연구 보조원", "short": "연구 보조원",
		"tex": NPC_DIR + "researcher_male/idle_01.png", "anim": "researcher_male", "head": 260.0, "body": 108.0,
		"accent": Color(0.78, 0.88, 0.80), "voice": "soft", "tone": 0.92,
	},
	## 플레이어(로봇)는 월드에 NPC 로 서 있지 않지만 말풍선 주인은 될 수 있다.
	## head 는 Main 이 플레이어 말풍선 꼬리를 붙일 높이로 그대로 읽는다 (Main._player_head).
	"player": {
		"name": "UNIT-7", "short": "UNIT-7",
		"tex": "", "head": 372.0, "body": 212.0,
		"accent": Color(1.0, 0.45, 0.38), "voice": "machine", "tone": 1.0,
	},
}

const LINES := {
	# ── 에어록 관리인 아르카디 ────────────────────────────────────────────────
	# 60대. 사흘째 혼자 문을 지켰고 지쳤고 화가 쌓였다. 툭툭 끊어 말하고 말끝을 흐린다.
	# 인과의 출발점 — 서쪽 격벽이 "닫힌" 게 아니라 "누가 내렸다" 는 사실을 흘린다.
	"caretaker": {
		"entry": [
			["priority_list", "list"],
			["lockdown", "again"],
			["seen:caretaker/hello", "again"],
			["", "hello"],
		],
		"hello": {
			"text": "…어. [p=0.45]진짜 걸어 들어오네.",
			"next": "hello2",
		},
		"hello2": {
			"text": "사흘 만이다. [p=0.35]멀쩡하게 움직이는 거 보는 게.",
			"next": "hello3",
		},
		"hello3": {
			"text": "그래서, [p=0.3]너 사람 꺼내러 온 거냐 [p=0.25]물건 꺼내러 온 거냐.",
			"choices": [
				{"text": "구조 프로토콜로 기동했다.", "to": "rescue"},
				{"text": "답할 권한이 없다.", "to": "no_answer"},
			],
		},
		"rescue": {
			"who": "player",
			"text": "구조 프로토콜. [p=0.2]생존자가 우선이다.",
			"next": "rescue2",
		},
		"rescue2": {
			"text": "…그래. [p=0.45]그 말 나중에 한 번 더 해봐라.",
			"next": "shutter",
		},
		"no_answer": {
			"who": "player",
			"text": "공개 권한 밖이다.",
			"next": "no_answer2",
		},
		"no_answer2": {
			"text": "하. [p=0.4]됐다. [p=0.25]알아들었어.",
			"next": "shutter",
		},
		"shutter": {
			"text": "서쪽 격벽 말인데. [p=0.35]저거 고장 나서 내려앉은 거 아니야.",
			"next": "shutter2",
		},
		"shutter2": {
			"text": "누가 내렸어. [p=0.35][shake]손으로[/shake].",
			"set": ["lockdown"],
			"next": "shutter3",
		},
		"shutter3": {
			"text": "안에 사람 있는 거 알고. [p=0.45]열둘.",
			"next": "shutter4",
		},
		"shutter4": {
			"text": "관제 애 이름이 [c=#8ac6ff]세린[/c]이야. [p=0.3]격납고 옆 통로에 처박혀 있어.",
			"next": "shutter5",
		},
		"shutter5": {
			"text": "가서 물어봐. [p=0.3]나한텐 문도 안 열어 주더라.",
			"next": "",
		},
		"again": {
			"text": "난 여기 있을란다. [p=0.35]문은 누가 지켜야 하잖냐.",
			"next": "",
		},
		"list": {
			"text": "회수 우선순위… [p=0.4]그거 사람 이름 적힌 거 맞지.",
			"next": "list2",
		},
		"list2": {
			"text": "…내 이름도 있디?",
			"choices": [
				{"text": "없었다.", "to": "list_no"},
				{"text": "명단에 사람은 없었다.", "to": "list_none"},
				{"text": "대답하지 않는다.", "to": "list_silent"},
			],
		},
		"list_no": {
			"text": "…그럴 줄 알았다. [p=0.45]근데 막상 들으니까 [p=0.3]좀 그렇네.",
			"next": "",
		},
		"list_none": {
			"text": "사람이 아예 없어? [p=0.5]…나 그럼 여태 [wave]뭘[/wave] 지킨 거야.",
			"next": "",
		},
		"list_silent": {
			"text": "…됐다. [p=0.35]안 물어볼게.",
			"next": "",
		},
	},

	# ── 방어망 관제원 세린 ───────────────────────────────────────────────────
	# 30대. 며칠 못 잤다. 말이 빠르고 자주 끊기며, 추궁당하면 먼저 방어한다.
	# lockdown 을 들고 오면 실토한다. 전력을 어디서 끌어왔는지까지.
	"controller": {
		"entry": [
			["broke_promise", "betrayed"],
			["keeper_bitter", "bitter"],
			["power_cut", "after"],
			["lockdown", "accuse"],
			["seen:controller/hello", "again"],
			["", "hello"],
		],
		"hello": {
			"text": "오지 마. [p=0.3]거기 서.",
			"next": "hello2",
		},
		"hello2": {
			"text": "…아, [p=0.3]기계구나. [p=0.35]됐어. 지나가.",
			"next": "",
		},
		"again": {
			"text": "말 걸지 마. [p=0.3]나 화면 봐야 돼.",
			"next": "",
		},
		"accuse": {
			"who": "player",
			"text": "서쪽 격벽. [p=0.25]수동 폐쇄 기록이 남아 있다.",
			"next": "accuse2",
		},
		"accuse2": {
			"text": "…누가 그래. [p=0.35]아르카디?",
			"next": "accuse3",
		},
		"accuse3": {
			"text": "그래, 내가 내렸어. [p=0.45]안 내렸으면 여기까지 다 죽었어.",
			"choices": [
				{"text": "안에 열두 명이 있었다.", "to": "cold"},
				{"text": "누가 그렇게 하라고 했나.", "to": "who"},
			],
		},
		"cold": {
			"text": "…알아. [p=0.55]그 열둘 이름, [p=0.3]내가 다 읽었어. 명단에서.",
			"next": "who",
		},
		"who": {
			"text": "본사 프로토콜이지. [p=0.4]근데 버튼은 내가 눌렀잖아. [p=0.3]그럼 누구 잘못이야.",
			"next": "power",
		},
		"power": {
			"text": "…그리고 하나 더 있어.",
			"next": "power2",
		},
		"power2": {
			"text": "포탑 돌릴 전기가 모자라서 [p=0.35][c=#8ae3a0]재배실[/c] 쪽에서 끌어왔어.",
			"set": ["power_cut"],
			"next": "power3",
		},
		"power3": {
			"text": "미나는 몰라. [p=0.5]말하지 마. [p=0.3]부탁이야.",
			"choices": [
				{"text": "말하지 않겠다.", "to": "promise", "set": ["promised"]},
				{"text": "약속할 수 없다.", "to": "refuse"},
			],
		},
		"promise": {
			"text": "…고마워. [p=0.45]진짜로.",
			"next": "",
		},
		"refuse": {
			"text": "…그래. [p=0.45]하고 싶은 대로 해.",
			"next": "",
		},
		"after": {
			"text": "아직 여기 있어. [p=0.35]3분만 비워도 그리드 꺼져.",
			"branch": [["priority_list", "after_list"]],
			"next": "",
		},
		"after_list": {
			"who": "player",
			"text": "회수 우선순위 목록을 확인했다. [p=0.3]1순위는 사람이 아니었다.",
			"next": "after_list2",
		},
		"after_list2": {
			"text": "…알아. [p=0.5]알고 있었어. [p=0.4]그래서 더 못 놓겠는 거야, 이거.",
			"next": "",
		},
		"bitter": {
			"text": "미나 왔다 갔어. [p=0.4]아무 말도 안 하고.",
			"next": "bitter2",
		},
		"bitter2": {
			"text": "…차라리 욕을 하지. [p=0.4]그냥 보고만 있다 가더라.",
			"next": "",
		},
		"betrayed": {
			"text": "말 안 한다며.",
			"next": "betrayed2",
		},
		"betrayed2": {
			"text": "…됐어. [p=0.45]내가 바보였지. [p=0.3]기계한테 부탁을 하고.",
			"next": "",
		},
	},

	# ── 수경재배사 미나 ──────────────────────────────────────────────────────
	# 40대. 조용하고 다정하고 몹시 피곤하다. 혼잣말이 섞이고, 화를 내는 대신 조용해진다.
	# power_cut 을 알고 오면 전할 수 있다. 전하면 미나는 얻고 세린은 잃는다.
	"keeper": {
		"entry": [
			["told_keeper", "after"],
			["power_cut", "tell"],
			["seen:keeper/hello", "again"],
			["", "hello"],
		],
		"hello": {
			"text": "쉿. [p=0.4]잠깐만.",
			"next": "hello2",
		},
		"hello2": {
			"text": "…들려? [p=0.35]펌프 소리. [p=0.3]어제부터 박자가 늦어.",
			"next": "hello3",
		},
		"hello3": {
			"text": "저 수조 셋이 기지 산소 [c=#8ae3a0]4할[/c]을 만들어. [p=0.4]근데 왜 전압이 반인지 아무도 말을 안 해줘.",
			"next": "",
		},
		"again": {
			"text": "펌프 소리 듣고 있어. [p=0.3]멎나 안 멎나.",
			"next": "",
		},
		"tell": {
			"text": "너 관제 쪽에서 왔지. [p=0.4]뭐 들은 거 없어? [p=0.25]전압 말이야.",
			"choices": [
				{"text": "관제원이 재배실 전기를 끌어갔다.", "to": "told", "if": "!promised", "set": ["told_keeper", "keeper_bitter"]},
				{"text": "관제원이 재배실 전기를 끌어갔다.", "to": "told", "if": "promised", "set": ["told_keeper", "keeper_bitter", "broke_promise"]},
				{"text": "기록이 남아 있지 않다.", "to": "lied", "if": "promised"},
				{"text": "아무 말도 하지 않는다.", "to": "silent"},
			],
		},
		"told": {
			"text": "…세린이.",
			"next": "told2",
		},
		"told2": {
			"text": "…아. [p=0.6]그랬구나.",
			"next": "told3",
		},
		"told3": {
			"text": "말해줘서 고마워. [p=0.4]진짜로. [p=0.35]이제 뭘 버릴지는 내가 정할게.",
			"next": "told4",
		},
		"told4": {
			"text": "…나도 하나 말해줄게. [p=0.4]검역에서 시료 하나가 없어졌어.",
			"next": "told5",
		},
		"told5": {
			"text": "[c=#f0b7d0]유나[/c]가 가져갔어. [p=0.35]침실 A 에 있을 거야.",
			"set": ["junior_secret"],
			"next": "",
		},
		"lied": {
			"who": "player",
			"text": "해당 구간 배전 기록은 남아 있지 않다.",
			"next": "lied2",
		},
		"lied2": {
			"text": "…그래. [p=0.45]기계는 거짓말 안 하니까.",
			"next": "lied3",
		},
		"lied3": {
			"text": "…물어봐서 미안해. [p=0.35]고마워.",
			"next": "",
		},
		"silent": {
			"text": "…됐어. [p=0.4]안 물어볼게.",
			"next": "",
		},
		"after": {
			"text": "3번 수조는 놨어. [p=0.4]둘은 어떻게든 살려 보려고.",
			"branch": [["priority_list", "after_list"]],
			"next": "",
		},
		"after_list": {
			"text": "회수 목록? [p=0.35]거기 내 수조도 있어? [p=0.45]…없겠지.",
			"next": "",
		},
	},

	# ── 젊은 연구원 유나 ─────────────────────────────────────────────────────
	# 20대. 무서워서 말이 많아지는 쪽. 빠르고 횡설수설하고, 말하다 스스로 끊는다.
	# junior_secret 을 만들고, 선임에게 전해지면 이 사람이 잃는다.
	"junior": {
		"entry": [
			["broke_junior", "betrayed"],
			["told_senior", "cold"],
			["kept_secret", "kept"],
			["junior_secret", "confront"],
			["seen:junior/hello", "again"],
			["", "hello"],
		],
		"hello": {
			"text": "으악 — [p=0.35]아, [p=0.25]로봇이구나. [p=0.3]로봇.",
			"next": "hello2",
		},
		"hello2": {
			"text": "미안. [p=0.3]나 요즘 문소리만 나면 심장이… [p=0.35]아니다. 됐어.",
			"next": "",
		},
		"again": {
			"text": "나 여기 있을게. [p=0.3]복도보단 여기가 나아.",
			"next": "",
		},
		"confront": {
			"who": "player",
			"text": "검역 시료 1건. [p=0.25]반출 기록 없음.",
			"next": "confront2",
		},
		"confront2": {
			"text": "…언니가 말했구나.",
			"next": "confront3",
		},
		"confront3": {
			"text": "맞아. [p=0.35]내가 가져왔어.",
			"next": "confront4",
		},
		"confront4": {
			"text": "봉쇄되면 그거 태운대. [p=0.4]안에 뭐가 들었는지 아무도 안 보고.",
			"next": "confront5",
		},
		"confront5": {
			"text": "치료 데이터야. [p=0.35]사람 몇백 명짜리라고. [p=0.4]그걸 왜 태워.",
			"next": "confront6",
		},
		"confront6": {
			"text": "박사님한텐 말하지 마. [p=0.35]응? [p=0.3]제발.",
			"choices": [
				{"text": "말하지 않겠다.", "to": "kept", "set": ["kept_secret"]},
				{"text": "보고 대상이다.", "to": "must"},
			],
		},
		"kept": {
			"text": "…고마워. [p=0.45]고마워, 진짜.",
			"next": "",
		},
		"must": {
			"text": "…아. [p=0.45]그렇지. [p=0.3]그러겠지.",
			"next": "must2",
		},
		"must2": {
			"text": "가. [p=0.35]붙잡아도 소용없을 거 아냐.",
			"next": "",
		},
		"betrayed": {
			"text": "말 안 한다며.",
			"next": "betrayed2",
		},
		"betrayed2": {
			"text": "…아니다. [p=0.45]내가 착각했지. [p=0.3]너 그냥 기계잖아.",
			"next": "",
		},
		"cold": {
			"text": "시료, [p=0.3]박사님이 가져갔어.",
			"next": "cold2",
		},
		"cold2": {
			"text": "…규정대로 됐네. [p=0.45]잘됐다.",
			"next": "",
		},
	},

	# ── 선임 연구원 델 박사 ──────────────────────────────────────────────────
	# 60대. 하게체로 정중하게 말하지만 자주 말끝을 흐린다. 미안함을 잘 못 감춘다.
	# 보고를 받으면 시료를 회수하고, 그 대가로 회수 우선순위 목록을 보여 준다.
	"senior": {
		"entry": [
			["priority_list", "after"],
			["junior_secret", "report"],
			["seen:senior/hello", "again"],
			["", "hello"],
		],
		"hello": {
			"text": "아, [p=0.3]자네가 그 유닛인가.",
			"next": "hello2",
		},
		"hello2": {
			"text": "나는 여기서 기록을 정리하고 있네. [p=0.4]지금 내가 할 수 있는 게 그것뿐이라서.",
			"next": "hello3",
		},
		"hello3": {
			"text": "사람은… [p=0.45]사람은 내가 어떻게 할 수가 없더군.",
			"next": "",
		},
		"again": {
			"text": "궁금한 게 생기면 오게. [p=0.3]나는 여기 있을 테니.",
			"next": "",
		},
		"report": {
			"text": "무슨 일인가. [p=0.4]표정이 없는 얼굴인데도 [p=0.25]뭔가 있어 보이는군.",
			"choices": [
				{"text": "유나가 검역 시료를 꺼냈다.", "to": "told", "if": "!kept_secret", "set": ["told_senior"]},
				{"text": "유나가 검역 시료를 꺼냈다.", "to": "told", "if": "kept_secret", "set": ["told_senior", "broke_junior"]},
				{"text": "아무것도 아니다.", "to": "hide"},
			],
		},
		"told": {
			"text": "…유나가.",
			"next": "told2",
		},
		"told2": {
			"text": "…그 아이가 왜.",
			"next": "told3",
		},
		"told3": {
			"text": "회수하겠네. [p=0.4]벌주려는 게 아니야. [p=0.35]검역이라 그래. [p=0.3]그것뿐이네.",
			"next": "told4",
		},
		"told4": {
			"text": "…대신 자네도 하나 봐야겠군. [p=0.35]본사에서 온 목록이네.",
			"next": "list",
		},
		"hide": {
			"text": "그런가. [p=0.5]자네, 방금 [wave]망설였나[/wave]?",
			"next": "hide2",
		},
		"hide2": {
			"text": "…됐네. [p=0.35]대신 자네가 볼 게 하나 있어.",
			"next": "list",
		},
		"list": {
			"text": "1순위 생체 시료. [p=0.3]2순위 연구 데이터. [p=0.3]3순위 장비.",
			"next": "list2",
		},
		"list2": {
			"text": "[p=0.35]…사람 항목이 [shake]없어[/shake].",
			"set": ["priority_list"],
			"next": "list3",
		},
		"list3": {
			"who": "player",
			"text": "…질의. [p=0.35]이 목록에 사람이 없는 이유.",
			"next": "list4",
		},
		"list4": {
			"text": "나도 모르네. [p=0.5]사흘 내내 그것만 보고 있었어.",
			"next": "list5",
		},
		"list5": {
			"text": "나한텐 그걸 고칠 권한이 없어. [p=0.45]…자네한텐 있을지도 모르지.",
			"next": "",
		},
		"after": {
			"text": "목록은 봤지. [p=0.45]따를 건지는 안 물어보겠네. [p=0.3]아직은.",
			"next": "",
		},
	},
}


static func get_cast(id: String) -> Dictionary:
	return CAST.get(id, CAST["player"])


static func get_tree_for(id: String) -> Dictionary:
	return LINES.get(id, {})


## 지금 상태에서 이 NPC 와 시작할 노드 id ("" 면 할 말이 없다)
static func entry_node(npc_id: String) -> String:
	var tree: Dictionary = LINES.get(npc_id, {})
	for pair in tree.get("entry", []):
		if NpcState.test(str(pair[0])):
			return str(pair[1])
	return ""


static func node(npc_id: String, node_id: String) -> Dictionary:
	var tree: Dictionary = LINES.get(npc_id, {})
	var n = tree.get(node_id, null)
	return n if n is Dictionary else {}
