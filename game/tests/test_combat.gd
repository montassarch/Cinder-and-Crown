class_name CombatTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# Tasks 4-6 built the player, weapons and enemies as separate components
# whose tests never made them touch. These tests close that loop: a swing
# must actually reduce an enemy's health, and an enemy's released attack
# must actually hurt the player. Without them the sandbox could look
# correct while nothing connected.

const SM := preload("res://src/player/player_state_machine.gd")


func _spawn_player() -> Player:
	var player: Player = auto_free(
		(load("res://src/player/player.tscn") as PackedScene).instantiate()
	)
	add_child(player)
	return player


func _spawn_enemy(path: String) -> Enemy:
	var enemy: Enemy = auto_free(
		(load("res://src/enemies/enemy.tscn") as PackedScene).instantiate()
	)
	add_child(enemy)
	enemy.configure(load(path))
	return enemy


# --- player hits enemy ---

func test_weapon_hit_reduces_enemy_health() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/shambler.tres")
	var before := enemy.health.current

	player.weapon.start_attack()
	player.weapon.advance(player.active_weapon_data().hit_window.x + 0.01)
	assert_bool(player.weapon.try_hit(enemy)).is_true()

	assert_int(enemy.health.current).is_less(before)


func test_weapon_hit_deals_the_weapons_damage() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/crown_brute.tres")
	var expected: int = player.active_weapon_data().damage
	var before := enemy.health.current

	player.weapon.start_attack()
	player.weapon.advance(player.active_weapon_data().hit_window.x + 0.01)
	player.weapon.try_hit(enemy)

	assert_int(before - enemy.health.current).is_equal(expected)


func test_swapped_weapon_deals_its_own_damage() -> void:
	# Proves damage is read from the equipped data rather than a constant.
	var player := _spawn_player()
	player.swap_weapon()
	var enemy := _spawn_enemy("res://data/enemies/crown_brute.tres")
	var expected: int = player.active_weapon_data().damage
	var before := enemy.health.current

	player.weapon.start_attack()
	player.weapon.advance(player.active_weapon_data().hit_window.x + 0.01)
	player.weapon.try_hit(enemy)

	assert_int(before - enemy.health.current).is_equal(expected)


func test_killing_an_enemy_emits_died() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/cinder_bat.tres")
	var deaths := [0]
	enemy.died.connect(func() -> void: deaths[0] += 1)

	# Enough swings to kill the weakest enemy outright.
	for _i: int in range(10):
		player.weapon.cancel_attack()
		player.weapon.start_attack()
		player.weapon.advance(player.active_weapon_data().hit_window.x + 0.01)
		player.weapon.try_hit(enemy)

	assert_bool(enemy.health.is_alive()).is_false()
	assert_int(deaths[0]).is_equal(1)


func test_hitting_a_dead_enemy_does_nothing() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/cinder_bat.tres")
	enemy.health.take_damage(enemy.health.max_health)

	player.weapon.start_attack()
	player.weapon.advance(player.active_weapon_data().hit_window.x + 0.01)
	player.weapon.try_hit(enemy)

	assert_int(enemy.health.current).is_equal(0)


# --- enemy hits player ---

func test_released_attack_hurts_the_player() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/shambler.tres")
	enemy.target = player
	enemy.global_position = player.global_position

	enemy.begin_telegraph()
	enemy.advance(enemy.data.telegraph_seconds + 0.01)

	assert_int(player.health.current).is_equal(
		Player.MAX_HEALTH - enemy.data.attack_damage
	)


func test_released_attack_misses_a_player_out_of_range() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/shambler.tres")
	enemy.target = player
	enemy.global_position = player.global_position + Vector2(
		GameConfig.tiles(20.0), 0.0
	)

	enemy.begin_telegraph()
	enemy.advance(enemy.data.telegraph_seconds + 0.01)

	assert_int(player.health.current).is_equal(Player.MAX_HEALTH)


func test_rolling_player_is_untouched_by_a_released_attack() -> void:
	# The i-frame window, end to end: the roll has to actually save you.
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/crown_brute.tres")
	enemy.target = player
	enemy.global_position = player.global_position

	player.state = SM.State.ROLL
	player._state_time = 0.15
	assert_bool(player.is_invincible()).is_true()

	enemy.begin_telegraph()
	enemy.advance(enemy.data.telegraph_seconds + 0.01)

	assert_int(player.health.current).is_equal(Player.MAX_HEALTH)


# --- enemy movement ---

func test_enemy_moves_toward_a_distant_target() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/shambler.tres")
	enemy.target = player
	enemy.global_position = player.global_position - Vector2(
		GameConfig.tiles(8.0), 0.0
	)

	enemy.decide(0.016)
	assert_float(enemy.velocity.x).is_greater(0.0)


func test_enemy_holds_still_while_telegraphing() -> void:
	# A wind-up the player cannot read is unfair. Stopping is most of what
	# makes the telegraph legible.
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/shambler.tres")
	enemy.target = player
	enemy.global_position = player.global_position

	enemy.decide(0.016)
	assert_bool(enemy.is_telegraphing()).is_true()
	assert_float(enemy.velocity.x).is_equal(0.0)


func test_enemy_with_no_target_does_not_move_horizontally() -> void:
	var enemy := _spawn_enemy("res://data/enemies/shambler.tres")
	enemy.decide(0.016)
	assert_float(enemy.velocity.x).is_equal(0.0)


func test_flyer_ignores_gravity() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/cinder_bat.tres")
	enemy.target = player
	enemy.global_position = player.global_position - Vector2(
		0.0, GameConfig.tiles(6.0)
	)

	enemy.decide(0.016)
	# A flyer closing vertically on a target below it moves down because it
	# chose to, not because it fell: no gravity accumulates.
	assert_bool(enemy.velocity.y > 0.0).is_true()
	var first := enemy.velocity.y
	enemy.decide(0.016)
	assert_float(enemy.velocity.y).is_equal(first)


func test_dead_enemy_stops_moving() -> void:
	var player := _spawn_player()
	var enemy := _spawn_enemy("res://data/enemies/shambler.tres")
	enemy.target = player
	enemy.global_position = player.global_position - Vector2(
		GameConfig.tiles(8.0), 0.0
	)
	enemy.health.take_damage(enemy.health.max_health)

	enemy.decide(0.016)
	assert_float(enemy.velocity.x).is_equal(0.0)
