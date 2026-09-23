class_name HitProp
extends Sprite2D
## 총에 맞으면 딱딱하게 들썩이는 배경 프랍 + 파츠 파괴.
## 축은 몸 중앙이 아니라 **바닥 접지 끝점**: 총이 날아온 반대편 바닥 모서리를 축으로
## 맞은 쪽이 살짝 들리고, 중력으로 떨어져 바닥에 '탁' 하고 닿는다(작은 튕김 후 정지).
## 반대편 모서리는 접지 마찰로 붙어 있고, 매 발마다 아주 조금씩 탄 방향으로 밀린다.
##
## 파츠: 텍스처를 CELL px 격자 조각으로 나눠 셀마다 내구도를 둔다. 탄착점 주변 셀에 피해가 누적돼
## 부서지면 마스크에서 사라지고 그 조각(ChunkDebris, 노멀맵 포함)이 날아가 바닥에 떨어진다.
## 붉은 피격 플래시(탄착점 주변). 탄흔·열 잔광은 BulletMark 가 프랍의 자식으로 붙어 따라간다.

const ANG_IMPULSE := 1.15         # 한 발당 각속도 (rad/s)
const ANG_GRAVITY := 22.0         # 들린 쪽을 끌어내리는 각가속도 (rad/s^2) — 클수록 딱딱
const MAX_ANGLE := 0.085          # 최대 기울기 (rad)
const RESTITUTION := 0.22         # 바닥에 닿을 때 튕김
const SLIDE_PER_HIT := 1.6        # 한 발당 밀리는 거리 (px)
const SLIDE_TIME := 0.08          # 밀림이 적용되는 시간

const CELL := 26.0                # 파츠 셀 크기 (텍스처 px)
const DAMAGE_RADIUS := 44.0       # 탄착점에서 이 거리 안의 셀이 피해를 받는다
const DAMAGE_PER_HIT := 0.78      # 중심 셀 피해 (1.0 이면 부서짐) → 같은 곳 2발이면 조각이 떨어진다
const MIN_COVERAGE := 0.22        # 셀의 불투명 비율이 이보다 작으면 조각으로 치지 않는다
const MAX_CHUNKS_PER_HIT := 4

var rect := Rect2()               # 월드 좌표 히트 박스 (밀림 반영)
var _w := 0.0
var _h := 0.0
var _base := Vector2.ZERO         # 바닥 중심 (밀림 반영)
var _angle := 0.0
var _ang_v := 0.0
var _pivot_side := 1              # +1: 오른쪽 바닥 모서리가 축 (왼쪽이 들림), -1: 반대
var _slide_left := 0.0
var _slide_dir := 0.0
var _flash := 0.0                 # 피격 플래시 (1 → 0)
var _mat: ShaderMaterial
var _heat: HeatSurface

var _cols := 1
var _rows := 1
var _damage := PackedFloat32Array()
var _coverage := PackedFloat32Array()
var _mask_img: Image
var _mask_tex: ImageTexture
var _broken := 0

const FLASH_TIME := 0.11
const FLASH_RADIUS := 70.0        # 탄착점 주변 플래시 반경 (px)


func setup(tex: Texture2D, top_left: Vector2) -> void:
	texture = tex
	centered = false
	_mat = Lighting.shader_material("prop_surface")
	material = _mat
	_heat = HeatSurface.new(_mat)
	_w = float(tex.get_width())
	_h = float(tex.get_height())
	offset = Vector2(-_w * 0.5, -_h)          # 원점 = 바닥 중심
	_base = top_left + Vector2(_w * 0.5, _h)
	position = _base
	_update_rect()
	_build_cells()


func _update_rect() -> void:
	rect = Rect2(_base - Vector2(_w * 0.5, _h), Vector2(_w, _h))


