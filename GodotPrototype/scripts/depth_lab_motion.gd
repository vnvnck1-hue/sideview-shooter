class_name DepthLabMotion
extends Node
## 공간감 테스트 씬의 발판 물리 — 본편 플레이어(Player)에 **여러 층 높이**를 얹는다.
##
## Player 는 점프·사다리를 "발(position)은 바닥에 둔 채 그림만 _air 만큼 들어 올린다" 로 처리한다.
## 여기서는 그 바닥을 층마다 바꾼다: g = 지금 발이 딛고 있는 높이(바닥선 위 px), position.y = floor_y − g.
## 공중에서는 발 높이 합(g + _air)을 유지한 채 **발밑 지지면으로 g 를 옮겨 준다(rebase)** —
## 그러면 Player 자신의 착지 판정(_air ≤ 0)이 어느 층에서든 그대로 동작한다.
##
## 두 노드로 나뉜다 — Player(우선순위 0)의 앞(pre, −5)에서 이전 위치를 적고, 뒤(post, 5)에서 발을 맞춘다.
## 카메라(10)는 그 뒤에 돈다.

const D := preload("res://scripts/depth_lab_data.gd")

var player: Player
var floor_y := 0.0
var solid: RoomSolid
var g := 0.0                        # 발이 딛고 있는 높이
var ladders: Array = []             # [x, h0, h1]
var _prev_x := 0.0
var _drop_ignore := -1              # 내려서는 중인 발판 번호 (그 아래로 내려갈 때까지 무시)
var blocked := false
var crawling := false


class _Phase extends Node:
	var owner_motion: DepthLabMotion
	var post := false

	func _process(_delta: float) -> void:
		if post:
			owner_motion._post()
		else:
			owner_motion._pre()


func setup(p: Player, floor_line: float, room_solid: RoomSolid) -> void:
	player = p
	floor_y = floor_line
	solid = room_solid
	ladders = D.LADDERS
	var pre := _Phase.new()
	pre.name = "MotionPre"
	pre.owner_motion = self
	pre.process_priority = -5
	add_child(pre)
	var post := _Phase.new()
	post.name = "MotionPost"
	post.owner_motion = self
	post.post = true
	post.process_priority = 5
	add_child(post)
	snap_to_ground()


## 순간 이동 뒤: 그 자리 가장 높은 지지면에 선다
func snap_to_ground(from_h := 99999.0) -> void:
	g = support_at(player.position.x, from_h)
	player.position.y = floor_y + 2.0 - g
	_prev_x = player.position.x


func total() -> float:
	return g + player.air_height()


## x 에서 발 높이 feet 이하(+tol)인 가장 높은 지지면 (바닥 0 포함)
func support_at(x: float, feet: float, tol := 0.5) -> float:
	var best := 0.0
	for i in range(D.PLATFORMS.size()):
		if i == _drop_ignore:
			continue
		var p: Dictionary = D.PLATFORMS[i]
		if x < float(p["x0"]) - D.HALF_W * 0.5 or x > float(p["x1"]) + D.HALF_W * 0.5:
			continue
		var h := float(p["h"])
		if h <= feet + tol and h > best:
			best = h
	return best


## 지금 서 있는 발판 번호 (-1 = 바닥)
func platform_under() -> int:
	if player.is_airborne():
		return -1
	for i in range(D.PLATFORMS.size()):
		var p: Dictionary = D.PLATFORMS[i]
		if absf(float(p["h"]) - g) < 1.0 and player.position.x >= float(p["x0"]) - D.HALF_W * 0.5 and player.position.x <= float(p["x1"]) + D.HALF_W * 0.5:
			return i
	return -1


func can_drop() -> bool:
	var i := platform_under()
	return i >= 0 and D.PLATFORMS[i]["kind"] == "oneway"


## S + W: 발판 아래로 내려선다
func drop() -> void:
	var i := platform_under()
	if i < 0:
		return
	_drop_ignore = i
	player._start_fall()


