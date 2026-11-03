class_name LibraryFx
## Effects from the free packs in art/library/vfx (see Design/Assets/CREDITS.md): each pack has a meta.json listing its
## effects (frame count, size, fps, pivot, blend) and a folder of numbered PNG frames per effect. They are pixel art at
## the game's own scale. A cue names one effect as "<pack>/<effect>".

const DIR := "res://art/library/vfx"

static var _meta: Dictionary = {}
static var _frames: Dictionary = {}


static func has_pack(pack: String) -> bool:
	return not _pack(pack).is_empty()


static func effects(pack: String) -> Array:
	return (_pack(pack).get("effects", {}) as Dictionary).keys()


static func info(pack: String, effect: String) -> Dictionary:
	return (_pack(pack).get("effects", {}) as Dictionary).get(effect, {})


static func has_cue(cue: String) -> bool:
	var parts := cue.split("/")
	return parts.size() == 2 and not info(parts[0], parts[1]).is_empty()


## The effect's frames as one animation, "play"; null when the pack or the effect is not there.
static func frames(pack: String, effect: String, loop: bool = false) -> SpriteFrames:
	var key := "%s/%s/%s" % [pack, effect, loop]
	if _frames.has(key):
		return _frames[key]
	var spec := info(pack, effect)
	if spec.is_empty():
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	sf.add_animation(&"play")
	sf.set_animation_loop(&"play", loop)
	sf.set_animation_speed(&"play", float(spec.get("fps", 12)))
	for i in int(spec["frames"]):
		var tex := load("%s/%s/%s/%d.png" % [DIR, pack, effect, i]) as Texture2D
		if tex == null:
			return null
		sf.add_frame(&"play", tex)
	_frames[key] = sf
	return sf


## A sprite for `cue`, pivoted where the pack says (its centre of action sits on the node's origin); null if missing.
static func sprite(cue: String, loop: bool = false) -> AnimatedSprite2D:
	var parts := cue.split("/")
	if parts.size() != 2:
		return null
	var sf := frames(parts[0], parts[1], loop)
	if sf == null:
		return null
	var spec := info(parts[0], parts[1])
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.centered = false
	var pivot: Array = spec.get("pivot", [0, 0])
	s.offset = -Vector2(float(pivot[0]), float(pivot[1]))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * float(spec.get("draw_scale", 1.0))
	if spec.get("blend", "") == "add":
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = glow
	s.set_meta(&"library_fx", cue)
	return s


## Plays `cue` once at `at` (mirrored when facing left) over the scene, then removes it. Null when it is missing.
static func spawn(parent: Node, cue: String, at: Vector2, facing_left: bool = false, size: float = 1.0, tint: Color = Color.WHITE) -> AnimatedSprite2D:
	var s := sprite(cue)
	if s == null:
		return null
	s.z_index = 21
	s.scale *= size
	if facing_left:
		s.scale.x = -s.scale.x
	s.modulate = tint
	s.animation_finished.connect(s.queue_free)
	parent.add_child(s)
	s.global_position = at
	s.play(&"play")
	return s


static func _pack(pack: String) -> Dictionary:
	if _meta.has(pack):
		return _meta[pack]
	var path := "%s/%s/meta.json" % [DIR, pack]
	var found := {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			found = parsed
	_meta[pack] = found
	return found
