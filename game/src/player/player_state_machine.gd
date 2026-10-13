class_name PlayerStateMachine
extends RefCounted

## The player's transition rules, as a pure function.
##
## No Input, no get_node, no delta, no engine state. It takes a context
## dictionary and returns the next state. Every rule about what the player
## may do and when lives here and nowhere else, which is what makes those
## rules provable in a headless test.
##
## What does NOT live here: speeds, distances, gravity, jump height. Those
## are physics values in tiles and belong to Player. This file holds timing
## and priority rules only.

enum State {
	IDLE,
	RUN,
	JUMP,
	FALL,
	ROLL,
	ATTACK,
	HURT,
}

## How long after leaving the floor a jump still counts. Pure forgiveness:
## without it, walking off a ledge and pressing jump reads as a bug.
const COYOTE_TIME: float = 0.1

## Axis magnitude below which the player is considered still, so a resting
## gamepad stick or drifting touch knob does not make them jog in place.
const MOVE_DEADZONE: float = 0.15

## States that run to completion and ignore input until they finish.
const COMMITTED_STATES: Array[State] = [State.ROLL, State.ATTACK, State.HURT]


## Returns the state the player should be in next.
##
## ctx keys:
##   on_floor: bool          -- touching ground this frame
##   move_axis: float        -- horizontal intent, -1..1
##   jump_buffered: bool     -- jump pressed within the input buffer
##   attack_buffered: bool
##   roll_buffered: bool
##   hurt: bool              -- took damage this frame, already filtered
##                              for invincibility by Player
##   state_finished: bool    -- the current state's duration has elapsed
##   coyote_time: float      -- seconds since last on floor, 0 while on it
##   vertical_velocity: float -- positive is downward, Godot's convention
static func next_state(current: State, ctx: Dictionary) -> State:
	# Taking a hit outranks everything, including a committed state. This
	# ordering matters: Player has already filtered ctx.hurt through
	# is_invincible(), so a true here means the player was genuinely
	# vulnerable. Letting a committed roll swallow it would make the
	# vulnerable edges of the roll -- its first 0.04s and last 0.06s,
	# outside IFRAME_WINDOW -- have no consequence at all, and the i-frame
	# window would be decoration.
	#
	# Excluded when already HURT: ctx.hurt stays true for the frame the hit
	# landed, and re-entering would reset the timer into a permanent stunlock.
	if bool(ctx[&"hurt"]) and current != State.HURT:
		return State.HURT

	# Otherwise a committed state keeps control until its duration elapses,
	# so a queued attack cannot cancel a roll.
	if current in COMMITTED_STATES and not bool(ctx[&"state_finished"]):
		return current

	# Defensive option wins a tie: a player pressing both is trying to
	# survive, not to trade.
	if bool(ctx[&"roll_buffered"]):
		return State.ROLL

	if bool(ctx[&"attack_buffered"]):
		return State.ATTACK

	var on_floor := bool(ctx[&"on_floor"])
	if bool(ctx[&"jump_buffered"]) and (on_floor or float(ctx[&"coyote_time"]) <= COYOTE_TIME):
		return State.JUMP

	if not on_floor:
		return State.FALL if float(ctx[&"vertical_velocity"]) > 0.0 else State.JUMP

	if absf(float(ctx[&"move_axis"])) > MOVE_DEADZONE:
		return State.RUN

	return State.IDLE
