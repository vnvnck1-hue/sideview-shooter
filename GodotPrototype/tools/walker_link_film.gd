extends SceneTree
## 보행 기체 **접속·해제 연출** 연속 촬영.
##   godot --path . --script res://tools/walker_link_film.gd   (렌더 필요 — --headless 금지)
## 저장: user://shots/link/
##
## 연출이 3초를 넘게 끌기 때문에(지지직 세 번이 잦아든다) **정해진 프레임 간격으로** 찍는다 —
## 사건마다 찍으면 잦아드는 구간이 통째로 빠진다.
const OUT := "user://shots/link/"
const EVERY := 8          # 프레임 간격 (60fps 기준 약 0.13초)
const COUNT := 26
const START := 40         # 이 프레임에 접속을 건다
const UNLINK := 20        # 이 장수째에 접속을 끊는다

var _main: Node
var _f := 0
var _n := 0
var _armed := false
var _unit
var _unlinked := false


func _initialize() -> void:
	AppFlow.start_test(self, "hangar", 880.0, -1)


func _process(_d: float) -> bool:
	_f += 1
	if _main == null:
		_main = root.get_child(root.get_child_count() - 1)
		if _main == null or not _main.has_method("_load_room"):
			_main = null
			return _f > 300
		DirAccess.make_dir_recursive_absolute(OUT)
		return false
	var room = _main.get("current_room")
	if room == null or room.walkers.is_empty():
		return false
	_unit = room.walkers[0]

	if _f == START:
		_main._on_front_door_requested()          # W/↑ 와 같은 길
	if _n >= UNLINK and not _unlinked and _unit.controlled:
		_unlinked = true
		_main.walker_link.link_out(func(): _unit.set_controlled(false))

	if _armed:
		var img := root.get_texture().get_image()
		if img == null or img.get_width() == 0:
			return false
		img.save_png(OUT + "L%02d.png" % _n)
		# 화면 상태를 같이 남긴다 — 그림만 보고는 어느 단계인지 판단이 안 된다
		var crt := root.get_node_or_null("CrtFx")
		var cam := _main.get("camera") as Camera2D
		print("L%02d  t=%.2f  crt=%s  zoom=%.3f  target=%s" % [
			_n, (_f - START) / 60.0, CrtPreset.get_preset(crt.index)["id"] if crt else "-",
			cam.zoom.x, cam.target.name])
		_n += 1
		_armed = false
		if _n >= COUNT:
			print("--- ", ProjectSettings.globalize_path(OUT), " ---")
			quit()
			return true
	elif _f >= START and _f % EVERY == 0:
		_armed = true
	return false
