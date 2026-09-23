class_name ForegroundLayer
extends Node2D
## 근경 실루엣 층 (z 7, DepthLayers "근경 분리" 전용). 카메라와 방 사이에 있는 배관·행거·늘어진 케이블·기둥·상자·바닥 케이블 트레이를
## 어두운 실루엣으로 그린다. 몸체는 라이트를 받지 않고(light_mask 0) CanvasModulate(앰비언트)만 곱해져 거의 검고,
## 사각형의 네 변에 두른 4px 띠(foreground_rim.gdshader)만 라이트를 받아 광원을 향한 윤곽이 그 광원 색으로 읽힌다.
## 카메라 화면 중심 이동(사격 흔들림 제외)의 (PARALLAX−1) 배만큼 반대로 움직여(평활 + 4px 격자 히스테리시스) 가까움이 느껴진다.
##
## 데이터 모델: items = [{"kind", "pos": Vector2, "size": Vector2}] (방 로컬 px). kind 별 그리기는 _draw_item.
##   pipe / pillar / tray / crate : 잉크 사각형 + 림 띠 (+ pillar 리벳 띠, crate 판자 이음선·보강대)
##   dark                        : 더 어두운 사각형, 림 없음 (행거·플랜지·잔해)
##   cable                       : pos 에서 size.x 만큼 오른쪽으로 걸린 처진 선, size.y 가 처짐
##   pipe_bracket / utility_housing : 그림 근경(assets/props/foreground_*_v2.png)을 size 로 늘린 스프라이트 (SPRITES)
## 방마다 저장된 배치 파일(DATA_DIR/<방 id>.json)이 있으면 그것을 쓰고, 없으면 방 id 시드로 절차 생성한다.
## 배치는 foreground/<방 id>.json 에서 읽는다 (없으면 절차 생성).

const PARALLAX := 1.045                            # 1.12 → 1.06 → 1.03(너무 낮음) → 1.045: 방 끝에서 끝까지 걸으면 근경은 ±40px 정도
const GRID := 4.0                                  # 1 아트 px = 월드 4px
const SMOOTH_SPEED := 5.0                          # 패럴랙스 목표 지수 평활 속도 (클수록 즉각적)
const INK := Color(0.07, 0.07, 0.10)               # 앰비언트가 다시 곱해져 방 밖 어둠(순검정)과 거의 구분되지 않게 — 형체는 림이 알려준다
const INK_DARK := Color(0.04, 0.04, 0.06)
const PILLAR_SPACING := 1300.0
const KEEP_AWAY := 200.0                           # 램프·문 중심에서 이 안쪽에는 기둥·케이블·상자를 두지 않는다
const RIM_W := GRID                                # 림 띠 두께 (아트 1px)
const CRATE_SPACING := 1100.0                      # 방 폭 이만큼마다 상자 무리 1개
## 방 실루엣 경계에 붙이는 규격 (작업실 foreground/workshop.json 수작업 배치에서 뽑은 값).
## 근경은 방 윤곽(천장선·바닥 밴드 하단·측벽)을 덮어 방을 바깥 어둠과 이어 주는 역할이다 — 경계에서 짧게 끊기면
## 그 뒤로 배경 벽이 다시 보이므로, 배관·트레이는 경계선을 가운데 두고 두껍게 깔고 열린 쪽(어둠)으로 VOID_EXT 만큼 더 뻗는다.
const PIPE_H := 48.0                               # 천장 배관 두께 — 천장선을 가운데 두고 위아래 24px
const PIPE_JOINT_GAP := 28.0                       # 배관 마디 사이 틈 (플랜지가 걸친다)
const TRAY_H := 56.0                               # 바닥 트레이 두께 — 바닥 밴드 하단선을 덮는다 (윗선 = 하단 − 28)
const TRAY_GAP := Vector2(96.0, 230.0)             # 트레이 마디 사이 틈 범위
const VOID_EXT := 320.0                            # 열린 쪽(방 끝·낮은 천장 위)으로 어둠 속에 더 뻗는 길이
const PILLAR_W := Vector2(40.0, 64.0)              # 기둥 폭 범위 — 100px 은 방을 반으로 자르는 검은 커튼이 되어 64 로 낮췄다 (작업실 수작업 48)
const PILLAR_OVER := Vector2(44.0, 32.0)           # 기둥이 천장 위·바닥 밴드 아래로 넘는 길이
const CRATE_SINK := 38.0                           # 상자 바닥이 바닥선보다 내려가는 px (가까워서 낮게 보인다)
## 그림 근경(pipe_bracket·utility_housing)은 덩치가 커서 방 한가운데에 원본 크기로 놓으면 화면을 통째로 가린다.
## 방 양 끝에 붙여 대부분을 벽 바깥 어둠에 두고 아래 비율만큼만 방 안으로 들인다 (작업실 수작업 배치에서 뽑은 값).
const SPRITE_IN := 0.25                            # 파이프 브래킷이 방 안으로 들어오는 폭 비율
const SPRITE_H := Vector2(240.0, 480.0)            # 브래킷 높이 범위 (방 안 높이의 80%)
const SPRITE_RATIO := 0.625                        # 브래킷 폭 / 높이
const HOUSING_SIZE := Vector2(520.0, 180.0)        # 유틸리티 하우징 기본 크기 — 낮게 깔린다
const HOUSING_IN := 0.42                           # 하우징이 방 안으로 들어오는 폭 비율
const HOUSING_SINK := 88.0                         # 하우징 바닥이 바닥 밴드 하단보다 더 내려가는 px (방 안에서는 윗면만 보인다)

