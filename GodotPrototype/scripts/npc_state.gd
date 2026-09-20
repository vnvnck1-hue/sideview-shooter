class_name NpcState
extends RefCounted
## NPC 대화가 남기는 **플래그 저장소**. 방을 옮기면 NPC 노드는 사라졌다 다시 만들어지므로
## "무엇을 들었고 무엇을 약속했는가" 는 여기(static)에만 남는다. AppFlow 와 같은 방식.
##
## 플래그는 NpcData.FLAGS 에 뜻이 적혀 있고, 조건식은 아래 test() 가 읽는다.
## 조건식 문법은 일부러 아주 좁다 — 대사 표에서 한눈에 읽혀야 하기 때문이다.
##   ""                빈 문자열 = 항상 참
##   "lockdown"        그 플래그가 서 있으면 참
##   "!promised"       서 있지 않으면 참
##   "power_cut & !promised"   & 로 이은 모든 항이 참이어야 한다

static var flags := {}
## 이미 한 번 끝까지 본 대화 노드 (한 번만 뜨는 인사·소개를 걸러낸다)
static var seen := {}


static func has(flag: String) -> bool:
	return bool(flags.get(flag, false))


static func set_flag(flag: String, value := true) -> void:
	if flag == "":
		return
	flags[flag] = value


static func set_all(list) -> void:
	for f in list:
		set_flag(str(f))


static func mark_seen(key: String) -> void:
	seen[key] = true


static func was_seen(key: String) -> bool:
	return bool(seen.get(key, false))


## "a & !b" 를 평가한다. 알 수 없는 플래그는 거짓.
static func test(cond: String) -> bool:
	var c := cond.strip_edges()
	if c == "":
		return true
	for term in c.split("&"):
		var t := term.strip_edges()
		if t == "":
			continue
		var want := true
		while t.begins_with("!"):
			want = not want
			t = t.substr(1).strip_edges()
		if t.begins_with("seen:"):
			if was_seen(t.substr(5)) != want:
				return false
		elif has(t) != want:
			return false
	return true


## 새 회차 (로비로 나갔다 들어올 때) — 들은 말과 약속을 지운다
static func reset() -> void:
	flags.clear()
	seen.clear()
