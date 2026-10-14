class_name PlayerVisual
extends AnimatedSprite2D
## The hero's hand-drawn animations: Hero Knight by Sven Thole (see art/hero_knight/CREDITS.md).
## Reads the player's state and plays the matching animation; attacks and the roll are
## stretched to last exactly as long as the gameplay action.

const ART_DIR := "res://art/hero_knight"
const FRAME := Vector2i(100, 55)
## Where the feet sit inside each frame, in art pixels (art data, not gameplay).
const FEET := Vector2(40.0, 53.0)
const ANIMS := {
	&"idle": {"dir": "Idle", "count": 8, "fps": 10.0, "loop": true},
	&"run": {"dir": "Run", "count": 10, "fps": 18.0, "loop": true},
	&"jump": {"dir": "Jump", "count": 3, "fps": 14.0, "loop": false},
	&"fall": {"dir": "Fall", "count": 4, "fps": 10.0, "loop": true},
	&"roll": {"dir": "Roll", "count": 9, "fps": 28.0, "loop": false},
	&"hurt": {"dir": "Hurt", "count": 3, "fps": 12.0, "loop": false},
	&"death": {"dir": "Death", "count": 10, "fps": 10.0, "loop": false},
	&"attack1": {"dir": "Attack1", "count": 6, "fps": 20.0, "loop": false},
	&"attack2": {"dir": "Attack2", "count": 6, "fps": 20.0, "loop": false},
	&"attack3": {"dir": "Attack3", "count": 8, "fps": 20.0, "loop": false},
}
## These play over exactly the action's duration instead of their own frame rate.
const FITTED: Array[StringName] = [&"roll", &"attack1", &"attack2", &"attack3"]
const COMBO_ANIMS: Array[StringName] = [&"attack1", &"attack2", &"attack3"]

const State := PlayerStateMachine.PlayerState


func _ready() -> void:
	centered = false
	sprite_frames = _build_frames()
	play(&"idle")


## feet_y: where the player's feet are, relative to the player's origin.
## action_seconds: how long the current attack or roll lasts, so its frames fit exactly.
func show_state(state: State, facing: float, feet_y: float, action_seconds: float, combo_step: int = 0, dead: bool = false) -> void:
	var anim := &"death" if dead else animation_for(state, combo_step)
	if anim != animation:
		if anim in FITTED and action_seconds > 0.0:
			sprite_frames.set_animation_speed(anim, ANIMS[anim]["count"] / action_seconds)
		play(anim)
	flip_h = facing < 0.0
	position = Vector2(-(FRAME.x - FEET.x) if flip_h else -FEET.x, feet_y - FEET.y)


static func animation_for(state: State, combo_step: int) -> StringName:
	match state:
		State.RUN: return &"run"
		State.JUMP: return &"jump"
		State.FALL: return &"fall"
		State.ROLL: return &"roll"
		State.ATTACK: return COMBO_ANIMS[combo_step % COMBO_ANIMS.size()]
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
			frames.add_frame(anim, load("%s/%s/HeroKnight_%s_%d.png" % [ART_DIR, spec["dir"], spec["dir"], i]))
	return frames
