class_name Enemy
extends CharacterBody2D
## Physics layers: 1 world, 3 enemy body, 5 enemy hurtbox (weapons hit layer 5).
## Behaviour is chosen by EnemyData.behaviour; every number comes from the data.

signal attack_released(damage: int)
signal died
## The poise ran out: the enemy is staggered and takes extra damage for a moment.
signal guard_broken
## The enemy blew itself up. It is gone without being killed, so `died` is not emitted
## (a self-destruct pays no cells).
signal exploded

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
## Past this share of its wind-up an enemy is committed: hits no longer stop the strike.
const COMMIT_FRACTION: float = 0.5
const FLINCH_SECONDS: float = 0.2
## A ranged enemy tolerates the hero this far either side of its preferred range.
const KEEP_DISTANCE_MARGIN_TILES: float = 1.0
## Where a shot leaves the enemy, ahead of its body.
const SHOT_MUZZLE_TILES: float = 0.8
## The floor ring that warns of a slam.
const SLAM_TELL_RADIUS_TILES: float = 2.0
## A dive ends when it is this close to the spot it was aimed at.
const DIVE_ARRIVE_TILES: float = 0.3
## Physics layer of the level's solid ground and ledges.
const WORLD_MASK: int = 1
## A flyer with a ledge in its way slides along it this long before trying the other side.
const FLYER_DETOUR_SECONDS: float = 4.0
## Shots, shockwaves and blast flashes join this group so a restarted level can sweep them up.
const ATTACK_GROUP := &"enemy_attacks"
const SHIELD_FLASH_COLOR := Color(0.85, 0.9, 1.0)
const SHIELD_FLASH_SECONDS: float = 0.1
const BLAST_COLOR := Color(1.0, 0.55, 0.1, 0.6)
const BLAST_FLASH_SECONDS: float = 0.3
## A broken guard: how long the enemy reels, and how much harder it is hit meanwhile.
const BREAK_STAGGER: float = 1.6
const BREAK_DAMAGE_MULTIPLIER: float = 1.5
const BREAK_TINT := Color(1.0, 0.6, 0.15)
## Poise refills in full after this long without a hit.
const POISE_REGEN_DELAY: float = 2.0
## The on-screen tell above a winding-up enemy: a ring that closes exactly as the strike lands.
const TELL_HEIGHT_PIXELS: float = 12.0
const TELL_START_RADIUS: float = 14.0
const TELL_END_RADIUS: float = 3.0
const TELL_COLOR := Color(1.0, 0.25, 0.2)
const TELL_COMMITTED_COLOR := Color(1.0, 0.85, 0.25)
## A dodge-only attack (it cannot be parried): roll or jump.
const TELL_DODGE_COLOR := Color(1.0, 0.55, 0.1)
const POISE_PIP_SIZE: float = 3.0
const POISE_PIP_GAP: float = 2.0
## How long a parried strike leaves the attacker staggered, and how far it is shoved back.
const PARRY_STAGGER: float = 0.8
const PERFECT_PARRY_STAGGER: float = 1.3
const PARRY_KNOCKBACK_TILES: float = 1.5

## Who this enemy hunts. Falls back to the first node in group "player".
var target: Node2D
var data: EnemyData

var _state: State = State.MOVE
var _move: EnemyMove
var _move_index: int = 0
## A dive latches the hero's position when its wind-up commits, then flies there.
var _dive_target: Vector2 = Vector2.ZERO
var _dive_velocity: Vector2 = Vector2.ZERO
## A blocked flyer slides this way (+1 right, -1 left) along the ledge until it has a clear line to the hero.
var _detour_dir: float = 0.0
var _detour_left: float = 0.0
## Seconds before the enemy may begin another attack (the rest after a whole string).
var _rest_left: float = 0.0
## Picks the move of a RANDOM pattern; tests seed it.
var rng := RandomNumberGenerator.new()
var _facing: float = 1.0
var _knockback_x: float = 0.0
var _strike_time: float = 0.0
var _struck: bool = false
var _age: float = 0.0
## How many times the enemy has been drawn (tests check the tell keeps being redrawn).
var draw_count: int = 0
var _shield_flash_left: float = 0.0
var _poise: int = 0
var _poise_idle: float = 0.0
var _vulnerable_left: float = 0.0
## The sprite, when this enemy has art (the coloured box is then hidden but keeps carrying the state colour).
var _art: EnemyVisual

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


