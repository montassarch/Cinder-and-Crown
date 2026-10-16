extends GdUnitTestSuite
## The move runner: how an enemy plays EnemyMove attacks.

const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const RECORDER := preload("res://tests/support/strike_recorder.gd")

func _move(kind: EnemyMove.Kind = EnemyMove.Kind.MELEE, parryable: bool = true) -> EnemyMove:
	var m := EnemyMove.new()
	m.id = "test"
	m.kind = kind
	m.telegraph_seconds = 0.1
	m.active_seconds = 0.1
	m.recovery_seconds = 0.1
	m.damage = 7
	m.reach_tiles = 2.0
	m.speed_tiles = 6.0
	m.range_tiles = 8.0
	m.parryable = parryable
	return m

func _data(moves: Array[EnemyMove] = []) -> EnemyData:
	var d := EnemyData.new()
	d.display_name = "Test"
	d.max_health = 100
	d.move_speed_tiles = 0.0
	d.attack_range_tiles = 2.0
	d.moves = moves
	d.body_size_tiles = Vector2(1.0, 1.0)
	return d

func _spawn(data: EnemyData) -> Enemy:
	var enemy: Enemy = auto_free(load(ENEMY_SCENE).instantiate())
	add_child(enemy)
	enemy.configure(data)
	return enemy

func _victim_beside(enemy: Enemy) -> Node2D:
	var victim: Node2D = auto_free(RECORDER.new())
	add_child(victim)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(1.0, 0.0)
	enemy.target = victim
	return victim

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func test_the_current_move_is_set_while_winding_up_and_cleared_after_recovery() -> void:
	var enemy := _spawn(_data([_move()] as Array[EnemyMove]))
	assert_object(enemy.current_move()).is_null()
	enemy.begin_telegraph()
	assert_object(enemy.current_move()).is_not_null()
	assert_int(enemy.current_move().kind).is_equal(EnemyMove.Kind.MELEE)
	assert_int(enemy.move_index()).is_equal(0)
	await _frames(40)
	assert_object(enemy.current_move()).is_null()

func test_an_enemy_without_moves_plays_its_implicit_move() -> void:
	var enemy := _spawn(_data())
	enemy.begin_telegraph()
	assert_str(enemy.current_move().id).is_equal("implicit")

func test_a_parryable_move_hits_through_take_strike() -> void:
	var enemy := _spawn(_data([_move(EnemyMove.Kind.MELEE, true)] as Array[EnemyMove]))
	var victim := _victim_beside(enemy)
	enemy.begin_telegraph()
	await _frames(20)
	assert_int(victim.strikes.size()).is_equal(1)
	assert_int(victim.strikes[0][0]).is_equal(7)
	assert_int(victim.hits.size()).is_equal(0)

func test_a_non_parryable_move_hits_through_take_hit_not_take_strike() -> void:
	var enemy := _spawn(_data([_move(EnemyMove.Kind.MELEE, false)] as Array[EnemyMove]))
	var victim := _victim_beside(enemy)
	enemy.begin_telegraph()
	await _frames(20)
	assert_int(victim.hits.size()).is_equal(1)
	assert_int(victim.hits[0][0]).is_equal(7)
	assert_int(victim.strikes.size()).is_equal(0)

func test_a_dash_move_rushes_and_hits_on_contact_without_being_parryable() -> void:
	var dash := _move(EnemyMove.Kind.DASH, false)
	dash.reach_tiles = 1.2
	dash.speed_tiles = 20.0
	dash.active_seconds = 0.2  # 4 tiles of rush: enough to reach a hero 3 tiles away
	var data := _data([dash] as Array[EnemyMove])
	data.behaviour = EnemyData.Behaviour.FLYER  # no gravity, so the test needs no floor
	var enemy := _spawn(data)
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(3.0, 0.0)
	enemy.begin_telegraph()
	await _frames(22)  # one rush: hit lands around frame 12, the next attack cannot start before frame 30
	assert_int(victim.hits.size()).is_equal(1)
	assert_int(victim.strikes.size()).is_equal(0)

