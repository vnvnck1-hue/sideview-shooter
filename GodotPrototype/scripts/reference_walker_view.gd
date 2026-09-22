class_name ReferenceWalkerView
extends Node2D
## 원화 기준 뼈대의 읽기 전용 그림. 모든 관절은 walker가 제공한 실제 자세를 따른다.
## walker의 직계 자식 / identity transform으로 사용한다. 텍스처, yaw 사영, IK 보정은 하지 않는다.

const CHASSIS := Color("f4c66a")
const TORSO := Color("b08cff")
const GUN := Color("7ddcf9")
const UPPER := Color("f28b73")
const LOWER := Color("83c984")
const FOOT := Color("78aef9")
const OUTLINE := Color("111924")
const LABEL := Color("f1f4fa")

var walker: Node2D
var show_labels := true
var show_targets := false
var leg_filter := "all"
## 선 굵기 / 글자 크기에만 적용한다. 뼈 길이와 관절 위치는 절대 바꾸지 않는다.
var visual_scale := 1.0

var _font: Font
var _parent_to_local := Transform2D.IDENTITY


func _ready() -> void:
	if walker == null:
		walker = get_parent() as Node2D
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(walker) or not walker.has_method("pose_legs") or not walker.has_method("pose_body"):
		return
	_parent_to_local = walker.transform.affine_inverse()
	var legs: Array = walker.call("pose_legs")
	var body: Dictionary = walker.call("pose_body")
	# 실제 깊이 순서만 사용한다. 관절을 화면용으로 재배치하지 않는다.
	for leg in legs:
		if _visible_leg(leg) and bool(leg.get("far", false)):
			_draw_leg(leg, body)
	_draw_body(body)
	for leg in legs:
		if _visible_leg(leg) and not bool(leg.get("far", false)):
			_draw_leg(leg, body)
	if show_labels:
		# 태그는 모든 뼈대 뒤에 그려 연결부에 가려지지 않게 한다.
		for leg in legs:
			if _visible_leg(leg):
				_draw_leg_tag(leg)


func _visible_leg(leg: Dictionary) -> bool:
	return leg_filter == "all" or leg_filter == str(leg.get("id", ""))


func _point(value: Vector2) -> Vector2:
	return _parent_to_local * value


func _draw_leg(leg: Dictionary, body: Dictionary) -> void:
	if not leg.has_all(["hip", "knee", "ankle", "toe"]):
		return
	var hip := _point(leg["hip"])
	var knee := _point(leg["knee"])
	var ankle := _point(leg["ankle"])
	var toe := _point(leg["toe"])
	var far := bool(leg.get("far", false))
	var inferred := bool(leg.get("inferred", false))
	# 축이 가려진 것과 다리 전체가 추정인 것은 구별한다. 전자는 관절 링만 표시한다.
	var uncertain: Array = leg.get("uncertain", [])
	var upper := _depth_color(UPPER, far)
	var lower := _depth_color(LOWER, far)
	var foot := _depth_color(FOOT, far)
	var mount_color := _depth_color(CHASSIS, far)
	if leg.has("mount"):
		var mount := _point(leg["mount"])
		if body.has("chassis"):
			_dashed(_point(body["chassis"]), mount, mount_color, 1.6 * visual_scale)
		_bone(mount, hip, mount_color, 13.0 * visual_scale, inferred)
		_joint(mount, mount_color, 6.0 * visual_scale, "0", inferred or "mount" in uncertain)
	elif body.has("chassis"):
		# 원화에서 내부 부모 연결부는 보이지 않으므로 관측된 뼈처럼 실선으로 단정하지 않는다.
		_dashed(_point(body["chassis"]), hip, _depth_color(CHASSIS, far), 2.0 * visual_scale)
	_bone(hip, knee, upper, 18.0 * visual_scale, inferred)
	_bone(knee, ankle, lower, 32.0 * visual_scale, inferred)
	_bone(ankle, toe, foot, 19.0 * visual_scale, inferred)
	_joint(hip, upper, 9.0 * visual_scale, "1", inferred or "hip" in uncertain)
	_joint(knee, lower, 10.0 * visual_scale, "2", inferred or "knee" in uncertain)
	_joint(ankle, foot, 8.5 * visual_scale, "3", inferred or "ankle" in uncertain)
	_joint(toe, foot, 6.0 * visual_scale, "4", inferred or "toe" in uncertain)
	if show_targets:
		var target := _point(leg.get("target", leg["toe"]))
		var planted := bool(leg.get("planted", false))
		var color := foot if planted else Color("e1bd85")
		draw_arc(target, 15.0 * visual_scale, 0.0, TAU, 28, color, 1.4 * visual_scale, true)
		draw_line(target - Vector2(20.0, 0.0) * visual_scale, target + Vector2(20.0, 0.0) * visual_scale,
			color, 1.4 * visual_scale, true)
		if not planted:
			var progress := clampf(float(leg.get("progress", 0.0)), 0.0, 1.0)
			draw_arc(target, 19.0 * visual_scale, -PI * 0.5, -PI * 0.5 + TAU * progress,
				28, color, 2.5 * visual_scale, true)


