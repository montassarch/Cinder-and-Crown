extends GdUnitTestSuite

const DUMMY := preload("res://tests/support/hurtable_dummy.gd")
const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const SHIPPED := [
	"res://data/enemies/shambler.tres",
	"res://data/enemies/cinder_bat.tres",
	"res://data/enemies/crown_brute.tres",
]

func _fast_data(behaviour: EnemyData.Behaviour = EnemyData.Behaviour.CHASER) -> EnemyData:
	var d := EnemyData.new()
	d.display_name = "Test"
	d.max_health = 20
	d.move_speed_tiles = 3.0
	d.attack_damage = 7
	d.attack_range_tiles = 2.0
	d.telegraph_seconds = 0.05
	d.recovery_seconds = 0.05
	d.behaviour = behaviour
	d.body_size_tiles = Vector2(1.0, 1.0)
	return d

func _spawn(data: EnemyData) -> Enemy:
	var enemy: Enemy = auto_free(load(ENEMY_SCENE).instantiate())
	add_child(enemy)
	enemy.configure(data)
	return enemy

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _add_floor() -> void:
	var floor_body: StaticBody2D = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(80.0, 1.0)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = GameConfig.tiles_v(0.0, 6.0)
	add_child(floor_body)

func test_all_three_shipped_enemies_load_from_disk() -> void:
	for path in SHIPPED:
		assert_object(load(path)).is_instanceof(EnemyData)
		assert_str(load(path).display_name).is_not_empty()

func test_shipped_enemies_have_positive_health_and_nonzero_telegraph() -> void:
	# A telegraph of 0 is unreadable and unfair; assert every enemy telegraphs.
	for path in SHIPPED:
		var d: EnemyData = load(path)
		assert_int(d.max_health).is_greater(0)
		assert_float(d.telegraph_seconds).is_greater(0.0)

func test_three_behaviours_are_all_represented_by_shipped_data() -> void:
	var seen := []
	for path in SHIPPED:
		seen.append(load(path).behaviour)
	assert_array(seen).contains_exactly_in_any_order([
		EnemyData.Behaviour.CHASER, EnemyData.Behaviour.FLYER, EnemyData.Behaviour.CHARGER])

func test_configure_sets_health_from_data() -> void:
	var enemy := _spawn(_fast_data())
	assert_int(enemy.health().max_health).is_equal(20)
	assert_int(enemy.health().current).is_equal(20)

func test_configure_before_entering_the_tree_still_applies() -> void:
	var enemy: Enemy = auto_free(load(ENEMY_SCENE).instantiate())
	enemy.configure(_fast_data())
	add_child(enemy)
	assert_int(enemy.health().current).is_equal(20)

func test_telegraph_releases_attack_after_telegraph_seconds() -> void:
	var enemy := _spawn(_fast_data())
	var released := []
	enemy.attack_released.connect(func(damage: int) -> void: released.append(damage))
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_true()
	assert_array(released).is_empty()
	await await_millis(200)
	assert_array(released).is_equal([7])
	assert_bool(enemy.is_telegraphing()).is_false()

func test_death_during_telegraph_cancels_the_attack() -> void:
	# Review Focus 4: kill mid-wind-up -> attack_released never fires.
	var enemy := _spawn(_fast_data())
	var released := []
	enemy.attack_released.connect(func(damage: int) -> void: released.append(damage))
	enemy.begin_telegraph()
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	await await_millis(200)
	assert_array(released).is_empty()
	assert_bool(enemy.is_telegraphing()).is_false()

func test_dead_enemy_cannot_begin_a_new_telegraph() -> void:
	var enemy := _spawn(_fast_data())
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_false()

func test_death_emits_died_once() -> void:
	var enemy := _spawn(_fast_data())
	var deaths := [0]
	enemy.died.connect(func() -> void: deaths[0] += 1)
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	assert_int(deaths[0]).is_equal(1)

