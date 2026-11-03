class_name PlayerVisual
extends AnimatedSprite2D
## The skeleton knight's animations: Quaternius's free hooded outfit and animation library, posed and
## rendered in Blender, then shrunk to pixel art (see art/skeleton_knight/CREDITS.md and the
## skeleton_knight_*.py tools). Every frame exists twice: plain, and washed red (shown briefly after a hit).
## Reads the player's state and plays the matching animation; attacks and the roll are
## stretched to last exactly as long as the gameplay action.

const ART_DIR := "res://art/skeleton_knight"
const FRAME := Vector2i(100, 72)
## Where the feet sit inside each frame, in art pixels (art data, not gameplay).
const FEET := Vector2(40.0, 70.0)
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
	# Ability casts reuse attack frames (no dedicated art yet): Storm holds the sword raised,
	# Rend is the heavy downward slash (wave leaves around its third frame).
	&"storm": {"dir": "Attack1", "frames": [0, 1, 1, 1, 1, 1], "fps": 10.0, "loop": false},
	&"rend": {"dir": "Attack3", "frames": [1, 2, 3, 4, 5, 6], "fps": 14.0, "loop": false},
	# Parry: the blade is thrust forward and held low (Attack3's follow-through), then drawn back.
	&"parry": {"dir": "Attack3", "frames": [5, 6, 6, 6, 6, 7], "fps": 12.0, "loop": false},
}
## These play over exactly the action's duration instead of their own frame rate.
const FITTED: Array[StringName] = [&"roll", &"attack1", &"attack2", &"attack3", &"storm", &"rend", &"parry"]
const COMBO_ANIMS: Array[StringName] = [&"attack1", &"attack2", &"attack3"]

const State := PlayerStateMachine.PlayerState

var _plain: SpriteFrames
var _masked: SpriteFrames
var _is_masked: bool = false
## Which weapon the art shows in his hand: "" is the sword set (art/skeleton_knight/plain|masked), otherwise
## art/skeleton_knight/<set>/plain|masked (rendered by weapon_showcase.py with HERO_WEAPON).
var _set: String = ""
static var _sets: Dictionary = {}


func _ready() -> void:
	centered = false
	_load_set(_set)
	sprite_frames = _plain
	play(&"idle")


static func has_art_set(set_name: String) -> bool:
	return set_name == "" or ResourceLoader.exists("%s/%s/plain/Idle/SkeletonKnight_Idle_0.png" % [ART_DIR, set_name])


func art_set() -> String:
	return _set


## Shows the hero holding another weapon; a set that has not been rendered falls back to the sword.
func set_art_set(set_name: String) -> void:
	if not has_art_set(set_name):
		set_name = ""
	if set_name == _set and _plain != null:
		return
	_set = set_name
	if not is_node_ready():
		return
	var anim := animation
	_load_set(set_name)
	sprite_frames = _masked if _is_masked else _plain
	play(anim if sprite_frames.has_animation(anim) else &"idle")


func _load_set(set_name: String) -> void:
	if not _sets.has(set_name):
		_sets[set_name] = [_build_frames("plain", set_name), _build_frames("masked", set_name)]
	_plain = _sets[set_name][0]
	_masked = _sets[set_name][1]


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
## attack_anim: the animation the current attack asks for (empty: the combo step's own).
func show_state(state: State, facing: float, feet_y: float, action_seconds: float, combo_step: int = 0, dead: bool = false, masked: bool = false, attack_anim: StringName = &"") -> void:
	set_masked(masked)
	var anim := &"death" if dead else animation_for(state, combo_step)
	if state == State.ATTACK and not dead and ANIMS.has(attack_anim):
		anim = attack_anim
	if anim != animation:
		if anim in FITTED and action_seconds > 0.0:
			for frames in [_plain, _masked]:
				frames.set_animation_speed(anim, _frame_indices(ANIMS[anim]).size() / action_seconds)
		play(anim)
	flip_h = facing < 0.0
	position = Vector2(-(FRAME.x - FEET.x) if flip_h else -FEET.x, feet_y - FEET.y)


static func animation_for(state: State, combo_step: int) -> StringName:
	match state:
		State.RUN: return &"run"
		State.JUMP, State.DOUBLE_JUMP: return &"jump"
		State.AIR_DASH: return &"roll"
		State.FALL: return &"fall"
		State.ROLL: return &"roll"
		State.ATTACK: return COMBO_ANIMS[combo_step % COMBO_ANIMS.size()]
		State.HURT: return &"hurt"
		State.STORM: return &"storm"
		State.REND: return &"rend"
		State.PARRY: return &"parry"
		_: return &"idle"


func _build_frames(variant: String, set_name: String = "") -> SpriteFrames:
	var root := ART_DIR if set_name == "" else "%s/%s" % [ART_DIR, set_name]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim in ANIMS:
		var spec: Dictionary = ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, spec["fps"])
		frames.set_animation_loop(anim, spec["loop"])
		for i in _frame_indices(spec):
			frames.add_frame(anim, load("%s/%s/%s/SkeletonKnight_%s_%d.png" % [root, variant, spec["dir"], spec["dir"], i]))
	return frames


static func _frame_indices(spec: Dictionary) -> Array:
	return spec["frames"] if spec.has("frames") else range(spec["count"])
