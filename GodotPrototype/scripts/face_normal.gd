class_name FaceNormal
extends RefCounted
## 손으로 나눈 **면 맵**에서 노멀맵을 만든다 (2026-09-22).
##
## Tools/build_normal_maps.py 는 노멀을 원화의 **밝기 + 실루엣 베벨**에서 추론한다. 그래서 평평하게 칠한
## 상판·측면은 밝기 변화가 없어 전부 (0,0,1) — 정면을 보는 평면 — 으로 취급되고, 면 경계는 두 평면이 아니라
## 그 선 위의 얇은 융기로 해석된다. 광원을 옮겨도 면이 따로 반응하지 않는 이유가 이것이다.
##
## 여기서는 추론하지 않고 **면을 선언한다**. 프랍 PNG 옆에 같은 크기의 면 맵 PNG 를 하나 더 두고,
## 각 면을 아래 PALETTE 색으로 평평하게 칠하면 그 영역이 그 방향을 향하는 노멀이 된다.
##   res://assets/props/workshop_locker_game_scale.png        ← 원화
##   res://assets/faces/props/workshop_locker_game_scale.png  ← 면 맵 (칠한 것)
##   res://assets/normals/props/workshop_locker_game_scale.png ← 결과 (Lighting.textured 가 읽는 자리)
##
## 셰이더·런타임 코드는 건드릴 것이 없다 — prop_surface/lit_surface 가 이미 NORMAL 을 lit_light() 에 넘기므로,
## 노멀이 면별로 갈라지는 순간 dot(N, L) 이 매 프레임 광원 방향을 따라간다. light_mask 로 면을 광원에 배정하는
## 방식과 달리 **광원이 움직여도 따라오고**, 45° 광원에 중간값으로 반응하며, 캔버스 아이템 수도 늘지 않는다
## (Lighting 의 아이템당 라이트 15개 한도 참고).
##
## **딱딱한 면과 부드러운 면.** 사물함·작업대처럼 모서리가 있는 것은 칠한 대로 딱 갈라져야 하지만,
## 소파처럼 경계가 없는 것은 그렇게 하면 있지도 않은 모서리가 생겨 어색해진다. 그래서 soft(번짐 폭)를 두었다.
## soft > 0 이면 **칠한 면을 코어로 보고 노멀 필드를 번지게** 해서 면과 면 사이가 그라데이션으로 넘어간다.
## 부드러운 물체는 각 면을 **최소한의 면적만** 칠하고 soft 를 키우는 것이 요령이다.
##
## 면을 나누고 눈으로 확인하는 곳: scripts/face_lab.gd (로비 → "면 라이팅 랩").
## 확정한 뒤 실제 자산으로 굽는 곳: godot --headless --script res://tools/bake_face_normals.gd

const FACE_DIR := "res://assets/faces/"
const NORMAL_DIR := "res://assets/normals/"
const ASSET_DIR := "res://assets/"
const TUNING_PATH := "res://faces/tuning.json"       # 앰비언스·그림자 랩과 같은 규약 (res:// 아래 JSON)

## 면 맵에 칠하는 색 → 그 면이 향하는 방향 (화면 좌표: x 오른쪽 +, y **위** +).
## 순색이라 Aseprite 팔레트에 올려 두고 페인트통으로 부으면 된다. 더 필요하면 여기에 줄을 추가하면 된다.
const PALETTE := [
	{"key": "front",  "rgb": Vector3(0, 0, 255),     "dir": Vector2(0, 0),               "name": "정면"},
	{"key": "top",    "rgb": Vector3(255, 0, 0),     "dir": Vector2(0, 1),               "name": "상판"},
	{"key": "left",   "rgb": Vector3(0, 255, 0),     "dir": Vector2(-1, 0),              "name": "좌측면"},
	{"key": "right",  "rgb": Vector3(255, 255, 0),   "dir": Vector2(1, 0),               "name": "우측면"},
	{"key": "bottom", "rgb": Vector3(255, 0, 255),   "dir": Vector2(0, -1),              "name": "밑면"},
	{"key": "bevel_tl", "rgb": Vector3(0, 255, 255), "dir": Vector2(-0.7071, 0.7071),    "name": "좌상 경사"},
	{"key": "bevel_tr", "rgb": Vector3(255, 255, 255), "dir": Vector2(0.7071, 0.7071),   "name": "우상 경사"},
]

