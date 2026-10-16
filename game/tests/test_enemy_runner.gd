extends GdUnitTestSuite
## The move runner: how an enemy plays EnemyMove attacks.

const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const RECORDER := preload("res://tests/support/strike_recorder.gd")

## Shots an enemy fires are added beside it, so tests must clear them out themselves.
func after_test() -> void:
	for child in get_children():
		if child is EnemyProjectile:
			child.queue_free()

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

# --- Projectile moves and keep-distance movement ---

func _shooter(behaviour: EnemyData.Behaviour = EnemyData.Behaviour.CHASER) -> EnemyData:
	var m := _move(EnemyMove.Kind.PROJECTILE, true)
	m.damage = 8
	m.speed_tiles = 6.0
	m.range_tiles = 14.0
	var d := _data([m] as Array[EnemyMove])
	d.behaviour = behaviour
	d.move_speed_tiles = 3.0
	d.preferred_range_tiles = 7.0
	d.attack_range_tiles = 14.0
	return d

func _shots_in(node: Node) -> Array[EnemyProjectile]:
	var found: Array[EnemyProjectile] = []
	for child in node.get_children():
		if child is EnemyProjectile:
			found.append(child)
	return found

func test_a_projectile_move_spawns_a_shot_that_flies_toward_the_hero() -> void:
	var enemy := _spawn(_shooter())
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(5.0, 0.0)
	enemy.begin_telegraph()
	await _frames(10)  # the 0.1 s wind-up is over: the shot is out
	var shots := _shots_in(self)
	assert_int(shots.size()).is_equal(1)
	assert_int(shots[0].damage).is_equal(8)
	var x_before := shots[0].global_position.x
	await _frames(10)
	assert_float(shots[0].global_position.x).is_greater(x_before + 5.0)

func test_a_shot_aimed_at_a_hero_on_the_left_flies_left() -> void:
	var enemy := _spawn(_shooter())
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(-5.0, 0.0)
	enemy.begin_telegraph()
	await _frames(10)
	var shots := _shots_in(self)
	var x_before := shots[0].global_position.x
	await _frames(10)
	assert_float(shots[0].global_position.x).is_less(x_before - 5.0)

func test_the_shot_carries_the_moves_range() -> void:
	var enemy := _spawn(_shooter())
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(5.0, 0.0)
	enemy.begin_telegraph()
	await _frames(10)
	var shot := _shots_in(self)[0]
	var start_x := shot.global_position.x
	var farthest := start_x
	for i in 400:
		await _frames(1)
		if not is_instance_valid(shot) or shot.is_queued_for_deletion():
			break
		farthest = shot.global_position.x
	assert_bool(not is_instance_valid(shot) or shot.is_queued_for_deletion()).is_true()
	assert_float(farthest - start_x).is_between(GameConfig.tiles(14.0) - 20.0, GameConfig.tiles(14.0) + 5.0)

func test_a_keep_distance_enemy_backs_off_when_the_hero_is_too_close() -> void:
	var enemy := _spawn(_shooter(EnemyData.Behaviour.KEEP_DISTANCE))
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(2.0, 0.0)
	var x_before := enemy.global_position.x
	await _frames(15)
	assert_float(enemy.global_position.x).is_less(x_before - 5.0)

func test_a_keep_distance_enemy_closes_in_when_the_hero_is_far() -> void:
	var enemy := _spawn(_shooter(EnemyData.Behaviour.KEEP_DISTANCE))
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(14.0, 0.0)
	var x_before := enemy.global_position.x
	await _frames(15)
	assert_float(enemy.global_position.x).is_greater(x_before + 5.0)

func test_a_keep_distance_enemy_holds_and_shoots_at_its_preferred_range() -> void:
	var enemy := _spawn(_shooter(EnemyData.Behaviour.KEEP_DISTANCE))
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(7.0, 0.0)
	await _frames(5)
	assert_bool(enemy.is_telegraphing()).is_true()

func test_a_cornered_keep_distance_enemy_shoots_instead_of_standing_idle() -> void:
	var wall: StaticBody2D = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16.0, 400.0)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(-16.0, 0.0)
	add_child(wall)
	var floor_body: StaticBody2D = auto_free(StaticBody2D.new())
	var floor_shape := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(800.0, 16.0)
	floor_shape.shape = floor_rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(300.0, 24.0)
	add_child(floor_body)
	var enemy := _spawn(_shooter(EnemyData.Behaviour.KEEP_DISTANCE))
	enemy.global_position = Vector2(8.0, 0.0)  # touching the wall on its left
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(2.0, 0.0)
	await _frames(40)
	assert_bool(enemy.is_telegraphing() or _shots_in(self).size() > 0).is_true()
