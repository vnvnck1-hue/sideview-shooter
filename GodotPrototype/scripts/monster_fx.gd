class_name MonsterFx
extends RefCounted
## 독성 종양 크롤러 전용 이펙트 아틀라스.
## 4x4 / 셀 64px: 육편, 체액 방울, 착탄 자국, 침·점액 순서다.

const ATLAS: Texture2D = preload("res://assets/effects/monster_fx_atlas.png")
const CELL := 64.0
const VARIANTS := 4

const ROW_FLESH := 0
const ROW_FLUID := 1
const ROW_SPLAT := 2
const ROW_SALIVA := 3


static func region(row: int, variant: int) -> Rect2:
	return Rect2(float(posmod(variant, VARIANTS)) * CELL, float(clampi(row, 0, 3)) * CELL, CELL, CELL)


static var _textures := {}      # 셀 → AtlasTexture (16개뿐 — 한 번 만들어 공유한다. 예전엔 살점 파편마다 새로 만들었다)


static func texture(row: int, variant: int) -> AtlasTexture:
	var r := region(row, variant)
	var atlas: AtlasTexture = _textures.get(r)
	if atlas == null:
		atlas = AtlasTexture.new()
		atlas.atlas = ATLAS
		atlas.region = r
		_textures[r] = atlas
	return atlas


static func draw(canvas: CanvasItem, row: int, variant: int, rect: Rect2, modulate := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(ATLAS, rect, region(row, variant), modulate)
