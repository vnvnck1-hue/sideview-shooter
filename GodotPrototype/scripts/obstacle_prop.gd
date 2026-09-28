class_name ObstacleProp
extends Sprite2D
## 플레이 경로의 장애물. HitProp 과 같은 hit/is_solid_at 인터페이스를 쓰고, 완전히 부서지기 전까지는
## 이동·착지 충돌을 사각형 그대로 유지한다.
##
## 타격감 — 한 발마다 셋이 겹친다.
##   반응   맞은 쪽 반대로 밀렸다 돌아오는 스프링 흔들림 + 눌림(발 고정 스쿼시) + 기울기, 전신 백색 섬광
##   재질   나무 = 가시 파편·톱밥 / 콘크리트 = 자갈·분진 / 금속 = 불꽃·쇳소리
##   누적   맞은 자리에서 뻗는 픽셀 균열이 쌓여 "곧 부서진다"가 보인다
## 파괴 — 원화를 판자·덩어리 모양으로 잘라 제자리에서 터뜨리고(ChunkDebris), 먼지 구름이 한순간
## 몸통을 가렸다가 걷히면 잔해가 눌렸다 펴지며 자리를 잡는다. 히트스톱·카메라 흔들림은 Main 이 받는다.
## 가스통 — 구멍 난 자리에서 쏜 쪽으로 가스가 뿜어진다. 체력이 다하면 곧바로 터지지 않고
## 짧은 점화(FUSE) 동안 불꽃을 뿜으며 떨다가 폭발한다. 폭발에 휘말린 가스통은 더 짧게 끓어 연쇄가 "쾅-쾅" 으로 울린다.
const ROOT := "res://assets/props/obstacles/"
const SPECS := {
	"barricade": {"hp": -1.0, "name": "철제 방호벽", "hint": "W / ↑ 점프로 넘기", "mat": "metal", "mass": 3.0},
	"cable_reel": {"hp": -1.0, "name": "케이블 드럼", "hint": "W / ↑ 점프로 넘기", "mat": "metal", "mass": 2.4},
	"supply_crate": {"hp": 4.0, "name": "목재 보급 상자", "hint": "사격으로 파괴 / 점프로 넘기", "mat": "wood", "mass": 1.0,
		"shake": 5.5, "stop": 0.05},
	"rubble_block": {"hp": 8.0, "name": "균열 콘크리트", "hint": "균열을 향해 사격해 통로 확보", "mat": "stone", "mass": 2.0,
		"shake": 7.5, "stop": 0.07},
	"gas_cylinder": {"hp": 3.0, "name": "폭발 가스통", "hint": "사격하면 폭발 · 가까이 서지 마세요", "mat": "metal", "mass": 1.2},
}
const FUSE := 0.5                  # 직접 쏴서 터뜨릴 때 점화 시간
const CHAIN_FUSE := Vector2(0.14, 0.28)
const BLAST_RADIUS := 410.0
const FLASH_TIME := 0.12
# 스프링 (x 밀림 px · 눌림 비율 · 기울기 rad) — 무거울수록(mass) 덜 움직이고 빨리 선다
const SPRING_K := 900.0
const SPRING_DAMP := 20.0

var kind := "supply_crate"
var obstacle_id := ""
var hp := 4.0
var destroyed := false
var rect := Rect2()
var room: Node2D
var _home := Vector2.ZERO
var _rest := Vector2.ZERO          # 흔들림이 돌아오는 자리 (날아간 가스통 외피는 떨어진 곳)
var _mat: ShaderMaterial
var _img: Image
var _hits := 0
var _flash := 0.0
var _kick := 0.0
var _kick_v := 0.0
var _squash := 0.0
var _squash_v := 0.0
var _tilt := 0.0
var _tilt_v := 0.0
var _cracks: Array = []            # 로컬 좌표 4px 칸 목록 (PackedVector2Array)
var _crack_layer: Node2D
var _hole := Vector2.INF           # 가스통 구멍 (로컬)
var _hole_dir := Vector2.LEFT
var _leak_t := 0.0
var _fuse := -1.0
var _fuse_len := FUSE
var _hiss: AudioStreamPlayer2D
var _toss := false
var _toss_off := Vector2.ZERO
var _toss_v := Vector2.ZERO
var _toss_spin := 0.0
static var _hiss_stream: AudioStreamWAV
signal broken(prop: ObstacleProp)


