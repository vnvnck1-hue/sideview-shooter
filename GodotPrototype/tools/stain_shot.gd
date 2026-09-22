extends SceneTree
## 체액 자국 공간감 확인용 자동 스크린샷. 작업실에서 몬스터를 치우고, 고정 난수로
## (A) 맨 뒷벽 (B) 프랍을 가로지르는 분사 (C) 바닥 근처 — 세 상황을 찍는다.
## 같은 시드·같은 좌표라 코드 수정 전후를 그대로 겹쳐 비교할 수 있다.
## 실행: godot --path . --script res://tools/stain_shot.gd -- <태그>   (렌더 필요 — --headless 금지)
## 저장: user://shots/stain_<태그>_*.png

const OUT := "user://shots/"
const SEED := 20260922

var tag := "before"
var main: Node2D
var t := 0.0
var step := 0
var steps := [
	[0.50, "setup"],
	[0.60, "fire:wall"],
	[1.60, "shot:a_wall"],
	[3.40, "shot:a_wall_late"],
	[3.50, "reset"],
	[3.60, "fire:prop"],
	[4.60, "shot:b_prop"],
	[6.40, "shot:b_prop_late"],
	[6.50, "reset"],
	[6.60, "fire:floor"],
	[7.60, "shot:c_floor"],
	[9.40, "shot:c_floor_late"],
	[9.50, "reset"],
	[9.60, "fire:front"],
	[10.4, "shot:d_front"],
	[11.8, "shot:d_front_late"],
	[12.0, "quit"],
]

var _cam_x := 0.0
var _focus := Vector2.ZERO        # 확대 크롭 중심 (직전 분사 지점)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		tag = a
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AppFlow.start_room = "workshop"
	change_scene_to_file(AppFlow.TEST_SCENE)


func _process(delta: float) -> bool:
	if main == null:
		main = current_scene as Node2D
		if main == null or main.get("player") == null or main.get("current_room") == null:
			return false
	t += delta
	while step < steps.size() and t >= steps[step][0]:
		var cmd: String = steps[step][1]
		step += 1
		if _do(cmd):
			return true
	return false


func _room() -> Room:
	return main.current_room as Room


## 촬영 기준점: 첫 프랍의 정면. 프랍이 없으면 방 가운데.
func _anchor() -> Vector2:
	var r := _room()
	if not r.props_hit.is_empty():
		var pr = r.props_hit[0]
		return pr.rect.position + Vector2(pr.rect.size.x * 0.5, pr.rect.size.y * 0.5)
	return Vector2(r.width * 0.5, r.floor_y - 200.0)


func _do(cmd: String) -> bool:
	var parts := cmd.split(":")
	match parts[0]:
		"setup":
			var r := _room()
			r.disable_monsters()
			var a := _anchor()
			_cam_x = a.x
			_focus = a
			main.player.position.x = a.x
			main.player.visible = false                  # 플레이어가 자국을 가리지 않게
			main.camera.lead_enabled = false
			main.camera.target = main.player
			main.camera.snap()
			var info := "ROOM %s width=%.0f floor=%.0f props=%d" % [r.room_id, r.width, r.floor_y, r.props_hit.size()]
			for pr in r.props_hit:
				info += "\n  prop rect=%s" % str(pr.rect)
			print(info)
		"reset":
			var r2 := _room()
			for s in r2._stains:
				if is_instance_valid(s):
					s.queue_free()
			r2._stains.clear()
		"fire":
			seed(SEED)
			var r3 := _room()
			var a2 := _anchor()
			match parts[1]:
				"wall":
					# 프랍이 없는 빈 벽면을 향해 — 지금은 전부 같은 평면에 깔린다
					var o := Vector2(a2.x + 520.0, a2.y - 60.0)
					_focus = o + Vector2(140, -20)
					r3.add_spray(o, Vector2(1, -0.25), 26, 280.0, 1.3)
					r3.add_stain(o + Vector2(40, 0), Vector2(1, -0.15), 20, 100.0)
				"prop":
					# 프랍 앞을 가로질러 분사 — 프랍 앞면/뒷벽이 섞여야 하는 상황
					var o2 := Vector2(a2.x + 430.0, a2.y - 40.0)
					_focus = a2
					r3.add_spray(o2, Vector2(-1, -0.1), 30, 460.0, 1.1)
					r3.add_stain(a2 + Vector2(-20, 0), Vector2(1, -0.15), 22, 110.0)
				"front":
					# ⑥ 근경 방울 — 확률(FRONT_CHANCE)에 기대지 않고 직접 불러 확인한다
					_focus = Vector2(a2.x + 240.0, a2.y - 40.0)
					for i in range(4):
						r3.add_spray(Vector2(a2.x + 520.0, a2.y - 30.0), Vector2(-1, -0.1), 10, 320.0, 1.2)
						BloodStain._front_drops(r3.foreground, Vector2(a2.x + 380.0, a2.y - 40.0), Vector2(-1, -0.1), 320.0)
				"floor":
					# 바닥 가까이 — 바닥면에 떨어진 것도 지금은 벽처럼 서 있다
					var o3 := Vector2(a2.x + 300.0, r3.floor_y - 110.0)
					_focus = Vector2(a2.x + 60.0, r3.floor_y - 90.0)
					r3.add_spray(o3, Vector2(-1, 0.45), 28, 340.0, 1.2)
					r3.add_stain(Vector2(a2.x, r3.floor_y - 8.0), Vector2(1, 0.0), 16, 90.0)
		"shot":
			var img := root.get_viewport().get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			var name := "stain_%s_%s" % [tag, parts[1]]
			img.save_png(OUT + name + ".png")
			# 자국 주변만 4배 확대 크롭 (저해상도 월드 뷰포트를 직접 캡처해야 월드→픽셀이 정확하다)
			var wimg: Image = main.world_vp.get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				wimg.convert(Image.FORMAT_RGBA8)
				wimg.linear_to_srgb()
			var wsize := wimg.get_size()
			var c: Vector2 = main.world_vp.get_canvas_transform() * _focus
			var half := Vector2i(190, 120)
			var o := (Vector2i(c) - half).clamp(Vector2i.ZERO, (wsize - half * 2).max(Vector2i.ZERO))
			var box := Rect2i(o, half * 2).intersection(Rect2i(Vector2i.ZERO, wsize))
			if box.size.x > 0 and box.size.y > 0:
				var crop := wimg.get_region(box)
				crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
				crop.save_png(OUT + name + "_zoom.png")
			print("SHOT %s" % name)
		"quit":
			print("STAIN SHOT DONE (%s)" % tag)
			return true
	return false
