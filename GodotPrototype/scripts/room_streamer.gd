class_name RoomStreamer
extends Node
## 아주 긴 방에서 **카메라에서 먼 것은 돌리지 않는다.**
##
## 왜 필요한가 — 이 프로젝트의 연출은 거의 다 매 프레임 스크립트로 돈다.
##   램프 24개는 줄을 버렛으로 흔들고(`_physics_process`), 조명마다 붙는 층 분리 거울
##   `LightMirror` 는 `_process` 로 원본을 따라가며, 비상등은 회전하고 불은 흔들리고 끊긴 전선은 물리를 돈다.
##   방 하나가 3,000px 일 때는 이게 다 화면 안이라 문제가 없었다. 20,000px 짜리 방에서는
##   **화면에 없는 것의 95% 가 계속 돌고 있다** — 측정: 붙박이 광원 218개(거울 포함), 무전투 41 → 28 FPS.
##
## 무엇을 하나 — 카메라 x 에서 `band` 밖에 있는 단위의 `process_mode` 를 DISABLED 로 내린다.
##   **그리기는 건드리지 않는다.** 밴드가 화면 반폭보다 넓으므로 화면에 보이는 것은 항상 살아 있고,
##   보이지 않는 것만 멈춘다. 되살아나면 거울은 다음 프레임에 원본과 다시 맞고, 램프 줄은 멈춘 자리에서 이어진다.
##   `visible` · `enabled` 는 **절대 만지지 않는다** — 그쪽은 깨진 램프 · 꺼진 단말기처럼
##   게임 상태가 쓰는 창구라, 스트리밍이 끼어들면 상태를 덮어쓴다.

const DEFAULT_BAND := 3400.0          # 카메라 x ± 이 거리 안은 살려 둔다 (가장 넓은 줌의 반폭 2,240 보다 넉넉히)
const INTERVAL := 0.12                # 갱신 주기 (초) — 매 프레임 훑을 필요가 없다

var band := DEFAULT_BAND
var _camera: Node2D
var _units: Array = []                # [{"node": Node, "x": float}]
var _t := 0.0
var _awake := 0                       # 마지막 갱신에서 살아 있던 단위 수 (HUD·계측용)


## room 안에서 x 를 가진 "단위"를 모은다. 조명(거울은 부모를 따라가므로 제외) · 연출 · 몬스터.
func setup(room: Node2D, camera: Node2D, band_px := DEFAULT_BAND) -> void:
	_camera = camera
	band = band_px
	_units.clear()
	_collect(room)


func _collect(n: Node) -> void:
	for c in n.get_children():
		if c is LightMirror:
			continue                  # 원본 조명의 자식이라 부모가 멈추면 같이 멈춘다
		if c is PointLight2D or c is EmergencyLight or c is FireSource or c is BrokenWire or c is WaterLeak:
			_track(c)
			continue
		_collect(c)


func _track(n: Node) -> void:
	var p := n as Node2D
	if p == null:
		return
	_units.append({"node": n, "x": p.global_position.x})


## **몬스터는 일부러 넣지 않는다.** 스폰은 이미 플레이어 주변(spawn.band)으로 묶여 있어 멀리 있는 개체가 없고,
## 죽는 중인 개체를 멈추면 시체가 영영 안 치워진다. 여기서 끄는 것은 **연출만** 이다.


func awake_count() -> int:
	return _awake


func _process(delta: float) -> void:
	if _camera == null:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = INTERVAL
	var cx := _camera.global_position.x
	var awake := 0
	var alive: Array = []
	for u in _units:
		var n: Node = u["node"]
		if not is_instance_valid(n):
			continue
		alive.append(u)
		var near := absf(float(u["x"]) - cx) <= band
		if near:
			awake += 1
		var want := Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
		if n.process_mode != want:
			n.process_mode = want
	_units = alive
	_awake = awake
