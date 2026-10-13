class_name EnemyDataTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# Same data-driven contract as weapons: a fourth enemy must be a new .tres
# file and no code change. behaviour selects a movement strategy from an
# enum, so adding a type means authoring data, not extending a match.

const SHAMBLER := "res://data/enemies/shambler.tres"
const CINDER_BAT := "res://data/enemies/cinder_bat.tres"
const CROWN_BRUTE := "res://data/enemies/crown_brute.tres"
const ALL := [SHAMBLER, CINDER_BAT, CROWN_BRUTE]


func _spawn(data: EnemyData) -> Enemy:
	var enemy: Enemy = auto_free(
		(load("res://src/enemies/enemy.tscn") as PackedScene).instantiate()
	)
	add_child(enemy)
	enemy.configure(data)
	return enemy


func _make_data(telegraph: float, damage: int = 10, health: int = 30) -> EnemyData:
	var data := EnemyData.new()
	data.display_name = "Test Enemy"
	data.max_health = health
	data.telegraph_seconds = telegraph
	data.attack_damage = damage
	return data


# --- shipped data ---

func test_all_three_shipped_enemies_load_from_disk() -> void:
	for path: String in ALL:
		assert_object(load(path)).override_failure_message(
			"%s did not load as EnemyData" % path
		).is_instanceof(EnemyData)


func test_shipped_enemies_have_positive_health_and_nonzero_telegraph() -> void:
	# A telegraph of 0 is an unreadable, unfair hit. Every enemy must give
	# the player something to react to.
	for path: String in ALL:
		var data: EnemyData = load(path)
		assert_int(data.max_health).override_failure_message(
			"%s has non-positive health" % path
		).is_greater(0)
		assert_float(data.telegraph_seconds).override_failure_message(
			"%s attacks with no telegraph" % path
		).is_greater(0.0)


func test_three_behaviours_are_all_represented_by_shipped_data() -> void:
	var seen := {}
	for path: String in ALL:
		seen[(load(path) as EnemyData).behaviour] = true
	assert_int(seen.size()).is_equal(3)


func test_shipped_enemies_are_named_distinctly() -> void:
	var names := {}
	for path: String in ALL:
		names[(load(path) as EnemyData).display_name] = true
	assert_int(names.size()).is_equal(3)


func test_the_heavy_enemy_telegraphs_longest() -> void:
	# A slow, high-damage enemy that struck as fast as a weak one would be
	# unreadable. Damage and telegraph should correlate.
	var brute: EnemyData = load(CROWN_BRUTE)
	var bat: EnemyData = load(CINDER_BAT)
	assert_bool(brute.attack_damage > bat.attack_damage).is_true()
	assert_bool(brute.telegraph_seconds > bat.telegraph_seconds).is_true()


# --- configure ---

func test_configure_sets_health_from_data() -> void:
	var enemy := _spawn(_make_data(0.5, 10, 42))
	assert_int(enemy.health.max_health).is_equal(42)
	assert_int(enemy.health.current).is_equal(42)


func test_configure_sets_the_display_name() -> void:
	var enemy := _spawn(_make_data(0.5))
	assert_str(enemy.data.display_name).is_equal("Test Enemy")


# --- telegraph ---

func test_begin_telegraph_sets_telegraphing() -> void:
	var enemy := _spawn(_make_data(0.5))
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_true()


func test_telegraph_releases_attack_after_telegraph_seconds() -> void:
	var enemy := _spawn(_make_data(0.5, 13))
	var released := [0, 0]
	enemy.attack_released.connect(
		func(damage: int) -> void:
			released[0] += 1
			released[1] = damage
	)
	enemy.begin_telegraph()
	enemy.advance(0.6)
	assert_int(released[0]).is_equal(1)
	assert_int(released[1]).is_equal(13)
	assert_bool(enemy.is_telegraphing()).is_false()


func test_telegraph_does_not_release_early() -> void:
	var enemy := _spawn(_make_data(0.5))
	var released := [0]
	enemy.attack_released.connect(func(_d: int) -> void: released[0] += 1)
	enemy.begin_telegraph()
	enemy.advance(0.3)
	assert_int(released[0]).is_equal(0)
	assert_bool(enemy.is_telegraphing()).is_true()


func test_begin_telegraph_while_already_telegraphing_does_not_restart() -> void:
	# Restarting would let an enemy wind up forever without ever striking.
	var enemy := _spawn(_make_data(0.5))
	enemy.begin_telegraph()
	enemy.advance(0.4)
	enemy.begin_telegraph()
	enemy.advance(0.2)
	assert_bool(enemy.is_telegraphing()).is_false()


