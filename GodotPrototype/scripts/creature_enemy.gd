class_name CreatureEnemy
extends Node2D
## Selected 01/04/05 creatures. Shared clip contract, distinct ecology and attacks.
signal died(pos: Vector2, power: float)
signal impacted(pos: Vector2, power: float)
const BASE := "res://assets/character/Creatures/"
const IDS := {"ceiling_bell":"CeilingBell", "ring_spine":"RingSpine", "seam_ambusher":"SeamAmbusher"}
const SCALE := 4.0
const ROLL_SPEED := 900.0
const ROLL_ACCEL := 4800.0
static var _cache: Dictionary = {}
var species := "ring_spine"
var room: Node2D
var facing := -1
var min_x := 150.0
var max_x := 2000.0
var floor_y := 486.0
var hp := 8
var state := "idle"
var clip := "idle"
var frame_index := 0
var frame_elapsed := 0.0
var velocity_x := 0.0
var roll_angle := 0.0
var roll_distance := 0.0
var roll_radius := 112.0
var weapon_hitstop_left := 0.0
var arc_slow_left := 0.0
var attack_count := 0
var damage_count := 0
var ai_enabled := true
var _body: Sprite2D
var _mat: ShaderMaterial
var _data: Dictionary
var _textures: Array
var _masks: Array
var _clips: Dictionary = {}
var _pivot := Vector2.ZERO
var _frame := 0
var _cooldown := 1.0
var _windup := 0.0
var _roll_time := 0.0
var _trail_time := 0.0
var _dead_time := 0.0
var _flash := 0.0
var _attack_hit := false
var _clip_finished := false
var _spin_center := Vector2.ZERO
var _spin_local := Vector2.ZERO
var _hurt_return := "idle"

func setup(host: Node2D, kind: String, at: Vector2, face_dir: int, bounds: Vector2) -> void:
	room = host
	species = kind
	position = at
	facing = face_dir
	min_x = bounds.x
	max_x = bounds.y
	floor_y = float(host.floor_y) + 2.0
	hp = 10 if species == "ceiling_bell" else (8 if species == "ring_spine" else 9)
	_cooldown = randf_range(0.7, 1.2)

func _ready() -> void:
	add_to_group("readability_actors")
	var id: String = IDS[species]
	if not _cache.has(id):
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + id + "/animation.json"))
		var tex: Array = []
		var masks: Array = []
		for fr in meta.frames:
			var file: String = BASE + id + "/" + str(fr.clip) + "/" + str(fr.key) + ".png"
			tex.append(Lighting.textured(file))
			var image: Image = (load(file) as Texture2D).get_image()
			if image.is_compressed():
				image.decompress()
			image.resize(int(meta.cell[0]), int(meta.cell[1]), Image.INTERPOLATE_NEAREST)
			masks.append(image)
		_cache[id] = {"data":meta, "textures":tex, "masks":masks}
	var cached: Dictionary = _cache[id]
	_data = cached.data
	_textures = cached.textures
	_masks = cached.masks
	_pivot = Vector2(_data.pivot[0], _data.pivot[1]) * SCALE
	for entry in _data.clips:
		_clips[str(entry.name)] = entry
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.centered = false
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = Lighting.character_material("prop_surface", 1.0)
	_mat.set_shader_parameter("grid", Vector2.ONE)
	_body.material = _mat
	add_child(_body)
	var b: Array = _data.frames[0].bounds
	_spin_center = Vector2((b[0] + b[2]) * 0.5, (b[1] + b[3]) * 0.5) * SCALE
	_spin_local = _spin_center - _pivot
	roll_radius = maxf(20.0, (float(b[3]) - float(b[1])) * SCALE * 0.5)
	_play("dormant" if species == "seam_ambusher" else "idle")

func _play(name: String) -> void:
	clip = name
	frame_index = 0
	frame_elapsed = 0.0
	_clip_finished = false
	_apply_frame()

