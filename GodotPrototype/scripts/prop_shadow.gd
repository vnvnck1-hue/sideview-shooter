extends Node2D
## 프랍 그림자 층 (2026-09-20). 지금까지 프랍 밑에는 **광원과 무관한 고정 띠**(검정 ColorRect)만 있었다.
## (class_name 없이 preload 로 쓴다 — light_mood.gd 와 같은 이유)
##
## **확정 방식은 "각도 그림자"(wedge)** 다. 프랍의 그림 모양(실루엣)을 투영하는 게 아니라,
## 프랍을 폭 w · 높이 h 의 **상자**로 보고 광원과의 **각도**만으로 삼각형을 그린다:
##
##       ☀ 광원 P
##        \
##         \                    ← 광선이 상자 꼭대기 far 모서리를 스친다
##     ┌────┐\
##     │상자 │ \                  그림자 = (모서리 밑) → (모서리 위) → (광선이 바닥에 닿는 점)
##     └────┴──\──── 바닥
##          ◣▓▓▓◤
##
## 광원이 머리 위로 올라갈수록 삼각형이 저절로 좁아져 사라지고, 옆으로 내려올수록 길게 눕는다.
## 광원이 움직이면 삼각형이 따라 돈다 — 실루엣 투영과 달리 "빛과 물체의 기하"가 그대로 보인다.
##
## 그림자는 **두 겹**이다:
##   1) 기본 그림자 (BASE_PRESETS · F6) — 방에 붙박인 광원(천장 램프·기구·무드 채광).
##      우세한 광원 위쪽 몇 개가 각각 자기 쐐기를 던진다 (WEDGE.count).
##   2) 동적 그림자 (DYN_PRESETS · F8) — **움직이거나 번쩍 켜졌다 꺼지는** 광원.
##      총구 화염·탄착 섬광·불·전선 아크·회전 비상등·날아가는 독액이 여기 들어간다
##      (Lighting.register_dynamic 으로 등록 → Lighting.dynamic_lights()).
##      붙박이 광원 몫은 1층이 이미 처리하므로 여기서는 **동적 광원만** 본다 — 같은 빛이 두 번 그림자를 만들지 않는다.
##
## 폐기하지 않고 남겨 둔 비교용 방식 (F6 로 순환):
##   접촉(contact)      프랍 밑 고정 띠. 광원과 무관 — 예전에 쓰던 것
##   블롭(blob)         바닥에 고인 타원이 광원 반대쪽으로 밀린다
##   바닥·벽 드리움     프랍 **실루엣**을 눕히거나 확대한 투영 — "모양이 그대로 나온다"는 이유로 반려됨
##   실제 차폐(occluder) Godot 2D 오클루더. 물리적으로는 맞지만 광원 중심 **방사형**이라 옆에서 보면 방향이 안 읽힌다

const SHADOW_SHADER := "prop_shadow"

## --- 각도 그림자(확정) 수치 -------------------------------------------------
## 길이는 닮은꼴 삼각형 그대로 len = |dx| · H / (광원높이 − H) 로 구하되, **물체 높이 H 의 배수**로 자른다.
## 자르지 않으면 두 극단이 다 깨진다 — 램프가 프랍 바로 위면 len→0 이라 그림자가 아예 사라지고,
## 벽 조명처럼 광원이 물체 꼭대기보다 낮으면 분모가 0 이하가 되어 방을 가로지른다.
##   min_ratio 광원이 머리 바로 위여도 이만큼은 남긴다 (접지감)
##   max_ratio 광원이 낮아도 이 이상 길어지지 않는다
## alpha 모서리 쪽 진하기 · top 꼭짓점 진하기 비율 · tip 바닥 끝점 진하기 비율
## count 프랍 하나가 받는 광원 수 (밝은 순). 2 면 램프 두 개가 각각 그림자를 만든다
## static var 인 이유: 조명 랩(shadow_lab.gd)이 실행 중에 값을 바꿔 가며 비교한다. 확정되면 그 값을 여기 적는다.
## 확정 2026-09-20 (조명 랩 A/B). 예전 값(top 0.55 · tip 0.12 · max_ratio 2.0)은 삼각형이 **검은 판때기**로 보였다 —
## 광원이 옆에 있으면 물체 높이 전체를 채운 큰 덩어리가 되어 옆 프랍까지 삼켰다.
## 고친 핵심은 길이 상한이 아니라 **그라데이션**이다: 꼭짓점·끝점을 확 떨어뜨리면 길어져도 그림자로 읽힌다.
## 그래서 max_ratio 는 1.2 로 넉넉히 남겨 뒀다 — 스치는 빛에서 길게 늘어나는 "유기적 반응"이 이 값에서 나온다.
static var WEDGE := {
	"alpha": 0.58, "top": 0.20, "tip": 0.04,
	"min_ratio": 0.12, "max_ratio": 1.2, "count": 2,
}
## 동적 광원용 — 총구 화염은 프랍과 같은 높이라 늘 max_ratio 에 붙는다. 더 길게 뻗도록 상한을 키운다.
static var DYN_WEDGE := {
	"alpha": 0.62, "top": 0.22, "tip": 0.05,
	"min_ratio": 0.15, "max_ratio": 1.8, "count": 1,
}

