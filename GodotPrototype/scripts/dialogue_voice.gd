class_name DialogueVoice
extends RefCounted
## 대사 **음성 방식** 표 — 말풍선이 글자를 찍는 동안 무슨 소리를 낼지 정한다.
##
## 표시 방식(DialogueBubble.STYLES)과 같은 생각이다. 엔진은 하나고, 방식이 그 엔진을
## 어떻게 쓸지만 정한다. 실행 중에 바꿀 수 있고(NPC 대화 테스트씬에서 V / Shift+V),
## 고른 값은 static 이라 씬을 다시 로드해도 남는다. 환경 변수 DIALOGUE_VOICE 로 시작값 고정.
##
## ── 소리를 내는 세 갈래 (소재: Tools/build_npc_voice_blips.py) ──────────────
##   blip     글자마다 **아무 모음 조각** 하나. 언더테일·동물의 숲 초기. 존재감 신호에 가깝다
##   phoneme  글자마다 **그 글자의 실제 모음**. 동물의 숲(Animalese).
##            "아무한테도" 면 ㅏ·ㅜ·ㅔ·ㅗ 가 그 순서로 울려 **말의 운율이 생긴다**.
##            한국어는 한글 낱자에서 중성을 바로 떼어낼 수 있어 값이 거의 안 든다
##   murmur   말하는 동안 **이음 루프 하나가 계속 돈다**. 음높이만 문장 억양을 따라간다.
##            글자 단위 반복이 아예 없어 지치지 않는다 — 기계·무전 인물에 특히 맞는다
##   off      소리 없음
##
## 여기에 **줄머리 한마디**(opener)를 얹을 수 있다. 줄이 시작될 때 두세 음절짜리
## 무의미어가 한 번만 나고 그 뒤는 조용한 방식(파이어 엠블렘·젤다)이다.
##
## 사람(human)과 기계(machine = UNIT-7)를 따로 정하는 이유는 이 게임의 대사 원칙 때문이다 —
## **사람은 사람처럼, 기계만 기계처럼**(Docs/DIALOGUE_SYSTEM.md §5-1). 둘이 같은 엔진으로
## 울리면 그 구분이 글에만 있고 소리에는 없다.
##
## 넣지 않은 갈래: **무의미어 실제 녹음**(심즈 Simlish). 품질로는 이 표의 무엇보다 낫지만
## 인물 5명치 연기 녹음이 필요해 합성으로는 대신할 수 없다. 방식을 확정한 뒤에도 남는 선택지다.

## 모음 7종. 파일 이름의 뒷자리이자 phoneme 방식이 고르는 단위 (Tools/build_npc_voice_blips.py VOWELS).
const VOWELS := ["a", "eo", "o", "u", "eu", "i", "e"]

## 한글 중성 21자(ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ) → 위 7종의 자리.
## 겹모음은 **끝소리 쪽**으로 접는다 — ㅘ 는 ㅏ, ㅟ 는 ㅣ. 귀가 듣는 것이 그쪽이다.
const JUNG_TO_VOWEL := [0, 6, 0, 6, 1, 6, 1, 6, 2, 0, 6, 6, 2, 3, 1, 6, 5, 3, 4, 5, 5]

const HANGUL_BASE := 0xAC00
const HANGUL_LAST := 0xD7A3
const JUNG_STRIDE := 28          # 종성 28가지 — 중성 한 칸이 이만큼이다
const JUNG_COUNT := 21

