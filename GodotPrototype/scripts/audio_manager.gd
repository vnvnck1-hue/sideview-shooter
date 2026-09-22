extends Node
## 사운드 재생·믹싱 중앙 관리자 (자동 로드 이름: Audio).
##
## 설계 원칙 — 프로토타입에서 소리가 귀에 거슬리는 원인은 대부분 셋이다.
##   1) 같은 파일이 똑같은 높이로 반복된다 → 모든 재생에 피치·음량을 흔든다(_rand).
##   2) 초당 10발 넘게 겹치며 저역이 쌓인다 → 소리마다 최소 간격(gap)과 동시 보이스 수(voices)를 제한한다.
##   3) 고역이 쏘아붙인다 → 버스 단위 로우패스로 깎는다(Weapon 9.5kHz, Ambience 2.2kHz).
## 마지막 안전망으로 Master 에 하드 리미터를 걸어 어떤 상황에서도 클리핑하지 않게 한다.
##
## 믹스를 조정할 때는 MIX 와 SOUNDS 의 db 값만 만지면 된다. 재생 호출부는 건드릴 필요 없다.
##
## 라이선스: 효과음은 대부분 Kenney CC0, 앰비언스는 Eric Berzins "Ultra Sci-Fi Ambience"(무료·상업 허용)
## 와 OpenGameArt "30 CC0 SFX loops"(CC0), 크리처 보컬은 OpenGameArt "80 CC0 creature SFX"(CC0).
## 단 총격음 5종만 GokhanBiyik "Gun Sounds 01" (CC BY 4.0) 이라
## 크레딧 표기 의무가 있다 — Docs/CREDITS.md 와 assets/audio/_licenses/ 참고.

## 방 앰비언스가 바뀔 때마다 (앰비언스 랩 패널이 받아 현재 값을 표시한다)
signal ambience_changed(room_id: String, plan: Dictionary)

const DIR := "res://assets/audio/"

const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_WEAPON := "Weapon"
const BUS_AMB := "Ambience"
const BUS_UI := "UI"
const BUS_VOICE := "Voice"     # NPC 대사 블립. 따로 두면 대화 중에만 밸런스를 잡을 수 있다

## 버스 레벨(dB). 카테고리 전체 밸런스는 여기서 잡는다.
const MIX := {
	BUS_MASTER: -1.0,
	BUS_SFX: -3.0,
	BUS_WEAPON: -1.0,    # 총은 이 게임에서 가장 큰 소리다. 눌러 두면 존재감이 안 산다
	BUS_AMB: -10.0,
	BUS_UI: -9.0,
	# 글자마다 하나씩 — 한 줄에 서른 번 울린다. 크면 금방 지친다.
	# "들리는 소리" 가 아니라 "읽는 리듬" 으로 깔리는 지점이 이 언저리다.
	BUS_VOICE: -13.0,
}

## 버스 필터 컷오프(Hz).
## Weapon 은 원래 6500 이었다 — 발사음 본체가 Kenney 금속 타격이던 시절,
## 그 쇳소리가 초당 11번 반복되는 걸 막으려던 값이다. 실총 녹음이 본체가 되고
## 금속은 -11dB 보조 레이어로 내려간 지금은 6500 이 **어택을 깎아먹는 쪽**이라 9500 으로 올렸다.
## 반사·잔향도 이 뒤에 걸리므로 방 울림도 같이 밝아진다. 쏘는 소리가 쨍하면 다시 내릴 것.
## Ambience 는 원래 700Hz 였다 — Kenney SF 엔진 루프의 금속성 고역을 통째로 잘라
## "지하 공간의 울림"만 남기려던 값이다. 베드를 실사/드론 계열로 갈아 끼우면서
## 2200 으로 올렸다. 지금 텍스처는 고역이 있어야 성격이 사는 것들이라
## (공조·물 흐름·단말기 노이즈) 700 에서는 최대 10dB 가 깎여 나갔다.
const LOWPASS := {
	BUS_WEAPON: 9500.0,
	BUS_AMB: 2200.0,
}

