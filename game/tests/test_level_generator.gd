extends GdUnitTestSuite

const Kind := RoomData.Kind

func _room(kind: Kind, room_name: String) -> RoomData:
	var room := RoomData.new()
	room.kind = kind
	room.resource_name = room_name
	return room

func _names(layout: Array[RoomData]) -> Array:
	var names := []
	for room in layout:
		names.append(room.resource_name)
	return names

func _pool() -> Array[RoomData]:
	var pool: Array[RoomData] = [
		_room(Kind.SPAWN, "spawn"),
		_room(Kind.NORMAL, "a"), _room(Kind.NORMAL, "b"), _room(Kind.NORMAL, "c"),
		_room(Kind.EXIT, "exit"),
	]
	return pool

func test_same_seed_produces_identical_layout() -> void:
	var first := LevelGenerator.generate(_pool(), 12, 42)
	var second := LevelGenerator.generate(_pool(), 12, 42)
	assert_array(_names(first)).is_equal(_names(second))

func test_different_seeds_produce_different_layouts() -> void:
	var first := LevelGenerator.generate(_pool(), 12, 1)
	var second := LevelGenerator.generate(_pool(), 12, 2)
	assert_array(_names(first)).is_not_equal(_names(second))

func test_first_room_is_always_spawn() -> void:
	for seed_value in 20:
		var layout := LevelGenerator.generate(_pool(), 6, seed_value)
		assert_int(layout[0].kind).is_equal(Kind.SPAWN)

func test_last_room_is_always_exit() -> void:
	for seed_value in 20:
		var layout := LevelGenerator.generate(_pool(), 6, seed_value)
		assert_int(layout[layout.size() - 1].kind).is_equal(Kind.EXIT)

func test_middle_rooms_are_all_normal() -> void:
	var layout := LevelGenerator.generate(_pool(), 10, 5)
	for i in range(1, layout.size() - 1):
		assert_int(layout[i].kind).is_equal(Kind.NORMAL)

func test_returns_requested_room_count() -> void:
	for count in [2, 3, 6, 15]:
		assert_int(LevelGenerator.generate(_pool(), count, 3).size()).is_equal(count)

func test_no_two_identical_rooms_in_a_row_when_pool_allows_it() -> void:
	for seed_value in 30:
		var layout := LevelGenerator.generate(_pool(), 30, seed_value)
		for i in range(1, layout.size()):
			assert_object(layout[i]).is_not_same(layout[i - 1])

func test_a_pool_with_one_normal_room_relaxes_the_no_repeat_rule(timeout := 3000) -> void:
	# Review Focus 3: a pool of one cannot satisfy "no repeats"; it must
	# relax that rule rather than spin forever.
	var pool: Array[RoomData] = [_room(Kind.SPAWN, "spawn"), _room(Kind.NORMAL, "only"), _room(Kind.EXIT, "exit")]
	var layout := LevelGenerator.generate(pool, 6, 9)
	assert_array(_names(layout)).is_equal(["spawn", "only", "only", "only", "only", "exit"])

func test_a_pool_of_a_single_room_returns_empty_without_looping(timeout := 3000) -> void:
	var pool: Array[RoomData] = [_room(Kind.NORMAL, "lonely")]
	assert_array(LevelGenerator.generate(pool, 5, 1)).is_empty()

func test_empty_pool_returns_empty_array(timeout := 3000) -> void:
	var pool: Array[RoomData] = []
	assert_array(LevelGenerator.generate(pool, 5, 1)).is_empty()

func test_pool_without_an_exit_room_returns_empty_array() -> void:
	var pool: Array[RoomData] = [_room(Kind.SPAWN, "spawn"), _room(Kind.NORMAL, "a")]
	assert_array(LevelGenerator.generate(pool, 4, 1)).is_empty()

func test_pool_without_a_spawn_room_returns_empty_array() -> void:
	var pool: Array[RoomData] = [_room(Kind.NORMAL, "a"), _room(Kind.EXIT, "exit")]
	assert_array(LevelGenerator.generate(pool, 4, 1)).is_empty()

func test_pool_without_normal_rooms_cannot_fill_a_longer_level() -> void:
	var pool: Array[RoomData] = [_room(Kind.SPAWN, "spawn"), _room(Kind.EXIT, "exit")]
	assert_array(LevelGenerator.generate(pool, 4, 1)).is_empty()
	assert_array(_names(LevelGenerator.generate(pool, 2, 1))).is_equal(["spawn", "exit"])

func test_fewer_than_two_rooms_is_unsatisfiable() -> void:
	assert_array(LevelGenerator.generate(_pool(), 1, 1)).is_empty()
	assert_array(LevelGenerator.generate(_pool(), 0, 1)).is_empty()
	assert_array(LevelGenerator.generate(_pool(), -3, 1)).is_empty()

func test_generate_does_not_mutate_the_pool() -> void:
	var pool := _pool()
	var before := _names(pool)
	LevelGenerator.generate(pool, 8, 4)
	assert_array(_names(pool)).is_equal(before)