func body_color() -> Color:
	return _body.color


## Highest point of the enemy: its sprite's head when it has one, else the top of its box.
func head_top() -> float:
	var hitbox_top := -GameConfig.tiles(data.body_size_tiles.y) / 2.0
	return minf(hitbox_top, _art.head_top()) if _art != null else hitbox_top


## +1 when the enemy faces right, -1 left.
func facing() -> float:
	return _facing


## The attack being played (winding up, striking or recovering); null between attacks.
func current_move() -> EnemyMove:
	return _move


func move_index() -> int:
	return _move_index


func is_telegraphing() -> bool:
	return _state == State.TELEGRAPH


func is_dead() -> bool:
	return _state == State.DEAD


func is_stunned() -> bool:
	return _state == State.STUNNED


func poise() -> int:
	return _poise


func is_guard_broken() -> bool:
	return _vulnerable_left > 0.0


## 0 as the wind-up starts, 1 as the strike lands; 0 whenever it is not winding up.
func telegraph_progress() -> float:
	if _state != State.TELEGRAPH or data == null or _move == null:
		return 0.0
	return clampf(1.0 - _telegraph_timer.time_left / maxf(_move.telegraph_seconds, 0.001), 0.0, 1.0)


## The colour of the ring over a winding-up enemy: red to parry, orange to dodge, yellow once
## the strike is committed; transparent when it is not winding up.
func tell_color() -> Color:
	if _state != State.TELEGRAPH or _move == null:
		return Color.TRANSPARENT
	if is_committed():
		return TELL_COMMITTED_COLOR
	return TELL_COLOR if _move.parryable else TELL_DODGE_COLOR


## The strike is coming whatever lands on the enemy (only a guard break stops it).
func is_committed() -> bool:
	return _state == State.STRIKE or (_state == State.TELEGRAPH and telegraph_progress() >= COMMIT_FRACTION)


## Freezes the enemy and cancels whatever it was winding up or doing.
func stun(seconds: float) -> void:
	if _state == State.DEAD or seconds <= 0.0:
		return
	_telegraph_timer.stop()
	_recovery_timer.stop()
	_move = null
	_move_index = 0
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


## Starts an attack: the first move of a string, or one random move.
func begin_telegraph() -> void:
	if data == null or _state != State.MOVE or _rest_left > 0.0:
		return
	var moves := data.effective_moves()
	var index := 0
	if data.pattern == EnemyData.Pattern.RANDOM and moves.size() > 1:
		index = rng.randi_range(0, moves.size() - 1)
	_start_move(index)


func _start_move(index: int) -> void:
	var foe := _current_target()
	if foe != null:
		_facing = signf(foe.global_position.x - global_position.x) if foe.global_position.x != global_position.x else _facing
	_move_index = index
	_move = data.effective_moves()[index]
	_state = State.TELEGRAPH
	_body.color = TELEGRAPH_FLASH
	_telegraph_timer.start(maxf(_move.telegraph_seconds, 0.001))


## A SEQUENCE string goes on to its next move; a RANDOM attack is one move.
func _has_next_move() -> bool:
	return data.pattern == EnemyData.Pattern.SEQUENCE and _move_index + 1 < data.effective_moves().size()


## Contract used by Weapon: damage lands, health drops, the body is knocked back.
func take_hit(damage: int, source_x: float, knockback_tiles: float = 0.0) -> void:
	if _state == State.DEAD:
		return
	if data.shielded and not is_guard_broken() and _is_front_hit(source_x):
		_absorb_with_shield()
		return
	if is_guard_broken():
		damage = ceili(damage * BREAK_DAMAGE_MULTIPLIER)
	_health.take_damage(damage)
	if _art != null:
		_art.flash()
	if _state == State.DEAD:
		return
	if knockback_tiles > 0.0:
		var direction := signf(global_position.x - source_x)
		_knockback_x = direction * GameConfig.tiles(sqrt(2.0 * KNOCKBACK_DECAY * knockback_tiles))
	_react_to_hit()


