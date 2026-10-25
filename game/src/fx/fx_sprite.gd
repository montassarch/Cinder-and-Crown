class_name FxSprite
## Spawns a one-shot effect: it plays its frames once and removes itself.

const DEFAULT_FPS: float = 24.0


## `facing_left` mirrors the art about its pivot (the art is drawn facing right). `tint` colours the white art.
static func spawn(parent: Node, art: StringName, at: Vector2, rotation: float = 0.0, facing_left: bool = false, tint: Color = Color.WHITE, scale_multiplier: float = 1.0, fps: float = DEFAULT_FPS) -> AnimatedSprite2D:
	var fx := FxArt.sprite(art, fps)
	fx.z_index = 20
	fx.set_meta(&"fx_art", art)
	fx.modulate = tint
	var size := FxArt.scale_for(art) * scale_multiplier
	fx.scale = Vector2(-size if facing_left else size, size)
	fx.animation_finished.connect(fx.queue_free)
	parent.add_child(fx)
	fx.global_position = at
	fx.rotation = rotation
	return fx
