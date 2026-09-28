class_name ObstacleExplosion
extends Node2D
## 가스통 폭발. 한 번의 "쾅" 을 시간 순서대로 쌓는다.
##   0.00  백열 섬광(원판) + 충격파 링 — 히트스톱(Main) 동안 이 프레임이 멎어 보인다
##   0.00~ 불덩이 원화 4덩이가 시차를 두고 부풀어 하나의 큰 화구가 된다 (1배 = 4px 격자 유지)
##   0.00~ 불꽃 알갱이·불씨 덩이가 솟았다 떨어져 바닥에서 잠시 탄다
##   0.05~ 바닥을 타고 좌우로 퍼지는 분진 띠, 짙은 연기 기둥이 천천히 오른다
##   ~2.6  바닥 잔불이 일렁이다 사그라든다. 그을음 자국은 방을 나갈 때까지 남는다
## 소리는 크런치(Kenney) + 저역 폭발(Kenney) + 절차 합성 꼬리 3겹, 0.3초 뒤 잔해 떨어지는 소리.
const LIFE := 2.8
const FRAME_TIME := [0.045, 0.07, 0.11, 0.19, 0.3, 0.42]   # 원화 6프레임 각각의 길이
const CANVAS := 384.0                                      # 원화 한 프레임 (96 art px × 4)
var age := 0.0
var sprite: Sprite2D                                       # 중심 불덩이 (검증용 참조)
var mode := "explosion"
var floor_line := 0.0
var radius := 410.0
var _balls: Array = []                                     # {sprite, delay}
var _flames: Array = []                                    # 바닥 잔불 {x, h, seed}
var _flame_seed := 0
var _flicker_t := 0.0
var _rattle := false
var _ring_dir := 1.0
static var _sound: AudioStreamWAV
static var _frames: Array = []


static func spawn(room: Node2D, floor_pos: Vector2, _center: Vector2, blast_radius := 410.0) -> ObstacleExplosion:
	var fx := ObstacleExplosion.new()
	fx.position = floor_pos
	fx.floor_line = floor_pos.y
	fx.radius = blast_radius
	room.add_child(fx)
	WeaponLightPool.get_pool(room).pulse(fx.get_instance_id(), floor_pos + Vector2(0, -140), Color(1, 0.55, 0.2), 1150.0, 7.0, 0.7)
	var sound := AudioStreamPlayer2D.new()
	sound.stream = explosion_sound()
	sound.bus = "Weapon"
	sound.volume_db = -7.0
	sound.max_distance = 2600.0
	fx.add_child(sound)
	sound.play()
	Audio.play_at("gas_explosion", floor_pos + Vector2(0, -80))
	Audio.play_at("gas_explosion_low", floor_pos + Vector2(0, -80))
	fx._burst(room)
	Scorch.stamp(room, floor_pos)
	return fx


static func frame(i: int) -> Texture2D:
	if _frames.is_empty():
		for f in range(6):
			_frames.append(load("res://assets/effects/obstacles/explosion_%02d.png" % f))
	return _frames[clampi(i, 0, 5)]


func _ready() -> void:
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	# 중심 + 좌·우 + 위, 네 덩이. 좌우 반전과 시차로 같은 원화가 한 덩이로 읽히지 않는다.
	# [자리, 시작 지연, 좌우 반전, 건너뛸 첫 프레임 수] — 곁가지는 점화 별(0번)을 건너뛰고 바로 부푼다
	for spec in [[Vector2(0, 0), 0.0, false, 0], [Vector2(-104, 12), 0.05, true, 1], [Vector2(116, 8), 0.085, false, 1], [Vector2(-8, -116), 0.13, true, 2]]:
		var s := Sprite2D.new()
		s.material = material
		s.centered = false
		s.flip_h = spec[2]
		s.position = (spec[0] as Vector2) + Vector2(-CANVAS * 0.5, -CANVAS + 16.0)
		s.texture = frame(0)
		s.visible = spec[1] == 0.0
		add_child(s)
		_balls.append({"sprite": s, "delay": spec[1], "skip": spec[3]})
		if spec[1] > 0.0:
			move_child(s, 0)             # 늦게 피는 곁가지는 중심 덩이 뒤로
	sprite = _balls[0].sprite
	for i in range(7):
		_flames.append({"x": randf_range(-150, 150), "h": randf_range(0.6, 1.0), "life": randf_range(1.6, 2.6)})
	_ring_dir = 1.0 if randf() < 0.5 else -1.0


