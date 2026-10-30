extends GdUnitTestSuite
## Each world ends in a boss level: spawn room, boss arena, exit. The boss appears as the hero walks in, a bar shows
## its health, the exit stays shut until it falls; beating the last world's boss wins the run.

const SCENE := "res://levels/generated_level.tscn"

var _level: GeneratedLevel


func before_test() -> void:
	_level = load(SCENE).instantiate()
	_level.level_seed = 5
	add_child(_level)


func after_test() -> void:
	get_tree().paused = false
	_level.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _goto(depth: int) -> void:
	_level.set_depth(depth)
	_level.regenerate(_level.level_seed)


func _arena_start_x() -> float:
	var x := 0.0
	for room in _level.layout():
		if room.kind == RoomData.Kind.BOSS:
			return x
		x += room.size_tiles.x
	return -1.0


## The boss is looked for in _process, which can lag several physics steps behind after a level build.
func _walk_into_arena() -> void:
	_level.player.global_position.x = GameConfig.tiles(_arena_start_x() + 6.0)
	await _frames(3)
	await get_tree().process_frame
	await get_tree().process_frame


func _boss() -> Enemy:
	for child in _level.get_children():
		if child is Enemy and child.data.boss:
			return child
	return null


func test_every_world_has_a_boss_on_its_last_level() -> void:
	for biome in BiomeData.load_all():
		assert_object(biome.boss).override_failure_message(biome.id).is_not_null()
		assert_bool(biome.boss.boss).is_true()
		assert_int(biome.boss_depth()).is_equal(biome.first_depth + biome.levels - 1)
		for move in biome.boss.moves + biome.boss.phase_two_moves:
			assert_bool(move.is_valid()).override_failure_message("%s %s" % [biome.boss.display_name, move.id]).is_true()
		assert_bool(biome.boss.phase_two_moves.is_empty()).is_false()


func test_the_next_world_starts_right_after_the_boss_level() -> void:
	var biomes := BiomeData.load_all()
	for i in range(1, biomes.size()):
		assert_int(biomes[i].first_depth).is_equal(biomes[i - 1].boss_depth() + 1)


func test_a_boss_level_is_spawn_arena_exit() -> void:
	_goto(2)
	assert_bool(_level.is_boss_level()).is_true()
	var kinds := _level.layout().map(func(r: RoomData) -> int: return r.kind)
	assert_array(kinds).is_equal([RoomData.Kind.SPAWN, RoomData.Kind.BOSS, RoomData.Kind.EXIT])


func test_ordinary_levels_have_no_arena() -> void:
	_goto(1)
	assert_bool(_level.is_boss_level()).is_false()
	for room in _level.layout():
		assert_int(room.kind).is_not_equal(RoomData.Kind.BOSS)


func test_the_boss_appears_when_the_hero_walks_into_the_arena() -> void:
	_goto(5)
	assert_object(_boss()).is_null()
	await _walk_into_arena()
	var boss := _boss()
	assert_object(boss).is_not_null()
	assert_str(boss.data.display_name).is_equal(_level.biome().boss.display_name)
	await _walk_into_arena()
	var count := _level.get_children().filter(func(n: Node) -> bool: return n is Enemy and n.data.boss).size()
	assert_int(count).is_equal(1)


func test_a_bar_shows_the_bosses_name_and_health() -> void:
	_goto(8)
	await _walk_into_arena()
	var hud := _level.get_node("Hud") as Hud
	var boss := _boss()
	assert_bool(hud.boss_visible()).is_true()
	assert_str(hud.boss_name()).is_equal(boss.data.display_name)
	assert_float(hud.boss_fraction()).is_equal(1.0)
	boss.take_hit(boss.health().max_health / 4, 0.0)
	assert_float(hud.boss_fraction()).is_less(0.8)


func test_the_exit_stays_shut_until_the_boss_falls_then_the_flask_is_refilled() -> void:
	_goto(2)
	await _walk_into_arena()
	var boss := _boss()
	_level.player.set_flask_charges(0)
	assert_object(_level.exit_gate_color()).is_equal(GeneratedLevel.GATE_SHUT_COLOR)
	boss.take_hit(100000, 0.0)
	await _frames(40)
	await get_tree().process_frame
	assert_object(_level.exit_gate_color()).is_not_equal(GeneratedLevel.GATE_SHUT_COLOR)
	assert_int(_level.player.flask_charges()).is_equal(_level.player.flask_max())
	assert_bool((_level.get_node("Hud") as Hud).boss_visible()).is_false()


func test_beating_the_last_worlds_boss_wins_the_run() -> void:
	var won := []
	_level.run_won.connect(func() -> void: won.append(true))
	_goto(11)
	await _walk_into_arena()
	_boss().take_hit(100000, 0.0)
	await _frames(5)
	assert_int(won.size()).is_equal(1)
	assert_str((_level.get_node("Hud") as Hud).banner_text()).contains("VICTORY")


func test_beating_an_earlier_boss_does_not_win_the_run() -> void:
	var won := []
	_level.run_won.connect(func() -> void: won.append(true))
	_goto(5)
	await _walk_into_arena()
	_boss().take_hit(100000, 0.0)
	await _frames(5)
	assert_int(won.size()).is_equal(0)


func test_the_exit_is_shut_even_before_the_boss_appears() -> void:
	_goto(5)
	await _frames(2)
	await get_tree().process_frame
	assert_object(_boss()).is_null()
	assert_object(_level.exit_gate_color()).is_equal(GeneratedLevel.GATE_SHUT_COLOR)


func test_zz_every_boss_has_its_art() -> void:
	for biome in BiomeData.load_all():
		assert_bool(EnemyVisual.has_art(biome.boss.art)).override_failure_message(biome.boss.art).is_true()


func test_the_bosses_summons_crumble_when_it_falls() -> void:
	_goto(2)
	await _walk_into_arena()
	var boss := _boss()
	var minion := _level.spawn_enemy_at(load("res://data/enemies/shambler.tres"), boss.global_position + Vector2(40, 0))
	boss.take_hit(100000, 0.0)
	assert_bool(minion.is_dead()).is_true()
	await _frames(40)
	await get_tree().process_frame
	assert_int(_level.enemy_count()).is_equal(0)
	assert_int(_level.get_children().filter(func(n: Node) -> bool: return n is Enemy and n.data.boss and not n.is_queued_for_deletion()).size()).is_equal(0)
