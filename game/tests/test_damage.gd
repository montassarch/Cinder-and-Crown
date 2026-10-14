extends GdUnitTestSuite

func test_applies_multiplier_then_subtracts_defense() -> void:
	assert_int(Damage.compute(10, 2.0, 5)).is_equal(15)

func test_rounds_down_fractional_damage() -> void:
	assert_int(Damage.compute(10, 1.55, 0)).is_equal(15)

func test_defense_exceeding_damage_clamps_to_zero() -> void:
	assert_int(Damage.compute(5, 1.0, 99)).is_equal(0)

func test_negative_base_never_heals() -> void:
	assert_int(Damage.compute(-10, 1.0, 0)).is_equal(0)

func test_zero_multiplier_deals_nothing() -> void:
	assert_int(Damage.compute(50, 0.0, 0)).is_equal(0)