## 소리 정의.
##   files  : DIR 기준 상대 경로. 여러 개면 매번 다른 것을 고른다
##   db     : 기본 음량
##   db_var : ± 이만큼 무작위로 흔든다 (같은 샘플의 반복감을 지운다)
##   pitch  : [최소, 최대] 배율
##   gap    : 같은 키가 다시 울리기까지의 최소 간격(초). 연사 중 소리가 뭉치는 것을 막는다
##   voices : 이 키가 동시에 차지할 수 있는 최대 보이스 수
const SOUNDS := {
	# --- 무기 ---
	# 발사음은 4레이어다 (2026-09-20 프리셋 "두껍게" 확정).
	#   fire_body   실총 녹음 본체 — 배리에이션 2종 중 하나가 매 발 나간다
	#   fire_body2  7ms 늦게 깔리는 두께 층 — 한 발을 점이 아니라 덩어리로 만든다
	#   fire_attack Kenney 금속 타격 — 이 팩에 없는 "탁"만 얇게 얹는다
	#   fire_sub    저역 — 타격감의 실체
	# 실총 녹음 쪽은 저역 편중이 심해 "쿵"은 있어도 "탁"이 없다 — 그래서 금속을 버리지 않았다.
	"fire_body": {
		"files": ["sfx/weapon/fire_body_01.wav", "sfx/weapon/fire_body_02.wav"],
		"db": -5.0, "db_var": 1.5, "pitch": [0.94, 1.06], "bus": BUS_WEAPON,
		"gap": 0.0, "voices": 6,
	},
	# 두께 층 — 보디와 같은 순간이 아니라 **7ms 늦게** 깔린다(무음이 파일에 구워져 있다).
	# 한 발이 하나의 점이 아니라 짧은 덩어리가 되면서 두툼해진다. AAA 무기 사운드의 상투적 수법.
	# 피치를 보디보다 낮게 잡아야 같은 소리가 두 번 난 것으로 안 들린다.
	"fire_body2": {
		"files": ["sfx/weapon/fire_body2_01.wav"],
		"db": -9.0, "db_var": 1.5, "pitch": [0.87, 0.93], "bus": BUS_WEAPON,
		"gap": 0.0, "voices": 4,
	},
	# 어택 보강 레이어. 이전에는 이게 발사음 본체였다(-7 dB).
	# 이제 보디가 따로 있으므로 크게 내려 "딱" 만 얹는 역할로 남긴다.
	# 실총 톤을 그대로 듣고 싶으면 db 를 -80 으로 내리면 이 레이어만 사라진다.
	"fire_attack": {
		"files": ["sfx/weapon/fire_metal_01.ogg", "sfx/weapon/fire_metal_02.ogg"],
		"db": -13.0, "db_var": 1.5, "pitch": [0.78, 0.90], "bus": BUS_WEAPON,
		"gap": 0.0, "voices": 4,
	},
	# 저역 레이어 — 타격감의 실체다. "들린다"기보다 "맞았다"로 느껴지는 부분.
	#
	# 예전에는 gap 0.16 으로 **두 발에 한 번만** 깔았다. 저역 누적을 막으려던 것이고
	# 그때는 맞는 판단이었다(원본이 220ms 였다). 지금은 150ms 로 줄이고 어택을 세웠으므로
	# 매 발 깔아도 쌓이지 않는다. 한 발 걸러 오는 무게는 타격감이 아니라 **박자**로 들린다.
	#
	# 되돌리려면 gap 을 0.16 으로 올리면 된다. 연사가 먹먹하면 그게 첫 번째 후보다.
	"fire_sub": {
		"files": ["sfx/weapon/fire_sub_01.wav"],
		"db": -7.0, "db_var": 1.0, "pitch": [0.94, 1.02], "bus": BUS_WEAPON,
		"gap": 0.0, "voices": 3,
	},
	# 사격이 끊긴 뒤 한 번만 울리는 방 잔향. 연사 중에는 절대 울리지 않는다 —
	# 매 발 깔면 0.6초짜리 꼬리가 무한히 겹쳐 먹먹해진다. 발사 처리는 _process 참고.
	"fire_tail": {
		"files": ["sfx/weapon/fire_tail_01.wav"],
		"db": -12.0, "db_var": 1.0, "pitch": [0.96, 1.04], "bus": BUS_WEAPON,
		"gap": 0.30, "voices": 1,
	},
	# --- 센트리건: 포신 2개가 번갈아 + 크랙 ---
	#
	# sentry_turret.gd 는 포신 2개가 0.055초 간격으로 **번갈아** 쏜다. 예전에는 소리가 한 장뿐이라
	# 초당 18발이 그냥 기계적인 연속음으로 들렸다. 이제 A/B 를 교대로 울린다(turret_fire 참고).
	#
	# 좌우 분리는 **파일에 구워져 있다**(스테레오, ±0.30). AudioStreamPlayer2D 의 위치 패닝으로는
	# 안 된다 — 두 포신 간격이 몇백 px 이라 4480px 가시 폭에서는 화면 비율상 거의 0 이다.
	#
	# 포신마다 gap 은 0.085. 한 포신이 다시 도는 주기가 0.11초(0.055×2)이므로 그 안쪽이면 충분하다.
	"turret_fire_a": {
		"files": ["sfx/weapon/turret_fire_01.wav"],
		"db": -6.0, "db_var": 1.5, "pitch": [0.97, 1.03], "bus": BUS_WEAPON,
		"gap": 0.085, "voices": 3,
	},
	# +2.5 dB 는 취향이 아니라 계산값이다. 둘 다 -1 dBFS 로 정규화해도 샘플마다 피크 대비
	# 에너지가 달라 그냥 두면 좌우가 2.5dB 어긋난다 — 그러면 "두 문이 교대"가 아니라
	# "한쪽이 크다"로 들린다. stage_gunshot_audio.py 가 실행할 때마다 이 값을 다시 찍어 준다.
	"turret_fire_b": {
		"files": ["sfx/weapon/turret_fire_02.wav"],
		"db": -3.5, "db_var": 1.5, "pitch": [0.90, 0.96], "bus": BUS_WEAPON,
		"gap": 0.085, "voices": 3,
	},
	# 매 발 얹는 고역 크랙. 저역뿐이던 센트리건에 "탕" 하는 지점을 만든다.
	# 40ms 짜리라 18발/초에도 쌓이지 않는다.
	"turret_crack": {
		"files": ["sfx/weapon/turret_crack_01.wav"],
		"db": -13.0, "db_var": 2.0, "pitch": [1.08, 1.16], "bus": BUS_WEAPON,
		"gap": 0.04, "voices": 4,
	},
	# 탄피는 작고 높다. 원본이 둔해서 피치를 크게 올렸다.
	"shell": {
		"files": ["sfx/weapon/shell_01.ogg"],
		"db": -20.0, "db_var": 2.0, "pitch": [1.18, 1.42], "bus": BUS_SFX,
		"gap": 0.05, "voices": 4,
	},

	# --- 플레이어 ---
	# 발소리는 채택된 샘플이 하나뿐이라 피치·음량 흔들기에 전적으로 의존한다.
	"footstep": {
		"files": ["sfx/player/footstep_01.ogg"],
		"db": -14.0, "db_var": 2.5, "pitch": [0.86, 1.08], "bus": BUS_SFX,
		"gap": 0.10, "voices": 3,
	},
	"cloth": {
		"files": ["sfx/player/cloth_01.ogg", "sfx/player/cloth_02.ogg", "sfx/player/cloth_03.ogg"],
		"db": -17.0, "db_var": 1.5, "pitch": [0.94, 1.10], "bus": BUS_SFX,
		"gap": 0.07, "voices": 3,
	},
	"land": {
		"files": ["sfx/player/roll_land_01.ogg"],
		"db": -10.0, "db_var": 1.0, "pitch": [0.88, 1.04], "bus": BUS_SFX,
		"gap": 0.10, "voices": 2,
	},

	# --- 탄착 ---
	"impact_wood": {
		"files": ["sfx/impact/wood_01.ogg"],
		"db": -12.0, "db_var": 2.0, "pitch": [0.84, 1.14], "bus": BUS_SFX,
		"gap": 0.05, "voices": 4,
	},
	"impact_stone": {
		"files": ["sfx/impact/stone_01.ogg"],
		"db": -12.0, "db_var": 2.0, "pitch": [0.84, 1.14], "bus": BUS_SFX,
		"gap": 0.05, "voices": 4,
	},

	# --- 환경 원샷 ---
	# 물방울은 Ambience 버스에 태우면 로우패스에 먹혀 사라진다. SFX 버스에 낮게 건다.
	"drip": {
		"files": ["ambience/drip_01.ogg"],
		"db": -17.0, "db_var": 2.5, "pitch": [0.88, 1.14], "bus": BUS_SFX,
		"gap": 0.3, "voices": 2,
	},

	# --- 크리처 (독성 종양 크롤러) ---
	#
	# 원본은 CC0 크리처 보컬이다(OGA "80 CC0 creature SFX"). 그대로 쓰면 **판타지 몬스터**로 들린다 —
	# 이 게임의 적은 연구시설에서 변이한 생물이라 톤이 한 옥타브쯤 아래에 있어야 한다.
	# 그래서 네 소리 모두 pitch 를 1.0 아래로 내려 잡았다. 파일에 구워 내리지 않은 이유는
	# 매 재생마다 다른 높이로 흔들어야 4번째 울음부터 드러나는 반복감을 막을 수 있기 때문이다.
	# 범위 폭(±0.06~0.09)도 일부러 다른 SFX(±0.03)보다 넓게 뒀다 — 생물의 목소리는 기계와 달리
	# 같은 높이로 두 번 울지 않는다.
	#
	# 파일은 전부 RMS -20 dBFS 로 맞춰 나왔다(Tools/stage_creature_audio.py). 아래 db 는 그 전제다.
	# 레벨을 다시 뽑으면 여기도 따라와야 한다.

	# 위협 — 포효(ROAR)와 공격 개시(ATTACK)에 함께 쓴다. 적이 "나를 봤다"를 알리는 소리라
	# 크롤러 소리 중 가장 크다. voices 2 는 방에 여럿이 있을 때 합창이 되는 걸 막는 선이다.
	"crawler_aggro": {
		"files": ["sfx/creature/aggro_01.ogg", "sfx/creature/aggro_02.ogg", "sfx/creature/aggro_03.ogg"],
		"db": -9.0, "db_var": 1.5, "pitch": [0.68, 0.82], "bus": BUS_SFX,
		"gap": 0.25, "voices": 2,
	},
	# 피격 — 초당 여러 번 울린다. 여기서 크게 잡으면 총성 위에 울음이 쌓여 사격 자체가 지저분해진다.
	# gap 0.09 는 발사 간격(약 0.09초)과 같다 — 연사 중에는 대략 한 발 걸러 한 번만 반응한다.
	# 매 발 울리는 것보다 이쪽이 "맞고 있다"로 들린다. 전탄 반응은 소리가 아니라 플래시가 맡는다.
	"crawler_hurt": {
		"files": ["sfx/creature/hurt_01.ogg", "sfx/creature/hurt_02.ogg"],
		"db": -13.0, "db_var": 2.0, "pitch": [0.74, 0.92], "bus": BUS_SFX,
		"gap": 0.09, "voices": 3,
	},
	# 죽음 — 한 개체당 정확히 한 번. 가장 낮게 끌어내린다(0.62~0.74). 위협음보다 더 아래여야
	# "힘이 빠지는" 방향으로 들린다. gap 을 두지 않는 이유는 여럿이 동시에 죽는 순간이
	# 이 게임에서 가장 시원한 지점이기 때문이다 — 여기서만큼은 겹쳐도 된다.
	"crawler_death": {
		"files": ["sfx/creature/death_01.ogg", "sfx/creature/death_02.ogg", "sfx/creature/death_03.ogg"],
		"db": -8.0, "db_var": 1.5, "pitch": [0.62, 0.74], "bus": BUS_SFX,
		"gap": 0.0, "voices": 3,
	},
	# 배회 — 걷는 중 이따금. **존재를 알리되 주의를 끌면 안 된다.** 앰비언스와 위협음 사이에
	# 앉혀야 하므로 -22dB 로 깊게 깔았다. 이 소리가 들리는 순간 플레이어가 화면을 돌아보면
	# 그건 너무 큰 것이다. 화면 밖 개체도 울리므로 voices 1 로 묶어 둔다.
	"crawler_idle": {
		"files": ["sfx/creature/idle_01.ogg"],
		"db": -22.0, "db_var": 2.5, "pitch": [0.64, 0.86], "bus": BUS_SFX,
		"gap": 0.8, "voices": 1,
	},

	# --- UI ---
	"ui_tick": {
		"files": ["ui/tick_01.ogg"],
		"db": -17.0, "db_var": 0.0, "pitch": [0.98, 1.02], "bus": BUS_UI,
		"gap": 0.04, "voices": 3,
	},

}

