class_name LightningArt
## The pre-rendered lightning sprites (art/lightning, made in Blender by tools/art/lightning_render.py):
## a tall bolt and a small sword crackle in blue and red, and Rend's red wave head.
## Playing frames is far cheaper than drawing jagged lines every tick.

const DIR := "res://art/lightning"
const FRAME_COUNTS := {&"bolt_blue": 8, &"bolt_red": 8, &"crackle_blue": 6, &"crackle_red": 6, &"wave_red": 6}

static var _cache: Dictionary = {}


## An AnimatedSprite2D set up with one lightning animation ("default"), already playing.
static func sprite(art: StringName, fps: float, loop: bool) -> AnimatedSprite2D:
	var node := AnimatedSprite2D.new()
	node.sprite_frames = frames(art, fps, loop)
	node.play(&"default")
	return node


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
