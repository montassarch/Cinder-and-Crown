extends GdUnitTestSuite
## Every weapon is a set of moves: a tap chain, an air move and a roll move.

const WEAPONS := {
	"Rusty Blade": "res://data/weapons/rusty_blade.tres",
	"Ember Spear": "res://data/weapons/ember_spear.tres",
	"Hunter's Bow": "res://data/weapons/hunters_bow.tres",
	"Ash Wand": "res://data/weapons/ash_wand.tres",
	"Iron Gauntlet": "res://data/weapons/iron_gauntlet.tres",
}


func _move(duration: float = 0.4, window: Vector2 = Vector2(0.1, 0.2)) -> WeaponMove:
	var m := WeaponMove.new()
	m.duration = duration
	m.hit_window = window
	return m


func test_a_move_needs_a_hit_window_inside_its_duration() -> void:
	assert_bool(_move(0.4, Vector2(0.1, 0.2)).is_valid()).is_true()
	assert_bool(_move(0.4, Vector2(0.3, 0.2)).is_valid()).is_false()
	assert_bool(_move(0.4, Vector2(0.1, 0.5)).is_valid()).is_false()
	assert_bool(_move(0.4, Vector2(-0.1, 0.2)).is_valid()).is_false()


func test_the_five_weapons_exist_by_name() -> void:
	for name in WEAPONS:
		var data := load(WEAPONS[name]) as WeaponData
		assert_object(data).is_not_null()
		assert_str(data.display_name).is_equal(name)


func test_the_sword_chains_three_attacks_and_the_spear_two() -> void:
	assert_int((load(WEAPONS["Rusty Blade"]) as WeaponData).chain.size()).is_equal(3)
	assert_int((load(WEAPONS["Ember Spear"]) as WeaponData).chain.size()).is_equal(2)


func test_every_weapon_has_at_least_four_moves() -> void:
	for name in WEAPONS:
		var data := load(WEAPONS[name]) as WeaponData
		assert_int(data.move_count()).is_greater_equal(4)
		assert_object(data.air_move).is_not_null()
		assert_object(data.roll_move).is_not_null()


func test_every_move_of_every_weapon_is_valid_and_named() -> void:
	for name in WEAPONS:
		for move in (load(WEAPONS[name]) as WeaponData).all_moves():
			assert_bool(move.is_valid()).override_failure_message("%s / %s" % [name, move.display_name]).is_true()
			assert_str(move.display_name).is_not_empty()


func test_the_bow_and_the_wand_shoot_and_the_rest_strike() -> void:
	for name in ["Hunter's Bow", "Ash Wand"]:
		for move in (load(WEAPONS[name]) as WeaponData).all_moves():
			assert_int(move.kind).override_failure_message("%s / %s" % [name, move.display_name]).is_equal(WeaponMove.Kind.PROJECTILE)
	for name in ["Rusty Blade", "Ember Spear", "Iron Gauntlet"]:
		for move in (load(WEAPONS[name]) as WeaponData).all_moves():
			assert_int(move.kind).is_equal(WeaponMove.Kind.MELEE)


func test_no_two_moves_of_a_weapon_play_alike() -> void:
	# Distinct hit shape or movement or look: a weapon whose moves are copies of each other is not a moveset.
	for name in WEAPONS:
		var seen := {}
		for move in (load(WEAPONS[name]) as WeaponData).all_moves():
			var signature := "%s|%s|%s|%s|%s|%s" % [move.hitbox_size_tiles, move.hitbox_offset_tiles, move.lunge_tiles_per_second, move.dive_speed_tiles, move.projectile_angle_degrees, move.projectile_count]
			assert_bool(seen.has(signature)).override_failure_message("%s: %s repeats %s" % [name, move.display_name, seen.get(signature, "")]).is_false()
			seen[signature] = move.display_name


func test_the_chain_steps_on_when_quick_and_restarts_after_a_pause() -> void:
	var sword := load(WEAPONS["Rusty Blade"]) as WeaponData
	assert_int(sword.next_chain_step(0, true)).is_equal(1)
	assert_int(sword.next_chain_step(1, true)).is_equal(2)
	assert_int(sword.next_chain_step(2, true)).is_equal(0)
	assert_int(sword.next_chain_step(1, false)).is_equal(0)
	var spear := load(WEAPONS["Ember Spear"]) as WeaponData
	assert_int(spear.next_chain_step(1, true)).is_equal(0)


func test_a_weapon_without_a_chain_still_has_its_plain_swing() -> void:
	var d := WeaponData.new()
	d.display_name = "Stick"
	assert_int(d.chain_move(0).kind).is_equal(WeaponMove.Kind.MELEE)
	assert_int(d.chain_length()).is_equal(1)