# --- Strings, patterns, cooldown, interruption ---

func _melee(damage: int) -> EnemyMove:
	var m := _move(EnemyMove.Kind.MELEE, true)
	m.damage = damage
	return m

func _string_data(damages: Array, pattern: EnemyData.Pattern = EnemyData.Pattern.SEQUENCE, cooldown: float = 5.0) -> EnemyData:
	var moves: Array[EnemyMove] = []
	for damage in damages:
		moves.append(_melee(damage))
	var d := _data(moves)
	d.behaviour = EnemyData.Behaviour.FLYER  # no gravity: the long rests need no floor
	d.pattern = pattern
	d.chain_gap_seconds = 0.1
	d.cooldown_seconds = cooldown
	return d

## An enemy with a hero beside it, recording every attack_released damage.
func _watched(data: EnemyData) -> Array:
	var enemy := _spawn(data)
	var victim := _victim_beside(enemy)
	var released: Array = []
	enemy.attack_released.connect(func(damage: int) -> void: released.append(damage))
	return [enemy, victim, released]

func test_a_string_plays_its_moves_in_order() -> void:
	var w := _watched(_string_data([6, 6, 14]))
	w[0].begin_telegraph()
	await _frames(70)
	assert_array(w[2]).is_equal([6, 6, 14])

func test_the_string_waits_out_its_cooldown_before_starting_again() -> void:
	var w := _watched(_string_data([4, 5], EnemyData.Pattern.SEQUENCE, 0.8))
	w[0].begin_telegraph()
	await _frames(55)  # the two moves are over (about 0.5 s), the 0.8 s rest is not
	assert_array(w[2]).is_equal([4, 5])
	await _frames(70)  # now well past the rest: the string starts over
	assert_int(w[2].size()).is_greater(2)

func test_a_parry_on_the_first_move_cancels_the_rest() -> void:
	var w := _watched(_string_data([6, 6, 14]))
	w[1].parry_it = true
	w[0].begin_telegraph()
	await _frames(40)
	assert_int(w[1].strikes.size()).is_equal(1)
	assert_array(w[2]).is_equal([6])
	assert_bool(w[0].is_stunned()).is_true()
	assert_int(w[0].move_index()).is_equal(0)

func test_a_stun_between_moves_ends_the_string() -> void:
	var w := _watched(_string_data([6, 6, 14]))
	w[0].begin_telegraph()
	await _frames(12)  # the first move has struck; the second has not begun
	assert_array(w[2]).is_equal([6])
	w[0].stun(1.5)
	await _frames(40)
	assert_array(w[2]).is_equal([6])

func test_a_death_between_moves_starts_no_further_move() -> void:
	var w := _watched(_string_data([6, 6, 14]))
	w[0].begin_telegraph()
	await _frames(12)
	w[0].take_hit(9999, w[0].global_position.x - 10.0)
	await _frames(70)
	assert_array(w[2]).is_equal([6])

func test_a_guard_break_ends_the_string() -> void:
	var data := _string_data([6, 6, 14])
	data.poise = 1
	var w := _watched(data)
	w[0].begin_telegraph()
	await _frames(12)
	w[0].take_hit(1, w[0].global_position.x - 10.0)
	assert_bool(w[0].is_guard_broken()).is_true()
	await _frames(40)
	assert_array(w[2]).is_equal([6])

func test_a_random_pattern_only_picks_listed_moves_one_per_attack() -> void:
	var enemy := _spawn(_string_data([1, 2, 3], EnemyData.Pattern.RANDOM, 0.0))
	var released: Array = []
	enemy.attack_released.connect(func(damage: int) -> void: released.append(damage))
	enemy.rng.seed = 5
	for i in 12:
		enemy.begin_telegraph()
		await _frames(25)
	assert_int(released.size()).is_equal(12)
	for damage in released:
		assert_bool(damage in [1, 2, 3]).is_true()
	assert_int(released.filter(func(d: int) -> bool: return d == 1).size()).is_less(12)
	assert_int(released.filter(func(d: int) -> bool: return d == 3).size()).is_greater(0)