func _apply_frame() -> void:
	_frame = int(_clips[clip].from) + frame_index
	_body.texture = _textures[_frame]
	_body.position = Vector2.ZERO
	_body.rotation = 0.0
	_body.offset = -_pivot
	_body.scale = Vector2(float(facing) if species != "ceiling_bell" else 1.0, 1.0)
	if state == "roll":
		# One canonical texture rotates with distance. Never also play the baked roll strip.
		_frame = 0
		_body.texture = _textures[0]
		_body.position = _spin_local
		_body.offset = -_spin_center
		_body.rotation = roll_angle
		_body.scale = Vector2.ONE

func _process(delta: float) -> void:
	if not is_instance_valid(room):
		return
	_flash = maxf(0.0, _flash - delta * 12.0)
	_mat.set_shader_parameter("flash", _flash)
	if is_dead():
		_advance(delta)
		_dead_time += delta
		if _dead_time > 8.0:
			modulate.a = maxf(0.0, 1.0 - (_dead_time - 8.0))
		if _dead_time >= 9.0:
			queue_free()
		return
	if weapon_hitstop_left > 0.0:
		weapon_hitstop_left = maxf(0.0, weapon_hitstop_left - delta)
		return
	if arc_slow_left > 0.0:
		arc_slow_left = maxf(0.0, arc_slow_left - delta)
		delta *= 0.42
	_cooldown = maxf(0.0, _cooldown - delta)
	if state == "roll":
		_roll(delta)
	elif state == "windup":
		_windup -= delta
		if _windup <= 0.0:
			state = "roll"
			_roll_time = 0.0
			velocity_x = 0.0
			_play("roll")
	else:
		_advance(delta)
		if state == "attack":
			_try_damage()
		if state == "idle" and ai_enabled and _cooldown <= 0.0:
			_decide()

func _advance(delta: float) -> void:
	if _clip_finished:
		return
	frame_elapsed += delta
	# Carry overshoot, and emit every crossed frame event (also at 20 fps).
	for safety in range(24):
		var duration := float(_data.frames[int(_clips[clip].from) + frame_index].durationMs) / 1000.0
		if frame_elapsed < duration:
			break
		frame_elapsed -= duration
		frame_index += 1
		var count := int(_clips[clip].to) - int(_clips[clip].from) + 1
		if frame_index >= count:
			if bool(_clips[clip].loop):
				frame_index = 0
			else:
				frame_index = count - 1
				_clip_finished = true
				_finish_clip()
				break
		_apply_frame()
		if state == "attack" and _damage_active():
			if frame_index == 2:
				_attack_accent()
			_try_damage()

func _finish_clip() -> void:
	if is_dead():
		return
	if state == "hurt":
		state = "idle"
		_cooldown = 0.35
		_play(_hurt_return)
		return
	var next := {"anticipate":"strike", "strike":"hold", "retract":"close", "emerge":"snap", "snap":"hold", "release":"withdraw", "uncoil":"lash", "lash":"recoil", "recoil":"coil"}
	if next.has(clip):
		_play(next[clip])
	elif clip in ["close", "withdraw", "coil"]:
		state = "idle"
		_cooldown = 1.5
		_play("dormant" if species == "seam_ambusher" else "idle")

func _decide() -> void:
	var target := _target()
	if target == null or not _same_section(target):
		return
	var dx := target.position.x - position.x
	if species == "ring_spine":
		if absf(dx) < 1200.0:
			facing = 1 if dx >= 0.0 else -1
			state = "windup"
			_attack_hit = false
			_windup = 0.28
			_play("idle")
			Audio.play_at("crawler_aggro", hit_center(), -9.0, 1.2)
			CreatureImpactFx.accent(get_parent(), hit_center(), Vector2(facing, 0), "charge", roll_radius)
	elif species == "ceiling_bell":
		if absf(dx) < 170.0 and _visible_target(target):
			force_attack()
	elif dx * facing > 0.0 and absf(dx) < 470.0 and _visible_target(target):
		force_attack()