func test_take_hit_reduces_health() -> void:
	var enemy := _spawn(_fast_data())
	enemy.take_hit(5, enemy.global_position.x - 10.0)
	assert_int(enemy.health().current).is_equal(15)

func _enemy_with_target_at(offset_tiles: float) -> Array:
	var data := _fast_data()
	data.recovery_seconds = 5.0  # one swing only; the AI must not re-attack mid-test
	var enemy := _spawn(data)
	var foe: Node2D = auto_free(DUMMY.new())
	add_child(foe)
	foe.global_position = enemy.global_position + GameConfig.tiles_v(offset_tiles, 0.0)
	enemy.target = foe
	return [enemy, foe]

func test_release_hits_a_target_in_range() -> void:
	var pair := _enemy_with_target_at(1.0)
	pair[0].begin_telegraph()
	await await_millis(200)
	assert_int(pair[1].hits.size()).is_equal(1)
	assert_int(pair[1].hits[0][0]).is_equal(7)

func test_a_target_that_steps_out_of_range_during_the_telegraph_takes_nothing() -> void:
	var pair := _enemy_with_target_at(1.0)
	pair[0].begin_telegraph()
	pair[1].global_position = pair[0].global_position + GameConfig.tiles_v(10.0, 0.0)
	await await_millis(200)
	assert_int(pair[1].hits.size()).is_equal(0)

func test_chaser_walks_toward_its_target() -> void:
	_add_floor()
	var enemy := _spawn(_fast_data())
	enemy.global_position = GameConfig.tiles_v(0.0, 5.0)
	var target: Node2D = auto_free(DUMMY.new())
	add_child(target)
	target.global_position = GameConfig.tiles_v(12.0, 5.0)
	enemy.target = target
	await _frames(40)
	assert_float(enemy.global_position.x).is_greater(GameConfig.tiles(1.0))

func test_flyer_does_not_fall() -> void:
	var enemy := _spawn(_fast_data(EnemyData.Behaviour.FLYER))
	enemy.global_position = GameConfig.tiles_v(0.0, 0.0)
	await _frames(40)
	assert_float(enemy.global_position.y).is_less(GameConfig.tiles(2.0))

func test_charger_winds_up_when_target_is_in_trigger_range() -> void:
	_add_floor()
	var data := _fast_data(EnemyData.Behaviour.CHARGER)
	data.attack_range_tiles = 6.0
	data.telegraph_seconds = 0.5
	var enemy := _spawn(data)
	enemy.global_position = GameConfig.tiles_v(0.0, 5.0)
	var target: Node2D = auto_free(DUMMY.new())
	add_child(target)
	target.global_position = GameConfig.tiles_v(4.0, 5.0)
	enemy.target = target
	await _frames(10)
	assert_bool(enemy.is_telegraphing()).is_true()

func test_flyer_holds_still_while_telegraphing() -> void:
	# A wind-up that drifts toward the player is not a readable telegraph.
	var data := _fast_data(EnemyData.Behaviour.FLYER)
	data.telegraph_seconds = 1.0
	data.recovery_seconds = 5.0
	var enemy := _spawn(data)
	enemy.global_position = GameConfig.tiles_v(0.0, 0.0)
	var target: Node2D = auto_free(DUMMY.new())
	add_child(target)
	target.global_position = GameConfig.tiles_v(0.0, 8.0)
	enemy.target = target
	await _frames(10)
	assert_float(enemy.velocity.y).is_greater(0.0)  # it really was flying toward the target
	enemy.begin_telegraph()
	await _frames(3)
	var held_at := enemy.global_position
	await _frames(10)
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	assert_vector(enemy.global_position).is_equal_approx(held_at, Vector2(0.01, 0.01))

