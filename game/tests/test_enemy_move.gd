extends GdUnitTestSuite

func _move(kind: EnemyMove.Kind) -> EnemyMove:
	var m := EnemyMove.new()
	m.id = "test"
	m.kind = kind
	m.telegraph_seconds = 0.5
	m.active_seconds = 0.2
	m.recovery_seconds = 0.5
	m.damage = 5
	m.reach_tiles = 1.5
	m.speed_tiles = 6.0
	m.range_tiles = 10.0
	m.parryable = kind == EnemyMove.Kind.MELEE or kind == EnemyMove.Kind.PROJECTILE
	return m

func test_a_melee_move_needs_a_reach_and_times() -> void:
	var m := _move(EnemyMove.Kind.MELEE)
	assert_bool(m.is_valid()).is_true()
	m.reach_tiles = 0.0
	assert_bool(m.is_valid()).is_false()
	m.reach_tiles = 1.5
	m.telegraph_seconds = 0.0
	assert_bool(m.is_valid()).is_false()
	m.telegraph_seconds = 0.5
	m.active_seconds = 0.0
	assert_bool(m.is_valid()).is_false()

func test_projectile_and_wave_moves_need_speed_and_range() -> void:
	for kind in [EnemyMove.Kind.PROJECTILE, EnemyMove.Kind.SLAM]:
		var m := _move(kind)
		assert_bool(m.is_valid()).is_true()
		m.speed_tiles = 0.0
		assert_bool(m.is_valid()).is_false()
		m.speed_tiles = 6.0
		m.range_tiles = 0.0
		assert_bool(m.is_valid()).is_false()

func test_dash_and_dive_need_speed_and_duration() -> void:
	for kind in [EnemyMove.Kind.DASH, EnemyMove.Kind.DIVE]:
		var m := _move(kind)
		assert_bool(m.is_valid()).is_true()
		m.speed_tiles = 0.0
		assert_bool(m.is_valid()).is_false()
		m.speed_tiles = 6.0
		m.active_seconds = 0.0
		assert_bool(m.is_valid()).is_false()

func test_explosions_need_a_radius() -> void:
	var m := _move(EnemyMove.Kind.EXPLODE)
	assert_bool(m.is_valid()).is_true()
	m.reach_tiles = 0.0
	assert_bool(m.is_valid()).is_false()

func test_effective_moves_returns_the_listed_moves() -> void:
	var data := EnemyData.new()
	var a := _move(EnemyMove.Kind.MELEE)
	var b := _move(EnemyMove.Kind.SLAM)
	data.moves = [a, b] as Array[EnemyMove]
	var moves := data.effective_moves()
	assert_int(moves.size()).is_equal(2)
	assert_object(moves[0]).is_same(a)
	assert_object(moves[1]).is_same(b)

func test_an_enemy_without_moves_gets_a_melee_move_from_its_old_fields() -> void:
	var data := EnemyData.new()
	data.attack_damage = 9
	data.attack_range_tiles = 2.25
	data.telegraph_seconds = 0.45
	data.recovery_seconds = 0.7
	var moves := data.effective_moves()
	assert_int(moves.size()).is_equal(1)
	assert_int(moves[0].kind).is_equal(EnemyMove.Kind.MELEE)
	assert_float(moves[0].telegraph_seconds).is_equal(0.45)
	assert_float(moves[0].recovery_seconds).is_equal(0.7)
	assert_int(moves[0].damage).is_equal(9)
	assert_float(moves[0].reach_tiles).is_equal(2.25)
	assert_bool(moves[0].parryable).is_true()

func test_a_charger_without_moves_gets_a_dash_move() -> void:
	var data := EnemyData.new()
	data.behaviour = EnemyData.Behaviour.CHARGER
	data.move_speed_tiles = 2.0
	data.attack_damage = 20
	var moves := data.effective_moves()
	assert_int(moves.size()).is_equal(1)
	assert_int(moves[0].kind).is_equal(EnemyMove.Kind.DASH)
	assert_bool(moves[0].parryable).is_false()
	assert_float(moves[0].speed_tiles).is_equal(2.0 * Enemy.CHARGE_SPEED_MULTIPLIER)
	assert_float(moves[0].active_seconds).is_equal(Enemy.CHARGE_DURATION)
	assert_int(moves[0].damage).is_equal(20)

func test_only_melee_and_projectile_moves_may_be_parryable() -> void:
	for kind in [EnemyMove.Kind.SLAM, EnemyMove.Kind.DASH, EnemyMove.Kind.DIVE, EnemyMove.Kind.EXPLODE]:
		var m := _move(kind)
		m.parryable = true
		assert_bool(m.is_valid()).is_false()
		m.parryable = false
		assert_bool(m.is_valid()).is_true()
	for kind in [EnemyMove.Kind.MELEE, EnemyMove.Kind.PROJECTILE]:
		var m := _move(kind)
		m.parryable = true
		assert_bool(m.is_valid()).is_true()
