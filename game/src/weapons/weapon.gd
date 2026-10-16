class_name Weapon
extends Node2D
## Runtime half of a WeaponData: owns the hitbox and the swing clock.
## Targets are anything with an enemy-hurtbox Area2D (physics layer 5) whose parent
## offers take_hit(damage: int, source_x: float, knockback_tiles: float).

signal hit_landed(target: Node, damage: int)

const ENEMY_HURTBOX_MASK: int = 16

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

var _elapsed: float = 0.0
## Real seconds per second of swing time; > 1 plays the whole swing (and its hit window) slower.
var _duration_scale: float = 1.0
var _attacking: bool = false
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
	_apply_geometry()


func set_facing(facing: float) -> void:
	_facing = signf(facing) if facing != 0.0 else _facing
	_apply_geometry()


func start_attack(duration_scale: float = 1.0) -> void:
	if data == null:
		return
	_hit_targets.clear()
	_duration_scale = maxf(duration_scale, 0.01)
	_elapsed = 0.0
	_attacking = true
	_sync_hitbox()


func cancel_attack() -> void:
	_attacking = false
	_elapsed = 0.0
	_hit_targets.clear()
	_sync_hitbox()


func advance(delta: float) -> void:
	if not _attacking:
		return
	_elapsed += delta / _duration_scale
	if _elapsed >= data.attack_duration:
		cancel_attack()
		return
	_sync_hitbox()


func is_hitbox_active() -> bool:
	return _attacking and data != null and _elapsed >= data.hit_window.x and _elapsed < data.hit_window.y


## The hit has come and gone; the rest of the swing is follow-through.
func is_recovering() -> bool:
	return _attacking and data != null and _elapsed >= data.hit_window.y


func hitbox_size() -> Vector2:
	return (_shape.shape as RectangleShape2D).size


func hitbox_center() -> Vector2:
	return _hitbox.position


## The live hitbox in world space (for the debug overlay).
func hitbox_global_rect() -> Rect2:
	var size := hitbox_size()
	return Rect2(global_position + hitbox_center() - size / 2.0, size)


func _apply_geometry() -> void:
	if data == null:
		return
	(_shape.shape as RectangleShape2D).size = GameConfig.tiles_v(data.hitbox_size_tiles.x, data.hitbox_size_tiles.y)
	_hitbox.position = GameConfig.tiles_v(data.hitbox_offset_tiles.x * _facing, data.hitbox_offset_tiles.y)


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
	var damage := Damage.compute(data.damage + bonus_damage, damage_multiplier * next_hit_multiplier, 0)
	if target.has_method("take_hit"):
		target.take_hit(damage, global_position.x, data.knockback_tiles)
	if stun_chance > 0.0 and rng.randf() < stun_chance and target.has_method("stun"):
		target.stun(stun_seconds)
	hit_landed.emit(target, damage)
	HitStop.freeze(data.hit_stop_seconds)