func setup(owner_room: Node2D, spec: Dictionary, floor_line: float) -> void:
	room = owner_room
	kind = str(spec.get("kind", "supply_crate"))
	obstacle_id = str(spec.get("id", "%s_%s" % [kind, spec.x]))
	name = "Obstacle_" + obstacle_id
	z_index = 1 # Ahead of decorative furniture in the same Props layer.
	hp = float(SPECS[kind].hp)
	_home = Vector2(float(spec.x), floor_line + 2.0)
	position = _home
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = Lighting.shader_material("prop_surface")
	_mat.set_shader_parameter("rim_ambient_strength", 0.5)
	_mat.set_shader_parameter("dark_actor", 0.65)
	_mat.set_shader_parameter("actor_fill", 0.3)
	_mat.set_shader_parameter("hit_fx_preset", 1)
	material = _mat
	_crack_layer = Node2D.new()
	_crack_layer.name = "Cracks"
	_crack_layer.draw.connect(_draw_cracks)
	add_child(_crack_layer)
	_set_art(false)
	var state: Dictionary = room.obstacle_state.get(obstacle_id, {})
	if not state.is_empty():
		hp = float(state.hp)
		destroyed = bool(state.destroyed)
		_hits = int(state.get("hits", 0))
		if destroyed or (hp < 0 and _hits > 0):
			_set_art(true)
		if destroyed and state.has("rest_x"):
			position.x = float(state.rest_x)    # 폭발로 날아간 외피는 떨어진 자리에 그대로
		if not destroyed and kind == "gas_cylinder" and hp < float(SPECS[kind].hp):
			_hole = Vector2(0, -rect.size.y * 0.55)
	_rest = position
	set_process(not destroyed)


func material_id() -> String:
	return str(SPECS[kind].mat)


## 탄착 이펙트·소리 종류 (Bullet.Impact) — 나무만 PROP, 금속·콘크리트는 벽처럼 불꽃과 돌 소리가 난다
func impact_kind() -> int:
	return Bullet.Impact.PROP if material_id() == "wood" else Bullet.Impact.WALL


func _set_art(broken_art: bool) -> void:
	texture = Lighting.textured(ROOT + kind + ("_broken" if broken_art else "") + ".png")
	centered = false
	offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
	rect = Rect2(_home + offset, texture.get_size())
	var t: Texture2D = texture
	if t is CanvasTexture:
		t = (t as CanvasTexture).diffuse_texture
	_img = t.get_image() if t else null
	if _img and _img.is_compressed():
		_img.decompress()
	queue_redraw()


func _draw() -> void:
	var w := float(texture.get_width()) * 0.46
	draw_colored_polygon(PackedVector2Array([Vector2(-w, -2), Vector2(-w * 0.8, 3), Vector2(w * 0.8, 3), Vector2(w, -2)]), Color(0.015, 0.018, 0.03, 0.7))


func is_solid_at(point: Vector2) -> bool:
	return not destroyed and rect.has_point(point)


func _opaque_local(p: Vector2) -> bool:
	if _img == null:
		return true
	var px := Vector2i(p - offset)
	if px.x < 0 or px.y < 0 or px.x >= _img.get_width() or px.y >= _img.get_height():
		return false
	return _img.get_pixelv(px).a > 0.5


