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
##             hip_cap / knee_cap  관절 원판: 이음매 틈을 가린다
##   다리 조각은 **가까운 벌 / 먼 벌 두 벌**이다. 원화가 3/4 이라 먼 다리는 작은 게 아니라
##   누워 있다 — 리그가 원근을 만들지 않고 원화에서 받아 쓴다 (LIMB_FAR 참고).
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
##   size   그림 크기(px, 리그 로컬 단위와 1:1)
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
	# 먼 다리용. 플레이스홀더 단계에서는 가까운 쪽과 같은 규격이면 충분하다 (원화가 오면 덮어쓴다)
	"sleeve_far": {"size": Vector2(74, 56), "anchor": Vector2(0, 28), "axis": "right"},
	"shin_far": {"size": Vector2(178, 52), "anchor": Vector2(0, 26), "axis": "right"},
	"hip_cap_far": {"size": Vector2(52, 52), "anchor": Vector2(26, 26), "axis": "none"},
	"knee_cap_far": {"size": Vector2(64, 64), "anchor": Vector2(32, 32), "axis": "none"},
}

## 원화 조각은 고관절·무릎에 같은 관절 원판을 쓴다 (원화에 온전한 실린더가 한 쌍뿐이다).
## "_far" 붙은 이름이 **먼 다리용 조각**이다 — 아래 LIMB_FAR 참고.
const CAP_ALIAS := {
	"hip_cap": "cap", "knee_cap": "cap",
	"hip_cap_far": "cap_far", "knee_cap_far": "cap_far",
}

## ## 먼 다리는 **원화가 그려 둔 먼 다리**를 쓴다 (2026-09-22)
## 예전엔 가까운 다리 한 벌을 0.82 배로 줄이고 어둡게 눌러 먼 다리로 썼다. 그런데 이 원화는
## 정측면이 아니라 3/4 이고, 그 안의 먼 다리는 "작은 가까운 다리" 가 아니라 **비스듬히 누워
## 폭이 절반으로 눌린** 다리다 (장갑판 폭 248 → 100px). 한 벌을 줄여 쓰면 리그의 사영 위에
## 원화의 원근이 한 번 더 얹혀 이중으로 보인다 — 다리가 넷인데 넷 다 카메라를 정면으로 보는
## 그 증상이다. 이제 원근을 **만들지 않고 원화에서 받아 온다.**
## 어느 쪽이 먼지는 yaw 를 따라 매 프레임 바뀌므로(돌아서면 앞뒤가 뒤바뀐다) 조각도 매 프레임 고른다.
const LIMB_FAR := {"rod": "rod", "sleeve": "sleeve_far", "shin": "shin_far",
	"hip_cap": "hip_cap_far", "knee_cap": "knee_cap_far"}

## 먼 다리를 이만큼만 어둡게 한다. 원화의 먼 다리가 **이미 어둡게 칠해져 있어**
## 예전의 FAR_MUL(0.62)을 그대로 먹이면 두 번 눌려 검게 죽는다 — 공기 원근만 살짝 얹는다.
const ART_FAR_MUL := 0.90

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
	"sleeve_far": Color(0.902, 0.549, 0.784),
	"shin_far": Color(0.851, 0.761, 0.369),
	"hip_cap_far": Color(0.518, 0.518, 0.878),
	"knee_cap_far": Color(0.518, 0.518, 0.878),
}

## 원화 조각을 찾는 곳. 파일이 있으면 쓰고, 없으면 플레이스홀더를 만든다 (A 단계)
const ART_DIR := "res://assets/quadruped/"

var walker: ProcWalker

## 총열 열 0..1 (WalkerUnit 이 매 프레임 넣어준다). 포신이 붉게 달아오른다 — 센트리건과 같은 BarrelGlow.
var heat := 0.0

## 스프라이트가 화면에서 차지하는 배율. 림 두께를 화면 기준으로 맞추는 데만 쓴다
## (본편은 0.5 배 그릇 안에 있고 랩은 1.0 이다 — 같은 값을 쓰면 본편에서 윤곽이 두 배로 두꺼워진다).
var px_scale := 1.0

var _plane: Node2D            # 몸통이 담기는 평면 (사영 행렬을 그대로 받는다)
var _hull: Sprite2D
var _turn_face: Sprite2D       # 회전 중 드러나는 두께 면; 측면과 연속적으로 교차한다
var _barrel: Sprite2D
var _chassis: Node2D          # 상체 회전과 독립된 하체 연결부
var _legs: Array = []         # [{index, holder, rod, sleeve, shin, hip_cap, knee_cap}] — index 는 walker.legs() 의 번호
var _tex: Dictionary = {}
var _mat: ShaderMaterial      # 조각이 **함께 쓰는** 라이팅 머티리얼 (노멀맵·림·열 잔광)
var _glow: BarrelGlow         # 달아오른 포신