## tilt: 면이 정면에서 기울어지는 각도(도). 45 면 상판 노멀이 (0, 0.707, 0.707).
##       올리면 면끼리 명암차가 커지고(입체감↑) 대신 면이 광원을 등지는 각도도 빨리 와서 더 자주 어두워진다.
## detail: 기존 자동 노멀(밝기·베벨에서 뽑은 것)의 xy 를 이만큼 섞는다. 0 이면 완전히 평평한 면,
##       0.3~0.4 면 면 방향은 유지한 채 리벳·홈 같은 표면 요철이 살아남는다.
## soft: 면과 면 사이를 잇는 **번짐 폭(px)**. 0 이면 칠한 대로 딱 갈라진다(각진 상자).
##       0 보다 크면 칠한 면을 코어로 보고 노멀을 주변으로 번지게 해 경계가 그라데이션이 된다(소파·쿠션).
##       번짐 사거리 밖(가까이에 칠한 면이 없는 곳)은 기존 자동 노멀로 자연스럽게 돌아간다.
##
## **자산마다 다르다.** 각진 것과 둥근 것에 같은 값을 쓰면 안 된다. 수치는 자산별로 덮어쓸 수 있다:
##   faces/tuning.json → {"tilt": 45, "detail": 0.35, "soft": 0,
##                        "assets": {"props/workshop_armchair_game_scale.png": {"tilt": 34, "detail": 0.45, "soft": 22}}}
## 랩에서 Q/A·W/S·1/2 는 **고른 자산의** 값을 바꾸고 Ctrl+S 가 그 자산 항목으로 저장한다 (Shift+Ctrl+S 는 기본값).
const DEFAULT := {"tilt": 45.0, "detail": 0.35, "soft": 0.0}
## 번짐 가중치가 이만큼이면 면 노멀을 100% 신뢰한다. 그 아래는 자동 노멀 쪽으로 섞여 들어간다 (번짐의 바깥 가장자리).
const SOFT_COVER := 0.25

static var _tuning := {}
static var _assets := {}                  # 자산 상대경로 → {"tilt", "detail", "soft"}


# ----------------------------------------------------------------------------- 경로

## res://assets/props/foo.png → res://assets/faces/props/foo.png
static func face_path(diffuse_path: String) -> String:
	return FACE_DIR + diffuse_path.trim_prefix(ASSET_DIR)


## res://assets/props/foo.png → res://assets/normals/props/foo.png
static func normal_path(diffuse_path: String) -> String:
	return NORMAL_DIR + diffuse_path.trim_prefix(ASSET_DIR)


static func has_face_map(diffuse_path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(face_path(diffuse_path)))


## PNG 를 **임포트를 거치지 않고** 원본 파일에서 직접 읽는다.
## 랩에서 그림을 고치고 R 을 누르면 바로 반영되게 하려면 이 경로여야 한다 — load() 는 에디터가 다시
## 임포트할 때까지 옛 파일을 준다. 패킹된 빌드에서는 원본 파일이 없으므로 load() 로 되돌아간다.
static func load_png(res_path: String) -> Image:
	var abs := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs):
		var img := Image.load_from_file(abs)
		if img:
			img.convert(Image.FORMAT_RGBA8)
			return img
	if ResourceLoader.exists(res_path):
		var tex: Texture2D = load(res_path)
		if tex:
			var i := tex.get_image()
			if i:
				i.convert(Image.FORMAT_RGBA8)
				return i
	return null


# ----------------------------------------------------------------------------- 변환

