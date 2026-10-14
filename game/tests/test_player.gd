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
