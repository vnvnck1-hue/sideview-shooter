class_name WeaponCatalog
extends RefCounted
## 새 무기 수치표. 기준은 기존 소총(Player.FIRE_COOLDOWN 0.09 · 탄속 20800 · 반동 라이트 40px)이다 —
## 한 발이 더 무거운 대신 **느려지지 않게** 잡는다. 탄은 전부 기존 소총과 같은 고속 궤적(Bullet)으로 날아가고,
## 쿨다운·충전은 "손맛이 끊기지 않는" 범위(0.5초 이내)에 둔다.
##   cooldown   : 발사 간격 (홀드 연사)
##   charge     : 충전 시간 (0 = 즉발)
##   recoil     : 반동 스프링 임펄스 배율 (Player.RECOIL 라이트 = 1.0)
##   climb      : 총구가 들리는 각 배율 (Player.RECOIL.arm_rad 기준)
##   kickback   : 발사 순간 몸이 뒤로 밀리는 속도 (px/s)
##   shake      : 카메라 흔들림 (기존 소총 SHAKE_PER_SHOT 3.5)
##   hitstop    : 명중 시 화면 전체가 멎는 시간 (초) — 플레이어 무기만
##   gun_scale  : 컨셉 원화(총+팔 레이어) → 월드 배율. 기존 캐릭터 키(≈225)에 원화 속 총 비율을 맞춘 값
##   flash      : 총구 화염 스프라이트 배율 · light = 총구 라이트 세기 배율
const BULLDOG := "bulldog"
const COIL := "coil"
const ARC := "arc_weaver"
const DATA := {
	"bulldog": {"name": "불독", "mag": 8, "reload": 1.0, "cooldown": 0.28, "charge": 0.0,
		"recoil": 1.9, "climb": 3.2, "kickback": 520.0, "shake": 8.0, "hitstop": 0.045,
		"gun_scale": 0.58, "flash": 2.3, "light": 1.5,
		"pellets": 7, "spread": 0.052, "power": 1.0, "damage": 1, "max_per_target": 3,
		"color": Color(1.0, 0.42, 0.10)},
	"coil": {"name": "코일랜스", "mag": 6, "reload": 1.15, "cooldown": 0.14, "charge": 0.3,
		"recoil": 2.3, "climb": 2.4, "kickback": 640.0, "shake": 10.0, "hitstop": 0.065,
		"gun_scale": 0.62, "flash": 1.9, "light": 1.7,
		"pierce": 6, "power": 2.2, "damage": 3,
		"color": Color(0.10, 0.85, 1.0)},
	"arc_weaver": {"name": "아크위버", "mag": 0, "reload": 0.0, "cooldown": 0.42, "charge": 0.0,
		"recoil": 1.0, "climb": 1.0, "kickback": 0.0, "shake": 3.2, "hitstop": 0.0,
		"speed": 2900.0, "power": 1.5, "damage": 3, "chain_damage": 2, "chain_range": 360.0, "chain_count": 3,
		"stun": 0.16, "slow": 2.2,
		"color": Color(0.20, 1.0, 0.86)},
}


static func data(id: String) -> Dictionary:
	return DATA.get(id, DATA[BULLDOG])
