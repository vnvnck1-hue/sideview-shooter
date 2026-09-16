class_name HitProp
extends Sprite2D
## 총에 맞으면 딱딱하게 들썩이는 배경 프랍.
## 축은 몸 중앙이 아니라 **바닥 접지 끝점**: 총이 날아온 반대편 바닥 모서리를 축으로
## 맞은 쪽이 살짝 들리고, 중력으로 떨어져 바닥에 '탁' 하고 닿는다(작은 튕김 후 정지).
## 반대편 모서리는 접지 마찰로 붙어 있고, 매 발마다 아주 조금씩 탄 방향으로 밀린다.

const ANG_IMPULSE := 1.15         # 한 발당 각속도 (rad/s)
const ANG_GRAVITY := 22.0         # 들린 쪽을 끌어내리는 각가속도 (rad/s^2) — 클수록 딱딱
const MAX_ANGLE := 0.085          # 최대 기울기 (rad)
const RESTITUTION := 0.22         # 바닥에 닿을 때 튕김
const SLIDE_PER_HIT := 1.6        # 한 발당 밀리는 거리 (px)
const SLIDE_TIME := 0.08          # 밀림이 적용되는 시간

var rect := Rect2()               # 월드 좌표 히트 박스 (밀림 반영)
var _w := 0.0
var _h := 0.0
var _base := Vector2.ZERO         # 바닥 중심 (밀림 반영)
var _angle := 0.0
var _ang_v := 0.0
var _pivot_side := 1              # +1: 오른쪽 바닥 모서리가 축 (왼쪽이 들림), -1: 반대
var _slide_left := 0.0
var _slide_dir := 0.0
var _shadow: Control
var _flash := 0.0                 # 피격 플래시 (1 → 0)
var _flash_mat: ShaderMaterial

const FLASH_TIME := 0.11
const FLASH_RADIUS := 70.0        # 탄착점 주변 플래시 반경 (px)


func setup(tex: Texture2D, top_left: Vector2, shadow: Control = null) -> void:
	texture = tex
	centered = false
	_flash_mat = Lighting.shader_material("hit_flash")
	material = _flash_mat
	_w = float(tex.get_width())
	_h = float(tex.get_height())
	offset = Vector2(-_w * 0.5, -_h)          # 원점 = 바닥 중심
	_base = top_left + Vector2(_w * 0.5, _h)
	position = _base
	_shadow = shadow
	_update_rect()


func _update_rect() -> void:
	rect = Rect2(_base - Vector2(_w * 0.5, _h), Vector2(_w, _h))


## dir: 탄 진행 방향 (+1 = 왼쪽→오른쪽으로 맞음). hit_y: 월드 Y (높이 맞을수록 더 들림)
## hit_point: 월드 탄착점 — 이 주변만 플래시
func hit(dir: float, hit_y: float, hit_point: Vector2 = Vector2.INF) -> void:
	var d := 1 if dir >= 0.0 else -1
	# 거의 서 있으면 축을 새로 잡는다: 총이 날아온 반대편 바닥 모서리
	if absf(_angle) < 0.004:
		_pivot_side = d
	var lever := clampf((rect.end.y - hit_y) / _h, 0.25, 1.0)
	# 축이 오른쪽(+1)이면 양의 회전이 왼쪽을 들어올린다
	_ang_v += ANG_IMPULSE * lever * float(_pivot_side)
	_slide_left = SLIDE_PER_HIT
	_slide_dir = float(d)
	_flash = 1.0
	_flash_mat.set_shader_parameter("flash", 1.0)
	if hit_point.is_finite():
		var uv := (hit_point - rect.position) / rect.size
		_flash_mat.set_shader_parameter("hit_uv", uv.clamp(Vector2.ZERO, Vector2.ONE))
	_flash_mat.set_shader_parameter("radius_px", FLASH_RADIUS)


func _process(delta: float) -> void:
	# 피격 플래시: 한 프레임 확 밝고 빠르게 빠진다
	if _flash > 0.0:
		_flash = maxf(_flash - delta / FLASH_TIME, 0.0)
		_flash_mat.set_shader_parameter("flash", _flash * _flash)

	# 아주 조금씩 밀림 (접지 마찰 — 짧게 미끄러지고 멈춤)
	if _slide_left > 0.0:
		var step := minf(_slide_left, SLIDE_PER_HIT * delta / SLIDE_TIME)
		_slide_left -= step
		_base.x += step * _slide_dir
		_update_rect()
		if _shadow:
			_shadow.position.x += step * _slide_dir

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