var _parts: Dictionary = {}       # 실제로 쓰는 규격 (원화가 있으면 parts.json 값)


func _ready() -> void:
	if walker == null:
		walker = get_parent() as ProcWalker
	_load_specs()
	# 조상 변환에서 화면 배율을 읽는다 (본편은 0.5 그릇, 랩은 1.0). 림 두께에만 쓴다.
	px_scale = maxf(absf(get_global_transform().get_scale().x), 0.05)
	_mat = _surface_material()
	for k in _parts.keys():
		_tex[k] = _load_or_placeholder(k)

	# 몸통 평면 — z_index 는 다리와 섞이므로 각 조각에서 따로 준다
	_plane = Node2D.new()
	_plane.name = "BodyPlane"
	add_child(_plane)
	_hull = _make("hull")
	_plane.add_child(_hull)
	_turn_face = _make("hull")
	_turn_face.name = "HullTurnFace"
	_turn_face.z_index = 4
	add_child(_turn_face)
	_chassis = Node2D.new()
	_chassis.name = "SuspensionBridge"
	_chassis.z_index = 3
	_chassis.draw.connect(_draw_chassis)
	add_child(_chassis)

	_barrel = _make("barrel")
	_barrel.z_index = 6
	add_child(_barrel)

	# 달아오른 총열. 포신 스프라이트 **위에** 가산으로 덧그리는 층이라 z 를 한 칸 위로 둔다.
	# 이 노드 자체를 포신 각도로 돌리므로, BarrelGlow 는 제 로컬에서 늘 가로로 누운 포신 하나만 안다
	# (센트리건은 포신이 로컬에서 가로라 그대로 됐지만, 이 기체는 포신이 360° 돈다).
	_glow = BarrelGlow.new()
	_glow.name = "BarrelGlow"
	_glow.z_index = 7
	add_child(_glow)
	_glow.setup([{"back": Vector2.ZERO, "tip": Vector2(ProcWalker.BARREL_LEN, 0.0), "w": ProcWalker.BARREL_W}])

	# 다리 딕셔너리를 **들고 있지 않는다. 번호만 기억한다.**
	# ProcWalker.reset_stance() 는 네 다리를 통째로 새 딕셔너리로 갈아 끼운다(씬 시작·초기화·착지 직후).
	# 여기서 딕셔너리를 잡아 두면 그 순간 리그만 **버려진 옛 다리**를 계속 그린다 —
	# 몸통은 걸어가는데 발이 처음 자리에 얼어붙는 그 증상이다. 번호로 매 프레임 다시 찾으면 그럴 일이 없다.
	for i in walker.legs().size():
		var leg: Dictionary = walker.legs()[i]
		var holder := Node2D.new()
		holder.name = "Leg_" + str(leg["name"])
		add_child(holder)
		var d := {
			"index": i, "holder": holder,
			"rod": _make("rod"), "sleeve": _make("sleeve"), "shin": _make("shin"),
			"hip_cap": _make("hip_cap"), "knee_cap": _make("knee_cap"),
		}
		if walker.spider_gait:
			d["mount_link"] = _make("rod")
			d["ankle_cap"] = _make("knee_cap")
			holder.add_child(d["mount_link"])
			holder.add_child(d["ankle_cap"])
			(d["ankle_cap"] as Sprite2D).z_index = 3
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
			"lean": float(d.get("lean", 0.0)),
			"file": name,
		}


func _make(key: String) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = key
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.material = _mat
	_wear(sp, key)
	return sp


## 이 조각의 그림·앵커를 스프라이트에 입힌다. 가까운 다리/먼 다리를 오가려면 매 프레임 바뀌므로
## 만들 때 한 번이 아니라 **필요할 때마다** 부른다 (같은 조각이면 건드리지 않는다).
func _wear(sp: Sprite2D, key: String) -> void:
	if sp.texture == _tex[key]:
		return
	sp.texture = _tex[key]
	sp.offset = -(_parts[key]["anchor"] as Vector2)      # 관절이 노드 원점에 오게


