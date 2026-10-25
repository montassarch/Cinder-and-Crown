class_name FxArt
## The combat effect sprites (art/fx, rendered in Blender by tools/art/fx_render.py): three slash arcs, a hit spark and
## a shock ring. White and glowing on black, so they are added over the scene (additive blending) and tinted with a
## colour. They are drawn at 150 px per metre and scaled to the hero's 25, and stay crisp because the game stretches
## to the screen's real pixels.

const DIR := "res://art/fx"
const FRAME_COUNTS := {&"slash_a": 6, &"slash_b": 6, &"slash_c": 6, &"spark": 7, &"ring": 6}
const FRAME_SIZES := {
	&"slash_a": Vector2i(512, 512), &"slash_b": Vector2i(512, 512), &"slash_c": Vector2i(512, 512),
	&"spark": Vector2i(384, 384), &"ring": Vector2i(384, 384),
}
## The point of each picture that is placed where the effect happens (its centre).
const PIVOTS := {
	&"slash_a": Vector2(256.0, 256.0), &"slash_b": Vector2(256.0, 256.0), &"slash_c": Vector2(256.0, 256.0),
	&"spark": Vector2(192.0, 192.0), &"ring": Vector2(192.0, 192.0),
}
const PIXELS_PER_METRE: float = 150.0
const GAME_PIXELS_PER_METRE: float = 25.0

static var _cache: Dictionary = {}
static var _additive: CanvasItemMaterial


static func scale_for(_art: StringName) -> float:
	return GAME_PIXELS_PER_METRE / PIXELS_PER_METRE


## A sprite set up for one effect: pivoted at its centre, scaled to the game, added over the scene, playing once.
static func sprite(art: StringName, fps: float) -> AnimatedSprite2D:
	var node := AnimatedSprite2D.new()
	node.sprite_frames = frames(art, fps)
	node.centered = false
	node.offset = -PIVOTS[art]
	node.scale = Vector2.ONE * scale_for(art)
	node.material = additive()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.play(&"default")
	return node


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


static func frames(art: StringName, fps: float) -> SpriteFrames:
	var key := "%s/%s" % [art, fps]
	if _cache.has(key):
		return _cache[key]
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	result.add_animation(&"default")
	result.set_animation_speed(&"default", fps)
	result.set_animation_loop(&"default", false)
	for i in FRAME_COUNTS[art]:
		result.add_frame(&"default", load("%s/%s_%d.png" % [DIR, art, i]))
	_cache[key] = result
	return result