func force_attack() -> void:
	if is_dead():
		return
	state = "attack"
	velocity_x = 0.0
	_attack_hit = false
	attack_count += 1
	Audio.play_at("crawler_aggro", hit_center(), -8.0, 0.9 if species == "ceiling_bell" else 1.1)
	_play("anticipate" if species == "ceiling_bell" else ("uncoil" if species == "ring_spine" else "emerge"))

func _roll(delta: float) -> void:
	_roll_time += delta
	velocity_x = move_toward(velocity_x, facing * ROLL_SPEED, ROLL_ACCEL * delta)
	var old := position.x
	var next := clampf(old + velocity_x * delta, min_x + roll_radius, max_x - roll_radius)
	if room.has_method("obstacle_move_x"):
		next = float(room.obstacle_move_x(old, next, floor_y, roll_radius * 1.8, roll_radius * 0.8))
	position.x = next
	var travel := next - old
	roll_angle += travel / roll_radius
	roll_distance += travel
	_apply_frame()
	_trail_time -= delta
	if absf(velocity_x) > 300.0 and absf(travel) > 0.1 and _trail_time <= 0.0:
		_trail_time = 0.035
		CreatureImpactFx.afterimage(get_parent(), _body)
	_try_contact()
	var target := _target()
	if target and _roll_time > 0.20 and absf(target.position.x - position.x) < 285.0:
		facing = 1 if target.position.x >= position.x else -1
		force_attack()
	elif absf(travel) < 0.01 or _roll_time > 2.0:
		state = "idle"
		velocity_x = 0.0
		_cooldown = 0.55
		_play("idle")

func _damage_active() -> bool:
	return (clip in ["strike", "snap", "lash"] and frame_index >= 2) or clip == "hold"

func _try_damage() -> void:
	# Hold is deliberately finite even though the asset can loop for authoring.
	if clip == "hold" and frame_index >= 3:
		_play("retract" if species == "ceiling_bell" else "release")
		return
	if _attack_hit or not _damage_active():
		return
	var target := _target()
	if target == null or not _visible_target(target):
		return
	if attack_rect().intersects(_target_rect(target)):
		_deal_hit(target)

func _try_contact() -> void:
	if _attack_hit:
		return
	var target := _target()
	if target and _visible_target(target) and hit_rect().intersects(_target_rect(target)):
		_deal_hit(target)

func _deal_hit(target: Node2D) -> void:
	if target.has_method("is_rolling") and target.is_rolling():
		return
	_attack_hit = true
	damage_count += 1
	var point := _target_rect(target).get_center()
	var dir := signf(target.position.x - position.x)
	if target.has_method("receive_monster_hit"):
		target.receive_monster_hit(point, dir, 18.0)
	else:
		room.player_hit.emit(point, dir)
	impacted.emit(point, 1.0)
	CreatureImpactFx.accent(get_parent(), point, Vector2(dir, 0), "impact", 75.0)

func attack_rect() -> Rect2:
	var box := hit_rect()
	if species == "ceiling_bell":
		return Rect2(Vector2(box.get_center().x - 58, box.end.y - 70), Vector2(116, 82))
	var x := box.end.x - 100.0 if facing > 0 else box.position.x
	return Rect2(Vector2(x, box.position.y + box.size.y * 0.18), Vector2(100, box.size.y * 0.72))

func _attack_accent() -> void:
	var tip := attack_rect().get_center()
	CreatureImpactFx.accent(get_parent(), tip, Vector2.DOWN if species == "ceiling_bell" else Vector2(facing, 0), "strike", 100.0)
	CreatureImpactFx.afterimage(get_parent(), _body)
	Audio.play_at("crawler_hurt", tip, -10.0, 1.35)
	impacted.emit(tip, 0.4)

func _target() -> Node2D:
	if room and is_instance_valid(room.get("bugbot_battle")):
		return room.bugbot_battle.monster_target(position)
	return room.get("player") if room else null

func _same_section(target: Node2D) -> bool:
	var span: Vector2 = room.section_of(position.x)
	return target.position.x >= span.x and target.position.x <= span.y