## len   전단 계수 배율      squash 바닥면 눌림      alpha 최대 진하기
## blur  번짐(텍셀)          fade 먼 끝 페이드
## depth 뒷벽이 프랍보다 얼마나 뒤에 있다고 볼지(px)   max_offset·offset_ratio 밀림 상한   max_scale 닮음비 상한
const BASE_PRESETS := [
	{"id": "none", "name": "없음", "desc": "기본 그림자 없음 — 비교 기준"},
	{"id": "contact", "name": "접촉 그림자 (이전)", "desc": "프랍 밑 고정된 짧고 단단한 띠. 광원이 어디 있든 똑같다",
		"contact": {"alpha": 0.35, "inset": 18.0, "thick": 10.0}},
	{"id": "blob", "name": "광원 블롭", "desc": "바닥에 고인 부드러운 타원이 광원 반대쪽으로 밀리고 늘어난다",
		"blob": {"len": 0.34, "alpha": 1.04, "squash": 0.26, "grow": 0.55}},
	{"id": "floor", "name": "바닥 드리움 (실루엣)", "desc": "프랍 실루엣을 바닥면에 눕혀 기울인 투영 — 물체 모양이 그대로 나온다",
		"blob": {"len": 0.20, "alpha": 0.30, "squash": 0.24, "grow": 0.30},
		"floor": {"len": 1.0, "squash": 0.20, "alpha": 0.55, "blur": 1.6, "fade": 0.62}},
	{"id": "wall", "name": "벽 드리움 (실루엣)", "desc": "뒷벽에 맺히는 확대된 실루엣",
		"contact": {"alpha": 0.30, "inset": 18.0, "thick": 10.0},
		"wall": {"depth": 85.0, "max_offset": 30.0, "offset_ratio": 0.15, "max_scale": 1.08, "alpha": 0.46, "blur": 3.2, "fade": 0.18}},
	{"id": "both", "name": "바닥+벽 드리움 (실루엣)", "desc": "실루엣 투영 두 장",
		"floor": {"len": 1.0, "squash": 0.20, "alpha": 0.50, "blur": 1.6, "fade": 0.62},
		"wall": {"depth": 75.0, "max_offset": 26.0, "offset_ratio": 0.13, "max_scale": 1.07, "alpha": 0.38, "blur": 3.2, "fade": 0.20}},
	{"id": "occluder", "name": "실제 차폐 (오클루더)", "desc": "Godot 2D 그림자 — 빛이 프랍에 실제로 막혀 방사형 그림자 기둥이 생긴다",
		"contact": {"alpha": 0.30, "inset": 18.0, "thick": 10.0},
		"occluder": true},
	{"id": "wedge", "name": "각도 그림자", "desc": "광원과 물체의 각도로 만든 단순한 삼각형. 광원이 옆으로 갈수록 길게 눕고 머리 위로 오면 사라진다",
		"contact": {"alpha": 0.22, "inset": 18.0, "thick": 8.0},
		"wedge": true},
]
const BASE_DEFAULT := 7         # 8번 "각도 그림자" — 확정 기본값
static var index := BASE_DEFAULT

## 동적 광원(총구 화염·탄착·불·아크·비상등·독액)에 대한 반응 방식
const DYN_PRESETS := [
	{"id": "none", "name": "없음", "desc": "동적 광원은 그림자를 만들지 않는다"},
	{"id": "occluder", "name": "실제 차폐 연동", "desc": "동적 광원에도 2D 오클루더 그림자를 켠다 — 진짜 차폐가 광원을 따라 돈다",
		"occluder": true},
	{"id": "wedge", "name": "각도 그림자", "desc": "총구 화염·탄착이 터진 자리에서 각도 삼각형이 확 뻗었다가 천천히 사라진다",
		"wedge": true},
	{"id": "wall", "name": "벽 드리움", "desc": "쏘는 순간에만 뒷벽에 실루엣이 확 맺혔다 사라진다 (붙박이 램프에는 안 붙는다)",
		"wall": true},
	{"id": "wedge_wall", "name": "각도 + 벽 드리움", "desc": "각도 삼각형 + 섬광에만 맺히는 벽 실루엣",
		"wedge": true, "wall": true},
	{"id": "all", "name": "전부", "desc": "실제 차폐 + 각도 그림자 + 벽 드리움",
		"occluder": true, "wedge": true, "wall": true},
]
const DYN_DEFAULT := 4          # "각도 + 벽 드리움"
static var dyn_index := DYN_DEFAULT

## 동적 광원 전용 **벽 드리움** — 총구 화염·탄착처럼 번쩍 켜지는 빛에만 맺히는 실루엣.
## 붙박이 램프에는 붙이지 않는다: 늘 떠 있으면 프랍마다 검은 분신이 하나씩 붙어 다니는 꼴이 된다.
## 섬광에만 한 순간 맺혔다 사라지므로 "총을 쏘는 순간 벽에 그림자가 확 튄다" 는 연출이 된다.
## 수치 의미는 BASE_PRESETS 의 wall 과 같다 (depth · max_offset · offset_ratio · max_scale).
static var DYN_WALL := {
	"depth": 75.0, "max_offset": 28.0, "offset_ratio": 0.14, "max_scale": 1.075,
	"alpha": 0.5, "blur": 3.0, "fade": 0.22,
}