func hit(dir: float, _hit_y: float, point := Vector2.INF, power := 1.0) -> void:
	if destroyed:
		return
	_hits += 1
	var p := point if point.is_finite() else rect.get_center()
	p = Vector2(clampf(p.x, rect.position.x + 2, rect.end.x - 2), clampf(p.y, rect.position.y + 2, rect.end.y - 2))
	if dir == 0.0:
		dir = 1.0 if p.x >= _home.x else -1.0
	_react(dir, p, power)
	if hp < 0:
		if _hits == 1:
			_set_art(true)       # 찌그러진 외형으로 바뀐다 (파괴 불가)
	elif _fuse >= 0.0:
		_fuse = minf(_fuse, 0.06)  # 끓고 있는 가스통을 또 쏘면 바로 터진다
	else:
		hp = maxf(0.0, hp - maxf(power, 0.0))
		_add_crack(p - _home, dir, power)
		if kind == "gas_cylinder" and not _hole.is_finite():
			_hole = (p - _home).snapped(Vector2(4, 4))
			_hole_dir = Vector2(-dir, -0.25).normalized()
		if hp <= 0:
			if kind == "gas_cylinder":
				_ignite(randf_range(CHAIN_FUSE.x, CHAIN_FUSE.y) if power >= 4.0 else FUSE)
			else:
				_destroy(dir, p)
	_save()


## 한 발의 반응: 스프링 흔들림 + 섬광 + 재질 파편 + 소리
func _react(dir: float, p: Vector2, power: float) -> void:
	var mass: float = SPECS[kind].mass
	var pw := clampf(power, 1.0, 3.0)
	_kick_v += dir * 330.0 * pw / mass
	_squash_v -= 2.4 * pw / mass
	# 위를 맞으면 더 기운다 (바닥 중심이 축)
	var height_k := clampf((_home.y - p.y) / maxf(rect.size.y, 1.0), 0.2, 1.0)
	_tilt_v += dir * 2.2 * pw * height_k / mass
	_flash = FLASH_TIME
	_mat.set_shader_parameter("hit_uv", ((p - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE))
	_mat.set_shader_parameter("radius_px", 90.0)
	var out := Vector2(-dir, -0.35).normalized()
	match material_id():
		"wood":
			PropFx.hit_chips(room, p, out, "wood", power)
			Audio.play_at("prop_plank", p, -4.0)
		"stone":
			PropFx.hit_chips(room, p, out, "stone", power)
		_:
			var sb := SparkBurst.spawn(room, room.floor_y)
			sb.burst(p, int(6 + pw * 3), out, 0.75, Vector2(220, 720), Color(1.0, 0.95, 0.75), Color(1.0, 0.4, 0.1),
				Vector2(0.15, 0.4), 2200.0, 3.0, true)
			Audio.play_at("prop_metal_hit", p, 0.0, 1.25 if kind == "gas_cylinder" else 1.0)
	set_process(true)


## 맞은 자리에서 뻗는 균열. 4px 칸을 이어 그린다(원화와 같은 픽셀 밀도). 나무는 결을 따라 가로로,
## 콘크리트는 여러 갈래로, 가스통은 움푹 팬 자국만.
func _add_crack(local: Vector2, dir: float, power: float) -> void:
	var cells := PackedVector2Array()
	var start := local.snapped(Vector2(4, 4))
	var branches := 1 if material_id() == "wood" else (2 if material_id() == "stone" else 0)
	if kind == "gas_cylinder":
		for o in [Vector2.ZERO, Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0), Vector2(0, -4)]:
			cells.append(start + o)
	for b in range(branches + (1 if power >= 2.0 else 0)):
		var p := start
		var heading := Vector2(-dir, randf_range(-0.5, 0.5)) if material_id() == "wood" else Vector2.RIGHT.rotated(randf() * TAU)
		for step in range(randi_range(6, 11)):
			heading = heading.rotated(randf_range(-0.7, 0.7))
			p += Vector2(signf(heading.x) * 4.0 if absf(heading.x) > 0.35 else 0.0, signf(heading.y) * 4.0 if absf(heading.y) > 0.35 else 0.0)
			if not _opaque_local(p):
				break
			cells.append(p)
	if not cells.is_empty():
		_cracks.append(cells)
		_crack_layer.queue_redraw()


