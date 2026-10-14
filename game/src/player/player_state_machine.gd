class_name PlayerStateMachine
extends RefCounted
## Pure transition table. No Input, no nodes, no delta: ctx in, state out.
##
## ctx keys (missing keys read as false / 0):
##   on_floor, move_axis, jump_buffered, attack_buffered, roll_buffered, hurt,
##   state_time    seconds spent in the current state
##   coyote_time   seconds of coyote jump remaining (> 0 means a jump is still allowed)
##   vel_y         vertical velocity in tiles/s, negative = rising
##   attack_duration  seconds the current attack lasts
##   attack_cancelable  the swing's hit has landed; a jump may cut its recovery short

enum PlayerState { IDLE, RUN, JUMP, FALL, ROLL, ATTACK, HURT }

const ROLL_DURATION: float = 0.32
const HURT_DURATION: float = 0.25
const AXIS_EPSILON: float = 0.01


static func next_state(current: PlayerState, ctx: Dictionary) -> PlayerState:
	var state_time: float = ctx.get("state_time", 0.0)

	# A roll is committed: nothing interrupts it, hits included (its i-frames are the point).
	if current == PlayerState.ROLL and state_time < ROLL_DURATION:
		return PlayerState.ROLL

	if ctx.get("hurt", false):
		return PlayerState.HURT

	match current:
		PlayerState.ROLL:
			return _settled_state(ctx)
		PlayerState.HURT:
			if state_time < HURT_DURATION:
				return PlayerState.HURT
			return _settled_state(ctx)
		PlayerState.ATTACK:
			if state_time < ctx.get("attack_duration", 0.0):
				if ctx.get("roll_buffered", false) and ctx.get("on_floor", false):
					return PlayerState.ROLL
				if ctx.get("attack_cancelable", false) and ctx.get("jump_buffered", false) \
						and (ctx.get("on_floor", false) or ctx.get("coyote_time", 0.0) > 0.0):
					return PlayerState.JUMP
				return PlayerState.ATTACK
			return _settled_state(ctx)
		PlayerState.JUMP:
			if ctx.get("vel_y", 0.0) < 0.0:
				return PlayerState.JUMP
			return _settled_state(ctx)
		_:
			return _free_state(ctx)


## IDLE, RUN and FALL: the states that may start any action.
static func _free_state(ctx: Dictionary) -> PlayerState:
	var on_floor: bool = ctx.get("on_floor", false)
	if on_floor and ctx.get("roll_buffered", false):
		return PlayerState.ROLL
	if ctx.get("jump_buffered", false) and (on_floor or ctx.get("coyote_time", 0.0) > 0.0):
		return PlayerState.JUMP
	if ctx.get("attack_buffered", false):
		return PlayerState.ATTACK
	return _settled_state(ctx)


## Where the player rests when no action is in progress. Leaving an action never
## chains straight into a buffered one; that happens on the next tick.
static func _settled_state(ctx: Dictionary) -> PlayerState:
	if not ctx.get("on_floor", false):
		return PlayerState.FALL
	if absf(ctx.get("move_axis", 0.0)) > AXIS_EPSILON:
		return PlayerState.RUN
	return PlayerState.IDLE