## 순간에 터져 나가는 알갱이들 — 스스로 사라지는 PropFx·SparkBurst 에 맡긴다.
func _burst(room: Node2D) -> void:
	var at := position + Vector2(0, -70)
	var sparks := SparkBurst.spawn(room, floor_line)
	sparks.burst(at, 44, Vector2(0, -1), 1.45, Vector2(380, 1250), Color(1, 0.95, 0.75), Color(1, 0.32, 0.06),
		Vector2(0.45, 1.1), 1900.0, 4.0, false)
	var embers := PropFx.make(room, floor_line + 2.0, true, 11, "embers")
	for i in range(26):
		var v := Vector2.UP.rotated(randf_range(-1.25, 1.25)) * randf_range(420, 1150)
		var s: float = [4.0, 8.0, 8.0, 12.0][randi() % 4]
		embers.chip(at + Vector2(randf_range(-30, 30), randf_range(-30, 20)), v, Vector2(s, s),
			Color(1.0, 0.85, 0.4), randf_range(1.2, 2.4), 1700.0, 0.0, 0.25, Color(0.55, 0.08, 0.02))
	# 연기 기둥: 불덩이 뒤에서 늦게 피어올라 오래 남는다 (라이트를 받는 일반 재질 — 불빛에 아래가 물든다)
	var smoke := PropFx.make(room, floor_line, false, 9, "smoke")
	for i in range(18):
		var p := position + Vector2(randf_range(-170, 170), randf_range(-260, -40))
		var shade := randf_range(0.1, 0.2)
		smoke.puff(p, Vector2(randf_range(-40, 40), -randf_range(50, 150)), randf_range(90, 150),
			Color(shade, shade * 0.9, shade * 1.15, 0.85), randf_range(2.0, 3.2), 1.5, 0.8, -25.0, randf_range(0.18, 0.7))
	var dust := PropFx.make(room, floor_line, false, 9, "blast_dust")
	PropFx.floor_wave(dust, Vector2(position.x, floor_line - 12), 160.0, Color(0.46, 0.44, 0.48, 0.7), 1.8, 14)


func _process(delta: float) -> void:
	age += delta
	for b in _balls:
		var t: float = age - float(b.delay)
		var s: Sprite2D = b.sprite
		s.visible = t >= 0.0
		if t < 0.0:
			continue
		var f := 0
		var acc := 0.0
		for i in range(int(b.skip), FRAME_TIME.size()):
			acc += FRAME_TIME[i]
			f = i
			if t < acc:
				break
		s.texture = frame(f)
		s.modulate.a = 1.0 - smoothstep(acc - 0.3, acc, t) if f == 5 else 1.0
		if t > acc:
			s.visible = false
	# 잔불이 일렁이는 동안 조명도 따라 일렁인다 (풀의 같은 슬롯을 이어 받는다)
	_flicker_t -= delta
	if age > 0.55 and age < 2.4 and _flicker_t <= 0.0:
		_flicker_t = 0.09
		var room := get_parent()
		if room is Node2D:
			WeaponLightPool.get_pool(room).pulse(get_instance_id(), global_position + Vector2(0, -50), Color(1, 0.45, 0.14),
				560.0, randf_range(1.6, 2.6) * (1.0 - age / 2.4), 0.12)
	if not _rattle and age > 0.3:
		_rattle = true
		Audio.play_at("prop_rubble", global_position, -4.0, 0.8)
	_flame_seed = int(age / 0.06)
	queue_redraw()
	if age > LIFE:
		queue_free()


func _draw() -> void:
	# 백열 섬광: 첫 두어 프레임만. 히트스톱이 이 순간을 붙잡는다.
	if age < 0.09:
		var k := age / 0.09
		var tex := flash_texture()
		var size := tex.get_size() * (4.0 if k < 0.5 else 3.0)            # 4px 격자 별 → 한 단계 작게
		draw_texture_rect(tex, Rect2(Vector2(0, -90) - size * 0.5, size), false, Color(4.0, 3.4, 2.6, 1.0 - k * 0.5))
	# 충격파: 두꺼운 링이 폭발 반경까지 빠르게 번진다
	if age < 0.28:
		var k := age / 0.28
		var rr := radius * (1.0 - pow(1.0 - k, 3.0))
		var w := snappedf(lerpf(28.0, 4.0, k), 4.0)
		# 바닥 위 반원만 — 바닥 아래로 링이 그려지면 땅속이 비쳐 보인다
		draw_arc(Vector2(0, -12), rr, PI, TAU, 40, Color(2.2, 1.7, 1.2, 0.6 * (1.0 - k)), w)
		draw_arc(Vector2(0, -12), rr * 0.8, PI, TAU, 32, Color(1.6, 0.9, 0.4, 0.32 * (1.0 - k)), w * 0.5)
	# 바닥 잔불: 4px 칸을 쌓아 만든 불꽃 혀. 아래 백열 → 위 주황 → 끝 적색
	if age > 0.35:
		var rng := RandomNumberGenerator.new()
		for i in range(_flames.size()):
			var fl: Dictionary = _flames[i]
			var life_k: float = clampf((age - 0.35) / float(fl.life), 0.0, 1.0)
			if life_k >= 1.0:
				continue
			rng.seed = _flame_seed * 97 + i * 13
			var h: float = snappedf(float(fl.h) * lerpf(64.0, 12.0, life_k) * rng.randf_range(0.75, 1.15), 4.0)
			var x: float = snappedf(float(fl.x), 4.0)
			var rows := int(h / 4.0)
			for row in range(rows):
				var up := float(row) / maxf(rows, 1)
				var half := snappedf(lerpf(14.0, 2.0, up) * (1.0 - life_k * 0.4), 4.0)
				var sway := snappedf(sin(up * 3.0 + age * 9.0 + i) * up * 6.0, 4.0)
				var col := Color(3.0, 2.6, 1.4) if up < 0.25 else (Color(2.6, 1.2, 0.3) if up < 0.65 else Color(1.6, 0.35, 0.08))
				draw_rect(Rect2(Vector2(x - half + sway, -4.0 - row * 4.0), Vector2(half * 2.0 + 4.0, 4.0)), col)


