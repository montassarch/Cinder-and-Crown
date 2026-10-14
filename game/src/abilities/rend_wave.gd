class_name RendWave
extends Area2D
## Crimson Rend's travelling wave: a tall crescent of red lightning that races along the
## ground, hits every enemy in its path once, and dies at a wall or at the end of its range.
## Drawn in the abyssal palette: black core, hot red-orange edge, magenta-violet glow.

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

const CORE := Color(0.05, 0.0, 0.02)
const EDGE := Color(1.0, 0.33, 0.2)
const GLOW := Color(0.78, 0.2, 0.62, 0.45)

var direction: float = 1.0

var _travelled: float = 0.0
var _hit: Array[Node] = []
var _tick: int = 0
var _shape: CollisionShape2D


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


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	var step := GameConfig.tiles(SPEED_TILES) * delta
	position.x += step * signf(direction)
	_travelled += step
	_tick += 1
	queue_redraw()
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


func _draw() -> void:
	var h := GameConfig.tiles(HEIGHT_TILES)
	var w := GameConfig.tiles(WIDTH_TILES)
	var lift := GameConfig.tiles(LIFT_TILES)
	var d := signf(direction)
	var fade := clampf(1.0 - _travelled / GameConfig.tiles(RANGE_TILES), 0.25, 1.0)
	# Crescent bulging forward: back edge straight-ish, front edge a curve.
	var points := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var t := float(i) / steps
		var y := -lift - h * t
		var bulge := sin(t * PI) * w * 1.4
		var jitter := (1.0 if (i + _tick) % 3 == 0 else 0.0)
		points.append(Vector2(d * (bulge + jitter), y))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		var y := -lift - h * t
		points.append(Vector2(d * (sin(t * PI) * w * 0.5 - w * 0.3), y))
	var glow := PackedVector2Array()
	for p in points:
		glow.append(Vector2(p.x * 1.5 - d * 2.0, p.y))
	draw_colored_polygon(glow, Color(GLOW.r, GLOW.g, GLOW.b, GLOW.a * fade))
	draw_colored_polygon(points, Color(EDGE.r, EDGE.g, EDGE.b, fade))
	var core := PackedVector2Array()
	for p in points:
		core.append(Vector2(p.x * 0.55, p.y))
	draw_colored_polygon(core, CORE)
	# Crackle: a few short red sparks trailing behind.
	for k in 3:
		var sy := -lift - h * (0.2 + 0.3 * k) - float((_tick * 7 + k * 13) % 9)
		var sx := -d * (4.0 + float((_tick * 5 + k * 11) % 10))
		draw_line(Vector2(sx, sy), Vector2(sx - d * 5.0, sy + 3.0), Color(EDGE.r, EDGE.g, EDGE.b, 0.8 * fade), 1.0)