## NPC 대사 음성. SOUNDS 에 두지 않는다 — 파일이 55개(말투 5 × 모음 7 + 웅얼 5 + 줄머리 15)이고
## 경로가 `sfx/voice/<말투>_<모음>.wav` 규칙이라 표로 늘어놓는 것보다 만들어 쓰는 쪽이 정확하다.
## 무엇을 언제 울릴지는 DialogueVoice.PRESETS 와 dialogue_bubble.gd 가 정한다.
## 합성: Tools/build_npc_voice_blips.py
##
## 음높이는 여기서 흔들지 않는다 — 글자마다의 음높이는 말품새의 일부라
## 호출부가 인물별 기준음 + 문장 억양 + 글자별 흔들림으로 직접 정해 넘긴다.
const VOICE_DIR := "sfx/voice/"
const VOICE_DB := {                 # 말투별 기본 음량. 원본 RMS 가 비슷하므로 성격 차이만 반영한다
	"slow": -3.0, "soft": -3.5, "clipped": -4.0, "quick": -5.0, "machine": -4.0,
}
const VOICE_DB_VAR := 1.2           # ± 이만큼 흔든다 (같은 조각의 반복감을 지운다)
const VOICE_OPEN_DB := 1.0          # 줄머리 한마디는 한 줄에 한 번뿐이라 조금 크게
const VOICE_OPEN_COUNT := 3         # <말투>_open_01..03.wav
const VOICE_MURMUR_DB := -7.0       # 이음 루프는 줄 내내 깔리므로 블립보다 훨씬 낮게
const VOICE_MURMUR_FADE := 0.07     # 웅얼거림이 들고 나는 시간(초). 짧게 — 말은 갑자기 시작된다


## 앰비언스는 2단이다 — 구역이 정하는 BED 한 겹 위에 방이 정하는 TEXTURE 를 최대 두 겹.
## 방 id 가 아니라 RoomData 의 zone 으로 베드를 고르기 때문에, 맵에 방이 늘어도
## 그 방이 속한 구역의 소리가 저절로 따라온다. 옛 방식(방 id 해시로 3종 중 랜덤)은
## 옆방으로 한 칸 걸어갔을 뿐인데 공간의 성격이 통째로 바뀌는 게 문제였다.
const ZONE_BEDS := {
	RoomData.ZONE_WORKSHOP: "ambience/bed_workshop.ogg",
	RoomData.ZONE_POWER: "ambience/bed_power.ogg",
	RoomData.ZONE_CREW: "ambience/bed_common.ogg",
	RoomData.ZONE_HYDRO: "ambience/bed_common.ogg",
	RoomData.ZONE_RESEARCH: "ambience/bed_common.ogg",
}
const BED_FALLBACK := "ambience/bed_common.ogg"

## 구역 기본 텍스처. 방별 지정(ROOM_TEX)이 있으면 그쪽이 이긴다.
## 정비 구역은 비워 둔다 — 넓고 빈 공간이라 베드만 남기는 편이 낫다.
const ZONE_TEX := {
	RoomData.ZONE_WORKSHOP: [],
	RoomData.ZONE_POWER: ["ambience/tex_power_machine_01.ogg"],
	RoomData.ZONE_CREW: ["ambience/tex_crew_quiet.ogg"],
	RoomData.ZONE_HYDRO: ["ambience/tex_hydro_air.ogg"],
	RoomData.ZONE_RESEARCH: ["ambience/tex_terminal_noise.ogg"],
}

## 방별 텍스처. 앞의 TEX_SLOTS 개까지만 깔린다.
const ROOM_TEX := {
	# 전력 — 고전압 위협감은 릴레이실과 축전기 저장고에만. 구역 전체에 깔면 금방 무뎌진다.
	"power_relay": ["ambience/tex_power_highvolt.ogg", "ambience/tex_power_machine_01.ogg"],
	"capacitor_vault": ["ambience/tex_power_highvolt.ogg"],
	"generator": ["ambience/tex_power_machine_02.ogg"],
	"cable_run": ["ambience/tex_power_machine_02.ogg"],
	# 수경재배 — 이 구역을 살아 있게 만드는 건 펌프와 물이다.
	"greenhouse": ["ambience/tex_hydro_air.ogg", "ambience/tex_hydro_pump.ogg"],
	"pump_corr": ["ambience/tex_hydro_pump.ogg"],
	"tank_room": ["ambience/tex_hydro_water.ogg", "ambience/tex_hydro_pump.ogg"],
	"nursery": ["ambience/tex_hydro_air.ogg"],
	"hydro_lock": ["ambience/tex_hydro_air.ogg"],
	# 정비 — 설비가 실제로 도는 두 방만 기계음을 얹는다.
	"workshop": ["ambience/tex_power_machine_01.ogg"],
	"hangar": ["ambience/tex_power_machine_02.ogg"],
	# 연구 — 관제·분석 쪽은 단말기 노이즈가 어울린다.
	"diagnostics": ["ambience/tex_terminal_noise.ogg"],
	"analysis_lab": ["ambience/tex_terminal_noise.ogg"],
	"cold_vault": ["ambience/tex_power_machine_02.ogg"],
}

const TEX_SLOTS := 2           # 동시에 까는 텍스처 최대 겹수

## 앰비언스 랩(로비 → "앰비언스 랩")에서 슬롯에 끼워 볼 수 있는 파일 전체.
## 랩이 , / . 로 이 목록을 돈다. 새 루프를 스테이징하면 여기에도 추가할 것.
const AMB_FILES := [
	"ambience/bed_common.ogg", "ambience/bed_workshop.ogg", "ambience/bed_power.ogg",
	"ambience/tex_power_highvolt.ogg", "ambience/tex_power_machine_01.ogg", "ambience/tex_power_machine_02.ogg",
	"ambience/tex_hydro_air.ogg", "ambience/tex_hydro_pump.ogg", "ambience/tex_hydro_water.ogg",
	"ambience/tex_crew_quiet.ogg", "ambience/tex_terminal_noise.ogg",
	# 옛 Kenney 베드 — 비교용으로 남겨 둔다
	"ambience/rumble_01.ogg", "ambience/rumble_02.ogg", "ambience/rumble_03.ogg", "ambience/machine_01.ogg",
]

