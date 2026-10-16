class_name Enemy
extends CharacterBody2D
## Physics layers: 1 world, 3 enemy body, 5 enemy hurtbox (weapons hit layer 5).
## Behaviour is chosen by EnemyData.behaviour; every number comes from the data.

signal attack_released(damage: int)
signal died

enum State { MOVE, TELEGRAPH, STRIKE, RECOVER, DEAD, STUNNED }

const GRAVITY: float = 56.0
const KNOCKBACK_DECAY: float = 20.0
const STRIKE_REACH_FACTOR: float = 1.25
const CHARGE_SPEED_MULTIPLIER: float = 4.0
const CHARGE_DURATION: float = 0.35
const CHARGE_CONTACT_TILES: float = 1.2
const FLYER_HOVER_ABOVE_TILES: float = 1.5
const FLYER_BOB_AMPLITUDE_TILES: float = 0.8
const FLYER_BOB_HZ: float = 1.5
## Within this distance of its hover point a flyer stops steering.
const FLYER_ARRIVE_TILES: float = 0.15
const DEATH_LINGER: float = 0.5
const TELEGRAPH_FLASH := Color(1.0, 1.0, 1.0)
const STUN_TINT := Color(0.55, 0.8, 1.0)
## How long a parried strike leaves the attacker staggered, and how far it is shoved back.
const PARRY_STAGGER: float = 0.8
const PERFECT_PARRY_STAGGER: float = 1.3
const PARRY_KNOCKBACK_TILES: float = 1.5

## Who this enemy hunts. Falls back to the first node in group "player".
var target: Node2D
var data: EnemyData

var _state: State = State.MOVE
var _facing: float = 1.0
var _knockback_x: float = 0.0
var _strike_time: float = 0.0
var _struck: bool = false
var _age: float = 0.0

@onready var _health: Health = $Health
@onready var _body: ColorRect = $Body
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var _telegraph_timer: Timer = $TelegraphTimer
@onready var _recovery_timer: Timer = $RecoveryTimer
var _stun_timer: Timer


func _ready() -> void:
	_health.died.connect(_on_health_died)
	_telegraph_timer.timeout.connect(_on_telegraph_timeout)
	_recovery_timer.timeout.connect(_on_recovery_timeout)
	_stun_timer = Timer.new()
	_stun_timer.one_shot = true
	_stun_timer.timeout.connect(_on_stun_timeout)
	add_child(_stun_timer)
	if data != null:
		_apply_data()


## Safe to call before or after the enemy enters the tree.
func configure(new_data: EnemyData) -> void:
	data = new_data
	if is_node_ready():
		_apply_data()


func health() -> Health:
	return _health


func is_telegraphing() -> bool:
	return _state == State.TELEGRAPH


func is_dead() -> bool:
	return _state == State.DEAD


func is_stunned() -> bool:
	return _state == State.STUNNED


## Freezes the enemy and cancels whatever it was winding up or doing.
func stun(seconds: float) -> void:
	if _state == State.DEAD or seconds <= 0.0:
		return
	_telegraph_timer.stop()
	_recovery_timer.stop()
	_state = State.STUNNED
	if data != null:
		_body.color = STUN_TINT
	_stun_timer.start(seconds)


## The player deflected this enemy's strike: it reels, shoved away from the parry.
func on_parried(perfect: bool, from_x: float) -> void:
	if _state == State.DEAD:
		return
	stun(PERFECT_PARRY_STAGGER if perfect else PARRY_STAGGER)
	var direction := signf(global_position.x - from_x)
	_knockback_x = (direction if direction != 0.0 else -_facing) * GameConfig.tiles(sqrt(2.0 * KNOCKBACK_DECAY * PARRY_KNOCKBACK_TILES))


func begin_telegraph() -> void:
	if data == null or _state != State.MOVE:
		return
	var foe := _current_target()
	if foe != null:
		_facing = signf(foe.global_position.x - global_position.x) if foe.global_position.x != global_position.x else _facing
	_state = State.TELEGRAPH
	_body.color = TELEGRAPH_FLASH
	_telegraph_timer.start(maxf(data.telegraph_seconds, 0.001))


## Contract used by Weapon: damage lands, health drops, the body is knocked back.
func take_hit(damage: int, source_x: float, knockback_tiles: float = 0.0) -> void:
	if _state == State.DEAD:
		return
	_health.take_damage(damage)
	if _state != State.DEAD and knockback_tiles > 0.0:
		var direction := signf(global_position.x - source_x)
		_knockback_x = direction * GameConfig.tiles(sqrt(2.0 * KNOCKBACK_DECAY * knockback_tiles))


