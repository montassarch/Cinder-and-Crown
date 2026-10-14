extends GdUnitTestSuite

const SCENE := "res://src/input/touch_controls.tscn"

var _controls: TouchControls

func before_test() -> void:
	_controls = load(SCENE).instantiate()
	_controls.force_visible = true
	add_child(_controls)

func after_test() -> void:
	_controls.queue_free()
	InputRouter.set_virtual_axis(0.0)
	for action in [&"attack", &"jump", &"roll", &"skill1", &"skill2"]:
		InputRouter.set_virtual_button(action, false)
		if action in [&"skill1", &"skill2"]:
			InputRouter.consume_skill(int(str(action).trim_prefix("skill")))
		else:
			InputRouter.call(&"consume_" + str(action))

## Where the screen actually is (headless runs have an odd-shaped window).
func _view() -> Vector2:
	return _controls.get_viewport().get_visible_rect().size

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	_controls._input(e)

func test_tapping_attack_button_buffers_an_attack() -> void:
	var center := _controls.button_center(&"attack", _view())
	_touch(0, center, true)
	assert_bool(InputRouter.attack_buffered()).is_true()

func test_stick_right_of_center_moves_right_and_release_stops() -> void:
	var center := _controls.stick_center(_view())
	_touch(1, center + Vector2(GameConfig.tiles(2.0), 0.0), true)
	assert_float(InputRouter.move_axis()).is_greater(0.5)
	_touch(1, center, false)
	assert_float(InputRouter.move_axis()).is_equal(0.0)

func test_stick_and_button_work_with_two_fingers_at_once() -> void:
	var stick := _controls.stick_center(_view())
	var jump := _controls.button_center(&"jump", _view())
	_touch(0, stick - Vector2(GameConfig.tiles(2.0), 0.0), true)
	_touch(1, jump, true)
	assert_float(InputRouter.move_axis()).is_less(-0.5)
	assert_bool(InputRouter.jump_held()).is_true()

func test_release_all_lets_go_of_every_finger() -> void:
	var stick := _controls.stick_center(_view())
	var jump := _controls.button_center(&"jump", _view())
	_touch(0, stick + Vector2(GameConfig.tiles(2.0), 0.0), true)
	_touch(1, jump, true)
	_controls.release_all()
	assert_float(InputRouter.move_axis()).is_equal(0.0)
	assert_bool(InputRouter.jump_held()).is_false()

func test_touch_above_the_stick_zone_does_not_grab_the_stick() -> void:
	_touch(0, GameConfig.tiles_v(3.5, 2.0), true)
	_touch(0, GameConfig.tiles_v(3.5, 2.0), false)
	assert_float(InputRouter.move_axis()).is_equal(0.0)
	var stick_start := Vector2(_controls.stick_center(_view()).x + GameConfig.tiles(2.0), GameConfig.tiles(2.0))
	_touch(2, stick_start, true)
	assert_float(InputRouter.move_axis()).is_equal(0.0)

func test_tapping_the_swap_button_requests_a_weapon_swap() -> void:
	var center := _controls.button_center(&"swap_weapon", _view())
	_touch(0, center, true)
	assert_bool(InputRouter.swap_weapon_pressed()).is_true()

func test_tapping_the_ability_buttons_buffers_the_matching_skill() -> void:
	_touch(0, _controls.button_center(&"skill1", _view()), true)
	assert_bool(InputRouter.skill_buffered(1)).is_true()
	assert_bool(InputRouter.skill_buffered(2)).is_false()
	_touch(1, _controls.button_center(&"skill2", _view()), true)
	assert_bool(InputRouter.skill_buffered(2)).is_true()

func test_no_two_touch_buttons_overlap() -> void:
	var names: Array = _controls.BUTTON_CENTERS_TILES.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var gap: float = _controls.BUTTON_CENTERS_TILES[names[i]].distance_to(_controls.BUTTON_CENTERS_TILES[names[j]])
			assert_float(gap).is_greater(2.0 * _controls.BUTTON_RADIUS_TILES)

func test_buttons_hug_the_right_edge_and_bottom_of_a_wide_screen() -> void:
	# iPhone landscape is ~19.5:9, so the view widens past 384 px; buttons must follow the edge.
	var wide := Vector2(468.0, 216.0)
	var attack: Vector2 = _controls.button_center(&"attack", wide)
	var base_attack := GameConfig.tiles_v(TouchControls.BUTTON_CENTERS_TILES[&"attack"].x, TouchControls.BUTTON_CENTERS_TILES[&"attack"].y)
	assert_float(wide.x - attack.x).is_equal_approx(GameConfig.BASE_WIDTH - base_attack.x, 0.001)
	assert_float(attack.y).is_equal_approx(base_attack.y, 0.001)

func test_stick_stays_at_the_left_and_follows_the_bottom_of_a_tall_screen() -> void:
	var tall := Vector2(384.0, 260.0)
	var stick: Vector2 = _controls.stick_center(tall)
	var base_stick := GameConfig.tiles_v(TouchControls.STICK_CENTER_TILES.x, TouchControls.STICK_CENTER_TILES.y)
	assert_float(stick.x).is_equal_approx(base_stick.x, 0.001)
	assert_float(tall.y - stick.y).is_equal_approx(GameConfig.BASE_HEIGHT - base_stick.y, 0.001)
