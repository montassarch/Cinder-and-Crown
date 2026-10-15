class_name PlayerVisual
extends AnimatedSprite2D
## The black swordsman's hand-drawn animations: Hero Knight by Sven Thole, recolored to black
## armor (see art/black_swordsman/CREDITS.md and tools/art/black_swordsman.py).
## Every frame exists twice: plain, and with the plague mask on (worn briefly after a hit).
## Reads the player's state and plays the matching animation; attacks and the roll are
## stretched to last exactly as long as the gameplay action.

const ART_DIR := "res://art/black_swordsman"
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

var _plain: SpriteFrames
var _masked: SpriteFrames
var _is_masked: bool = false


func _ready() -> void:
	centered = false
	_plain = _build_frames("plain")
	_masked = _build_frames("masked")
	sprite_frames = _plain
	play(&"idle")


func is_masked() -> bool:
	return _is_masked


## Swap to the masked (or plain) art without losing the animation, frame or timing.
func set_masked(masked: bool) -> void:
	if masked == _is_masked:
		return
	_is_masked = masked
	var anim := animation
	var current_frame := frame
	var progress := frame_progress
	sprite_frames = _masked if masked else _plain
	play(anim)
	set_frame_and_progress(current_frame, progress)


## One frame as an image (for tests and tooling).
func frame_image(anim: StringName, index: int, masked: bool) -> Image:
	var frames := _masked if masked else _plain
	return frames.get_frame_texture(anim, index).get_image()


## feet_y: where the player's feet are, relative to the player's origin.
## action_seconds: how long the current attack or roll lasts, so its frames fit exactly.
func show_state(state: State, facing: float, feet_y: float, action_seconds: float, combo_step: int = 0, dead: bool = false, masked: bool = false) -> void:
	set_masked(masked)
	var anim := &"death" if dead else animation_for(state, combo_step)
	if anim != animation:
		if anim in FITTED and action_seconds > 0.0:
			for frames in [_plain, _masked]:
				frames.set_animation_speed(anim, ANIMS[anim]["count"] / action_seconds)
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


func _build_frames(variant: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in ANIMS:
		var spec: Dictionary = ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec["fps"])
		frames.set_animation_loop(anim, spec["loop"])
		for i in spec["count"]:
			frames.add_frame(anim, load("%s/%s/%s/HeroKnight_%s_%d.png" % [ART_DIR, variant, spec["dir"], spec["dir"], i]))
	return frames
