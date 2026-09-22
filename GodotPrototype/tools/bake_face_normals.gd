extends SceneTree
## 손으로 나눈 면 맵을 실제 노멀맵 자산으로 굽는다 (헤드리스).
## 실행:  godot --path . --headless --script res://tools/bake_face_normals.gd -- [자산경로 ...]
##
## assets/faces/ 아래의 면 맵을 전부 찾아 같은 이름의 원화·자동 노멀과 합쳐
## assets/normals/<같은 상대경로> 에 덮어쓴다. Lighting.textured 가 읽는 자리가 거기라
## 굽고 나면 게임 코드는 건드릴 것 없이 그대로 적용된다.
##
## 수치(tilt·detail)는 면 랩이 Ctrl+S 로 저장한 faces/tuning.json 을 읽는다 — 랩에서 맞춘 값이 그대로 온다.
## 환경변수로 덮어쓸 수 있다: FACE_TILT=50 FACE_DETAIL=0.3
##
## Tools/build_normal_maps.py 는 면 맵이 있는 파일을 건너뛰므로, 자동 베이커를 다시 돌려도 여기서 구운 것이
## 덮어써지지 않는다. 면을 다시 나눴으면 이 도구를 다시 돌리면 된다.
##
## 굽기 전에 눈으로 맞추는 곳: scripts/face_lab.gd (로비 → "면 라이팅 랩"). 규약은 scripts/face_normal.gd.

func _init() -> void:
	var only := []
	for a in OS.get_cmdline_user_args():
		only.append(String(a))

	# 수치는 자산마다 다를 수 있으므로(faces/tuning.json 의 "assets") 기본은 NAN 을 넘겨 자산별 값을 쓰게 한다.
	# 환경변수를 준 경우에만 전부 그 값으로 강제한다 — A/B 로 한 번에 훑어볼 때 쓴다.
	var tilt := NAN
	var detail := NAN
	if OS.get_environment("FACE_TILT") != "":
		tilt = float(OS.get_environment("FACE_TILT"))
	if OS.get_environment("FACE_DETAIL") != "":
		detail = float(OS.get_environment("FACE_DETAIL"))
	var forced := not (is_nan(tilt) and is_nan(detail))
	print("면 노멀 베이커 — %s (기본 tilt %.1f°  detail %.2f  soft %.0fpx)" % [
		"환경변수로 강제" if forced else "자산별 수치",
		FaceNormal.tuning()["tilt"], FaceNormal.tuning()["detail"], FaceNormal.tuning()["soft"]])

	var faces := []
	_scan(FaceNormal.FACE_DIR, faces)
	if faces.is_empty():
		print("assets/faces/ 에 면 맵이 없다. 면 랩에서 T 로 템플릿을 만들고 칠한 뒤 다시 돌려라.")
		quit(0)
		return

	var done := 0
	var failed := 0
	for face_res in faces:
		# assets/faces/props/foo.png → assets/props/foo.png
		var rel: String = face_res.trim_prefix(FaceNormal.FACE_DIR)
		var diffuse := FaceNormal.ASSET_DIR + rel
		if not only.is_empty() and not _matches(only, rel, diffuse):
			continue
		if not FileAccess.file_exists(ProjectSettings.globalize_path(diffuse)):
			printerr("  원화 없음: %s  (면 맵 %s)" % [diffuse, face_res])
			failed += 1
			continue
		var img := FaceNormal.bake_for(diffuse, tilt, detail)
		if img == null:
			printerr("  굽기 실패: %s" % diffuse)
			failed += 1
			continue
		var dst := FaceNormal.normal_path(diffuse)
		var abs := ProjectSettings.globalize_path(dst)
		DirAccess.make_dir_recursive_absolute(abs.get_base_dir())
		if img.save_png(abs) != OK:
			printerr("  저장 실패: %s" % dst)
			failed += 1
			continue
		var used := FaceNormal.tuning_for(diffuse)
		print("  %s → %s   (tilt %.0f° detail %.2f soft %.0fpx%s)" % [rel, dst,
			used["tilt"] if is_nan(tilt) else tilt, used["detail"] if is_nan(detail) else detail, used["soft"],
			" 자산별" if FaceNormal.has_override(diffuse) and not forced else ""])
		done += 1

	print("완료: %d 개 구움%s" % [done, ("  ·  실패 %d" % failed) if failed > 0 else ""])
	quit(1 if failed > 0 else 0)


func _matches(only: Array, rel: String, diffuse: String) -> bool:
	for o in only:
		if rel.contains(o) or diffuse.contains(o):
			return true
	return false


func _scan(dir_path: String, out: Array) -> void:
	var abs := ProjectSettings.globalize_path(dir_path)
	var d := DirAccess.open(abs)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.begins_with("."):
			name = d.get_next()
			continue
		if d.current_is_dir():
			_scan(dir_path.path_join(name), out)
		elif name.get_extension().to_lower() == "png":
			out.append(dir_path.path_join(name))
		name = d.get_next()
	d.list_dir_end()
	out.sort()
