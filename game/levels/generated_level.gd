class_name GeneratedLevel
extends Sandbox
## Rooms chosen by LevelGenerator from data/rooms, laid end to end. Reaching the exit
## builds the next level from the next seed. Everything else (player, HUD, menu, touch)
## comes from Sandbox.

signal level_completed

const ROOM_DIR := "res://data/rooms"

@export var level_seed: int = 1
@export var room_count: int = 6

var _layout: Array[RoomData] = []
var _width_tiles: float = 0.0
var _spawn: Vector2 = Vector2.ZERO

@onready var _rooms: Node2D = $Rooms
@onready var _walls: Node2D = $Walls


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
			# Physics callbacks may not free bodies, so build the next level a frame later.
			zone.body_entered.connect(func(body: Node) -> void: _on_exit_entered.call_deferred(body))
		cursor += room.size_tiles.x
	_width_tiles = cursor

	var wall_top := GROUND_TOP_TILES - WALL_HEIGHT_TILES
	var wall_height := WALL_HEIGHT_TILES + GROUND_THICKNESS_TILES
	_add_block(Rect2(-1.0, wall_top, 1.0, wall_height), GROUND_COLOR, false, _walls)
	_add_block(Rect2(_width_tiles, wall_top, 1.0, wall_height), GROUND_COLOR, false, _walls)


func _on_exit_entered(body: Node) -> void:
	if body is Player:
		level_completed.emit()
		regenerate(level_seed + 1)