func _draw_cracks() -> void:
	var dark := Color(0.03, 0.02, 0.02, 1.0)
	# 갈라진 턱에 드러난 속살 — 나무는 생목 색, 콘크리트는 밝은 골재, 금속은 벗겨진 쇠
	var raw := {"wood": Color(0.95, 0.72, 0.42, 0.9), "stone": Color(0.86, 0.86, 0.84, 0.85)}.get(material_id(), Color(0.8, 0.8, 0.82, 0.8)) as Color
	raw = Color(raw.r * PropFx.LIT_BOOST, raw.g * PropFx.LIT_BOOST, raw.b * PropFx.LIT_BOOST, raw.a)
	for cells in _cracks:
		for c in cells:
			_crack_layer.draw_rect(Rect2(c + Vector2(0, 4), Vector2(4, 4)), raw)
		for c in cells:
			_crack_layer.draw_rect(Rect2(c, Vector2(4, 4)), dark)
	if _hole.is_finite() and not destroyed:
		_crack_layer.draw_rect(Rect2(_hole - Vector2(4, 4), Vector2(8, 8)), Color(0.02, 0.02, 0.02, 1))


func _save() -> void:
	var state := {"hp": hp, "destroyed": destroyed, "hits": _hits}
	if destroyed:
		state["rest_x"] = position.x if not _toss else _home.x + _toss_off.x
	room.obstacle_state[obstacle_id] = state


## 원화를 파괴 단위로 자른다: 목재 = 가로 판자 줄(한 줄을 2~3토막), 콘크리트·금속 = 불규칙 덩어리.
func _chunk_regions() -> Array:
	var out: Array = []
	var size := texture.get_size()
	var wood := material_id() == "wood"
	var rows := 4 if wood else int(clampf(size.y / 44.0, 2.0, 5.0))
	var y := 0.0
	for r in range(rows):
		var h := snappedf(size.y / rows, 4.0) if r < rows - 1 else size.y - y
		var x := 0.0
		var pieces := randi_range(2, 3) if wood else int(clampf(size.x / 44.0, 1.0, 4.0))
		for c in range(pieces):
			var w := snappedf(size.x / pieces * randf_range(0.8, 1.2), 4.0) if c < pieces - 1 else size.x - x
			w = minf(w, size.x - x)
			if w >= 8.0 and h >= 8.0:
				var reg := Rect2(x, y, w, h)
				if _coverage(reg) > 0.3:
					out.append(reg)
			x += w
		y += h
	return out


func _coverage(reg: Rect2) -> float:
	if _img == null:
		return 1.0
	var solid := 0
	var total := 0
	for yy in range(int(reg.position.y), int(reg.end.y), 4):
		for xx in range(int(reg.position.x), int(reg.end.x), 4):
			total += 1
			if _img.get_pixel(mini(xx, _img.get_width() - 1), mini(yy, _img.get_height() - 1)).a > 0.5:
				solid += 1
	return float(solid) / maxf(total, 1)


func _spawn_chunks(dir: float, from: Vector2, force: float) -> void:
	var tex := texture
	for reg in _chunk_regions():
		var world: Vector2 = rect.position + (reg as Rect2).get_center()
		var away: Vector2 = (world - from).normalized() if world.distance_to(from) > 4.0 else Vector2(dir, -1).normalized()
		var v: Vector2 = (away * 0.6 + Vector2(dir * 0.5, -0.9)).normalized() * randf_range(320, 640) * force
		var debris := ChunkDebris.new()
		debris.setup(tex, reg, world, v, _home.y)
		debris.spin *= 0.6
		room.stain_layer().add_child(debris)