const DATA_DIR := "res://foreground/"
const KINDS := ["pipe", "pillar", "crate", "tray", "dark", "cable", "pipe_bracket", "utility_housing"]
## 새로 추가할 때 기본 크기
const DEFAULT_SIZE := {
	"pipe": Vector2(480, 24), "pillar": Vector2(40, 900), "crate": Vector2(144, 120),
	"tray": Vector2(480, 20), "dark": Vector2(32, 32), "cable": Vector2(360, 160),
	"pipe_bracket": Vector2(300, 480), "utility_housing": Vector2(520, 180),
}
## 그림 근경 (assets/props/foreground_*_v2.png). region = 불투명 영역, 항목 size 에 맞춰 늘린다 (기본 = 원본의 절반).
## 실루엣 근경과 같은 층·같은 어둠(라이트 제외, 앰비언트만) — SPRITE_TINT 로 톤을 맞춘다.
const SPRITES := {
	"pipe_bracket": {"path": "res://assets/props/foreground_pipe_bracket_v2.png", "region": Rect2(156, 0, 839, 1231)},
	"utility_housing": {"path": "res://assets/props/foreground_utility_housing_v2.png", "region": Rect2(85, 254, 1612, 558)},
}
const SPRITE_TINT := Color(0.55, 0.55, 0.60)
## 그림 근경을 절차 생성에 넣는 방 (시작 방 근처에서 시험). 다른 방은 랩에서 7·8 로 직접 놓는다.
const SPRITE_ROOMS := ["airlock", "corr_west", "workshop", "tank_room"]

var room_id := ""
var room_width := 0.0
var floor_y := 0.0
var ceiling_y := 0.0                               # 가장 높은 천장 y
var col_ceilings: Array = []                       # 열(128px)별 천장 y (계단형)
var room_bottom := 0.0                             # 바닥 밴드 하단 y
var items: Array = []                              # [{"kind": String, "pos": Vector2, "size": Vector2}]
var from_file := false                             # 저장 파일에서 읽었는지 (랩 HUD 표시용)

var _center := Vector2.ZERO
var _smooth := Vector2.ZERO                       # 평활된 패럴랙스 목표 (격자 스냅 전)
var _rng := RandomNumberGenerator.new()
var _rim_mat: ShaderMaterial
var _shapes: Node2D                                # 그려진 폴리곤들의 부모 (rebuild 때 통째로 갈아엎는다)


func _ready() -> void:
	light_mask = 0
	process_priority = 11                          # GameCamera(10) 뒤에 갱신


static func data_path(id: String) -> String:
	return DATA_DIR + id + ".json"


