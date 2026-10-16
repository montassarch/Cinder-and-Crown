extends GdUnitTestSuite
## Generated levels spawn a wave when the hero enters each middle room, and the exit
## stays shut until every enemy is dead.

const SCENE := "res://levels/generated_level.tscn"

var _level: GeneratedLevel

func before_test() -> void:
	_use_scratch_save()
	_level = load(SCENE).instantiate()
	_level.level_seed = 7
	_level.room_count = 5
	add_child(_level)

func after_test() -> void:
	get_tree().paused = false
	MetaSave.path = MetaSave.DEFAULT_PATH
	_level.queue_free()
	InputRouter.set_virtual_axis(0.0)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

## Left edge of room `index` of the layout, in tiles.
func _room_start(index: int) -> float:
	var x := 0.0
	for i in index:
		x += _level.layout()[i].size_tiles.x
	return x

func _enter_room(index: int) -> void:
	_level.player.global_position = GameConfig.tiles_v(_room_start(index) + 4.0, 10.0)
	await _frames(3)

func _enemies() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for child in _level.get_children():
		if child is Enemy and not child.is_dead():
			found.append(child)
	return found

func _kill_all() -> void:
	for enemy in _enemies():
		enemy.take_hit(9999, enemy.global_position.x - 10.0)

func _stand_on_exit() -> void:
	var rooms := _level.get_node("Rooms").get_children()
	_level.player.global_position = (rooms[rooms.size() - 1].get_node("ExitZone") as Area2D).global_position

func test_only_the_middle_rooms_have_encounters() -> void:
	assert_int(_level.encounter_room_count()).is_equal(3)

func test_no_enemies_while_the_hero_stays_in_the_spawn_room() -> void:
	await _frames(20)
	assert_int(_enemies().size()).is_equal(0)

func test_entering_a_middle_room_spawns_a_wave() -> void:
	await _enter_room(1)
	assert_int(_enemies().size()).is_greater_equal(1)

func test_the_wave_stands_inside_the_room_that_was_entered() -> void:
	await _enter_room(1)
	var left := GameConfig.tiles(_room_start(1))
	var right := GameConfig.tiles(_room_start(2))
	for enemy in _enemies():
		assert_float(enemy.global_position.x).is_between(left, right)

func test_a_room_spawns_its_wave_only_once() -> void:
	await _enter_room(1)
	var first := _enemies().size()
	await _enter_room(0)
	await _enter_room(1)
	assert_int(_enemies().size()).is_equal(first)

func test_each_middle_room_has_its_own_wave() -> void:
	await _enter_room(1)
	var after_one := _enemies().size()
	await _enter_room(2)
	assert_int(_enemies().size()).is_greater(after_one)

func test_the_first_level_only_brings_the_lightest_enemy() -> void:
	await _enter_room(1)
	await _enter_room(2)
	await _enter_room(3)
	for enemy in _enemies():
		assert_str(enemy.data.display_name).is_equal("Shambler")

func test_deeper_levels_bring_heavier_enemies() -> void:
	_level.set_depth(4)
	var seen := {}
	for index in [1, 2, 3]:
		await _enter_room(index)
	for enemy in _enemies():
		seen[enemy.data.display_name] = true
	assert_int(seen.size()).is_greater(1)

func test_the_same_seed_and_depth_spawn_the_same_waves() -> void:
	await _enter_room(2)
	var mine := _enemies().map(func(e: Enemy) -> String: return e.data.display_name)
	var other: GeneratedLevel = auto_free(load(SCENE).instantiate())
	other.level_seed = 7
	other.room_count = 5
	add_child(other)
	other.player.global_position = GameConfig.tiles_v(_room_start(2) + 4.0, 10.0)
	await _frames(3)
	var theirs: Array = []
	for child in other.get_children():
		if child is Enemy:
			theirs.append(child.data.display_name)
	assert_array(theirs).is_equal(mine)

# --- The exit stays shut until the level is cleared ---

func test_the_exit_is_shut_while_enemies_live() -> void:
	await _enter_room(1)
	_stand_on_exit()
	_level._on_exit_entered(_level.player)
	assert_bool((_level.get_node("BoonPicker") as BoonPicker).is_open()).is_false()

func test_the_exit_opens_once_every_enemy_is_dead() -> void:
	await _enter_room(1)
	_kill_all()
	_stand_on_exit()
	_level._on_exit_entered(_level.player)
	assert_bool((_level.get_node("BoonPicker") as BoonPicker).is_open()).is_true()