## True when a hit came from the side the enemy faces (its shield side).
func _is_front_hit(source_x: float) -> bool:
	return (source_x - global_position.x) * _facing >= 0.0


## A shield takes the whole blow, but a poised enemy's poise still wears down, so a guard can
## still be broken from the front.
func _absorb_with_shield() -> void:
	_shield_flash_left = SHIELD_FLASH_SECONDS
	_body.color = SHIELD_FLASH_COLOR
	if data.poise > 0:
		_react_to_hit()


## The colour the body should show for what the enemy is doing (after a shield flash ends).
func _state_color() -> Color:
	match _state:
		State.TELEGRAPH:
			return TELEGRAPH_FLASH
		State.STUNNED:
			return BREAK_TINT if is_guard_broken() else STUN_TINT
	return BREAK_TINT if is_guard_broken() else data.tint


## Poised enemies wear their poise down and break; light ones flinch unless they are already
## committed to a strike, recovering, or reeling.
func _react_to_hit() -> void:
	_poise_idle = 0.0
	if data.poise > 0 and not is_guard_broken():
		_poise -= 1
		if _poise <= 0:
			_break_guard()
		return
	if _state == State.STUNNED or _state == State.RECOVER or is_committed():
		return
	stun(FLINCH_SECONDS)


func _break_guard() -> void:
	_poise = data.poise
	_vulnerable_left = BREAK_STAGGER
	stun(BREAK_STAGGER)
	_body.color = BREAK_TINT
	guard_broken.emit()


func _physics_process(delta: float) -> void:
	if data == null or _state == State.DEAD:
		return
	_age += delta
	if _shield_flash_left > 0.0:
		_shield_flash_left -= delta
		if _shield_flash_left <= 0.0:
			_body.color = _state_color()
	_rest_left = maxf(0.0, _rest_left - delta)
	_vulnerable_left = maxf(0.0, _vulnerable_left - delta)
	_tick_poise(delta)
	_knockback_x = move_toward(_knockback_x, 0.0, GameConfig.tiles(KNOCKBACK_DECAY) * delta)

	var foe := _current_target()
	if _state == State.TELEGRAPH and _move != null and _move.kind == EnemyMove.Kind.DIVE and not is_committed() and foe != null:
		_dive_target = foe.global_position
	if data.shielded and foe != null and _state == State.MOVE:  # not while recovering: its back stays open
		var side := foe.global_position.x - global_position.x
		if side != 0.0:
			_facing = signf(side)
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
	if _state == State.STRIKE and _move != null and _move.kind == EnemyMove.Kind.DIVE:
		velocity.y = _dive_velocity.y
	move_and_slide()
	queue_redraw()  # the tell and the poise pips change with the state, so redraw every frame
	_update_art()


## Shows the sprite for what the enemy is doing, tinted when it is stunned, broken or blocking.
func _update_art() -> void:
	if _art == null:
		return
	var move: EnemyMove = _move if _move != null else data.effective_moves()[0]
	var colour := _body.color
	var tint := Color.WHITE if colour == data.tint or colour == TELEGRAPH_FLASH else colour.lerp(Color.WHITE, 0.2)
	_art.show_state(_state, _facing, absf(velocity.x) > 1.0, move.kind, move.telegraph_seconds, move.active_seconds, move.recovery_seconds, tint)


func _tick_poise(delta: float) -> void:
	if data.poise <= 0 or _poise >= data.poise or is_guard_broken():
		return
	_poise_idle += delta
	if _poise_idle >= POISE_REGEN_DELAY:
		_poise = data.poise


## Returns horizontal velocity; FLYER also sets velocity.y directly.
func _think_move(foe: Node2D, delta: float) -> float:
	if foe == null:
		return 0.0
	var offset := foe.global_position - global_position
	var speed := GameConfig.tiles(data.move_speed_tiles)
	var reach := GameConfig.tiles(data.attack_range_tiles)

	match data.behaviour:
		EnemyData.Behaviour.FLYER:
			if not has_clear_path_to(foe):
				return _slide_round_the_ledge(offset, speed, delta)
			_detour_dir = 0.0
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
		EnemyData.Behaviour.KEEP_DISTANCE:
			return _keep_distance(offset, speed)
		_:
			if absf(offset.x) <= reach * 0.9 and absf(offset.y) <= GameConfig.tiles(2.0):
				begin_telegraph()
				return 0.0
			return signf(offset.x) * speed


