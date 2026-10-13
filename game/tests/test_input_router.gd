class_name InputRouterTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# InputRouter is the single gate between the engine's input and gameplay.
# Nothing in src/player or src/weapons may call Input.* directly.
#
# Three seams exist on it -- time_provider, physical_axis_provider and
# physical_pressed_provider -- because Godot delivers no InputEvents in
# headless mode. Without them, neither the buffer timings nor Review
# Focus 2 (opposing multi-device input) could be tested at all.

const InputRouterScript := preload("res://src/input/input_router.gd")

var _now: float = 0.0
var _physical_axis: float = 0.0
var _physical_held: Dictionary = {}


func _make() -> Node:
	_now = 0.0
	_physical_axis = 0.0
	_physical_held = {}
	var router: Node = auto_free(InputRouterScript.new())
	router.time_provider = func() -> float: return _now
	router.physical_axis_provider = func() -> float: return _physical_axis
	router.physical_pressed_provider = func(action: StringName) -> bool:
		return _physical_held.get(action, false)
	return router


# --- axis ---

func test_virtual_axis_drives_move_axis() -> void:
	var router := _make()
	router.set_virtual_axis(1.0)
	assert_float(router.move_axis()).is_equal(1.0)


func test_physical_axis_drives_move_axis() -> void:
	var router := _make()
	_physical_axis = -1.0
	assert_float(router.move_axis()).is_equal(-1.0)


func test_opposing_virtual_and_physical_input_resolves_to_zero() -> void:
	# Review Focus 2. Physical says left, touch says right, same frame.
	# The documented rule is that they cancel -- and crucially that the
	# result is STABLE, not alternating between frames, which is what a
	# last-writer-wins implementation would produce.
	var router := _make()
	_physical_axis = -1.0
	router.set_virtual_axis(1.0)
	assert_float(router.move_axis()).is_equal(0.0)
	assert_float(router.move_axis()).is_equal(0.0)
	assert_float(router.move_axis()).is_equal(0.0)


func test_axis_is_clamped_to_unit_range() -> void:
	var router := _make()
	router.set_virtual_axis(5.0)
	assert_float(router.move_axis()).is_equal(1.0)
	router.set_virtual_axis(-5.0)
	assert_float(router.move_axis()).is_equal(-1.0)


func test_agreeing_sources_do_not_double_the_axis() -> void:
	# Holding right on the keyboard AND the touch stick must not move the
	# player at twice speed.
	var router := _make()
	_physical_axis = 1.0
	router.set_virtual_axis(1.0)
	assert_float(router.move_axis()).is_equal(1.0)


# --- buffers ---

func test_buffer_survives_shorter_than_buffer_seconds() -> void:
	var router := _make()
	router.press(&"jump")
	_now += router.BUFFER_SECONDS * 0.5
	assert_bool(router.jump_buffered()).is_true()


func test_jump_buffer_expires_after_buffer_seconds() -> void:
	# The point of the buffer is forgiveness, not a jump that fires half a
	# second after the player let go.
	var router := _make()
	router.press(&"jump")
	_now += router.BUFFER_SECONDS * 2.0
	assert_bool(router.jump_buffered()).is_false()


func test_consume_jump_clears_the_buffer() -> void:
	var router := _make()
	router.press(&"jump")
	assert_bool(router.jump_buffered()).is_true()
	router.consume_jump()
	assert_bool(router.jump_buffered()).is_false()


func test_attack_and_roll_buffer_independently() -> void:
	# Consuming one must not swallow the other, or a roll would eat a
	# queued attack.
	var router := _make()
	router.press(&"attack")
	router.press(&"roll")
	router.consume_roll()
	assert_bool(router.attack_buffered()).is_true()
	assert_bool(router.roll_buffered()).is_false()


func test_virtual_button_feeds_the_same_buffer_as_physical() -> void:
	# Touch is first-class per the spec: an on-screen button must be
	# indistinguishable from a key once it reaches gameplay.
	var router := _make()
	router.set_virtual_button(&"attack", true)
	assert_bool(router.attack_buffered()).is_true()


# --- held state ---

func test_jump_held_true_from_either_source() -> void:
	var router := _make()
	assert_bool(router.jump_held()).is_false()
	_physical_held[&"jump"] = true
	assert_bool(router.jump_held()).is_true()
	_physical_held[&"jump"] = false
	router.set_virtual_button(&"jump", true)
	assert_bool(router.jump_held()).is_true()


func test_releasing_virtual_button_clears_held_state() -> void:
	var router := _make()
	router.set_virtual_button(&"jump", true)
	router.set_virtual_button(&"jump", false)
	assert_bool(router.jump_held()).is_false()