## 방별 수치 보정. 랩에서 저장하면 여기에 쌓이고 다음 실행부터 위의 기본값을 덮는다.
## 프로젝트 안에 두어 커밋된다 (foreground/<방>.json 과 같은 생각).
const TUNING_PATH := "res://ambience/tuning.json"

## 레벨은 소스 파일의 RMS 와 한 쌍이다 — 둘 중 하나만 보면 반드시 틀린다.
## 스테이징(Tools/stage_ambience.py)이 모든 앰비언스를 -14dBFS 로 맞춰 내보내므로
## 아래 값은 그 -14 를 전제로 한다. 파일을 다시 뽑을 때 목표 RMS 를 바꾸면 여기도 따라와야 한다.
const BED_DB := -5.0           # Ambience 버스(-10dB)를 한 번 더 통과한다 → 실효 -29dBFS
const TEX_DB := -11.0          # 베드보다 6dB 아래 — 텍스처가 베드를 밀어내면 안 된다

## crest 가 큰 네 파일은 피크에 걸려 -14dBFS 까지 못 올라갔다(물 튐·전기 스파크 같은
## 순간 피크가 평균보다 20dB 높다). 파일을 더 밀면 찌그러지므로 모자란 만큼을
## 재생 게인으로 되돌린다. 값은 stage_ambience.py 가 찍어 주는 "목표보다 N dB 낮음" 그대로다.
const TEX_TRIM := {
	"ambience/tex_power_machine_02.ogg": 6.0,
	"ambience/tex_crew_quiet.ogg": 5.5,
	"ambience/tex_hydro_air.ogg": 4.1,
	"ambience/tex_terminal_noise.ogg": 3.3,
}
const BED_FADE := 1.4          # 방 전환 시 크로스페이드 (초)

const DRIP_INTERVAL := Vector2(5.5, 13.0)   # 물방울 원샷 간격 범위 (초)
const DRIP_SPREAD := 900.0                  # 플레이어 기준 좌우로 흩뿌리는 범위

const POOL_2D := 20            # 월드 보이스 (위치 기반)
const POOL_FLAT := 6           # 비위치 보이스 (월드가 아직 없을 때의 대비책)
## 대사 블립 전용 풀. 공용 flat 풀을 같이 쓰면 한 줄 찍는 동안 UI 소리가 낼 자리가 없어진다
## (블립은 초당 열몇 번 난다). 반대로 블립이 UI 에 밀려 빠지는 것도 막는다.
const POOL_VOICE := 4
const MAX_DISTANCE := 3000.0
const PANNING := 0.35          # 낮게 — 사이드뷰에서 하드 패닝은 금방 피로해진다

## 발사 잔향·첫 발 보강 타이밍.
const FIRE_TAIL_DELAY := 0.12  # 사격이 끊기고 이만큼 지나면 방 잔향을 한 번 울린다
const FIRE_BURST_GAP := 0.35   # 이보다 오래 쉬었다 쏘면 "연사 시작"으로 본다
const TURRET_BURST_GAP := 0.30 # 이보다 오래 쉬었다 쏘면 포신 A 부터 다시 시작한다
const FIRE_FIRST_BOOST := 2.5  # 연사 첫 발만 이만큼 크게(dB) — 방아쇠를 당긴 순간이 서야 한다

## --- 총성의 공간감 ---
##
## 총소리가 납작하게 들리는 이유는 샘플이 나빠서가 아니라 **방이 소리에 개입하지 않아서**다.
## 폭 640px 짜리 통로(corr_mid)와 4096px 짜리 격납고(hangar)에서 같은 소리가 나면
## 아무리 좋은 샘플이어도 "녹음을 튼다"로 들린다. 그래서 Weapon 버스에 두 가지를 건다.
##
##   1) 슬랩백(Delay) — 반대쪽 벽을 때리고 돌아오는 첫 반사. 이게 공간의 **크기**를 말해 준다.
##      좌우로 갈라 패닝해서 스테레오 폭도 같이 만든다. 리버브만으로는 안 나오는 부분이다.
##   2) 리버브 — 그 뒤에 남는 잔향. 공간의 **재질**(콘크리트·금속)을 말해 준다.
##
## 픽셀 → 미터 환산은 CELL(128px) ≈ 1 m 로 잡았다. 천장 4~9칸 = 4~9 m, 격납고 41 m —
## 지하 산업시설 치수로 말이 된다. 슬랩 왕복 시간 = 폭(m) / 343(m/s).
const PX_PER_M := 128.0
const SOUND_MPS := 343.0

const SPACE_W_MIN := 640.0     # corr_mid — 가장 좁은 방
const SPACE_W_MAX := 4096.0    # hangar — 가장 넓은 방

## 좁은 방 → 넓은 방으로 갈 때 각 값이 이 범위를 선형으로 오간다.
const SPACE_WET := Vector2(0.10, 0.30)        # 리버브 wet — 넓을수록 잔향이 많이 남는다
const SPACE_ROOM := Vector2(0.30, 0.92)       # 리버브 room_size
const SPACE_DAMP := Vector2(0.80, 0.42)       # 넓을수록 덜 감쇠 = 길게 끌린다
const SPACE_SLAP_DB := Vector2(-17.0, -11.0)  # 슬랩백 레벨 — 넓은 방일수록 또렷하게 들린다
const SPACE_TAIL_DB := Vector2(-5.0, 3.0)     # fire_tail 에 얹는 보정 — 통로에선 죽이고 홀에선 살린다
const SPACE_HIPASS := 0.34     # 저역은 리버브에 넣지 않는다. 넣으면 연사에서 바로 진창이 된다
const SLAP2_RATIO := 1.68      # 두 번째 반사(다른 벽) 시간 배율 — 정수배를 피해야 통처럼 안 울린다

var enabled := true

var _streams := {}             # 경로 → AudioStream
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_flat: Array[AudioStreamPlayer] = []
var _pool_voice: Array[AudioStreamPlayer] = []
var _murmur: AudioStreamPlayer                 # 웅얼거림 이음 루프 (한 번에 한 사람만 말한다)
var _murmur_voice := ""
var _murmur_tween: Tween
var _pool_root: Node2D
var _last_played := {}         # 키 → 마지막 재생 시각
var _active := {}              # 키 → 현재 울리는 보이스 수

var _bed_a: AudioStreamPlayer
var _bed_b: AudioStreamPlayer
var _bed_front := true         # 지금 소리를 내고 있는 쪽이 _bed_a 인가
var _bed_tween: Tween
var _room := ""                             # 지금 울리고 있는 방 (랩이 어느 방을 고치는지 판단)
var _tuning := {}                           # 방 id → 보정값 (TUNING_PATH 에서 읽는다)
var _tex: Array[AudioStreamPlayer] = []     # 텍스처 슬롯 (TEX_SLOTS 개)
var _tex_path: Array[String] = []           # 슬롯이 지금 물고 있는 경로 — 같으면 건드리지 않는다
var _tex_tween: Array[Tween] = []
var _drip_t := 0.0
var _listener: Node2D          # 물방울을 뿌릴 기준 (플레이어)

var _fire_last := -99.0        # 마지막 발사 시각 — 잔향과 첫 발 보강의 기준
var _fire_pos := Vector2.ZERO  # 마지막 총구 위치 (잔향을 여기서 울린다)
var _fire_tail_db := 0.0
var _fire_tail_done := true