func _visible_target(target: Node2D) -> bool:
	if not _same_section(target):
		return false
	var end := _target_rect(target).get_center()
	return room.clip_shot(hit_center(), end).distance_to(end) < 5.0

func _target_rect(target: Node2D) -> Rect2:
	if target.has_method("hit_rect"):
		return target.hit_rect()
	var air: float = target.air_height() if target.has_method("air_height") else 0.0
	return Rect2(target.position + Vector2(-48, -250 - air), Vector2(96, 245))

func hit_rect() -> Rect2:
	var b: Array = _data.frames[_frame].bounds
	var p := Vector2(b[0], b[1]) * SCALE + _body.offset
	var q := Vector2(b[2], b[3]) * SCALE + _body.offset
	var box := Rect2(_body.to_global(p), Vector2.ZERO)
	for v in [Vector2(q.x, p.y), q, Vector2(p.x, q.y)]:
		box = box.expand(_body.to_global(v))
	return box

func is_hit(point: Vector2) -> bool:
	if is_dead() or not hit_rect().has_point(point):
		return false
	var p := (_body.to_local(point) - _body.offset) / SCALE
	var image: Image = _masks[_frame]
	return p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height() and image.get_pixel(int(p.x), int(p.y)).a > 0.5

func ray_hit_t(a: Vector2, b: Vector2) -> float:
	var entry := WeaponProjectile._rect_t(a, b, hit_rect())
	if entry < 0.0:
		return -1.0
	var count := maxi(1, int(ceil(a.distance_to(b) / 2.0)))
	for i in range(maxi(0, int(entry * count)), count + 1):
		var t := float(i) / count
		if is_hit(a.lerp(b, t)):
			return t
	return -1.0

func hit_center() -> Vector2:
	# Aim at flesh rather than the empty center of the ring.
	var fr: Dictionary = _data.frames[_frame]
	if fr.has("weakPointVisualCenter"):
		var p: Array = fr.weakPointVisualCenter
		return _body.to_global(Vector2(p[0], p[1]) * SCALE + _body.offset)
	return hit_rect().get_center()

func is_dead() -> bool:
	return state == "dead"

func apply_arc_slow(seconds: float) -> void:
	arc_slow_left = maxf(arc_slow_left, seconds)

func hit(point: Vector2, dir: float, power := 1.0, damage := 1) -> void:
	if is_dead():
		return
	var weak := clip in ["strike", "hold", "retract", "uncoil", "lash", "recoil", "emerge", "snap", "release"]
	var bonus := 2 if weak and point.distance_to(hit_center()) < 38.0 else 1
	hp -= damage * bonus
	_flash = 1.0
	_mat.set_shader_parameter("hit_uv", ((_body.to_local(point) - _body.offset) / Vector2(_data.cell[0] * SCALE, _data.cell[1] * SCALE)).clamp(Vector2.ZERO, Vector2.ONE))
	_mat.set_shader_parameter("radius_px", 140.0)
	var burst := SparkBurst.spawn(get_parent(), floor_y)
	burst.burst(point, 4, Vector2(dir, -0.4), 0.8, Vector2(100, 260), Color(0.6, 0.5, 0.2), Color(0.25, 0.08, 0.09), Vector2(0.2, 0.4), 1800.0, 4.0, false, 0.3, MonsterFx.ROW_FLUID)
	if hp <= 0:
		state = "dead"
		velocity_x = 0.0
		var center := hit_center()
		_play("death")
		CreatureImpactFx.fragments(get_parent(), center, floor_y, {"ceiling_bell":0,"ring_spine":1,"seam_ambusher":2}[species], power)
		Audio.play_at("crawler_death", center, -4.0, 0.85)
		died.emit(center, 1.0)
	else:
		Audio.play_at("crawler_hurt", point, -8.0, 1.0)
		if state == "idle":
			_hurt_return = "dormant" if species == "seam_ambusher" else "idle"
			state = "hurt"
			_play("hurt")