## 벽 드리움은 **스무딩을 전혀 걸지 않는다** — 섬광 세기를 그대로 쓴다.
## 쐐기와 같은 곡선(릴리스 5/s)은 물론, 빠른 곡선(30/s)으로도 부족했다:
## 연사 간격 0.09초 중 총구가 꺼져 있는 시간은 0.035초뿐이라 두어 프레임밖에 못 빠지고,
## 광원이 프랍에 가까워 기여도가 클 때는 골이 0 까지 내려오지 않아 "계속 켜진 채 흔들리는" 것처럼 보였다.
## 총구가 꺼지면 동적 광원이 하나도 없어 target 이 정확히 0 이 되므로, 그대로 쓰면 발사에 딱 맞춰 꺼진다.
## (쐐기는 길이·각도가 같이 변해 잔상이 오히려 자연스러우므로 기존 곡선을 유지한다.)

## 동적 광원 기여도 → 세기 곡선. alpha = power / (power + knee).
## 합을 그냥 clamp 하면 불·아크만으로 1.0 에 붙박여 총구 화염이 터져도 더 진해지지 않는다 —
## 이 곡선은 늘 여유를 남겨 섬광이 한 번 더 눌러 준다.
##
## **스무딩(어택/릴리스)은 걸지 않는다.** 예전에는 릴리스 5/s 로 잔상을 남겼는데,
## 본편 총구 화염은 0.03초만 켜지고 0.06초 쉬는(FIRE_COOLDOWN 0.09) 짧은 섬광이라
## 잔상이 발사 간격보다 길어 그림자가 계속 떠 있는 것처럼 보였다 — "둔하게 반응" 의 원인.
## 총구가 꺼지면 target 이 정확히 0 이 되므로, 그대로 쓰면 한 발 한 발에 딱 맞춰 켜졌다 꺼진다.
## 방향(slot.pos)은 빛이 살아 있을 때만 갱신하므로, 꺼지는 순간 제자리로 튀지 않는다.
const DYN_FOLLOW := {"falloff": 900.0, "knee": 0.9}

## 오클루더 수치 (기본·동적 공용)
const OCC := {"softness": 14.0, "alpha": 0.78, "width": 0.88, "height": 0.92}

const MAX_SHEAR := 2.2            # (실루엣 드리움용) 전단 계수 상한
const MIN_UP := 0.35              # (실루엣 드리움용) 광원 방향의 최소 수직 성분
const FALLOFF := 700.0            # 붙박이 광원 가중치 감쇠 기준 거리 (px)

## --- 조명 랩이 맞춘 값을 본편과 공유한다 -------------------------------------
## 앰비언스 랩(ambience/tuning.json)과 같은 규약: res:// 아래 JSON 에 저장하고, 실행할 때 읽어 덮어쓴다.
## 파일이 없으면 위에 적힌 코드 기본값 그대로 간다 — 저장 전까지는 아무것도 바뀌지 않는다.
const TUNING_PATH := "res://shadow/tuning.json"
## 저장·복원 대상 (static var 인 사전들). 프리셋 선택(index·dyn_index)도 같이 넣는다.
const TUNED := ["WEDGE", "DYN_WEDGE", "DYN_WALL"]
static var _tuning_loaded := false


## 지금 수치를 JSON 으로. 랩이 저장할 때, 그리고 랩 HUD 가 보여줄 때 쓴다.
static func tuning_dict() -> Dictionary:
	return {
		"wedge": WEDGE.duplicate(), "dyn_wedge": DYN_WEDGE.duplicate(), "dyn_wall": DYN_WALL.duplicate(),
		"base_preset": BASE_PRESETS[index]["id"], "dyn_preset": DYN_PRESETS[dyn_index]["id"],
	}