## True when no solid ground or ledge lies on the straight line from this enemy to `other`.
func has_clear_path_to(other: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, other.global_position, WORLD_MASK)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## A flyer over a ledge cannot dive through it and the hero cannot reach it, so it never winds up there: it slides
## sideways (toward the hero's side, switching sides now and then or at a wall) until the way is clear.
func _slide_round_the_ledge(offset: Vector2, speed: float, delta: float) -> float:
	_detour_left -= delta
	if _detour_dir == 0.0:
		_detour_dir = signf(offset.x) if absf(offset.x) > 1.0 else _facing
		_detour_left = FLYER_DETOUR_SECONDS
	elif _detour_left <= 0.0 or is_on_wall():
		_detour_dir = -_detour_dir
		_detour_left = FLYER_DETOUR_SECONDS
	velocity.y = 0.0
	return _detour_dir * speed


## Ranged enemies stand at their preferred range: back off when the hero is closer than
## that (less a margin), close in when farther, and shoot from the band in between. Backed
## against a wall they shoot rather than stand idle.
func _keep_distance(offset: Vector2, speed: float) -> float:
	var distance := absf(offset.x)
	var preferred := GameConfig.tiles(data.preferred_range_tiles)
	var margin := GameConfig.tiles(KEEP_DISTANCE_MARGIN_TILES)
	var level := absf(offset.y) <= GameConfig.tiles(2.0)
	if distance < preferred - margin:
		if is_on_wall() and level:
			begin_telegraph()
			return 0.0
		return -signf(offset.x) * speed
	if distance > preferred + margin:
		return signf(offset.x) * speed
	if level:
		begin_telegraph()
	return 0.0


## A rush (DASH): runs at the hero for the move's duration and hits on contact.
func _think_strike(foe: Node2D, delta: float) -> float:
	if _move.kind == EnemyMove.Kind.DIVE:
		return _think_dive(foe, delta)
	_strike_time += delta
	if foe != null and not _struck:
		if global_position.distance_to(foe.global_position) <= GameConfig.tiles(_move.reach_tiles):
			_struck = true
			_hit_hero(foe, _move)
	if _state == State.STUNNED:
		return 0.0  # the strike was parried
	if _strike_time >= _move.active_seconds:
		_start_recovery()
		return 0.0
	return _facing * GameConfig.tiles(_move.speed_tiles)


## A dive flies at the spot the hero stood when the wind-up committed, hurts on contact, and
## lands there: the enemy is then exposed (see _start_recovery).
func _think_dive(foe: Node2D, delta: float) -> float:
	_strike_time += delta
	if foe != null and not _struck and global_position.distance_to(foe.global_position) <= GameConfig.tiles(_move.reach_tiles):
		_struck = true
		_hit_hero(foe, _move)
	if _state == State.STUNNED:
		_dive_velocity = Vector2.ZERO
		return 0.0
	if _strike_time >= _move.active_seconds or global_position.distance_to(_dive_target) <= GameConfig.tiles(DIVE_ARRIVE_TILES):
		_dive_velocity = Vector2.ZERO
		_start_recovery()
		return 0.0
	return _dive_velocity.x


