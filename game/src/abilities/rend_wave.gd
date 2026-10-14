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

const CORE := Color(0.04, 0.0, 0.02)
const EDGE := Color(1.0, 0.33, 0.2)
const HOT := Color(1.0, 0.78, 0.6)
const GLOW := Color(0.78, 0.2, 0.62, 0.4)
const FORKS: int = 5
const SPIKE_GAP_TILES: float = 1.8
const SPIKE_POINTS: int = 7

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


## Crimson Rend's look: a jagged forked bolt of red lightning races along the ground, and tall
## jagged bolts erupt upward along its path as it passes, tallest at the head. Every bolt is a
## violet glow, a red-orange edge, a black band and a hot cream core, re-rolled every few ticks.
func _draw() -> void:
	var d := signf(direction)
	var ground := -GameConfig.tiles(LIFT_TILES)
	var fade := clampf((1.0 - _travelled / GameConfig.tiles(RANGE_TILES)) / 0.35, 0.3, 1.0)
	# Ground bolt from where the wave started to its head (the node's origin).
	var back := minf(_travelled, GameConfig.tiles(RANGE_TILES))
	var ground_bolt := _jagged(Vector2(-d * back, ground), Vector2(0.0, ground), maxi(int(back / 8.0), 2), 3.0, 0)
	_bolt(ground_bolt, 1.0, fade)
	# Forks branching off the ground bolt (up and forward, a couple dipping low).
	for k in FORKS:
		var index := 1 + int(_flicker(k) * float(ground_bolt.size() - 2))
		var root := ground_bolt[clampi(index, 0, ground_bolt.size() - 1)]
		var rise := 10.0 + 14.0 * _flicker(k + 70)
		var tip := root + Vector2(d * (4.0 + 8.0 * _flicker(k + 90)), -rise if k % 3 != 2 else 4.0)
		_bolt(_jagged(root, tip, 5, 3.0, 100 + k), 0.55, fade)
	# Tall bolts erupting at fixed spots along the path, rising then sinking as time passes.
	var gap := GameConfig.tiles(SPIKE_GAP_TILES)
	var speed := GameConfig.tiles(SPEED_TILES)
	var k := 1
	while float(k) * gap <= _travelled:
		var age := (_travelled - float(k) * gap) / speed
		var rise := clampf(age / 0.05, 0.0, 1.0)
		var sink := clampf(1.0 - (age - 0.15) / 0.6, 0.0, 1.0)
		if rise * sink > 0.05:
			var base := Vector2(-d * (_travelled - float(k) * gap), ground)
			var size := 0.5 + 0.3 * minf(float(k) / 4.0, 1.0)
			var top := base + Vector2(d * 2.0, -GameConfig.tiles(HEIGHT_TILES) * size * rise * sink)
			_bolt(_jagged(base, top, SPIKE_POINTS, 3.0, 200 + k), 0.7, fade)
		k += 1
	var head_top := Vector2(d * 2.0, ground - GameConfig.tiles(HEIGHT_TILES) * (0.9 + 0.1 * _flicker(5)))
	_bolt(_jagged(Vector2(0.0, ground), head_top, SPIKE_POINTS, 3.5, 7), 1.0, fade)


## One lightning bolt: violet glow, red-orange edge, black band and a hot cream core.
## `weight` scales its thickness (thin forks are about half).
func _bolt(points: PackedVector2Array, weight: float, fade: float) -> void:
	draw_polyline(points, Color(GLOW, GLOW.a * 0.6 * fade), 4.0 + 4.0 * weight)
	draw_polyline(points, Color(EDGE, fade), maxf(3.0, 5.0 * weight))
	draw_polyline(points, Color(CORE, fade), maxf(1.0, 3.0 * weight))
	if weight >= 0.7:
		draw_polyline(points, Color(HOT, fade), 1.0)


## A jagged line from a to b: `segments` pieces, each point pushed sideways at random.
func _jagged(a: Vector2, b: Vector2, segments: int, amplitude: float, seed_value: int) -> PackedVector2Array:
	var points := PackedVector2Array([a])
	var along := b - a
	var normal := Vector2(-along.y, along.x).normalized()
	for i in range(1, segments):
		var u := float(i) / float(segments)
		var offset := (_flicker(seed_value + i * 3) * 2.0 - 1.0) * amplitude
		points.append(a + along * u + normal * offset)
	points.append(b)
	return points


## 0..1, re-rolled every few ticks so the bolts crackle.
func _flicker(seed_value: int) -> float:
	var h := (_tick / 3) * 17 + seed_value * 31
	return fposmod(sin(float(h) * 12.9898) * 43758.5453, 1.0)
