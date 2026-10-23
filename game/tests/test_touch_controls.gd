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

func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	_controls._input(e)

func _player() -> Player:
	var player: Player = auto_free(load("res://src/player/player.tscn").instantiate())
	add_child(player)
	return player

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func test_tapping_attack_button_buffers_an_attack() -> void:
	var center := _controls.button_center(&"attack", _view())
	_touch(0, center, true)
	assert_bool(InputRouter.attack_buffered()).is_true()

func test_stick_right_of_where_it_landed_moves_right_and_release_stops() -> void:
	var center := _controls.stick_center(_view())
	_touch(1, center, true)
	_drag(1, center + Vector2(GameConfig.tiles(2.0), 0.0))
	assert_float(InputRouter.move_axis()).is_greater(0.5)
	_touch(1, center, false)
	assert_float(InputRouter.move_axis()).is_equal(0.0)

func test_stick_and_button_work_with_two_fingers_at_once() -> void:
	var stick := _controls.stick_center(_view())
	var jump := _controls.button_center(&"jump", _view())
	_touch(0, stick, true)
	_drag(0, stick - Vector2(GameConfig.tiles(2.0), 0.0))
	_touch(1, jump, true)
	assert_float(InputRouter.move_axis()).is_less(-0.5)
	assert_bool(InputRouter.jump_held()).is_true()

func test_release_all_lets_go_of_every_finger() -> void:
	var stick := _controls.stick_center(_view())
	var jump := _controls.button_center(&"jump", _view())
	_touch(0, stick, true)
	_drag(0, stick + Vector2(GameConfig.tiles(2.0), 0.0))
	_touch(1, jump, true)
	_controls.release_all()
	assert_float(InputRouter.move_axis()).is_equal(0.0)
	assert_bool(InputRouter.jump_held()).is_false()

func test_the_stick_appears_where_the_thumb_lands() -> void:
	var view := _view()
	var landing := Vector2(GameConfig.tiles(5.0), view.y - GameConfig.tiles(4.0))
	_touch(1, landing, true)
	assert_vector(_controls.stick_origin()).is_equal_approx(landing, Vector2(0.01, 0.01))
	assert_float(InputRouter.move_axis()).is_equal(0.0)   # no push yet, wherever it landed
	_drag(1, landing + Vector2(GameConfig.tiles(TouchControls.STICK_RADIUS_TILES) * 0.6, 0.0))
	assert_float(InputRouter.move_axis()).is_equal_approx(0.6, 0.02)
	_touch(1, landing, false)
	assert_vector(_controls.stick_origin()).is_equal_approx(_controls.stick_center(view), Vector2(0.01, 0.01))

func test_the_stick_ring_stays_fully_on_screen() -> void:
	var view := _view()
	_touch(1, Vector2(1.0, view.y - 1.0), true)
	var origin: Vector2 = _controls.stick_origin()
	var radius := GameConfig.tiles(TouchControls.STICK_RADIUS_TILES)
	assert_float(origin.x - radius).is_greater_equal(0.0)
	assert_float(origin.y + radius).is_less_equal(view.y)

func test_a_second_finger_on_the_left_does_not_steal_the_stick() -> void:
	var view := _view()
	var first := Vector2(GameConfig.tiles(4.0), view.y - GameConfig.tiles(4.0))
	_touch(1, first, true)
	_drag(1, first + Vector2(GameConfig.tiles(2.0), 0.0))
	_touch(2, Vector2(GameConfig.tiles(2.0), view.y - GameConfig.tiles(3.0)), true)
	assert_vector(_controls.stick_origin()).is_equal_approx(first, Vector2(0.01, 0.01))
	assert_float(InputRouter.move_axis()).is_greater(0.5)

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
			var radii: float = _controls.BUTTON_RADII_TILES[names[i]] + _controls.BUTTON_RADII_TILES[names[j]]
			assert_float(gap).is_greater(radii + 0.2)

func test_the_attack_button_is_the_biggest() -> void:
	for action in TouchControls.BUTTON_RADII_TILES:
		if action != &"attack":
			assert_float(TouchControls.BUTTON_RADII_TILES[&"attack"]).is_greater(TouchControls.BUTTON_RADII_TILES[action])

