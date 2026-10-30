extends GdUnitTestSuite
## A generated level wears the art, weather and enemies of the world its depth is in.

const SCENE := "res://levels/generated_level.tscn"

var _level: GeneratedLevel


func before_test() -> void:
	_level = load(SCENE).instantiate()
	_level.level_seed = 7
	_level.room_count = 4
	_level.encounters_enabled = false
	add_child(_level)


func after_test() -> void:
	get_tree().paused = false
	_level.queue_free()


func _goto(depth: int) -> void:
	_level.set_depth(depth)
	_level.regenerate(_level.level_seed)


func test_a_new_run_starts_in_the_cathedral() -> void:
	assert_str(_level.biome().id).is_equal("cathedral")
	assert_str((_level.get_node("Backdrop") as Backdrop).biome().id).is_equal("cathedral")


func test_a_deeper_level_wears_its_worlds_backdrop() -> void:
	_goto(4)
	assert_str(_level.biome().id).is_equal("frost_ossuary")
	var backdrop := _level.get_node("Backdrop") as Backdrop
	assert_str(backdrop.biome().id).is_equal("frost_ossuary")
	for layer in backdrop.layers():
		assert_str((layer.get_node("Art") as Sprite2D).texture.resource_path).contains("frost_ossuary")


func test_the_backdrop_is_rebuilt_not_stacked() -> void:
	_goto(4)
	_goto(7)
	var backdrop := _level.get_node("Backdrop") as Backdrop
	assert_int(backdrop.layers().size()).is_equal(4)
	assert_int(backdrop.get_children().filter(func(n: Node) -> bool: return n is Parallax2D and not n.is_queued_for_deletion()).size()).is_equal(5)


func test_floors_and_ledges_wear_the_worlds_tiles() -> void:
	_goto(7)
	var ground := load(_level.biome().art_path("ground_tile"))
	var ledge := load(_level.biome().art_path("ledge_tile"))
	var floors := 0
	var ledges := 0
	for room in _level.get_node("Rooms").get_children():
		for body in room.get_children():
			if not (body is StaticBody2D):
				continue
			var visual := body.get_node("Visual")
			assert_object(visual).is_instanceof(TextureRect)
			var one_way: bool = (body.get_node("Shape") as CollisionShape2D).one_way_collision
			if one_way:
				ledges += 1
				assert_object((visual as TextureRect).texture).is_same(ledge)
			else:
				floors += 1
				assert_object((visual as TextureRect).texture).is_same(ground)
	assert_int(floors).is_greater(0)


func test_the_end_walls_wear_the_worlds_ground_tile() -> void:
	_goto(10)
	var ground := load(_level.biome().art_path("ground_tile"))
	for wall in _level.get_node("Walls").get_children():
		assert_object((wall.get_node("Visual") as TextureRect).texture).is_same(ground)


func test_the_waves_are_drawn_from_the_worlds_enemies() -> void:
	_goto(7)
	assert_array(_level.enemy_pool()).is_equal(_level.biome().enemies)


func test_the_weather_follows_the_world() -> void:
	_goto(10)
	var backdrop := _level.get_node("Backdrop") as Backdrop
	assert_int(backdrop.weather_kind()).is_equal(BiomeData.Weather.RAIN)
	assert_bool(backdrop.embers().emitting).is_true()


func test_entering_a_new_world_announces_it() -> void:
	_level.set_depth(2)
	_level._on_boon_chosen(load("res://data/boons/keen_edge.tres"))
	assert_str(_level.biome().id).is_equal("frost_ossuary")
	var hud := _level.get_node("Hud") as Hud
	assert_bool(hud.banner_visible()).is_true()
	assert_str(hud.banner_text()).contains(_level.biome().display_name)


func test_a_level_inside_the_same_world_is_not_announced_again() -> void:
	_level.set_depth(3)
	_level.regenerate(_level.level_seed)
	var hud := _level.get_node("Hud") as Hud
	hud.hide_banner()
	_level._on_boon_chosen(load("res://data/boons/keen_edge.tres"))
	assert_bool(hud.banner_visible()).is_false()


func test_choosing_a_world_in_the_menu_jumps_the_run_to_that_worlds_first_level() -> void:
	var menu := _level.get_node("Menu") as SandboxMenu
	menu.choose_world(3)
	assert_str(_level.biome().id).is_equal("storm_spire")
	assert_int(_level.depth()).is_equal(_level.biome().first_depth)
