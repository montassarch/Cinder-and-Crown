extends GdUnitTestSuite

const BLADE := "res://data/weapons/rusty_blade.tres"
const SPEAR := "res://data/weapons/ember_spear.tres"

func _data(attack_duration: float, window: Vector2) -> WeaponData:
	var d := WeaponData.new()
	d.display_name = "Test"
	d.damage = 10
	d.attack_duration = attack_duration
	d.hit_window = window
	d.hitbox_size_tiles = Vector2(1.0, 1.0)
	return d

func _weapon() -> Weapon:
	return auto_free(Weapon.new())

func test_both_shipped_weapons_load_from_disk() -> void:
	assert_object(load(BLADE)).is_instanceof(WeaponData)
	assert_object(load(SPEAR)).is_instanceof(WeaponData)
	assert_str(load(BLADE).display_name).is_not_empty()
	assert_str(load(SPEAR).display_name).is_not_empty()

func test_shipped_weapons_have_valid_hit_windows() -> void:
	assert_bool(load(BLADE).is_hit_window_valid()).is_true()
	assert_bool(load(SPEAR).is_hit_window_valid()).is_true()

func test_hit_window_starting_after_it_ends_is_invalid() -> void:
	assert_bool(_data(0.5, Vector2(0.3, 0.2)).is_hit_window_valid()).is_false()
	assert_bool(_data(0.5, Vector2(0.2, 0.2)).is_hit_window_valid()).is_false()

func test_hit_window_past_attack_duration_is_invalid() -> void:
	assert_bool(_data(0.5, Vector2(0.2, 0.6)).is_hit_window_valid()).is_false()

func test_hit_window_starting_before_zero_is_invalid() -> void:
	assert_bool(_data(0.5, Vector2(-0.1, 0.2)).is_hit_window_valid()).is_false()

func test_hitbox_inactive_before_window_opens() -> void:
	var weapon := _weapon()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	weapon.start_attack()
	weapon.advance(0.1)
	assert_bool(weapon.is_hitbox_active()).is_false()

func test_hitbox_active_inside_window() -> void:
	var weapon := _weapon()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	weapon.start_attack()
	weapon.advance(0.25)
	assert_bool(weapon.is_hitbox_active()).is_true()

func test_hitbox_inactive_after_window_closes() -> void:
	var weapon := _weapon()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	weapon.start_attack()
	weapon.advance(0.35)
	assert_bool(weapon.is_hitbox_active()).is_false()

func test_cancel_attack_deactivates_hitbox_immediately() -> void:
	var weapon := _weapon()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	weapon.start_attack()
	weapon.advance(0.25)
	weapon.cancel_attack()
	assert_bool(weapon.is_hitbox_active()).is_false()

func test_swapping_weapon_mid_hit_window_withdraws_the_hitbox() -> void:
	# Review Focus 1: equip() during an active window must cancel the attack,
	# leave is_hitbox_active() false, and reset elapsed time so the new
	# weapon does not inherit the old window's progress.
	var weapon := _weapon()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	weapon.start_attack()
	weapon.advance(0.25)
	assert_bool(weapon.is_hitbox_active()).is_true()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	assert_bool(weapon.is_hitbox_active()).is_false()
	weapon.advance(0.1)
	assert_bool(weapon.is_hitbox_active()).is_false()
	# New weapon's own swing starts from zero, not from the old 0.25 s.
	weapon.start_attack()
	weapon.advance(0.1)
	assert_bool(weapon.is_hitbox_active()).is_false()

func test_attack_ends_itself_at_attack_duration() -> void:
	var weapon := _weapon()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	weapon.start_attack()
	weapon.advance(0.6)
	assert_bool(weapon.is_hitbox_active()).is_false()
	weapon.advance(0.01)
	assert_bool(weapon.is_hitbox_active()).is_false()

func test_equip_sizes_the_hitbox_from_tiles() -> void:
	var weapon := _weapon()
	var d := _data(0.5, Vector2(0.2, 0.3))
	d.hitbox_size_tiles = Vector2(2.0, 1.0)
	d.hitbox_offset_tiles = Vector2(1.5, 0.0)
	weapon.equip(d)
	assert_vector(weapon.hitbox_size()).is_equal(GameConfig.tiles_v(2.0, 1.0))
	assert_vector(weapon.hitbox_center()).is_equal(GameConfig.tiles_v(1.5, 0.0))
	weapon.set_facing(-1.0)
	assert_vector(weapon.hitbox_center()).is_equal(GameConfig.tiles_v(-1.5, 0.0))

func test_weapon_is_recovering_only_after_its_hit_window_closes() -> void:
	var weapon := _weapon()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	weapon.start_attack()
	weapon.advance(0.1)
	assert_bool(weapon.is_recovering()).is_false()
	weapon.advance(0.25)
	assert_bool(weapon.is_recovering()).is_true()
	weapon.cancel_attack()
	assert_bool(weapon.is_recovering()).is_false()

func test_a_slower_swing_stretches_its_hit_window_in_time() -> void:
	var weapon := _weapon()
	weapon.equip(_data(0.5, Vector2(0.2, 0.3)))
	weapon.start_attack(2.0)
	weapon.advance(0.25)                 # 0.125 s of swing time: before the window
	assert_bool(weapon.is_hitbox_active()).is_false()
	weapon.advance(0.25)                 # 0.25 s of swing time: inside it
	assert_bool(weapon.is_hitbox_active()).is_true()
	weapon.advance(0.6)                  # 0.55 s of swing time: past attack_duration, swing over
	assert_bool(weapon.is_hitbox_active()).is_false()
	assert_bool(weapon.is_recovering()).is_false()
