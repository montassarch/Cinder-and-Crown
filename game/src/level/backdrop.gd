class_name Backdrop
extends Node2D
## The ruined cathedral hall behind the action: four parallax layers (deeper = slower),
## a drifting haze band, flickering braziers and rising embers. Art comes from
## tools/art/cathedral.py. Everything sits behind the player (negative z).

const DIR := "res://art/cathedral"
const LAYERS := [
	{"name": "Far", "file": "layer_far", "scale": 0.12, "z": -100},
	{"name": "MidFar", "file": "layer_mid_far", "scale": 0.3, "z": -90},
	{"name": "Mid", "file": "layer_mid", "scale": 0.55, "z": -80},
	{"name": "Near", "file": "layer_near", "scale": 0.8, "z": -60},
]
const FOG_SCALE: float = 0.7
const FOG_DRIFT: float = -5.0
const FOG_Y: float = 130.0
const REPEATS: int = 4
## Brazier positions in the Mid layer's own pixels (the layer repeats every 384 px).
const BRAZIER_X: Array[float] = [96.0, 352.0]
const BRAZIER_BOWL_Y: float = 158.0
const FLAME_FPS: float = 9.0
const EMBER_COUNT: int = 36

var _layers: Array[Parallax2D] = []
var _flames: Array[AnimatedSprite2D] = []
var _embers: CPUParticles2D


func _ready() -> void:
	for spec in LAYERS:
		_layers.append(_make_layer(spec))
	_make_fog()
	_make_braziers(_layers[2])
	_make_embers()


func layers() -> Array[Parallax2D]:
	return _layers


func flames() -> Array[AnimatedSprite2D]:
	return _flames


func embers() -> CPUParticles2D:
	return _embers


func _make_layer(spec: Dictionary) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.name = spec["name"]
	layer.scroll_scale = Vector2(spec["scale"], 1.0)
	layer.z_index = spec["z"]
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = load("%s/%s.png" % [DIR, spec["file"]])
	sprite.centered = false
	layer.add_child(sprite)
	layer.repeat_size = Vector2(sprite.texture.get_width(), 0.0)
	layer.repeat_times = REPEATS
	add_child(layer)
	return layer


func _make_fog() -> void:
	var fog := Parallax2D.new()
	fog.name = "Haze"
	fog.scroll_scale = Vector2(FOG_SCALE, 1.0)
	fog.autoscroll = Vector2(FOG_DRIFT, 0.0)
	fog.z_index = -70
	var sprite := Sprite2D.new()
	sprite.texture = load("%s/fog.png" % DIR)
	sprite.centered = false
	sprite.position = Vector2(0.0, FOG_Y)
	fog.add_child(sprite)
	fog.repeat_size = Vector2(sprite.texture.get_width(), 0.0)
	fog.repeat_times = REPEATS
	add_child(fog)


func _make_braziers(layer: Parallax2D) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", FLAME_FPS)
	frames.set_animation_loop(&"burn", true)
	for i in 4:
		frames.add_frame(&"burn", load("%s/flame_%d.png" % [DIR, i]))
	var glow_texture: Texture2D = load("%s/glow.png" % DIR)
	for x in BRAZIER_X:
		var glow := Sprite2D.new()
		glow.texture = glow_texture
		glow.position = Vector2(x, BRAZIER_BOWL_Y - 16.0)
		glow.material = _additive()
		layer.add_child(glow)
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.centered = false
		flame.position = Vector2(x - 7.0, BRAZIER_BOWL_Y - 17.0)
		layer.add_child(flame)
		flame.play(&"burn")
		flame.frame = int(x) % 4          # braziers flicker out of step
		_flames.append(flame)


func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _make_embers() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "EmberLayer"
	canvas.layer = 2  # above the world, below the HUD
	add_child(canvas)
	_embers = CPUParticles2D.new()
	_embers.amount = EMBER_COUNT
	_embers.lifetime = 5.0
	_embers.preprocess = 5.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2(0.15, -1.0)
	_embers.spread = 18.0
	_embers.gravity = Vector2.ZERO
	_embers.initial_velocity_min = 6.0
	_embers.initial_velocity_max = 16.0
	_embers.scale_amount_min = 1.0
	_embers.scale_amount_max = 2.0
	_embers.color = Color(1.0, 0.62, 0.25, 0.9)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	_embers.color_ramp = fade
	canvas.add_child(_embers)
	_fit_embers()
	get_viewport().size_changed.connect(_fit_embers)


## Embers rise across the whole visible screen, whatever shape the phone is.
func _fit_embers() -> void:
	var view := get_viewport().get_visible_rect().size
	_embers.position = Vector2(view.x / 2.0, view.y)
	_embers.emission_rect_extents = Vector2(view.x / 2.0, 2.0)