func test_the_exit_gate_looks_shut_or_open() -> void:
	await _enter_room(1)
	await _frames(2)
	var shut: Color = _level.exit_gate_color()
	_kill_all()
	await _frames(2)
	assert_object(_level.exit_gate_color()).is_not_equal(shut)

# --- Depth ---

func test_depth_starts_at_zero_and_grows_with_each_chosen_boon() -> void:
	assert_int(_level.depth()).is_equal(0)
	_stand_on_exit()
	_level._on_exit_entered(_level.player)
	(_level.get_node("BoonPicker") as BoonPicker).choose(0)
	assert_int(_level.depth()).is_equal(1)

func test_a_new_run_goes_back_to_depth_zero() -> void:
	_level.set_depth(3)
	_level.reset_player()
	assert_int(_level.depth()).is_equal(0)

func test_the_next_level_has_fresh_encounters() -> void:
	await _enter_room(1)
	_kill_all()
	_stand_on_exit()
	_level._on_exit_entered(_level.player)
	(_level.get_node("BoonPicker") as BoonPicker).choose(0)
	await _frames(3)
	assert_int(_enemies().size()).is_equal(0)
	await _enter_room(1)
	assert_int(_enemies().size()).is_greater_equal(1)

# --- Health and the flask carry between levels ---

func test_the_next_level_keeps_the_heros_health_and_gives_back_a_flask_charge() -> void:
	_level.player.get_node("Health").take_damage(45)
	_level.player.set_flask_charges(1)
	_level._on_boon_chosen(load("res://data/boons/whetstone.tres"))
	assert_int(_level.player.get_node("Health").current).is_equal(55)
	assert_int(_level.player.flask_charges()).is_equal(2)

func test_dying_starts_a_new_run_with_full_health_and_flask() -> void:
	_level.player.get_node("Health").take_damage(80)
	_level.player.set_flask_charges(0)
	_level.reset_player()
	assert_int(_level.player.get_node("Health").current).is_equal(100)
	assert_int(_level.player.flask_charges()).is_equal(Player.FLASK_BASE_CHARGES)

# --- Cells and the shop ---

const SAVE_PATH := "user://test_level_meta.json"

func _use_scratch_save() -> void:
	MetaSave.path = SAVE_PATH
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(SAVE_PATH + suffix)
	MetaSave.path = SAVE_PATH

func test_killing_an_enemy_banks_its_cells() -> void:
	_use_scratch_save()
	await _enter_room(1)
	var before := MetaSave.cells()
	var enemy := _enemies()[0]
	var reward := enemy.data.cell_reward
	enemy.take_hit(9999, enemy.global_position.x - 10.0)
	assert_int(MetaSave.cells() - before).is_equal(reward)
	assert_int(_level.cells_this_run()).is_equal(reward)
	MetaSave.path = MetaSave.DEFAULT_PATH

func test_dying_opens_the_shop_instead_of_respawning_at_once() -> void:
	_use_scratch_save()
	var shop: MetaShop = _level.get_node("MetaShop")
	_level.player.take_hit(9999, _level.player.global_position.x - 10.0)
	await _frames(3)
	assert_bool(shop.is_open()).is_true()
	MetaSave.path = MetaSave.DEFAULT_PATH

func test_starting_from_the_shop_begins_a_new_run() -> void:
	_use_scratch_save()
	var shop: MetaShop = _level.get_node("MetaShop")
	_level.set_depth(3)
	_level.player.take_hit(9999, _level.player.global_position.x - 10.0)
	await _frames(3)
	shop.press_start()
	assert_int(_level.depth()).is_equal(0)
	assert_bool(_level.player.get_node("Health").is_alive()).is_true()
	assert_int(_level.cells_this_run()).is_equal(0)
	MetaSave.path = MetaSave.DEFAULT_PATH

func test_upgrades_bought_in_the_shop_apply_to_the_next_run() -> void:
	_use_scratch_save()
	MetaSave.add_cells(100)
	var soul: MetaUpgradeData = load("res://data/meta/ember_soul.tres")
	MetaSave.buy(soul)
	_level.player.take_hit(9999, _level.player.global_position.x - 10.0)
	await _frames(3)
	(_level.get_node("MetaShop") as MetaShop).press_start()
	assert_int(_level.player.get_node("Health").max_health).is_equal(100 + int(soul.amount_per_rank))
	MetaSave.path = MetaSave.DEFAULT_PATH

func test_the_hud_shows_the_banked_cells() -> void:
	_use_scratch_save()
	MetaSave.add_cells(9)
	await _frames(3)
	assert_str((_level.get_node("Hud") as Hud).cells_text()).contains("9")
	MetaSave.path = MetaSave.DEFAULT_PATH
