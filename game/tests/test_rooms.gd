extends GdUnitTestSuite
## Every room under data/rooms must be a usable chunk. Adding a room is adding files,
## so this test is what stops a bad file from breaking level generation.

const Kind := RoomData.Kind
const ROOM_DIR := "res://data/rooms"

func _all_rooms() -> Array[RoomData]:
	var rooms: Array[RoomData] = []
	for path in DataScanner.list(ROOM_DIR):
		var room := load(path) as RoomData
		if room != null:
			rooms.append(room)
	return rooms

func _shapes(node: Node, found: Array = []) -> Array:
	for child in node.get_children():
		if child is CollisionShape2D:
			found.append(child)
		_shapes(child, found)
	return found

func test_every_kind_is_available() -> void:
	var kinds := []
	for room in _all_rooms():
		kinds.append(room.kind)
	assert_array(kinds).contains([Kind.SPAWN, Kind.NORMAL, Kind.EXIT])
	assert_int(kinds.count(Kind.NORMAL)).is_greater_equal(2)

func test_every_room_has_a_scene_that_instantiates() -> void:
	for room in _all_rooms():
		assert_object(room.scene).is_not_null()
		var instance: Node = auto_free(room.scene.instantiate())
		assert_object(instance).is_instanceof(Node2D)

func test_every_room_has_a_floor_spanning_its_full_width() -> void:
	for room in _all_rooms():
		var instance: Node = auto_free(room.scene.instantiate())
		add_child(instance)
		var bottom := GameConfig.tiles(room.size_tiles.y)
		var covered := 0.0
		for shape: CollisionShape2D in _shapes(instance):
			var size: Vector2 = shape.shape.size
			var top: float = shape.global_position.y - size.y / 2.0
			if is_equal_approx(top, GameConfig.tiles(Sandbox.GROUND_TOP_TILES)):
				covered += size.x
		assert_float(covered).is_equal(GameConfig.tiles(room.size_tiles.x))

func test_all_geometry_stays_inside_the_declared_size() -> void:
	for room in _all_rooms():
		var instance: Node = auto_free(room.scene.instantiate())
		add_child(instance)
		var bounds := Rect2(Vector2.ZERO, GameConfig.tiles_v(room.size_tiles.x, room.size_tiles.y))
		for shape: CollisionShape2D in _shapes(instance):
			var size: Vector2 = shape.shape.size
			var rect := Rect2(shape.global_position - size / 2.0, size)
			assert_bool(bounds.grow(0.01).encloses(rect)).is_true()

func test_platform_heights_are_clearable_jumps() -> void:
	for room in _all_rooms():
		var instance: Node = auto_free(room.scene.instantiate())
		add_child(instance)
		for shape: CollisionShape2D in _shapes(instance):
			if not shape.one_way_collision:
				continue
			var top: float = shape.global_position.y - shape.shape.size.y / 2.0
			var rise := (GameConfig.tiles(Sandbox.GROUND_TOP_TILES) - top) / GameConfig.TILE_SIZE
			var steps := rise / Sandbox.PLATFORM_STEP_TILES
			assert_float(absf(steps - roundf(steps))).is_less(0.01)
			assert_float(steps).is_between(1.0, 2.0)

func test_spawn_rooms_mark_the_player_spawn_and_exit_rooms_have_an_exit_zone() -> void:
	for room in _all_rooms():
		var instance: Node = auto_free(room.scene.instantiate())
		add_child(instance)
		if room.kind == Kind.SPAWN:
			assert_object(instance.get_node_or_null("PlayerSpawn")).is_instanceof(Marker2D)
		if room.kind == Kind.EXIT:
			assert_object(instance.get_node_or_null("ExitZone")).is_instanceof(Area2D)
