extends SceneTree
## 총구 라이트 세기 · 몬스터 사망 체액 폭발(GoreBurst) 확인용 자동 스크린샷 (2026-09-24).
## (A) 쏘기 직전 / 쏜 직후(라이트를 최고 세기로 붙잡은 상태) 두 장 — 주변이 얼마나 붉게 물드는지
## (B) 크롤러를 한 발에 죽이고 0.03 · 0.08 · 0.2 · 0.5초 뒤 — 체액 폭발이 퍼지는 모양
## 실행: godot --path . --script res://tools/gore_muzzle_shot.gd -- <태그>   (렌더 필요 — --headless 금지)
## 저장: user://shots/gore_<태그>_*.png

const OUT := "user://shots/"

var tag := "after"
var main: Node2D
var t := 0.0
var step := 0
var steps := [
	[0.60, "setup"],
	[1.20, "shot:a_idle"],
	[1.25, "fire"],
	[1.26, "hold"],
	[1.70, "shot:a_fire"],
	[1.75, "release"],
	[1.90, "spawn"],
	[2.40, "kill"],
	[2.43, "shot:b_003"],
	[2.48, "shot:b_008"],
	[2.60, "shot:b_020"],
	[2.90, "shot:b_050"],
	[3.20, "quit"],
]
var _crawler: Node2D


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


func _do(cmd: String) -> bool:
	var parts := cmd.split(":")
	var r = main.current_room
	match parts[0]:
		"setup":
			r.disable_monsters()
			main.player.position.x = r.width * 0.35
			main.camera.lead_enabled = false
			main.camera.target = main.player
			main.camera.snap()
		"fire":
			main.player.aim_target = main.player.position + Vector2(700, -120)
			main.player._fire()
			print("FIRE light=%s energy=%.2f" % [main.player.muzzle_light.enabled, main.player.muzzle_light.energy])
		"hold":
			# 한 발짜리 라이트는 캡처 프레임과 어긋나기 쉬워, 최고 세기로 잠시 붙잡아 둔다
			main.player._muzzle_light_t = 99.0
		"release":
			main.player._muzzle_light_t = 0.0
		"spawn":
			_crawler = r._add_crawler(main.player.position.x + 520.0, -1)
		"kill":
			# 고정 시드 — 수정 전후를 같은 비산으로 비교한다 (GORE_SEED 환경변수로 바꿀 수 있다)
			seed(int(OS.get_environment("GORE_SEED")) if OS.get_environment("GORE_SEED") != "" else 20260924)
			if _crawler != null and is_instance_valid(_crawler):
				_crawler.set("hp", 1)
				_crawler.hit(_crawler.hit_center(), 1.0, 1.0)
		"shot":
			var img := root.get_viewport().get_texture().get_image()
			if ProjectSettings.get_setting("rendering/viewport/hdr_2d", false):
				img.convert(Image.FORMAT_RGBA8)
				img.linear_to_srgb()
			var name := "gore_%s_%s" % [tag, parts[1]]
			img.save_png(OUT + name + ".png")
			print("SHOT %s" % name)
		"quit":
			print("GORE SHOT DONE (%s)" % tag)
			return true
	return false