var _turret_barrel := 0        # 다음에 울릴 센트리건 포신 (0 = A, 1 = B)
var _turret_last := -99.0      # 마지막 센트리건 발사 시각

var _weapon_delay: AudioEffectDelay     # 벽 반사(슬랩백)
var _weapon_reverb: AudioEffectReverb   # 그 뒤에 남는 잔향
var _space_tail_db := 0.0               # 방 크기에 따른 fire_tail 보정


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_build_pools()
	_build_beds()
	_drip_t = randf_range(DRIP_INTERVAL.x, DRIP_INTERVAL.y)
	_load_tuning()


# ---------------------------------------------------------------- 버스

## 버스를 코드로 구성한다. .tres 를 따로 두지 않아 에디터 설정과 어긋날 일이 없다.
func _setup_buses() -> void:
	AudioServer.set_bus_volume_db(0, MIX[BUS_MASTER])
	_add_master_limiter()
	for bus_name in [BUS_SFX, BUS_WEAPON, BUS_AMB, BUS_UI, BUS_VOICE]:
		var idx := _ensure_bus(bus_name)
		AudioServer.set_bus_volume_db(idx, MIX[bus_name])
		# Weapon 은 SFX 를 거쳐 나간다 — SFX 페이더 하나로 효과음 전체를 잡을 수 있다
		AudioServer.set_bus_send(idx, BUS_SFX if bus_name == BUS_WEAPON else BUS_MASTER)
		if LOWPASS.has(bus_name):
			_add_lowpass(idx, LOWPASS[bus_name])
	_build_weapon_space()
	_add_ambience_duck()


## Weapon 버스의 공간계. 순서가 중요하다 —
## 로우패스로 먼저 고역을 깎고, 그 결과를 벽에 튕기고(Delay), 남은 것이 잔향(Reverb)이 된다.
## 반대로 걸면 반사음만 쨍하게 남아 오히려 더 납작해진다.
func _build_weapon_space() -> void:
	var idx := AudioServer.get_bus_index(BUS_WEAPON)
	if idx < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(idx)):
		var fx := AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectDelay:
			_weapon_delay = fx
		elif fx is AudioEffectReverb:
			_weapon_reverb = fx

	if _weapon_delay == null:
		var d := AudioEffectDelay.new()
		d.dry = 1.0                     # 직접음은 그대로 두고 반사만 더한다
		d.tap1_active = true
		d.tap2_active = true
		d.tap1_pan = 0.42               # 두 반사를 좌우로 갈라 스테레오 폭을 만든다
		d.tap2_pan = -0.36
		d.feedback_active = false       # 피드백은 쓰지 않는다 — 초당 11발에서 금세 쌓인다
		AudioServer.add_bus_effect(idx, d)
		_weapon_delay = d

	if _weapon_reverb == null:
		var r := AudioEffectReverb.new()
		r.dry = 1.0
		r.spread = 1.0
		r.hipass = SPACE_HIPASS
		AudioServer.add_bus_effect(idx, r)
		_weapon_reverb = r

	_apply_room_space(SPACE_W_MIN)      # 방이 정해지기 전 기본값 = 가장 좁은 공간


## 방 크기로 총성의 공간감을 결정한다. set_room_ambience 에서 방을 옮길 때마다 부른다.
func _apply_room_space(width_px: float) -> void:
	var t := clampf((width_px - SPACE_W_MIN) / (SPACE_W_MAX - SPACE_W_MIN), 0.0, 1.0)
	var slap := width_px / PX_PER_M / SOUND_MPS          # 반대쪽 벽 왕복 시간(초)

	if _weapon_delay != null:
		_weapon_delay.tap1_delay_ms = clampf(slap * 1000.0, 5.0, 500.0)
		_weapon_delay.tap2_delay_ms = clampf(slap * 1000.0 * SLAP2_RATIO, 5.0, 500.0)
		_weapon_delay.tap1_level_db = lerpf(SPACE_SLAP_DB.x, SPACE_SLAP_DB.y, t)
		_weapon_delay.tap2_level_db = lerpf(SPACE_SLAP_DB.x, SPACE_SLAP_DB.y, t) - 5.0

	if _weapon_reverb != null:
		_weapon_reverb.room_size = lerpf(SPACE_ROOM.x, SPACE_ROOM.y, t)
		_weapon_reverb.damping = lerpf(SPACE_DAMP.x, SPACE_DAMP.y, t)
		_weapon_reverb.wet = lerpf(SPACE_WET.x, SPACE_WET.y, t)
		_weapon_reverb.predelay_msec = clampf(slap * 1000.0 * 0.5, 1.0, 250.0)

	_space_tail_db = lerpf(SPACE_TAIL_DB.x, SPACE_TAIL_DB.y, t)


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	return idx


## 어떤 상황에서도 마스터가 클리핑하지 않게 하는 마지막 안전망.
##
## release 가 0.12 였을 때 문제가 있었다 — 발사 간격이 0.09초라 **릴리스가 발사 간격보다 길었다.**
## 연사를 시작하면 리미터가 한 번도 회복하지 못하고 계속 눌린 상태로 남는다.
## 그러면 리미터가 깎는 것이 정확히 타격감을 만드는 어택 피크다. 소리는 크게 틀었는데
## 펀치만 사라지는, 원인 찾기 고약한 종류의 먹먹함이다.
## 0.035 로 내려 **발사와 발사 사이에 반드시 원래대로 돌아오게** 했다.
func _add_master_limiter() -> void:
	for i in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -1.5
	lim.pre_gain_db = 0.0
	lim.release = 0.035
	AudioServer.add_bus_effect(0, lim)


## 총을 쏘는 동안 앰비언스를 눌러 비켜 준다(사이드체인 덕킹).
##
## 체감 음량은 절대값이 아니라 **주변과의 차이**로 정해진다. 총성만 키우면 한계가 있지만
## 쏘는 순간 방 소리가 움찔하고 물러나면, 같은 dB 라도 훨씬 크고 위협적으로 들린다.
## 총성이 끝나면 앰비언스가 천천히 돌아오면서 "방금 시끄러웠다"는 여운까지 남는다.
##
## Weapon 버스를 키로 삼고 Ambience 를 누른다. Weapon 자신은 SFX 를 거쳐 나가므로
## 이 컴프레서를 통과하지 않는다 — 총소리 자체는 전혀 눌리지 않는다.
func _add_ambience_duck() -> void:
	var idx := AudioServer.get_bus_index(BUS_AMB)
	if idx < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectCompressor:
			return
	var c := AudioEffectCompressor.new()
	c.threshold = -32.0
	c.ratio = 6.0
	c.attack_us = 3000.0      # 3ms — 첫 발과 함께 즉시 물러난다
	c.release_ms = 420.0      # 천천히 돌아온다. 빠르면 앰비언스가 펌핑으로 들린다
	c.gain = 0.0
	c.mix = 1.0
	c.sidechain = BUS_WEAPON
	AudioServer.add_bus_effect(idx, c)


func _add_lowpass(idx: int, cutoff: float) -> void:
	for i in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectLowPassFilter:
			return
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = cutoff
	lp.resonance = 0.25
	AudioServer.add_bus_effect(idx, lp)


# ---------------------------------------------------------------- 보이스 풀

func _build_pools() -> void:
	_pool_root = Node2D.new()
	_pool_root.name = "VoicePool"
	add_child(_pool_root)
	for i in range(POOL_2D):
		var p := AudioStreamPlayer2D.new()
		p.max_distance = MAX_DISTANCE
		p.attenuation = 1.0
		p.panning_strength = PANNING
		_pool_root.add_child(p)
		_pool_2d.append(p)
	for i in range(POOL_FLAT):
		var f := AudioStreamPlayer.new()
		add_child(f)
		_pool_flat.append(f)
	for i in range(POOL_VOICE):
		var v := AudioStreamPlayer.new()
		add_child(v)
		_pool_voice.append(v)
	_murmur = AudioStreamPlayer.new()
	_murmur.name = "VoiceMurmur"
	add_child(_murmur)