func _destroy(dir: float, p: Vector2) -> void:
	destroyed = true
	_save()
	_spawn_chunks(dir, p, 1.0)
	PropFx.break_burst(room, rect, p, dir, material_id())
	_set_art(true)
	_after_break()
	# 잔해가 눌렸다 펴지며 자리를 잡는다 (쌓인 판자가 "털썩")
	_squash = 0.4
	_squash_v = 0.0
	_tilt = 0.0
	_tilt_v = 0.0
	if material_id() == "wood":
		Audio.play_at("prop_wood_break", p)
		Audio.play_at("prop_plank", p, 0.0, 0.8)
	else:
		Audio.play_at("prop_stone_break", p)
		Audio.play_at("prop_rubble", p)
	if room.has_signal("obstacle_broken"):
		room.obstacle_broken.emit(rect.get_center(), float(SPECS[kind].get("shake", 5.0)), float(SPECS[kind].get("stop", 0.05)))
	broken.emit(self)


func _after_break() -> void:
	_flash = 0.0
	_mat.set_shader_parameter("flash", 0.0)
	_cracks.clear()
	for child in get_children():
		if child != _crack_layer:
			child.queue_free() # Attached bullet marks must not float over the remains.
	_crack_layer.queue_redraw()
	_stop_hiss()


# ------------------------------------------------------------------ 가스통

func _ignite(fuse: float) -> void:
	_fuse = fuse
	_fuse_len = fuse
	if not _hole.is_finite():
		_hole = Vector2(0, -rect.size.y * 0.55)
	_start_hiss()
	_mat.set_shader_parameter("hit_fx_preset", 4)
	set_process(true)


func _explode() -> void:
	# Mark dead BEFORE radial damage: chained cylinders cannot recurse back.
	_fuse = -1.0
	destroyed = true
	var blast_center := rect.get_center()
	var dir := signf(-_hole_dir.x) if _hole_dir.x != 0.0 else 1.0
	_spawn_chunks(dir, blast_center, 1.7)
	_set_art(true)
	_after_break()
	_mat.set_shader_parameter("hit_fx_preset", 1)
	position = _home
	rotation = 0.0
	scale = Vector2.ONE
	# 빈 외피가 폭압에 튕겨 올라 한 바퀴 돌고 떨어진다
	_toss = true
	_toss_off = Vector2.ZERO
	_toss_v = Vector2(dir * randf_range(160, 320), -randf_range(900, 1150))
	_toss_spin = dir * randf_range(9.0, 13.0)
	_save()
	broken.emit(self)
	ObstacleExplosion.spawn(room, _home, blast_center, BLAST_RADIUS)
	room.obstacle_blast(blast_center, BLAST_RADIUS, self)
	set_process(true)


func _start_hiss() -> void:
	if _hiss == null:
		_hiss = AudioStreamPlayer2D.new()
		_hiss.stream = hiss_stream()
		_hiss.bus = "SFX"
		_hiss.max_distance = 1600.0
		_hiss.volume_db = -20.0
		add_child(_hiss)
		_hiss.play()


func _stop_hiss() -> void:
	if is_instance_valid(_hiss):
		_hiss.queue_free()
	_hiss = null


## 가스 새는 소리 — 대역 잡음 루프 (0.5초). 누출 중 낮게, 점화 중 크고 높게.
static func hiss_stream() -> AudioStreamWAV:
	if _hiss_stream != null:
		return _hiss_stream
	var rate := 22050
	var n := rate / 2
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4412
	var a := 0.0
	var b := 0.0
	for i in range(n):
		var x := rng.randf_range(-1, 1)
		a = lerpf(a, x, 0.55)
		b = lerpf(b, a, 0.25)
		data.encode_s16(i * 2, int(clampf((a - b) * 1.6, -1, 1) * 22000))   # 저역을 뺀 쉬익 소리
	_hiss_stream = AudioStreamWAV.new()
	_hiss_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_hiss_stream.mix_rate = rate
	_hiss_stream.data = data
	_hiss_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_hiss_stream.loop_end = n
	return _hiss_stream


func _exit_tree() -> void:
	# 점화 중에 방을 떠나면 그대로 터진 것으로 남긴다
	if _fuse >= 0.0 and not destroyed and is_instance_valid(room):
		destroyed = true
		_save()


# ------------------------------------------------------------------ 매 프레임

