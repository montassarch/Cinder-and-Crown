class_name Backdrop
extends Node2D
## The world behind the action: four parallax layers (deeper = slower), a drifting haze band, flickering lights
## (braziers, crystals, furnaces...) and the world's weather (embers, snow, ash or rain; storms also flash).
## Art comes from the world's BiomeData (painted by tools/art/cathedral.py and tools/art/biomes.py).
## Everything sits behind the player (negative z) except the weather, which drifts over the scene.

const DEFAULT_BIOME := "res://data/biomes/cathedral.tres"
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
const WEATHER_COUNT: int = 36
const RAIN_COUNT: int = 90
## A storm lights the sky up every so often.
const FLASH_GAP := Vector2(3.5, 8.0)
const FLASH_SECONDS: float = 0.35

var _biome: BiomeData
var _layers: Array[Parallax2D] = []
var _flames: Array[AnimatedSprite2D] = []
var _embers: CPUParticles2D
var _weather_canvas: CanvasLayer
var _flash_left: float = 0.0
var _next_flash: float = 0.0
var _flashes: int = 0


func _ready() -> void:
	if _biome == null:
		_biome = load(DEFAULT_BIOME)
	_build()


## Dresses the backdrop as `biome`'s world, replacing whatever it showed before.
func apply(biome: BiomeData) -> void:
	if biome == _biome and not _layers.is_empty():
		return
	_biome = biome
	if is_inside_tree():
		_clear()
		_build()


func biome() -> BiomeData:
	return _biome


func layers() -> Array[Parallax2D]:
	return _layers


func flames() -> Array[AnimatedSprite2D]:
	return _flames


## The weather particles (named for the first world's rising embers).
func embers() -> CPUParticles2D:
	return _embers


func weather_kind() -> BiomeData.Weather:
	return _biome.weather


## Storm flashes so far (storm worlds only).
func flash_count() -> int:
	return _flashes


func _process(delta: float) -> void:
	if _biome == null or _biome.weather != BiomeData.Weather.RAIN or _layers.is_empty():
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(FLASH_GAP.x, FLASH_GAP.y)
		_flash_left = FLASH_SECONDS
		_flashes += 1
	_flash_left = maxf(0.0, _flash_left - delta)
	# a double flicker: bright, dim, bright, fade
	var t := 1.0 - _flash_left / FLASH_SECONDS
	var bright := 0.0 if _flash_left <= 0.0 else (1.0 - t) * (0.6 + 0.4 * absf(sin(t * 14.0)))
	for i in 2:
		_layers[i].modulate = Color(1.0, 1.0, 1.0).lerp(Color(2.2, 2.3, 2.8), bright)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_layers.clear()
	_flames.clear()
	_embers = null


func _build() -> void:
	for spec in LAYERS:
		_layers.append(_make_layer(spec))
	_make_fog()
	_make_lights(_layers[2])
	_make_weather()
	_next_flash = randf_range(1.0, FLASH_GAP.x)


func _make_layer(spec: Dictionary) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.name = spec["name"]
	layer.scroll_scale = Vector2(spec["scale"], 1.0)
	layer.z_index = spec["z"]
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = load(_biome.art_path(spec["file"]))
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
	sprite.texture = load(_biome.art_path("fog"))
	sprite.centered = false
	sprite.position = Vector2(0.0, FOG_Y)
	fog.add_child(sprite)
	fog.repeat_size = Vector2(sprite.texture.get_width(), 0.0)
	fog.repeat_times = REPEATS
	add_child(fog)


func _make_lights(layer: Parallax2D) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"burn")
	frames.set_animation_speed(&"burn", _biome.light_fps)
	frames.set_animation_loop(&"burn", true)
	for i in 4:
		frames.add_frame(&"burn", load(_biome.art_path("%s_%d" % [_biome.light_prefix, i])))
	var glow_texture: Texture2D = load(_biome.art_path("glow"))
	var size := frames.get_frame_texture(&"burn", 0).get_size()
	for x in _biome.light_x:
		var glow := Sprite2D.new()
		glow.texture = glow_texture
		glow.position = Vector2(x, _biome.light_y - 16.0)
		glow.material = _additive()
		layer.add_child(glow)
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = frames
		flame.centered = false
		flame.position = Vector2(x - size.x / 2.0, _biome.light_y - size.y)
		layer.add_child(flame)
		flame.play(&"burn")
		flame.frame = int(x) % 4          # lights flicker out of step
		_flames.append(flame)


func _additive() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _make_weather() -> void:
	_weather_canvas = CanvasLayer.new()
	_weather_canvas.name = "EmberLayer"
	_weather_canvas.layer = 2  # above the world, below the HUD
	add_child(_weather_canvas)
	var p := CPUParticles2D.new()
	p.name = "Weather"
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.gravity = Vector2.ZERO
	p.color = _biome.weather_color
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = fade
	match _biome.weather:
		BiomeData.Weather.EMBERS:
			p.amount = WEATHER_COUNT; p.lifetime = 5.0
			p.direction = Vector2(0.15, -1.0); p.spread = 18.0
			p.initial_velocity_min = 6.0; p.initial_velocity_max = 16.0
			p.scale_amount_min = 1.0; p.scale_amount_max = 2.0
		BiomeData.Weather.ASH:
			p.amount = WEATHER_COUNT + 14; p.lifetime = 4.0
			p.direction = Vector2(0.2, -1.0); p.spread = 30.0
			p.initial_velocity_min = 10.0; p.initial_velocity_max = 30.0
			p.scale_amount_min = 1.0; p.scale_amount_max = 2.5
		BiomeData.Weather.SNOW:
			p.amount = WEATHER_COUNT + 24; p.lifetime = 9.0
			p.direction = Vector2(-0.25, 1.0); p.spread = 20.0
			p.initial_velocity_min = 8.0; p.initial_velocity_max = 18.0
			p.scale_amount_min = 1.0; p.scale_amount_max = 2.5
		BiomeData.Weather.RAIN:
			p.amount = RAIN_COUNT; p.lifetime = 1.2
			p.direction = Vector2(-0.3, 1.0); p.spread = 3.0
			p.initial_velocity_min = 170.0; p.initial_velocity_max = 220.0
			p.texture = _streak()
			p.particle_flag_align_y = true
	p.preprocess = p.lifetime
	_embers = p
	_weather_canvas.add_child(p)
	_fit_weather()
	if not get_viewport().size_changed.is_connected(_fit_weather):
		get_viewport().size_changed.connect(_fit_weather)


## A raindrop: a short vertical streak, fading at the top.
func _streak() -> Texture2D:
	var img := Image.create(1, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		img.set_pixel(0, y, Color(1, 1, 1, float(y + 1) / 7.0))
	return ImageTexture.create_from_image(img)


## Weather covers the whole visible screen, whatever shape the phone is: falling weather starts above the
## screen, rising weather below it.
func _fit_weather() -> void:
	if _embers == null:
		return
	var view := get_viewport().get_visible_rect().size
	var falls := _biome.weather in [BiomeData.Weather.SNOW, BiomeData.Weather.RAIN]
	_embers.position = Vector2(view.x / 2.0 + (view.x * 0.15 if falls else 0.0), -4.0 if falls else view.y)
	_embers.emission_rect_extents = Vector2(view.x * (0.65 if falls else 0.5), 2.0)
