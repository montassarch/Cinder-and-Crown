class_name ControlsHelpTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# The controls list is built from InputMap at runtime, not hand-written.
# A hardcoded table drifts the first time a binding changes and then lies
# to the player, which is worse than showing nothing. These tests pin that
# it stays sourced from the real bindings.

const Help := preload("res://src/ui/controls_help.gd")


func test_every_listed_action_actually_exists() -> void:
	for entry: Array in Help.ACTIONS:
		assert_bool(InputMap.has_action(entry[0])).override_failure_message(
			"the controls list advertises '%s', which is not in InputMap" % entry[0]
		).is_true()


func test_every_listed_action_has_a_binding() -> void:
	# An action in the list with no key would render as "unbound" to the
	# player -- a list that tells you a move exists but not how to do it.
	for entry: Array in Help.ACTIONS:
		assert_str(Help.bindings_for(entry[0])).override_failure_message(
			"'%s' is listed with no binding" % entry[0]
		).is_not_equal("unbound")


func test_every_gameplay_action_is_documented() -> void:
	# The other direction: a move the player can perform but cannot look up.
	var listed := {}
	for entry: Array in Help.ACTIONS:
		listed[entry[0]] = true
	for action: StringName in [
		&"move_left", &"move_right", &"jump", &"attack", &"roll", &"swap_weapon",
	]:
		assert_bool(listed.has(action)).override_failure_message(
			"'%s' is playable but missing from the controls list" % action
		).is_true()


func test_every_entry_has_a_description() -> void:
	for entry: Array in Help.ACTIONS:
		assert_str(entry[1]).is_not_empty()


func test_bindings_are_human_readable_not_numbers() -> void:
	# "Pad 0" means nothing to a player; the keyboard key must be a name.
	var jump := Help.bindings_for(&"jump")
	assert_str(jump).contains("Space")
	assert_str(Help.bindings_for(&"move_left")).contains("A")


func test_unknown_action_reports_unbound_rather_than_erroring() -> void:
	assert_str(Help.bindings_for(&"no_such_action")).is_equal("unbound")


func test_help_panel_is_visible_on_launch() -> void:
	# A player who has never seen the game should not have to guess which
	# key reveals the key list.
	var help: CanvasLayer = auto_free(
		(load("res://src/ui/controls_help.tscn") as PackedScene).instantiate()
	)
	add_child(help)
	await get_tree().process_frame
	assert_bool((help.get_node("%Panel") as Control).visible).is_true()


func test_toggle_hides_and_shows_the_panel() -> void:
	var help: CanvasLayer = auto_free(
		(load("res://src/ui/controls_help.tscn") as PackedScene).instantiate()
	)
	add_child(help)
	await get_tree().process_frame
	var panel := help.get_node("%Panel") as Control
	help.toggle()
	assert_bool(panel.visible).is_false()
	help.toggle()
	assert_bool(panel.visible).is_true()


func test_panel_lists_one_row_per_action() -> void:
	var help: CanvasLayer = auto_free(
		(load("res://src/ui/controls_help.tscn") as PackedScene).instantiate()
	)
	add_child(help)
	await get_tree().process_frame
	var grid := help.get_node("%Grid") as GridContainer
	# Two columns per action: the keys, and what they do.
	assert_int(grid.get_child_count()).is_equal(Help.ACTIONS.size() * 2)