## 조각이 함께 쓰는 라이팅 머티리얼. 이 기체는 인물이 아니라 **기계**라 센트리건과 같은
## prop_surface 를 쓴다 (노멀맵 확산 + 스페큘러 + 배경 림). 림 두께는 텍스처 px 기준이라
## 화면 배율로 나눠 줘야 어떤 크기로 놓든 같은 굵기로 보인다 — SentryTurret._surface_material 과 같다.
func _surface_material() -> ShaderMaterial:
	var m := Lighting.shader_material("prop_surface")
	m.set_shader_parameter("rim_width_px", float(Lighting.rim_preset()["width"]) / px_scale)
	return m


## 원화 조각이 있으면 그걸 쓴다. 없으면 규격 크기의 단색 판을 만들어 자리부터 맞춘다.
## 판에는 윗면 띠와 테두리를 넣는다 — 그게 없으면 조각이 뒤집혀 붙어도 눈치채지 못한다.
func _load_or_placeholder(key: String) -> Texture2D:
	var path := ART_DIR + String(_parts[key].get("file", key)) + ".png"
	if ResourceLoader.exists(path):
		# **Lighting.textured()** 로 받는다 — assets/normals/quadruped/<이름>.png 가 붙은 CanvasTexture 다.
		# 예전엔 load() 로 원화만 받아 조각이 통째로 평평하게 칠해졌다: 램프 밑을 걸어도 위아래가
		# 갈리지 않고 앰비언트 색만 곱해져, 같은 방의 인물·프랍만 입체로 보이고 이 기체만 종이였다.
		# (노멀맵은 Tools/build_normal_maps.py 의 "quadruped" 그룹이 굽는다)
		return Lighting.textured(path)
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
	_chassis.queue_redraw()
	for d in _legs:
		_sync_leg(d)


## 원화 몸통은 다리 소켓까지 한 장이다. 몸통만 돌릴 때 드러나는 관절을 고정 하체에 잇는다.
func _draw_chassis() -> void:
	var hub := walker.project(0.0, 30.0, 0.0)
	for leg in walker.legs():
		var hip := _to_rig(leg["pose"]["mount"] if walker.spider_gait else walker.hip_world(leg))
		var inner := hip.lerp(hub, 0.76)
		_chassis.draw_line(inner, hip, Color("171e25"), 28.0)
		_chassis.draw_line(inner + Vector2(0, -2), hip + Vector2(0, -2), Color("48504d"), 18.0)
		_chassis.draw_line(inner + Vector2(0, -9), hip + Vector2(0, -9), Color("8c8b69"), 3.0)
	# 낮은 회전 베어링: 네 다리는 고정 하체를 받치고 상체만 그 위에서 돌아간다.
	_chassis.draw_set_transform(hub + Vector2(0, -10), 0.0, Vector2(1.0, 0.25))
	_chassis.draw_circle(Vector2.ZERO, 61.0, Color("171e25"))
	_chassis.draw_arc(Vector2.ZERO, 56.0, 0.0, PI, 20, Color("b39650"), 7.0)
	_chassis.draw_set_transform(Vector2.ZERO)


## 상체의 연속 사영과 압축을 그대로 그린다. 포가도 같은 body_project()를 사용한다.
func _sync_body() -> void:
	# 원화가 두께를 품고 있으므로 몸통 중심(s=0)에 붙인다.
	var fx: float = walker.body_fore_x()
	var squash := walker.presentation_scale()
	_plane.transform = Transform2D(Vector2(fx, walker.body_fore_y()) * squash, Vector2(0.0, squash.y), Vector2.ZERO)
	_hull.z_index = 5
	# 측면 투영이 얇아질 때 두께 축의 면을 보여 준다. 좌우 폭을 강제로 뒤집지 않으므로
	# 상체 그림과 실제 포가가 같은 연속 좌표를 사용한다. 원화 텍스처와 금속 명암을 유지한다.
	var side_weight := smoothstep(0.02, 0.50, absf(fx))
	# 알파를 섞으면 금속이 잠시 반투명해 보인다. 두께 면을 실제로 펼쳐 항상 불투명한 부피를 유지한다.
	_hull.modulate.a = 1.0
	_turn_face.visible = side_weight < 0.999
	_turn_face.transform = Transform2D(walker.body_extrude_vec() / ProcWalker.BODY_LEN * squash * (1.0 - side_weight),
		Vector2(0.0, squash.y), Vector2.ZERO)
	_turn_face.modulate = Color(0.88, 0.90, 0.86)

	# 포신 전체를 반동 거리만큼 뒤로 옮긴다. 총열 길이는 상체 선회와 무관하게 유지한다.
	var pivot: Vector2 = walker.turret_local(-walker.recoil_distance())
	var tip: Vector2 = walker.turret_local(ProcWalker.BARREL_LEN - walker.recoil_distance())
	var d := tip - pivot
	_barrel.position = pivot
	_barrel.rotation = d.angle() if d.length() > 0.001 else 0.0
	var fore: float = clampf(d.length() / ProcWalker.BARREL_LEN, ProcWalker.SQUASH_MIN, 1.0)
	# 왼쪽으로 조준해도 포신의 윗면을 위로 유지한다. 하체 방향과는 무관하다.
	_barrel.scale = Vector2(fore, 1.0 if walker.aim_dir().x >= 0.0 else -1.0)

	# 달아오른 총열은 포신과 **같은 자리·같은 각도**에 얹는다 (좌우 반전은 따르지 않는다 —
	# 위아래 대칭으로 그리므로 뒤집을 필요가 없고, 뒤집으면 발광 라이트가 반대편으로 간다).
	_glow.position = pivot
	_glow.rotation = _barrel.rotation
	_glow.heat = heat


