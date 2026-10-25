extends GdUnitTestSuite
## The hero plays his weapon's moves: the tap chain, an air move and a roll move, each with its own motion.

const State := PlayerStateMachine.PlayerState
const BOW := "res://data/weapons/hunters_bow.tres"
const SPEAR := "res://data/weapons/ember_spear.tres"
const GAUNTLET := "res://data/weapons/iron_gauntlet.tres"

var _player: Player
var _floor: StaticBody2D


func before_test() -> void:
	_floor = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(60.0, 1.0)
	shape.shape = rect
	_floor.add_child(shape)
	_floor.position = GameConfig.tiles_v(0.0, 6.0)
	add_child(_floor)
	_player = load("res://src/player/player.tscn").instantiate()
	_player.position = GameConfig.tiles_v(0.0, 3.0)
	add_child(_player)


func after_test() -> void:
	_player.queue_free()
	for action in [&"jump", &"attack", &"roll"]:
		InputRouter.set_virtual_button(action, false)
	InputRouter.consume_jump()
	InputRouter.consume_attack()
	InputRouter.consume_roll()
	InputRouter.set_virtual_axis(0.0)
	Engine.time_scale = 1.0


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _land() -> void:
	await _frames(60)


func _tap(action: StringName = &"attack") -> void:
	InputRouter.set_virtual_button(action, true)
	await _frames(1)
	InputRouter.set_virtual_button(action, false)


func _equip(path: String) -> void:
	_player.set_weapon(0, load(path))


func _move_name() -> String:
	return _player.current_move().display_name


func test_the_blade_chains_slash_rising_cut_crushing_blow() -> void:
	await _land()
	var names := []
	for i in 3:
		await _tap()
		await _frames(3)
		names.append(_move_name())
		await _frames(int(Player.COMBO_WINDOW * 60.0 * 0.5) + 20)
	assert_array(names).is_equal(["Slash", "Rising Cut", "Crushing Blow"])


func test_the_spear_chains_two_strikes_then_starts_over() -> void:
	await _land()
	_equip(SPEAR)
	var steps := []
	for i in 3:
		await _tap()
		await _frames(3)
		steps.append(_player.combo_step())
		await _frames(int(Player.COMBO_WINDOW * 60.0 * 0.5) + 28)
	assert_array(steps).is_equal([0, 1, 0])


func test_attacking_in_the_air_plays_the_air_move_and_dives() -> void:
	await _land()
	var plunge := (load("res://data/weapons/rusty_blade.tres") as WeaponData).air_move
	_player.position.y -= GameConfig.tiles(3.0)
	await _frames(2)
	await _tap()
	await _frames(2)
	assert_int(_player.state()).is_equal(State.ATTACK)
	assert_str(_move_name()).is_equal(plunge.display_name)
	assert_float(_player.velocity.y).is_greater_equal(GameConfig.tiles(plunge.dive_speed_tiles) * 0.9)


func test_attacking_while_rising_also_plays_the_air_move() -> void:
	await _land()
	InputRouter.set_virtual_button(&"jump", true)
	await _frames(6)
	InputRouter.set_virtual_button(&"jump", false)
	assert_int(_player.state()).is_equal(State.JUMP)
	await _tap()
	await _frames(2)
	assert_int(_player.state()).is_equal(State.ATTACK)
	assert_str(_move_name()).is_equal("Plunge")


func test_attacking_just_after_a_roll_plays_the_roll_move_and_lunges() -> void:
	await _land()
	var start_x := _player.global_position.x
	await _tap(&"roll")
	await _frames(int(PlayerStateMachine.ROLL_DURATION * 60.0) - 3)
	await _tap()
	await _frames(8)
	assert_int(_player.state()).is_equal(State.ATTACK)
	assert_str(_move_name()).is_equal("Roll Cut")
	var after_roll := _player.global_position.x
	await _frames(14)
	assert_float(_player.global_position.x - after_roll).is_greater(GameConfig.tiles(0.8))
	assert_float(after_roll).is_greater(start_x)


func test_a_later_attack_is_the_plain_first_strike_again() -> void:
	await _land()
	await _tap(&"roll")
	await _frames(int(PlayerStateMachine.ROLL_DURATION * 60.0) + 40)
	await _tap()
	await _frames(3)
	assert_str(_move_name()).is_equal("Slash")


func test_a_move_does_not_chain_into_the_second_strike_of_the_chain() -> void:
	await _land()
	await _tap(&"roll")
	await _frames(int(PlayerStateMachine.ROLL_DURATION * 60.0) - 3)
	await _tap()
	await _frames(40)
	await _tap()
	await _frames(3)
	assert_str(_move_name()).is_equal("Slash")


func test_a_strike_carries_the_hero_forward() -> void:
	await _land()
	_equip(SPEAR)
	var start_x := _player.global_position.x
	await _tap()
	await _frames(25)
	assert_float(_player.global_position.x - start_x).is_greater(GameConfig.tiles(0.4))


func test_the_bow_fires_a_shot_and_the_hero_steps_back() -> void:
	await _land()
	_equip(BOW)
	var start_x := _player.global_position.x
	await _tap()
	await _frames(20)
	var shots := get_children().filter(func(n: Node) -> bool: return n is PlayerProjectile)
	assert_int(shots.size()).is_equal(1)
	assert_float(shots[0].global_position.x).is_greater(start_x)
	assert_float(_player.global_position.x).is_less(start_x)


func test_the_gauntlet_chains_three_punches() -> void:
	await _land()
	_equip(GAUNTLET)
	var names := []
	for i in 3:
		await _tap()
		await _frames(3)
		names.append(_move_name())
		await _frames(int(Player.COMBO_WINDOW * 60.0 * 0.5) + 12)
	assert_array(names).is_equal(["Jab", "Cross", "Uppercut"])


func test_the_hero_swings_with_the_move_animation_of_the_weapon() -> void:
	await _land()
	_equip(SPEAR)
	await _tap()
	await _frames(4)
	assert_str(_player.get_node("Visual").animation).is_equal("parry")
