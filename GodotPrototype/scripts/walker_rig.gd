class_name WalkerRig
extends Node2D
## 사족보행 기체의 **원화 파츠 리그** (2026-09-22). ProcWalker 가 푼 자세를 스프라이트에 입힌다.
##
## 키프레임을 굽지 않는다. 절차적 보행이 매 프레임 내놓는 고관절·무릎·발 위치를 그대로 받아
## 조각의 위치·회전·자른 길이로 옮긴다 — 걸음이 지형에 맞춰 달라지면 그림도 같이 달라진다.
##
## ## 조각 목록 (원화 컷 계획과 1:1)
##   hull      몸통 본체 (포탑 받침·앞머리까지 한 장)
##   barrel    약실 + 포신 + 총구 (한 장. 요동축에서 부앙으로 회전)
##   다리 ×4 — rod    유압 로드: **민무늬 원통**. 늘이지 않고 region 으로 잘라 쓴다
##             sleeve 유압 슬리브(원화의 초록 장갑판): 고관절에 고정, 로드를 덮는다
##             shin   정강이 + 발: 길이 불변 — 원화에서 잘라 그대로 돌린다 (±15°)
##             hip_cap / knee_cap  관절 원통: 이음매 틈을 가린다
##
## ## 늘어나는 허벅지를 스프라이트로 다루는 법
## 픽셀을 **늘리지 않는다.** 로드를 항상 전체 길이로 두고 `region_rect` 로 필요한 만큼만 잘라 보인다
## (민무늬 원통이라 자른 자리가 보이지 않는다). 슬리브는 고관절에 붙어 그 안쪽을 덮는다.
## sentry_turret.gd 의 신축 받침대(_riser)가 같은 수법이다 — 그쪽은 밀어 넣고 머리로 가린다.
##
## ## 돌아서기 (yaw)
## 좌우를 뒤집지 않는다. ProcWalker.yaw 가 몸이 돌아간 각이고, 리그는 두 가지로 그걸 표현한다.
##   1) 몸통은 **평면 노드**에 담는다. 그 노드의 transform 을 사영의 정확한 2×2 행렬로 맞추면,
##      안쪽 스프라이트를 (a, u) 자리에 놓기만 해도 project() 와 같은 자리에 떨어진다 (기울기·눌림 포함).
##   2) 다리·포신은 끝점이 이미 월드에서 정해져 있으므로 그 두 점으로 회전·길이를 직접 만든다.
## 가로 눌림에는 하한(ProcWalker.SQUASH_MIN)을 둔다 — 정면을 지날 때 그림이 종이처럼 사라지지 않게.
## (나중에 정면 전환 시트를 끼우면 그 하한 구간을 시트가 대체한다)

## 조각 규격의 **기본값**(= 플레이스홀더용). 원화 조각이 있으면 parts.json 의 값으로 덮어쓴다.
##   size   그림 크기(px, 월드 단위와 1:1)
##   anchor 그림 안에서 **관절이 있는 자리**
##   axis   그림이 뻗은 방향 — "down" 은 원화에서 아래로 뻗은 마디(회전할 때 -90° 를 더한다) ·
##          "right" 는 오른쪽으로 뻗은 마디 · "none" 은 회전하지 않는 조각
const PARTS_DEFAULT := {
	"hull": {"size": Vector2(294, 222), "anchor": Vector2(130, 160), "axis": "none"},
	"barrel": {"size": Vector2(240, 68), "anchor": Vector2(62, 34), "axis": "right"},
	"rod": {"size": Vector2(230, 38), "anchor": Vector2(0, 19), "axis": "right"},
	"sleeve": {"size": Vector2(74, 56), "anchor": Vector2(0, 28), "axis": "right"},
	"shin": {"size": Vector2(178, 52), "anchor": Vector2(0, 26), "axis": "right"},
	"hip_cap": {"size": Vector2(52, 52), "anchor": Vector2(26, 26), "axis": "none"},
	"knee_cap": {"size": Vector2(64, 64), "anchor": Vector2(32, 32), "axis": "none"},
}

## 원화 조각은 관절 원통을 **한 장**만 잘라 고관절·무릎에 같이 쓴다 (원화에 실린더가 하나뿐이다)
const CAP_ALIAS := {"hip_cap": "cap", "knee_cap": "cap"}