func _on_telegraph_timeout() -> void:
	if _state != State.TELEGRAPH:
		return
	var move := _move  # a parry inside _hit_hero clears _move, so keep our own reference
	_body.color = data.tint
	attack_released.emit(move.damage)
	match move.kind:
		EnemyMove.Kind.DASH, EnemyMove.Kind.DIVE:
			_state = State.STRIKE
			_strike_time = 0.0
			_struck = false
			if move.kind == EnemyMove.Kind.DIVE:
				var aim := _dive_target - global_position
				var heading := aim.normalized() if aim.length() > 1.0 else Vector2(_facing, 0.0)
				_dive_velocity = heading * GameConfig.tiles(move.speed_tiles)
			return
		EnemyMove.Kind.PROJECTILE:
			_fire_projectile(move)
		EnemyMove.Kind.SLAM:
			_launch_waves(move)
		EnemyMove.Kind.EXPLODE:
			var target_foe := _current_target()
			if target_foe != null and global_position.distance_to(target_foe.global_position) <= GameConfig.tiles(move.reach_tiles):
				_hit_hero(target_foe, move)
			if _state == State.STUNNED:
				return  # a parry cancelled the blast
			_explode(move)
			return
		EnemyMove.Kind.MELEE:
			var foe := _current_target()
			if foe != null and _melee_reaches(foe, move):
				_hit_hero(foe, move)
	if _state != State.STUNNED:  # a parried strike leaves the attacker staggered, not recovering
		_start_recovery()


## A swing lands when the hero is within reach; a shielded enemy also has to face him, so
## a hero who has stepped round behind it is not stabbed through its back.
func _melee_reaches(foe: Node2D, move: EnemyMove) -> bool:
	if global_position.distance_to(foe.global_position) > GameConfig.tiles(move.reach_tiles * STRIKE_REACH_FACTOR):
		return false
	return not data.shielded or _is_front_hit(foe.global_position.x)


func _fire_projectile(move: EnemyMove) -> void:
	var shot := EnemyProjectile.new()
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector2(_facing * GameConfig.tiles(SHOT_MUZZLE_TILES), 0.0)
	shot.launch(_facing, GameConfig.tiles(move.speed_tiles), GameConfig.tiles(move.range_tiles), move.damage, self)


## A slam sends a shockwave along the floor each way.
func _launch_waves(move: EnemyMove) -> void:
	var feet_y := global_position.y + GameConfig.tiles(data.body_size_tiles.y) / 2.0
	for direction in [-1.0, 1.0]:
		var wave := FloorWave.new()
		get_parent().add_child(wave)
		wave.global_position = Vector2(global_position.x + direction * GameConfig.tiles(SHOT_MUZZLE_TILES), feet_y - FloorWave.STRIP_SIZE.y / 2.0)
		wave.launch(direction, GameConfig.tiles(move.speed_tiles), GameConfig.tiles(move.range_tiles), move.damage)


## The line a rush or dive will follow, as two points relative to the enemy; empty when the
## enemy is not winding up one.
func path_tell() -> PackedVector2Array:
	if _state != State.TELEGRAPH or _move == null:
		return PackedVector2Array()
	match _move.kind:
		EnemyMove.Kind.DASH:
			return PackedVector2Array([Vector2.ZERO, Vector2(_facing * GameConfig.tiles(_move.speed_tiles) * _move.active_seconds, 0.0)])
		EnemyMove.Kind.DIVE:
			return PackedVector2Array([Vector2.ZERO, _dive_target - global_position])
	return PackedVector2Array()


## Radius of the ring on the floor while a slam or an explosion winds up; 0 otherwise.
func ground_tell_radius() -> float:
	if _state != State.TELEGRAPH or _move == null:
		return 0.0
	match _move.kind:
		EnemyMove.Kind.SLAM:
			return GameConfig.tiles(SLAM_TELL_RADIUS_TILES)
		EnemyMove.Kind.EXPLODE:
			return GameConfig.tiles(_move.reach_tiles)
	return 0.0


func _on_stun_timeout() -> void:
	if _state == State.STUNNED:
		_state = State.MOVE
		if data != null:
			_body.color = data.tint


func _on_recovery_timeout() -> void:
	if _state != State.RECOVER:
		return
	if _has_next_move():
		_start_move(_move_index + 1)
		return
	_state = State.MOVE
	_move = null
	_move_index = 0
	_rest_left = data.cooldown_seconds
	_body.color = data.tint


func _start_recovery() -> void:
	_state = State.RECOVER
	if _move.exposed_seconds > 0.0:
		_vulnerable_left = maxf(_vulnerable_left, _move.exposed_seconds)
		_body.color = BREAK_TINT
	var wait := _move.recovery_seconds + (data.chain_gap_seconds if _has_next_move() else 0.0)
	_recovery_timer.start(maxf(wait, 0.001))


