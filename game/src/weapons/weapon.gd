class_name Weapon
extends Node2D

## The runtime half of a weapon: owns the hitbox and the swing clock.
##
## Time is advanced through advance(), called from _physics_process in the
## game and directly from tests. That seam is why the hit window's edges
## are provable instead of inferred from frame counts.

signal hit_landed(target: Node, damage: int)

var data: WeaponData

var _elapsed: float = 0.0
var _attacking: bool = false
var _hit_this_swing: Array[Node] = []

var _hitbox: Area2D
var _hitbox_shape: CollisionShape2D


func _ready() -> void:
	_hitbox = Area2D.new()
	_hitbox.name = "Hitbox"
	# Layer 4 is the attack layer, mask 2 is hurtboxes. Matches player.tscn.
	_hitbox.collision_layer = 4
	_hitbox.collision_mask = 2
	_hitbox.monitoring = false
	_hitbox_shape = CollisionShape2D.new()
	_hitbox.add_child(_hitbox_shape)
	add_child(_hitbox)
	if data != null:
		_shape_hitbox()


## Equips a weapon, cancelling any swing in progress.
##
## The cancel is Review Focus 1: swapping is always legal in this combat
## model, so it can land inside an active hit window. Without the cancel the
## outgoing weapon's hitbox would stay live, and the incoming one would
## inherit the elapsed time -- a long-windowed weapon could come up already
## swinging.
func equip(new_data: WeaponData) -> void:
	cancel_attack()
	data = new_data
	# null is a legitimate empty slot, per Player.equip_slot. Dereferencing
	# it here crashed the first swap whenever a slot was left unfilled.
	if _hitbox_shape != null and data != null:
		_shape_hitbox()


func start_attack() -> void:
	if data == null:
		return
	_attacking = true
	_elapsed = 0.0
	_hit_this_swing.clear()


func cancel_attack() -> void:
	_attacking = false
	_elapsed = 0.0
	_hit_this_swing.clear()
	if _hitbox != null:
		_hitbox.monitoring = false


func is_attacking() -> bool:
	return _attacking


## True only while the hitbox should deal damage.
func is_hitbox_active() -> bool:
	if not _attacking or data == null:
		return false
	return _elapsed >= data.hit_window.x and _elapsed <= data.hit_window.y


## Advances the swing clock. Separated from _physics_process so tests can
## drive it without waiting on frames.
func advance(delta: float) -> void:
	if not _attacking:
		return
	_elapsed += delta
	if data == null or _elapsed >= data.attack_duration:
		cancel_attack()
		return
	_hitbox.monitoring = is_hitbox_active()

	# Polled rather than driven by area_entered, because a target already
	# standing inside the hitbox when the window opens never emits an
	# enter signal -- and that is exactly the point-blank case.
	if is_hitbox_active():
		for area: Area2D in _hitbox.get_overlapping_areas():
			try_hit(area.owner if area.owner != null else area)


## Registers a hit on target, returning whether it counted.
##
## One hit per target per swing. Without that, a hitbox overlapping an enemy
## for six frames deals six hits and every weapon shreds at point-blank
## range.
func try_hit(target: Node) -> bool:
	if not is_hitbox_active():
		return false
	# Never hit whoever is holding this weapon.
	#
	# The hitbox masks the hurtbox layer, and the wielder's own hurtbox sits
	# right at the hitbox's inner edge -- so polling overlaps found the
	# player themselves and routed their swing into their own health, 8 HP
	# a swing with the blade and 15 with the spear, plus a stagger from
	# their own weapon.
	#
	# Guarded here rather than in the polling loop so every caller is
	# covered, and so this holds when enemies get weapons of their own.
	if target == owner:
		return false
	if target in _hit_this_swing:
		return false
	_hit_this_swing.append(target)
	hit_landed.emit(target, data.damage)
	HitStop.freeze(data.hit_stop_seconds)
	return true


func _physics_process(delta: float) -> void:
	advance(delta)


## Mirrors the hitbox to the facing direction. Called by the owner.
func face(direction: float) -> void:
	if data == null:
		return
	var offset := GameConfig.tiles_v(
		data.hitbox_offset_tiles.x, data.hitbox_offset_tiles.y
	)
	_hitbox.position = Vector2(offset.x * signf(direction), offset.y)


func _shape_hitbox() -> void:
	var shape := RectangleShape2D.new()
	shape.size = GameConfig.tiles_v(
		data.hitbox_size_tiles.x, data.hitbox_size_tiles.y
	)
	_hitbox_shape.shape = shape
	face(1.0)
