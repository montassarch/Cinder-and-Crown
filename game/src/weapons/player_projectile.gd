class_name PlayerProjectile
extends Area2D
## A shot from the hero's bow or wand. It flies straight, strikes enemies through the weapon that fired it (so
## damage, hit sparks and boons all apply), passes through as many as its move allows, and stops on a wall or
## past its range. Physics layers: 1 world, 5 enemy hurtbox (16).

const WORLD_MASK: int = 1
const ENEMY_HURTBOX_MASK: int = 16
const TRAIL_PIXELS: float = 9.0

var _direction := Vector2.RIGHT
var _speed: float = 0.0
var _max_distance: float = 0.0
var _travelled: float = 0.0
var _pierce_left: int = 0
var _weapon: Weapon
var _move: WeaponMove
var _hit: Array[Node] = []


func _init() -> void:
	collision_layer = 0
	collision_mask = ENEMY_HURTBOX_MASK | WORLD_MASK
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	add_child(shape)
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	z_index = 20
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


## direction: any vector (it is normalised).
func launch(weapon: Weapon, move: WeaponMove, direction: Vector2) -> void:
	_weapon = weapon
	_move = move
	_direction = direction.normalized()
	_speed = GameConfig.tiles(move.projectile_speed_tiles)
	_max_distance = GameConfig.tiles(move.projectile_range_tiles)
	_pierce_left = move.projectile_pierce
	((get_child(0) as CollisionShape2D).shape as CircleShape2D).radius = move.projectile_radius
	rotation = _direction.angle()
	queue_redraw()


func direction() -> Vector2:
	return _direction


func _physics_process(delta: float) -> void:
	var step := _speed * delta
	global_position += _direction * step
	_travelled += step
	if _travelled >= _max_distance:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null or _hit.has(target) or not is_instance_valid(_weapon):
		return
	_hit.append(target)
	_weapon.strike(target, _move, global_position.x)
	if _pierce_left <= 0:
		queue_free()
	_pierce_left -= 1


func _on_body_entered(_body: Node) -> void:
	queue_free()


func _draw() -> void:
	if _move == null:
		return
	var radius := _move.projectile_radius
	var tint := _move.projectile_tint
	draw_line(Vector2(-TRAIL_PIXELS, 0.0), Vector2.ZERO, Color(tint, 0.35), radius * 1.2)
	draw_circle(Vector2.ZERO, radius * 1.8, Color(tint, 0.25))
	draw_circle(Vector2.ZERO, radius, tint)
	draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
