class_name LevelGeneratorTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# LevelGenerator is a pure static function over a seed, which is what makes
# a run reproducible: the same seed must rebuild the same level exactly, or
# a bug found in a run can never be revisited.
#
# Review Focus 3 lives here: a degenerate pool must terminate rather than
# spin forever trying to satisfy "no two identical rooms in a row".

const LG := preload("res://src/level/level_generator.gd")


func _room(kind: RoomData.Kind, name: String = "room") -> RoomData:
	var data := RoomData.new()
	data.kind = kind
	data.display_name = name
	data.size_tiles = Vector2i(24, 14)
	return data


func _pool(normal_count: int) -> Array[RoomData]:
	var pool: Array[RoomData] = [
		_room(RoomData.Kind.SPAWN, "spawn"),
		_room(RoomData.Kind.EXIT, "exit"),
	]
	for i: int in range(normal_count):
		pool.append(_room(RoomData.Kind.NORMAL, "normal_%d" % i))
	return pool


# --- determinism ---

func test_same_seed_produces_identical_layout() -> void:
	var pool := _pool(4)
	var first := LG.generate(pool, 6, 12345)
	var second := LG.generate(pool, 6, 12345)
	assert_int(first.size()).is_equal(second.size())
	for i: int in range(first.size()):
		assert_object(first[i]).is_same(second[i])


func test_different_seeds_produce_different_layouts() -> void:
	# Not guaranteed for any single pair of seeds, so this searches a few.
	# A generator that ignored its seed would fail for all of them.
	var pool := _pool(6)
	var baseline := LG.generate(pool, 8, 1)
	var found_difference := false
	for seed_value: int in [2, 3, 4, 5, 6, 7, 8]:
		var other := LG.generate(pool, 8, seed_value)
		for i: int in range(baseline.size()):
			if baseline[i] != other[i]:
				found_difference = true
				break
		if found_difference:
			break
	assert_bool(found_difference).is_true()


# --- structure ---

func test_first_room_is_always_spawn() -> void:
	for seed_value: int in range(10):
		var level := LG.generate(_pool(4), 5, seed_value)
		assert_int(level[0].kind).is_equal(RoomData.Kind.SPAWN)


func test_last_room_is_always_exit() -> void:
	for seed_value: int in range(10):
		var level := LG.generate(_pool(4), 5, seed_value)
		assert_int(level[level.size() - 1].kind).is_equal(RoomData.Kind.EXIT)


func test_returns_requested_room_count() -> void:
	assert_int(LG.generate(_pool(4), 7, 99).size()).is_equal(7)


func test_middle_rooms_are_all_normal() -> void:
	# A second spawn or exit mid-level would be a dead end or an early out.
	var level := LG.generate(_pool(4), 6, 42)
	for i: int in range(1, level.size() - 1):
		assert_int(level[i].kind).is_equal(RoomData.Kind.NORMAL)


func test_no_two_identical_rooms_in_a_row_when_pool_allows_it() -> void:
	var level := LG.generate(_pool(5), 10, 7)
	for i: int in range(1, level.size()):
		assert_object(level[i]).override_failure_message(
			"room %d repeated immediately" % i
		).is_not_same(level[i - 1])


# --- Review Focus 3: degenerate pools ---

func test_single_normal_room_pool_returns_without_looping() -> void:
	# Review Focus 3. With one NORMAL room, "no repeats" is unsatisfiable.
	# The rule must be a bounded preference, not a loop condition, or this
	# hangs the game instead of building a level.
	var level := LG.generate(_pool(1), 6, 3)
	assert_int(level.size()).is_equal(6)
	assert_int(level[0].kind).is_equal(RoomData.Kind.SPAWN)
	assert_int(level[5].kind).is_equal(RoomData.Kind.EXIT)


func test_empty_pool_returns_empty_array() -> void:
	var empty: Array[RoomData] = []
	assert_array(LG.generate(empty, 5, 1)).is_empty()


func test_pool_without_an_exit_room_returns_empty_array() -> void:
	# Better an empty result than a level the player cannot leave.
	var pool: Array[RoomData] = [_room(RoomData.Kind.SPAWN), _room(RoomData.Kind.NORMAL)]
	assert_array(LG.generate(pool, 5, 1)).is_empty()


