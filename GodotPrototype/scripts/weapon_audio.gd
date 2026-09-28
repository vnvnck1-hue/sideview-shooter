class_name WeaponAudio
extends RefCounted
## 새 무기 전용 합성음. 실총 녹음 레이어(Audio.fire · turret_crack 등)에 **얹는** 용도다 — 합성음만으로는
## "쿵" 은 나도 몸통이 없다. 한 번 만들면 캐시한다.
##   coil     : 전자 크랙(노이즈 6ms) + 2.6k→90Hz 급강하 FM + 55Hz 서브 쿵
##   charge   : 0.3초 상승음 (충전 시간과 같다) — 끝에서 날카롭게 선다
##   arc      : 발사 — 짧은 방전 지직임 + 저음 험
##   arc_hit  : 터짐 — 굵은 방전 폭발 + 잔떨림
##   pump     : 불독 펌프 — 금속 두 번 (척-칵)
##   thump    : 불독 저역 보강 (48Hz 쿵)
static var cache: Dictionary = {}
const RATE := 22050


static func play(host: Node, at: Vector2, id: String, volume := -9.0, pitch := 1.0) -> AudioStreamPlayer2D:
	if host == null or not is_instance_valid(host):
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = _sound(id)
	p.bus = "Weapon"
	p.volume_db = volume
	p.pitch_scale = pitch
	p.max_distance = 2400.0
	p.attenuation = 0.6
	host.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()
	return p


static func _sound(id: String) -> AudioStreamWAV:
	if cache.has(id):
		return cache[id]
	var durations := {"coil": 0.42, "charge": 0.32, "arc": 0.26, "arc_hit": 0.5, "pump": 0.24, "thump": 0.3}
	var duration: float = durations.get(id, 0.3)
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var ph := 0.0
	var ph2 := 0.0
	var noise_hold := 0.0
	var gate := 1.0
	var lp := 0.0
	for i in range(n):
		var t := float(i) / RATE
		var k := t / duration
		var v := 0.0
		match id:
			"coil":
				var f := 90.0 + 2500.0 * exp(-t * 26.0)
				ph += TAU * f / RATE
				var fm := sin(ph + sin(ph * 2.01) * 2.2 * exp(-t * 10.0))
				ph2 += TAU * (55.0 + 30.0 * exp(-t * 30.0)) / RATE
				var crack := rng.randf_range(-1.0, 1.0) * exp(-t * 520.0)
				v = fm * 0.5 * exp(-t * 7.5) + sin(ph2) * 0.85 * exp(-t * 11.0) + crack * 1.2
				v += rng.randf_range(-1.0, 1.0) * 0.12 * exp(-t * 16.0)
			"charge":
				var f := lerpf(180.0, 1500.0, pow(k, 1.6))
				ph += TAU * f / RATE
				ph2 += TAU * f * 1.5 / RATE
				var trem := 0.7 + 0.3 * sin(t * TAU * lerpf(18.0, 60.0, k))
				v = (sin(ph) * 0.45 + sign(sin(ph2)) * 0.12) * trem * minf(k * 4.0, 1.0) * lerpf(0.35, 1.0, k)
			"arc", "arc_hit":
				# 방전: 무작위로 끊기는(게이트) 거친 노이즈 + 60Hz 대 험. 샘플&홀드로 치직거리게
				if i % int(rng.randf_range(3, 14)) == 0:
					noise_hold = rng.randf_range(-1.0, 1.0)
				if i % 180 == 0:
					gate = 1.0 if rng.randf() < 0.72 else 0.15
				ph += TAU * (110.0 if id == "arc" else 70.0) / RATE
				var hum := signf(sin(ph)) * 0.25 + sin(ph * 3.0) * 0.15
				var decay := exp(-t * (13.0 if id == "arc" else 6.5))
				var boom := sin(TAU * 48.0 * t) * exp(-t * 14.0) * (0.9 if id == "arc_hit" else 0.3)
				v = (noise_hold * 0.75 * gate + hum) * decay + boom
				v += rng.randf_range(-1.0, 1.0) * exp(-t * 300.0)
			"pump":
				for click in [0.0, 0.11]:
					var ct: float = t - click
					if ct >= 0.0:
						var ring := sin(TAU * (1900.0 if click == 0.0 else 1350.0) * ct) * exp(-ct * 90.0)
						v += (rng.randf_range(-1.0, 1.0) * exp(-ct * 260.0) * 0.9 + ring * 0.5)
			"thump":
				ph += TAU * (48.0 + 70.0 * exp(-t * 40.0)) / RATE
				v = sin(ph) * exp(-t * 9.0) * minf(t / 0.003, 1.0)
		# 완만한 저역 통과로 디지털 거친 끝만 깎는다
		lp += (v - lp) * 0.55
		var env := minf(t / 0.0015, 1.0) * (1.0 - pow(k, 6.0))
		data.encode_s16(i * 2, int(clampf(lp * env, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	cache[id] = wav
	return wav