# --- Review Focus 4 ---

func test_death_during_telegraph_cancels_the_attack() -> void:
	# Review Focus 4. Killing an enemy mid-wind-up must cancel the strike.
	# A corpse that still lands its hit reads as the game cheating.
	var enemy := _spawn(_make_data(0.5, 10, 30))
	var released := [0]
	enemy.attack_released.connect(func(_d: int) -> void: released[0] += 1)
	enemy.begin_telegraph()
	enemy.advance(0.2)
	enemy.health.take_damage(30)
	enemy.advance(0.6)
	assert_int(released[0]).is_equal(0)
	assert_bool(enemy.is_telegraphing()).is_false()


func test_dead_enemy_cannot_begin_a_new_telegraph() -> void:
	var enemy := _spawn(_make_data(0.5, 10, 30))
	enemy.health.take_damage(30)
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_false()


func test_death_emits_died() -> void:
	var enemy := _spawn(_make_data(0.5, 10, 30))
	var deaths := [0]
	enemy.died.connect(func() -> void: deaths[0] += 1)
	enemy.health.take_damage(30)
	assert_int(deaths[0]).is_equal(1)


func test_enemy_is_sized_in_tiles_from_data() -> void:
	var data := _make_data(0.5)
	data.body_size_tiles = Vector2(2.0, 3.0)
	var enemy := _spawn(data)
	var expected := GameConfig.tiles_v(2.0, 3.0)
	var shape := enemy.get_node("%EnemyShape") as CollisionShape2D
	assert_vector((shape.shape as RectangleShape2D).size).is_equal(expected)


# --- regressions from the final review ---

func test_enemy_waits_out_recovery_before_winding_up_again() -> void:
	# Final review I5. recovery_seconds was authored in all three enemies
	# and read nowhere, so an enemy in contact re-telegraphed the frame
	# after striking. A Crown Brute was an unbroken 22-damage-per-second
	# machine with no punish window -- and the recovery pause is precisely
	# the window the player is meant to counter into.
	var data := _make_data(0.3)
	data.recovery_seconds = 0.5
	var enemy := _spawn(data)

	enemy.begin_telegraph()
	enemy.advance(0.31)
	assert_bool(enemy.is_telegraphing()).is_false()

	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).override_failure_message(
		"enemy re-telegraphed inside its recovery window"
	).is_false()

	enemy.advance(0.51)
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_true()


func test_recovery_is_reported_while_it_runs() -> void:
	var data := _make_data(0.3)
	data.recovery_seconds = 0.5
	var enemy := _spawn(data)
	enemy.begin_telegraph()
	enemy.advance(0.31)
	assert_bool(enemy.is_recovering()).is_true()
	enemy.advance(0.51)
	assert_bool(enemy.is_recovering()).is_false()


func test_charger_commits_to_a_rush_when_it_strikes() -> void:
	# Final review I7. CHARGER and CHASER took the identical code path, so
	# the enum promised three strategies and delivered two. The old test
	# asserted three distinct integers appeared in three data files, which
	# still passed with no implementation at all.
	var data := _make_data(0.3)
	data.behaviour = EnemyData.Behaviour.CHARGER
	data.move_speed_tiles = 2.0
	var enemy := _spawn(data)
	var target: Node2D = auto_free(Node2D.new())
	add_child(target)
	target.global_position = enemy.global_position + Vector2(GameConfig.tiles(8.0), 0.0)
	enemy.target = target

	enemy.begin_telegraph()
	enemy.advance(0.31)
	enemy.decide(0.016)

	assert_bool(enemy.is_rushing()).is_true()
	assert_float(absf(enemy.velocity.x)).override_failure_message(
		"a charger's rush is no faster than its walk"
	).is_greater(GameConfig.tiles(data.move_speed_tiles))


func test_chaser_does_not_rush() -> void:
	var data := _make_data(0.3)
	data.behaviour = EnemyData.Behaviour.CHASER
	var enemy := _spawn(data)
	enemy.begin_telegraph()
	enemy.advance(0.31)
	assert_bool(enemy.is_rushing()).is_false()


func test_rush_ends_after_its_duration() -> void:
	var data := _make_data(0.3)
	data.behaviour = EnemyData.Behaviour.CHARGER
	var enemy := _spawn(data)
	enemy.begin_telegraph()
	enemy.advance(0.31)
	assert_bool(enemy.is_rushing()).is_true()
	enemy.advance(Enemy.RUSH_SECONDS + 0.01)
	assert_bool(enemy.is_rushing()).is_false()
