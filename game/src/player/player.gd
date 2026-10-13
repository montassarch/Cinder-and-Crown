class_name Player
extends CharacterBody2D

## The player body: physics, state application, and the invincibility gate.
##
## All transition RULES live in PlayerStateMachine. This file owns the
## physics values, and every one of them is in tiles or tiles/second per
## the project's resolution rule -- so moving toward Dead Cells-scale art
## changes GameConfig.TILE_SIZE and nothing here.
##
## Numbers below are a starting point for the feel, not a finished answer.
## No test can assert that a jump arc feels good; that is judged by playing
## the sandbox and changing these.

signal died
signal state_changed(new_state: PlayerStateMachine.State)

## Horizontal run speed.
const RUN_SPEED_TILES: float = 9.0

## Peak height of a full jump, measured in tiles. The impulse is derived
## from this and GRAVITY_TILES, so raising one does not silently break the
## other.
const JUMP_HEIGHT_TILES: float = 3.2
const GRAVITY_TILES: float = 56.0

## Air control, as a fraction of RUN_SPEED. Dead Cells gives near-full air
## control; a lower value here would make the platforming feel floaty.
const AIR_CONTROL: float = 0.85

## The roll: fast, committed, and invincible only in the middle.
const ROLL_SPEED_TILES: float = 14.0
const ROLL_DURATION: float = 0.32

## Invincibility window WITHIN the roll, in seconds from its start. The
## roll is 0.32s long, so the player is exposed for the first 0.04s and the
## last 0.06s. That exposure is the risk that makes the move a decision
## rather than a free escape.
const IFRAME_WINDOW: Vector2 = Vector2(0.04, 0.26)

## Placeholder attack length. Task 5 replaces this with the equipped
## weapon's attack_duration, since reach and speed are weapon properties.
const ATTACK_DURATION: float = 0.3

const HURT_DURATION: float = 0.25
const HURT_KNOCKBACK_TILES: float = 4.0

const MAX_HEALTH: int = 100

## Placeholder body, 1x2 tiles. Replaced when real art exists.
const BODY_SIZE_TILES: Vector2 = Vector2(1.0, 2.0)

var state: PlayerStateMachine.State = PlayerStateMachine.State.IDLE
var facing: float = 1.0

var _state_time: float = 0.0
var _coyote_time: float = 0.0
var _hurt_pending: bool = false
var _hurt_source: Vector2 = Vector2.ZERO

@onready var health: Health = %Health


## True while the roll's invincibility window is open.
##
## Static and pure so the window is provable in a test rather than only
## observable by getting hit at the right moment. is_invincible() is the
## instance view of the same rule.
static func is_invincible_at(at_state: PlayerStateMachine.State, state_time: float) -> bool:
	if at_state != PlayerStateMachine.State.ROLL:
		return false
	return state_time >= IFRAME_WINDOW.x and state_time <= IFRAME_WINDOW.y


## Upward impulse that reaches exactly JUMP_HEIGHT_TILES under
## GRAVITY_TILES. Derived rather than tuned, so the two constants cannot
## drift apart.
static func jump_velocity() -> float:
	return -sqrt(2.0 * GameConfig.tiles(GRAVITY_TILES) * GameConfig.tiles(JUMP_HEIGHT_TILES))


func _ready() -> void:
	health.configure(MAX_HEALTH)
	health.died.connect(func() -> void: died.emit())
	_size_placeholder_body()


func is_invincible() -> bool:
	return is_invincible_at(state, _state_time)


## The only way damage reaches the player. Invincibility is filtered here,
## which is why PlayerStateMachine can treat ctx.hurt as unconditional.
func take_hit(amount: int, from_position: Vector2) -> void:
	if is_invincible():
		return
	if health.take_damage(amount) <= 0:
		return
	_hurt_pending = true
	_hurt_source = from_position


func _physics_process(delta: float) -> void:
	_state_time += delta
	_coyote_time = 0.0 if is_on_floor() else _coyote_time + delta

	var next_state: PlayerStateMachine.State = PlayerStateMachine.next_state(state, {
		&"on_floor": is_on_floor(),
		&"move_axis": InputRouter.move_axis(),
		&"jump_buffered": InputRouter.jump_buffered(),
		&"attack_buffered": InputRouter.attack_buffered(),
		&"roll_buffered": InputRouter.roll_buffered(),
		&"hurt": _hurt_pending,
		&"state_finished": _state_time >= _duration_of(state),
		&"coyote_time": _coyote_time,
		&"vertical_velocity": velocity.y,
	})

	if next_state != state:
		_enter(next_state)

	_apply(delta)
	move_and_slide()
	_hurt_pending = false


func _duration_of(of_state: PlayerStateMachine.State) -> float:
	match of_state:
		PlayerStateMachine.State.ROLL:
			return ROLL_DURATION
		PlayerStateMachine.State.ATTACK:
			return ATTACK_DURATION
		PlayerStateMachine.State.HURT:
			return HURT_DURATION
		_:
			return 0.0


func _enter(new_state: PlayerStateMachine.State) -> void:
	state = new_state
	_state_time = 0.0

	match new_state:
		PlayerStateMachine.State.JUMP:
			# Consumed so one press cannot fire a second jump next frame
			# while the buffer is still warm.
			InputRouter.consume_jump()
			velocity.y = jump_velocity()
			_coyote_time = PlayerStateMachine.COYOTE_TIME + 1.0
		PlayerStateMachine.State.ROLL:
			InputRouter.consume_roll()
			velocity.x = facing * GameConfig.tiles(ROLL_SPEED_TILES)
		PlayerStateMachine.State.ATTACK:
			InputRouter.consume_attack()
		PlayerStateMachine.State.HURT:
			var away := 1.0 if global_position.x >= _hurt_source.x else -1.0
			velocity.x = away * GameConfig.tiles(HURT_KNOCKBACK_TILES)
			velocity.y = -GameConfig.tiles(HURT_KNOCKBACK_TILES) * 0.5

	state_changed.emit(new_state)


func _apply(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GameConfig.tiles(GRAVITY_TILES) * delta

	var axis := InputRouter.move_axis()
	if absf(axis) > PlayerStateMachine.MOVE_DEADZONE:
		facing = signf(axis)

	match state:
		PlayerStateMachine.State.IDLE:
			velocity.x = 0.0
		PlayerStateMachine.State.RUN:
			velocity.x = axis * GameConfig.tiles(RUN_SPEED_TILES)
		PlayerStateMachine.State.JUMP, PlayerStateMachine.State.FALL:
			velocity.x = axis * GameConfig.tiles(RUN_SPEED_TILES) * AIR_CONTROL
		PlayerStateMachine.State.ROLL:
			# Velocity set on entry and held, so the roll covers a fixed
			# distance the player can learn.
			velocity.x = facing * GameConfig.tiles(ROLL_SPEED_TILES)
		PlayerStateMachine.State.ATTACK:
			# Rooted while swinging, which is what gives the commitment
			# weight. Air attacks keep their momentum.
			if is_on_floor():
				velocity.x = 0.0
		PlayerStateMachine.State.HURT:
			pass


func _size_placeholder_body() -> void:
	var body := GameConfig.tiles_v(BODY_SIZE_TILES.x, BODY_SIZE_TILES.y)

	var shape := RectangleShape2D.new()
	shape.size = body
	(%CollisionShape2D as CollisionShape2D).shape = shape

	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = body
	(%HurtboxShape as CollisionShape2D).shape = hurt_shape

	var rect := %Placeholder as ColorRect
	rect.size = body
	rect.position = -body * 0.5
