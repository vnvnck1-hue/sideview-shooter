class_name Npc
extends Node2D
## 월드에 서 있는 생존자. 플레이어가 옆에서 W/↑ 로 말을 건다 (단말기·센트리건과 같은 키).
##
## 이 노드가 맡는 것은 **몸**뿐이다 — 서 있기·숨쉬기·플레이어 쪽으로 돌아보기·말할 때 끄덕이기.
## 무슨 말을 하는지는 npc_data.gd 가, 말풍선은 dialogue_bubble.gd 가, 카메라는 Main 이 맡는다.
##
## 일반 NPC 는 한 장짜리 idle. 연구원 유나는 Native4 프레임 클립 4종을 쓴다.
## 정지 프레임만 있는 NPC 의 살아 있는 느낌은 절차적이다:
##   숨쉬기   발을 고정한 채 세로로 아주 얕게 늘었다 준다 (플레이어 BREATH_SCALE 과 같은 결)
##   돌아보기 플레이어가 사정거리에 들어오면 그쪽으로 몸을 돌린다 (뒤집기, 0.12초 스쿼시)
##   끄덕이기 말풍선 한 줄이 시작될 때 한 번 (talk_beat)

signal talk_requested(npc: Npc)

## 말을 걸 수 있는 거리. 대화 줌(≈1.0)에서 두 사람 스프라이트(각 240px 남짓)가 겹치지 않을 만큼 넉넉히 둔다 —
## 좁으면 플레이어가 상대 위에 올라선 채로 대화가 시작된다.
const INTERACT_RANGE := 340.0
const CELL := 320.0                   # 스프라이트 셀 (80 아트 px × 4)
const FOOT_PAD := 4.0                 # 셀 바닥과 발바닥 사이 여백 (아트 1px × 4)
const BREATH_PERIOD := 3.4
const BREATH_SCALE := Vector2(0.010, 0.024)
const TURN_TIME := 0.12
const NOD_TIME := 0.26
const NOD_PX := 7.0
## 말을 걸 수 있을 때 머리 위에 뜨는 작은 표식
const MARK_BOB := 6.0
const MARK_SIZE := 14.0
const ANIM_CLIPS := {"idle_breathe": 4, "idle_notes": 4, "idle_listen": 4, "walk": 8}
const ANIM_FPS := {"idle_breathe": 3.0, "idle_notes": 3.0, "idle_listen": 3.0, "walk": 8.0}

var npc_id := ""
var cast: Dictionary = {}
var facing := -1                      # 스프라이트 원본이 오른쪽을 본다 (+1 = 오른쪽)
var talking := false
var in_range := false

var _pivot: Node2D                    # 발을 축으로 한 숨쉬기·뒤집기 스케일
var _sprite: Node2D
var _anim_sprite: AnimatedSprite2D
var _idle_timer := 8.0
var _mark: Node2D
var _breath := 0.0
var _nod := 0.0
var _turn := 0.0                      # 방금 돌아본 직후의 스쿼시 잔여
var _base_scale := Vector2.ONE


func setup(id: String, center_x: float, floor_line: float, face_dir := -1) -> void:
	npc_id = id
	cast = NpcData.get_cast(id)
	name = "Npc_" + id
	facing = 1 if face_dir >= 0 else -1
	position = Vector2(round(center_x), floor_line + 2.0)


func _ready() -> void:
	_pivot = Node2D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	# 바닥에 닿는 짧고 단단한 접촉 그림자 (프랍·단말기와 같은 규칙)
	var shadow := ColorRect.new()
	shadow.name = "ContactShadow"
	shadow.color = Color(0.0, 0.0, 0.0, 0.34)
	shadow.size = Vector2(112.0, 10.0)
	shadow.position = Vector2(-56.0, -6.0)
	shadow.z_index = -1
	add_child(shadow)

	if cast.has("anim"):
		_anim_sprite = _build_animated_sprite(str(cast["anim"]))
		_sprite = _anim_sprite
	else:
		var still := Sprite2D.new()
		still.centered = false
		still.texture = Lighting.textured(str(cast.get("tex", "")))
		_sprite = still
	_sprite.name = "Body"
	_sprite.position = Vector2(-CELL * 0.5, -(CELL - FOOT_PAD))
	_sprite.material = Lighting.character_material()
	_pivot.add_child(_sprite)

	_mark = _build_mark()
	add_child(_mark)

	_breath = randf() * BREATH_PERIOD          # 여럿이 같은 숨을 쉬면 인형처럼 보인다
	_idle_timer = randf_range(6.0, 10.0)
	_apply_transform()


func _build_animated_sprite(animation_id: String) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	var base := "res://assets/character/npc/%s/animations/" % animation_id
	for clip in ANIM_CLIPS:
		frames.add_animation(clip)
		frames.set_animation_speed(clip, ANIM_FPS[clip])
		frames.set_animation_loop(clip, clip != "idle_notes")
		for index in range(1, ANIM_CLIPS[clip] + 1):
			var path := "%s%s/%s_%02d.png" % [base, clip, clip, index]
			frames.add_frame(clip, Lighting.textured(path))
	var animated := AnimatedSprite2D.new()
	animated.centered = false
	animated.sprite_frames = frames
	animated.play("idle_breathe")
	animated.animation_finished.connect(_on_animation_finished)
	return animated