## 월드(카메라가 있는 뷰포트)에 보이스 풀을 붙인다. 이걸 호출해야 위치 기반 패닝이 동작한다.
##
## 월드는 SubViewport 안에 있다(main.gd:_setup_view). 여기에 함정이 하나 있다 —
## AudioStreamPlayer2D 는 자기가 속한 뷰포트에 2D 리스너가 켜져 있어야만 소리를 낸다.
## 루트 창은 기본으로 켜져 있지만 **SubViewport 는 audio_listener_enable_2d 가 기본 false** 다.
## 켜 주지 않으면 발사·발소리·탄착이 전부 무음이 된다(경고도 안 뜬다).
## 그래서 붙이는 쪽에서 리스너까지 같이 책임진다 — 뷰 구조가 바뀌어도 빠뜨릴 일이 없다.
func attach_to_world(world: Node) -> void:
	if world == null or _pool_root == null:
		return
	if _pool_root.get_parent() != world:
		_pool_root.get_parent().remove_child(_pool_root)
		world.add_child(_pool_root)
	var vp := world.get_viewport()
	if vp != null:
		vp.audio_listener_enable_2d = true


## 물방울을 뿌릴 기준점(보통 플레이어).
func set_listener(node: Node2D) -> void:
	_listener = node


func _free_2d() -> AudioStreamPlayer2D:
	for p in _pool_2d:
		if not p.playing:
			return p
	return null


func _free_flat() -> AudioStreamPlayer:
	for p in _pool_flat:
		if not p.playing:
			return p
	return null


## 블립은 **가장 오래된 것을 밀어내고서라도** 울린다. 한 자 찍혔는데 소리가 빠지면
## 그 자리만 발음이 사라진 것처럼 들리기 때문이다 (총소리와 반대의 판단).
func _free_voice() -> AudioStreamPlayer:
	for p in _pool_voice:
		if not p.playing:
			return p
	var oldest: AudioStreamPlayer = _pool_voice[0]
	for p in _pool_voice:
		if p.get_playback_position() > oldest.get_playback_position():
			oldest = p
	return oldest


# ---------------------------------------------------------------- 재생

func _stream(rel: String) -> AudioStream:
	if _streams.has(rel):
		return _streams[rel]
	var path := DIR + rel
	if not ResourceLoader.exists(path):
		push_warning("오디오 파일 없음: %s" % path)
		_streams[rel] = null
		return null
	var s: AudioStream = load(path)
	_streams[rel] = s
	return s


## 이 키를 지금 울려도 되는지 — 최소 간격과 동시 보이스 수를 함께 본다.
func _allowed(key: String, cfg: Dictionary) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var gap := float(cfg.get("gap", 0.0))
	if gap > 0.0 and now - float(_last_played.get(key, -99.0)) < gap:
		return false
	if int(_active.get(key, 0)) >= int(cfg.get("voices", 4)):
		return false
	return true


func _apply(player, cfg: Dictionary) -> void:
	var pitch: Array = cfg.get("pitch", [1.0, 1.0])
	player.pitch_scale = randf_range(float(pitch[0]), float(pitch[1]))
	var var_db := float(cfg.get("db_var", 0.0))
	player.volume_db = float(cfg["db"]) + randf_range(-var_db, var_db)
	player.bus = cfg.get("bus", BUS_SFX)


## 월드 좌표에서 한 발. db_offset 으로 호출부에서 개별 감쇠를,
## pitch_mul 로 개별 음정 배율을 줄 수 있다 (거대종처럼 같은 목소리를 몸집만큼 끌어내릴 때).
func play_at(key: String, pos: Vector2, db_offset := 0.0, pitch_mul := 1.0) -> void:
	if not enabled or not SOUNDS.has(key):
		return
	var cfg: Dictionary = SOUNDS[key]
	if not _allowed(key, cfg):
		return
	var files: Array = cfg["files"]
	var s := _stream(String(files[randi() % files.size()]))
	if s == null:
		return
	var p := _free_2d()
	if p == null:
		return          # 풀이 꽉 찼으면 조용히 버린다 — 억지로 끼워 넣으면 소리가 뭉친다
	_apply(p, cfg)
	p.volume_db += db_offset
	p.pitch_scale *= pitch_mul
	p.global_position = pos
	p.stream = s
	p.play()
	_mark(key, p)


## 위치가 없는 한 발 (UI 등).
func play(key: String, db_offset := 0.0) -> void:
	if not enabled or not SOUNDS.has(key):
		return
	var cfg: Dictionary = SOUNDS[key]
	if not _allowed(key, cfg):
		return
	var files: Array = cfg["files"]
	var s := _stream(String(files[randi() % files.size()]))
	if s == null:
		return
	var p := _free_flat()
	if p == null:
		return
	_apply(p, cfg)
	p.volume_db += db_offset
	p.stream = s
	p.play()
	_mark(key, p)


## 대사 블립 한 방. 말풍선에 글자가 찍힐 때마다 dialogue_bubble.gd 가 부른다.
##
## vowel 이 빈 문자열이면 아무 모음이나 고른다("모음 블립" 방식), 주어지면 그 모음을 낸다
## ("음소 블립" 방식 — 그 글자의 실제 중성이 넘어온다).
##
## 다른 소리와 달리 **음높이를 밖에서 정해 넘긴다** — 같은 "slow" 말투여도
## 아르카디와 델 박사가 같은 목소리면 안 되고(인물별 tone), 한 줄 안에서도
## 글자마다 조금씩 흘려야 사람이 말하는 것처럼 들리기 때문이다.
## 대화는 화면이 말하는 사람에게 가 있는 순간이라 위치 패닝을 주지 않는다.
func voice_blip(voice_id: String, vowel := "", pitch := 1.0, db_offset := 0.0) -> void:
	var v: String = vowel if vowel != "" else DialogueVoice.VOWELS[randi() % DialogueVoice.VOWELS.size()]
	_voice_one_shot("%s%s_%s.wav" % [VOICE_DIR, voice_id, v], voice_id, pitch, db_offset)


## 줄머리 한마디 — 줄이 시작될 때 한 번. 세 벌 중 하나를 고른다.
func voice_opener(voice_id: String, pitch := 1.0, db_offset := 0.0) -> void:
	var n := 1 + randi() % VOICE_OPEN_COUNT
	_voice_one_shot("%s%s_open_%02d.wav" % [VOICE_DIR, voice_id, n], voice_id, pitch,
		db_offset + VOICE_OPEN_DB)


## 대사 음성의 원샷 재생.
##
## _allowed()/_mark() 를 타지 않는다. 울릴 간격은 이미 호출부(말투별 gap)가 걸러 보내고,
## 밀어내기(_free_voice)로 재생 중인 보이스를 가로채면 finished 가 오지 않아
## 동시 보이스 수 집계가 한쪽으로만 쌓여 영영 막히기 때문이다.
func _voice_one_shot(rel: String, voice_id: String, pitch: float, db_offset: float) -> void:
	if not enabled:
		return
	var s := _stream(rel)
	if s == null:
		return
	var p := _free_voice()
	if p == null:
		return
	p.bus = BUS_VOICE
	p.volume_db = float(VOICE_DB.get(voice_id, -4.0)) + randf_range(-VOICE_DB_VAR, VOICE_DB_VAR) + db_offset
	p.pitch_scale = clampf(pitch, 0.4, 2.4)
	p.stream = s
	p.play()