func test_flyer_holds_still_while_recovering() -> void:
	var data := _fast_data(EnemyData.Behaviour.FLYER)
	data.recovery_seconds = 5.0
	var enemy := _spawn(data)
	enemy.global_position = GameConfig.tiles_v(0.0, 0.0)
	var target: Node2D = auto_free(DUMMY.new())
	add_child(target)
	target.global_position = GameConfig.tiles_v(0.0, 8.0)
	enemy.target = target
	await _frames(10)
	enemy.begin_telegraph()
	await await_millis(250)  # telegraph (0.05s) has released; now recovering
	var held_at := enemy.global_position
	await _frames(10)
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	assert_vector(enemy.global_position).is_equal_approx(held_at, Vector2(0.01, 0.01))

func test_stun_cancels_a_telegraphed_attack() -> void:
	var data := _fast_data()
	data.telegraph_seconds = 0.1
	data.recovery_seconds = 5.0
	var enemy := _spawn(data)
	var released := []
	enemy.attack_released.connect(func(damage: int) -> void: released.append(damage))
	enemy.begin_telegraph()
	enemy.stun(0.5)
	assert_bool(enemy.is_stunned()).is_true()
	assert_bool(enemy.is_telegraphing()).is_false()
	await await_millis(250)
	assert_array(released).is_empty()

func test_a_stunned_enemy_recovers_and_can_fight_again() -> void:
	var enemy := _spawn(_fast_data())
	enemy.stun(0.1)
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_false()
	await await_millis(250)
	assert_bool(enemy.is_stunned()).is_false()
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_true()

func test_a_dead_enemy_cannot_be_stunned() -> void:
	var enemy := _spawn(_fast_data())
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	enemy.stun(1.0)
	assert_bool(enemy.is_stunned()).is_false()

# --- Parry ---

func test_a_parried_enemy_is_staggered_and_its_wind_up_cancelled() -> void:
	var enemy := _spawn(_fast_data())
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_true()
	enemy.on_parried(false, enemy.global_position.x - 20.0)
	assert_bool(enemy.is_stunned()).is_true()
	assert_bool(enemy.is_telegraphing()).is_false()

func test_a_perfect_parry_staggers_longer() -> void:
	var plain := _spawn(_fast_data())
	var perfect := _spawn(_fast_data())
	plain.on_parried(false, -10.0)
	perfect.on_parried(true, -10.0)
	assert_float(Enemy.PERFECT_PARRY_STAGGER).is_greater(Enemy.PARRY_STAGGER)
	await get_tree().create_timer(Enemy.PARRY_STAGGER + 0.15).timeout
	assert_bool(plain.is_stunned()).is_false()
	assert_bool(perfect.is_stunned()).is_true()

func test_a_parried_enemy_is_knocked_back_away_from_the_parry() -> void:
	_add_floor()
	var enemy := _spawn(_fast_data())
	enemy.global_position = GameConfig.tiles_v(5.0, 5.0)
	await _frames(5)
	var before := enemy.global_position.x
	enemy.on_parried(false, enemy.global_position.x - 20.0)
	await _frames(10)
	assert_float(enemy.global_position.x).is_greater(before + 1.0)

func test_an_enemy_names_itself_as_the_attacker_when_it_strikes() -> void:
	var enemy := _spawn(_fast_data())
	var victim: Node2D = auto_free(load("res://tests/support/strike_recorder.gd").new())
	add_child(victim)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(1.0, 0.0)
	enemy.target = victim
	enemy.begin_telegraph()
	await _frames(15)
	assert_int(victim.strikes.size()).is_greater_equal(1)
	assert_object(victim.strikes[0][2]).is_same(enemy)

func test_a_strike_that_gets_parried_does_not_fall_through_into_recovery() -> void:
	var enemy := _spawn(_fast_data())
	var victim: Node2D = auto_free(load("res://tests/support/strike_recorder.gd").new())
	victim.parry_it = true
	add_child(victim)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(1.0, 0.0)
	enemy.target = victim
	enemy.begin_telegraph()
	await _frames(12)
	assert_bool(enemy.is_stunned()).is_true()
