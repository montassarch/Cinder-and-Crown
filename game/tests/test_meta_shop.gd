extends GdUnitTestSuite

const TEST_PATH := "user://test_meta_shop.json"

var _shop: MetaShop
var _starts: Array = []

func _upgrade(id: String, costs: Array[int]) -> MetaUpgradeData:
	var u := MetaUpgradeData.new()
	u.id = id
	u.display_name = id.capitalize()
	u.description = "Does %s." % id
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
	_starts.clear()
	_shop = auto_free(MetaShop.new())
	add_child(_shop)
	_shop.start_requested.connect(func() -> void: _starts.append(true))

func after_test() -> void:
	get_tree().paused = false
	_wipe()
	MetaSave.path = MetaSave.DEFAULT_PATH

func _two() -> Array[MetaUpgradeData]:
	return [_upgrade("soul", [5, 12] as Array[int]), _upgrade("edge", [8] as Array[int])]

func test_it_starts_closed() -> void:
	assert_bool(_shop.is_open()).is_false()

func test_opening_lists_every_upgrade_with_its_price() -> void:
	MetaSave.add_cells(20)
	_shop.open(_two(), 4)
	assert_bool(_shop.is_open()).is_true()
	assert_int(_shop.row_count()).is_equal(2)
	assert_str(_shop.row_text(0)).contains("Soul")
	assert_str(_shop.row_text(0)).contains("5")
	assert_str(_shop.row_text(1)).contains("Edge")

func test_it_shows_the_cells_earned_this_run_and_the_bank() -> void:
	MetaSave.add_cells(12)
	_shop.open(_two(), 4)
	assert_str(_shop.cells_text()).contains("12")
	assert_str(_shop.run_text()).contains("4")

func test_buying_spends_cells_and_raises_the_rank() -> void:
	MetaSave.add_cells(20)
	_shop.open(_two(), 0)
	_shop.press_buy(0)
	assert_int(MetaSave.cells()).is_equal(15)
	assert_int(MetaSave.rank("soul")).is_equal(1)
	assert_str(_shop.cells_text()).contains("15")
	assert_str(_shop.row_text(0)).contains("12")  # the next rank's price

func test_an_unaffordable_upgrade_cannot_be_bought() -> void:
	MetaSave.add_cells(3)
	_shop.open(_two(), 0)
	assert_bool(_shop.buy_enabled(0)).is_false()
	_shop.press_buy(0)
	assert_int(MetaSave.cells()).is_equal(3)
	assert_int(MetaSave.rank("soul")).is_equal(0)

func test_a_maxed_upgrade_says_so_and_cannot_be_bought() -> void:
	MetaSave.add_cells(50)
	_shop.open(_two(), 0)
	_shop.press_buy(1)
	assert_str(_shop.row_text(1)).contains("MAX")
	assert_bool(_shop.buy_enabled(1)).is_false()

func test_buttons_light_up_as_cells_allow() -> void:
	MetaSave.add_cells(5)
	_shop.open(_two(), 0)
	assert_bool(_shop.buy_enabled(0)).is_true()
	assert_bool(_shop.buy_enabled(1)).is_false()  # costs 8

func test_pressing_start_closes_it_and_asks_for_a_new_run() -> void:
	_shop.open(_two(), 0)
	_shop.press_start()
	assert_bool(_shop.is_open()).is_false()
	assert_array(_starts).is_equal([true])

func test_start_only_counts_once_per_visit() -> void:
	_shop.open(_two(), 0)
	_shop.press_start()
	_shop.press_start()
	assert_int(_starts.size()).is_equal(1)
