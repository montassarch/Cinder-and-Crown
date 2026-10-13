class_name Enemy
extends CharacterBody2D

## One enemy body, driven entirely by an EnemyData resource.
##
## There is no Shambler class and no Bat class. Behaviour comes from the
## data's `behaviour` enum, which is the only thing this file switches on,
## so a fourth enemy type needs a .tres file and nothing else.
##
## Like Weapon, time advances through advance() so the telegraph's timing
## is provable in a test rather than counted in frames.

signal attack_released(damage: int)
signal died

var data: EnemyData

var _telegraphing: bool = false
var _telegraph_elapsed: float = 0.0

@onready var health: Health = %Health


func configure(new_data: EnemyData) -> void:
	data = new_data
	health.configure(data.max_health)
	_apply_placeholder_body()


func _ready() -> void:
	health.died.connect(_on_died)
	if data != null:
		configure(data)


func is_telegraphing() -> bool:
	return _telegraphing


## Starts the wind-up. Ignored if already winding up -- restarting would
## let an enemy telegraph forever without ever striking -- and ignored if
## dead.
func begin_telegraph() -> void:
	if _telegraphing or data == null or not health.is_alive():
		return
	_telegraphing = true
	_telegraph_elapsed = 0.0


## Cancels a wind-up with no strike. Called on death, which is Review
## Focus 4: a corpse that still lands its hit reads as the game cheating.
func cancel_telegraph() -> void:
	_telegraphing = false
	_telegraph_elapsed = 0.0


## Advances the telegraph clock. Separated from _physics_process so tests
## can drive it directly.
func advance(delta: float) -> void:
	if not _telegraphing:
		return
	_telegraph_elapsed += delta
	if _telegraph_elapsed < data.telegraph_seconds:
		return
	_telegraphing = false
	_telegraph_elapsed = 0.0
	# Checked again here rather than trusting the earlier guard: the enemy
	# may have died during the wind-up, between frames.
	if health.is_alive():
		attack_released.emit(data.attack_damage)


func _physics_process(delta: float) -> void:
	advance(delta)
	if data == null or not health.is_alive():
		return
	if data.behaviour != EnemyData.Behaviour.FLYER:
		velocity.y += GameConfig.tiles(GameConfig.GRAVITY_TILES) * delta
	move_and_slide()


func _on_died() -> void:
	# Review Focus 4: the queued strike dies with the enemy.
	cancel_telegraph()
	died.emit()


func _apply_placeholder_body() -> void:
	var body := GameConfig.tiles_v(data.body_size_tiles.x, data.body_size_tiles.y)

	var shape := RectangleShape2D.new()
	shape.size = body
	(%EnemyShape as CollisionShape2D).shape = shape

	var hurt_shape := RectangleShape2D.new()
	hurt_shape.size = body
	(%EnemyHurtboxShape as CollisionShape2D).shape = hurt_shape

	var rect := %Placeholder as ColorRect
	rect.size = body
	rect.position = -body * 0.5
	rect.color = data.tint