## 파츠 격자 준비: 셀별 불투명 비율(coverage) 계산, 마스크 텍스처 생성
func _build_cells() -> void:
	_cols = int(ceil(_w / CELL))
	_rows = int(ceil(_h / CELL))
	_damage.resize(_cols * _rows)
	_damage.fill(0.0)
	_coverage.resize(_cols * _rows)
	_coverage.fill(1.0)
	var img := _diffuse_image()
	if img:
		for cy in range(_rows):
			for cx in range(_cols):
				var x0 := int(cx * CELL)
				var y0 := int(cy * CELL)
				var x1 := mini(int((cx + 1) * CELL), int(_w))
				var y1 := mini(int((cy + 1) * CELL), int(_h))
				var solid := 0
				var total := 0
				for y in range(y0, y1, 2):
					for x in range(x0, x1, 2):
						total += 1
						if img.get_pixel(x, y).a > 0.5:
							solid += 1
				_coverage[cy * _cols + cx] = float(solid) / maxf(float(total), 1.0)
	_mask_img = Image.create(_cols, _rows, false, Image.FORMAT_L8)
	_mask_img.fill(Color.WHITE)
	_mask_tex = ImageTexture.create_from_image(_mask_img)
	_mat.set_shader_parameter("mask", _mask_tex)
	_mat.set_shader_parameter("grid", Vector2(_cols, _rows))


func _diffuse_image() -> Image:
	var t := texture
	if t is CanvasTexture:
		t = (t as CanvasTexture).diffuse_texture
	if t is AtlasTexture:
		t = (t as AtlasTexture).atlas
	return t.get_image() if t else null


## 이 월드 점에 아직 실제 조각(불투명·온전)이 있나 — 구멍이면 뒤의 벽이 맞는다
func is_solid_at(point: Vector2) -> bool:
	if not rect.has_point(point):
		return false
	var local := point - rect.position
	var cx := int(local.x / CELL)
	var cy := int(local.y / CELL)
	if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
		return false
	var idx := cy * _cols + cx
	if _damage[idx] >= 1.0:
		return false
	if _coverage[idx] < 0.05:
		return false
	return true


## dir: 탄 진행 방향 (+1 = 왼쪽→오른쪽으로 맞음). hit_y: 월드 Y (높이 맞을수록 더 들림)
## hit_point: 월드 탄착점 — 이 주변만 플래시·열·파츠 피해
## power: 위력 배율(1.0 플레이어 소총 · 2.0 센트리건) — 들썩임·밀림·조각 수와 비거리가 비례한다
func hit(dir: float, hit_y: float, hit_point: Vector2 = Vector2.INF, power := 1.0) -> void:
	var d := 1 if dir >= 0.0 else -1
	# 거의 서 있으면 축을 새로 잡는다: 총이 날아온 반대편 바닥 모서리
	if absf(_angle) < 0.004:
		_pivot_side = d
	var lever := clampf((rect.end.y - hit_y) / _h, 0.25, 1.0)
	# 축이 오른쪽(+1)이면 양의 회전이 왼쪽을 들어올린다
	_ang_v += ANG_IMPULSE * lever * float(_pivot_side) * power
	_slide_left = SLIDE_PER_HIT * power
	_slide_dir = float(d)
	_flash = 1.0
	_mat.set_shader_parameter("flash", 1.0)
	_mat.set_shader_parameter("radius_px", FLASH_RADIUS)
	if hit_point.is_finite():
		var uv := ((hit_point - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE)
		_mat.set_shader_parameter("hit_uv", uv)
		# 열 잔광은 BulletMark(모든 면 공용 탄흔)가 맡는다 — 셰이더 heat_hits 를 함께 켜면 붉은 원이 겹친다
		_damage_cells(hit_point - rect.position, Vector2(dir, 0.0), power)


## 탄착점(텍스처 로컬 px) 주변 셀에 피해 누적, 부서진 셀은 조각으로 날린다
func _damage_cells(local: Vector2, shot_dir: Vector2, power := 1.0) -> void:
	var broke: Array = []
	for cy in range(_rows):
		for cx in range(_cols):
			var idx := cy * _cols + cx
			if _damage[idx] >= 1.0 or _coverage[idx] < MIN_COVERAGE:
				continue
			var center := Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL)
			var dist := center.distance_to(local)
			if dist > DAMAGE_RADIUS:
				continue
			var fall := 1.0 - smoothstep(0.0, DAMAGE_RADIUS, dist)
			_damage[idx] += DAMAGE_PER_HIT * (0.35 + 0.65 * fall) * power
			if _damage[idx] >= 1.0:
				broke.append(Vector2i(cx, cy))
	if broke.is_empty():
		return
	# 가까운 것부터, 한 발에 너무 많이 떨어지지 않게
	broke.sort_custom(func(a, b):
		return Vector2((a.x + 0.5) * CELL, (a.y + 0.5) * CELL).distance_to(local) < Vector2((b.x + 0.5) * CELL, (b.y + 0.5) * CELL).distance_to(local))
	var n := 0
	for c in broke:
		if n >= int(MAX_CHUNKS_PER_HIT * power):
			_damage[c.y * _cols + c.x] = 0.92      # 거의 부서진 채 다음 발에 떨어진다
			continue
		_break_cell(c.x, c.y, shot_dir, local, power)
		n += 1
	_mask_tex.update(_mask_img)


