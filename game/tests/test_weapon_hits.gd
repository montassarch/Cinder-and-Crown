extends GdUnitTestSuite

const DUMMY := preload("res://tests/support/hurtable_dummy.gd")

var _weapon: Weapon
var _dummy: Node2D

func before_test() -> void:
	_weapon = auto_free(Weapon.new())
	add_child(_weapon)
	_weapon.equip(load("res://data/weapons/rusty_blade.tres"))
	_dummy = auto_free(DUMMY.new())
	_dummy.position = GameConfig.tiles_v(1.3, 0.0)
	add_child(_dummy)

func after_test() -> void:
	Engine.time_scale = 1.0

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func test_a_swing_hits_a_target_once_with_the_weapons_damage() -> void:
	var landed := []
	_weapon.hit_landed.connect(func(target: Node, damage: int) -> void: landed.append([target, damage]))
	_weapon.start_attack()
	await _frames(40)
	assert_int(_dummy.hits.size()).is_equal(1)
	assert_int(_dummy.hits[0][0]).is_equal(load("res://data/weapons/rusty_blade.tres").damage)
	assert_int(landed.size()).is_equal(1)
	assert_object(landed[0][0]).is_same(_dummy)

func test_a_target_outside_the_hitbox_is_not_hit() -> void:
	_dummy.position = GameConfig.tiles_v(8.0, 0.0)
	_weapon.start_attack()
	await _frames(40)
	assert_int(_dummy.hits.size()).is_equal(0)

func test_hitbox_facing_left_does_not_hit_a_target_on_the_right() -> void:
	_weapon.set_facing(-1.0)
	_weapon.start_attack()
	await _frames(40)
	assert_int(_dummy.hits.size()).is_equal(0)

func test_late_overlap_after_a_swap_deals_no_damage() -> void:
	# Review Focus 1, physics side: an overlap already queued when the weapon is
	# swapped must not land on the old weapon's behalf.
	_weapon.start_attack()
	_weapon.advance(0.12)
	assert_bool(_weapon.is_hitbox_active()).is_true()
	_weapon.equip(load("res://data/weapons/ember_spear.tres"))
	_weapon._on_area_entered(_dummy.hurtbox())
	assert_int(_dummy.hits.size()).is_equal(0)

func test_hit_stop_slows_time_then_restores_it() -> void:
	HitStop.freeze(0.1)
	assert_float(Engine.time_scale).is_less(1.0)
	await await_millis(250)
	assert_float(Engine.time_scale).is_equal(1.0)

func test_longer_freeze_is_not_cut_short_by_a_shorter_one() -> void:
	HitStop.freeze(0.5)
	HitStop.freeze(0.05)
	OS.delay_msec(120)  # real time passes; the short freeze has expired, the long one has not
	HitStop._process(0.0)
	assert_float(Engine.time_scale).is_less(1.0)
