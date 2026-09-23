extends SceneTree
## 탄흔 확인용 자동 스크린샷. 같은 방 뒷벽에 현재 프리셋(인자로 바꿀 수 있음)을 SHOTS 발 **동시에** 쏘고
## (Main._spawn_shot — 실제 사격 경로 그대로) 박힌 뒤 경과 시간별로 자국 주변을 확대 크롭한다.
## 마지막엔 센트리건 위력(1.7)·프랍·바닥 탄착도 한 장 찍어 모든 면에 자국이 남는지 본다.
## 실행: godot --path . --script res://tools/bullet_mark_shot.gd -- [방 id] [프리셋 번호 0~2]   (렌더 필요 — --headless 금지)
## (Bullet·SentryTurret 을 여기서 직접 부르면 오토로드 Audio 보다 먼저 컴파일돼 깨진다 — 값만 옮겨 적는다: 탄속 20800, 센트리건 위력 1.7·궤적 2.0)
## 발마다 식는 시간·구멍 여부가 무작위라 여러 발을 나란히 본다.
## 저장: user://shots/mark_<발>_<ms>.png · mark_surfaces.png

const OUT := "user://shots/"
const TIMES := [0.02, 0.10, 0.25, 0.45, 0.65, 0.85, 1.20, 2.5]   # 박힌 뒤 촬영 시각 (초)
const HALF := Vector2i(34, 34)                                 # 크롭 반폭 (화면 px)
const ZOOM := 4
const SHOTS := 5

var room_id := "workshop"
var main: Node2D
var t := 0.0
var phase := "boot"
var _shot_t := 0.0
var _ti := 0
var _points: Array = []           # 프리셋별 탄착점
var _surf_points: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		room_id = args[0]
	if args.size() > 1:
		BulletMark.set_preset(int(args[1]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AppFlow.start_room = room_id
	change_scene_to_file(AppFlow.TEST_SCENE)


func _process(delta: float) -> bool:
	if main == null:
		main = current_scene as Node2D
		if main == null or main.get("player") == null or main.get("current_room") == null:
			return false
	t += delta
	var r = main.current_room
	match phase:
		"boot":
			if t > 0.6:
				r.disable_monsters()
				main.player.visible = false
				main.camera.lead_enabled = false
				main.camera.target = main.player
				_points = _find_wall_points(r, SHOTS)
				main.player.position.x = _points[SHOTS / 2].x
				main.camera.snap()
				phase = "settle"
		"settle":
			if t > 1.2:
				var muzzle: Vector2 = Vector2(_points[SHOTS / 2].x - 900.0, r.floor_y - 120.0)
				for i in range(SHOTS):
					main._spawn_shot(muzzle, _points[i])
				_shot_t = t + (_points[0] - muzzle).length() / 20800.0   # 탄이 날아가는 시간
				phase = "shoot"
		"shoot":
			while _ti < TIMES.size() and t - _shot_t >= TIMES[_ti]:
				for i in range(SHOTS):
					_crop(_points[i], "mark_%d_%04d" % [i, int(TIMES[_ti] * 1000.0)])
				_ti += 1
			if _ti >= TIMES.size():
				phase = "surfaces"
				_surf_setup(r)
		"surfaces":
			if t - _shot_t >= 0.45:
				var img := _world_image()
				img.save_png(OUT + "mark_surfaces.png")
				for i in range(_surf_points.size()):
					_crop(_surf_points[i], "mark_surface_%d" % i)
				print("SHOT mark_surfaces  points=%s" % str(_surf_points))
				for m in BulletMark._marks:
					if is_instance_valid(m):
						print("  mark %s parent=%s holes=%d cool=%.2f" % [m.global_position, m.get_parent().name, m._hole_cells.size(), m._cool])
				print("MARK SHOT DONE  marks=%d" % BulletMark._marks.filter(func(x): return is_instance_valid(x)).size())
				return true
	return false


## 뒷벽(hit_at 이 none/wall)인 점을 방 가운데 근처에서 n 개 고른다
func _find_wall_points(r, n: int) -> Array:
	var out: Array = []
	var y: float = r.floor_y - 230.0
	var x: float = r.width * 0.5 - 200.0
	while out.size() < n and x < r.width - 100.0:
		var p := Vector2(x, y)
		var k: String = r.hit_at(p)["kind"]
		if k == "none" or k == "wall":
			out.append(p)
			x += 70.0
		else:
			x += 20.0
	while out.size() < n:
		out.append(Vector2(r.width * 0.5 + out.size() * 110.0, y))
	return out


## 센트리건 위력 · 프랍 · 바닥 — 한 화면에 몰아 쏜다 (현재 프리셋)
func _surf_setup(r) -> void:
	var c: Vector2 = _points[1]
	var muzzle: Vector2 = Vector2(c.x - 900.0, r.floor_y - 120.0)
	_surf_points = [c + Vector2(0, 90), Vector2(c.x + 60.0, r.floor_y - 1.0)]
	main._spawn_shot(muzzle, _surf_points[0], 1.7, 2.0)
	main._spawn_shot(muzzle, _surf_points[1])
	for pr in r.props_hit:
		var pp: Vector2 = pr.rect.get_center()
		if pr.is_solid_at(pp):
			main._spawn_shot(muzzle, pp)
			_surf_points.append(pp)
			break
	_shot_t = t


func _world_image() -> Image:
	var img: Image = main.world_vp.get_texture().get_image()
	if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
		img.convert(Image.FORMAT_RGBA8)
		img.linear_to_srgb()
	return img


func _crop(world_p: Vector2, name: String) -> void:
	var img := _world_image()
	var c: Vector2 = main.world_vp.get_canvas_transform() * world_p
	var o := Vector2i(c) - HALF
	var box := Rect2i(o, HALF * 2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if box.size.x <= 0 or box.size.y <= 0:
		return
	var crop := img.get_region(box)
	crop.resize(crop.get_width() * ZOOM, crop.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	crop.save_png(OUT + name + ".png")
