extends GdUnitTestSuite

const SCENE := "res://src/input/touch_controls.tscn"

var _controls: CanvasLayer

func before_test() -> void:
	_controls = load(SCENE).instantiate()
	_controls.force_visible = true
	add_child(_controls)

func after_test() -> void:
	_controls.queue_free()
	InputRouter.set_virtual_axis(0.0)
	for action in [&"attack", &"jump", &"roll"]:
		InputRouter.set_virtual_button(action, false)
		InputRouter.call(&"consume_" + str(action))

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	_controls._input(e)

func test_tapping_attack_button_buffers_an_attack() -> void:
	var center := GameConfig.tiles_v(_controls.BUTTON_CENTERS_TILES[&"attack"].x, _controls.BUTTON_CENTERS_TILES[&"attack"].y)
	_touch(0, center, true)
	assert_bool(InputRouter.attack_buffered()).is_true()

func test_stick_right_of_center_moves_right_and_release_stops() -> void:
	var center := GameConfig.tiles_v(_controls.STICK_CENTER_TILES.x, _controls.STICK_CENTER_TILES.y)
	_touch(1, center + Vector2(GameConfig.tiles(2.0), 0.0), true)
	assert_float(InputRouter.move_axis()).is_greater(0.5)
	_touch(1, center, false)
	assert_float(InputRouter.move_axis()).is_equal(0.0)

func test_stick_and_button_work_with_two_fingers_at_once() -> void:
	var stick := GameConfig.tiles_v(_controls.STICK_CENTER_TILES.x, _controls.STICK_CENTER_TILES.y)
	var jump := GameConfig.tiles_v(_controls.BUTTON_CENTERS_TILES[&"jump"].x, _controls.BUTTON_CENTERS_TILES[&"jump"].y)
	_touch(0, stick - Vector2(GameConfig.tiles(2.0), 0.0), true)
	_touch(1, jump, true)
	assert_float(InputRouter.move_axis()).is_less(-0.5)
	assert_bool(InputRouter.jump_held()).is_true()

func test_release_all_lets_go_of_every_finger() -> void:
	var stick := GameConfig.tiles_v(_controls.STICK_CENTER_TILES.x, _controls.STICK_CENTER_TILES.y)
	var jump := GameConfig.tiles_v(_controls.BUTTON_CENTERS_TILES[&"jump"].x, _controls.BUTTON_CENTERS_TILES[&"jump"].y)
	_touch(0, stick + Vector2(GameConfig.tiles(2.0), 0.0), true)
	_touch(1, jump, true)
	_controls.release_all()
	assert_float(InputRouter.move_axis()).is_equal(0.0)
	assert_bool(InputRouter.jump_held()).is_false()

func test_touch_above_the_stick_zone_does_not_grab_the_stick() -> void:
	_touch(0, GameConfig.tiles_v(3.5, 2.0), true)
	_touch(0, GameConfig.tiles_v(3.5, 2.0), false)
	assert_float(InputRouter.move_axis()).is_equal(0.0)
	var stick_start := GameConfig.tiles_v(_controls.STICK_CENTER_TILES.x + 2.0, 2.0)
	_touch(2, stick_start, true)
	assert_float(InputRouter.move_axis()).is_equal(0.0)

func test_tapping_the_swap_button_requests_a_weapon_swap() -> void:
	var center := GameConfig.tiles_v(_controls.BUTTON_CENTERS_TILES[&"swap_weapon"].x, _controls.BUTTON_CENTERS_TILES[&"swap_weapon"].y)
	_touch(0, center, true)
	assert_bool(InputRouter.swap_weapon_pressed()).is_true()

func test_no_two_touch_buttons_overlap() -> void:
	var names: Array = _controls.BUTTON_CENTERS_TILES.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var gap: float = _controls.BUTTON_CENTERS_TILES[names[i]].distance_to(_controls.BUTTON_CENTERS_TILES[names[j]])
			assert_float(gap).is_greater(2.0 * _controls.BUTTON_RADIUS_TILES)
