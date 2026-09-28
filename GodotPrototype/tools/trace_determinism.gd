extends SceneTree
## 최적화 전후 시뮬레이션이 **똑같은지** 확인하는 궤적 기록기.
## 격납고에서 F10 전투를 켜고 플레이어도 고정 패턴으로 쏘면서, 일정 프레임마다 버그봇 몸통·발·관절,
## 몬스터 위치·체력을 소수점 4자리로 찍는다. 두 번 돌린 출력을 diff 해서 한 글자라도 다르면 결과가 바뀐 것이다.
##
## 실행: godot --headless --path . --fixed-fps 60 --script res://tools/trace_determinism.gd -- [프레임=1500] [간격=30]

var main: Node
var _frame := 0
var _total := 1500
var _step := 30
var _warm := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_total = int(args[0])
	if args.size() > 1:
		_step = maxi(1, int(args[1]))
	seed(4812)
	AppFlow.start_test(self, "hangar", 2000.0, 1)


func _process(_delta: float) -> bool:
	if main == null:
		main = current_scene
		if main == null or main.get("player") == null or main.get("current_room") == null:
			main = null
			return false
	var room = main.get("current_room")
	_warm += 1
	if _warm == 20:
		_key(true)
	elif _warm == 23:
		_key(false)
	if _warm < 30:
		return false
	_frame += 1
	if _frame % 6 == 0:
		var p: Node2D = main.get("player")
		var k := float(_frame)
		var target := Vector2(p.position.x + sin(k * 0.37) * 850.0, 300.0 + cos(k * 0.21) * 150.0)
		main.call("_spawn_shot", p.position + Vector2(0, -40), target, 1.0, 1.0)
	if _frame % _step == 0:
		_dump(room)
	return _frame >= _total


func _key(pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F10
	key.pressed = pressed
	Input.parse_input_event(key)


func _v(v: Vector2) -> String:
	return "%.4f,%.4f" % [v.x, v.y]


func _dump(room) -> void:
	var line := "F%d" % _frame
	var battle = room.get("bugbot_battle")
	if battle != null:
		for bot in battle.bots:
			if not is_instance_valid(bot):
				continue
			var w = bot.get("_walker")
			line += " | B %s a=%.5f t=%.5f armor=%.2f" % [_v(w.body_pos), w._angle, w._turret, bot.armor]
			for leg in w._legs:
				line += " %s:%s" % [leg["id"], _v(leg["foot"])]
				var pose: Dictionary = leg.get("pose", {})
				for part in ["hip", "knee", "ankle"]:
					if pose.has(part):
						line += "/" + _v(pose[part])
		line += " | kills=%d serial=%d" % [battle.kills, battle._spawn_serial]
	for m in room.monsters:
		if is_instance_valid(m):
			line += " | M %s hp=%s" % [_v(m.position), str(m.hp)]
	print(line)
