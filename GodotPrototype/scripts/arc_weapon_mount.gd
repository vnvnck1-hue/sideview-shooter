class_name ArcWeaponMount
extends Node2D
## 버그봇 포탑에 얹는 아크위버 원화. 원래 포신 자리(포신 후퇴 포함)를 따라가며 조준 방향으로 돈다.
## 쏘면 포 자체가 뒤로 튀고 눌렸다 펴진다(kick) — 기관포의 빠른 후퇴 대신 한 방의 무게를 보여 준다.
var unit: WalkerUnit
var sprite: Sprite2D
var muzzle: Marker2D
var glow: Sprite2D
const ART_SCALE := 0.34
const KICK_BACK := 36.0              # 발사 순간 포가 뒤로 밀리는 거리 (월드 px, 스프링으로 돌아온다)
var _kick := Vector2.ZERO            # (값, 속도) 임계 감쇠 스프링


func _ready() -> void:
	process_priority = 45
	z_index = 8
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/weapons/arc_weaver.png")
	sprite.centered = false
	sprite.offset = Vector2(-660, -814)
	sprite.scale = Vector2.ONE * ART_SCALE
	sprite.material = Lighting.character_material("lit_surface", 0.5, true)
	add_child(sprite)
	muzzle = Marker2D.new()
	muzzle.position = Vector2(1558 - 660, 440 - 814) * ART_SCALE
	add_child(muzzle)
	sync()


func kick() -> void:
	_kick.y += 58.0


func _process(delta: float) -> void:
	_kick.y += -_kick.x * 900.0 * delta
	_kick.y *= exp(-60.0 * delta)
	_kick.x += _kick.y * delta
	sync()


func sync() -> void:
	if not is_instance_valid(unit._rig):
		return
	unit._rig._barrel.visible = false
	unit._rig._glow.visible = false
	var w := unit._walker
	var pivot: Vector2 = unit._scaler.global_transform * (w.transform * w.turret_local(-w.recoil_distance()))
	var d: Vector2 = unit._scaler.global_transform.basis_xform(w.aim_dir()).normalized()
	global_position = pivot + Vector2(0, -5) - d * KICK_BACK * clampf(_kick.x, 0.0, 1.5)
	rotation = d.angle()
	var squash := 1.0 + 0.12 * clampf(_kick.x, 0.0, 1.5)
	scale = Vector2(0.5 / squash, (0.5 if d.x >= 0 else -0.5) * squash)


func muzzle_world() -> Vector2:
	sync()
	return muzzle.global_position
