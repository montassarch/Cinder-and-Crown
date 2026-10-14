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
const VIOLET := Color(0.62, 0.14, 0.55)
const GLOW := Color(0.78, 0.2, 0.62, 0.4)
const FORKS: int = 5
const SPIKE_GAP_TILES: float = 1.8
const SPIKE_POINTS: int = 6
const SPIKE_BASE_WIDTH: float = 3.6

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


## Crimson Rend's look: a jagged forked bolt of black-cored red lightning races along the
## ground, and black spikes with a red-orange rim and violet glow erupt upward as it passes,
## tallest at the head. Re-rolled every few ticks so it crackles.
func _draw() -> void:
	var d := signf(direction)
	var ground := -GameConfig.tiles(LIFT_TILES)
	var fade := clampf((1.0 - _travelled / GameConfig.tiles(RANGE_TILES)) / 0.35, 0.3, 1.0)
	# Ground bolt from where the wave started to its head (the node's origin).
	var back := minf(_travelled, GameConfig.tiles(RANGE_TILES))
	var start := Vector2(-d * back, ground)
	var ground_bolt := _jagged(start, Vector2(0.0, ground), maxi(int(back / 9.0), 2), 3.0, 0)
	draw_polyline(ground_bolt, Color(GLOW, GLOW.a * fade), 7.0)
	draw_polyline(ground_bolt, Color(EDGE, fade), 4.0)
	draw_polyline(ground_bolt, Color(VIOLET, fade), 2.0)
	draw_polyline(ground_bolt, Color(CORE, fade), 1.0)
	# Forks branching up off the bolt.
	for k in FORKS:
		var index := 1 + int(_flicker(k) * float(ground_bolt.size() - 2))
		var root := ground_bolt[clampi(index, 0, ground_bolt.size() - 1)]
		var reach := 12.0 + 10.0 * _flicker(k + 70)
		var tip := root + Vector2(d * (4.0 + 8.0 * _flicker(k + 90)), -reach)
		var fork := _jagged(root, tip, 5, 3.0, 100 + k)
		draw_polyline(fork, Color(GLOW, GLOW.a * fade), 5.0)
		draw_polyline(fork, Color(EDGE, fade), 3.0)
		draw_polyline(fork, Color(CORE, fade), 1.0)
	# Spikes erupting at fixed spots along the path, rising then sinking as time passes.
	var gap := GameConfig.tiles(SPIKE_GAP_TILES)
	var speed := GameConfig.tiles(SPEED_TILES)
	var k := 1
	while float(k) * gap <= _travelled:
		var age := (_travelled - float(k) * gap) / speed
		var rise := clampf(age / 0.05, 0.0, 1.0)
		var sink := clampf(1.0 - (age - 0.15) / 0.6, 0.0, 1.0)
		if rise * sink > 0.05:
			var local_x := -d * (_travelled - float(k) * gap)
			var size := 0.55 + 0.3 * minf(float(k) / 4.0, 1.0)
			_spike(Vector2(local_x, ground), GameConfig.tiles(HEIGHT_TILES) * size * rise * sink, d, 100 + k, fade)
		k += 1
	_spike(Vector2(0.0, ground), GameConfig.tiles(HEIGHT_TILES) * (0.85 + 0.15 * _flicker(5)) * fade, d, 7, fade)


## A tapering black spike (rim, violet glow, core) leaning with the wave's direction.
func _spike(base: Vector2, height: float, d: float, seed_value: int, fade: float) -> void:
	var spine := _jagged(base, base + Vector2(d * height * 0.18, -height), SPIKE_POINTS, 2.2, seed_value)
	var half := PackedFloat32Array()
	var normals := PackedVector2Array()
	for i in spine.size():
		var t := float(i) / float(spine.size() - 1)
		half.append(maxf(SPIKE_BASE_WIDTH * pow(1.0 - t, 0.85) * (0.7 + 0.3 * fade), 0.4))
		var tangent := (spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
		normals.append(Vector2(-tangent.y, tangent.x) * d)
	var none := PackedFloat32Array()
	none.resize(spine.size())
	_claw_layer(spine, normals, half, none, none, 1.9, 1.9, Color(GLOW, GLOW.a * fade))
	_claw_layer(spine, normals, half, none, none, 1.4, 1.25, Color(EDGE, fade))
	_claw_layer(spine, normals, half, none, none, 1.15, 1.05, Color(VIOLET, fade))
	_claw_layer(spine, normals, half, none, none, 0.8, 0.85, Color(CORE, fade))


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


## One filled strip along `spine`, `front_scale` / `back_scale` times as wide as `half`.
func _claw_layer(spine: PackedVector2Array, normals: PackedVector2Array, half: PackedFloat32Array, front_extra: PackedFloat32Array, back_extra: PackedFloat32Array, front_scale: float, back_scale: float, colour: Color) -> void:
	var colours := PackedColorArray([colour, colour, colour])
	for i in spine.size() - 1:
		var a_front := spine[i] + normals[i] * (half[i] + front_extra[i]) * front_scale
		var a_back := spine[i] - normals[i] * (half[i] + back_extra[i]) * back_scale
		var b_front := spine[i + 1] + normals[i + 1] * (half[i + 1] + front_extra[i + 1]) * front_scale
		var b_back := spine[i + 1] - normals[i + 1] * (half[i + 1] + back_extra[i + 1]) * back_scale
		draw_primitive(PackedVector2Array([a_front, a_back, b_back]), colours, PackedVector2Array())
		draw_primitive(PackedVector2Array([a_front, b_back, b_front]), colours, PackedVector2Array())


## 0..1, re-rolled every few ticks so the bolts crackle.
func _flicker(seed_value: int) -> float:
	var h := (_tick / 3) * 17 + seed_value * 31
	return fposmod(sin(float(h) * 12.9898) * 43758.5453, 1.0)
