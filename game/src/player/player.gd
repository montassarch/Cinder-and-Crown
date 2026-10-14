class_name Player
extends CharacterBody2D
## Physics layers: 1 world, 2 player body, 3 enemy body, 4 player hurtbox, 5 enemy hurtbox.

signal died

const State := PlayerStateMachine.PlayerState

# All distances are tiles, speeds tiles/s, accelerations tiles/s^2, times seconds.
const RUN_SPEED: float = 9.0
const JUMP_HEIGHT: float = 3.2
const ROLL_SPEED: float = 14.0
const ROLL_DURATION: float = PlayerStateMachine.ROLL_DURATION
const IFRAME_WINDOW := Vector2(0.04, 0.26)
const COYOTE_TIME: float = 0.1
const GRAVITY: float = 56.0
const HURT_DURATION: float = PlayerStateMachine.HURT_DURATION
const HURT_KNOCKBACK_SPEED: float = 5.0
const HURT_KNOCKBACK_DECAY: float = 20.0
const ATTACK_MOVE_FACTOR: float = 0.25
## Applied every frame while jump is released and the player is still rising,
## so letting go ends the rise quickly: height scales with how long jump is held.
const JUMP_RELEASE_FACTOR: float = 0.5
const BODY_SIZE_TILES := Vector2(1.0, 2.0)
## Used only while no weapon is equipped.
const DEFAULT_ATTACK_DURATION: float = 0.3
const WEAPON_SLOTS: int = 2
## Attacks started within this many seconds of the last one ending continue the combo.
const COMBO_WINDOW: float = 0.4
const COMBO_STEPS: int = 3

## Slot 0 and 1 loadout. Set in the scene; the sandbox menu can reassign at runtime.
@export var starting_weapons: Array[WeaponData] = []

var _state: State = State.IDLE
var _state_time: float = 0.0
var _coyote: float = 0.0
var _hurt_pending: bool = false
var _hit_direction: float = 0.0
var _facing: float = 1.0
var _weapons: Array[WeaponData] = [null, null]
var _active_slot: int = 0
var _combo_step: int = 0
var _clock: float = 0.0
var _last_attack_end: float = -1000.0
## A tap during a swing, kept until the swing ends (input buffering alone would expire it).
var _attack_queued: bool = false

@onready var _weapon: Weapon = $Weapon
@onready var _health: Health = $Health
@onready var _body: ColorRect = $Body
@onready var _visual: PlayerVisual = $Visual
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D


func _ready() -> void:
	var size := GameConfig.tiles_v(BODY_SIZE_TILES.x, BODY_SIZE_TILES.y)
	(_shape.shape as RectangleShape2D).size = size
	(_hurtbox_shape.shape as RectangleShape2D).size = size
	_body.size = size
	_body.position = -size / 2.0
	_body.visible = false  # SPIKE: the animated hero replaces the placeholder box
	_health.died.connect(func() -> void: died.emit())
	for slot in mini(WEAPON_SLOTS, starting_weapons.size()):
		_weapons[slot] = starting_weapons[slot]
	_weapon.equip(_weapons[_active_slot])


func _physics_process(delta: float) -> void:
	if not _health.is_alive():
		_idle_while_dead(delta)
		_update_visual()
		return
	_state_time += delta
	_clock += delta
	if _state == State.ATTACK and InputRouter.attack_buffered():
		_attack_queued = true
		InputRouter.consume_attack()
	if InputRouter.swap_weapon_pressed():
		swap_weapons()
	_coyote = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote - delta)

	var hurt_now := _hurt_pending
	_hurt_pending = false
	var next := PlayerStateMachine.next_state(_state, _build_context(hurt_now))
	if next != _state or (next == State.HURT and hurt_now):
		_enter_state(next)

	_apply_velocity(delta)
	move_and_slide()
	_update_visual()


func _update_visual() -> void:
	var action := ROLL_DURATION
	if _state == State.ATTACK and _weapon.data != null:
		action = _weapon.data.attack_duration
	var shown := State.HURT if not _health.is_alive() else _state
	_visual.show_state(shown, _facing, GameConfig.tiles(BODY_SIZE_TILES.y) / 2.0, action, _combo_step)


func state() -> State:
	return _state


