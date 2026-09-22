class_name WalkerTimeline
extends Control
## 작성 도구의 시간 눈금. 데이터 수정은 하지 않고 선택한 시간만 상위 패널에 알린다.

signal seek_requested(time: float)
signal key_moved(from: float, to: float)

const LEFT := 16.0
const RIGHT := 18.0
const ACCENT := Color("72dbeb")
const KEY_COLOR := Color("f4c66a")

var _duration := 1.0
var _time := 0.0
var _keys: Array[float] = []
var _dragging := false
var _playing := false
var _drag_key_from := -1.0
var _drag_key_preview := 0.0
var _drag_key_start_x := 0.0
var _drag_key_moved := false


func _ready() -> void:
	custom_minimum_size = Vector2(240.0, 64.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "빈 곳 드래그: 시간 이동 · 다이아몬드 드래그: 키 시간 변경 · 방향키: 한 프레임 이동"


func refresh(state: Dictionary) -> void:
	_duration = maxf(float(state.get("duration", 1.0)), 0.01)
	if not _dragging:
		_time = clampf(float(state.get("time", 0.0)), 0.0, _duration)
	_playing = bool(state.get("playing", false))
	_keys.clear()
	for key in state.get("keys", []):
		_keys.append(float(key))
	queue_redraw()


func _time_to_x(value: float) -> float:
	return LEFT + clampf(value / _duration, 0.0, 1.0) * maxf(size.x - LEFT - RIGHT, 1.0)


func _x_to_time(value: float) -> float:
	return clampf((value - LEFT) / maxf(size.x - LEFT - RIGHT, 1.0), 0.0, 1.0) * _duration


func _seek(value: float) -> void:
	_time = clampf(value, 0.0, _duration)
	seek_requested.emit(_time)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_dragging = true
				_drag_key_from = -1.0
				_drag_key_moved = false
				_drag_key_start_x = mouse.position.x
				grab_focus()
				var selected_time := _x_to_time(mouse.position.x)
				var nearest := 9.0
				if absf(mouse.position.y - (size.y + 10.0) * 0.5) < 14.0:
					for key in _keys:
						var distance := absf(_time_to_x(key) - mouse.position.x)
						if distance < nearest:
							nearest = distance
							selected_time = key
							_drag_key_from = key
				_drag_key_preview = selected_time
				_seek(selected_time)
			else:
				_dragging = false
				if _drag_key_from >= 0.0 and _drag_key_moved and absf(_drag_key_preview - _drag_key_from) > 0.0001:
					var original := _drag_key_from
					var changed := _drag_key_preview
					_drag_key_from = -1.0
					key_moved.emit(original, changed)
				_drag_key_from = -1.0
				_drag_key_moved = false
				queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		if _drag_key_from >= 0.0:
			if absf(motion.position.x - _drag_key_start_x) > 3.0:
				_drag_key_moved = true
			if _drag_key_moved:
				_drag_key_preview = _x_to_time(motion.position.x)
				_time = _drag_key_preview
				queue_redraw()
		else:
			_seek(_x_to_time(motion.position.x))
		accept_event()
	elif event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				if _dragging:
					if _drag_key_from >= 0.0:
						_time = _drag_key_from
					_dragging = false
					_drag_key_from = -1.0
					_drag_key_moved = false
					queue_redraw()
					accept_event()
			KEY_LEFT:
				_seek(_time - 1.0 / 30.0)
				accept_event()
			KEY_RIGHT:
				_seek(_time + 1.0 / 30.0)
				accept_event()
			KEY_HOME:
				_seek(0.0)
				accept_event()
			KEY_END:
				_seek(_duration)
				accept_event()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var track_y := size.y - 20.0
	var top := 22.0
	var track := Rect2(Vector2(LEFT, top), Vector2(maxf(size.x - LEFT - RIGHT, 1.0), maxf(track_y - top + 9.0, 1.0)))
	draw_style_box(_box(Color("0c1522"), Color("283c4e"), 5), track)
	var slices := maxi(2, mini(12, floori(size.x / 88.0)))
	for i in range(slices + 1):
		var time := _duration * float(i) / float(slices)
		var x := _time_to_x(time)
		draw_line(Vector2(x, top), Vector2(x, track_y + 8.0), Color("263b4c"), 1.0)
		var text := "%.2f" % time
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11).x
		draw_string(font, Vector2(x - text_width * 0.5, 13.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color("8ea7ba"))
	for time in _keys:
		var shown_time := _drag_key_preview if _dragging and _drag_key_from >= 0.0 and is_equal_approx(time, _drag_key_from) else time
		var x := _time_to_x(shown_time)
		var selected := absf(shown_time - _time) <= 0.012
		var radius := 7.0 if selected else 5.5
		var y := top + (track_y + 8.0 - top) * 0.5
		var points := PackedVector2Array([Vector2(x, y - radius), Vector2(x + radius, y), Vector2(x, y + radius), Vector2(x - radius, y)])
		draw_colored_polygon(points, KEY_COLOR if selected else Color("b79556"))
		if selected:
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, Color("fff0be"), 1.5, true)
	var playhead_x := _time_to_x(_time)
	if _dragging and _drag_key_from >= 0.0 and _drag_key_moved:
		var original_x := _time_to_x(_drag_key_from)
		draw_line(Vector2(original_x, top), Vector2(original_x, track_y + 8.0), Color("796d4e"), 1.0)
		draw_line(Vector2(original_x, track_y + 12.0), Vector2(playhead_x, track_y + 12.0), KEY_COLOR, 1.0)
	draw_line(Vector2(playhead_x, top - 4.0), Vector2(playhead_x, track_y + 12.0), ACCENT, 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(playhead_x - 5.0, top - 6.0), Vector2(playhead_x + 5.0, top - 6.0), Vector2(playhead_x, top),
	]), ACCENT)
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.86, 0.92, 0.3), false, 1.0)
	if _keys.is_empty():
		var hint := "포즈를 만든 뒤  키 기록 K"
		draw_string(font, Vector2(LEFT + 12.0, track_y + 1.0), hint, HORIZONTAL_ALIGNMENT_LEFT,
			maxf(size.x - 60.0, 10.0), 12, Color("647e93"))


func _box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