func _break_cell(cx: int, cy: int, shot_dir: Vector2, local_hit: Vector2, power := 1.0) -> void:
	_mask_img.set_pixel(cx, cy, Color.BLACK)
	_broken += 1
	var region := Rect2(cx * CELL, cy * CELL, minf(CELL, _w - cx * CELL), minf(CELL, _h - cy * CELL))
	var center_local := region.get_center()
	var world := to_global(offset + center_local)
	var away := (center_local - local_hit)
	away = away.normalized() if away.length() > 1.0 else Vector2(0, -1)
	var vel := (shot_dir.normalized() * randf_range(140.0, 380.0) + away * randf_range(60.0, 200.0) + Vector2(0, -randf_range(120.0, 320.0))) * power
	var chunk := ChunkDebris.new()
	chunk.setup(texture, region, world, vel, rect.end.y)
	chunk.z_index = 1
	get_parent().add_child(chunk)


func _process(delta: float) -> void:
	# 피격 플래시: 한 프레임 확 밝고 빠르게 빠진다
	if _flash > 0.0:
		_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
		_mat.set_shader_parameter("flash", _flash * _flash)

	# 아주 조금씩 밀림 (접지 마찰 — 짧게 미끄러지고 멈춤)
	if _slide_left > 0.0:
		var step := minf(_slide_left, SLIDE_PER_HIT * delta / SLIDE_TIME)
		_slide_left -= step
		_base.x += step * _slide_dir
		_update_rect()

	var resting := absf(_angle) < 0.0005 and absf(_ang_v) < 0.02
	if resting:
		if rotation != 0.0 or position != _base:
			rotation = 0.0
			position = _base
			_angle = 0.0
			_ang_v = 0.0
		return

	# 들린 쪽을 중력이 끌어내린다 (축 방향으로 부호가 정해짐)
	_ang_v -= ANG_GRAVITY * delta * float(_pivot_side)
	_angle += _ang_v * delta

	# 바닥에 닿음: 축 반대편이 다시 접지 → 작은 튕김
	if _angle * float(_pivot_side) <= 0.0:
		_angle = 0.0
		_ang_v = -_ang_v * RESTITUTION
		if absf(_ang_v) < 0.12:
			_ang_v = 0.0
	if absf(_angle) > MAX_ANGLE:
		_angle = MAX_ANGLE * signf(_angle)
		_ang_v = 0.0

	# 축(바닥 모서리)을 고정한 회전: 바닥 중심의 새 위치를 구한다
	var corner := _base + Vector2(_w * 0.5 * float(_pivot_side), 0.0)
	position = corner + (_base - corner).rotated(_angle)
	rotation = _angle
