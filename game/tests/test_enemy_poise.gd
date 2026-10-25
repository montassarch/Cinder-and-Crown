extends GdUnitTestSuite
## Hits flinch light enemies until their strike is committed; poised enemies shrug hits off
## until their guard breaks, which leaves them staggered and taking extra damage.

const ENEMY_SCENE := "res://src/enemies/enemy.tscn"

func _data(poise: int = 0, telegraph: float = 0.5, behaviour: EnemyData.Behaviour = EnemyData.Behaviour.CHASER) -> EnemyData:
	var d := EnemyData.new()
	d.display_name = "Test"
	d.max_health = 100
	d.move_speed_tiles = 0.0
	d.attack_damage = 7
	d.attack_range_tiles = 2.0
	d.telegraph_seconds = telegraph
	d.recovery_seconds = 0.4
	d.poise = poise
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

func _hit(enemy: Enemy, damage: int = 1) -> void:
	enemy.take_hit(damage, enemy.global_position.x - 10.0)

# --- Telegraph progress (what the on-screen cue is drawn from) ---

func test_telegraph_progress_is_zero_when_not_winding_up() -> void:
	assert_float(_spawn(_data()).telegraph_progress()).is_equal(0.0)

func test_telegraph_progress_climbs_to_the_strike() -> void:
	# A long wind-up, so uneven frame speed under load cannot carry the progress out of the range checked.
	var data := _data()
	data.telegraph_seconds = 3.0
	var enemy := _spawn(data)
	enemy.begin_telegraph()
	assert_float(enemy.telegraph_progress()).is_less(0.1)
	await _frames(15)
	assert_float(enemy.telegraph_progress()).is_between(0.03, 0.45)

# --- Light enemies flinch, unless the strike is committed ---

func test_a_hit_early_in_the_wind_up_interrupts_it() -> void:
	var enemy := _spawn(_data())
	enemy.begin_telegraph()
	await _frames(3)
	_hit(enemy)
	assert_bool(enemy.is_telegraphing()).is_false()
	assert_bool(enemy.is_stunned()).is_true()

func test_a_flinch_is_short_and_the_enemy_resumes() -> void:
	var enemy := _spawn(_data())
	enemy.begin_telegraph()
	_hit(enemy)
	await _frames(int(Enemy.FLINCH_SECONDS * 60.0) + 8)
	assert_bool(enemy.is_stunned()).is_false()

func test_a_hit_late_in_the_wind_up_does_not_stop_the_strike() -> void:
	var enemy := _spawn(_data())
	var released := [0]
	enemy.attack_released.connect(func(_d: int) -> void: released[0] += 1)
	enemy.begin_telegraph()
	await _frames(int(0.5 * 60.0 * Enemy.COMMIT_FRACTION) + 5)
	assert_bool(enemy.is_committed()).is_true()
	_hit(enemy)
	assert_bool(enemy.is_telegraphing()).is_true()
	await _frames(25)
	assert_int(released[0]).is_equal(1)

func test_a_hit_still_damages_a_committed_enemy() -> void:
	var enemy := _spawn(_data())
	enemy.begin_telegraph()
	await _frames(int(0.5 * 60.0 * Enemy.COMMIT_FRACTION) + 5)
	_hit(enemy, 9)
	assert_int(enemy.health().current).is_equal(91)

func test_an_enemy_walking_towards_you_flinches_when_hit() -> void:
	var enemy := _spawn(_data())
	_hit(enemy)
	assert_bool(enemy.is_stunned()).is_true()

func test_a_recovering_enemy_does_not_flinch() -> void:
	var enemy := _spawn(_data())
	enemy.begin_telegraph()
	await _frames(int(0.5 * 60.0) + 6)
	assert_bool(enemy.is_telegraphing()).is_false()
	_hit(enemy)
	assert_bool(enemy.is_stunned()).is_false()

func test_a_hit_that_kills_does_not_flinch() -> void:
	var enemy := _spawn(_data())
	_hit(enemy, 999)
	assert_bool(enemy.is_dead()).is_true()
	assert_bool(enemy.is_stunned()).is_false()

# --- Poise ---

func test_a_poised_enemy_starts_with_full_poise() -> void:
	var enemy := _spawn(_data(4))
	assert_int(enemy.poise()).is_equal(4)
	assert_int(_spawn(_data(0)).poise()).is_equal(0)

