class_name PlayerTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# Player's physics and feel are judged by playing the sandbox, not here.
# What IS pinned here are the two rules that are exactly specified: where
# the roll's invincibility window opens and closes, and that the jump
# impulse stays derived from the height and gravity constants rather than
# drifting into a hand-tuned number that no longer matches them.

const SM := preload("res://src/player/player_state_machine.gd")


# --- invincibility window ---

func test_not_invincible_outside_the_roll() -> void:
	for state: int in [
		SM.State.IDLE, SM.State.RUN, SM.State.JUMP,
		SM.State.FALL, SM.State.ATTACK, SM.State.HURT,
	]:
		assert_bool(Player.is_invincible_at(state, 0.1)).is_false()


func test_not_invincible_at_the_very_start_of_the_roll() -> void:
	# The exposed first frames are what stop the roll being a free escape.
	assert_bool(Player.is_invincible_at(SM.State.ROLL, 0.0)).is_false()
	assert_bool(Player.is_invincible_at(SM.State.ROLL, 0.02)).is_false()


func test_invincible_inside_the_window() -> void:
	assert_bool(Player.is_invincible_at(SM.State.ROLL, Player.IFRAME_WINDOW.x)).is_true()
	assert_bool(Player.is_invincible_at(SM.State.ROLL, 0.15)).is_true()
	assert_bool(Player.is_invincible_at(SM.State.ROLL, Player.IFRAME_WINDOW.y)).is_true()


func test_not_invincible_in_the_roll_recovery_tail() -> void:
	# Between the window closing and the roll ending the player is exposed
	# again, so spamming roll is punishable.
	assert_bool(Player.is_invincible_at(SM.State.ROLL, 0.28)).is_false()
	assert_bool(Player.is_invincible_at(SM.State.ROLL, Player.ROLL_DURATION)).is_false()


func test_iframe_window_falls_inside_the_roll_duration() -> void:
	# Guards against a later tuning pass setting a window that outlives the
	# move, which would make the roll fully invincible by accident.
	assert_float(Player.IFRAME_WINDOW.x).is_greater(0.0)
	assert_float(Player.IFRAME_WINDOW.y).is_less(Player.ROLL_DURATION)
	assert_float(Player.IFRAME_WINDOW.x).is_less(Player.IFRAME_WINDOW.y)


# --- derived jump impulse ---

func test_jump_velocity_is_upward() -> void:
	# Godot's Y axis points down, so a jump is negative.
	assert_float(Player.jump_velocity()).is_less(0.0)


func test_jump_velocity_reaches_the_configured_height() -> void:
	# v^2 = 2*g*h, so the apex height implied by the impulse must equal
	# JUMP_HEIGHT_TILES. If someone replaces the derivation with a magic
	# number, this fails.
	var v := absf(Player.jump_velocity())
	var gravity := GameConfig.tiles(Player.GRAVITY_TILES)
	var apex_pixels := (v * v) / (2.0 * gravity)
	assert_float(apex_pixels).is_equal_approx(
		GameConfig.tiles(Player.JUMP_HEIGHT_TILES), 0.01
	)


# --- resolution rule ---

func test_speeds_are_expressed_in_tiles_not_pixels() -> void:
	# The project's hard rule: gameplay constants are tile-space. A run
	# speed of 9 tiles/s is 144 px/s at TILE_SIZE 16 -- and becomes
	# something else, correctly, if TILE_SIZE changes.
	assert_float(GameConfig.tiles(Player.RUN_SPEED_TILES)).is_equal(144.0)
	assert_float(GameConfig.tiles(Player.ROLL_SPEED_TILES)).is_equal(224.0)


# --- weapon slots ---

func _spawn_player() -> Player:
	var player: Player = auto_free(
		(load("res://src/player/player.tscn") as PackedScene).instantiate()
	)
	add_child(player)
	return player


func test_player_starts_with_both_slots_filled() -> void:
	var player := _spawn_player()
	assert_object(player.slots[0]).is_not_null()
	assert_object(player.slots[1]).is_not_null()
	assert_int(player.active_slot).is_equal(0)


