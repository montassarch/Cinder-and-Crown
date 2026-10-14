class_name Player
extends CharacterBody2D
## Physics layers: 1 world, 2 player body, 3 enemy body, 4 player hurtbox, 5 enemy hurtbox.

signal died
## An ability button was pressed without enough mana (the HUD flashes the mana bar).
signal mana_denied
## Storm Blade's bolt has struck the sword (for the lightning effect).
signal storm_struck

const State := PlayerStateMachine.PlayerState

# All distances are tiles, speeds tiles/s, accelerations tiles/s^2, times seconds.
const RUN_SPEED: float = 13.0
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
## The last hit of the combo is a heavier, slower swing.
const FINISHER_DURATION_SCALE: float = 1.8

# Mana and abilities (all times in seconds).
const MANA_MAX: float = 100.0
const MANA_REGEN: float = 2.0
const MANA_PER_HIT: float = 6.0
## Storm Blade: raise the sword, a bolt charges it; charged hits deal more and may stun.
const STORM_COST: float = 40.0
const STORM_CAST_SECONDS: float = 0.6
const STORM_STRIKE_AT: float = 0.4
const STORM_SECONDS: float = 8.0
const STORM_FADE_SECONDS: float = 2.0
const STORM_BONUS_DAMAGE: int = 3
const STORM_STUN_CHANCE: float = 0.3
const STORM_STUN_SECONDS: float = 1.2
## Crimson Rend: a vertical slash that launches a travelling wave of red lightning.
const REND_COST: float = 30.0
const REND_CAST_SECONDS: float = 0.45
const REND_RELEASE_SECONDS: float = 0.16

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
var _attack_scale: float = 1.0
var _mana: Mana
var _storm_left: float = 0.0
var _cast_fired: bool = false

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
	_body.visible = false  # the animated hero replaces the placeholder box
	_health.died.connect(func() -> void: died.emit())
	for slot in mini(WEAPON_SLOTS, starting_weapons.size()):
		_weapons[slot] = starting_weapons[slot]
	_weapon.equip(_weapons[_active_slot])
	_mana = Mana.new()
	_mana.name = "Mana"
	_mana.max_mana = MANA_MAX
	_mana.regen_per_second = MANA_REGEN
	add_child(_mana)
	_mana.refill()
	_weapon.hit_landed.connect(func(_target: Node, _damage: int) -> void: _mana.gain(MANA_PER_HIT))


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
	_mana.advance(delta)
	_tick_storm(delta)
	_refuse_unaffordable_skills()
	_coyote = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote - delta)

	var hurt_now := _hurt_pending
	_hurt_pending = false
	var next := PlayerStateMachine.next_state(_state, _build_context(hurt_now))
	if next != _state or (next == State.HURT and hurt_now):
		_enter_state(next)

	_fire_cast_moment()
	_apply_velocity(delta)
	move_and_slide()
	_update_visual()


func _update_visual() -> void:
	var action := ROLL_DURATION
	if _state == State.ATTACK and _weapon.data != null:
		action = _weapon.data.attack_duration * _attack_scale
	elif _state == State.STORM:
		action = STORM_CAST_SECONDS
	elif _state == State.REND:
		action = REND_CAST_SECONDS
	_visual.show_state(_state, _facing, GameConfig.tiles(BODY_SIZE_TILES.y) / 2.0, action, _combo_step, not _health.is_alive())


func state() -> State:
	return _state


func mana() -> Mana:
	return _mana


func storm_seconds_left() -> float:
	return _storm_left


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
	_mana.refill()
	_storm_left = 0.0
	_apply_storm_to_weapon()


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
		"skill1_buffered": InputRouter.skill_buffered(1),
		"skill2_buffered": InputRouter.skill_buffered(2),
		"storm_ready": _mana.can_afford(STORM_COST),
		"rend_ready": _mana.can_afford(REND_COST),
		"cast_duration": STORM_CAST_SECONDS if _state == State.STORM else REND_CAST_SECONDS,
		"roll_buffered": InputRouter.roll_buffered(),
		"state_time": _state_time,
		"coyote_time": _coyote,
		"hurt": hurt_now,
		"vel_y": velocity.y / GameConfig.TILE_SIZE,
		"attack_duration": _weapon.data.attack_duration * _attack_scale if _weapon.data != null else DEFAULT_ATTACK_DURATION,
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
			_attack_scale = FINISHER_DURATION_SCALE if _combo_step == COMBO_STEPS - 1 else 1.0
			_weapon.start_attack(_attack_scale)
		State.STORM:
			InputRouter.consume_skill(1)
			_mana.spend(STORM_COST)
			_cast_fired = false
		State.REND:
			InputRouter.consume_skill(2)
			_mana.spend(REND_COST)
			_cast_fired = false
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
		State.STORM, State.REND:
			velocity.x = 0.0
		State.ATTACK:
			velocity.x = axis * GameConfig.tiles(RUN_SPEED) * ATTACK_MOVE_FACTOR
		_:
			velocity.x = axis * GameConfig.tiles(RUN_SPEED)

	velocity.y += GameConfig.tiles(GRAVITY) * delta
	if _state == State.JUMP and velocity.y < 0.0 and not InputRouter.jump_held():
		velocity.y *= JUMP_RELEASE_FACTOR


## Count down the Storm Blade charge and keep the sword's modifiers in step with it.
func _tick_storm(delta: float) -> void:
	if _storm_left > 0.0:
		_storm_left = maxf(0.0, _storm_left - delta)
		_apply_storm_to_weapon()


func _apply_storm_to_weapon() -> void:
	var charged := _storm_left > 0.0
	_weapon.bonus_damage = STORM_BONUS_DAMAGE if charged else 0
	_weapon.stun_chance = STORM_STUN_CHANCE if charged else 0.0
	_weapon.stun_seconds = STORM_STUN_SECONDS if charged else 0.0


## A pressed ability without the mana for it: drop the press and tell the HUD.
func _refuse_unaffordable_skills() -> void:
	for slot in [1, 2]:
		var cost := STORM_COST if slot == 1 else REND_COST
		if InputRouter.skill_buffered(slot) and not _mana.can_afford(cost):
			InputRouter.consume_skill(slot)
			mana_denied.emit()


## The moment inside a cast where the effect happens: the bolt lands, or the wave leaves.
func _fire_cast_moment() -> void:
	if _cast_fired:
		return
	if _state == State.STORM and _state_time >= STORM_STRIKE_AT:
		_cast_fired = true
		_storm_left = STORM_SECONDS
		_apply_storm_to_weapon()
		storm_struck.emit()
	elif _state == State.REND and _state_time >= REND_RELEASE_SECONDS:
		_cast_fired = true
		var wave := RendWave.new()
		wave.direction = _facing
		get_parent().add_child(wave)
		wave.global_position = global_position + Vector2(_facing * GameConfig.tiles(1.0), GameConfig.tiles(BODY_SIZE_TILES.y) / 2.0)
