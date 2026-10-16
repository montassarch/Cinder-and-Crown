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

func test_weapon_damages_a_real_enemy_through_its_hurtbox() -> void:
	_dummy.queue_free()
	var data := EnemyData.new()
	data.max_health = 30
	data.behaviour = EnemyData.Behaviour.FLYER  # no gravity, no target: stays put
	data.body_size_tiles = Vector2(1.0, 1.0)
	data.telegraph_seconds = 0.5
	var enemy: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	enemy.position = GameConfig.tiles_v(1.3, 0.0)
	add_child(enemy)
	enemy.configure(data)
	_weapon.start_attack()
	await _frames(40)
	assert_int(enemy.health().current).is_equal(30 - load("res://data/weapons/rusty_blade.tres").damage)

func test_bonus_damage_adds_to_every_hit() -> void:
	_weapon.bonus_damage = 3
	_weapon.start_attack()
	await _frames(40)
	assert_int(_dummy.hits[0][0]).is_equal(load("res://data/weapons/rusty_blade.tres").damage + 3)

func test_a_certain_stun_chance_stuns_the_target() -> void:
	_weapon.stun_chance = 1.0
	_weapon.stun_seconds = 1.2
	_weapon.start_attack()
	await _frames(40)
	assert_array(_dummy.stuns).is_equal([1.2])

func test_no_stun_chance_never_stuns() -> void:
	_weapon.stun_chance = 0.0
	_weapon.start_attack()
	await _frames(40)
	assert_array(_dummy.stuns).is_empty()

func test_a_next_hit_multiplier_scales_the_damage_of_that_swing() -> void:
	var base: int = load("res://data/weapons/rusty_blade.tres").damage
	_weapon.next_hit_multiplier = 3.0
	_weapon.start_attack()
	await _frames(40)
	assert_int(_dummy.hits[0][0]).is_equal(base * 3)

func test_the_next_hit_multiplier_stacks_with_the_run_damage_multiplier() -> void:
	var base: int = load("res://data/weapons/rusty_blade.tres").damage
	_weapon.damage_multiplier = 1.5
	_weapon.next_hit_multiplier = 2.0
	_weapon.start_attack()
	await _frames(40)
	assert_int(_dummy.hits[0][0]).is_equal(floori(base * 3.0))