## ProcWalker 가 내놓는 좌표(발·고관절)는 **워커의 부모 공간**이다 — 월드가 아니다.
## 그걸 리그 로컬로 옮긴다. 리그는 워커의 직계 자식이고 제 변환이 없으므로 워커 변환의 역이 곧 답이다.
##
## 예전엔 to_local() 을 썼다. 그건 **글로벌** 기준 변환이라, 랩처럼 위쪽 노드가 전부 단위 변환일
## 때만 우연히 맞는다. 본편은 기체를 0.5 배 그릇에 담으므로(walker_unit.gd) 전부 어긋나
## **다리가 통째로 화면 밖에 그려졌다** — 몸통과 포신만 공중에 떠 있는 그림이 그 증상이었다.
## 조상 변환에 기대지 않는 이 방식이면 어떤 배율·어떤 부모 아래서도 같다.
func _to_rig(p: Vector2) -> Vector2:
	return walker.transform.affine_inverse() * p


func _sync_leg(d: Dictionary) -> void:
	var leg: Dictionary = walker.legs()[int(d["index"])]     # 번호로 매번 찾는다 (위 _ready 주석 참고)
	if walker.spider_gait:
		_sync_spider_leg(d, leg)
		return
	var z: float = walker.leg_depth(leg)
	var hip: Vector2 = _to_rig(walker.hip_world(leg))
	var foot: Vector2 = _to_rig(leg["foot"]) + walker.depth_vec() * z
	var knee: Vector2 = ProcWalker.solve_knee_v(hip, foot, walker.phi0(leg))

	var holder: Node2D = d["holder"]
	# 깊이: 먼 쪽은 몸통 뒤(z_index 낮게) · **원화의 먼 다리 조각**으로 갈아입고 · 살짝 어둡게.
	# 가늘게 줄이지 않는다 — 그 원근은 이미 조각에 그려져 있다 (LIMB_FAR 주석 참고)
	var far: float = clampf(z * 2.0, 0.0, 1.0)
	holder.z_index = 1 if z > 0.0 else 8
	var mul: float = lerpf(1.0, ART_FAR_MUL, far)
	holder.modulate = Color(mul, mul, mul)
	var set_far := z > 0.0

	var strut := hip.distance_to(knee)
	var ang := (knee - hip).angle()
	_fit(_pick("rod", set_far), d["rod"], hip, ang, strut)                                   # 로드: 필요한 만큼만
	_fit(_pick("sleeve", set_far), d["sleeve"], hip, ang, minf(ProcWalker.SLEEVE_LEN, strut))  # 무릎을 넘지 않게
	_fit(_pick("shin", set_far), d["shin"], knee, (foot - knee).angle(), -1.0)               # 정강이: 길이 불변
	_cap(d["hip_cap"], _pick("hip_cap", set_far), hip)
	_cap(d["knee_cap"], _pick("knee_cap", set_far), knee)


