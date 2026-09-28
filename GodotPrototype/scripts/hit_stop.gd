class_name HitStop
extends RefCounted
## 히트스톱 — 명중 순간 화면 전체를 아주 짧게(수십 ms) 거의 멈춘다 (Engine.time_scale).
## 무거운 한 방(산탄 몰빵 · 코일 관통 · 처치)이 "맞았다" 로 읽히게 하는 가장 싼 수단이다.
## 해제는 실시간 타이머(ignore_time_scale)로 한다 — 느려진 시간으로 재면 멈춘 동안 타이머도 같이 느려져 20배 길게 멎는다.
##
## ## 해제는 "마지막으로 건 타이머" 가 무조건 한다
## 예전엔 타이머가 울릴 때 벽시계(Time.get_ticks_msec)로 종료 시각이 지났는지 다시 확인했다. 그런데 타이머는
## 프레임 delta 를 누적해 재므로 벽시계와 몇 ms 어긋난다 — 타이머가 조금 **일찍** 울리면 해제를 건너뛰고,
## 그 뒤에는 풀어 줄 타이머가 없어 **다음 명중까지 0.05배속이 계속** 됐다 (산탄으로 치면 슬로모션이 길게 걸리던 버그).
## 이제는 건 순서(serial)만 본다: 더 늦게 끝나는 히트스톱이 새로 걸리면 serial 이 바뀌어 앞 타이머는 무시되고,
## 마지막 타이머는 시계와 상관없이 반드시 1.0 으로 되돌린다. 그리고 MAX_HOLD 를 넘게 멈춰 있는 일은 없다.
## 플레이어 무기 · 장애물 폭발만 쓴다. 자동 전투(버그봇 셋)가 매 발 걸면 화면이 계속 끊긴다.

const SLOW := 0.05
const MAX_HOLD := 0.12              # 한 번에 멈출 수 있는 최대 시간 (초) — 호출부가 큰 값을 줘도 여기서 자른다
static var _until := 0              # 지금 걸린 멈춤이 끝나는 벽시계 (ms) — 더 짧은 요청을 걸러내는 데만 쓴다
static var _serial := 0


static func apply(tree: SceneTree, seconds: float) -> void:
	if tree == null or seconds <= 0.0:
		return
	seconds = minf(seconds, MAX_HOLD)
	var now := Time.get_ticks_msec()
	var until := now + int(seconds * 1000.0)
	if Engine.time_scale < 1.0 and until <= _until:
		return                       # 이미 걸린 멈춤이 더 늦게 끝난다 — 그 타이머가 푼다
	_until = until
	_serial += 1
	var mine := _serial
	Engine.time_scale = SLOW
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if mine == _serial:
			_release())


static func _release() -> void:
	_until = 0
	Engine.time_scale = 1.0


## 씬 전환 · 테스트 정리용 — 걸려 있던 멈춤을 즉시 푼다
static func clear() -> void:
	_serial += 1
	_release()
