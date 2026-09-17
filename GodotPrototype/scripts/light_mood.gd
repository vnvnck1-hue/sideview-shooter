extends RefCounted
## (class_name 없이 preload 로 쓴다 — 새 전역 클래스는 .godot 캐시 재생성 전까지 헤드리스 실행에서 안 보인다)
## 배경 라이팅 무드 프리셋 3종. 방(Room)이 조립된 뒤 `apply(room, layer, index)` 로 얹는다.
## 기존 램프·불·비상등은 그대로 두고, 앰비언트 색 + 방 전체에 깔리는 보조 광원만 바꾼다.
## 확정: 1 그라데이션 필 (DEFAULT). 나머지 프리셋은 참고용으로 남겨 둔다.
##
##  0 컬러 앰비언트   (Dead Cells 식)  : 앰비언트를 채도 있는 청록으로. 배경은 항상 보이고 대비는 난색 광원과의 색상 차로
##  1 그라데이션 필   (Katana Zero 식) : 앰비언트는 조금 낮추고, 방 위에서 내려오는 넓은 채광 라이트가 위→아래 그라데이션과 노멀 방향성을 만든다
##  2 배경 자체 발광  (Eastward 식)     : 앰비언트 중간. 바닥 몰딩 LED 스트립·천장 배관 표시등·창문 외광 등 배경 광원을 늘린다

const PRESETS := [
	{
		"id": "color_ambient", "name": "컬러 앰비언트",
		"desc": "채도 있는 청록 앰비언트. 배경이 항상 보이고 난색 램프·불과 색상 대비",
		"ambient": Color(0.36, 0.52, 0.64),
	},
	{
		"id": "gradient_fill", "name": "그라데이션 필",
		"desc": "위에서 내려오는 넓은 채광 라이트. 위→아래 밝기 그라데이션 + 노멀 방향성",
		"ambient": Color(0.34, 0.37, 0.50),
		"fill": {"spacing": 900.0, "y": -420.0, "radius": 2600.0, "height": 320.0, "energy": 0.48, "color": Color(0.78, 0.86, 1.0)},
		# 바닥 조명: 바닥선에 깔리는 넓고 낮은 라이트 (위 채광이 바닥까지 못 미치는 것을 보완). 살짝 난색.
		"floor": {"spacing": 700.0, "dy": 26.0, "radius": 820.0, "height": 110.0, "energy": 0.28, "color": Color(0.96, 0.90, 0.82), "squash": 0.42},
	},
	{
		"id": "emissive_bg", "name": "배경 자체 발광",
		"desc": "바닥 LED 스트립·천장 표시등·창문 외광 등 배경 광원 추가",
		"ambient": Color(0.40, 0.42, 0.54),
		"strip": {"y": 481.0, "seg": 150.0, "gap": 60.0, "thick": 3.0, "color": Color(0.45, 0.95, 1.0), "radius": 240.0, "energy": 0.5},
		"pilot": {"y": 62.0, "spacing": 300.0, "size": 5.0, "radius": 170.0, "energy": 0.55,
			"colors": [Color(1.0, 0.68, 0.30), Color(0.40, 1.0, 0.55), Color(1.0, 0.68, 0.30), Color(0.55, 0.75, 1.0)]},
		"window": {"color": Color(0.62, 0.82, 1.0), "radius": 520.0, "energy": 0.9, "glass": Color(1.5, 1.7, 2.1, 1.0)},
	},
]
const DEFAULT := 1
static var index := DEFAULT


static func preset() -> Dictionary:
	return PRESETS[wrapi(index, 0, PRESETS.size())]


