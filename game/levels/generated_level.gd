class_name GeneratedLevel
extends Sandbox
## Rooms chosen by LevelGenerator from data/rooms, laid end to end. Reaching the exit
## builds the next level from the next seed. Everything else (player, HUD, menu, touch)
## comes from Sandbox.

signal level_completed

const ROOM_DIR := "res://data/rooms"
const BOON_DIR := "res://data/boons"
const OFFER_COUNT: int = 3

@export var level_seed: int = 1
@export var room_count: int = 6

var _layout: Array[RoomData] = []
var _width_tiles: float = 0.0
var _spawn: Vector2 = Vector2.ZERO
var _boon_pool: Array[BoonData] = []
var _exit_zones: Array[Area2D] = []

@onready var _rooms: Node2D = $Rooms
@onready var _walls: Node2D = $Walls
@onready var _picker: BoonPicker = $BoonPicker


func _ready() -> void:
	super()
	for path in DataScanner.list(BOON_DIR):
		var boon := load(path) as BoonData
		if boon != null:
			_boon_pool.append(boon)
	_picker.chosen.connect(_on_boon_chosen)


func layout() -> Array[RoomData]:
	return _layout


func spawn_point() -> Vector2:
	return _spawn


func arena_width_tiles() -> float:
	return _width_tiles


func arena_height_tiles() -> float:
	var tallest := 0
	for room in _layout:
		tallest = maxi(tallest, room.size_tiles.y)
	return float(tallest) if tallest > 0 else super.arena_height_tiles()


## Builds the next level and puts the player back at its spawn.
func regenerate(new_seed: int) -> void:
	level_seed = new_seed
	for container in [_rooms, _walls]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	clear_enemies()
	_build_arena()
	_apply_camera_limits()
	player.reset(spawn_point())


func _scene_switch() -> Array:
	return ["Sandbox", SANDBOX_PATH]


func _build_arena() -> void:
	_exit_zones.clear()
	var pool: Array[RoomData] = []
	for path in DataScanner.list(ROOM_DIR):
		var room := load(path) as RoomData
		if room != null:
			pool.append(room)
	_layout = LevelGenerator.generate(pool, room_count, level_seed)
	if _layout.is_empty():
		push_error("GeneratedLevel: no valid level from %d rooms in %s (seed %d)" % [pool.size(), ROOM_DIR, level_seed])
		_width_tiles = ARENA_WIDTH_TILES
		_spawn = super.spawn_point()
		return

	var cursor := 0.0
	for room in _layout:
		var instance: Node2D = room.scene.instantiate()
		instance.position = GameConfig.tiles_v(cursor, 0.0)
		_rooms.add_child(instance)
		if room.kind == RoomData.Kind.SPAWN:
			_spawn = (instance.get_node("PlayerSpawn") as Marker2D).global_position
		elif room.kind == RoomData.Kind.EXIT:
			var zone := instance.get_node("ExitZone") as Area2D
			_exit_zones.append(zone)
			# Physics callbacks may not free bodies, so build the next level a frame later.
			zone.body_entered.connect(func(body: Node) -> void: _on_exit_entered.call_deferred(body))
		cursor += room.size_tiles.x
	_width_tiles = cursor

	var wall_top := GROUND_TOP_TILES - WALL_HEIGHT_TILES
	var wall_height := WALL_HEIGHT_TILES + GROUND_THICKNESS_TILES
	_add_block(Rect2(-1.0, wall_top, 1.0, wall_height), GROUND_COLOR, false, _walls)
	_add_block(Rect2(_width_tiles, wall_top, 1.0, wall_height), GROUND_COLOR, false, _walls)


## True when the hero's body really overlaps an exit zone. The physics engine can report
## a zone built this frame as entered by a hero who has since been moved to the spawn.
func _hero_on_exit(hero: Player) -> bool:
	var size := GameConfig.tiles_v(Player.BODY_SIZE_TILES.x, Player.BODY_SIZE_TILES.y)
	var body_rect := Rect2(hero.global_position - size / 2.0, size)
	for zone in _exit_zones:
		if not is_instance_valid(zone) or not zone.is_inside_tree():
			continue
		for child in zone.get_children():
			var shape := (child as CollisionShape2D).shape as RectangleShape2D if child is CollisionShape2D else null
			if shape != null and Rect2(zone.global_position - shape.size / 2.0, shape.size).intersects(body_rect, true):
				return true
	return false


## Reaching the exit offers boons; the next level is built once one is taken.
func _on_exit_entered(body: Node) -> void:
	if not (body is Player) or _picker.is_open() or not _hero_on_exit(body):
		return
	level_completed.emit()
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	var offers := player.build().roll_offers(_boon_pool, OFFER_COUNT, rng)
	if offers.is_empty():
		regenerate(level_seed + 1)
		return
	_touch.release_all()
	_picker.offer(offers)


func _on_boon_chosen(boon: BoonData) -> void:
	player.apply_boon(boon)
	regenerate(level_seed + 1)