# ---------------------------------------------------------------- 웅얼거림

## 말하는 동안 계속 도는 이음 루프를 켠다 ("웅얼거림" 방식).
## 같은 인물로 이미 돌고 있으면 음높이만 갈아 준다 — 다시 틀면 줄 중간에 이음매가 들린다.
func voice_murmur_start(voice_id: String, pitch := 1.0) -> void:
	if not enabled or _murmur == null:
		return
	voice_murmur_pitch(pitch)
	if _murmur.playing and _murmur_voice == voice_id:
		return
	var s := _looped(VOICE_DIR + voice_id + "_murmur.wav")
	if s == null:
		return
	_murmur_voice = voice_id
	_murmur.stream = s
	_murmur.bus = BUS_VOICE
	_murmur.volume_db = -60.0
	_murmur.play()
	_murmur_fade(float(VOICE_MURMUR_DB) + float(VOICE_DB.get(voice_id, -4.0)), false)


## 문장 억양을 따라 음높이만 움직인다 (호출부가 매 프레임 부른다).
func voice_murmur_pitch(pitch: float) -> void:
	if _murmur != null:
		_murmur.pitch_scale = clampf(pitch, 0.4, 2.4)


func voice_murmur_stop() -> void:
	if _murmur != null and _murmur.playing:
		_murmur_fade(-60.0, true)


func _murmur_fade(to_db: float, stop_after: bool) -> void:
	if _murmur_tween != null and _murmur_tween.is_valid():
		_murmur_tween.kill()
	_murmur_tween = create_tween()
	_murmur_tween.tween_property(_murmur, "volume_db", to_db, VOICE_MURMUR_FADE)
	if stop_after:
		_murmur_tween.tween_callback(func() -> void:
			_murmur.stop()
			_murmur_voice = "")


func _mark(key: String, player) -> void:
	_last_played[key] = Time.get_ticks_msec() / 1000.0
	_active[key] = int(_active.get(key, 0)) + 1
	var release := func() -> void:
		_active[key] = maxi(int(_active.get(key, 1)) - 1, 0)
	player.finished.connect(release, CONNECT_ONE_SHOT)


# ---------------------------------------------------------------- 복합 이벤트