static var _flash_tex: Texture2D

## 점화 섬광 — 가시가 삐죽한 72×72 art px 별. 가운데 백열, 바깥 노랑 (그리는 쪽에서 밝기를 올린다).
static func flash_texture() -> Texture2D:
	if _flash_tex == null:
		var img := Image.create(72, 72, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5531
		var spikes := []
		for i in range(11):
			spikes.append([rng.randf() * TAU, rng.randf_range(0.35, 1.0)])
		for y in range(72):
			for x in range(72):
				var d := Vector2(x - 35.5, y - 35.5)
				var a := d.angle()
				var reach := 13.0
				for sp in spikes:
					var da := absf(wrapf(a - float(sp[0]), -PI, PI))
					reach = maxf(reach, 13.0 + 22.0 * float(sp[1]) * maxf(0.0, 1.0 - da / 0.16))
				var r := d.length()
				if r < reach:
					var core := r < 9.0 or r < reach * 0.42
					img.set_pixel(x, y, Color(1, 1, 1, 1) if core else Color(1.0, 0.82, 0.42, 1))
		_flash_tex = ImageTexture.create_from_image(img)
	return _flash_tex


static func explosion_sound() -> AudioStreamWAV:
	if _sound != null:
		return _sound
	var rate := 22050
	var samples := int(rate * 1.6)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71825
	var low := 0.0
	var low2 := 0.0
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / rate
		var noise := rng.randf_range(-1, 1)
		low = lerpf(low, noise, 0.09)
		low2 = lerpf(low2, low, 0.05)
		phase += TAU * lerpf(70, 24, minf(t / 0.8, 1.0)) / rate
		# 짧은 크랙 + 저역 럼블 + 길게 끄는 굉음 꼬리 (실내 잔향처럼 1.5초 끈다)
		var value := (noise * exp(-t * 38) * 0.4 + low * exp(-t * 3.2) * 1.2 + low2 * exp(-t * 1.6) * 2.2
			+ sin(phase) * exp(-t * 5.0) * 0.6) * minf(t / 0.002, 1.0)
		data.encode_s16(i * 2, int(clampf(value, -1, 1) * 26000))
	_sound = AudioStreamWAV.new()
	_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_sound.mix_rate = rate
	_sound.data = data
	return _sound


## 그을음 자국 — 폭발 자리 뒷벽·바닥에 남는 검은 얼룩. 방을 나가면 방과 함께 사라진다.
class Scorch extends Sprite2D:
	static func stamp(room: Node2D, floor_pos: Vector2) -> void:
		var s := Scorch.new()
		var img := Image.create(80, 56, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for y in range(56):
			for x in range(80):
				# 바닥 쪽이 가장 진하고 위로 갈수록 얇아지는 부채꼴 + 픽셀 단위 거친 가장자리
				var d := Vector2((x - 40.0) / 40.0, (56.0 - y) / 52.0).length()
				var edge := d + rng.randf_range(-0.12, 0.12)
				if edge < 1.0:
					var a := clampf((1.0 - edge) * 1.6, 0.0, 0.78)
					a = snappedf(a, 0.26)
					if a > 0.0:
						img.set_pixel(x, y, Color(0.02, 0.016, 0.018, a))
		s.texture = ImageTexture.create_from_image(img)
		s.centered = false
		s.scale = Vector2(4, 4)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = floor_pos + Vector2(-160, -56 * 4 + 6)
		s.z_index = -1
		var layer: Node = room.stain_layer() if room.has_method("stain_layer") else room
		layer.add_child(s)