## avoid_x: 램프·문 중심 X 목록 (절차 생성 때 기둥·케이블·상자가 피한다)
## col_ceilings: 열(128px)별 천장 y — 계단형 천장. room_bottom: 바닥 밴드 하단 y. 림 셰이더가 어둠 쪽 면을 억제할 때 쓴다.
func build(id: String, width: float, floor_line: float, ceiling: float, avoid_x: Array, col_ceilings: Array = [], room_bottom := 0.0) -> void:
	room_id = id
	room_width = width
	floor_y = floor_line
	ceiling_y = ceiling
	_center = Vector2(width * 0.5, (ceiling_y + floor_y) * 0.5)
	self.col_ceilings = col_ceilings if not col_ceilings.is_empty() else [ceiling]
	self.room_bottom = room_bottom if room_bottom > 0.0 else floor_y + 50.0
	# Room.build 는 트리에 들어가기 전에 불리므로(_ready 이전) 머티리얼은 여기서 만든다
	_rim_mat = Lighting.shader_material("foreground_rim")
	_rim_mat.set_shader_parameter("ink", INK)
	_rim_mat.set_shader_parameter("room_w", width)
	_rim_mat.set_shader_parameter("room_bottom", self.room_bottom)
	var cols := PackedFloat32Array()
	for i in range(32):
		cols.append(float(col_ceilings[i]) if i < col_ceilings.size() else ceiling)
	_rim_mat.set_shader_parameter("col_count", mini(col_ceilings.size(), 32) if not col_ceilings.is_empty() else 1)
	_rim_mat.set_shader_parameter("col_ceiling", cols)
	_rim_mat.set_shader_parameter("cell_w", width / maxf(1.0, float(col_ceilings.size())) if not col_ceilings.is_empty() else width)
	if not load_items():
		generate(avoid_x)
	rebuild_visuals()


## 저장 파일이 있으면 items 로 읽는다
func load_items() -> bool:
	var path := data_path(room_id)
	if not FileAccess.file_exists(path):
		from_file = false
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary) or not parsed.has("items"):
		push_warning("근경 배치 파일 형식 오류: " + path)
		from_file = false
		return false
	items.clear()
	for e in parsed["items"]:
		if not (e is Dictionary) or not KINDS.has(e.get("kind", "")):
			continue
		items.append({
			"kind": String(e["kind"]),
			"pos": Vector2(float(e["pos"][0]), float(e["pos"][1])),
			"size": Vector2(float(e["size"][0]), float(e["size"][1])),
		})
	from_file = true
	return true


## items 를 DATA_DIR/<방 id>.json 에 저장 (랩의 S). 프로젝트 안에 두어 커밋된다.
func save_items() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	var out := []
	for it in items:
		out.append({"kind": it["kind"], "pos": [it["pos"].x, it["pos"].y], "size": [it["size"].x, it["size"].y]})
	var path := data_path(room_id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"room": room_id, "items": out}, "\t"))
	f.close()
	from_file = true
	return ProjectSettings.globalize_path(path)