## 플레이스홀더 색 — 원화 조각이 없을 때만 쓴다. 그레이박스와 같은 색으로 둬서
## F4 로 번갈아 보며 자리맞춤을 확인할 수 있게 한다.
const PLACEHOLDER := {
	"hull": Color(0.573, 0.737, 0.765),
	"barrel": Color(0.30, 0.42, 0.46),
	"rod": Color(0.70, 0.38, 0.60),
	"sleeve": Color(0.902, 0.549, 0.784),
	"shin": Color(0.851, 0.761, 0.369),
	"hip_cap": Color(0.518, 0.518, 0.878),
	"knee_cap": Color(0.518, 0.518, 0.878),
}

## 원화 조각을 찾는 곳. 파일이 있으면 쓰고, 없으면 플레이스홀더를 만든다 (A 단계)
const ART_DIR := "res://assets/quadruped/"

var walker: ProcWalker

var _plane: Node2D            # 몸통이 담기는 평면 (사영 행렬을 그대로 받는다)
var _hull: Sprite2D
var _barrel: Sprite2D
var _legs: Array = []         # [{rod, sleeve, shin, hip_cap, knee_cap, holder}]
var _tex: Dictionary = {}
var _turn_sheet: Texture2D = null     # 정면 전환 시트 (아직 없다 — _sync_body 의 "정면 전환 시트 자리" 참고)


var _parts: Dictionary = {}       # 실제로 쓰는 규격 (원화가 있으면 parts.json 값)


func _ready() -> void:
	if walker == null:
		walker = get_parent() as ProcWalker
	_load_specs()
	for k in _parts.keys():
		_tex[k] = _load_or_placeholder(k)

	# 몸통 평면 — z_index 는 다리와 섞이므로 각 조각에서 따로 준다
	_plane = Node2D.new()
	_plane.name = "BodyPlane"
	add_child(_plane)
	_hull = _make("hull")
	_plane.add_child(_hull)

	_barrel = _make("barrel")
	_barrel.z_index = 6
	add_child(_barrel)

	for leg in walker.legs():
		var holder := Node2D.new()
		holder.name = "Leg_" + str(leg["name"])
		add_child(holder)
		var d := {
			"leg": leg, "holder": holder,
			"rod": _make("rod"), "sleeve": _make("sleeve"), "shin": _make("shin"),
			"hip_cap": _make("hip_cap"), "knee_cap": _make("knee_cap"),
		}
		# 한 다리 안에서의 순서: 로드 → 정강이 → 슬리브 → 관절 캡 (캡이 이음매를 덮는다)
		for key in ["rod", "shin", "sleeve", "knee_cap", "hip_cap"]:
			holder.add_child(d[key])
		(d["rod"] as Sprite2D).z_index = 0
		(d["shin"] as Sprite2D).z_index = 1
		(d["sleeve"] as Sprite2D).z_index = 2
		(d["knee_cap"] as Sprite2D).z_index = 3
		(d["hip_cap"] as Sprite2D).z_index = 3
		_legs.append(d)


## 규격을 정한다. ART_DIR/parts.json 이 있으면 그 값으로 (원화를 자른 도구가 써 준다),
## 없으면 PARTS_DEFAULT (플레이스홀더 치수) 로.
## 도구: Tools/ImageProcessing/cut_quadruped_rig_parts.py
func _load_specs() -> void:
	_parts = {}
	for k in PARTS_DEFAULT.keys():
		_parts[k] = (PARTS_DEFAULT[k] as Dictionary).duplicate()
	var path := ART_DIR + "parts.json"
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("parts"):
		return
	var src: Dictionary = data["parts"]
	for k in _parts.keys():
		var name: String = CAP_ALIAS.get(k, k)
		if not src.has(name):
			continue
		var d: Dictionary = src[name]
		_parts[k] = {
			"size": Vector2(float(d["size"][0]), float(d["size"][1])),
			"anchor": Vector2(float(d["anchor"][0]), float(d["anchor"][1])),
			"axis": String(d["axis"]),
			"file": name,
		}