func test_pool_without_a_spawn_room_returns_empty_array() -> void:
	var pool: Array[RoomData] = [_room(RoomData.Kind.NORMAL), _room(RoomData.Kind.EXIT)]
	assert_array(LG.generate(pool, 5, 1)).is_empty()


func test_pool_without_normal_rooms_still_builds_spawn_and_exit() -> void:
	var pool: Array[RoomData] = [_room(RoomData.Kind.SPAWN), _room(RoomData.Kind.EXIT)]
	var level := LG.generate(pool, 5, 1)
	assert_int(level.size()).is_equal(2)
	assert_int(level[0].kind).is_equal(RoomData.Kind.SPAWN)
	assert_int(level[1].kind).is_equal(RoomData.Kind.EXIT)


func test_room_count_below_two_is_clamped_to_spawn_and_exit() -> void:
	# A level is at least somewhere to start and somewhere to leave.
	for requested: int in [-5, 0, 1, 2]:
		var level := LG.generate(_pool(3), requested, 1)
		assert_int(level.size()).is_equal(2)


func test_shipped_rooms_load_from_disk() -> void:
	var paths: Array[String] = [
		"res://data/rooms/room_spawn.tres",
		"res://data/rooms/room_a.tres",
		"res://data/rooms/room_b.tres",
		"res://data/rooms/room_exit.tres",
	]
	for path: String in paths:
		assert_object(load(path)).override_failure_message(
			"%s did not load as RoomData" % path
		).is_instanceof(RoomData)


func test_shipped_rooms_cover_all_three_kinds() -> void:
	var kinds := {}
	for path: String in [
		"res://data/rooms/room_spawn.tres",
		"res://data/rooms/room_a.tres",
		"res://data/rooms/room_exit.tres",
	]:
		kinds[(load(path) as RoomData).kind] = true
	assert_int(kinds.size()).is_equal(3)


func test_shipped_rooms_generate_a_valid_level() -> void:
	# End to end on the real data, not constructed fixtures.
	var pool: Array[RoomData] = []
	for path: String in [
		"res://data/rooms/room_spawn.tres",
		"res://data/rooms/room_a.tres",
		"res://data/rooms/room_b.tres",
		"res://data/rooms/room_exit.tres",
	]:
		pool.append(load(path))
	var level := LG.generate(pool, 5, 2026)
	assert_int(level.size()).is_equal(5)
	assert_int(level[0].kind).is_equal(RoomData.Kind.SPAWN)
	assert_int(level[4].kind).is_equal(RoomData.Kind.EXIT)
	for room: RoomData in level:
		assert_object(room.scene).is_not_null()


# --- room placement ---

const RunLevelScript := preload("res://src/level/run_level.gd")


func test_room_offsets_lay_rooms_end_to_end() -> void:
	# An off-by-one here is rooms overlapping or a gap the player falls
	# through -- both tedious to spot by eye, trivial to assert.
	var level: Array[RoomData] = [
		_room(RoomData.Kind.SPAWN), _room(RoomData.Kind.NORMAL),
	]
	level[0].size_tiles = Vector2i(24, 14)
	level[1].size_tiles = Vector2i(28, 14)

	var offsets: Array[float] = RunLevelScript.room_offsets(level)
	assert_float(offsets[0]).is_equal(0.0)
	assert_float(offsets[1]).is_equal(GameConfig.tiles(24.0))


func test_room_offsets_are_empty_for_an_empty_level() -> void:
	var empty: Array[RoomData] = []
	assert_array(RunLevelScript.room_offsets(empty)).is_empty()


func test_total_width_is_the_sum_of_room_widths() -> void:
	var level: Array[RoomData] = [
		_room(RoomData.Kind.SPAWN), _room(RoomData.Kind.EXIT),
	]
	level[0].size_tiles = Vector2i(24, 14)
	level[1].size_tiles = Vector2i(20, 14)
	assert_float(RunLevelScript.total_width(level)).is_equal(GameConfig.tiles(44.0))


func test_offsets_are_measured_in_tiles_not_pixels() -> void:
	# The resolution rule: widths are authored in tiles, so the pixel
	# offsets must come out of GameConfig rather than a literal.
	var level: Array[RoomData] = [_room(RoomData.Kind.SPAWN)]
	level[0].size_tiles = Vector2i(10, 14)
	assert_float(RunLevelScript.total_width(level)).is_equal(10.0 * GameConfig.TILE_SIZE)
