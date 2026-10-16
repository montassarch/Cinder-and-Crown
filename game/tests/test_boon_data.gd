extends GdUnitTestSuite

const BOON_DIR := "res://data/boons"

func _all() -> Array[BoonData]:
	var boons: Array[BoonData] = []
	for path in DataScanner.list(BOON_DIR):
		var boon := load(path) as BoonData
		if boon != null:
			boons.append(boon)
	return boons

func test_a_dozen_boons_ship() -> void:
	assert_int(_all().size()).is_greater_equal(13)

func test_every_file_in_the_folder_is_a_boon() -> void:
	assert_int(_all().size()).is_equal(DataScanner.list(BOON_DIR).size())

func test_ids_are_unique_and_match_the_file_name() -> void:
	var seen := {}
	for path in DataScanner.list(BOON_DIR):
		var boon := load(path) as BoonData
		assert_str(boon.id).is_equal(path.get_file().get_basename())
		assert_bool(seen.has(boon.id)).is_false()
		seen[boon.id] = true

func test_every_boon_reads_well_and_does_something() -> void:
	for boon in _all():
		assert_str(boon.display_name).is_not_empty()
		assert_str(boon.description).is_not_empty()
		assert_float(boon.amount).is_greater(0.0)

func test_all_three_rarities_are_present() -> void:
	var rarities := {}
	for boon in _all():
		rarities[boon.rarity] = true
	assert_int(rarities.size()).is_equal(3)

func test_epic_boons_are_unique() -> void:
	for boon in _all():
		if boon.rarity == BoonData.Rarity.EPIC:
			assert_bool(boon.unique).is_true()

func test_every_effect_has_at_least_one_boon() -> void:
	var effects := {}
	for boon in _all():
		effects[boon.effect] = true
	assert_int(effects.size()).is_equal(BoonData.Effect.size())
