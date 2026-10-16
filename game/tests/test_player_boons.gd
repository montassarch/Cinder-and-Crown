extends GdUnitTestSuite
## Boons taken during a run change the real player: health, speed, sword damage, lifesteal, mana.

var _player: Player
var _floor: StaticBody2D

func before_test() -> void:
	_floor = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(40.0, 1.0)
	shape.shape = rect
	_floor.add_child(shape)
	_floor.position = GameConfig.tiles_v(0.0, 6.0)
	add_child(_floor)
	_player = load("res://src/player/player.tscn").instantiate()
	_player.position = GameConfig.tiles_v(0.0, 3.0)
	add_child(_player)

func after_test() -> void:
	_player.queue_free()
	InputRouter.set_virtual_axis(0.0)
	InputRouter.set_virtual_button(&"attack", false)
	InputRouter.consume_attack()

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _land() -> void:
	await _frames(60)

func _boon(effect: BoonData.Effect, amount: float) -> BoonData:
	var b := BoonData.new()
	b.id = "test_%d" % effect
	b.effect = effect
	b.amount = amount
	return b

func _health() -> Health:
	return _player.get_node("Health")

func _dummy_in_reach() -> Node2D:
	var dummy: Node2D = auto_free(load("res://tests/support/hurtable_dummy.gd").new())
	add_child(dummy)
	dummy.global_position = _player.global_position + GameConfig.tiles_v(1.3, 0.0)
	return dummy

func _swing_at(dummy: Node2D) -> void:
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(1)
	InputRouter.set_virtual_button(&"attack", false)
	await _frames(25)

func test_a_max_health_boon_raises_the_cap_and_the_current_health() -> void:
	_player.apply_boon(_boon(BoonData.Effect.MAX_HEALTH, 20.0))
	assert_int(_health().max_health).is_equal(120)
	assert_int(_health().current).is_equal(120)

func test_a_heal_boon_restores_health_up_to_the_cap() -> void:
	_health().take_damage(50)
	_player.apply_boon(_boon(BoonData.Effect.HEAL, 30.0))
	assert_int(_health().current).is_equal(80)
	_player.apply_boon(_boon(BoonData.Effect.HEAL, 30.0))
	assert_int(_health().current).is_equal(100)

func test_a_speed_boon_makes_the_hero_run_faster() -> void:
	await _land()
	_player.apply_boon(_boon(BoonData.Effect.SPEED, 0.10))
	InputRouter.set_virtual_axis(1.0)
	await _frames(20)
	assert_float(_player.velocity.x).is_equal_approx(GameConfig.tiles(Player.RUN_SPEED) * 1.1, 0.01)

func test_a_damage_boon_makes_the_sword_hit_harder() -> void:
	await _land()
	var base: int = _player.weapon_in_slot(0).damage
	_player.apply_boon(_boon(BoonData.Effect.DAMAGE, 0.5))
	var dummy := _dummy_in_reach()
	await _swing_at(dummy)
	assert_int(dummy.hits.size()).is_equal(1)
	assert_int(dummy.hits[0][0]).is_equal(floori(base * 1.5))

func test_lifesteal_heals_on_every_sword_hit() -> void:
	await _land()
	_health().take_damage(40)
	_player.apply_boon(_boon(BoonData.Effect.LIFESTEAL, 2.0))
	var dummy := _dummy_in_reach()
	await _swing_at(dummy)
	assert_int(dummy.hits.size()).is_equal(1)
	assert_int(_health().current).is_equal(62)

func test_lifesteal_never_heals_past_the_cap() -> void:
	await _land()
	_player.apply_boon(_boon(BoonData.Effect.LIFESTEAL, 3.0))
	var dummy := _dummy_in_reach()
	await _swing_at(dummy)
	assert_int(_health().current).is_equal(100)

func test_a_mana_gain_boon_boosts_the_mana_a_hit_restores() -> void:
	await _land()
	_player.apply_boon(_boon(BoonData.Effect.MANA_GAIN, 0.5))
	_player.mana().spend(50.0)
	_player.mana().regen_per_second = 0.0
	var dummy := _dummy_in_reach()
	await _swing_at(dummy)
	assert_float(_player.mana().current).is_equal_approx(50.0 + Player.MANA_PER_HIT * 1.5, 0.01)

func test_reset_between_levels_keeps_the_boons() -> void:
	await _land()
	_player.apply_boon(_boon(BoonData.Effect.MAX_HEALTH, 20.0))
	_player.apply_boon(_boon(BoonData.Effect.DAMAGE, 0.5))
	_health().take_damage(60)
	_player.reset(GameConfig.tiles_v(2.0, 3.0))
	assert_int(_health().max_health).is_equal(120)
	assert_int(_health().current).is_equal(120)
	assert_float(_player.build().damage_multiplier()).is_equal_approx(1.5, 0.0001)

func test_starting_a_new_run_drops_every_boon() -> void:
	await _land()
	_player.apply_boon(_boon(BoonData.Effect.MAX_HEALTH, 20.0))
	_player.apply_boon(_boon(BoonData.Effect.DAMAGE, 0.5))
	_player.apply_boon(_boon(BoonData.Effect.SPEED, 0.2))
	_player.start_new_run()
	_player.reset(GameConfig.tiles_v(2.0, 3.0))
	assert_int(_health().max_health).is_equal(100)
	assert_int(_health().current).is_equal(100)
	await _frames(40)
	var dummy := _dummy_in_reach()
	await _swing_at(dummy)
	assert_int(dummy.hits[0][0]).is_equal(_player.weapon_in_slot(0).damage)
	InputRouter.set_virtual_axis(1.0)
	await _frames(20)
	assert_float(_player.velocity.x).is_equal_approx(GameConfig.tiles(Player.RUN_SPEED), 0.01)