func _draw_body(body: Dictionary) -> void:
	if not body.has_all(["chassis", "pivot", "gun", "muzzle"]):
		return
	var chassis := _point(body["chassis"])
	var pivot := _point(body["pivot"])
	var gun := _point(body["gun"])
	var muzzle := _point(body["muzzle"])
	var upper_center := _point(body.get("upper_center", body["pivot"]))
	var barrel := _point(body.get("barrel", body["gun"]))
	_bone(chassis, pivot, CHASSIS, 28.0 * visual_scale, false)
	if body.has("upper_center"):
		_bone(pivot, upper_center, TORSO, 28.0 * visual_scale, false)
		_joint(upper_center, TORSO, 9.0 * visual_scale, "", false)
	# 본체 중심과 작은 포가 축의 부모 연결은 내부에 숨겨져 있다. 총구로 직접 잇지 않는다.
	_dashed(upper_center, gun, TORSO, 1.8 * visual_scale)
	if body.has("barrel"):
		_bone(gun, barrel, GUN, 13.0 * visual_scale, false)
		_pivot_ring(barrel, GUN, 8.0 * visual_scale)
	_bone(barrel, muzzle, GUN, 22.0 * visual_scale, false)
	# 루트 십자와 회전축 링을 구별해 고정 몸통 길이의 시작점을 읽을 수 있게 한다.
	_root_marker(chassis)
	_pivot_ring(pivot, TORSO, 14.0 * visual_scale)
	_pivot_ring(gun, GUN, 10.0 * visual_scale)
	var direction := (muzzle - barrel).normalized()
	var cross := Vector2(-direction.y, direction.x) * 9.0 * visual_scale
	draw_line(muzzle - cross, muzzle + cross, OUTLINE, 7.0 * visual_scale, true)
	draw_line(muzzle - cross, muzzle + cross, GUN, 3.5 * visual_scale, true)
	if show_labels:
		_pill(chassis + Vector2(-24.0, 21.0) * visual_scale, "C0", CHASSIS)
		_pill(pivot + Vector2(17.0, -21.0) * visual_scale, "T0", TORSO)
		_pill(gun + Vector2(14.0, 15.0) * visual_scale, "G0", GUN)
		if body.has("upper_center"):
			_pill(upper_center + Vector2(13.0, -24.0) * visual_scale, "U0", TORSO)
		if body.has("barrel"):
			_pill(barrel + Vector2(9.0, -25.0) * visual_scale, "B0", GUN)
		_pill(muzzle + Vector2(0.0, -27.0) * visual_scale, "M0", GUN)


func _bone(a: Vector2, b: Vector2, color: Color, width: float, inferred: bool) -> void:
	var delta := b - a
	var span := delta.length()
	if span < 0.01:
		return
	var normal := Vector2(-delta.y, delta.x) / span
	var shoulder := a + delta * 0.24
	var half := minf(width * 0.5, span * 0.20)
	var points := PackedVector2Array([a, shoulder + normal * half, b, shoulder - normal * half])
	var closed := PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	if inferred:
		var ghost := color
		ghost.a = 0.16
		draw_colored_polygon(points, ghost)
		for i in range(4):
			_dashed(points[i], points[(i + 1) % 4], color, 1.8 * visual_scale)
		_dashed(a, b, color, 2.3 * visual_scale)
	else:
		draw_colored_polygon(points, color)
		draw_polyline(closed, OUTLINE, 3.6 * visual_scale, true)
		var highlight := color.lightened(0.15)
		draw_line(a + delta * 0.08, b - delta * 0.08, highlight, 1.3 * visual_scale, true)


