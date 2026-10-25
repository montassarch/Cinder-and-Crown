class_name Weapon
extends Node2D
## Runtime half of a WeaponData: owns the hitbox and the swing clock.
## Targets are anything with an enemy-hurtbox Area2D (physics layer 5) whose parent
## offers take_hit(damage: int, source_x: float, knockback_tiles: float).

signal hit_landed(target: Node, damage: int)

const ENEMY_HURTBOX_MASK: int = 16
## Where a shot leaves the hero, ahead of him, in pixels.
const MUZZLE_FORWARD_PIXELS: float = 10.0
const MUZZLE_HEIGHT_PIXELS: float = -4.0

var data: WeaponData
## Temporary modifiers from abilities (Storm Blade sets these while the blade is charged).
var bonus_damage: int = 0
var stun_chance: float = 0.0
var stun_seconds: float = 0.0
## Run-wide damage scaling (boons set this).
var damage_multiplier: float = 1.0
## Scales the next landed hit only (a riposte); whoever sets it clears it.
var next_hit_multiplier: float = 1.0
var rng := RandomNumberGenerator.new()
## Where shots are added (the level); the current scene when unset.
var projectile_parent: Node

var _elapsed: float = 0.0
## Real seconds per second of swing time; > 1 plays the whole swing (and its hit window) slower.
var _duration_scale: float = 1.0
var _attacking: bool = false
var _fired: bool = false
var _move: WeaponMove
var _facing: float = 1.0
var _hit_targets: Array[Node] = []
var _hitbox: Area2D
var _shape: CollisionShape2D


func _init() -> void:
	_hitbox = Area2D.new()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = ENEMY_HURTBOX_MASK
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	_shape = CollisionShape2D.new()
	_shape.shape = RectangleShape2D.new()
	_hitbox.add_child(_shape)
	add_child(_hitbox)
	_hitbox.area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	advance(delta)


## Always cancels first: a swap mid-swing withdraws the old hitbox and the new
## weapon starts from zero rather than inheriting the old window's progress.
func equip(new_data: WeaponData) -> void:
	cancel_attack()
	data = new_data
	_move = data.chain_move(0) if data != null else null
	_apply_geometry()


func set_facing(facing: float) -> void:
	_facing = signf(facing) if facing != 0.0 else _facing
	_apply_geometry()


## The weapon's first strike (the plain swing).
func start_attack(duration_scale: float = 1.0) -> void:
	start_move(data.chain_move(0) if data != null else null, duration_scale)


func start_move(move: WeaponMove, duration_scale: float = 1.0) -> void:
	if data == null or move == null:
		return
	_move = move
	_apply_geometry()
	_hit_targets.clear()
	_fired = false
	_duration_scale = maxf(duration_scale, 0.01)
	_elapsed = 0.0
	_attacking = true
	_sync_hitbox()


func cancel_attack() -> void:
	_attacking = false
	_fired = false
	_elapsed = 0.0
	_hit_targets.clear()
	_sync_hitbox()


func advance(delta: float) -> void:
	if not _attacking:
		return
	_elapsed += delta / _duration_scale
	if _elapsed >= _move.duration:
		cancel_attack()
		return
	if _move.kind == WeaponMove.Kind.PROJECTILE and not _fired and _elapsed >= _move.hit_window.x:
		_fired = true
		_fire()
	_sync_hitbox()


func current_move() -> WeaponMove:
	return _move


func is_hitbox_active() -> bool:
	return _attacking and _move != null and _move.kind == WeaponMove.Kind.MELEE \
			and _elapsed >= _move.hit_window.x and _elapsed < _move.hit_window.y


## The hit has come and gone; the rest of the swing is follow-through.
func is_recovering() -> bool:
	return _attacking and _move != null and _elapsed >= _move.hit_window.y


func hitbox_size() -> Vector2:
	return (_shape.shape as RectangleShape2D).size


func hitbox_center() -> Vector2:
	return _hitbox.position


## The live hitbox in world space (for the debug overlay).
func hitbox_global_rect() -> Rect2:
	var size := hitbox_size()
	return Rect2(global_position + hitbox_center() - size / 2.0, size)


func _apply_geometry() -> void:
	if _move == null:
		return
	(_shape.shape as RectangleShape2D).size = GameConfig.tiles_v(_move.hitbox_size_tiles.x, _move.hitbox_size_tiles.y)
	_hitbox.position = GameConfig.tiles_v(_move.hitbox_offset_tiles.x * _facing, _move.hitbox_offset_tiles.y)


func _sync_hitbox() -> void:
	_hitbox.set_deferred("monitoring", is_hitbox_active())


func _on_area_entered(area: Area2D) -> void:
	# Re-check here: an overlap can be queued before a swap/cancel and arrive after it.
	if not is_hitbox_active():
		return
	var target := area.get_parent()
	if target == null or _hit_targets.has(target):
		return
	_hit_targets.append(target)
	strike(target, _move, global_position.x)


## Lands one hit of `move` on `target`: damage, knockback, stun chance, the hit signal and the hit stop.
func strike(target: Node, move: WeaponMove, source_x: float) -> void:
	var base := roundi(data.damage * move.damage_multiplier) + bonus_damage
	var damage := Damage.compute(base, damage_multiplier * next_hit_multiplier, 0)
	if target.has_method("take_hit"):
		target.take_hit(damage, source_x, move.knockback_tiles)
	if stun_chance > 0.0 and rng.randf() < stun_chance and target.has_method("stun"):
		target.stun(stun_seconds)
	hit_landed.emit(target, damage)
	HitStop.freeze(move.hit_stop_seconds)


func _fire() -> void:
	var parent := projectile_parent if projectile_parent != null else get_tree().current_scene
	if parent == null:
		return
	var count := maxi(_move.projectile_count, 1)
	for i in count:
		var fan := 0.0 if count == 1 else _move.projectile_spread_degrees * (float(i) / float(count - 1) - 0.5)
		var angle := deg_to_rad(_move.projectile_angle_degrees + fan)
		var shot := PlayerProjectile.new()
		parent.add_child(shot)
		shot.global_position = global_position + Vector2(_facing * MUZZLE_FORWARD_PIXELS, MUZZLE_HEIGHT_PIXELS)
		shot.launch(self, _move, Vector2(_facing * cos(angle), sin(angle)))