## 면 맵 → 노멀맵 이미지.
##   diffuse : 원화 (알파로 실루엣 밖을 판단한다)
##   faces   : 면 맵. **알파가 있는 픽셀만** 칠한 것으로 친다 — 비워 둔 곳은 auto 를 그대로 쓰므로
##             프랍 전체를 다 칠하지 않고 큰 면 두세 개만 칠해도 된다.
##   auto    : 지금 쓰고 있는 자동 노멀 (없으면 평평한 것으로 친다)
##   soft    : 0 이면 칠한 대로 딱 갈라지고, 크면 칠한 면이 코어가 되어 주변으로 번진다 (아래 2단계)
static func bake_image(diffuse: Image, faces: Image, auto: Image, tilt_deg := NAN, detail := NAN, soft := NAN) -> Image:
	var tilt: float = tuning()["tilt"] if is_nan(tilt_deg) else tilt_deg
	var mix: float = tuning()["detail"] if is_nan(detail) else detail
	var spread: float = tuning()["soft"] if is_nan(soft) else soft
	var w := diffuse.get_width()
	var h := diffuse.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.5, 0.5, 1.0, 1.0))

	var a := deg_to_rad(clampf(tilt, 0.0, 85.0))
	var sn := sin(a)
	var cs := cos(a)
	# 팔레트 색 → 면 노멀 (미리 계산)
	var face_n := []
	for p in PALETTE:
		var d: Vector2 = p["dir"]
		face_n.append(Vector3(0, 0, 1) if d.length() < 0.001 else Vector3(d.normalized().x * sn, d.normalized().y * sn, cs))

	var fw := faces.get_width()
	var fh := faces.get_height()
	var aw := auto.get_width() if auto else 0
	var ah := auto.get_height() if auto else 0
	var lut := {}                      # 칠한 색(24bit) → 팔레트 인덱스. 면 맵은 색 수가 몇 개뿐이라 이 캐시가 거의 다 맞는다

	# 1) 칠한 면 → 노멀 필드 (nx, ny, nz, 가중치). 안 칠한 곳은 가중치 0 이다.
	var field := PackedFloat32Array()
	field.resize(w * h * 4)
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in range(h):
		for x in range(w):
			if diffuse.get_pixel(x, y).a < 0.5:
				continue               # 실루엣 밖 — 평평하게 둔다
			var idx := y * w + x
			solid[idx] = 1
			if x >= fw or y >= fh:
				continue
			var fc := faces.get_pixel(x, y)
			if fc.a < 0.5:
				continue
			var key := (int(round(fc.r * 255.0)) << 16) | (int(round(fc.g * 255.0)) << 8) | int(round(fc.b * 255.0))
			var pi: int = lut[key] if lut.has(key) else _nearest(fc)
			lut[key] = pi
			var n: Vector3 = face_n[pi]
			field[idx * 4] = n.x
			field[idx * 4 + 1] = n.y
			field[idx * 4 + 2] = n.z
			field[idx * 4 + 3] = 1.0

	# 2) 부드러운 면: 노멀 **필드 자체를** 번지게 한다 (정규화 컨볼루션 — 가중치도 같은 커널로 흐린 뒤 나눈다).
	#    면과 면 사이가 선이 아니라 그라데이션으로 넘어가고, 아무것도 칠하지 않은 곳은 가중치가 0 으로
	#    떨어져 자동 노멀로 되돌아간다. spread 가 0 이면 이 단계를 건너뛰어 칠한 대로 딱 갈린다.
	var softened := spread > 0.5
	if softened:
		var r := maxi(1, int(round(spread / 3.0)))
		for _i in range(3):            # 박스 블러 3회 ≈ 가우시안
			field = _blur4(field, w, h, r)

	# 3) 합치기
	for y in range(h):
		for x in range(w):
			var idx := y * w + x
			if solid[idx] == 0:
				continue
			var an := Vector3(0, 0, 1)
			if auto and x < aw and y < ah:
				var ac := auto.get_pixel(x, y)
				an = Vector3(ac.r * 2.0 - 1.0, ac.g * 2.0 - 1.0, ac.b * 2.0 - 1.0)
				if an.length_squared() > 1e-6:
					an = an.normalized()
			var n := an
			var wt := field[idx * 4 + 3]
			if wt > 0.0001:
				var fn := Vector3(field[idx * 4], field[idx * 4 + 1], field[idx * 4 + 2]) / wt
				if fn.length_squared() > 1e-6:
					fn = fn.normalized()
					n = an.lerp(fn, clampf(wt / SOFT_COVER, 0.0, 1.0)) if softened else fn
			if mix > 0.0:
				n = n + Vector3(an.x, an.y, 0.0) * mix
			if n.length_squared() < 1e-6:
				n = Vector3(0, 0, 1)
			n = n.normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return out