## 절차 생성 (저장 파일이 없을 때, 또는 랩의 R 초기화). 작업실 수작업 배치의 규칙을 모든 방에 적용한다:
##   천장선마다 두꺼운 배관(마디·플랜지·행거), 바닥 밴드 하단선에 두꺼운 트레이(+잔해), 둘 다 열린 쪽 어둠으로 더 뻗음,
##   실내 기둥(천장 위~바닥 아래), 바닥 상자 무리, 배관에서 처진 케이블.
func generate(avoid_x: Array) -> void:
	items.clear()
	_rng.seed = hash(room_id)
	var width := room_width
	var cell := width / maxf(1.0, float(col_ceilings.size()))

	# 1. 천장 배관: 같은 높이로 이어진 천장 구간마다 한 줄. 구간 양끝이 열려 있으면(방 끝, 또는 옆 열이 더 낮음) 어둠 속으로 VOID_EXT 더.
	var runs := _ceiling_runs(cell)
	for run in runs:
		var cy: float = run["y"]
		var x0: float = run["x0"] - (VOID_EXT if run["open_l"] else 0.0)
		var x1: float = run["x1"] + (VOID_EXT if run["open_r"] else 0.0)
		var py := cy - PIPE_H * 0.5
		var x := x0
		while x < x1 - GRID:
			var seg := _q(_rng.randf_range(300.0, 900.0))
			if x + seg > x1 - 120.0:
				seg = _q(x1 - x)                                                   # 마지막 마디는 끝까지
			_add("pipe", Vector2(x, py), Vector2(seg, PIPE_H))
			if x + seg < x1 - GRID:
				_add("dark", Vector2(x + seg - GRID, cy - 4.0), Vector2(PIPE_JOINT_GAP + GRID * 2.0, 56.0))   # 마디 이음 플랜지
			var hx := _q(x + seg * 0.5)
			if hx > run["x0"] and hx < run["x1"]:
				_add("dark", Vector2(hx - 8.0, cy + PIPE_H * 0.5 + 12.0), Vector2(16.0, 28.0))              # 행거
			x += seg + PIPE_JOINT_GAP

	# 2. 늘어진 케이블: 가장 높은 천장 배관 아래에서 처진 곡선 1~3개 (램프·문 회피)
	var top_run: Dictionary = runs[0]
	for run in runs:
		if run["y"] < top_run["y"] or (run["y"] == top_run["y"] and run["x1"] - run["x0"] > top_run["x1"] - top_run["x0"]):
			top_run = run
	var n_cables := clampi(int(round((top_run["x1"] - top_run["x0"]) / 700.0)), 1, 3)
	for i in range(n_cables):
		var cx := _pick_x_in(top_run["x0"], top_run["x1"], avoid_x, 160.0)
		if cx < 0.0:
			continue
		var span := _q(_rng.randf_range(330.0, 420.0))
		var sag := _q(_rng.randf_range(130.0, 220.0))
		_add("cable", Vector2(cx - span * 0.5, top_run["y"] + PIPE_H * 0.5 + 12.0), Vector2(span, sag))

	# 3. 실내 기둥: 방 1300px 당 1개, 폭 64~100, 그 열의 천장 위 44px ~ 바닥 밴드 아래 32px
	var n_pillars := maxi(1, int(round(width / PILLAR_SPACING)))
	var placed: Array = []
	for i in range(n_pillars):
		var px := _pick_x_in(0.0, width, avoid_x + placed, KEEP_AWAY)
		if px < 0.0:
			continue
		placed.append(px)
		var w := _q(_rng.randf_range(PILLAR_W.x, PILLAR_W.y))
		var top := _ceiling_at(px, cell) - PILLAR_OVER.x
		_add("pillar", Vector2(px - w * 0.5, top), Vector2(w, room_bottom + PILLAR_OVER.y - top))

	# 4. 상자 무리: 바닥선보다 38px 아래에 닿는 상자 + 위에 얹힌 작은 상자. 램프·문·기둥·방 가운데 회피
	var n_crates := maxi(1, int(round(width / CRATE_SPACING)))
	for i in range(n_crates):
		var cx := _pick_x_in(0.0, width, avoid_x + placed, KEEP_AWAY)
		if cx < 0.0:
			continue
		placed.append(cx)
		_gen_crate_group(cx, floor_y + CRATE_SINK)

	# 5. 바닥 트레이: 바닥 밴드 하단선을 덮는 두꺼운 띠, 양쪽 어둠으로 VOID_EXT 더. 마디 사이 틈, 위에 잔해
	var ty := room_bottom - 28.0
	var tx0 := -VOID_EXT
	var tx1 := width + VOID_EXT
	var x := tx0
	while x < tx1 - GRID:
		var seg := _q(_rng.randf_range(500.0, 1000.0))
		if x + seg > tx1 - 200.0:
			seg = _q(tx1 - x)
		var h := TRAY_H + (4.0 if _rng.randf() < 0.5 else 0.0)
		_add("tray", Vector2(x, ty), Vector2(seg, h))
		if _rng.randf() < 0.6 and x > 0.0 and x + seg < width:
			var dx := x + _q(_rng.randf_range(40.0, maxf(44.0, seg - 60.0)))
			_add("dark", Vector2(dx, ty - 16.0), Vector2(_q(_rng.randf_range(32.0, 56.0)), 16.0))   # 놓인 잔해
		x += seg + _q(_rng.randf_range(TRAY_GAP.x, TRAY_GAP.y))

	# 6. 그림 근경 (시험 방만): 파이프 브래킷과 유틸리티 하우징을 방의 반대쪽 끝에 하나씩, 대부분 벽 바깥 어둠에 걸쳐 놓는다.
	#    예전처럼 방 한가운데에 원본 크기로 놓으면 좁은 방(에어록·서쪽 통로)은 화면이 통째로 가려진다.
	if SPRITE_ROOMS.has(room_id):
		var bracket_right := _rng.randf() < 0.5
		_gen_pipe_bracket(bracket_right, cell)
		_gen_utility_housing(not bracket_right)
	from_file = false


