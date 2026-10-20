class_name RendWave
extends Area2D
## Crimson Rend's travelling wave: a crackle of red lightning that races along the ground, hits every
## enemy in its path once, and dies at a wall or at the end of its range. Its look is a pre-rendered
## animation (see LightningArt), not lines drawn every tick.

const SPEED_TILES: float = 14.0
const RANGE_TILES: float = 10.0
const DAMAGE: int = 14
const KNOCKBACK_TILES: float = 2.0
const HEIGHT_TILES: float = 2.4
const WIDTH_TILES: float = 0.9
## Kept just above the ground so the floor itself does not stop it.
const LIFT_TILES: float = 0.1
const WORLD_MASK: int = 1
const ENEMY_HURTBOX_MASK: int = 16

## The art is 64 x 48 px, faces right, with its head on the right edge and its bottom on the ground.
const ART_FPS: float = 20.0
const ART_SIZE := Vector2(64.0, 48.0)
const ART_HEAD_X: float = 62.0

var direction: float = 1.0

var _travelled: float = 0.0
var _hit: Array[Node] = []
var _shape: CollisionShape2D
var _art: AnimatedSprite2D


func _init() -> void:
	collision_layer = 0
	collision_mask = WORLD_MASK | ENEMY_HURTBOX_MASK
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(WIDTH_TILES, HEIGHT_TILES)
	shape.shape = rect
	shape.position = Vector2(0.0, -GameConfig.tiles(HEIGHT_TILES / 2.0 + LIFT_TILES))
	add_child(shape)
	_shape = shape
	_art = LightningArt.sprite(&"wave_red", ART_FPS, true)
	_art.name = "Art"
	_art.centered = false
	_art.flip_h = direction < 0.0
	add_child(_art)


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# `direction` is set after _init, so the sprite is placed now
	_art.flip_h = direction < 0.0
	var head_x := ART_HEAD_X if direction >= 0.0 else ART_SIZE.x - ART_HEAD_X - 1.0
	_art.position = Vector2(-head_x, -ART_SIZE.y - GameConfig.tiles(LIFT_TILES))


func _physics_process(delta: float) -> void:
	var step := GameConfig.tiles(SPEED_TILES) * delta
	position.x += step * signf(direction)
	_travelled += step
	_art.modulate.a = clampf((1.0 - _travelled / GameConfig.tiles(RANGE_TILES)) / 0.35, 0.3, 1.0)
	if _travelled >= GameConfig.tiles(RANGE_TILES) or _overlaps_wall():
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target == null or _hit.has(target):
		return
	_hit.append(target)
	if target.has_method("take_hit"):
		target.take_hit(DAMAGE, global_position.x - signf(direction) * GameConfig.tiles(1.0), KNOCKBACK_TILES)


## Areas are not told about static walls they move into, so ask the physics space directly.
func _overlaps_wall() -> bool:
	if not is_inside_tree():
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape.shape
	query.transform = _shape.global_transform
	query.collision_mask = WORLD_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body: Object = hit["collider"]
		if body is StaticBody2D and not _is_one_way(body):
			return true
	return false


func _is_one_way(body: Node) -> bool:
	for child in body.get_children():
		if child is CollisionShape2D and child.one_way_collision:
			return true
	return false
