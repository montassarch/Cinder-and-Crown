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

## How much further the strike reaches than the range that triggered it.
## A little slack, so stepping back on the last frame is not a guaranteed
## dodge -- that is what the roll is for.
const ATTACK_REACH_SLACK: float = 1.3

## Fallback knockback when the hit carries none, in tiles/second. The real
## value comes from the weapon's knockback_tiles.
const HIT_KNOCKBACK_TILES: float = 3.0

## How long a CHARGER's committed rush lasts, and how much faster than its
## walk it travels. The rush is the whole identity of the behaviour: it
## commits to a direction and overshoots, which is what makes a charger
## dodgeable by sidestepping rather than by out-running.
const RUSH_SECONDS: float = 0.35
const RUSH_SPEED_MULTIPLIER: float = 3.0

var data: EnemyData

## What this enemy pursues. Set by whoever spawns it; null means idle.
var target: Node2D = null

var _telegraphing: bool = false
var _telegraph_elapsed: float = 0.0
var _recovery_remaining: float = 0.0
var _rush_remaining: float = 0.0
var _rush_direction: float = 1.0

@onready var health: Health = %Health


func configure(new_data: EnemyData) -> void:
	data = new_data
	health.configure(data.max_health)
	_apply_placeholder_body()


func _ready() -> void:
	health.died.connect(_on_died)
	attack_released.connect(_on_attack_released)
	if data != null:
		configure(data)


## Takes a hit from the player's weapon. Mirrors Player.take_hit so both
## sides of combat go through one named entry point rather than reaching
## into each other's Health.
func take_hit(amount: int, from_position: Vector2, knockback_tiles: float = -1.0) -> int:
	if not health.is_alive():
		return 0
	var absorbed := health.take_damage(amount)
	if absorbed > 0:
		var away := signf(global_position.x - from_position.x)
		# Per-weapon, not a constant: the field exists so a designer can
		# tune how much a weapon shoves, and a constant made it inert.
		var push := knockback_tiles if knockback_tiles >= 0.0 else HIT_KNOCKBACK_TILES
		velocity.x = (away if away != 0.0 else 1.0) * GameConfig.tiles(push)
		# Being hit interrupts a committed rush.
		_rush_remaining = 0.0
	return absorbed


func is_telegraphing() -> bool:
	return _telegraphing


## Starts the wind-up. Ignored if already winding up -- restarting would
## let an enemy telegraph forever without ever striking -- and ignored if
## dead.
func begin_telegraph() -> void:
	if _telegraphing or data == null or not health.is_alive():
		return
	# The recovery pause after a strike is the window the player counters
	# into. Without this guard an enemy in contact re-wound up on the very
	# next frame and had no punish window at all.
	if _recovery_remaining > 0.0:
		return
	_telegraphing = true
	_telegraph_elapsed = 0.0


func is_recovering() -> bool:
	return _recovery_remaining > 0.0


func is_rushing() -> bool:
	return _rush_remaining > 0.0


## Cancels a wind-up with no strike. Called on death, which is Review
## Focus 4: a corpse that still lands its hit reads as the game cheating.
func cancel_telegraph() -> void:
	_telegraphing = false
	_telegraph_elapsed = 0.0


## Advances the telegraph clock. Separated from _physics_process so tests
## can drive it directly.
func advance(delta: float) -> void:
	# Recovery and rush timers run whether or not a wind-up is in progress,
	# so they must tick before the telegraph early-out.
	_recovery_remaining = maxf(_recovery_remaining - delta, 0.0)
	_rush_remaining = maxf(_rush_remaining - delta, 0.0)

	if not _telegraphing:
		return
	_telegraph_elapsed += delta
	if _telegraph_elapsed < data.telegraph_seconds:
		return
	_telegraphing = false
	_telegraph_elapsed = 0.0
	# Checked again here rather than trusting the earlier guard: the enemy
	# may have died during the wind-up, between frames.
	if not health.is_alive():
		return

	_recovery_remaining = data.recovery_seconds
	if data.behaviour == EnemyData.Behaviour.CHARGER:
		_rush_remaining = RUSH_SECONDS
		_rush_direction = (
			signf(target.global_position.x - global_position.x) if target != null else 1.0
		)
		if _rush_direction == 0.0:
			_rush_direction = 1.0
	attack_released.emit(data.attack_damage)


## Chooses this frame's velocity and whether to start winding up.
##
## Separated from _physics_process, like advance(), so the movement rules
## are testable without a running scene.
func decide(delta: float) -> void:
	if data == null or not health.is_alive():
		velocity = Vector2.ZERO
		return

	var flying := data.behaviour == EnemyData.Behaviour.FLYER

	# A committed rush overrides pursuit: the charger keeps going in the
	# direction it chose, which is what makes it dodgeable by sidestepping
	# instead of by out-running it.
	if _rush_remaining > 0.0:
		velocity.x = _rush_direction * GameConfig.tiles(
			data.move_speed_tiles * RUSH_SPEED_MULTIPLIER
		)
		if flying:
			velocity.y = 0.0
		else:
			velocity.y += GameConfig.tiles(GameConfig.GRAVITY_TILES) * delta
		return

	if _telegraphing:
		# Holding still is most of what makes a wind-up readable. An enemy
		# that keeps closing while telegraphing cannot be reacted to.
		velocity.x = 0.0
		if flying:
			velocity.y = 0.0
		else:
			velocity.y += GameConfig.tiles(GameConfig.GRAVITY_TILES) * delta
		return

	if target == null:
		velocity.x = 0.0
		if flying:
			velocity.y = 0.0
		else:
			velocity.y += GameConfig.tiles(GameConfig.GRAVITY_TILES) * delta
		return

	var to_target := target.global_position - global_position
	var distance_tiles := to_target.length() / float(GameConfig.TILE_SIZE)
	var speed := GameConfig.tiles(data.move_speed_tiles)

	if distance_tiles <= data.attack_range_tiles:
		begin_telegraph()
		velocity.x = 0.0
		if flying:
			velocity.y = 0.0
	elif flying:
		# Moves on both axes by choice and never accumulates gravity, so a
		# bat hovers rather than sinking between decisions.
		velocity = to_target.normalized() * speed
	else:
		velocity.x = signf(to_target.x) * speed

	if not flying:
		velocity.y += GameConfig.tiles(GameConfig.GRAVITY_TILES) * delta


func _physics_process(delta: float) -> void:
	advance(delta)
	decide(delta)
	move_and_slide()


## Lands the strike if the target is still close enough. The enemy commits
## to the wind-up before knowing whether it will connect, which is what
## gives the player something to dodge.
func _on_attack_released(damage: int) -> void:
	if target == null or data == null:
		return
	var distance_tiles := global_position.distance_to(
		target.global_position
	) / float(GameConfig.TILE_SIZE)
	if distance_tiles > data.attack_range_tiles * ATTACK_REACH_SLACK:
		return
	if target.has_method(&"take_hit"):
		target.take_hit(damage, global_position)


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
