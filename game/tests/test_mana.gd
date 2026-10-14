extends GdUnitTestSuite

func _mana(max_value: float = 100.0, regen: float = 2.0) -> Mana:
	var mana: Mana = auto_free(Mana.new())
	mana.max_mana = max_value
	mana.regen_per_second = regen
	mana.refill()
	return mana

func test_starts_full_after_refill() -> void:
	assert_float(_mana().current).is_equal(100.0)

func test_spending_what_you_have_succeeds_and_lowers_mana() -> void:
	var mana := _mana()
	assert_bool(mana.spend(40.0)).is_true()
	assert_float(mana.current).is_equal(60.0)

func test_spending_more_than_you_have_fails_and_changes_nothing() -> void:
	var mana := _mana()
	mana.spend(80.0)
	assert_bool(mana.spend(30.0)).is_false()
	assert_float(mana.current).is_equal(20.0)

func test_gain_never_exceeds_max() -> void:
	var mana := _mana()
	mana.spend(10.0)
	mana.gain(50.0)
	assert_float(mana.current).is_equal(100.0)

func test_regenerates_over_time() -> void:
	var mana := _mana()
	mana.spend(50.0)
	mana.advance(2.5)
	assert_float(mana.current).is_equal_approx(55.0, 0.001)

func test_mana_changed_reports_current_and_max() -> void:
	var mana := _mana()
	var seen := []
	mana.mana_changed.connect(func(cur: float, mx: float) -> void: seen.append([cur, mx]))
	mana.spend(40.0)
	assert_array(seen).is_equal([[60.0, 100.0]])

func test_can_afford() -> void:
	var mana := _mana()
	mana.spend(75.0)
	assert_bool(mana.can_afford(25.0)).is_true()
	assert_bool(mana.can_afford(26.0)).is_false()
