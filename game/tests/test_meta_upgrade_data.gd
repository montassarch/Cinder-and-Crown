extends GdUnitTestSuite

const DIR := "res://data/meta"

func _all() -> Array[MetaUpgradeData]:
	var found: Array[MetaUpgradeData] = []
	for path in DataScanner.list(DIR):
		var u := load(path) as MetaUpgradeData
		if u != null:
			found.append(u)
	return found

func test_four_upgrades_ship() -> void:
	assert_int(_all().size()).is_greater_equal(4)

func test_ids_match_file_names_and_are_unique() -> void:
	var seen := {}
	for path in DataScanner.list(DIR):
		var u := load(path) as MetaUpgradeData
		assert_str(u.id).is_equal(path.get_file().get_basename())
		assert_bool(seen.has(u.id)).is_false()
		seen[u.id] = true

func test_every_upgrade_reads_well_and_has_a_price_ladder() -> void:
	for u in _all():
		assert_str(u.display_name).is_not_empty()
		assert_str(u.description).is_not_empty()
		assert_float(u.amount_per_rank).is_greater(0.0)
		assert_int(u.costs.size()).is_greater(0)
		for i in u.costs.size():
			assert_int(u.costs[i]).is_greater(0)
			if i > 0:
				assert_int(u.costs[i]).is_greater(u.costs[i - 1])

func test_the_enemies_pay_cells() -> void:
	for path in DataScanner.list("res://data/enemies"):
		assert_int((load(path) as EnemyData).cell_reward).is_greater(0)
	assert_int((load("res://data/enemies/crown_brute.tres") as EnemyData).cell_reward).is_greater((load("res://data/enemies/shambler.tres") as EnemyData).cell_reward)
