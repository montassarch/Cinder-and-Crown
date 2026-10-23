class_name LightningArt
## The smooth, glowing lightning (art/lightning_hd, rendered in Blender by tools/art/lightning_hd_render.py): a bolt from
## the sky, lightning wrapped round the sword, and Rend's ground wave, in blue and red. The frames are drawn on black
## and added over the scene (additive blending), and they are high resolution: the game stretches to the screen's real
## pixels, so they stay crisp and smooth beside the pixel art.

const DIR := "res://art/lightning_hd"
const FRAME_COUNTS := {&"blade_blue": 8, &"blade_red": 8, &"bolt_blue": 8, &"bolt_red": 8, &"wave_red": 6}
## Texture pixels per metre of each set, and the point of the picture that is placed on the thing it belongs to:
## the blade's guard, the bolt's foot, the wave's head on the ground.
const PIXELS_PER_METRE := {&"blade": 150.0, &"bolt": 100.0, &"wave": 150.0}
const PIVOTS := {
	&"blade_blue": Vector2(106.0, 128.0), &"blade_red": Vector2(106.0, 128.0),
	&"bolt_blue": Vector2(144.0, 600.0), &"bolt_red": Vector2(144.0, 600.0),
	&"wave_red": Vector2(372.0, 280.0),
}
## The hero's art is drawn at this many pixels per metre, so lightning is scaled to match.
const GAME_PIXELS_PER_METRE: float = 25.0

static var _cache: Dictionary = {}
static var _additive: CanvasItemMaterial


## A sprite playing one lightning set ("default"), pivoted where it attaches, already scaled to the game and playing.
static func sprite(art: StringName, fps: float, loop: bool) -> AnimatedSprite2D:
	var node := AnimatedSprite2D.new()
	node.sprite_frames = frames(art, fps, loop)
	node.centered = false
	node.offset = -PIVOTS[art]
	node.scale = Vector2.ONE * scale_for(art)
	node.material = additive()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.play(&"default")
	return node


static func scale_for(art: StringName) -> float:
	return GAME_PIXELS_PER_METRE / float(PIXELS_PER_METRE[StringName(String(art).get_slice("_", 0))])


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


static func frames(art: StringName, fps: float, loop: bool) -> SpriteFrames:
	var key := "%s/%s/%s" % [art, fps, loop]
	if _cache.has(key):
		return _cache[key]
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	result.add_animation(&"default")
	result.set_animation_speed(&"default", fps)
	result.set_animation_loop(&"default", loop)
	for i in FRAME_COUNTS[art]:
		result.add_frame(&"default", load("%s/%s_%d.png" % [DIR, art, i]))
	_cache[key] = result
	return result
