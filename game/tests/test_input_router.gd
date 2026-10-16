extends GdUnitTestSuite

const ROUTER_SCRIPT := "res://src/input/input_router.gd"

func _make_router() -> Node:
	return auto_free(load(ROUTER_SCRIPT).new())

func after_test() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")

func test_virtual_axis_drives_move_axis() -> void:
	var router := _make_router()
	router.set_virtual_axis(0.5)
	assert_float(router.move_axis()).is_equal(0.5)

func test_opposing_virtual_and_physical_input_resolves_to_zero() -> void:
	# Documented rule: opposing inputs cancel; they never jitter.
	var router := _make_router()
	Input.action_press("move_left")
	router.set_virtual_axis(1.0)
	for i in 5:
		assert_float(router.move_axis()).is_equal(0.0)

func test_axis_is_clamped_to_unit_range() -> void:
	var router := _make_router()
	router.set_virtual_axis(5.0)
	assert_float(router.move_axis()).is_equal(1.0)
	router.set_virtual_axis(-5.0)
	assert_float(router.move_axis()).is_equal(-1.0)

func test_jump_buffer_expires_after_buffer_seconds() -> void:
	var router := _make_router()
	router.set_virtual_button(&"jump", true)
	assert_bool(router.jump_buffered()).is_true()
	await await_millis(int(router.BUFFER_SECONDS * 1000.0) + 80)
	assert_bool(router.jump_buffered()).is_false()

func test_consume_jump_clears_the_buffer() -> void:
	var router := _make_router()
	router.set_virtual_button(&"jump", true)
	router.consume_jump()
	assert_bool(router.jump_buffered()).is_false()

func test_buffer_survives_shorter_than_buffer_seconds() -> void:
	var router := _make_router()
	router.set_virtual_button(&"jump", true)
	await await_millis(30)
	assert_bool(router.jump_buffered()).is_true()

func test_virtual_jump_held_follows_press_and_release() -> void:
	var router := _make_router()
	router.set_virtual_button(&"jump", true)
	assert_bool(router.jump_held()).is_true()
	router.set_virtual_button(&"jump", false)
	assert_bool(router.jump_held()).is_false()

func test_virtual_swap_reads_true_exactly_once() -> void:
	# The player polls once per physics frame; a tap must not swap twice.
	var router := _make_router()
	router.set_virtual_button(&"swap_weapon", true)
	assert_bool(router.swap_weapon_pressed()).is_true()
	assert_bool(router.swap_weapon_pressed()).is_false()

func test_holding_the_virtual_swap_button_does_not_repeat() -> void:
	var router := _make_router()
	router.set_virtual_button(&"swap_weapon", true)
	router.swap_weapon_pressed()
	router.set_virtual_button(&"swap_weapon", true)
	assert_bool(router.swap_weapon_pressed()).is_true()
	router.set_virtual_button(&"swap_weapon", false)
	assert_bool(router.swap_weapon_pressed()).is_false()

func test_virtual_skill_buttons_buffer_and_consume() -> void:
	var router := _make_router()
	router.set_virtual_button(&"skill1", true)
	router.set_virtual_button(&"skill2", true)
	assert_bool(router.skill_buffered(1)).is_true()
	assert_bool(router.skill_buffered(2)).is_true()
	router.consume_skill(1)
	assert_bool(router.skill_buffered(1)).is_false()
	assert_bool(router.skill_buffered(2)).is_true()

func test_virtual_parry_buffers_and_consumes() -> void:
	var router := _make_router()
	router.set_virtual_button(&"parry", true)
	assert_bool(router.parry_buffered()).is_true()
	router.consume_parry()
	assert_bool(router.parry_buffered()).is_false()

func test_a_parry_press_expires_after_the_buffer_window() -> void:
	var router := _make_router()
	router.set_virtual_button(&"parry", true)
	assert_bool(router.parry_buffered()).is_true()
	await await_millis(int(router.BUFFER_SECONDS * 1000.0) + 80)
	assert_bool(router.parry_buffered()).is_false()

func test_the_parry_action_exists_with_a_key_and_a_pad_button() -> void:
	assert_bool(InputMap.has_action(&"parry")).is_true()
	var kinds := InputMap.action_get_events(&"parry").map(func(e: InputEvent) -> bool: return e is InputEventKey)
	assert_bool(kinds.has(true)).is_true()
	var pads := InputMap.action_get_events(&"parry").map(func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	assert_bool(pads.has(true)).is_true()

func test_virtual_flask_buffers_and_consumes() -> void:
	var router := _make_router()
	router.set_virtual_button(&"flask", true)
	assert_bool(router.flask_buffered()).is_true()
	router.consume_flask()
	assert_bool(router.flask_buffered()).is_false()

func test_the_flask_action_exists_with_a_key_and_a_pad_button() -> void:
	assert_bool(InputMap.has_action(&"flask")).is_true()
	assert_bool(InputMap.action_get_events(&"flask").any(func(e: InputEvent) -> bool: return e is InputEventKey)).is_true()
	assert_bool(InputMap.action_get_events(&"flask").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton)).is_true()
