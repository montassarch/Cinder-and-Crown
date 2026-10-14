class_name PlayerVisual
extends AnimatedSprite2D
## SPIKE: the animated hero. Reads the player's state and plays the matching animation.
## The sprite sheet comes from tools/art/hero_sheet.py.

const SHEET := preload("res://art/hero/hero_sheet.png")
const CELL := Vector2i(64, 64)
## Where the feet and hips sit inside each cell, in sheet pixels (art data, not gameplay).
const FEET := Vector2(26.0, 58.0)
const ANIMS := {
	&"idle": {"row": 0, "first": 0, "count": 8, "fps": 7.0, "loop": true},
	&"run": {"row": 1, "first": 0, "count": 8, "fps": 13.0, "loop": true},
	&"jump": {"row": 2, "first": 0, "count": 1, "fps": 1.0, "loop": false},
	&"fall": {"row": 2, "first": 1, "count": 1, "fps": 1.0, "loop": false},
	&"hurt": {"row": 2, "first": 2, "count": 1, "fps": 1.0, "loop": false},
	&"attack": {"row": 3, "first": 0, "count": 4, "fps": 12.0, "loop": false},
	&"roll": {"row": 4, "first": 0, "count": 4, "fps": 12.0, "loop": false},
}
const HURT_TINT := Color(1.0, 0.55, 0.55)

const State := PlayerStateMachine.PlayerState


func _ready() -> void:
	centered = false
	sprite_frames = _build_frames()
	play(&"idle")


## feet_y: where the player's feet are, relative to the player's origin.
## action_seconds: how long the current attack or roll lasts, so its frames fit exactly.
func show_state(state: State, facing: float, feet_y: float, action_seconds: float) -> void:
	var anim := animation_for(state)
	if anim != animation:
		var spec: Dictionary = ANIMS[anim]
		if anim in [&"attack", &"roll"] and action_seconds > 0.0:
			sprite_frames.set_animation_speed(anim, spec["count"] / action_seconds)
		play(anim)
	flip_h = facing < 0.0
	position = Vector2(-(CELL.x - FEET.x) if flip_h else -FEET.x, feet_y - FEET.y)
	modulate = HURT_TINT if state == State.HURT else Color.WHITE


static func animation_for(state: State) -> StringName:
	match state:
		State.RUN: return &"run"
		State.JUMP: return &"jump"
		State.FALL: return &"fall"
		State.ROLL: return &"roll"
		State.ATTACK: return &"attack"
		State.HURT: return &"hurt"
		_: return &"idle"


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in ANIMS:
		var spec: Dictionary = ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec["fps"])
		frames.set_animation_loop(anim, spec["loop"])
		for i in spec["count"]:
			var cell := AtlasTexture.new()
			cell.atlas = SHEET
			cell.region = Rect2(Vector2((spec["first"] + i) * CELL.x, spec["row"] * CELL.y), Vector2(CELL))
			frames.add_frame(anim, cell)
	return frames
