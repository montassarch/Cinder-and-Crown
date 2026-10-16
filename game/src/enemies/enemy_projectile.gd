class_name EnemyProjectile
extends Area2D
## An ember an enemy throws. It flies straight and hurts the hero through take_strike, so a
## parry catches it: a parried shot flies back, now hostile to enemies, for double damage
## (triple after a perfect parry). It disappears on any hit, on a wall, or past its range.
## Physics layers: 1 world, 4 hero hurtbox (8), 5 enemy hurtbox (16).

const WORLD_MASK: int = 1
const HERO_HURTBOX_MASK: int = 8
const ENEMY_HURTBOX_MASK: int = 16
const RADIUS: float = 3.0
const REFLECT_MULTIPLIER: int = 2
const PERFECT_REFLECT_MULTIPLIER: int = 3
const COLOR := Color(1.0, 0.55, 0.15)
const REFLECTED_COLOR := Color(0.6, 0.95, 1.0)
const KNOCKBACK_TILES: float = 1.0

var damage: int = 0

var _direction: float = 1.0
var _speed: float = 0.0
var _max_distance: float = 0.0
var _travelled: float = 0.0
var _shooter: Node
var _reflected: bool = false


func _init() -> void:
	add_to_group(Enemy.ATTACK_GROUP)
	collision_layer = 0
	collision_mask = HERO_HURTBOX_MASK | WORLD_MASK
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


## direction: +1 right, -1 left. Distances and speed in pixels.
func launch(direction: float, speed_px: float, max_distance_px: float, hit_damage: int, shooter: Node) -> void:
	_direction = signf(direction) if direction != 0.0 else 1.0
	_speed = speed_px
	_max_distance = max_distance_px
	damage = hit_damage
	_shooter = shooter
	queue_redraw()


func is_reflected() -> bool:
	return _reflected


## The hero deflected it: it turns round and now hurts enemies instead.
func on_parried(perfect: bool, _from_x: float) -> void:
	if _reflected:
		return
	_reflected = true
	_direction = -_direction
	damage *= PERFECT_REFLECT_MULTIPLIER if perfect else REFLECT_MULTIPLIER
	# Deferred: this runs inside the physics callback that delivered the hit.
	set_deferred("collision_mask", ENEMY_HURTBOX_MASK | WORLD_MASK)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var step := _speed * delta
	global_position.x += _direction * step
	_travelled += step
	if _travelled >= _max_distance:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null:
		return
	if _reflected:
		if target.has_method("take_hit"):
			target.take_hit(damage, global_position.x, KNOCKBACK_TILES)
		queue_free()
		return
	if target.has_method("take_strike"):
		target.take_strike(damage, _source_x(), self)
	elif target.has_method("take_hit"):
		target.take_hit(damage, _source_x())
	if not _reflected:  # a parry turned it round instead of spending it
		queue_free()


func _on_body_entered(_body: Node) -> void:
	queue_free()


func _source_x() -> float:
	if is_instance_valid(_shooter) and _shooter is Node2D:
		return (_shooter as Node2D).global_position.x
	return global_position.x - _direction * RADIUS


func _draw() -> void:
	var color := REFLECTED_COLOR if _reflected else COLOR
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color.WHITE)
