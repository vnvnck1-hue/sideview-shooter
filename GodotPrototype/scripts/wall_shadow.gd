class_name WallShadow
extends Node2D
## 벽 바깥 어둠 — 방 실루엣 밖을 완전히 덮고, 실루엣 안쪽으로 짧은 그라데이션을 넣어
## 벽 가장자리가 어둠으로 이어지게 하는 층. 모든 층(타일 0 ~ 근경 7) 위에 얹는다.
##
## 이게 없으면 비상등 회전 광선·램프 빛·근경 실루엣이 방 실루엣 밖 검은 여백 위로 그대로 새어나가
## "벽 너머에 공간이 있다" 처럼 보인다. 벽을 RoomSolid 로 막은 것과 짝이 되는 시각 처리다.
##
## 알파는 방 모양에서 구워 만든다 (열 프로필이 방마다 다르고 계단형·성당형도 있으므로 셰이더보다 단순하다):
##   실루엣 밖        = 1 (완전한 검정)
##   실루엣 안 d px   = (1 - d/FADE)^EXP   — 네 방향 중 가장 어두운 값. 띠 두께보다 조금 긴 거리에서 0 이 된다.
## 16px 텍셀 + 선형 필터라 계단이 보이지 않고, 방 하나당 20~30k 텍셀이라 조립 비용도 눈에 띄지 않는다.

const TEXEL := 16.0              # 알파 텍스처 한 칸의 월드 px (방 격자 128 의 약수 — 실루엣 경계와 딱 맞는다)
const PAD := 192.0               # 실루엣 바깥으로 굽는 여유 (전부 1). TEXEL 의 배수
const VOID := 6000.0             # 그 바깥을 메우는 검은 사각형의 크기 (카메라가 방 밖을 보여주는 폭보다 충분히 크게)

## 그라데이션이 0 이 되는 안쪽 거리 — 각 띠 두께(벽 56 · 천장 48 · 바닥 78)보다 조금 길게 잡아
## 띠의 바깥 절반이 어두워지고 안쪽 끝에서는 거의 사라지도록 한다.
const FADE_SIDE := 60.0          # 벽 띠 56
const FADE_TOP := 52.0           # 천장 띠 48
const FADE_BOTTOM := 66.0        # 바닥 띠 78 — 밟는 띠 윗선(바닥선)까지 올라오지 않게 조금 짧게
const EXP := 2.0                 # 감쇠 지수 — 클수록 어둠이 가장자리에 붙는다


func build(solid: RoomSolid, heights: Array) -> void:
	var lay := RoomTiles.layout(heights)
	var origin := Vector2(-PAD, float(lay["ceiling_y"]) - PAD)
	var size := Vector2(float(lay["width"]) + PAD * 2.0, float(lay["bottom_y"]) - float(lay["ceiling_y"]) + PAD * 2.0)

	var sprite := Sprite2D.new()
	sprite.name = "Gradient"
	sprite.centered = false
	sprite.texture = _bake(solid, heights, origin, size)
	sprite.position = origin
	sprite.scale = Vector2(TEXEL, TEXEL)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR    # 16px 텍셀을 부드럽게 편다
	sprite.material = _unlit()
	add_child(sprite)

	# 구운 범위 바깥(카메라가 보여주는 방 밖 여백)은 그냥 검정
	for r in [
		Rect2(origin.x - VOID, origin.y - VOID, size.x + VOID * 2.0, VOID),
		Rect2(origin.x - VOID, origin.y + size.y, size.x + VOID * 2.0, VOID),
		Rect2(origin.x - VOID, origin.y, VOID, size.y),
		Rect2(origin.x + size.x, origin.y, VOID, size.y),
	]:
		var fill := ColorRect.new()
		fill.color = Color.BLACK
		fill.position = r.position
		fill.size = r.size
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.material = _unlit()
		add_child(fill)


## 라이트를 받지 않는 머티리얼 — 이 층은 램프·비상등 빛에 밝아지면 안 된다
static func _unlit() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m


## 방 모양 → 알파 텍스처. 텍셀 행마다 그 높이에서 막힌 열을 훑어 좌우 거리까지 한 번에 구한다.
static func _bake(solid: RoomSolid, heights: Array, origin: Vector2, size: Vector2) -> ImageTexture:
	var w := int(round(size.x / TEXEL))
	var h := int(round(size.y / TEXEL))
	var cols := heights.size()
	var bottom := solid.bottom_y()
	var tops := PackedFloat32Array()             # 열별 실루엣 윗선
	tops.resize(cols)
	for c in range(cols):
		tops[c] = solid.ceiling_top_at(float(c) * RoomSolid.CELL + RoomSolid.CELL * 0.5)

	var data := PackedByteArray()
	data.resize(w * h * 4)
	var run_x0 := PackedFloat32Array()           # 이 행에서 열 c 가 속한 실루엣 덩어리의 좌·우 끝 (월드 x)
	var run_x1 := PackedFloat32Array()
	run_x0.resize(cols)
	run_x1.resize(cols)

	for j in range(h):
		var y := origin.y + (float(j) + 0.5) * TEXEL
		# 이 높이에서 실루엣에 속한 열들의 덩어리 경계
		var c := 0
		while c < cols:
			if y < tops[c] or y >= bottom:
				run_x0[c] = 0.0
				run_x1[c] = -1.0                 # 이 행에서는 방 밖
				c += 1
				continue
			var s := c
			while c < cols and y >= tops[c] and y < bottom:
				c += 1
			var x0 := float(s) * RoomSolid.CELL
			var x1 := float(c) * RoomSolid.CELL
			for k in range(s, c):
				run_x0[k] = x0
				run_x1[k] = x1

		for i in range(w):
			var x := origin.x + (float(i) + 0.5) * TEXEL
			var a := 1.0
			var col := int(floor(x / RoomSolid.CELL))
			if col >= 0 and col < cols and run_x1[col] > run_x0[col]:
				a = maxf(
					maxf(_ramp(x - run_x0[col], FADE_SIDE), _ramp(run_x1[col] - x, FADE_SIDE)),
					maxf(_ramp(y - tops[col], FADE_TOP), _ramp(bottom - y, FADE_BOTTOM)))
			data[(j * w + i) * 4 + 3] = int(round(clampf(a, 0.0, 1.0) * 255.0))

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(img)


static func _ramp(d: float, fade: float) -> float:
	if d >= fade:
		return 0.0
	return pow(1.0 - maxf(d, 0.0) / fade, EXP)
