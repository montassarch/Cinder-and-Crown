class_name WeaponDataTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# The data-driven rule, enforced: adding a third weapon must be a new .tres
# file and no code change. These tests load the shipped weapons from disk
# rather than constructing them inline, so a broken resource file fails
# here instead of silently at play time.

const WeaponScript := preload("res://src/weapons/weapon.gd")

const RUSTY_BLADE := "res://data/weapons/rusty_blade.tres"
const EMBER_SPEAR := "res://data/weapons/ember_spear.tres"


func _make_data(duration: float, window: Vector2) -> WeaponData:
	var data := WeaponData.new()
	data.attack_duration = duration
	data.hit_window = window
	return data


func _make_weapon(data: WeaponData) -> Node2D:
	var weapon: Node2D = auto_free(WeaponScript.new())
	add_child(weapon)
	weapon.equip(data)
	return weapon


# --- shipped data ---

func test_both_shipped_weapons_load_from_disk() -> void:
	assert_object(load(RUSTY_BLADE)).is_instanceof(WeaponData)
	assert_object(load(EMBER_SPEAR)).is_instanceof(WeaponData)


func test_shipped_weapons_have_valid_hit_windows() -> void:
	for path: String in [RUSTY_BLADE, EMBER_SPEAR]:
		var data: WeaponData = load(path)
		assert_bool(data.is_hit_window_valid()).override_failure_message(
			"%s has an unusable hit window" % path
		).is_true()


func test_shipped_weapons_differ_in_reach_and_damage() -> void:
	# Two weapons that play identically would not prove the system is
	# data-driven, only that it loads files.
	var blade: WeaponData = load(RUSTY_BLADE)
	var spear: WeaponData = load(EMBER_SPEAR)
	assert_bool(spear.hitbox_size_tiles.x > blade.hitbox_size_tiles.x).is_true()
	assert_bool(spear.damage > blade.damage).is_true()
	assert_bool(spear.attack_duration > blade.attack_duration).is_true()


func test_shipped_weapons_are_named() -> void:
	for path: String in [RUSTY_BLADE, EMBER_SPEAR]:
		assert_str((load(path) as WeaponData).display_name).is_not_empty()


# --- hit window validation ---

func test_hit_window_starting_after_it_ends_is_invalid() -> void:
	assert_bool(_make_data(0.4, Vector2(0.3, 0.1)).is_hit_window_valid()).is_false()


func test_hit_window_past_attack_duration_is_invalid() -> void:
	# A window that outlives the swing would leave the hitbox live after
	# the animation ended.
	assert_bool(_make_data(0.3, Vector2(0.1, 0.5)).is_hit_window_valid()).is_false()


func test_negative_hit_window_start_is_invalid() -> void:
	assert_bool(_make_data(0.3, Vector2(-0.1, 0.2)).is_hit_window_valid()).is_false()


func test_zero_length_hit_window_is_invalid() -> void:
	# A window with no duration can never be sampled, so the weapon would
	# simply never hit anything.
	assert_bool(_make_data(0.3, Vector2(0.1, 0.1)).is_hit_window_valid()).is_false()


# --- hitbox timing ---

func test_hitbox_inactive_before_window_opens() -> void:
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	weapon.start_attack()
	weapon.advance(0.05)
	assert_bool(weapon.is_hitbox_active()).is_false()


func test_hitbox_active_inside_window() -> void:
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	weapon.start_attack()
	weapon.advance(0.15)
	assert_bool(weapon.is_hitbox_active()).is_true()


func test_hitbox_inactive_after_window_closes() -> void:
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	weapon.start_attack()
	weapon.advance(0.3)
	assert_bool(weapon.is_hitbox_active()).is_false()


func test_hitbox_inactive_before_any_attack_starts() -> void:
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	assert_bool(weapon.is_hitbox_active()).is_false()


func test_attack_ends_on_its_own_after_the_duration() -> void:
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	weapon.start_attack()
	weapon.advance(0.5)
	assert_bool(weapon.is_attacking()).is_false()


func test_cancel_attack_deactivates_hitbox_immediately() -> void:
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	weapon.start_attack()
	weapon.advance(0.15)
	assert_bool(weapon.is_hitbox_active()).is_true()
	weapon.cancel_attack()
	assert_bool(weapon.is_hitbox_active()).is_false()


# --- Review Focus 1 ---

func test_swapping_weapon_mid_hit_window_withdraws_the_hitbox() -> void:
	# Review Focus 1. Swapping is always allowed in this combat model -- no
	# stamina, no lockout -- so it can land inside an active hit window.
	# The old weapon's hitbox must go down immediately.
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	weapon.start_attack()
	weapon.advance(0.15)
	assert_bool(weapon.is_hitbox_active()).is_true()

	weapon.equip(_make_data(0.6, Vector2(0.2, 0.4)))
	assert_bool(weapon.is_hitbox_active()).is_false()
	assert_bool(weapon.is_attacking()).is_false()


func test_swapped_in_weapon_does_not_inherit_elapsed_time() -> void:
	# Review Focus 1, the subtler half: if elapsed time carried over, the
	# new weapon would start its swing already part-way through -- and with
	# a longer window could come up instantly live.
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	weapon.start_attack()
	weapon.advance(0.35)

	weapon.equip(_make_data(0.6, Vector2(0.2, 0.4)))
	weapon.start_attack()
	assert_bool(weapon.is_hitbox_active()).is_false()
	weapon.advance(0.05)
	assert_bool(weapon.is_hitbox_active()).is_false()


func test_each_target_is_hit_once_per_swing() -> void:
	# Without this a hitbox overlapping an enemy for 6 frames deals six
	# hits, and every weapon becomes a shredder at point-blank range.
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.3)))
	var target: Node = auto_free(Node.new())
	weapon.start_attack()
	weapon.advance(0.15)
	assert_bool(weapon.try_hit(target)).is_true()
	assert_bool(weapon.try_hit(target)).is_false()


func test_a_new_swing_can_hit_the_same_target_again() -> void:
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.3)))
	var target: Node = auto_free(Node.new())
	weapon.start_attack()
	weapon.advance(0.15)
	weapon.try_hit(target)
	weapon.cancel_attack()
	weapon.start_attack()
	weapon.advance(0.15)
	assert_bool(weapon.try_hit(target)).is_true()


func test_try_hit_outside_the_window_is_refused() -> void:
	var weapon := _make_weapon(_make_data(0.4, Vector2(0.1, 0.2)))
	var target: Node = auto_free(Node.new())
	weapon.start_attack()
	weapon.advance(0.05)
	assert_bool(weapon.try_hit(target)).is_false()