## 파이프 브래킷: 방 끝에 붙여 세로관만 SPRITE_IN 만큼 방 안으로 들인다. 천장 어둠에서 내려오게 천장선 위로 더 뻗는다.
func _gen_pipe_bracket(right: bool, cell: float) -> void:
	var edge := room_width if right else 0.0
	var probe := clampf(edge + (-cell * 0.5 if right else cell * 0.5), 0.0, room_width - 1.0)
	var cy := _ceiling_at(probe, cell)
	var h := _q(clampf((floor_y - cy) * 0.8, SPRITE_H.x, SPRITE_H.y))
	var w := _q(minf(h * SPRITE_RATIO, room_width * 0.3))
	var x := edge - w * SPRITE_IN if right else edge - w * (1.0 - SPRITE_IN)
	_add("pipe_bracket", Vector2(_q(x), _q(cy - h * 0.24)), Vector2(w, h))


## 유틸리티 하우징: 반대쪽 방 끝에 붙인 낮은 바닥 덩어리. 바닥 밴드 아래로 깊이 내려 방 안에서는 윗면만 보인다.
func _gen_utility_housing(right: bool) -> void:
	var w := _q(minf(HOUSING_SIZE.x, room_width * 0.34))
	var h: float = HOUSING_SIZE.y
	var edge := room_width if right else 0.0
	var x := edge - w * HOUSING_IN if right else edge - w * (1.0 - HOUSING_IN)
	_add("utility_housing", Vector2(_q(x), _q(room_bottom + HOUSING_SINK - h)), Vector2(w, h))


## 같은 천장 높이로 이어진 열 구간 목록: {y, x0, x1, open_l, open_r}. open = 그쪽이 방 끝이거나 옆 구간 천장이 더 낮음(위가 어둠)
func _ceiling_runs(cell: float) -> Array:
	var runs: Array = []
	var n := col_ceilings.size()
	var i := 0
	while i < n:
		var y := float(col_ceilings[i])
		var j := i
		while j + 1 < n and float(col_ceilings[j + 1]) == y:
			j += 1
		var open_l := i == 0 or float(col_ceilings[i - 1]) > y          # y 가 작을수록 높다
		var open_r := j == n - 1 or float(col_ceilings[j + 1]) > y
		runs.append({"y": y, "x0": i * cell, "x1": (j + 1) * cell, "open_l": open_l, "open_r": open_r})
		i = j + 1
	return runs


func _ceiling_at(x: float, cell: float) -> float:
	var c := clampi(int(floor(x / cell)), 0, col_ceilings.size() - 1)
	return float(col_ceilings[c])


func _gen_crate_group(cx: float, bottom_y: float) -> void:
	var w := _q(_rng.randf_range(112.0, 160.0))
	var h := _q(_rng.randf_range(104.0, 144.0))
	var big := Vector2(cx - w * 0.5, bottom_y - h)
	_add("crate", big, Vector2(w, h))
	var r := _rng.randf()
	if r < 0.55:
		var sw := _q(_rng.randf_range(64.0, w * 0.7))
		var sh := _q(_rng.randf_range(56.0, 80.0))
		var sx := big.x + _q(_rng.randf_range(0.0, w - sw))
		_add("crate", Vector2(sx, big.y - sh), Vector2(sw, sh))                       # 위에 얹힌 작은 상자
	elif r < 0.85:
		var sw := _q(_rng.randf_range(72.0, 120.0))
		var sh := _q(_rng.randf_range(56.0, h * 0.8))
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var sx := big.x + w + GRID * 2.0 if side > 0.0 else big.x - sw - GRID * 2.0
		_add("crate", Vector2(sx, bottom_y - sh), Vector2(sw, sh))                    # 옆에 붙은 낮은 상자