func _process(delta: float) -> void:
	var mass: float = SPECS[kind].mass
	var k := SPRING_K * (0.7 + mass * 0.3)
	_kick_v += (-k * _kick - SPRING_DAMP * _kick_v) * delta
	_kick += _kick_v * delta
	_squash_v += (-k * _squash - SPRING_DAMP * _squash_v) * delta
	_squash += _squash_v * delta
	_tilt_v += (-k * _tilt - SPRING_DAMP * _tilt_v) * delta
	_tilt += _tilt_v * delta
	_kick = clampf(_kick, -10.0, 10.0)
	_squash = clampf(_squash, -0.18, 0.45)
	_tilt = clampf(_tilt, -0.12, 0.12)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_mat.set_shader_parameter("flash", _flash / FLASH_TIME)
		_mat.set_shader_parameter("hit_fx_phase", 1.0 - _flash / FLASH_TIME)
	var jitter := Vector2.ZERO
	if not destroyed and kind == "gas_cylinder" and _hole.is_finite():
		_process_leak(delta)
		if _fuse >= 0.0:
			var fk := 1.0 - _fuse / maxf(_fuse_len, 0.001)
			jitter = Vector2(randf_range(-1, 1), randf_range(-1, 0)) * lerpf(2.0, 7.0, fk)
			_mat.set_shader_parameter("flash", clampf(0.35 + fk * 0.5 + sin(fk * 60.0) * 0.25, 0.0, 1.0))
			_mat.set_shader_parameter("hit_fx_phase", 0.18)
			_mat.set_shader_parameter("hit_uv", Vector2(0.5, 0.5))
			_mat.set_shader_parameter("radius_px", 400.0)
			if is_instance_valid(_hiss):
				_hiss.volume_db = lerpf(-8.0, -2.0, fk)
				_hiss.pitch_scale = lerpf(1.1, 1.9, fk)
			_fuse -= delta
			if _fuse <= 0.0:
				_explode()
				return
		else:
			jitter = Vector2(randf_range(-1, 1), 0) * 1.0
	if _toss:
		_toss_v.y += 2600.0 * delta
		_toss_off += _toss_v * delta
		rotation += _toss_spin * delta
		if _toss_off.y >= 0.0 and _toss_v.y > 0.0:
			_toss_off.y = 0.0
			_toss_v = Vector2(_toss_v.x * 0.45, -_toss_v.y * 0.28)
			_toss_spin *= 0.35
			Audio.play_at("prop_metal_hit", position, -3.0, 0.7)
			if absf(_toss_v.y) < 120.0:
				_toss = false
				rotation = 0.0
				position = _home + Vector2(_toss_off.x, 0)
				_rest = position
				_save()
		if _toss:
			position = _home + _toss_off
		return
	position = _rest + Vector2(snappedf(_kick, 2.0), 0) + jitter.snapped(Vector2(2, 2))
	scale = Vector2(1.0 - _squash * 0.5, 1.0 + _squash) if absf(_squash) > 0.002 else Vector2.ONE
	rotation = _tilt
	var settled := absf(_kick) + absf(_kick_v) * 0.01 + absf(_squash) + absf(_squash_v) * 0.01 + absf(_tilt) + absf(_tilt_v) * 0.01 < 0.01
	if settled and _flash <= 0.0 and (destroyed or not (kind == "gas_cylinder" and _hole.is_finite())):
		position = position.round()
		scale = Vector2.ONE
		rotation = 0.0
		set_process(false)


func _process_leak(delta: float) -> void:
	_leak_t += delta
	var burning := _fuse >= 0.0
	if _leak_t >= (0.03 if burning else 0.07):
		_leak_t = 0.0
		var dir := _hole_dir.rotated(randf_range(-0.1, 0.1))
		PropFx.gas_jet(room, position + _hole.rotated(rotation), dir, burning)
		if burning:
			WeaponLightPool.get_pool(room).pulse(get_instance_id(), position + _hole, Color(1, 0.55, 0.2), 380.0, 1.8, 0.1)