## 발사 = 보디 + 두께 + 어택 + 저역 4레이어. 저역은 gap 이 걸러 두 발에 한 번만 깔린다.
## 연사 시작 첫 발만 조금 크게 — 사격이 "시작"되는 느낌이 살면서 평균 음량은 그대로다.
func fire(pos: Vector2, db_offset := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var opening := now - _fire_last > FIRE_BURST_GAP
	var boost := FIRE_FIRST_BOOST if opening else 0.0
	play_at("fire_body", pos, db_offset + boost)
	play_at("fire_body2", pos, db_offset + boost)
	play_at("fire_attack", pos, db_offset + boost)
	play_at("fire_sub", pos, db_offset)
	_fire_last = now
	_fire_pos = pos
	_fire_tail_db = db_offset
	_fire_tail_done = false


## 센트리건 발사 = 포신 A/B 교대 + 매 발 얹는 크랙.
##
## 교대가 핵심이다. 한 장을 반복하면 초당 18발이 기계적인 연속음이 되는데,
## 좌우로 갈린 두 샘플이 번갈아 오면 "두 문이 교대로 때린다"로 들린다.
## 발사가 한참 끊겼다가 다시 시작하면 늘 A 부터 — 첫 발이 매번 같아야 시작이 또렷하다.
##
## 플레이어와 다른 샘플을 쓰므로 방 잔향(fire_tail)은 따로 달지 않는다.
func turret_fire(pos: Vector2, db_offset := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _turret_last > TURRET_BURST_GAP:
		_turret_barrel = 0
	play_at("turret_fire_a" if _turret_barrel == 0 else "turret_fire_b", pos, db_offset)
	play_at("turret_crack", pos, db_offset)
	_turret_barrel = 1 - _turret_barrel
	_turret_last = now


## 탄착. 재질에 따라 채택된 두 샘플 중 하나로 간다.
## power 가 큰 탄일수록 조금 더 크게 울린다.
func impact(kind: String, pos: Vector2, power := 1.0) -> void:
	var key := "impact_stone"
	if kind == "prop":
		key = "impact_wood"
	elif kind == "none":
		return
	play_at(key, pos, linear_to_db(clampf(power, 0.5, 2.0)) * 0.5)


# ---------------------------------------------------------------- 앰비언스

func _build_beds() -> void:
	_bed_a = _make_bed()
	_bed_b = _make_bed()
	for i in range(TEX_SLOTS):
		_tex.append(_make_bed())
		_tex_path.append("")
		_tex_tween.append(null)


func _make_bed() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS_AMB
	p.volume_db = -80.0
	add_child(p)
	return p


func _looped(rel: String) -> AudioStream:
	var s := _stream(rel)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	elif s is AudioStreamWAV:
		# wav 는 루프 구간을 프레임 수로 준다. 임포트 설정 대신 여기서 켜는 이유는
		# 같은 파일을 원샷으로 쓰는 일이 없어서다 — 웅얼거림 전용이다.
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return s


## 방에 맞는 앰비언스로 넘어간다 — 구역이 정하는 베드 위에 방이 정하는 텍스처를 얹는다.
## 구역이 같으면 베드는 그대로 두고 텍스처만 갈아 끼우므로, 한 구역을 걸어 다니는 동안
## 바닥 소리는 이어지고 방의 성격만 바뀐다.
func set_room_ambience(room_id: String) -> void:
	if not enabled:
		return
	# 앰비언스보다 먼저 — 방을 옮기면 총성이 울리는 방식도 같이 바뀌어야 한다.
	# 베드와 달리 이건 같은 구역 안에서 옆방으로 가도 매번 갱신한다. 통로와 홀은
	# 같은 구역이어도 크기가 3배 차이 나고, 그 차이가 곧 공간감이기 때문이다.
	if RoomData.has_room(room_id):
		_apply_room_space(float(RoomData.room_width(room_id)))

	_room = room_id
	var plan := plan_for(room_id)
	var s := _looped(String(plan["bed"]))
	if s == null:
		return

	# 같은 구역 안에서 옆방으로 넘어간 것뿐이면 베드는 건드리지 않는다.
	# 크로스페이드를 걸면 문을 지날 때마다 공간이 한 번씩 흔들린다.
	var front: AudioStreamPlayer = _bed_a if _bed_front else _bed_b
	if front.stream != s or not front.playing:
		var incoming := _bed_b if _bed_front else _bed_a
		var outgoing := _bed_a if _bed_front else _bed_b
		_bed_front = not _bed_front

		incoming.stream = s
		incoming.volume_db = -80.0
		incoming.play()

		if _bed_tween != null and _bed_tween.is_valid():
			_bed_tween.kill()
		_bed_tween = create_tween()
		_bed_tween.set_parallel(true)
		_bed_tween.tween_property(incoming, "volume_db", float(plan["bed_db"]), BED_FADE)
		_bed_tween.tween_property(outgoing, "volume_db", -80.0, BED_FADE)
		_bed_tween.chain().tween_callback(outgoing.stop)
	else:
		front.volume_db = float(plan["bed_db"])     # 베드는 이어 가되 보정값은 즉시 반영

	# 텍스처는 방이 정한다. 방별 지정이 없으면 구역 기본으로 떨어진다.
	var want: Array = plan["tex"]
	for i in range(TEX_SLOTS):
		if i < want.size():
			_set_texture(i, String(want[i]["file"]), float(want[i]["db"]))
		else:
			_set_texture(i, "", 0.0)
	ambience_changed.emit(room_id, plan)


## 텍스처 슬롯 하나를 다른 루프로 갈아 끼운다. 빈 문자열이면 비운다.
## 같은 경로면 아무것도 하지 않는다 — 구역 안을 돌아다니는 동안 펌프 소리가
## 방마다 끊겼다 다시 시작하면 그것만큼 티 나는 게 없다.
func _set_texture(slot: int, rel: String, db: float) -> void:
	if slot >= _tex.size() or _tex_path[slot] == rel:
		return
	_tex_path[slot] = rel
	var p := _tex[slot]
	var s: AudioStream = _looped(rel) if rel != "" else null
	if s == null and not p.playing:
		return          # 뺄 것도 넣을 것도 없다 (파일 없음 포함) — 빈 트윈을 만들지 않는다

	if _tex_tween[slot] != null and _tex_tween[slot].is_valid():
		_tex_tween[slot].kill()
	var t := create_tween()
	_tex_tween[slot] = t

	# 앞의 것을 반쯤에 걸쳐 빼고, 뒤의 것을 나머지 반에 걸쳐 넣는다.
	if p.playing:
		t.tween_property(p, "volume_db", -80.0, BED_FADE * 0.5)
		t.tween_callback(p.stop)
	if s != null:
		t.tween_callback(_start_texture.bind(slot, s))
		t.tween_property(p, "volume_db", db, BED_FADE * 0.5)


func _start_texture(slot: int, s: AudioStream) -> void:
	var p := _tex[slot]
	p.stream = s
	p.volume_db = -80.0
	p.play()


# ------------------------------------------------- 앰비언스 튜닝 (랩이 쓰는 API)

## 이 방에서 무엇이 어떤 크기로 울려야 하는가. 기본값(ZONE_BEDS·ROOM_TEX·TEX_TRIM) 위에
## 저장된 보정(TUNING_PATH)을 덮어 돌려준다. 랩 패널도 재생부도 전부 이 한 곳을 본다.
##   { "bed": 경로, "bed_db": float, "tex": [ {"file": 경로, "db": float}, ... ] }
func plan_for(room_id: String) -> Dictionary:
	var zone := String(RoomData.get_room_or(room_id, {}).get("zone", ""))
	var plan := {
		"bed": String(ZONE_BEDS.get(zone, BED_FALLBACK)),
		"bed_db": BED_DB,
		"tex": [],
	}
	for f in ROOM_TEX.get(room_id, ZONE_TEX.get(zone, [])):
		var rel := String(f)
		plan["tex"].append({"file": rel, "db": TEX_DB + float(TEX_TRIM.get(rel, 0.0))})

	var t: Dictionary = _tuning.get(room_id, {})
	if t.has("bed"):
		plan["bed"] = String(t["bed"])
	if t.has("bed_db"):
		plan["bed_db"] = float(t["bed_db"])
	if t.has("tex"):
		var tex := []
		for e in t["tex"]:
			tex.append({"file": String(e["file"]), "db": float(e["db"])})
		plan["tex"] = tex
	return plan


## 랩이 수치를 바꿀 때마다 부른다 — 보정으로 기억하고, 지금 그 방에 있으면 즉시 반영한다.
## 볼륨만 달라졌으면 페이드 없이 바로 바꾼다(손으로 돌리는 노브처럼 반응해야 한다).
## 파일이 달라졌으면 _set_texture 가 평소대로 크로스페이드한다.
func apply_plan(room_id: String, plan: Dictionary) -> void:
	_tuning[room_id] = {
		"bed": String(plan["bed"]),
		"bed_db": float(plan["bed_db"]),
		"tex": plan["tex"].duplicate(true),
	}
	if room_id != _room:
		return
	var front: AudioStreamPlayer = _bed_a if _bed_front else _bed_b
	var s := _looped(String(plan["bed"]))
	if s != null and front.stream != s:
		set_room_ambience(room_id)          # 베드 교체는 크로스페이드를 타야 한다
		return
	front.volume_db = float(plan["bed_db"])
	var want: Array = plan["tex"]
	for i in range(TEX_SLOTS):
		var rel := String(want[i]["file"]) if i < want.size() else ""
		var db := float(want[i]["db"]) if i < want.size() else 0.0
		if _tex_path[i] == rel:
			if rel != "":
				_tex[i].volume_db = db      # 같은 파일이면 노브만 돌린다
		else:
			_set_texture(i, rel, db)
	ambience_changed.emit(room_id, plan)


## 이 방 보정을 지우고 기본값으로 되돌린다.
func reset_room(room_id: String) -> void:
	_tuning.erase(room_id)
	if room_id == _room:
		set_room_ambience(room_id)


## 보정 전체를 TUNING_PATH 에 쓴다. 방 id 순으로 정렬해 저장해야 커밋 diff 가 읽힌다.
func save_tuning() -> String:
	var out := {}
	var ids: Array = _tuning.keys()
	ids.sort()
	for id in ids:
		out[id] = _tuning[id]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TUNING_PATH.get_base_dir()))
	var f := FileAccess.open(TUNING_PATH, FileAccess.WRITE)
	if f == null:
		push_error("앰비언스 보정 저장 실패: %s" % TUNING_PATH)
		return ""
	f.store_string(JSON.stringify(out, "	", false) + "
")
	f.close()
	return ProjectSettings.globalize_path(TUNING_PATH)


func tuned_rooms() -> int:
	return _tuning.size()


func has_tuning(room_id: String) -> bool:
	return _tuning.has(room_id)


func current_room_id() -> String:
	return _room


func _load_tuning() -> void:
	if not FileAccess.file_exists(TUNING_PATH):
		return
	var f := FileAccess.open(TUNING_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_tuning = parsed


func stop_ambience() -> void:
	for p in [_bed_a, _bed_b]:
		if p != null:
			p.stop()
	for i in range(_tex.size()):
		_tex[i].stop()
		_tex_path[i] = ""


## 시간에 매달린 두 가지를 돌린다.
##   1) 사격이 끊긴 뒤의 방 잔향 — 트리거를 떼야 울리므로 여기서 감시한다
##   2) 물방울 — 불규칙한 간격으로 흩뿌린다. 규칙적으로 떨어지면 금방 기계처럼 들린다
func _process(delta: float) -> void:
	if not enabled:
		return

	# 사격이 끊긴 뒤 한 번만 울리는 방 잔향. 연사 중에는 _fire_last 가 계속 갱신되므로
	# 여기 조건이 성립하지 않는다 — 즉 트리거를 떼야 비로소 방이 울린다.
	if not _fire_tail_done and Time.get_ticks_msec() / 1000.0 - _fire_last >= FIRE_TAIL_DELAY:
		_fire_tail_done = true
		play_at("fire_tail", _fire_pos, _fire_tail_db + _space_tail_db)

	if _listener == null or not is_instance_valid(_listener):
		return
	if not _bed_a.playing and not _bed_b.playing:
		return
	_drip_t -= delta
	if _drip_t > 0.0:
		return
	_drip_t = randf_range(DRIP_INTERVAL.x, DRIP_INTERVAL.y)
	var at := _listener.global_position + Vector2(randf_range(-DRIP_SPREAD, DRIP_SPREAD), -randf_range(0.0, 260.0))
	play_at("drip", at)


# ---------------------------------------------------------------- 외부 제어

## 카테고리 볼륨 조정 (설정 메뉴용). 0.0 ~ 1.0
func set_category_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, MIX.get(bus_name, 0.0) + linear_to_db(linear))


func set_enabled(on: bool) -> void:
	enabled = on
	AudioServer.set_bus_mute(0, not on)
