class_name PaintedFx
## The hand-painted effects (art/fx_painted, drawn by tools/art/toon_fx.py): full colour with transparency,
## drawn at 150 px per metre and shown at the game's 25. Floor effects stand on the floor line that sits
## FLOOR_MARGIN art pixels above the bottom of their pictures.

const DIR := "res://art/fx_painted"
const FRAME_COUNTS := {
	&"frost_blade": 9, &"tidal_slash": 7, &"arcane_ward": 6, &"ember_blade": 6, &"ember_crash": 6,
	&"fire_pillar": 8, &"lightning_strike": 6,
}
const FLOOR_MARGIN := {&"frost_blade": 30.0, &"fire_pillar": 20.0, &"ember_crash": 26.0, &"lightning_strike": 20.0, &"arcane_ward": 30.0}
const PIXELS_PER_METRE: float = 150.0
const GAME_PIXELS_PER_METRE: float = 25.0

static var _cache: Dictionary = {}


static func scale() -> float:
	return GAME_PIXELS_PER_METRE / PIXELS_PER_METRE


static func frames(art: StringName, fps: float) -> SpriteFrames:
	var key := "%s@%s" % [art, fps]
	if _cache.has(key):
		return _cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	sf.add_animation(&"play")
	sf.set_animation_loop(&"play", false)
	sf.set_animation_speed(&"play", fps)
	for i in int(FRAME_COUNTS[art]):
		sf.add_frame(&"play", load("%s/%s/%d.png" % [DIR, art, i]))
	_cache[key] = sf
	return sf


## A sprite of `art`, placed so its floor line (or its centre, for effects without one) sits at the node's origin.
static func sprite(art: StringName, fps: float = 14.0) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(art, fps)
	s.centered = true
	s.scale = Vector2.ONE * scale()
	var size := s.sprite_frames.get_frame_texture(&"play", 0).get_size()
	if FLOOR_MARGIN.has(art):
		s.offset = Vector2(0.0, -size.y / 2.0 + FLOOR_MARGIN[art])
	return s


## A painted effect that plays once where it is put and removes itself.
static func spawn(parent: Node, art: StringName, at: Vector2, facing_left: bool = false, size: float = 1.0, fps: float = 14.0) -> AnimatedSprite2D:
	var s := sprite(art, fps)
	s.z_index = 20
	s.scale = Vector2(-1.0 if facing_left else 1.0, 1.0) * scale() * size
	s.set_meta(&"painted_fx", art)
	s.animation_finished.connect(s.queue_free)
	parent.add_child(s)
	s.global_position = at
	s.play(&"play")
	return s