func _on_animation_finished() -> void:
	if _anim_sprite != null and not talking and _anim_sprite.animation == "idle_notes":
		_anim_sprite.play("idle_breathe")


## 이동 AI 가 연결되면 walk 를 호출하고 멈출 때 idle_breathe 로 되돌린다.
func play_animation_clip(clip: String) -> void:
	if _anim_sprite != null and ANIM_CLIPS.has(clip):
		_anim_sprite.play(clip)


## 말 걸 수 있음 표식 — 강조색 작은 삼각형. 글자를 쓰지 않는다(먼 거리에서 읽히지 않으므로).
func _build_mark() -> Node2D:
	var n := Node2D.new()
	n.name = "TalkMark"
	n.visible = false
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([
		Vector2(-MARK_SIZE, -MARK_SIZE), Vector2(MARK_SIZE, -MARK_SIZE), Vector2(0.0, MARK_SIZE * 0.6),
	])
	tri.color = cast.get("accent", Color(1, 1, 1))
	n.add_child(tri)
	n.position = Vector2(0.0, -head_height() - 52.0)
	return n


func head_height() -> float:
	return float(cast.get("head", 250.0))


## 말풍선 꼬리가 가리키는 점 (머리 꼭대기, 월드 좌표)
func head_point() -> Vector2:
	return global_position + Vector2(0.0, -head_height())


## 카메라가 잡을 점 — 머리가 아니라 가슴 높이. 얼굴이 화면 가운데에 오면 발이 잘린다.
func focus_point() -> Vector2:
	return global_position + Vector2(0.0, -head_height() * 0.62)


func can_interact(px: float) -> bool:
	return absf(px - position.x) <= INTERACT_RANGE


func prompt_text() -> String:
	return "▲  W / ↑  —  %s에게 말 걸기" % str(cast.get("short", "생존자"))


## 옆에 섰을 때 머리 위 표식을 켠다 (Main 이 매 프레임 알려 준다)
func set_in_range(v: bool) -> void:
	if in_range == v:
		return
	in_range = v
	_mark.visible = v and not talking


## W/↑ — Main 에 대화를 요청한다 (카메라·말풍선은 Main 이 맡는다)
func activate() -> void:
	talk_requested.emit(self)


func set_talking(v: bool) -> void:
	talking = v
	_mark.visible = in_range and not v
	if _anim_sprite != null:
		_anim_sprite.play("idle_listen" if v else "idle_breathe")


## 플레이어 쪽으로 돌아본다. 방향이 바뀌면 짧게 눌렸다 편다 — "돌아섰다" 가 읽히게.
func look_at_x(px: float) -> void:
	var want := 1 if px > position.x else -1
	if want == facing:
		return
	facing = want
	_turn = TURN_TIME


## 말풍선 한 줄이 시작될 때 한 번 끄덕인다
func talk_beat() -> void:
	_nod = NOD_TIME


func _process(delta: float) -> void:
	_breath += delta
	if _anim_sprite != null and not talking:
		_idle_timer -= delta
		if _idle_timer <= 0.0 and _anim_sprite.animation == "idle_breathe":
			_anim_sprite.play("idle_notes")
			_idle_timer = randf_range(7.0, 12.0)
	_nod = maxf(_nod - delta, 0.0)
	_turn = maxf(_turn - delta, 0.0)
	_apply_transform()
	if _mark.visible:
		_mark.position.y = -head_height() - 52.0 + sin(_breath * 3.4) * MARK_BOB
		_mark.rotation = sin(_breath * 2.1) * 0.05


func _apply_transform() -> void:
	# 숨쉬기: 발을 고정한 채 세로로 늘었다 준다. 말하는 동안은 조금 더 크게 쉰다.
	var amp := 1.35 if talking else 1.0
	var b := sin(_breath * TAU / BREATH_PERIOD)
	var s := Vector2.ONE if _anim_sprite != null else Vector2(1.0 - BREATH_SCALE.x * b * amp, 1.0 + BREATH_SCALE.y * b * amp)
	# 돌아선 직후의 스쿼시 — 반쯤 지나며 가로로 눌렸다 돌아온다
	if _turn > 0.0:
		var k := _turn / TURN_TIME
		var squash := sin(k * PI) * 0.16
		s.x *= 1.0 - squash
		s.y *= 1.0 + squash * 0.6
	_pivot.scale = Vector2(s.x * float(facing), s.y)
	# 끄덕임: 몸 전체가 살짝 내려왔다 올라간다 (머리만 따로 움직일 프레임이 없다)
	var nod := 0.0
	if _nod > 0.0:
		nod = sin((1.0 - _nod / NOD_TIME) * PI) * NOD_PX
	_pivot.position.y = nod
