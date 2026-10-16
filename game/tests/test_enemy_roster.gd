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

func test_the_wisp_data_is_valid_and_unlocked_at_depth_two() -> void:
	var wisp := _enemy("ember_wisp")
	assert_int(wisp.behaviour).is_equal(EnemyData.Behaviour.KEEP_DISTANCE)
	assert_int(wisp.unlock_depth).is_equal(2)
	assert_int(wisp.moves.size()).is_equal(1)
	assert_int(wisp.moves[0].kind).is_equal(EnemyMove.Kind.PROJECTILE)
	assert_bool(wisp.moves[0].parryable).is_true()
	assert_float(wisp.preferred_range_tiles).is_greater(0.0)
	assert_float(wisp.moves[0].range_tiles).is_greater(wisp.preferred_range_tiles)

func _floor() -> void:
	var floor_body: StaticBody2D = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(60.0, 1.0)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = GameConfig.tiles_v(10.0, 6.0)
	add_child(floor_body)

func test_the_brute_charges_then_slams() -> void:
	var brute := _enemy("crown_brute")
	assert_int(brute.moves.size()).is_equal(2)
	assert_int(brute.moves[0].kind).is_equal(EnemyMove.Kind.DASH)
	assert_int(brute.moves[1].kind).is_equal(EnemyMove.Kind.SLAM)
	assert_bool(brute.moves[0].parryable).is_false()
	assert_bool(brute.moves[1].parryable).is_false()
	assert_int(brute.pattern).is_equal(EnemyData.Pattern.SEQUENCE)

func test_the_real_brute_plays_its_charge_then_its_slam() -> void:
	_floor()
	var brute: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	add_child(brute)
	brute.configure(load("res://data/enemies/crown_brute.tres"))
	brute.global_position = GameConfig.tiles_v(3.0, 3.0)
	var hero: Node2D = auto_free(load("res://tests/support/strike_recorder.gd").new())
	add_child(hero)
	hero.global_position = GameConfig.tiles_v(7.0, 5.0)
	brute.target = hero
	var released: Array = []
	brute.attack_released.connect(func(damage: int) -> void: released.append(damage))
	await get_tree().create_timer(0.0).timeout
	for i in 300:
		await get_tree().physics_frame
		if released.size() >= 2:
			break
	assert_array(released.slice(0, 2)).is_equal([20, 16])

func test_the_bat_dives_and_is_exposed_afterwards() -> void:
	var bat := _enemy("cinder_bat")
	assert_int(bat.moves.size()).is_equal(1)
	assert_int(bat.moves[0].kind).is_equal(EnemyMove.Kind.DIVE)
	assert_bool(bat.moves[0].parryable).is_false()
	assert_float(bat.moves[0].exposed_seconds).is_greater(0.0)

func test_the_migrated_enemies_keep_their_threat_and_cell_reward() -> void:
	assert_int(_enemy("crown_brute").threat).is_equal(5)
	assert_int(_enemy("crown_brute").cell_reward).is_equal(3)
	assert_int(_enemy("cinder_bat").threat).is_equal(3)
	assert_int(_enemy("cinder_bat").cell_reward).is_equal(1)

func test_the_brute_unlocks_at_depth_four_and_the_bat_at_one() -> void:
	assert_int(_enemy("crown_brute").unlock_depth).is_equal(4)
	assert_int(_enemy("cinder_bat").unlock_depth).is_equal(1)

func test_the_penitent_data_is_valid() -> void:
	var penitent := _enemy("penitent")
	assert_bool(penitent.shielded).is_true()
	assert_int(penitent.poise).is_greater(1)
	assert_int(penitent.moves.size()).is_equal(1)
	assert_int(penitent.moves[0].kind).is_equal(EnemyMove.Kind.MELEE)
	assert_bool(penitent.moves[0].parryable).is_true()
	assert_int(penitent.unlock_depth).is_equal(3)
	assert_int(penitent.max_per_wave).is_equal(1)
