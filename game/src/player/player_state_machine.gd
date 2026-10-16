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
##   skill1_buffered / skill2_buffered  an ability button was pressed (1 Storm Blade, 2 Crimson Rend)
##   storm_ready / rend_ready  there is enough mana for that ability
##   cast_duration  seconds the current ability cast lasts
##   parry_buffered / parry_ready  the parry button was pressed / its cooldown is over
##   parry_duration  seconds a parry lasts, hit or whiff
##   parry_succeeded  this parry deflected a strike (attack or roll may then cut it short)
##   heal_buffered / heal_ready  the flask button was pressed / a drink would help (charge and missing health)
##   heal_duration  seconds a drink lasts

enum PlayerState { IDLE, RUN, JUMP, FALL, ROLL, ATTACK, HURT, STORM, REND, PARRY, HEAL }

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
		PlayerState.STORM, PlayerState.REND:
			# A cast is committed: nothing but a hit (handled above) cuts it short.
			if state_time < ctx.get("cast_duration", 0.0):
				return current
			return _settled_state(ctx)
		PlayerState.HEAL:
			# A drink is committed; only a hit (handled above) spills it.
			if state_time < ctx.get("heal_duration", 0.0):
				return PlayerState.HEAL
			return _settled_state(ctx)
		PlayerState.PARRY:
			# Committed, unless the parry landed: then the counter may start at once.
			if state_time < ctx.get("parry_duration", 0.0):
				if ctx.get("parry_succeeded", false):
					if ctx.get("attack_buffered", false):
						return PlayerState.ATTACK
					if ctx.get("roll_buffered", false) and ctx.get("on_floor", false):
						return PlayerState.ROLL
				return PlayerState.PARRY
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
	if ctx.get("parry_buffered", false) and ctx.get("parry_ready", false):
		return PlayerState.PARRY
	if on_floor and ctx.get("heal_buffered", false) and ctx.get("heal_ready", false):
		return PlayerState.HEAL
	if on_floor and ctx.get("skill1_buffered", false) and ctx.get("storm_ready", false):
		return PlayerState.STORM
	if ctx.get("skill2_buffered", false) and ctx.get("rend_ready", false):
		return PlayerState.REND
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