func test_a_poised_enemy_shrugs_off_hits_without_flinching() -> void:
	var enemy := _spawn(_data(3))
	_hit(enemy)
	assert_bool(enemy.is_stunned()).is_false()
	assert_int(enemy.poise()).is_equal(2)

func test_a_poised_enemy_keeps_its_wind_up_through_hits() -> void:
	var enemy := _spawn(_data(3))
	enemy.begin_telegraph()
	await _frames(2)
	_hit(enemy)
	assert_bool(enemy.is_telegraphing()).is_true()

func test_the_last_point_of_poise_breaks_the_guard() -> void:
	var enemy := _spawn(_data(2))
	_hit(enemy)
	_hit(enemy)
	assert_bool(enemy.is_stunned()).is_true()
	assert_bool(enemy.is_guard_broken()).is_true()

func test_a_guard_break_cancels_even_a_committed_strike() -> void:
	var enemy := _spawn(_data(1))
	var released := [0]
	enemy.attack_released.connect(func(_d: int) -> void: released[0] += 1)
	enemy.begin_telegraph()
	await _frames(int(0.5 * 60.0 * Enemy.COMMIT_FRACTION) + 5)
	_hit(enemy)
	await _frames(40)
	assert_int(released[0]).is_equal(0)

func test_a_broken_guard_takes_extra_damage() -> void:
	var enemy := _spawn(_data(1))
	_hit(enemy)
	var before := enemy.health().current
	_hit(enemy, 10)
	assert_int(before - enemy.health().current).is_equal(ceili(10 * Enemy.BREAK_DAMAGE_MULTIPLIER))

func test_the_break_wears_off_and_poise_is_full_again() -> void:
	var enemy := _spawn(_data(2))
	_hit(enemy)
	_hit(enemy)
	await _frames(int(Enemy.BREAK_STAGGER * 60.0) + 10)
	assert_bool(enemy.is_guard_broken()).is_false()
	assert_bool(enemy.is_stunned()).is_false()
	assert_int(enemy.poise()).is_equal(2)
	var before := enemy.health().current
	_hit(enemy, 10)
	assert_int(before - enemy.health().current).is_equal(10)

func test_poise_comes_back_after_a_while_without_being_hit() -> void:
	var enemy := _spawn(_data(4))
	_hit(enemy)
	_hit(enemy)
	assert_int(enemy.poise()).is_equal(2)
	await _frames(int(Enemy.POISE_REGEN_DELAY * 60.0) + 10)
	assert_int(enemy.poise()).is_equal(4)

func test_being_hit_again_delays_the_poise_recovery() -> void:
	var enemy := _spawn(_data(4))
	_hit(enemy)
	await _frames(int(Enemy.POISE_REGEN_DELAY * 60.0 * 0.7))
	_hit(enemy)
	await _frames(int(Enemy.POISE_REGEN_DELAY * 60.0 * 0.7))
	assert_int(enemy.poise()).is_less(4)

# --- Data ---

func test_the_crown_brute_has_poise_and_the_light_enemies_do_not() -> void:
	assert_int((load("res://data/enemies/crown_brute.tres") as EnemyData).poise).is_greater(1)
	assert_int((load("res://data/enemies/shambler.tres") as EnemyData).poise).is_equal(0)
	assert_int((load("res://data/enemies/cinder_bat.tres") as EnemyData).poise).is_equal(0)

# --- Shield ---

func _shielded(poise: int = 0) -> Enemy:
	var data := _data(poise)
	data.shielded = true
	data.behaviour = EnemyData.Behaviour.FLYER  # no gravity: needs no floor
	return _spawn(data)

func test_a_hit_from_the_front_is_absorbed() -> void:
	var enemy := _shielded()
	assert_float(enemy.facing()).is_equal(1.0)
	enemy.take_hit(10, enemy.global_position.x + 10.0)  # from the side it faces
	assert_int(enemy.health().current).is_equal(100)

func test_a_hit_from_behind_deals_full_damage() -> void:
	var enemy := _shielded()
	enemy.take_hit(10, enemy.global_position.x - 10.0)
	assert_int(enemy.health().current).is_equal(90)