func test_the_buttons_sit_on_two_arcs_round_the_attack_button() -> void:
	var attack: Vector2 = TouchControls.BUTTON_CENTERS_TILES[&"attack"]
	for action in [&"roll", &"parry", &"jump"]:
		assert_float(attack.distance_to(TouchControls.BUTTON_CENTERS_TILES[action])).is_equal_approx(TouchControls.INNER_ARC_TILES, 0.1)
	for action in [&"skill1", &"skill2", &"flask", &"swap_weapon"]:
		assert_float(attack.distance_to(TouchControls.BUTTON_CENTERS_TILES[action])).is_equal_approx(TouchControls.OUTER_ARC_TILES, 0.1)

func test_every_button_is_fully_on_the_base_screen() -> void:
	for action in TouchControls.BUTTON_CENTERS_TILES:
		var c: Vector2 = TouchControls.BUTTON_CENTERS_TILES[action]
		var r: float = TouchControls.BUTTON_RADII_TILES[action]
		assert_float(c.x - r).is_greater_equal(0.0)
		assert_float(c.x + r).is_less_equal(GameConfig.BASE_WIDTH / float(GameConfig.TILE_SIZE))
		assert_float(c.y - r).is_greater_equal(0.0)
		assert_float(c.y + r).is_less_equal(GameConfig.BASE_HEIGHT / float(GameConfig.TILE_SIZE))

func test_a_touch_only_counts_inside_the_button_itself() -> void:
	var view := _view()
	var centre := _controls.button_center(&"swap_weapon", view)
	var radius := GameConfig.tiles(TouchControls.BUTTON_RADII_TILES[&"swap_weapon"])
	_touch(0, centre + Vector2(radius + GameConfig.tiles(0.1), 0.0), true)
	assert_bool(InputRouter.swap_weapon_pressed()).is_false()
	_touch(0, centre + Vector2(radius - GameConfig.tiles(0.1), 0.0), true)
	assert_bool(InputRouter.swap_weapon_pressed()).is_true()

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

func test_tapping_parry_buffers_a_parry() -> void:
	_touch(0, _controls.button_center(&"parry", _view()), true)
	assert_bool(InputRouter.parry_buffered()).is_true()
	_touch(0, _controls.button_center(&"parry", _view()), false)
	InputRouter.consume_parry()

func test_tapping_flask_buffers_a_drink() -> void:
	_touch(0, _controls.button_center(&"flask", _view()), true)
	assert_bool(InputRouter.flask_buffered()).is_true()
	_touch(0, _controls.button_center(&"flask", _view()), false)
	InputRouter.consume_flask()

# --- Wild Rift style feedback: buttons dim when they cannot be used, shrink when pressed ---

func test_ability_buttons_dim_and_fill_with_the_mana_they_have() -> void:
	var player := _player()
	_controls.bind(player)
	player.mana().current = player.mana().max_mana
	await _frames(2)
	assert_bool(_controls.button_enabled(&"skill1")).is_true()
	assert_float(_controls.button_fill(&"skill1")).is_equal(1.0)
	player.mana().current = 10.0
	await _frames(2)
	assert_bool(_controls.button_enabled(&"skill1")).is_false()
	assert_float(_controls.button_fill(&"skill1")).is_equal_approx(10.0 / Player.STORM_COST, 0.05)
	assert_float(_controls.button_fill(&"skill2")).is_equal_approx(10.0 / Player.REND_COST, 0.05)

func test_the_flask_button_dims_when_the_flask_is_empty() -> void:
	var player := _player()
	_controls.bind(player)
	await _frames(2)
	assert_bool(_controls.button_enabled(&"flask")).is_true()
	player._flask = 0
	await _frames(2)
	assert_bool(_controls.button_enabled(&"flask")).is_false()

func test_a_dimmed_button_still_sends_its_press_so_the_game_can_say_no() -> void:
	var player := _player()
	_controls.bind(player)
	player.mana().current = 0.0
	await _frames(2)
	_touch(0, _controls.button_center(&"skill1", _view()), true)
	assert_bool(InputRouter.skill_buffered(1)).is_true()

func test_a_pressed_button_shrinks_a_little() -> void:
	assert_float(_controls.button_scale(&"attack")).is_equal(1.0)
	_touch(0, _controls.button_center(&"attack", _view()), true)
	assert_float(_controls.button_scale(&"attack")).is_less(1.0)
	_touch(0, _controls.button_center(&"attack", _view()), false)
	assert_float(_controls.button_scale(&"attack")).is_equal(1.0)

func test_the_overlay_redraws_only_when_something_changed() -> void:
	var player := _player()
	_controls.bind(player)
	player.mana().current = player.mana().max_mana
	await _frames(3)
	var before: int = _controls.redraw_count
	await _frames(10)
	assert_int(_controls.redraw_count).is_equal(before)