## 음성 방식. 앞의 다섯은 갈래 하나씩이고, 뒤의 다섯은 **조합**이다.
##   human    사람 인물(아르카디·세린·미나·유나·델 박사)이 쓰는 갈래
##   machine  UNIT-7 이 쓰는 갈래
##   opener   줄 시작에 한마디를 내는가
const PRESETS := [
	{
		"id": "blip", "name": "모음 블립",
		"desc": "글자마다 아무 모음 조각 하나. 언더테일 결 — 말이라기보다 '말하고 있다'는 신호",
		"human": "blip", "machine": "blip", "opener": false,
	},
	{
		"id": "phoneme", "name": "음소 블립",
		"desc": "글자마다 그 글자의 실제 모음. 동물의 숲 결 — 대사의 운율이 소리에 실린다",
		"human": "phoneme", "machine": "phoneme", "opener": false,
	},
	{
		"id": "murmur", "name": "웅얼거림",
		"desc": "말하는 동안 이음 루프가 돈다. 글자 단위 반복이 없어 가장 덜 지친다. 대신 또렷함도 없다",
		"human": "murmur", "machine": "murmur", "opener": false,
	},
	{
		"id": "opener", "name": "줄머리 한마디",
		"desc": "줄이 시작될 때 두세 음절만 한 번. 나머지는 조용하다. 파이어 엠블렘·젤다 결",
		"human": "off", "machine": "off", "opener": true,
	},
	{
		"id": "silent", "name": "무음",
		"desc": "소리 없이 자막만. 앰비언스가 살아난다 — 비교 기준선이기도 하다",
		"human": "off", "machine": "off", "opener": false,
	},
	{
		"id": "blip_bot", "name": "블립 + 기계 웅얼",
		"desc": "사람은 지금 쓰던 블립 그대로, UNIT-7 만 기계 웅얼로 갈라 둔다. 가장 작은 변화",
		"human": "blip", "machine": "murmur", "opener": false,
	},
	{
		"id": "phoneme_bot", "name": "음소 + 기계 웅얼",
		"desc": "사람은 모음을 따라 말하고 기계는 이음 루프로 웅얼거린다. **추천** — 사람과 기계가 소리로 갈린다",
		"human": "phoneme", "machine": "murmur", "opener": false,
	},
	{
		"id": "phoneme_open", "name": "음소 + 줄머리",
		"desc": "줄을 한마디로 열고 그 뒤를 음소 블립으로 잇는다. 말을 꺼내는 호흡이 생긴다",
		"human": "phoneme", "machine": "phoneme", "opener": true,
	},
	{
		"id": "full", "name": "음소 + 기계 웅얼 + 줄머리",
		"desc": "추천안에 줄머리 한마디까지. 가장 두껍다 — 대사가 많아지면 먼저 지칠 쪽이기도 하다",
		"human": "phoneme", "machine": "murmur", "opener": true,
	},
	{
		"id": "murmur_open", "name": "웅얼 + 줄머리",
		"desc": "한마디로 열고 나머지는 웅얼거림으로 흘린다. 인물이 멀리 있는 듯한 거리감",
		"human": "murmur", "machine": "murmur", "opener": true,
	},
]

## 지금 방식. 기본값은 추천안(음소 + 기계 웅얼) — 아직 확정이 아니라 비교 중이다.
static var preset_index := 6


static func preset_of(i: int) -> Dictionary:
	return PRESETS[wrapi(i, 0, PRESETS.size())]


static func preset() -> Dictionary:
	return preset_of(preset_index)


static func set_preset(i: int) -> void:
	preset_index = wrapi(i, 0, PRESETS.size())


static func cycle(step := 1) -> void:
	set_preset(preset_index + step)


## 시작값을 환경 변수로 고정할 수 있다 (DialogueBubble 의 DIALOGUE_STYLE 과 같은 방식).
static func apply_env() -> void:
	var env := OS.get_environment("DIALOGUE_VOICE")
	if env != "" and env.is_valid_int():
		set_preset(int(env))


## 이 말투가 지금 프리셋에서 쓰는 갈래. UNIT-7(machine)만 따로 간다.
static func mode_for(voice_id: String) -> String:
	var p := preset()
	return str(p["machine"] if voice_id == "machine" else p["human"])


static func opener_enabled() -> bool:
	return bool(preset().get("opener", false))


## 이 글자가 낼 모음. 한글이면 중성에서 떼어내고, 아닌 글자는 글자값으로 흩는다
## (숫자·라틴 문자도 소리는 나야 하고, 같은 글자는 늘 같은 모음이어야 말투가 흔들리지 않는다).
static func vowel_for(ch: String) -> String:
	if ch.is_empty():
		return VOWELS[0]
	var c := ch.unicode_at(0)
	if c >= HANGUL_BASE and c <= HANGUL_LAST:
		var jung := int((c - HANGUL_BASE) / JUNG_STRIDE) % JUNG_COUNT
		return VOWELS[JUNG_TO_VOWEL[jung]]
	return VOWELS[c % VOWELS.size()]
