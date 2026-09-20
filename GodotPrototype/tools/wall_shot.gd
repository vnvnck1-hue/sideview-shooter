extends SceneTree
## 크롤러 벽·천장 이동 확인용 자동 스크린샷: 가장 큰 방(격납고)에서 몬스터 한 마리만 남기고
## 벽 도약 → 벽 등반 → 안쪽 코너 → 천장 기어가기 → 덮치기(낙하)까지 단계마다 한 장씩 저장하고 종료한다.
## 실행: godot --path . --script res://tools/wall_shot.gd   (렌더가 필요하므로 --headless 금지)
## 저장: user://shots/wall_*.png  (Windows: %APPDATA%\Godot\app_userdata\Sideview Workshop Prototype\shots\)

const OUT := "user://shots/"

var main: Node2D
var t := 0.0
var step := 0
var steps := [
	[0.40, "setup"],
	[0.60, "shot:wall_00_floor"],
	[0.65, "wall"],                 # 강제 벽 도약
	[0.78, "shot:wall_01_crouch"],
	[0.90, "shot:wall_02_air_a"],
	[1.02, "shot:wall_03_air_b"],
	[1.16, "shot:wall_04_attach"],
	[1.90, "shot:wall_05_climb"],
	[3.40, "corner"],               # 지금 붙어 있는 높이에서 바로 코너로
	[3.52, "shot:wall_06_corner_a"],
	[3.64, "shot:wall_07_corner_b"],
	[3.80, "shot:wall_08_corner_c"],
	[4.40, "shot:wall_09_ceiling"],
	# 천장에 매달린 채 죽이기 — 육편·체액이 그 높이에서 터지고 시체가 바닥으로 떨어진다
	[6.05, "killwall"],
	[6.15, "shot:wall_10_ceiling_death"],
	[6.45, "shot:wall_11_corpse_falling"],
	[7.10, "shot:wall_12_corpse_landed"],
	# 새로 스폰한 놈으로 덮치기(낙하) 마무리까지 한 번 더
	[7.20, "respawn"],
	[7.60, "wall"],
	[13.50, "shot:wall_13_pounce"],
	[14.60, "shot:wall_14_after"],
	[14.80, "quit"],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AppFlow.start_room = RoomData.SENTRY_TEST_ROOM      # 맵에서 가장 큰 방 — 벽까지 거리가 넉넉하다
	change_scene_to_file(AppFlow.TEST_SCENE)


func _process(delta: float) -> bool:
	if main == null:
		main = current_scene as Node2D
		if main == null or main.get("player") == null:
			return false
	t += delta
	while step < steps.size() and t >= steps[step][0]:
		var cmd: String = steps[step][1]
		step += 1
		if _do(cmd):
			return true
	return false


## 살아 있는 첫 크롤러 (스포너가 계속 넣으므로 매번 다시 찾는다)
func _first() -> Crawler:
	for m in main.current_room.monsters:
		if is_instance_valid(m) and not m.is_dead():
			return m
	return null


## true 를 돌려주면 종료
func _do(cmd: String) -> bool:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			# 지속 스폰을 끄고 한 마리만 남긴다 (연출 단계를 또렷하게 보려고)
			main.current_room._spawn_cfg = {"max": 0, "interval": [99.0, 99.0]}
			var keep := _first()
			for m in main.current_room.monsters:
				if is_instance_valid(m) and m != keep:
					m.queue_free()
			main.current_room.monsters = [keep] if keep else []
			if keep:
				# 왼쪽 벽 가까이 세워 도약이 확실히 성사되게 한다
				keep.position.x = keep.min_x + 420.0
				main.player.position.x = keep.position.x + 900.0
			main.camera.snap()
		"wall":
			var c := _first()
			if c:
				c.force_wall()
		"corner":
			# 등반이 끝날 때까지 기다리지 않고 지금 높이에서 코너 전환 (각도 보간 확인용)
			var cc := _first()
			if cc and cc.state == Crawler.State.WALL and cc._surface == Crawler.Surface.WALL:
				cc._start_corner(cc.position.y - Crawler.WALL_CLEAR)
		"respawn":
			var n: Crawler = main.current_room._add_crawler(main.player.position.x - 900.0, 1)
			n.spawn_in()
		"killwall":
			# 벽에 붙어 있는 그 자리에서 즉사시킨다 (총알 난수에 기대지 않고 죽음 연출만 본다)
			var k := _first()
			if k:
				while not k.is_dead():
					k.hit(k.hit_center(), 1.0, 2.0)
		"aimm":
			var c2 := _first()
			if c2:
				Input.warp_mouse(main.world_to_screen(c2.hit_center()))
		"press":
			Input.action_press(parts[1])
		"release":
			Input.action_release(parts[1])
		"shot":
			var img := root.get_viewport().get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			img.save_png(OUT + parts[1] + ".png")
			var c3 := _first()
			if c3:
				# 크롤러 주변만 잘라 한 장 더 (접지·자세 확인용). 저해상도 월드 SubViewport 를 직접 캡처하면
				# 그 캔버스 변환만으로 월드→픽셀이 정확히 나온다 (루트 화면 좌표는 레터박스·스트레치가 낀다).
				var wimg: Image = main.world_vp.get_texture().get_image()
				if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
					wimg.convert(Image.FORMAT_RGBA8)
					wimg.linear_to_srgb()
				var wsize := wimg.get_size()
				var c: Vector2 = main.world_vp.get_canvas_transform() * c3.hit_center()
				var half := Vector2i(70, 70)
				var o := (Vector2i(c) - half).clamp(Vector2i.ZERO, (wsize - half * 2).max(Vector2i.ZERO))
				var box := Rect2i(o, half * 2).intersection(Rect2i(Vector2i.ZERO, wsize))
				if box.size.x > 0 and box.size.y > 0:
					var crop := wimg.get_region(box)
					crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
					crop.save_png(OUT + parts[1] + "_zoom.png")
				print("SHOT %s  state=%d surface=%d side=%d pos=(%.0f,%.0f) clip=%s frame=%d flip=%s/%s" % [
					parts[1], c3.state, c3._surface, c3._wall_side, c3.position.x, c3.position.y,
					c3._sprite.animation, c3._sprite.frame, c3._sprite.flip_h, c3._sprite.flip_v])
			else:
				print("SHOT %s  (살아 있는 크롤러 없음)" % parts[1])
		"quit":
			print("WALL SHOT DONE")
			return true
	return false