func _add(kind: String, pos: Vector2, size: Vector2) -> Dictionary:
	var it := {"kind": kind, "pos": pos.snapped(Vector2(GRID, GRID)), "size": size.snapped(Vector2(GRID, GRID))}
	items.append(it)
	return it


## 랩용: 새 항목을 pos 에 기본 크기로 추가하고 인덱스를 돌려준다
func add_item(kind: String, pos: Vector2) -> int:
	var size: Vector2 = DEFAULT_SIZE.get(kind, Vector2(64, 64))
	_add(kind, pos - size * 0.5, size)
	rebuild_visuals()
	return items.size() - 1


func remove_item(i: int) -> void:
	if i >= 0 and i < items.size():
		items.remove_at(i)
		rebuild_visuals()


## 항목의 사각형 (cable 은 걸린 구간 × 처짐)
func item_rect(i: int) -> Rect2:
	var it: Dictionary = items[i]
	return Rect2(it["pos"], it["size"].abs())


## 로컬 좌표 p 위의 항목 (나중에 그린 것 = 위에 있는 것 우선). 없으면 -1
func hit_item(p: Vector2) -> int:
	for i in range(items.size() - 1, -1, -1):
		if item_rect(i).grow(2.0).has_point(p):
			return i
	return -1


## items 를 다시 그린다 (랩에서 옮기거나 늘린 뒤)
func rebuild_visuals() -> void:
	if _shapes:
		_shapes.queue_free()
	_shapes = Node2D.new()
	_shapes.name = "Shapes"
	add_child(_shapes)
	for it in items:
		_draw_item(it)


func _draw_item(it: Dictionary) -> void:
	var pos: Vector2 = it["pos"]
	var size: Vector2 = it["size"]
	match it["kind"]:
		"pipe", "tray":
			_rect(pos, size, INK)
		"dark":
			_rect(pos, size, INK_DARK, false)
		"pillar":
			_rect(pos, size, INK)
			# 리벳 띠 3개 — 방 안 높이(천장~바닥)의 20/50/80% 지점. 기둥이 어둠까지 뻗어도 띠는 방 안에만
			var top := maxf(pos.y, ceiling_y)
			var bottom := minf(pos.y + size.y, floor_y)
			for k in range(3):
				var ry := _q(top + (bottom - top) * (0.2 + 0.3 * k))
				_rect(Vector2(pos.x - GRID, ry), Vector2(size.x + GRID * 2.0, 12.0), INK_DARK, false)
		"crate":
			_rect(pos, size, INK)
			var planks := 2 if size.y < 128.0 else 3
			for k in range(1, planks):
				_rect(pos + Vector2(RIM_W, _q(size.y * float(k) / planks)), Vector2(size.x - RIM_W * 2.0, RIM_W), INK_DARK, false)
			if size.x >= 64.0 and size.y >= 48.0:
				_rect(pos + Vector2(_q(size.x * 0.5) - RIM_W, RIM_W * 2.0), Vector2(RIM_W * 2.0, size.y - RIM_W * 4.0), INK_DARK, false)   # 세로 보강대
		"cable":
			_cable(pos, pos + Vector2(size.x, 0), size.y)
		"pipe_bracket", "utility_housing":
			_sprite(it["kind"], pos, size)


func _process(delta: float) -> void:
	# 패럴랙스 기준은 카메라의 실제 화면 중심(사격 흔들림 offset 제외). 마우스·시선 리드로 카메라가 내다보면 근경이 따라 밀리고,
	# 캐릭터가 걷기만 할 때는 카메라가 그만큼만 따라오므로 반응이 작다. 떨림 방지: 지수 평활 + 격자 한 칸 이상 벌어질 때만 이동.
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var ref := cam.get_screen_center_position() - cam.offset
	var want := -(ref - _center) * (PARALLAX - 1.0)
	_smooth = _smooth.lerp(want, 1.0 - exp(-SMOOTH_SPEED * delta))
	var d := _smooth - position
	if absf(d.x) >= GRID:
		position.x = snappedf(_smooth.x, GRID)
	if absf(d.y) >= GRID:
		position.y = snappedf(_smooth.y, GRID)