## 4채널 필드의 분리형 박스 블러 (가로 → 세로). 가중치 채널도 같은 커널로 흐르므로 커널 정규화만 하면 된다.
static func _blur4(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var inv := 1.0 / float(2 * r + 1)
	var tmp := PackedFloat32Array()
	tmp.resize(src.size())
	for y in range(h):
		var row := y * w * 4
		var s0 := 0.0
		var s1 := 0.0
		var s2 := 0.0
		var s3 := 0.0
		for x in range(mini(r + 1, w)):
			var i := row + x * 4
			s0 += src[i]
			s1 += src[i + 1]
			s2 += src[i + 2]
			s3 += src[i + 3]
		for x in range(w):
			var o := row + x * 4
			tmp[o] = s0 * inv
			tmp[o + 1] = s1 * inv
			tmp[o + 2] = s2 * inv
			tmp[o + 3] = s3 * inv
			var add := x + r + 1
			if add < w:
				var i := row + add * 4
				s0 += src[i]
				s1 += src[i + 1]
				s2 += src[i + 2]
				s3 += src[i + 3]
			var rem := x - r
			if rem >= 0:
				var i := row + rem * 4
				s0 -= src[i]
				s1 -= src[i + 1]
				s2 -= src[i + 2]
				s3 -= src[i + 3]
	var out := PackedFloat32Array()
	out.resize(src.size())
	var stride := w * 4
	for x in range(w):
		var col := x * 4
		var s0 := 0.0
		var s1 := 0.0
		var s2 := 0.0
		var s3 := 0.0
		for y in range(mini(r + 1, h)):
			var i := y * stride + col
			s0 += tmp[i]
			s1 += tmp[i + 1]
			s2 += tmp[i + 2]
			s3 += tmp[i + 3]
		for y in range(h):
			var o := y * stride + col
			out[o] = s0 * inv
			out[o + 1] = s1 * inv
			out[o + 2] = s2 * inv
			out[o + 3] = s3 * inv
			var add := y + r + 1
			if add < h:
				var i := add * stride + col
				s0 += tmp[i]
				s1 += tmp[i + 1]
				s2 += tmp[i + 2]
				s3 += tmp[i + 3]
			var rem := y - r
			if rem >= 0:
				var i := rem * stride + col
				s0 -= tmp[i]
				s1 -= tmp[i + 1]
				s2 -= tmp[i + 2]
				s3 -= tmp[i + 3]
	return out


## 칠한 색에 가장 가까운 팔레트 항목. 정확히 순색으로 칠하지 않아도(안티에일리어싱 없이 살짝 어긋나도) 붙잡힌다.
static func _nearest(c: Color) -> int:
	var best := 0
	var best_d := INF
	var v := Vector3(c.r * 255.0, c.g * 255.0, c.b * 255.0)
	for i in range(PALETTE.size()):
		var d: float = v.distance_squared_to(PALETTE[i]["rgb"])
		if d < best_d:
			best_d = d
			best = i
	return best


## 자산 경로 하나를 통째로 구워 ImageTexture 로. 면 맵이 없으면 null.
static func build(diffuse_path: String, tilt_deg := NAN, detail := NAN, soft := NAN) -> ImageTexture:
	var img := bake_for(diffuse_path, tilt_deg, detail, soft)
	return ImageTexture.create_from_image(img) if img else null


static func bake_for(diffuse_path: String, tilt_deg := NAN, detail := NAN, soft := NAN) -> Image:
	var faces := load_png(face_path(diffuse_path))
	if faces == null:
		return null
	var diffuse := load_png(diffuse_path)
	if diffuse == null:
		return null
	var t := tuning_for(diffuse_path)
	return bake_image(diffuse, faces, load_png(normal_path(diffuse_path)),
		t["tilt"] if is_nan(tilt_deg) else tilt_deg,
		t["detail"] if is_nan(detail) else detail,
		t["soft"] if is_nan(soft) else soft)


# ----------------------------------------------------------------------------- 템플릿

## 면 맵 시작본: 실루엣 전체를 "정면"(파랑)으로 채운 PNG. 여기에 경계선을 긋고 페인트통으로 부으면 된다.
## 원화와 같은 크기·같은 알파라 Aseprite 에서 원화 위에 레이어로 올리면 그대로 겹친다.
static func template(diffuse: Image) -> Image:
	var w := diffuse.get_width()
	var h := diffuse.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var front := Color8(0, 0, 255, 255)
	for y in range(h):
		for x in range(w):
			if diffuse.get_pixel(x, y).a >= 0.5:
				out.set_pixel(x, y, front)
	return out


## 선택한 자산의 면 맵 템플릿을 만들어 저장한다. 이미 있으면 overwrite 가 false 일 때 건드리지 않는다.
## 성공하면 저장한 res:// 경로, 실패·생략이면 "".
static func write_template(diffuse_path: String, overwrite := false) -> String:
	var dst := face_path(diffuse_path)
	var abs := ProjectSettings.globalize_path(dst)
	if FileAccess.file_exists(abs) and not overwrite:
		return ""
	var diffuse := load_png(diffuse_path)
	if diffuse == null:
		return ""
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	if template(diffuse).save_png(abs) != OK:
		return ""
	return dst


# ----------------------------------------------------------------------------- 수치

## 기본 수치 (자산별 덮어쓰기가 없을 때)
static func tuning() -> Dictionary:
	if _tuning.is_empty():
		_tuning = DEFAULT.duplicate()
		var abs := ProjectSettings.globalize_path(TUNING_PATH)
		if FileAccess.file_exists(abs):
			var f := FileAccess.open(abs, FileAccess.READ)
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in DEFAULT:
					if parsed.has(k):
						_tuning[k] = float(parsed[k])
				var per = parsed.get("assets")
				if per is Dictionary:
					for rel in per:
						if per[rel] is Dictionary:
							_assets[String(rel)] = per[rel]
	return _tuning


## 이 자산에 쓸 수치 — 자산별 항목이 있으면 그것, 없으면 기본값
static func tuning_for(diffuse_path: String) -> Dictionary:
	var out := tuning().duplicate()
	var rel := diffuse_path.trim_prefix(ASSET_DIR)
	if _assets.has(rel):
		for k in DEFAULT:
			if _assets[rel].has(k):
				out[k] = float(_assets[rel][k])
	return out


static func has_override(diffuse_path: String) -> bool:
	tuning()
	return _assets.has(diffuse_path.trim_prefix(ASSET_DIR))


## diffuse_path 를 주면 그 자산 항목으로, 비우면 기본값으로 저장한다.
static func save_tuning(tilt: float, detail: float, soft: float, diffuse_path := "") -> bool:
	tuning()                                   # 아직 안 읽었으면 먼저 읽는다 (다른 자산 항목이 날아가지 않게)
	if diffuse_path == "":
		_tuning = {"tilt": tilt, "detail": detail, "soft": soft}
	else:
		_assets[diffuse_path.trim_prefix(ASSET_DIR)] = {"tilt": tilt, "detail": detail, "soft": soft}
	var data := _tuning.duplicate()
	data["assets"] = _assets
	var abs := ProjectSettings.globalize_path(TUNING_PATH)
	DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
	var f := FileAccess.open(abs, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true