## Back to a fresh life at `at`: full health, standing, nothing held over.
func reset(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_weapon.cancel_attack()
	_state = State.IDLE
	_state_time = 0.0
	_coyote = 0.0
	_hurt_pending = false
	_health.setup(_health.max_health)


func set_weapon(slot: int, data: WeaponData) -> void:
	_weapons[slot] = data
	if slot == _active_slot:
		_weapon.equip(data)


func weapon_in_slot(slot: int) -> WeaponData:
	return _weapons[slot]


func combo_step() -> int:
	return _combo_step


func active_slot() -> int:
	return _active_slot


## Always allowed: no stamina, no lockout. Equipping withdraws any live hitbox.
func swap_weapons() -> void:
	var other := 1 - _active_slot
	if _weapons[other] == null:
		return
	_active_slot = other
	_weapon.equip(_weapons[_active_slot])


func is_invincible() -> bool:
	return _state == State.ROLL and _state_time >= IFRAME_WINDOW.x and _state_time <= IFRAME_WINDOW.y


## Damage lands unless the roll's i-frames cover it. A hit mid-roll outside the
## i-frame window still hurts but does not interrupt the roll.
func take_hit(damage: int, source_x: float) -> void:
	if is_invincible():
		return
	if _health.take_damage(damage) == 0:
		return
	if _state != State.ROLL:
		_hurt_pending = true
		_hit_direction = signf(global_position.x - source_x)


func _idle_while_dead(delta: float) -> void:
	_weapon.cancel_attack()
	velocity.x = move_toward(velocity.x, 0.0, GameConfig.tiles(HURT_KNOCKBACK_DECAY) * delta)
	velocity.y += GameConfig.tiles(GRAVITY) * delta
	move_and_slide()


func _build_context(hurt_now: bool) -> Dictionary:
	return {
		"on_floor": is_on_floor(),
		"move_axis": InputRouter.move_axis(),
		"jump_buffered": InputRouter.jump_buffered(),
		"attack_buffered": InputRouter.attack_buffered() or _attack_queued,
		"attack_cancelable": _weapon.is_recovering(),
		"roll_buffered": InputRouter.roll_buffered(),
		"state_time": _state_time,
		"coyote_time": _coyote,
		"hurt": hurt_now,
		"vel_y": velocity.y / GameConfig.TILE_SIZE,
		"attack_duration": _weapon.data.attack_duration if _weapon.data != null else DEFAULT_ATTACK_DURATION,
	}


func _enter_state(next: State) -> void:
	if _state == State.ATTACK and next != State.ATTACK:
		_weapon.cancel_attack()
		_last_attack_end = _clock
		if next in [State.JUMP, State.ROLL, State.HURT]:
			_attack_queued = false
	_state = next
	_state_time = 0.0
	match next:
		State.JUMP:
			velocity.y = -GameConfig.tiles(sqrt(2.0 * GRAVITY * JUMP_HEIGHT))
			_coyote = 0.0
			InputRouter.consume_jump()
		State.ROLL:
			InputRouter.consume_roll()
		State.ATTACK:
			InputRouter.consume_attack()
			_attack_queued = false
			var chained := _clock - _last_attack_end <= COMBO_WINDOW
			_combo_step = (_combo_step + 1) % COMBO_STEPS if chained else 0
			_weapon.set_facing(_facing)
			_weapon.start_attack()
		State.HURT:
			velocity.x = _hit_direction * GameConfig.tiles(HURT_KNOCKBACK_SPEED)


func _apply_velocity(delta: float) -> void:
	var axis := InputRouter.move_axis()
	if absf(axis) > PlayerStateMachine.AXIS_EPSILON and _state != State.ROLL and _state != State.HURT:
		_facing = signf(axis)

	match _state:
		State.ROLL:
			velocity.x = _facing * GameConfig.tiles(ROLL_SPEED)
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, GameConfig.tiles(HURT_KNOCKBACK_DECAY) * delta)
		State.ATTACK:
			velocity.x = axis * GameConfig.tiles(RUN_SPEED) * ATTACK_MOVE_FACTOR
		_:
			velocity.x = axis * GameConfig.tiles(RUN_SPEED)

	velocity.y += GameConfig.tiles(GRAVITY) * delta
	if _state == State.JUMP and velocity.y < 0.0 and not InputRouter.jump_held():
		velocity.y *= JUMP_RELEASE_FACTOR
