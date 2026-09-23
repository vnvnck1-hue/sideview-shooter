@tool
extends Node2D
## Detachable fixture sprite with an actual Godot 2D light.
## The picture contains the bulb and its casing; illumination is provided here.

@export var fixture_texture: Texture2D:
	set(value):
		fixture_texture = value
		if is_instance_valid(_fixture):
			_fixture.texture = value
@export var emitter_offset := Vector2.ZERO:
	set(value):
		emitter_offset = value
		if is_instance_valid(_light):
			_light.position = value
@export var light_color := Color(1.0, 0.84, 0.58):
	set(value):
		light_color = value
		if is_instance_valid(_light):
			_light.color = value
@export_range(32.0, 800.0, 1.0) var light_radius := 190.0:
	set(value):
		light_radius = value
		if is_instance_valid(_light):
			_light.texture_scale = value * 2.0 / 256.0
@export_range(0.0, 3.0, 0.01) var light_energy := 0.85:
	set(value):
		light_energy = value
		if is_instance_valid(_light):
			_light.energy = value
@export var light_enabled := true:
	set(value):
		light_enabled = value
		if is_instance_valid(_light):
			_light.enabled = value

var _fixture: Sprite2D
var _light: PointLight2D


func _ready() -> void:
	_fixture = Sprite2D.new()
	_fixture.name = "FixtureSprite"
	_fixture.centered = false
	_fixture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fixture.texture = fixture_texture
	add_child(_fixture)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.34, Color(1, 1, 1, 0.55))
	gradient.add_point(0.68, Color(1, 1, 1, 0.16))
	var falloff := GradientTexture2D.new()
	falloff.gradient = gradient
	falloff.width = 256
	falloff.height = 256
	falloff.fill = GradientTexture2D.FILL_RADIAL
	falloff.fill_from = Vector2(0.5, 0.5)
	falloff.fill_to = Vector2(1.0, 0.5)

	_light = PointLight2D.new()
	_light.name = "EngineLight"
	_light.position = emitter_offset
	_light.texture = falloff
	_light.texture_scale = light_radius * 2.0 / 256.0
	_light.color = light_color
	_light.energy = light_energy
	_light.enabled = light_enabled
	_light.shadow_enabled = false
	add_child(_light)