## A parryable move goes through take_strike (the hero can deflect it); a dodge-only one is
## a plain hit that only a roll's i-frames or a jump avoid.
func _hit_hero(foe: Node, move: EnemyMove) -> void:
	if move.parryable and foe.has_method("take_strike"):
		foe.take_strike(move.damage, global_position.x, self)
	elif foe.has_method("take_hit"):
		foe.take_hit(move.damage, global_position.x)


## Health.died is the single place a wind-up is cancelled: a dead enemy deals nothing.
func _on_health_died() -> void:
	_leave_play()
	died.emit()


## Takes the enemy out of the fight: no more timers, no body, no hurtbox, freed shortly.
func _leave_play(show_death: bool = true) -> void:
	_state = State.DEAD
	_move = null
	_telegraph_timer.stop()
	_recovery_timer.stop()
	_stun_timer.stop()
	_body.visible = false
	if _art != null:
		if show_death:
			_art.play_death()
		else:
			_art.visible = false
	_hurtbox.set_deferred("monitorable", false)
	_shape.set_deferred("disabled", true)
	_hurtbox_shape.set_deferred("disabled", true)
	get_tree().create_timer(DEATH_LINGER).timeout.connect(queue_free)


## The fuse ran out: a flash the size of the blast, then the enemy is gone (not "killed").
func _explode(move: EnemyMove) -> void:
	var radius := GameConfig.tiles(move.reach_tiles)
	var flash := Polygon2D.new()
	var ring := PackedVector2Array()
	for i in 24:
		ring.append(Vector2.from_angle(TAU * float(i) / 24.0) * radius)
	flash.polygon = ring
	flash.color = BLAST_COLOR
	flash.add_to_group(ATTACK_GROUP)
	get_parent().add_child(flash)
	flash.global_position = global_position
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, BLAST_FLASH_SECONDS)
	get_tree().create_timer(BLAST_FLASH_SECONDS + 0.05).timeout.connect(flash.queue_free)
	_leave_play(false)
	exploded.emit()


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
	_poise = data.poise
	_health.setup(data.max_health)
	if _art != null:
		_art.queue_free()
		_art = null
	_body.visible = true
	if data.art != "" and EnemyVisual.has_art(data.art):
		_art = EnemyVisual.new()
		_art.name = "Art"
		add_child(_art)
		_art.setup(data.art, size.y / 2.0)
		_body.visible = false


func _draw() -> void:
	draw_count += 1
	if data == null or _state == State.DEAD:
		return
	var hitbox_top := -GameConfig.tiles(data.body_size_tiles.y) / 2.0
	var top := head_top()
	if _state == State.TELEGRAPH:
		var color := tell_color()
		var center := Vector2(0.0, top - TELL_HEIGHT_PIXELS)
		var radius := lerpf(TELL_START_RADIUS, TELL_END_RADIUS, telegraph_progress())
		draw_arc(center, radius, 0.0, TAU, 20, color, 2.0)
		draw_rect(Rect2(center.x - 1.0, center.y - 4.0, 2.0, 5.0), color)
		draw_rect(Rect2(center.x - 1.0, center.y + 2.0, 2.0, 2.0), color)
	var path := path_tell()
	if path.size() == 2:
		draw_dashed_line(path[0], path[1], tell_color(), 1.5, 4.0)
	var ground := ground_tell_radius()
	if ground > 0.0:
		var feet := Vector2(0.0, -hitbox_top)
		draw_arc(feet, ground, 0.0, TAU, 32, tell_color(), 1.5)
	if data.poise > 0:
		var width := data.poise * POISE_PIP_SIZE + (data.poise - 1) * POISE_PIP_GAP
		var left := -width / 2.0
		for i in data.poise:
			var filled := i < _poise
			var tint := BREAK_TINT if is_guard_broken() else Color(0.85, 0.85, 0.9)
			var rect := Rect2(left + i * (POISE_PIP_SIZE + POISE_PIP_GAP), top - 5.0, POISE_PIP_SIZE, POISE_PIP_SIZE)
			if filled or is_guard_broken():
				draw_rect(rect, tint)
			else:
				draw_rect(rect, Color(tint, 0.25))
