class_name AccessTerminal
extends Node2D
## 월드에 서 있는(또는 벽에 붙은) 단말기 프랍. 플레이어가 옆에서 W/↑ 로 접속한다.
##
## 역할 5종(link · security · rewire · save · survey)은 TerminalData.ROLES 가 정하고,
## 이 노드는 그 역할의 자산·화면 발광색·설치 방식(바닥/벽걸이)만 반영한다.
## 접속했을 때 화면 안에서 무엇을 할 수 있는지는 scripts/terminal_screen.gd 가 맡는다.
##
## 화면은 역할 색으로 은은히 맥동하고(대기), 접속 요청 순간 한 번 세게 밝아진다(접속 펄스).
## 접속 중에는 계속 밝은 상태로 고정된다 — 멀리서도 "지금 누가 쓰고 있다" 가 읽힌다.
## 컨셉: Docs/TERMINAL_SYSTEM_CONCEPT.md

signal access_requested(terminal: AccessTerminal)

const INTERACT_RANGE := 150.0
const WALL_DEFAULT_FY := 300.0          # 벽걸이 단말기 기본 높이 (바닥선에서 위로)

var terminal_id := ""
var role_id := "link"
var role: Dictionary = TerminalData.ROLES["link"]
var data: Dictionary = {}
var floor_y := 0.0
var connected := false                  # 지금 플레이어가 접속 중인가 (화면이 밝게 고정된다)

var _screen_light: PointLight2D
var _base_energy := 0.52
var _pulse_t := 0.0
var _idle_t := 0.0


## id = TerminalData.TERMINALS 의 키. wall_y 를 주면(벽걸이) 그 높이에 스프라이트 중심을 맞춘다.
func setup(id: String, center_x: float, floor_line: float, wall_y := NAN) -> void:
	terminal_id = id
	data = TerminalData.get_terminal(id)
	role_id = str(data.get("role", "link"))
	role = TerminalData.ROLES.get(role_id, TerminalData.ROLES["link"])
	name = "Terminal_" + (id if id != "" else role_id)
	floor_y = floor_line
	if is_finite(wall_y):
		position = Vector2(round(center_x), round(wall_y))
	else:
		position = Vector2(round(center_x), floor_line + 2.0)


func _ready() -> void:
	# 자산·설치 방식은 역할이 정하지만, 자리가 좁은 방에서는 단말기 정의가 덮어쓸 수 있다
	# (예: 격납고의 보안 관제는 바닥에 480px 를 낼 자리가 없어 벽걸이 패널로 단다).
	var tex := Lighting.textured(TerminalData.texture_of(terminal_id))
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var wall := TerminalData.is_wall(terminal_id)

	var sprite := Sprite2D.new()
	sprite.name = "TerminalSprite"
	sprite.centered = true
	sprite.texture = tex
	# 바닥형은 원점이 접지선이라 절반 높이만큼 올려 세우고, 벽걸이는 준 위치가 곧 중심이다
	sprite.position = Vector2.ZERO if wall else Vector2(0.0, -h * 0.5)
	sprite.material = Lighting.shader_material("prop_surface")

	# 접지·각도 그림자는 프랍 그림자 층(PropShadow)이 그린다 — Room 이 바닥형 단말기를 캐스터로 등록한다.
	# 여기서 따로 접촉 띠를 깔면 두 겹으로 겹쳐 이 프랍만 유독 어두워진다.
	add_child(sprite)

	_screen_light = PointLight2D.new()
	_screen_light.name = "ScreenLight"
	_screen_light.texture = Lighting.radial_texture()
	_screen_light.texture_scale = Lighting.scale_for_radius(float(role["screen_radius"]))
	_screen_light.color = role["screen"]
	_screen_light.energy = _base_energy
	_screen_light.height = Lighting.LAMP_HEIGHT
	# 벽걸이로 덮어쓴 경우 역할의 발광 지점(바닥 기준)을 그대로 쓰면 화면에서 멀리 떨어진다 — 스프라이트 중심으로
	_screen_light.position = Vector2.ZERO if wall and not bool(role["wall"]) else role["screen_local"]
	add_child(_screen_light)
	Lighting.split_by_depth(_screen_light, 0.7)


func _process(delta: float) -> void:
	_idle_t += delta
	_pulse_t = maxf(_pulse_t - delta, 0.0)
	if _screen_light == null:
		return
	# 대기: 형광체가 숨쉬듯 아주 얕게 흔들린다. 접속 중: 밝게 고정되고 흔들림만 남는다.
	var flicker := 0.045 * sin(_idle_t * 3.7) + 0.02 * sin(_idle_t * 8.9)
	var pulse := 0.0
	if _pulse_t > 0.0:
		pulse = 0.85 * sin((1.0 - _pulse_t / 0.8) * PI)
	var base := _base_energy * (2.1 if connected else 1.0)
	_screen_light.energy = base + flicker + pulse


## 화면 발광 지점의 월드 좌표 — 카메라가 접속할 때 밀어 넣는 목표점
func screen_point() -> Vector2:
	return _screen_light.global_position if _screen_light != null else to_global(role["screen_local"])


func can_interact(px: float) -> bool:
	return absf(px - position.x) <= INTERACT_RANGE


func prompt_text() -> String:
	var title := str(data.get("title", role["name"]))
	return "▲  W / ↑  —  %s  ·  %s" % [title, role["short"]]


## W/↑ — 접속 펄스를 한 번 치고 Main 에 접속을 요청한다 (화면 전환은 Main 이 맡는다)
func activate() -> void:
	_pulse_t = 0.8
	access_requested.emit(self)


func set_connected(active: bool) -> void:
	connected = active
	if active:
		_pulse_t = 0.8