func test_a_front_hit_still_wears_poise_down_until_the_guard_breaks() -> void:
	var enemy := _shielded(2)
	enemy.take_hit(10, enemy.global_position.x + 10.0)
	assert_int(enemy.poise()).is_equal(1)
	assert_bool(enemy.is_guard_broken()).is_false()
	enemy.take_hit(10, enemy.global_position.x + 10.0)
	assert_bool(enemy.is_guard_broken()).is_true()
	assert_int(enemy.health().current).is_equal(100)  # nothing got through yet

func test_a_broken_shield_takes_full_damage_from_the_front() -> void:
	var enemy := _shielded(1)
	enemy.take_hit(10, enemy.global_position.x + 10.0)  # breaks the guard
	assert_bool(enemy.is_guard_broken()).is_true()
	enemy.take_hit(10, enemy.global_position.x + 10.0)
	assert_int(enemy.health().current).is_equal(100 - ceili(10 * Enemy.BREAK_DAMAGE_MULTIPLIER))

func test_a_non_shielded_enemy_is_hurt_from_the_front_as_always() -> void:
	var enemy := _spawn(_data(0))
	enemy.take_hit(10, enemy.global_position.x + 10.0)
	assert_int(enemy.health().current).is_equal(90)

func test_the_shield_follows_the_hero_even_after_the_enemy_is_knocked_past_him() -> void:
	var data := _data(0)
	data.shielded = true
	data.behaviour = EnemyData.Behaviour.FLYER
	var enemy := _spawn(data)
	var hero: Node2D = auto_free(Node2D.new())
	add_child(hero)
	hero.global_position = enemy.global_position + Vector2(100.0, 0.0)
	enemy.target = hero
	await _frames(3)
	assert_float(enemy.facing()).is_equal(1.0)
	enemy.global_position = hero.global_position + Vector2(100.0, 0.0)  # knocked back past the hero
	await _frames(3)
	assert_float(enemy.facing()).is_equal(-1.0)
	enemy.take_hit(10, hero.global_position.x)  # the hero is on its left: its front
	assert_int(enemy.health().current).is_equal(100)
	enemy.take_hit(10, enemy.global_position.x + 50.0)  # from its right: its back
	assert_int(enemy.health().current).is_equal(90)

func _melee_shield_scene() -> Array:
	var data := _data(0)
	data.shielded = true
	data.behaviour = EnemyData.Behaviour.FLYER
	var enemy := _spawn(data)
	var hero: Node2D = auto_free(load("res://tests/support/strike_recorder.gd").new())
	add_child(hero)
	hero.global_position = enemy.global_position + Vector2(24.0, 0.0)
	enemy.target = hero
	return [enemy, hero]

func test_a_hero_behind_a_winding_up_shielded_enemy_is_not_struck() -> void:
	var scene := _melee_shield_scene()
	var enemy: Enemy = scene[0]
	var hero: Node2D = scene[1]
	enemy.begin_telegraph()  # the hero is on its right: it winds up facing right
	await _frames(5)
	hero.global_position = enemy.global_position + Vector2(-24.0, 0.0)  # he steps round behind it
	await _frames(45)
	assert_int(hero.strikes.size() + hero.hits.size()).is_equal(0)

func test_a_shielded_enemy_does_not_turn_while_recovering_so_its_back_stays_open() -> void:
	var scene := _melee_shield_scene()
	var enemy: Enemy = scene[0]
	var hero: Node2D = scene[1]
	enemy.begin_telegraph()
	await _frames(33)  # the strike is over: it is recovering
	hero.global_position = enemy.global_position + Vector2(-24.0, 0.0)
	await _frames(5)
	assert_float(enemy.facing()).is_equal(1.0)  # still facing where it struck
	enemy.take_hit(10, hero.global_position.x)  # from behind it
	assert_int(enemy.health().current).is_equal(90)

func test_a_blocked_hit_flashes_the_body_then_settles() -> void:
	var enemy := _shielded()
	enemy.take_hit(10, enemy.global_position.x + 10.0)
	assert_object(enemy.body_color()).is_equal(Enemy.SHIELD_FLASH_COLOR)
	await _frames(int(Enemy.SHIELD_FLASH_SECONDS * 60.0) + 6)
	assert_object(enemy.body_color()).is_equal(enemy.data.tint)