func _make(key: String) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = key
	sp.texture = _tex[key]
	sp.centered = false
	sp.offset = -(_parts[key]["anchor"] as Vector2)      # 관절이 노드 원점에 오게
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sp


## 원화 조각이 있으면 그걸 쓴다. 없으면 규격 크기의 단색 판을 만들어 자리부터 맞춘다.
## 판에는 윗면 띠와 테두리를 넣는다 — 그게 없으면 조각이 뒤집혀 붙어도 눈치채지 못한다.
func _load_or_placeholder(key: String) -> Texture2D:
	var path := ART_DIR + String(_parts[key].get("file", key)) + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var size: Vector2 = _parts[key]["size"]
	var w := int(size.x)
	var h := int(size.y)
	var col: Color = PLACEHOLDER[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	for x in range(w):                                  # 윗면 띠 (위아래를 구분)
		for y in range(maxi(h / 8, 2)):
			img.set_pixel(x, y, col.lightened(0.22))
	for x in range(w):                                  # 테두리
		img.set_pixel(x, 0, col.darkened(0.55))
		img.set_pixel(x, h - 1, col.darkened(0.55))
	for y in range(h):
		img.set_pixel(0, y, col.darkened(0.55))
		img.set_pixel(w - 1, y, col.darkened(0.55))
	for y in range(h):                                  # 앞쪽 끝을 밝게 — 방향을 읽게
		img.set_pixel(w - 2, y, col.lightened(0.35))
		img.set_pixel(w - 3, y, col.lightened(0.35))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if walker == null:
		return
	_sync_body()
	for d in _legs:
		_sync_leg(d)


## 몸통 평면. 사영의 정확한 행렬을 얹는다 (walker.project 의 미분).
##   x = a·(c - dv.x·sn/BD) + (상수)      y = a·(-dv.y·sn/BD) + u + (상수)
## a 축 배율에만 하한을 둔다 — 정면을 지날 때 그림이 사라지지 않게.
func _sync_body() -> void:
	# 몸통 평면의 행렬은 walker 의 사영(fore_x/fore_y)을 그대로 쓴다.
	# 몸통 그림은 **두께의 가운데(s=0)** 에 둔다 — 원화가 이미 사선으로 두께를 품고 있으므로,
	# 가까운 면에 붙이면 돌아설 때 먼 쪽 다리 두 개가 몸통 밖으로 떨어져 나간다.
	#
	# 다만 **그림에만** 가로 폭 하한을 둔다. fore_x 는 돌아서는 도중 0 을 지나는데(그 각도에서
	# 측면 그림의 폭은 실제로 0 이다), 그대로 두면 그 두어 프레임 동안 몸통이 사라지고 다리와
	# 포신만 남아 기체가 반쪽으로 보인다 (원화를 붙이고 나서야 얼마나 어색한지 드러났다).
	# 하한을 두면 대신 그 순간 몸통 그림이 한 프레임 좌우로 뒤집힌다 — 폭이 가장 좁은
	# 순간이라 눈에 훨씬 덜 걸린다. **관절은 하한을 쓰지 않는다** (정확한 사영 그대로) —
	# 그림만 하한을 쓰고 관절도 같이 하한을 쓰면 포신이 몸에서 떠 버린다.
	# 이 하한 구간이 곧 정면 전환 시트가 들어갈 자리다.
	var fx: float = walker.fore_x()
	if absf(fx) < ProcWalker.SQUASH_MIN:
		fx = (1.0 if fx >= 0.0 else -1.0) * ProcWalker.SQUASH_MIN
	_plane.transform = Transform2D(Vector2(fx, walker.fore_y()), Vector2(0.0, 1.0), Vector2.ZERO)
	_hull.z_index = 4

	# ── 정면 전환 시트 자리 ──
	# fore_x 의 절댓값이 문턱보다 작으면 측면 그림이 종이처럼 얇아지는 구간이다.
	# 그 몇 프레임을 **정면에서 본 짧은 시트**로 덮으면 전환이 훨씬 또렷해진다 (다음 단계).
	# 지금은 시트가 없으므로 그냥 얇아지게 둔다 — 다리·포신이 따로 그려져 실루엣이 끊기지는 않는다.
	_hull.visible = true
	if _turn_sheet != null and absf(walker.fore_x()) < ProcWalker.SQUASH_MIN:
		pass      # TODO: 시트 프레임으로 교체 (yaw 진행 방향에 따라 프레임 선택)

	# 포신 — 요동축과 끝점을 각각 사영해 그 두 점으로 회전·길이를 만든다.
	# 몸이 돌면 두 점이 가까워져 포신이 저절로 짧아진다 (region 이 아니라 배율로 줄인다 —
	# 포신은 끝에 총구 블록이 있어 자르면 그게 사라진다)
	var pivot: Vector2 = walker.turret_local(0.0)
	var tip: Vector2 = walker.turret_local(ProcWalker.BARREL_LEN)
	var d := tip - pivot
	_barrel.position = pivot
	_barrel.rotation = d.angle() if d.length() > 0.001 else 0.0
	var fore: float = clampf(d.length() / ProcWalker.BARREL_LEN, ProcWalker.SQUASH_MIN, 1.0)
	_barrel.scale = Vector2(fore, 1.0)


func _sync_leg(d: Dictionary) -> void:
	var leg: Dictionary = d["leg"]
	var z: float = walker.leg_depth(leg)
	var hip: Vector2 = to_local(walker.hip_world(leg))
	var foot: Vector2 = to_local(leg["foot"]) + walker.depth_vec() * z
	var knee: Vector2 = ProcWalker.solve_knee_v(hip, foot, walker.phi0(leg))

	var holder: Node2D = d["holder"]
	# 깊이: 먼 쪽은 몸통 뒤(z_index 낮게) · 어둡게 · 조금 작게
	var far: float = clampf(z * 2.0, 0.0, 1.0)
	holder.z_index = 1 if z > 0.0 else 8
	holder.modulate = Color(1, 1, 1).lerp(Color(ProcWalker.FAR_MUL, ProcWalker.FAR_MUL, ProcWalker.FAR_MUL), far)
	var shrink := 1.0 - 0.18 * far

	var strut := hip.distance_to(knee)
	var ang := (knee - hip).angle()
	_fit("rod", d["rod"], hip, ang, strut, shrink)                                  # 로드: 필요한 만큼만
	_fit("sleeve", d["sleeve"], hip, ang, minf(ProcWalker.SLEEVE_LEN, strut), shrink)  # 무릎을 넘지 않게
	_fit("shin", d["shin"], knee, (foot - knee).angle(), -1.0, shrink)              # 정강이: 길이 불변
	(d["hip_cap"] as Sprite2D).position = hip
	(d["hip_cap"] as Sprite2D).scale = Vector2(shrink, shrink)
	(d["knee_cap"] as Sprite2D).position = knee
	(d["knee_cap"] as Sprite2D).scale = Vector2(shrink, shrink)


## 조각을 관절에 붙인다.
##   at   관절의 자리 (리그 로컬)
##   ang  마디가 **화면에서** 뻗어야 하는 방향
##   len  0 이상이면 그 길이만큼 **잘라** 보인다 (늘이지 않는다). 음수면 통째로.
##
## 원화에서 아래로 뻗게 그려진 조각(axis="down")은 -90° 를 더해 돌린다. 미리 90° 돌려 저장하면
## 위에서 내려오는 빛이 옆으로 눕어 금속의 방향감이 무너진다 — 그래서 그림은 세워 두고 회전으로 맞춘다.
## 자르는 방향도 그 축을 따른다 (down 이면 높이를, right 이면 너비를 자른다).
func _fit(key: String, sp: Sprite2D, at: Vector2, ang: float, len: float, shrink: float) -> void:
	var axis: String = _parts[key]["axis"]
	sp.position = at
	sp.rotation = ang - (PI * 0.5 if axis == "down" else 0.0)
	sp.scale = Vector2(shrink, shrink)
	var full: Vector2 = sp.texture.get_size()
	if len < 0.0:
		sp.region_enabled = false
		return
	sp.region_enabled = true
	if axis == "down":
		sp.region_rect = Rect2(0.0, 0.0, full.x, clampf(len, 1.0, full.y))
	else:
		sp.region_rect = Rect2(0.0, 0.0, clampf(len, 1.0, full.x), full.y)