## room: 방 노드. layer: 보조 광원을 올릴 레이어(Lights). 이전 무드 노드는 지운다.
static func apply(room: Node2D, layer: Node2D, ambient: CanvasModulate, i: int) -> void:
	index = wrapi(i, 0, PRESETS.size())
	var p: Dictionary = PRESETS[index]
	ambient.color = p["ambient"]
	var old := layer.get_node_or_null("Mood")
	if old:
		old.free()
	var mood := Node2D.new()
	mood.name = "Mood"
	layer.add_child(mood)
	var width := float(room.width)
	var room_floor := float(room.get("floor_y")) if room.get("floor_y") != null else float(RoomData.FLOOR_Y)

	if p.has("fill"):
		var f: Dictionary = p["fill"]
		var n := maxi(1, int(ceil(width / float(f["spacing"]))))
		for k in range(n):
			var l := PointLight2D.new()
			l.texture = Lighting.radial_texture()
			l.texture_scale = Lighting.scale_for_radius(f["radius"])
			l.color = f["color"]
			l.energy = f["energy"]
			l.height = f["height"]
			l.position = Vector2(width * (k + 0.5) / n, f["y"])
			mood.add_child(l)

	if p.has("floor"):
		var fl: Dictionary = p["floor"]
		var n := maxi(1, int(ceil(width / float(fl["spacing"]))))
		for k in range(n):
			var l := PointLight2D.new()
			l.texture = Lighting.radial_texture()
			l.texture_scale = Lighting.scale_for_radius(fl["radius"])
			l.scale = Vector2(1.0, fl["squash"])          # 바닥을 따라 옆으로 길게 눌린 빛
			l.color = fl["color"]
			l.energy = fl["energy"]
			l.height = fl["height"]
			l.position = Vector2(width * (k + 0.5) / n, room_floor + float(fl["dy"]))
			mood.add_child(l)

	if p.has("strip"):
		var s: Dictionary = p["strip"]
		var seg: float = s["seg"]
		var gap: float = s["gap"]
		var x := 140.0
		while x + seg < width - 140.0:
			var line := Line2D.new()
			line.width = s["thick"]
			line.default_color = s["color"] * Color(2.6, 2.6, 2.6, 1.0)      # 앰비언트를 이겨 글로우 임계에 닿게
			line.add_point(Vector2(x, s["y"]))
			line.add_point(Vector2(x + seg, s["y"]))
			mood.add_child(line)
			var l := PointLight2D.new()
			l.texture = Lighting.radial_texture()
			l.texture_scale = Lighting.scale_for_radius(s["radius"])
			l.color = s["color"]
			l.energy = s["energy"]
			l.height = 60.0
			l.position = Vector2(x + seg * 0.5, s["y"] - 6.0)
			mood.add_child(l)
			x += seg + gap

	if p.has("pilot"):
		var pl: Dictionary = p["pilot"]
		var cols: Array = pl["colors"]
		var x := 200.0
		var k := 0
		while x < width - 160.0:
			var c: Color = cols[k % cols.size()]
			var dot := Polygon2D.new()
			var hs: float = pl["size"] * 0.5
			dot.polygon = PackedVector2Array([Vector2(-hs, -hs), Vector2(hs, -hs), Vector2(hs, hs), Vector2(-hs, hs)])
			dot.color = c * Color(3.0, 3.0, 3.0, 1.0)
			dot.position = Vector2(x, pl["y"])
			mood.add_child(dot)
			var l := PointLight2D.new()
			l.texture = Lighting.radial_texture()
			l.texture_scale = Lighting.scale_for_radius(pl["radius"])
			l.color = c
			l.energy = pl["energy"]
			l.height = 80.0
			l.position = dot.position
			mood.add_child(l)
			x += pl["spacing"]
			k += 1

	# 창문: 있으면 외광 라이트 + 유리 밝기. 없으면 원래대로
	for w in room.windows:
		if p.has("window"):
			var wd: Dictionary = p["window"]
			w.modulate = wd["glass"]
			var l := PointLight2D.new()
			l.texture = Lighting.radial_texture()
			l.texture_scale = Lighting.scale_for_radius(wd["radius"])
			l.color = wd["color"]
			l.energy = wd["energy"]
			l.height = 120.0
			l.position = w.rect.get_center()
			mood.add_child(l)
		else:
			w.modulate = Color.WHITE
