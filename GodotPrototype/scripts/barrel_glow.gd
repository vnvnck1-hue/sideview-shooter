class_name BarrelGlow
extends Node2D
## 총열 과열 발광. `heat` (0..1) 가 오를수록 포신이 뿌리에서 총구 쪽으로 붉게 달아오르고,
## 달아오른 총열이 주변을 은은하게 비춘다. 가산 블렌드라 글로우(임계 0.85)에도 걸린다.
##
## 포신 스프라이트 위에 덧그리는 층이라 부모(_recoil) 안에서 머리 스프라이트 **뒤에 추가하면 안 된다**.
## 좌우 반전(_flip.scale.x = -1)은 같은 로컬 공간이라 그대로 따라간다.

const SLICES := 16                   # 포신 하나를 몇 조각으로 끊어 칠하나 (조각 = 4px 블록 몇 개)
const COLD := Color(0.72, 0.09, 0.02)    # 막 달아오르기 시작한 검붉은 색
const HOT := Color(1.0, 0.46, 0.14)      # 한계까지 달아오른 주황
const ALPHA_MAX := 0.62                  # 가산 블렌드 최대 세기 (금속이 하얗게 날아가지 않게)
const LIGHT_RADIUS := 240.0

var heat := 0.0                      # 0..1 (SentryTurret 이 매 프레임 넣어준다)
var barrels: Array = []              # [{"back": Vector2, "tip": Vector2, "w": float}]

var _light: PointLight2D
var _shown := -1.0


func setup(barrel_specs: Array) -> void:
	barrels = barrel_specs
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light = PointLight2D.new()
	_light.name = "HeatLight"
	_light.texture = Lighting.radial_texture()
	_light.texture_scale = Lighting.scale_for_radius(LIGHT_RADIUS)
	_light.color = Color(1.0, 0.34, 0.14)
	_light.height = Lighting.FLASH_HEIGHT
	_light.energy = 0.0
	_light.enabled = false
	if not barrels.is_empty():
		_light.position = (barrels[0]["tip"] + barrels[-1]["back"]) * 0.5
	add_child(_light)


func _process(_delta: float) -> void:
	if absf(heat - _shown) < 0.004:
		return
	_shown = heat
	var e := maxf(heat - 0.25, 0.0) * 1.4           # 25% 아래에서는 빛나지 않는다
	_light.energy = e
	_light.enabled = e > 0.02
	queue_redraw()


func _draw() -> void:
	if heat <= 0.02:
		return
	var k := clampf(heat, 0.0, 1.0)
	var col := COLD.lerp(HOT, k)
	for b in barrels:
		var back: Vector2 = b["back"]
		var tip: Vector2 = b["tip"]
		var h: float = b["w"]
		var span := tip - back
		var step := span / float(SLICES)
		for i in range(SLICES):
			var t := float(i) / float(SLICES - 1)
			# 총구 쪽이 먼저·더 뜨겁게 달아오른다
			var local_k := clampf(k * (0.3 + 0.9 * t), 0.0, 1.0)
			var a := pow(local_k, 1.7) * ALPHA_MAX
			if a <= 0.01:
				continue
			var p := back + step * float(i)
			var hh := h * (0.78 + 0.22 * t) * 0.5          # 총구 쪽이 살짝 굵다
			draw_rect(Rect2(p.x, p.y - hh, step.x + 1.0, hh * 2.0), Color(col.r, col.g, col.b, a))