## 저장된 값을 읽어 덮어쓴다 (없으면 그대로). 방이 조립될 때 한 번만 돈다.
static func load_tuning() -> void:
	if _tuning_loaded:
		return
	_tuning_loaded = true
	if not FileAccess.file_exists(TUNING_PATH):
		return
	var f := FileAccess.open(TUNING_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("그림자 튜닝 파일을 읽지 못했습니다: %s" % TUNING_PATH)
		return
	_merge(WEDGE, parsed.get("wedge", {}))
	_merge(DYN_WEDGE, parsed.get("dyn_wedge", {}))
	_merge(DYN_WALL, parsed.get("dyn_wall", {}))
	var bi := _preset_index(BASE_PRESETS, str(parsed.get("base_preset", "")))
	if bi >= 0:
		index = bi
	var di := _preset_index(DYN_PRESETS, str(parsed.get("dyn_preset", "")))
	if di >= 0:
		dyn_index = di


## 파일에 있는 키만 덮어쓴다 — 나중에 수치를 추가해도 옛 저장 파일이 그것을 지우지 않는다.
static func _merge(target: Dictionary, src) -> void:
	if not (src is Dictionary):
		return
	for k in src:
		if target.has(k):
			target[k] = float(src[k]) if target[k] is float else int(src[k])


static func _preset_index(table: Array, id: String) -> int:
	for i in table.size():
		if table[i]["id"] == id:
			return i
	return -1


## 지금 수치를 TUNING_PATH 에 쓴다. 반환값은 사람이 읽을 절대 경로 (실패 시 빈 문자열).
static func save_tuning() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TUNING_PATH.get_base_dir()))
	var f := FileAccess.open(TUNING_PATH, FileAccess.WRITE)
	if f == null:
		push_error("그림자 튜닝 저장 실패: %s" % TUNING_PATH)
		return ""
	f.store_string(JSON.stringify(tuning_dict(), "	", false) + "
")
	f.close()
	return ProjectSettings.globalize_path(TUNING_PATH)


var _floor_y := 0.0
var _room_w := 100000.0           # 쐐기가 방 밖으로 뻗지 않게 자르는 폭
## {"node": Node2D(원점=바닥 중심), "tex", "w", "h", "lx"/"rx"(원점 기준 불투명 좌·우), "ty"(원점 기준 불투명 윗선)}
var _casters: Array = []
static var _box_cache := {}       # 텍스처 → 불투명 경계 Rect2i (Image.get_used_rect)
var _lights: Array = []           # 방 붙박이 배경 PointLight2D (거울 라이트·바닥 풀 제외)
var _items: Array = []            # 프랍별 그림자 노드
var _shadowed: Array = []         # shadow_enabled 를 켠 라이트 WeakRef (프리셋을 끌 때 되돌린다)
var _shadow_watermark := 64       # _shadowed 청소 기준선 (Lighting._track 와 같은 상각 규칙)
var _occluders_built := false


func setup(floor_line: float, room_width := 100000.0) -> void:
	load_tuning()                     # 조명 랩이 저장한 값이 있으면 여기서 반영된다
	name = "PropShadows"
	_floor_y = floor_line
	_room_w = room_width
	set_process(false)


## 프랍 하나를 그림자 캐스터로 등록. node 의 원점이 **바닥 중심**이어야 한다 (HitProp·PowerRelayProp 둘 다 그렇다).
## 그림자 상자는 텍스처 크기가 아니라 **불투명 픽셀 경계**로 잡는다 — 자산마다 투명 여백이 수십 px 씩 있어
## (예: 370x315 텍스처의 실제 그림은 (48,33)-(331,292)) 그대로 쓰면 그림자가 물체보다 크고 높은 데서 시작한다.
func add_caster(node: Node2D, tex: Texture2D) -> void:
	if tex == null or node == null:
		return
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var box := _opaque_box(tex)
	_casters.append({"node": node, "tex": tex, "w": w, "h": h,
		"lx": float(box.position.x) - w * 0.5,       # 원점(바닥 중심) 기준 불투명 왼쪽
		"rx": float(box.end.x) - w * 0.5,            # 〃 오른쪽
		"ty": float(box.position.y) - h})            # 〃 윗선 (음수)


## 텍스처의 불투명 픽셀 경계. CanvasTexture 는 디퓨즈에서 꺼낸다.
static func _opaque_box(tex: Texture2D) -> Rect2i:
	if _box_cache.has(tex):
		return _box_cache[tex]
	var src: Texture2D = tex
	if tex is CanvasTexture:
		src = (tex as CanvasTexture).diffuse_texture
	var box := Rect2i(0, 0, int(tex.get_width()), int(tex.get_height()))
	var img: Image = src.get_image() if src else null
	if img:
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			box = used
	_box_cache[tex] = box
	return box


## 방 조립이 끝난 뒤(무드 광원까지 올라간 뒤) Room 이 부른다.
func build(lights_layer: Node2D, i: int) -> void:
	_lights.clear()
	if lights_layer:
		_collect_lights(lights_layer)
	apply(i)


## 붙박이 광원 수집 — 배경 층을 비추는 PointLight2D 만. 인물 층 거울 라이트(LightMirror)와
## 램프 바로 밑 바닥 풀(FloorPool)은 뺀다: 풀은 프랍보다 **아래**에 있어 그림자를 위로 뒤집는다.
func _collect_lights(n: Node) -> void:
	for c in n.get_children():
		if c is LightMirror or c.name == "FloorPool":
			continue
		if c is PointLight2D:
			_lights.append(c)
		_collect_lights(c)


func apply(i: int) -> void:
	index = wrapi(i, 0, BASE_PRESETS.size())
	_rebuild()


func apply_dynamic(i: int) -> void:
	dyn_index = wrapi(i, 0, DYN_PRESETS.size())
	_rebuild()


func _rebuild() -> void:
	var p: Dictionary = BASE_PRESETS[index]
	var dp: Dictionary = DYN_PRESETS[dyn_index]
	for it in _items:
		for k in ["contact", "blob", "floor", "wall"]:
			if it[k] != null:
				it[k].queue_free()
		for poly in it["wedges"]:
			poly.queue_free()
		for slot in it["dwedges"]:
			for key in ["poly", "wall"]:
				if slot.get(key) != null:
					slot[key].queue_free()
	_items.clear()
	_clear_occluders()

	var floor_mat := _shadow_material(p.get("floor", {}))
	var wall_mat := _shadow_material(p.get("wall", {}))
	var dyn_wall_mat := _shadow_material(DYN_WALL) if dp.get("wall", false) else null

	for c in _casters:
		if not is_instance_valid(c["node"]):
			continue
		var it := {"c": c, "contact": null, "blob": null, "floor": null, "wall": null,
			"wedges": [], "dwedges": []}
		# 뒤에 붙인 것이 위에 그려진다. 동적 쐐기는 기본 그림자 **위**에 얹어 번쩍일 때 확실히 읽히게 한다.
		if p.has("wall"):
			it["wall"] = _sprite(c, wall_mat)
		if p.has("floor"):
			it["floor"] = _sprite(c, floor_mat)
		if p.get("wedge", false):
			for _k in range(int(WEDGE["count"])):
				it["wedges"].append(_wedge_poly())
		if p.has("blob"):
			it["blob"] = _blob(float(p["blob"]["alpha"]))
		if p.has("contact"):
			it["contact"] = _contact(c, p["contact"])
		# 동적 슬롯: 우세한 동적 광원 하나가 쐐기와 벽 실루엣을 같은 추종값으로 함께 움직인다
		var dyn_wedge: bool = dp.get("wedge", false)
		var dyn_wall: bool = dp.get("wall", false)
		if dyn_wedge or dyn_wall:
			for _k in range(int(DYN_WEDGE["count"])):
				it["dwedges"].append({
					"poly": _wedge_poly() if dyn_wedge else null,
					"wall": _sprite(c, dyn_wall_mat) if dyn_wall else null,
					"pos": Vector2.ZERO, "a": 0.0, "aw": 0.0})
		_items.append(it)

	if p.get("occluder", false) or dp.get("occluder", false):
		_build_occluders()
	# 붙박이 광원 차폐는 기본 프리셋이 오클루더일 때만 (동적 프리셋은 동적 광원만 켠다)
	if p.get("occluder", false):
		for l in _lights:
			_enable_shadow(l)

	set_process(index != 0 or dyn_index != 0)
	if is_processing():
		_process(0.0)                                   # 첫 프레임 전에 자리를 잡아 둔다


func _shadow_material(cfg: Dictionary) -> ShaderMaterial:
	if cfg.is_empty():
		return null
	var m := Lighting.shader_material(SHADOW_SHADER)
	m.set_shader_parameter("strength", float(cfg["alpha"]))
	m.set_shader_parameter("blur", float(cfg["blur"]))
	m.set_shader_parameter("far_fade", float(cfg["fade"]))
	return m


## 각도 그림자 삼각형. 정점 색으로 모서리(진함) → 꼭짓점 → 바닥 끝(옅음) 그라데이션을 준다.
func _wedge_poly() -> Polygon2D:
	var poly := Polygon2D.new()
	poly.color = Color.WHITE                       # 실제 색·알파는 vertex_colors 가 들고 있다
	poly.visible = false
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # 그림자가 라이트에 밝아지면 안 된다
	poly.material = m
	add_child(poly)
	return poly


## 프랍을 상자로 보고 광원 P 에서 만들어지는 그림자 삼각형을 poly 에 넣는다.
##   far 모서리 ex = 광원 **반대쪽** 수직 모서리
##   삼각형 = (ex, 바닥) → (ex, 바닥−h) → (광선이 바닥에 닿는 점, 바닥)
## 광원이 머리 위로 갈수록 끝점이 ex 로 붙어 삼각형이 사라지고, 옆·아래로 갈수록 길게 눕는다.
## alpha ≤ 0 이거나 길이가 min_len 미만이면 숨긴다. 반환값 = 보이는가.
func _place_wedge(poly: Polygon2D, cfg: Dictionary, P: Vector2, left: float, right: float, top_y: float, alpha: float) -> bool:
	var height := _floor_y - top_y
	if alpha <= 0.01 or height <= 1.0:
		poly.visible = false
		return false
	var cx := (left + right) * 0.5
	var ex := right if P.x <= cx else left        # 그림자를 던지는 수직 모서리 = 광원 **반대쪽**
	var dx := ex - P.x                            # 광원 → 그 모서리의 가로 거리 (부호가 곧 그림자 방향)
	var side := 1.0 if dx >= 0.0 else -1.0
	# 닮은꼴 삼각형: 광원 높이 lh, 물체 높이 height → 바닥에 닿는 지점까지 |dx|·height/(lh−height).
	# 분모는 1 로 바닥을 깔아 광원이 물체 꼭대기 아래에 있어도 발산하지 않는다 (아래 clamp 가 받는다).
	var lh := _floor_y - P.y
	var shadow_len := absf(dx) * height / maxf(lh - height, 1.0)
	shadow_len = clampf(shadow_len, height * float(cfg["min_ratio"]), height * float(cfg["max_ratio"]))
	var tip := clampf(ex + side * shadow_len, -_room_w * 0.05, _room_w * 1.05)
	if absf(tip - ex) < 2.0:
		poly.visible = false
		return false

	poly.visible = true
	poly.polygon = PackedVector2Array([
		Vector2(ex, _floor_y), Vector2(ex, top_y), Vector2(tip, _floor_y)])
	var a := clampf(alpha * float(cfg["alpha"]), 0.0, 1.0)
	poly.vertex_colors = PackedColorArray([
		Color(0, 0, 0, a),
		Color(0, 0, 0, a * float(cfg["top"])),
		Color(0, 0, 0, a * float(cfg["tip"]))])
	return true


func _sprite(c: Dictionary, mat: ShaderMaterial) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = c["tex"]
	s.offset = Vector2(-float(c["w"]) * 0.5, -float(c["h"]))   # 원점 = 바닥 중심 (프랍과 같은 규약)
	s.material = mat
	s.visible = false
	add_child(s)
	return s


## 바닥 블롭 — 라이트와 같은 원형 그라데이션을 검정으로 찍는다
func _blob(alpha: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Lighting.radial_texture()
	s.self_modulate = Color(0, 0, 0, alpha)
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = m
	add_child(s)
	return s


func _contact(c: Dictionary, cfg: Dictionary) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, float(cfg["alpha"]))
	r.size = Vector2(maxf(float(c["w"]) - float(cfg["inset"]) * 2.0, 18.0), float(cfg["thick"]))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	r.material = m
	add_child(r)
	return r


## 이 프랍에 대한 광원별 기여도. 밝은 순으로 정렬해 앞의 n 개만 돌려준다 (각도 그림자용 — 광원마다 쐐기 하나).
## below_ok = true 면 프랍보다 낮은 광원도 센다 (총구 화염은 사람 가슴 높이라 대부분 프랍보다 낮다).
func _top_lights(base: Vector2, lights: Array, falloff: float, n: int, below_ok := false) -> Array:
	var out: Array = []
	for l in lights:
		if not is_instance_valid(l) or not l.enabled or not l.visible or l.energy <= 0.01:
			continue
		var lp: Vector2 = l.global_position
		if not below_ok and lp.y > base.y - 24.0:
			continue
		var dist := maxf(base.distance_to(lp), 40.0)
		var w: float = l.energy * float(l.get_meta("shadow_weight", 1.0)) / (1.0 + pow(dist / falloff, 2.2))
		out.append({"pos": lp, "w": w})
	out.sort_custom(func(a, b): return a["w"] > b["w"])
	return out.slice(0, n)


## 프랍 바닥 중심에서 본 우세 광원 방향 (실루엣 드리움·블롭용 — 각도 그림자는 _top_lights 를 쓴다)
func _dominant(base: Vector2, lights: Array, falloff: float, below_ok := false) -> Dictionary:
	var acc := Vector2.ZERO
	var total := 0.0
	for l in lights:
		if not is_instance_valid(l) or not l.enabled or not l.visible or l.energy <= 0.01:
			continue
		var lp: Vector2 = l.global_position
		if not below_ok and lp.y > base.y - 24.0:
			continue
		var d := base - lp
		var dist := maxf(d.length(), 40.0)
		var w: float = l.energy * float(l.get_meta("shadow_weight", 1.0)) / (1.0 + pow(dist / falloff, 2.2))
		acc += (d / dist) * w
		total += w
	if total <= 0.0001:
		return {"dir": Vector2(0, 1), "power": 0.0, "coh": 0.0}
	var mean := acc / total
	return {"dir": mean.normalized(), "power": total, "coh": clampf(mean.length(), 0.0, 1.0)}


func _process(delta: float) -> void:
	var p: Dictionary = BASE_PRESETS[index]
	var dp: Dictionary = DYN_PRESETS[dyn_index]
	var dyn_lights: Array = Lighting.dynamic_lights() if dyn_index != 0 else []
	# 투영(쐐기·벽)은 **사격 계열 광원만** 본다 — 불·비상등처럼 늘 켜진 빛이 섞이면
	# 기여도가 0 으로 안 내려와 "쏴도 반응 안 하는" 상태가 된다. 오클루더는 전부 그대로 쓴다.
	var shot_lights: Array = Lighting.dynamic_lights("shot") if dyn_index != 0 else []
	# 새로 생긴 동적 광원(총구 화염·탄착)에도 차폐를 켠다 — 쏠 때마다 생겼다 사라지므로 여기서 따라잡는다
	if dp.get("occluder", false):
		for l in dyn_lights:
			_enable_shadow(l)

	for it in _items:
		var c: Dictionary = it["c"]
		var node: Node2D = c["node"]
		if not is_instance_valid(node) or not node.visible:
			for k in ["contact", "blob", "floor", "wall"]:
				if it[k] != null:
					it[k].visible = false
			for poly in it["wedges"]:
				poly.visible = false
			for slot in it["dwedges"]:
				for key in ["poly", "wall"]:
					if slot.get(key) != null:
						slot[key].visible = false
			continue
		var w: float = c["w"]
		var h: float = c["h"]
		var base: Vector2 = node.position              # 프랍 원점 = 바닥 중심 (밀림 반영)
		base.y = _floor_y                              # 그림자는 늘 바닥선에서 시작한다

		# --- 각도 그림자 (확정): 밝은 순으로 광원마다 쐐기 하나 -----------------
		if not it["wedges"].is_empty():
			var top := _top_lights(base, _lights, FALLOFF, it["wedges"].size())
			var lead: float = float(top[0]["w"]) if not top.is_empty() else 0.0
			for k in it["wedges"].size():
				if k >= top.size() or lead <= 0.0001:
					it["wedges"][k].visible = false
					continue
				var lw: float = top[k]["w"]
				# 세기: 우세 광원은 진하게, 보조 광원은 기여도 비율만큼 옅게
				var a := clampf(lw * 1.4, 0.0, 1.0) * (0.45 + 0.55 * (lw / lead))
				_place_wedge(it["wedges"][k], WEDGE, top[k]["pos"],
					node.position.x + float(c["lx"]), node.position.x + float(c["rx"]),
					node.position.y + float(c["ty"]), a)

		# --- 비교용: 접촉 · 블롭 · 실루엣 드리움 -------------------------------
		if it["contact"] != null or it["blob"] != null or it["floor"] != null or it["wall"] != null:
			var dom := _dominant(base, _lights, FALLOFF)
			var dir: Vector2 = dom["dir"]
			var lit := clampf(float(dom["power"]) * 1.4, 0.0, 1.0)
			var coh: float = dom["coh"]
			var shear := clampf(dir.x / maxf(dir.y, MIN_UP), -MAX_SHEAR, MAX_SHEAR)

			if it["contact"] != null:
				var r: ColorRect = it["contact"]
				r.visible = true
				r.position = Vector2(base.x - r.size.x * 0.5, _floor_y - 2.0)

			if it["blob"] != null:
				var b: Dictionary = p["blob"]
				var s: Sprite2D = it["blob"]
				s.visible = lit > 0.02
				var rx := w * 0.60 * (1.0 + absf(shear) * float(b["grow"]) * 0.5)
				var ry := rx * float(b["squash"])
				var k2 := float(Lighting.TEX_SIZE) * 0.5
				s.scale = Vector2(rx / k2, ry / k2)
				s.position = Vector2(base.x + shear * h * float(b["len"]) * 0.5, _floor_y + 4.0)
				s.self_modulate.a = clampf(float(b["alpha"]) * lerpf(0.55, 1.0, lit), 0.0, 1.0)

			if it["floor"] != null:
				it["floor"].visible = lit > 0.02
				_place_floor(it["floor"], p["floor"], base, shear,
					lerpf(0.35, 1.0, lit) * lerpf(0.5, 1.0, coh))
			if it["wall"] != null:
				# 벽 드리움은 방향이 아니라 광원 **위치**가 필요하다 (광원 중심 닮음 투영)
				var wl := _top_lights(base, _lights, FALLOFF, 1)
				it["wall"].visible = lit > 0.02 and not wl.is_empty()
				if it["wall"].visible:
					var bw := float(c["rx"]) - float(c["lx"])
					var bh := _floor_y - (node.position.y + float(c["ty"]))
					_place_wall(it["wall"], p["wall"], base, bw, bh, wl[0]["pos"],
						lerpf(0.3, 1.0, lit) * lerpf(0.45, 1.0, coh))

		# --- 동적 각도 그림자: 총구 화염·탄착·불·아크·비상등 -------------------
		if it["dwedges"].is_empty():
			continue
		var dtop := _top_lights(base, shot_lights, float(DYN_FOLLOW["falloff"]), it["dwedges"].size(), true)
		for k in it["dwedges"].size():
			var slot: Dictionary = it["dwedges"][k]
			var target := 0.0
			if k < dtop.size():
				var raw: float = dtop[k]["w"]
				target = raw / (raw + float(DYN_FOLLOW["knee"]))
				slot["pos"] = dtop[k]["pos"]            # 빛이 살아 있는 동안만 위치를 갱신한다
			# 쐐기·벽 모두 섬광 세기를 그대로 쓴다 (스무딩 없음 — 한 발 한 발에 딱 붙는다)
			slot["a"] = target
			slot["aw"] = target
			var sa := float(slot["a"])
			if slot["poly"] != null:
				_place_wedge(slot["poly"], DYN_WEDGE, slot["pos"],
					node.position.x + float(c["lx"]), node.position.x + float(c["rx"]),
					node.position.y + float(c["ty"]), sa)
			if slot["wall"] != null:
				var wa := float(slot["aw"])
				slot["wall"].visible = wa > 0.02
				if slot["wall"].visible:
					var bw2 := float(c["rx"]) - float(c["lx"])
					var bh2 := _floor_y - (node.position.y + float(c["ty"]))
					_place_wall(slot["wall"], DYN_WALL, base, bw2, bh2, slot["pos"], wa)


## (비교용) 바닥 실루엣 드리움: 로컬 (x, y) → base + (x − shear·y, −squash·y)
func _place_floor(s: Sprite2D, cfg: Dictionary, base: Vector2, shear: float, alpha: float) -> void:
	s.transform = Transform2D(Vector2(1.0, 0.0),
		Vector2(-shear * float(cfg["len"]), float(cfg["squash"])), base)
	s.self_modulate.a = clampf(alpha, 0.0, 1.0)


## (비교용) 벽 실루엣 드리움 — **광원을 중심으로 한 닮음 투영**.
## 프랍보다 depth 만큼 뒤에 뒷벽이 있다고 보면, 광원 P 에서 프랍을 지나 벽에 맺히는 상은
## P 를 중심으로 k = 1 + 밀림/거리 배 확대한 것이다:  월드점 q → P + (q − P)·k
## 확대 중심이 광원이라 밀림이 X·Y 양쪽에 생긴다 — 광원이 위로 가면 그림자가 아래로, 내려오면 위로.
## (예전에는 접지점을 축으로 확대하고 x 로만 밀어서 늘 물체 살짝 위에 붙박여 좌우로만 흔들렸다.)
##
## 밀림 거리는 **물체 크기로 잘라** 그림자가 실루엣에서 떨어져 나가지 않게 한다.
## 광원 중심 투영은 원래 밀림이 = depth 로 고정(거리와 무관)인데, 작은 프랍에는 그 170px 가
## 몸통보다 커서 그림자가 통째로 옆에 뚝 떨어진 별개의 얼룩처럼 보였다.
##   max_offset   밀림 절대 상한 (px)
##   offset_ratio 밀림 상한을 물체의 **짧은 변** 대비 비율로 한 번 더 조인다 (작은 프랍일수록 더 바짝)
##   max_scale    닮음비 상한 — 광원이 아주 가까울 때 그림자가 물체를 둘러싸며 커지는 것을 막는다
func _place_wall(s: Sprite2D, cfg: Dictionary, base: Vector2, box_w: float, box_h: float,
		light_pos: Vector2, alpha: float) -> void:
	var d := base - light_pos
	var dist := maxf(d.length(), 1.0)
	var cap := minf(float(cfg["max_offset"]), minf(box_w, box_h) * float(cfg["offset_ratio"]))
	var off := minf(float(cfg["depth"]), cap)
	var k := clampf(1.0 + off / dist, 1.0, float(cfg["max_scale"]))
	s.transform = Transform2D(Vector2(k, 0.0), Vector2(0.0, k), light_pos + d * k)
	s.self_modulate.a = clampf(alpha, 0.0, 1.0)


## --- 실제 차폐 (Godot 2D 오클루더) ---------------------------------------
## 프랍마다 사각 오클루더를 세우고, 그림자를 만들 라이트에 shadow_enabled 를 켠다.
## 인물 층 거울 라이트는 그대로 꺼 둬서 플레이어·몬스터는 이 그림자에 걸리지 않는다.
func _build_occluders() -> void:
	if _occluders_built:
		return
	for c in _casters:
		if not is_instance_valid(c["node"]):
			continue
		var node: Node2D = c["node"]
		var l := node.position.x + float(c["lx"])
		var r := node.position.x + float(c["rx"])
		var cx := (l + r) * 0.5
		var hw := (r - l) * 0.5 * float(OCC["width"])
		var hh := (_floor_y - (node.position.y + float(c["ty"]))) * float(OCC["height"])
		var poly := OccluderPolygon2D.new()
		poly.closed = true
		poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
		poly.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, 0.0), Vector2(-hw, 0.0)])
		var occ := LightOccluder2D.new()
		occ.occluder = poly
		occ.position = Vector2(cx, _floor_y)
		add_child(occ)
	_occluders_built = true


func _enable_shadow(l: PointLight2D) -> void:
	if not is_instance_valid(l) or l.shadow_enabled:
		return
	l.shadow_enabled = true
	# PCF13 은 쓰지 않는다 — Godot 문서가 "높은 렌더 비용 때문에 한 번에 몇 개 광원에만" 쓰라고 명시하는데
	# 여기는 총구 화염·탄착이 초당 여러 개씩 켜지는 자리다. PCF5 가 픽셀아트에는 충분하다.
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	l.shadow_filter_smooth = float(OCC["softness"])
	l.shadow_color = Color(0, 0, 0, float(OCC["alpha"]))
	if _shadowed.size() >= _shadow_watermark:
		var alive: Array = []
		for w in _shadowed:
			if w.get_ref() != null:
				alive.append(w)
		_shadowed.assign(alive)
		_shadow_watermark = maxi(64, alive.size() * 2)
	_shadowed.append(weakref(l))


func _clear_occluders() -> void:
	for c in get_children():
		if c is LightOccluder2D:
			c.queue_free()
	_occluders_built = false
	for w in _shadowed:
		var l = w.get_ref()
		if l != null and is_instance_valid(l):
			l.shadow_enabled = false
	_shadowed.clear()
