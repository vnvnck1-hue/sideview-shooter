class_name HeatSurface
extends RefCounted
## 피격 열 잔광 관리자. lit_surface / prop_surface 머티리얼의 heat_hits(u, v, 세기, 경과) 배열을 채우고
## 매 프레임 경과 시간을 올린다. 활성 표면만 static 목록에 올려 Main 이 tick_all 로 갱신한다.

const MAX_HITS := 12
const COOL := 1.7                  # 셰이더 heat_cool 과 같은 값 (3.4 → 1.7, 잔광 절반)
const RADIUS_PX := 18.0            # 잔광 반경 (36 → 18, 절반)
const KEEP := COOL * 4.5           # 이 시간이 지나면 항목 제거 (exp(-4.5) ≈ 1%)

static var _active: Array = []

var material: ShaderMaterial
var _hits := PackedVector4Array()
var _listed := false


func _init(m: ShaderMaterial) -> void:
	material = m
	material.set_shader_parameter("heat_cool", COOL)
	material.set_shader_parameter("heat_radius_px", RADIUS_PX)


## uv: 텍스처 UV 상의 탄착점. strength: 1.0 = 한 발 (겹치면 더 뜨겁게 → 흰 열)
func add_hit(uv: Vector2, strength := 1.0) -> void:
	_hits.append(Vector4(uv.x, uv.y, strength, 0.0))
	while _hits.size() > MAX_HITS:
		_hits.remove_at(0)
	_upload()
	if not _listed:
		_listed = true
		_active.append(self)


func _tick(delta: float) -> bool:
	for i in range(_hits.size()):
		var h := _hits[i]
		h.w += delta
		_hits[i] = h
	while _hits.size() > 0 and _hits[0].w > KEEP:
		_hits.remove_at(0)
	_upload()
	if _hits.is_empty():
		_listed = false
		return false
	return true


func _upload() -> void:
	material.set_shader_parameter("heat_count", _hits.size())
	if _hits.size() > 0:
		material.set_shader_parameter("heat_hits", _hits)


## Main._process 가 매 프레임 호출
static func tick_all(delta: float) -> void:
	var i := 0
	while i < _active.size():
		var hs: HeatSurface = _active[i]
		if hs._tick(delta):
			i += 1
		else:
			_active.remove_at(i)


static func clear_all() -> void:
	for hs in _active:
		hs._listed = false
	_active.clear()
