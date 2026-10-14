extends GdUnitTestSuite
## Wiring check for player.tscn: real physics, real scene, virtual input.

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
	for action in [&"jump", &"attack", &"roll"]:
		InputRouter.set_virtual_button(action, false)
	InputRouter.consume_jump()
	InputRouter.consume_attack()
	InputRouter.consume_roll()

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _land() -> void:
	await _frames(60)

func test_player_falls_and_settles_idle_on_the_floor() -> void:
	await _land()
	assert_bool(_player.is_on_floor()).is_true()
	assert_int(_player.state()).is_equal(State.IDLE)

func test_jump_input_lifts_the_player() -> void:
	await _land()
	var ground_y := _player.position.y
	InputRouter.set_virtual_button(&"jump", true)
	await _frames(10)
	assert_float(_player.position.y).is_less(ground_y - GameConfig.tiles(0.5))
	assert_int(_player.state()).is_equal(State.JUMP)

func test_roll_grants_iframes_then_ends() -> void:
	await _land()
	InputRouter.set_virtual_button(&"roll", true)
	await _frames(5)
	assert_int(_player.state()).is_equal(State.ROLL)
	assert_bool(_player.is_invincible()).is_true()
	InputRouter.set_virtual_button(&"roll", false)
	await _frames(30)
	assert_bool(_player.is_invincible()).is_false()
	assert_int(_player.state()).is_equal(State.IDLE)

func test_hit_outside_a_roll_staggers_and_costs_health() -> void:
	await _land()
	_player.take_hit(10, _player.global_position.x - 20.0)
	await _frames(2)
	assert_int(_player.state()).is_equal(State.HURT)
	assert_int(_player.get_node("Health").current).is_equal(90)

func test_hit_during_iframes_is_ignored() -> void:
	await _land()
	InputRouter.set_virtual_button(&"roll", true)
	await _frames(5)
	_player.take_hit(10, _player.global_position.x - 20.0)
	assert_int(_player.get_node("Health").current).is_equal(100)
	assert_int(_player.state()).is_equal(State.ROLL)

func test_player_starts_with_blade_in_slot_zero_and_spear_in_slot_one() -> void:
	assert_str(_player.weapon_in_slot(0).display_name).is_equal("Rusty Blade")
	assert_str(_player.weapon_in_slot(1).display_name).is_equal("Ember Spear")
	assert_int(_player.active_slot()).is_equal(0)

func test_swap_is_always_allowed_and_toggles_slots() -> void:
	_player.swap_weapons()
	assert_int(_player.active_slot()).is_equal(1)
	_player.swap_weapons()
	assert_int(_player.active_slot()).is_equal(0)

func test_swap_input_toggles_slots() -> void:
	await _land()
	Input.action_press("swap_weapon")
	await _frames(2)
	Input.action_release("swap_weapon")
	assert_int(_player.active_slot()).is_equal(1)

func test_attack_input_opens_the_equipped_weapons_hitbox_during_its_window() -> void:
	await _land()
	var weapon: Weapon = _player.get_node("Weapon")
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(2)
	assert_int(_player.state()).is_equal(State.ATTACK)
	assert_bool(weapon.is_hitbox_active()).is_false()
	await _frames(8)
	assert_bool(weapon.is_hitbox_active()).is_true()
	InputRouter.set_virtual_button(&"attack", false)

func test_swapping_mid_swing_leaves_no_live_hitbox() -> void:
	await _land()
	var weapon: Weapon = _player.get_node("Weapon")
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(10)
	InputRouter.set_virtual_button(&"attack", false)
	assert_bool(weapon.is_hitbox_active()).is_true()
	_player.swap_weapons()
	assert_bool(weapon.is_hitbox_active()).is_false()
