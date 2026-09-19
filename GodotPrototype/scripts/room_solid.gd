class_name RoomSolid
extends RefCounted
## 방의 "벽" — 열 프로필(RoomTiles)에서 뽑아낸 실제 충돌 기하. 물리 노드 없이 기하로만 판정한다
## (이 게임은 좌우 이동뿐이라 CharacterBody2D 가 필요 없고, 탄·파편·독액만 벽을 넘지 못하면 된다).
##
## 열린 공간(방 안의 공기)은 열마다
##   위   : 천장 타일 상단 + CEILING_BAND   (천장 띠 아랫선)
##   아래 : 바닥선 floor_y
##   좌우 : 막힌 이웃 열과의 경계에서 WALL_BAND 안쪽   (계단형 방의 단차 벽면도 포함)
## 이고, 그 밖은 모두 벽이다. 방 밖(어둠)도 벽으로 친다 — 총알·파편이 어둠으로 넘어가지 않는다.
##
## 쓰는 곳:  Main 의 사격(clip_ray 로 탄착점을 벽면까지 당긴다) · 탄피/파편/불꽃/독액(bounce_walls)

const CELL := RoomTheme.CELL
const CEILING_BAND := RoomTiles.CEILING_BAND
const WALL_BAND := RoomTiles.WALL_BAND

const RAY_STEP := 6.0        # clip_ray 의 전진 간격 (px) — 걸린 뒤 이분 탐색으로 표면을 찾는다
const RAY_REFINE := 7        # 이분 탐색 횟수 (6px → 0.05px)

## 현재 방 (탄피·파편처럼 방을 모르는 자유 물체가 참조한다. WaterPool.active 와 같은 방식)
static var active: RoomSolid

var floor_y := 0.0
var width := 0.0
var _open_top: PackedFloat32Array = PackedFloat32Array()   # 열별 열린 천장 y (천장 띠 아랫선)
var _ceil_top: PackedFloat32Array = PackedFloat32Array()   # 열별 천장 타일 상단 y (실루엣 윗선)
var _cols := 0
var _bottom_y := 0.0


func build(heights: Array, floor_line: float) -> void:
	floor_y = floor_line
	var lay := RoomTiles.layout(heights)
	width = float(lay["width"])
	_bottom_y = float(lay["bottom_y"])
	_cols = heights.size()
	_open_top.resize(_cols)
	_ceil_top.resize(_cols)
	var origin_y: float = lay["origin"].y
	var rows: int = lay["rows"]
	for c in range(_cols):
		var top := origin_y + CELL * (rows - int(heights[c]))
		_ceil_top[c] = top
		_open_top[c] = top + CEILING_BAND


## 실루엣(타일이 찍힌 영역) 윗선 — 그림자 그라데이션이 쓴다
func ceiling_top_at(x: float) -> float:
	return _ceil_top[_col(x)]


func bottom_y() -> float:
	return _bottom_y


## 이 x 열에서 열린 천장 y (천장 띠 아랫선)
func open_top_at(x: float) -> float:
	return _open_top[_col(x)]


## 점이 벽(또는 방 밖)인가
func is_solid(p: Vector2) -> bool:
	if p.y >= floor_y:
		return true
	if p.x < 0.0 or p.x >= width:
		return true
	var c := _col(p.x)
	if p.y < _open_top[c]:
		return true
	# 좌우 벽 띠 — 이 높이에서 막힌 이웃 열과의 경계 안쪽 WALL_BAND
	if _blocked(c - 1, p.y) and p.x - float(c) * CELL < WALL_BAND:
		return true
	if _blocked(c + 1, p.y) and float(c + 1) * CELL - p.x < WALL_BAND:
		return true
	return false


## from → to 선분이 처음 벽에 닿는 점. 벽에 닿지 않으면 to 그대로.
## 총구가 이미 벽 띠 안이면(벽에 바짝 붙어 쏠 때) 벽을 빠져나온 뒤부터 본다.
func clip_ray(from: Vector2, to: Vector2) -> Vector2:
	var seg := to - from
	var dist := seg.length()
	if dist < 1.0:
		return to
	var dir := seg / dist
	var t := 0.0
	while t < dist and is_solid(from + dir * t):
		t += RAY_STEP
	var prev := t
	while t < dist:
		t = minf(t + RAY_STEP, dist)
		if is_solid(from + dir * t):
			var lo := prev
			var hi := t
			for i in range(RAY_REFINE):
				var mid := (lo + hi) * 0.5
				if is_solid(from + dir * mid):
					hi = mid
				else:
					lo = mid
			return from + dir * lo
		prev = t
	return to


## 높이 y 에서 x 가 속한 열린 구간의 좌우 끝 (계단형 방은 같은 높이로 이어진 열들만 한 구간)
func open_span_at(x: float, y: float) -> Vector2:
	var c := _col(x)
	if y < _open_top[c]:
		return Vector2(x, x)                      # 이미 벽 안 — 가로로는 건드리지 않는다
	var lo := c
	while lo > 0 and not _blocked(lo - 1, y):
		lo -= 1
	var hi := c
	while hi < _cols - 1 and not _blocked(hi + 1, y):
		hi += 1
	return Vector2(float(lo) * CELL + WALL_BAND, float(hi + 1) * CELL - WALL_BAND)


## 자유 물체를 방 안에 가둔다. 벽에 닿으면 되밀고 그 축의 속도를 튕긴다. → [위치, 속도]
## (바닥은 각자 floor_y 로 이미 처리하므로 좌우 벽과 천장만 본다)
func confine(pos: Vector2, vel: Vector2, restitution := 0.4) -> Array:
	var span := open_span_at(pos.x, pos.y)
	if pos.x < span.x:
		pos.x = span.x
		if vel.x < 0.0:
			vel.x = -vel.x * restitution
	elif pos.x > span.y:
		pos.x = span.y
		if vel.x > 0.0:
			vel.x = -vel.x * restitution
	var top := open_top_at(pos.x)
	if pos.y < top:
		pos.y = top
		if vel.y < 0.0:
			vel.y = -vel.y * restitution
	return [pos, vel]


## 현재 방 기준 confine. 방이 없으면 그대로 돌려준다.
static func bounce_walls(pos: Vector2, vel: Vector2, restitution := 0.4) -> Array:
	if active == null:
		return [pos, vel]
	return active.confine(pos, vel, restitution)


func _col(x: float) -> int:
	return clampi(int(floor(x / CELL)), 0, maxi(_cols - 1, 0))


## 열 c 가 높이 y 에서 막혀 있는가 (방 밖 열도 막힘)
func _blocked(c: int, y: float) -> bool:
	if c < 0 or c >= _cols:
		return true
	return y < _open_top[c]