## 머리 위 여유 (방 천장 · 기어가는 구간)
func headroom() -> float:
	var x := player.position.x
	var top := floor_y - solid.open_top_at(x)
	for c in D.CRAWLS:
		if x > float(c[0]) - D.HALF_W and x < float(c[1]) + D.HALF_W:
			top = minf(top, float(c[2]))
	return top - total()


func can_jump() -> bool:
	return headroom() >= D.STAND_H + 150.0 and player.can_jump()


## 잡을 수 있는 사다리 — 축 가까이 있고 발 높이가 사다리 범위 안
func ladder_near() -> Array:
	var x := player.position.x
	var t := total()
	for l in ladders:
		if absf(float(l[0]) - x) <= Ladder.GRAB_RANGE and t >= float(l[1]) - 12.0 and t <= float(l[2]) + 12.0:
			return l
	return []


func start_climb(l: Array) -> void:
	var t := total()
	g = float(l[1])
	player._air = clampf(t - g, 0.0, float(l[2]) - g)
	player.start_climb(float(l[0]), float(l[2]) - g)
	player.position.y = floor_y + 2.0 - g


func _pre() -> void:
	if player == null:
		return
	_prev_x = player.position.x
	# 사다리 꼭대기 발판에서 S — 사다리를 잡고 내려간다
	if Input.is_action_just_pressed("crouch") and not player.is_airborne() and player.input_enabled:
		for l in ladders:
			if absf(float(l[0]) - player.position.x) <= Ladder.GRAB_RANGE and absf(g - float(l[2])) < 2.0 and float(l[2]) > float(l[1]):
				start_climb(l)
				break
	# 기어가는 구간 — 서 있는 채로는 들어가지 못하고, 안에서는 웅크림이 강제된다
	crawling = false
	for c in D.CRAWLS:
		if player.position.x > float(c[0]) - D.HALF_W and player.position.x < float(c[1]) + D.HALF_W and total() < float(c[2]):
			crawling = true
	player.force_crouch = crawling


func _post() -> void:
	if player == null:
		return
	blocked = false
	if player.is_climbing():
		player.position.y = floor_y + 2.0 - g
		return
	var x := player.position.x
	var t := total()
	# 옆이 막힌 덩어리(solid) · 서서 들어가는 기어가기 구간
	for p in D.PLATFORMS:
		if p["kind"] != "solid":
			continue
		var top := float(p["h"])
		if t >= top - D.STEP:
			continue
		var a := float(p["x0"]) - D.HALF_W
		var b := float(p["x1"]) + D.HALF_W
		var was_in := _prev_x > a and _prev_x < b
		if x > a and x < b and not was_in:
			x = a if _prev_x <= a else b
			blocked = true
	if not crawling and not player.is_crouching() and not player.is_rolling():
		for c in D.CRAWLS:
			var a := float(c[0]) - D.HALF_W
			var b := float(c[1]) + D.HALF_W
			if t < float(c[2]) and x > a and x < b and not (_prev_x > a and _prev_x < b):
				x = a if _prev_x <= a else b
				blocked = true
	if blocked:
		player.position.x = x
		player.velocity_x = 0.0
	# 내려서던 발판을 다 지났으면 다시 받는다
	if _drop_ignore >= 0 and t < float(D.PLATFORMS[_drop_ignore]["h"]) - 4.0:
		_drop_ignore = -1
	if player.is_airborne():
		var sup := support_at(x, t)
		if absf(sup - g) > 0.01:
			player._air = t - sup
			g = sup
	else:
		var sup := support_at(x, g + D.STEP)
		if sup > g:
			g = sup                                   # 턱 오르기
		elif sup < g - 1.0 and not player.is_rolling():
			var h := g
			g = sup
			player._start_fall()                      # 발판 끝에서 떨어진다
			player._air = h - sup
	player.position.y = floor_y + 2.0 - g
