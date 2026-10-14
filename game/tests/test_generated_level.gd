extends GdUnitTestSuite

const SCENE := "res://levels/generated_level.tscn"

var _level: GeneratedLevel

func before_test() -> void:
	_level = load(SCENE).instantiate()
	_level.level_seed = 7
	_level.room_count = 5
	add_child(_level)

func after_test() -> void:
	get_tree().paused = false
	_level.queue_free()
	InputRouter.set_virtual_axis(0.0)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func test_builds_the_requested_rooms_end_to_end() -> void:
	var layout := _level.layout()
	assert_int(layout.size()).is_equal(5)
	var width := 0
	for room in layout:
		width += room.size_tiles.x
	assert_float(_level.arena_width_tiles()).is_equal(float(width))
	assert_int(_level.get_node("Rooms").get_child_count()).is_equal(5)

func test_layout_starts_at_spawn_and_ends_at_exit() -> void:
	var layout := _level.layout()
	assert_int(layout[0].kind).is_equal(RoomData.Kind.SPAWN)
	assert_int(layout[layout.size() - 1].kind).is_equal(RoomData.Kind.EXIT)

func test_player_starts_in_the_spawn_room() -> void:
	var first_width := GameConfig.tiles(_level.layout()[0].size_tiles.x)
	assert_float(_level.spawn_point().x).is_less(first_width)
	assert_vector(_level.player.global_position).is_equal(_level.spawn_point())

func test_same_seed_builds_the_same_level() -> void:
	var other: GeneratedLevel = auto_free(load(SCENE).instantiate())
	other.level_seed = 7
	other.room_count = 5
	add_child(other)
	var mine := []
	var theirs := []
	for room in _level.layout():
		mine.append(room.resource_path)
	for room in other.layout():
		theirs.append(room.resource_path)
	assert_array(mine).is_equal(theirs)

func test_player_can_walk_out_of_the_spawn_room_along_the_floor() -> void:
	await _frames(40)
	InputRouter.set_virtual_axis(1.0)
	await _frames(190)
	var first_width := GameConfig.tiles(_level.layout()[0].size_tiles.x)
	assert_float(_level.player.global_position.x).is_greater(first_width)
	assert_bool(_level.player.is_on_floor()).is_true()

func test_reaching_the_exit_builds_the_next_level_and_resets_the_player() -> void:
	var before := _level.level_seed
	_level.player.global_position = Vector2(999.0, 0.0)
	_level._on_exit_entered(_level.player)
	assert_int(_level.level_seed).is_equal(before + 1)
	assert_vector(_level.player.global_position).is_equal(_level.spawn_point())
	assert_int(_level.layout().size()).is_equal(5)

func test_something_other_than_the_player_entering_the_exit_does_nothing() -> void:
	var before := _level.level_seed
	var stranger: Node2D = auto_free(Node2D.new())
	_level._on_exit_entered(stranger)
	assert_int(_level.level_seed).is_equal(before)

func test_regenerate_replaces_the_rooms_instead_of_stacking_them() -> void:
	_level.regenerate(8)
	await _frames(2)
	assert_int(_level.get_node("Rooms").get_child_count()).is_equal(5)

func test_the_menu_offers_a_way_back_to_the_sandbox() -> void:
	var menu: SandboxMenu = _level.get_node("Menu")
	assert_str(menu.scene_switch_target()).is_equal("res://levels/sandbox.tscn")

func test_regenerate_also_replaces_the_boundary_walls() -> void:
	_level.regenerate(8)
	await _frames(2)
	assert_int(_level.get_node("Walls").get_child_count()).is_equal(2)
