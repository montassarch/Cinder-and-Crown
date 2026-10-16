extends GdUnitTestSuite
## The shipped enemies and attacks as data.

const MOVE_DIR := "res://data/moves"
const ENEMY_DIR := "res://data/enemies"

func _enemy(file: String) -> EnemyData:
	return load("%s/%s.tres" % [ENEMY_DIR, file]) as EnemyData

func test_every_move_file_is_valid_and_matches_its_file_name() -> void:
	var paths := DataScanner.list(MOVE_DIR)
	assert_int(paths.size()).is_greater(0)
	for path in paths:
		var move := load(path) as EnemyMove
		assert_object(move).is_not_null()
		assert_bool(move.is_valid()).is_true()
		assert_str(move.id).is_equal(path.get_file().get_basename())

func test_the_crown_guard_has_a_three_move_string_ending_in_an_unparryable_heavy() -> void:
	var guard := _enemy("crown_guard")
	assert_int(guard.moves.size()).is_equal(3)
	assert_int(guard.pattern).is_equal(EnemyData.Pattern.SEQUENCE)
	assert_bool(guard.moves[0].parryable).is_true()
	assert_bool(guard.moves[1].parryable).is_true()
	assert_bool(guard.moves[2].parryable).is_false()
	assert_int(guard.moves[2].damage).is_greater(guard.moves[0].damage)
	assert_float(guard.moves[2].telegraph_seconds).is_greater(guard.moves[0].telegraph_seconds)

func test_the_crown_guard_is_unlocked_by_depth_one() -> void:
	assert_int(_enemy("crown_guard").unlock_depth).is_equal(1)

func test_the_crown_guard_starts_its_string_within_its_own_reach() -> void:
	var guard := _enemy("crown_guard")
	assert_float(guard.attack_range_tiles).is_greater_equal(guard.moves[0].reach_tiles)