func _sync_spider_leg(d: Dictionary, leg: Dictionary) -> void:
	var pose: Dictionary = leg["pose"]
	var far: bool = leg["far"]
	var holder: Node2D = d["holder"]
	holder.z_index = 1 if far else 8
	var light := ART_FAR_MUL if far else 1.0
	holder.modulate = Color(light, light, light)
	# The shared solver already projected depth. No legacy depth_vec offset or second IK.
	var mount := _to_rig(pose["mount"])
	var hip := _to_rig(pose["hip"])
	var knee := _to_rig(pose["knee"])
	var ankle := _to_rig(pose["ankle"])
	var toe := _to_rig(pose["toe"])
	_fit_spatial_segment("rod", d["mount_link"], mount, hip, .65)
	_fit_spatial_segment("rod", d["rod"], hip, knee, .78)
	_fit_spatial_segment(_pick("sleeve", far), d["sleeve"], knee, ankle)
	_fit_spatial_segment(_pick("shin", far), d["shin"], ankle, toe)
	_cap(d["hip_cap"], _pick("hip_cap", far), hip)
	_cap(d["knee_cap"], _pick("knee_cap", far), knee)
	_cap(d["ankle_cap"], _pick("knee_cap", far), ankle)


func _fit_spatial_segment(key: String, sprite: Sprite2D, start: Vector2, finish: Vector2, width := 1.0) -> void:
	# Physical lengths remain fixed in 3D. Only the projected sprite length changes.
	_fit(key, sprite, start, (finish - start).angle(), -1.0)
	var down: bool = _parts[key]["axis"] == "down"
	var anchor: Vector2 = _parts[key]["anchor"]
	var full: Vector2 = sprite.texture.get_size()
	var lean: float = _parts[key].get("lean", 0.0)
	var source_axis := (Vector2.DOWN if down else Vector2.RIGHT).rotated(-lean)
	var source_cross := Vector2(-source_axis.y, source_axis.x)
	var source_length := (full.y - anchor.y) / maxf(source_axis.y, .1) if down else (full.x - anchor.x) / maxf(source_axis.x, .1)
	var length_scale := start.distance_to(finish) / maxf(source_length, 1.0)
	var direction := (finish - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	sprite.transform = Transform2D(direction * length_scale * source_axis.x + perpendicular * width * source_cross.x,
		direction * length_scale * source_axis.y + perpendicular * width * source_cross.y, start)


func _pick(key: String, far: bool) -> String:
	return String(LIMB_FAR[key]) if far else key


func _cap(sp: Sprite2D, key: String, at: Vector2) -> void:
	_wear(sp, key)
	sp.position = at


## 조각을 관절에 붙인다.
##   at   관절의 자리 (리그 로컬)
##   ang  마디가 **화면에서** 뻗어야 하는 방향
##   len  0 이상이면 그 길이만큼 **잘라** 보인다 (늘이지 않는다). 음수면 통째로.
##
## 원화에서 아래로 뻗게 그려진 조각(axis="down")은 -90° 를 더해 돌린다. 미리 90° 돌려 저장하면
## 위에서 내려오는 빛이 옆으로 눕어 금속의 방향감이 무너진다 — 그래서 그림은 세워 두고 회전으로 맞춘다.
## 자르는 방향도 그 축을 따른다 (down 이면 높이를, right 이면 너비를 자른다).
##
## **조각을 줄이지 않는다.** 길이는 관절 두 점이 이미 정해 놓았고(len 이 그 실측 거리다),
## 굵기의 원근은 먼 다리 조각에 그려져 있다. 예전엔 먼 다리를 통째로 0.82 배로 줄였는데,
## 무릎·발 캡은 줄이지 않은 자리에 놓이니 먼 쪽 두 다리가 **늘 관절에서 0.18×길이
## (스트럿 172 에서 약 30px) 만큼 끊겨** 보였다.
##
## lean 은 그 조각이 **원화 안에서** 이미 기울어 있는 각이다 (먼 다리 장갑판은 18° 누워 있다).
## 회전에서 그만큼 되돌려야 관절이 맞는다. 자르는 길이도 그 기울기만큼 늘려 잡는다 —
## 비스듬한 마디는 같은 길이를 덮는 데 세로로 더 많은 픽셀이 든다.
func _fit(key: String, sp: Sprite2D, at: Vector2, ang: float, len: float) -> void:
	_wear(sp, key)
	var axis: String = _parts[key]["axis"]
	var lean: float = _parts[key].get("lean", 0.0)
	sp.position = at
	sp.rotation = ang - (PI * 0.5 if axis == "down" else 0.0) + lean
	sp.scale = Vector2.ONE
	var full: Vector2 = sp.texture.get_size()
	if len < 0.0:
		sp.region_enabled = false
		return
	var span := len / maxf(cos(lean), 0.2)
	sp.region_enabled = true
	if axis == "down":
		sp.region_rect = Rect2(0.0, 0.0, full.x, clampf(span, 1.0, full.y))
	else:
		sp.region_rect = Rect2(0.0, 0.0, clampf(span, 1.0, full.x), full.y)