func test_swap_weapon_alternates_between_the_two_slots() -> void:
	var player := _spawn_player()
	var first := player.active_weapon_data()
	player.swap_weapon()
	assert_object(player.active_weapon_data()).is_not_same(first)
	player.swap_weapon()
	assert_object(player.active_weapon_data()).is_same(first)


func test_attack_duration_comes_from_the_equipped_weapon() -> void:
	# The carried note from Task 4: a slow spear must not swing at a fast
	# blade's rate. If this reads ATTACK_DURATION, the weapon data is
	# being ignored.
	var player := _spawn_player()
	var blade_duration: float = player.active_weapon_data().attack_duration
	player.swap_weapon()
	var spear_duration: float = player.active_weapon_data().attack_duration
	assert_float(spear_duration).is_not_equal(blade_duration)
	assert_float(player._duration_of(SM.State.ATTACK)).is_equal(spear_duration)


func test_swapping_equips_the_weapon_on_the_weapon_node() -> void:
	var player := _spawn_player()
	player.swap_weapon()
	assert_object(player.weapon.data).is_same(player.slots[1])


func test_equipping_an_inactive_slot_does_not_change_the_live_weapon() -> void:
	var player := _spawn_player()
	var live := player.weapon.data
	var other := WeaponData.new()
	player.equip_slot(1, other)
	assert_object(player.weapon.data).is_same(live)
	assert_object(player.slots[1]).is_same(other)


# --- scene wiring ---

func test_player_scene_instantiates_and_readies() -> void:
	# Catches what a parse check cannot: a % unique-name that does not
	# resolve, a missing child, a Health node that never attached. _ready
	# only runs once the node is in a tree.
	var player: Player = auto_free(
		(load("res://src/player/player.tscn") as PackedScene).instantiate()
	)
	add_child(player)
	assert_object(player.health).is_not_null()
	assert_int(player.health.max_health).is_equal(Player.MAX_HEALTH)
	assert_int(player.health.current).is_equal(Player.MAX_HEALTH)


func test_player_body_and_hurtbox_are_sized_from_tiles() -> void:
	var player: Player = auto_free(
		(load("res://src/player/player.tscn") as PackedScene).instantiate()
	)
	add_child(player)
	var expected := GameConfig.tiles_v(
		Player.BODY_SIZE_TILES.x, Player.BODY_SIZE_TILES.y
	)
	var body := player.get_node("%CollisionShape2D") as CollisionShape2D
	var hurt := player.get_node("%HurtboxShape") as CollisionShape2D
	assert_vector((body.shape as RectangleShape2D).size).is_equal(expected)
	assert_vector((hurt.shape as RectangleShape2D).size).is_equal(expected)


func test_player_starts_idle_and_vulnerable() -> void:
	var player: Player = auto_free(
		(load("res://src/player/player.tscn") as PackedScene).instantiate()
	)
	add_child(player)
	assert_int(player.state).is_equal(SM.State.IDLE)
	assert_bool(player.is_invincible()).is_false()


func test_take_hit_is_ignored_while_invincible() -> void:
	# The gate that lets PlayerStateMachine treat ctx.hurt as unconditional.
	var player: Player = auto_free(
		(load("res://src/player/player.tscn") as PackedScene).instantiate()
	)
	add_child(player)
	player.state = SM.State.ROLL
	player._state_time = 0.15
	assert_bool(player.is_invincible()).is_true()
	player.take_hit(25, Vector2.ZERO)
	assert_int(player.health.current).is_equal(Player.MAX_HEALTH)


func test_take_hit_lands_when_not_invincible() -> void:
	var player: Player = auto_free(
		(load("res://src/player/player.tscn") as PackedScene).instantiate()
	)
	add_child(player)
	player.take_hit(25, Vector2.ZERO)
	assert_int(player.health.current).is_equal(Player.MAX_HEALTH - 25)


func test_roll_covers_a_learnable_fixed_distance() -> void:
	# Roll distance is speed x duration and must stay a value a player can
	# internalise: far enough to clear an attack, not a teleport.
	var distance_tiles := Player.ROLL_SPEED_TILES * Player.ROLL_DURATION
	assert_float(distance_tiles).is_greater(3.0)
	assert_float(distance_tiles).is_less(6.0)
