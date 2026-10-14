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