func _dashed(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var span := a.distance_to(b)
	if span < 0.01:
		return
	var direction := (b - a) / span
	var cursor := 0.0
	var dash := 7.0 * visual_scale
	var gap := 5.0 * visual_scale
	while cursor < span:
		var end := minf(cursor + dash, span)
		var start_point := a + direction * cursor
		var end_point := a + direction * end
		draw_line(start_point, end_point, OUTLINE, width + 2.6 * visual_scale, true)
		draw_line(start_point, end_point, color, width, true)
		cursor += dash + gap


func _joint(at: Vector2, color: Color, radius: float, number: String, inferred: bool) -> void:
	draw_circle(at, radius + 2.0 * visual_scale, OUTLINE)
	draw_circle(at, radius, color)
	draw_circle(at, radius * 0.60, OUTLINE)
	if inferred:
		draw_arc(at, radius + 4.0 * visual_scale, -PI * 0.85, -PI * 0.2, 12, color, 1.2 * visual_scale, true)
	else:
		draw_circle(at, 2.2 * visual_scale, color)
	if show_labels and not number.is_empty():
		var size := maxi(9, roundi(10.0 * visual_scale))
		var text_width := _font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		var pos := at + Vector2(radius + 5.0 * visual_scale, -radius - 2.0 * visual_scale)
		draw_string_outline(_font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, text_width, size, maxi(2, roundi(3.0 * visual_scale)), OUTLINE)
		draw_string(_font, pos, number, HORIZONTAL_ALIGNMENT_LEFT, text_width, size, LABEL)


func _root_marker(at: Vector2) -> void:
	var radius := 11.0 * visual_scale
	draw_circle(at, radius + 3.0 * visual_scale, OUTLINE)
	draw_circle(at, radius, CHASSIS)
	draw_circle(at, radius * 0.65, OUTLINE)
	draw_line(at - Vector2(radius + 5.0 * visual_scale, 0.0), at + Vector2(radius + 5.0 * visual_scale, 0.0), CHASSIS, 2.0 * visual_scale, true)
	draw_line(at - Vector2(0.0, radius + 5.0 * visual_scale), at + Vector2(0.0, radius + 5.0 * visual_scale), CHASSIS, 2.0 * visual_scale, true)


func _pivot_ring(at: Vector2, color: Color, radius: float) -> void:
	draw_circle(at, radius + 3.0 * visual_scale, OUTLINE)
	draw_circle(at, radius, color)
	draw_circle(at, radius * 0.64, OUTLINE)
	draw_circle(at, radius * 0.23, color)
	draw_arc(at, radius + 5.0 * visual_scale, -PI * 0.9, -PI * 0.3, 14, color, 1.7 * visual_scale, true)


func _draw_leg_tag(leg: Dictionary) -> void:
	if not leg.has("hip"):
		return
	var id := str(leg.get("id", leg.get("label", "?"))).to_upper()
	var aliases := {"NEAR_FRONT": "NF", "NEAR_REAR": "NR", "FAR_FRONT": "FF", "FAR_REAR": "FR"}
	id = str(aliases.get(id, id))
	if bool(leg.get("inferred", false)):
		id += " est."
	var hip := _point(leg["hip"])
	var far := bool(leg.get("far", false))
	var offset := Vector2(-20.0, -33.0 if far else -22.0) * visual_scale
	_pill(hip + offset, id, _depth_color(UPPER, far))


func _pill(at: Vector2, text: String, color: Color) -> void:
	var size := maxi(11, roundi(13.0 * visual_scale))
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size)
	var padding := Vector2(7.0, 4.0) * visual_scale
	var box := Rect2(at, Vector2(text_size.x, float(size) + 2.0 * visual_scale) + padding * 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = OUTLINE
	style.border_color = color
	style.set_border_width_all(maxi(1, roundi(1.5 * visual_scale)))
	style.set_corner_radius_all(roundi(7.0 * visual_scale))
	draw_style_box(style, box)
	draw_string(_font, at + padding + Vector2(0.0, float(size)), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, LABEL)


func _depth_color(color: Color, far: bool) -> Color:
	var gain := 0.6 if far else 1.0
	return Color(color.r * gain, color.g * gain, color.b * gain, color.a)