func _physics_process(delta: float) -> void:
	if data == null or _state == State.DEAD:
		return
	_age += delta
	_knockback_x = move_toward(_knockback_x, 0.0, GameConfig.tiles(KNOCKBACK_DECAY) * delta)

	var foe := _current_target()
	var move_x := 0.0
	match _state:
		State.MOVE:
			move_x = _think_move(foe, delta)
		State.STRIKE:
			move_x = _think_strike(foe, delta)
		_:
			move_x = 0.0

	velocity.x = move_x + _knockback_x
	if data.behaviour != EnemyData.Behaviour.FLYER:
		velocity.y += GameConfig.tiles(GRAVITY) * delta
	elif _state != State.MOVE:
		velocity.y = 0.0  # a wind-up or recovery must not drift; only MOVE steers a flyer
	move_and_slide()


## Returns horizontal velocity; FLYER also sets velocity.y directly.
func _think_move(foe: Node2D, _delta: float) -> float:
	if foe == null:
		return 0.0
	var offset := foe.global_position - global_position
	var speed := GameConfig.tiles(data.move_speed_tiles)
	var reach := GameConfig.tiles(data.attack_range_tiles)

	match data.behaviour:
		EnemyData.Behaviour.FLYER:
			var hover := foe.global_position + Vector2(0.0, -GameConfig.tiles(FLYER_HOVER_ABOVE_TILES))
			hover.y += sin(_age * TAU * FLYER_BOB_HZ) * GameConfig.tiles(FLYER_BOB_AMPLITUDE_TILES)
			var heading := hover - global_position
			var arrived := heading.length() <= GameConfig.tiles(FLYER_ARRIVE_TILES)
			velocity.y = 0.0 if arrived else heading.normalized().y * speed
			if offset.length() <= reach:
				begin_telegraph()
				return 0.0
			return 0.0 if arrived else heading.normalized().x * speed
		EnemyData.Behaviour.CHARGER:
			if absf(offset.x) <= reach and absf(offset.y) <= GameConfig.tiles(2.0):
				begin_telegraph()
				return 0.0
			return signf(offset.x) * speed
		_:
			if absf(offset.x) <= reach * 0.9 and absf(offset.y) <= GameConfig.tiles(2.0):
				begin_telegraph()
				return 0.0
			return signf(offset.x) * speed


func _think_strike(foe: Node2D, delta: float) -> float:
	_strike_time += delta
	if foe != null and not _struck:
		if global_position.distance_to(foe.global_position) <= GameConfig.tiles(CHARGE_CONTACT_TILES):
			_struck = true
			_deal_damage(foe)
	if _state == State.STUNNED:
		return 0.0  # the strike was parried
	if _strike_time >= CHARGE_DURATION:
		_start_recovery()
		return 0.0
	return _facing * GameConfig.tiles(data.move_speed_tiles * CHARGE_SPEED_MULTIPLIER)


func _on_telegraph_timeout() -> void:
	if _state != State.TELEGRAPH:
		return
	_body.color = data.tint
	attack_released.emit(data.attack_damage)
	if data.behaviour == EnemyData.Behaviour.CHARGER:
		_state = State.STRIKE
		_strike_time = 0.0
		_struck = false
		return
	var foe := _current_target()
	if foe != null and global_position.distance_to(foe.global_position) <= GameConfig.tiles(data.attack_range_tiles * STRIKE_REACH_FACTOR):
		_deal_damage(foe)
	if _state != State.STUNNED:  # a parried strike leaves the attacker staggered, not recovering
		_start_recovery()


func _on_stun_timeout() -> void:
	if _state == State.STUNNED:
		_state = State.MOVE
		if data != null:
			_body.color = data.tint


func _on_recovery_timeout() -> void:
	if _state == State.RECOVER:
		_state = State.MOVE


func _start_recovery() -> void:
	_state = State.RECOVER
	_recovery_timer.start(maxf(data.recovery_seconds, 0.001))


func _deal_damage(foe: Node) -> void:
	if foe.has_method("take_strike"):
		foe.take_strike(data.attack_damage, global_position.x, self)
	elif foe.has_method("take_hit"):
		foe.take_hit(data.attack_damage, global_position.x)


## Health.died is the single place a wind-up is cancelled: a dead enemy deals nothing.
func _on_health_died() -> void:
	_state = State.DEAD
	_telegraph_timer.stop()
	_recovery_timer.stop()
	_stun_timer.stop()
	_body.visible = false
	_hurtbox.set_deferred("monitorable", false)
	_shape.set_deferred("disabled", true)
	_hurtbox_shape.set_deferred("disabled", true)
	died.emit()
	get_tree().create_timer(DEATH_LINGER).timeout.connect(queue_free)


func _current_target() -> Node2D:
	if is_instance_valid(target):
		return target
	return get_tree().get_first_node_in_group("player") as Node2D


func _apply_data() -> void:
	var size := GameConfig.tiles_v(data.body_size_tiles.x, data.body_size_tiles.y)
	(_shape.shape as RectangleShape2D).size = size
	(_hurtbox_shape.shape as RectangleShape2D).size = size
	_body.size = size
	_body.position = -size / 2.0
	_body.color = data.tint
	_health.setup(data.max_health)
