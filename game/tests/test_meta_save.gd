extends GdUnitTestSuite
## Cells and upgrade ranks kept between runs. Every test points the save at a scratch file.

const TEST_PATH := "user://test_meta_save.json"

func _upgrade(id: String = "ember_soul", costs: Array[int] = [5, 12, 22]) -> MetaUpgradeData:
	var u := MetaUpgradeData.new()
	u.id = id
	u.display_name = id.capitalize()
	u.description = "test"
	u.effect = BoonData.Effect.MAX_HEALTH
	u.amount_per_rank = 10.0
	u.costs = costs
	return u

func _wipe() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(TEST_PATH + suffix):
			DirAccess.remove_absolute(TEST_PATH + suffix)

func before_test() -> void:
	_wipe()
	MetaSave.path = TEST_PATH

func after_test() -> void:
	_wipe()
	MetaSave.path = MetaSave.DEFAULT_PATH

func test_a_fresh_save_is_empty() -> void:
	assert_int(MetaSave.cells()).is_equal(0)
	assert_int(MetaSave.rank("ember_soul")).is_equal(0)

func test_cells_add_up_and_survive_a_reload() -> void:
	MetaSave.add_cells(3)
	MetaSave.add_cells(4)
	assert_int(MetaSave.cells()).is_equal(7)
	MetaSave.path = TEST_PATH  # drops the in-memory copy, forcing a read from disk
	assert_int(MetaSave.cells()).is_equal(7)

func test_adding_nothing_or_less_changes_nothing() -> void:
	MetaSave.add_cells(5)
	MetaSave.add_cells(0)
	MetaSave.add_cells(-3)
	assert_int(MetaSave.cells()).is_equal(5)

func test_next_cost_follows_the_rank_and_ends_at_max() -> void:
	var u := _upgrade()
	assert_int(MetaSave.next_cost(u)).is_equal(5)
	MetaSave.add_cells(100)
	MetaSave.buy(u)
	assert_int(MetaSave.next_cost(u)).is_equal(12)
	MetaSave.buy(u)
	MetaSave.buy(u)
	assert_int(MetaSave.next_cost(u)).is_equal(-1)

func test_buying_spends_the_cost_and_raises_the_rank() -> void:
	var u := _upgrade()
	MetaSave.add_cells(8)
	assert_bool(MetaSave.buy(u)).is_true()
	assert_int(MetaSave.cells()).is_equal(3)
	assert_int(MetaSave.rank(u.id)).is_equal(1)

func test_buying_without_enough_cells_changes_nothing() -> void:
	var u := _upgrade()
	MetaSave.add_cells(4)
	assert_bool(MetaSave.can_afford(u)).is_false()
	assert_bool(MetaSave.buy(u)).is_false()
	assert_int(MetaSave.cells()).is_equal(4)
	assert_int(MetaSave.rank(u.id)).is_equal(0)

func test_a_maxed_upgrade_cannot_be_bought_again() -> void:
	var u := _upgrade("ember_soul", [1, 1] as Array[int])
	MetaSave.add_cells(50)
	MetaSave.buy(u)
	MetaSave.buy(u)
	assert_bool(MetaSave.buy(u)).is_false()
	assert_int(MetaSave.rank(u.id)).is_equal(2)
	assert_int(MetaSave.cells()).is_equal(48)

func test_ranks_survive_a_reload() -> void:
	var u := _upgrade()
	MetaSave.add_cells(30)
	MetaSave.buy(u)
	MetaSave.buy(u)
	MetaSave.path = TEST_PATH
	assert_int(MetaSave.rank(u.id)).is_equal(2)
	assert_int(MetaSave.cells()).is_equal(30 - 5 - 12)

func test_a_damaged_file_falls_back_to_an_empty_save() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	MetaSave.path = TEST_PATH
	assert_int(MetaSave.cells()).is_equal(0)
	MetaSave.add_cells(2)
	assert_int(MetaSave.cells()).is_equal(2)

func test_a_save_with_odd_types_is_cleaned_up() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string('{"cells": "many", "ranks": [1, 2]}')
	f.close()
	MetaSave.path = TEST_PATH
	assert_int(MetaSave.cells()).is_equal(0)
	assert_int(MetaSave.rank("ember_soul")).is_equal(0)

func test_owned_ranks_become_run_bonuses() -> void:
	var a := _upgrade("ember_soul")
	var b := _upgrade("sharpened")
	b.effect = BoonData.Effect.DAMAGE
	b.amount_per_rank = 0.06
	MetaSave.add_cells(100)
	MetaSave.buy(a)
	MetaSave.buy(a)
	var bonuses := MetaSave.bonus_boons([a, b] as Array[MetaUpgradeData])
	assert_int(bonuses.size()).is_equal(1)  # the unbought upgrade adds nothing
	assert_int(bonuses[0].effect).is_equal(BoonData.Effect.MAX_HEALTH)
	assert_float(bonuses[0].amount).is_equal_approx(20.0, 0.001)
