extends GdUnitTestSuite
## The healing flask: a committed drink that heals when it finishes, a few charges per run,
## one charge back for every level cleared.

const State := PlayerStateMachine.PlayerState

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
	InputRouter.set_virtual_button(&"flask", false)
	InputRouter.consume_flask()

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _land() -> void:
	await _frames(60)

func _tap_flask() -> void:
	InputRouter.set_virtual_button(&"flask", true)
	await _frames(1)
	InputRouter.set_virtual_button(&"flask", false)

func _health() -> Health:
	return _player.get_node("Health")

func _drink_time() -> int:
	return int(Player.HEAL_SECONDS * 60.0) + 6

func test_a_fresh_hero_carries_the_base_charges() -> void:
	assert_int(_player.flask_charges()).is_equal(Player.FLASK_BASE_CHARGES)
	assert_int(_player.flask_max()).is_equal(Player.FLASK_BASE_CHARGES)

func test_drinking_heals_when_the_drink_finishes_and_uses_a_charge() -> void:
	await _land()
	_health().take_damage(60)
	await _tap_flask()
	await _frames(2)
	assert_int(_player.state()).is_equal(State.HEAL)
	assert_int(_health().current).is_equal(40)  # nothing yet: the drink is still in progress
	await _frames(_drink_time())
	assert_int(_health().current).is_equal(40 + Player.FLASK_HEAL)
	assert_int(_player.flask_charges()).is_equal(Player.FLASK_BASE_CHARGES - 1)
	assert_int(_player.state()).is_not_equal(State.HEAL)

func test_a_drink_never_heals_past_full() -> void:
	await _land()
	_health().take_damage(10)
	await _tap_flask()
	await _frames(_drink_time())
	assert_int(_health().current).is_equal(100)

func test_a_flask_is_not_wasted_at_full_health() -> void:
	await _land()
	await _tap_flask()
	await _frames(4)
	assert_int(_player.state()).is_not_equal(State.HEAL)
	assert_int(_player.flask_charges()).is_equal(Player.FLASK_BASE_CHARGES)

func test_no_charges_no_drink() -> void:
	await _land()
	_player.set_flask_charges(0)
	_health().take_damage(50)
	await _tap_flask()
	await _frames(4)
	assert_int(_player.state()).is_not_equal(State.HEAL)

func test_a_hit_during_the_drink_spills_it() -> void:
	await _land()
	_health().take_damage(50)
	await _tap_flask()
	await _frames(10)
	_player.take_hit(10, _player.global_position.x - 20.0)
	await _frames(_drink_time())
	assert_int(_health().current).is_equal(40)
	assert_int(_player.flask_charges()).is_equal(Player.FLASK_BASE_CHARGES)

func test_the_flask_announces_its_charges() -> void:
	await _land()
	var seen := []
	_player.flask_changed.connect(func(charges: int, maximum: int) -> void: seen.append([charges, maximum]))
	_health().take_damage(50)
	await _tap_flask()
	await _frames(_drink_time())
	assert_array(seen).is_equal([[Player.FLASK_BASE_CHARGES - 1, Player.FLASK_BASE_CHARGES]])

func test_clearing_a_level_returns_a_charge_up_to_the_maximum() -> void:
	_player.set_flask_charges(1)
	_player.refill_flask(1)
	assert_int(_player.flask_charges()).is_equal(2)
	_player.refill_flask(5)
	assert_int(_player.flask_charges()).is_equal(_player.flask_max())

func test_a_flask_boon_raises_the_maximum_and_fills_a_charge() -> void:
	_player.set_flask_charges(1)
	var boon := BoonData.new()
	boon.id = "test_flask"
	boon.effect = BoonData.Effect.FLASK_CHARGE
	boon.amount = 1.0
	_player.apply_boon(boon)
	assert_int(_player.flask_max()).is_equal(Player.FLASK_BASE_CHARGES + 1)
	assert_int(_player.flask_charges()).is_equal(2)

func test_a_new_run_refills_the_flask_and_drops_the_extra_charge() -> void:
	var boon := BoonData.new()
	boon.id = "test_flask"
	boon.effect = BoonData.Effect.FLASK_CHARGE
	boon.amount = 1.0
	_player.apply_boon(boon)
	_player.set_flask_charges(0)
	_player.start_new_run()
	assert_int(_player.flask_max()).is_equal(Player.FLASK_BASE_CHARGES)
	assert_int(_player.flask_charges()).is_equal(Player.FLASK_BASE_CHARGES)

func test_entering_the_next_level_keeps_health_and_flask() -> void:
	await _land()
	_health().take_damage(55)
	_player.set_flask_charges(1)
	_player.enter_level(GameConfig.tiles_v(3.0, 3.0))
	assert_int(_health().current).is_equal(45)
	assert_int(_player.flask_charges()).is_equal(1)
	assert_vector(_player.global_position).is_equal(GameConfig.tiles_v(3.0, 3.0))
	assert_int(_player.state()).is_equal(State.IDLE)

func test_entering_the_next_level_refills_mana() -> void:
	_player.mana().spend(70.0)
	_player.enter_level(GameConfig.tiles_v(3.0, 3.0))
	assert_float(_player.mana().current).is_equal(Player.MANA_MAX)

func test_a_full_reset_still_restores_health() -> void:
	_health().take_damage(55)
	_player.reset(GameConfig.tiles_v(3.0, 3.0))
	assert_int(_health().current).is_equal(100)
