extends GdUnitTestSuite
## Double jump and air dash with the real player scene.

const State := PlayerStateMachine.PlayerState

var _player: Player
var _floor: StaticBody2D


func before_test() -> void:
	_floor = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(80.0, 1.0)
	shape.shape = rect
	_floor.add_child(shape)
	_floor.position = GameConfig.tiles_v(0.0, 6.0)
	add_child(_floor)
	_player = load("res://src/player/player.tscn").instantiate()
	_player.position = GameConfig.tiles_v(0.0, 3.0)
	add_child(_player)


func after_test() -> void:
	_player.queue_free()
	for action in [&"jump", &"roll", &"attack"]:
		InputRouter.set_virtual_button(action, false)
	InputRouter.consume_jump()
	InputRouter.consume_roll()
	InputRouter.set_virtual_axis(0.0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	InputRouter.set_virtual_button(action, true)
	await _frames(1)
	InputRouter.set_virtual_button(action, false)
	await _frames(1)


func _hold(action: StringName, frames: int) -> void:
	InputRouter.set_virtual_button(action, true)
	await _frames(frames)
	InputRouter.set_virtual_button(action, false)
	await _frames(1)


func test_a_second_jump_in_the_air_lifts_the_hero_again_once() -> void:
	await _frames(60)
	var ground_y := _player.position.y
	var jumps := []
	_player.jumped.connect(func() -> void: jumps.append(true))
	await _hold(&"jump", 20)               # a full first jump
	await _frames(5)
	var peak_one := _player.position.y
	await _tap(&"jump")
	assert_int(_player.state()).is_equal(State.DOUBLE_JUMP)
	await _frames(15)
	assert_float(_player.position.y).is_less(peak_one - GameConfig.tiles(0.8))
	await _tap(&"jump")                    # no third jump
	assert_int(jumps.size()).is_equal(2)
	await _frames(90)
	assert_float(_player.position.y).is_equal_approx(ground_y, 1.0)
	await _hold(&"jump", 20)               # landing gives the double jump back
	await _frames(5)
	await _tap(&"jump")
	assert_int(jumps.size()).is_equal(4)


func test_an_air_dash_shoots_the_hero_forward_without_falling_and_only_once_per_jump() -> void:
	await _frames(60)
	var dashes := []
	_player.air_dashed.connect(func() -> void: dashes.append(true))
	await _hold(&"jump", 20)
	await _frames(2)
	var start := _player.position
	await _tap(&"roll")
	assert_int(_player.state()).is_equal(State.AIR_DASH)
	assert_bool(_player.is_invincible()).is_true()
	await _frames(int(PlayerStateMachine.AIR_DASH_DURATION * 60.0) - 3)
	assert_float(_player.position.x - start.x).is_greater(GameConfig.tiles(2.5))
	assert_float(absf(_player.position.y - start.y)).is_less(GameConfig.tiles(0.5))
	await _frames(10)
	await _tap(&"roll")
	assert_int(dashes.size()).is_equal(1)


func test_a_roll_on_the_ground_is_still_a_roll() -> void:
	await _frames(60)
	await _tap(&"roll")
	assert_int(_player.state()).is_equal(State.ROLL)