## 격자 스냅
func _q(v: float) -> float:
	return snappedf(v, GRID)


## 사각형 실루엣 = 잉크색 몸체(라이트 제외) + 네 변의 림 띠(라이트 받음, 정점 색 rg = 바깥 법선). rim=false 면 몸체만.
func _rect(pos: Vector2, size: Vector2, col: Color, rim := true) -> void:
	pos = pos.snapped(Vector2(GRID, GRID))
	size = size.snapped(Vector2(GRID, GRID))
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_quad(pos, size, col, Vector2.ZERO)
	if not rim or size.x < RIM_W * 3.0 or size.y < RIM_W * 3.0:
		return
	_quad(pos, Vector2(size.x, RIM_W), col, Vector2.UP)                                    # 윗변
	_quad(pos + Vector2(0, size.y - RIM_W), Vector2(size.x, RIM_W), col, Vector2.DOWN)     # 아랫변
	_quad(pos, Vector2(RIM_W, size.y), col, Vector2.LEFT)                                  # 왼변
	_quad(pos + Vector2(size.x - RIM_W, 0), Vector2(RIM_W, size.y), col, Vector2.RIGHT)    # 오른변


## normal == ZERO: 몸체(unshaded). 아니면 림 띠 — foreground_rim 셰이더가 정점 색에서 법선을 읽는다.
func _quad(pos: Vector2, size: Vector2, col: Color, normal: Vector2) -> void:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y)])
	if normal == Vector2.ZERO:
		p.color = col
		p.light_mask = 0
	else:
		p.material = _rim_mat
		var vc := Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, 0.0, 1.0)
		p.vertex_colors = PackedColorArray([vc, vc, vc, vc])
	_shapes.add_child(p)


## 그림 근경: 불투명 영역(region)을 pos·size 에 맞춰 늘린 Sprite2D. 라이트 제외 + 어두운 틴트 (앰비언트가 다시 곱해진다)
func _sprite(kind: String, pos: Vector2, size: Vector2) -> void:
	var info: Dictionary = SPRITES[kind]
	var sp := Sprite2D.new()
	sp.texture = load(info["path"])
	sp.centered = false
	sp.region_enabled = true
	sp.region_rect = info["region"]
	sp.position = pos
	sp.scale = size / info["region"].size
	sp.modulate = SPRITE_TINT
	sp.light_mask = 0
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shapes.add_child(sp)


## 처진 케이블: a→b 사이를 포물선으로, 점은 격자 스냅. 끝에는 작은 커넥터 블록.
func _cable(a: Vector2, b: Vector2, sag: float) -> void:
	var line := Line2D.new()
	line.width = 8.0
	line.default_color = INK
	line.light_mask = 0
	line.joint_mode = Line2D.LINE_JOINT_SHARP
	var n := 10
	for i in range(n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector2(0, sag * 4.0 * t * (1.0 - t))
		line.add_point(p.snapped(Vector2(GRID, GRID)))
	_shapes.add_child(line)
	_rect(a - Vector2(8, 0), Vector2(16, 20), INK_DARK, false)
	_rect(b - Vector2(8, 0), Vector2(16, 20), INK_DARK, false)


## [x0, x1] 안쪽(양끝 12% 여백)에서 avoid 목록과 keep 이상 떨어진 X 를 고른다 (방 가운데 스폰 지점도 피함). 못 찾으면 -1
func _pick_x_in(x0: float, x1: float, avoid: Array, keep: float) -> float:
	var span := x1 - x0
	for _try in range(24):
		var cx := _q(_rng.randf_range(x0 + span * 0.12, x1 - span * 0.12))
		var ok := absf(cx - room_width * 0.5) > keep
		for ax in avoid:
			if absf(cx - float(ax)) < keep:
				ok = false
				break
		if ok:
			return cx
	return -1.0
