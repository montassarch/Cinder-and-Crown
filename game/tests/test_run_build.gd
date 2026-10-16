extends GdUnitTestSuite

func _boon(id: String, effect: BoonData.Effect, amount: float, rarity: BoonData.Rarity = BoonData.Rarity.COMMON, unique: bool = false) -> BoonData:
	var b := BoonData.new()
	b.id = id
	b.display_name = id.capitalize()
	b.description = "test"
	b.effect = effect
	b.amount = amount
	b.rarity = rarity
	b.unique = unique
	return b

func _pool() -> Array[BoonData]:
	var pool: Array[BoonData] = []
	for i in 6:
		pool.append(_boon("c%d" % i, BoonData.Effect.DAMAGE, 0.1))
	pool.append(_boon("r0", BoonData.Effect.SPEED, 0.2, BoonData.Rarity.RARE))
	pool.append(_boon("e0", BoonData.Effect.LIFESTEAL, 2.0, BoonData.Rarity.EPIC, true))
	return pool

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_a_fresh_build_changes_nothing() -> void:
	var build := RunBuild.new()
	assert_float(build.damage_multiplier()).is_equal(1.0)
	assert_float(build.speed_multiplier()).is_equal(1.0)
	assert_float(build.mana_gain_multiplier()).is_equal(1.0)
	assert_int(build.lifesteal()).is_equal(0)
	assert_int(build.bonus_max_health()).is_equal(0)

func test_damage_boons_stack_additively() -> void:
	var build := RunBuild.new()
	build.apply(_boon("a", BoonData.Effect.DAMAGE, 0.15))
	build.apply(_boon("b", BoonData.Effect.DAMAGE, 0.30))
	assert_float(build.damage_multiplier()).is_equal_approx(1.45, 0.0001)

func test_each_effect_feeds_its_own_stat() -> void:
	var build := RunBuild.new()
	build.apply(_boon("s", BoonData.Effect.SPEED, 0.1))
	build.apply(_boon("m", BoonData.Effect.MANA_GAIN, 0.5))
	build.apply(_boon("l", BoonData.Effect.LIFESTEAL, 2.0))
	build.apply(_boon("h", BoonData.Effect.MAX_HEALTH, 20.0))
	assert_float(build.speed_multiplier()).is_equal_approx(1.1, 0.0001)
	assert_float(build.mana_gain_multiplier()).is_equal_approx(1.5, 0.0001)
	assert_int(build.lifesteal()).is_equal(2)
	assert_int(build.bonus_max_health()).is_equal(20)
	assert_float(build.damage_multiplier()).is_equal(1.0)

func test_heal_boons_change_no_stat() -> void:
	var build := RunBuild.new()
	build.apply(_boon("heal", BoonData.Effect.HEAL, 30.0))
	assert_float(build.damage_multiplier()).is_equal(1.0)
	assert_int(build.bonus_max_health()).is_equal(0)

func test_taken_boons_are_counted_and_cleared() -> void:
	var build := RunBuild.new()
	var b := _boon("a", BoonData.Effect.DAMAGE, 0.1)
	build.apply(b)
	build.apply(b)
	assert_int(build.times_taken("a")).is_equal(2)
	build.clear()
	assert_int(build.times_taken("a")).is_equal(0)
	assert_float(build.damage_multiplier()).is_equal(1.0)

func test_offers_have_the_requested_number_of_distinct_boons() -> void:
	var build := RunBuild.new()
	var offers := build.roll_offers(_pool(), 3, _rng(1))
	assert_int(offers.size()).is_equal(3)
	var ids := offers.map(func(b: BoonData) -> String: return b.id)
	assert_int(ids.size()).is_equal(3)
	assert_array(ids).contains_exactly_in_any_order(ids.duplicate())
	assert_int(Dictionary(ids.reduce(func(acc: Dictionary, id: String) -> Dictionary:
		acc[id] = true
		return acc, {})).size()).is_equal(3)

func test_a_small_pool_offers_what_it_has() -> void:
	var build := RunBuild.new()
	var pool: Array[BoonData] = [_boon("only", BoonData.Effect.DAMAGE, 0.1)]
	assert_int(build.roll_offers(pool, 3, _rng(1)).size()).is_equal(1)
	assert_int(build.roll_offers([] as Array[BoonData], 3, _rng(1)).size()).is_equal(0)

func test_the_same_seed_rolls_the_same_offers() -> void:
	var a := RunBuild.new().roll_offers(_pool(), 3, _rng(42)).map(func(b: BoonData) -> String: return b.id)
	var b := RunBuild.new().roll_offers(_pool(), 3, _rng(42)).map(func(b2: BoonData) -> String: return b2.id)
	assert_array(a).is_equal(b)

func test_a_unique_boon_that_was_taken_is_never_offered_again() -> void:
	var build := RunBuild.new()
	var pool := _pool()
	build.apply(pool[7])  # the unique epic
	for seed_value in 40:
		for offer in build.roll_offers(pool, 3, _rng(seed_value)):
			assert_str(offer.id).is_not_equal("e0")

func test_a_non_unique_boon_can_be_offered_after_taking_it() -> void:
	var build := RunBuild.new()
	var pool := _pool()
	build.apply(pool[0])
	var seen := false
	for seed_value in 60:
		for offer in build.roll_offers(pool, 3, _rng(seed_value)):
			seen = seen or offer.id == "c0"
	assert_bool(seen).is_true()

func test_rarity_weights_make_commons_the_most_frequent() -> void:
	var counts := {BoonData.Rarity.COMMON: 0, BoonData.Rarity.RARE: 0, BoonData.Rarity.EPIC: 0}
	var pool: Array[BoonData] = [
		_boon("c", BoonData.Effect.DAMAGE, 0.1),
		_boon("r", BoonData.Effect.SPEED, 0.1, BoonData.Rarity.RARE),
		_boon("e", BoonData.Effect.SPEED, 0.1, BoonData.Rarity.EPIC),
	]
	var rng := _rng(7)
	for i in 600:
		var build := RunBuild.new()
		counts[build.roll_offers(pool, 1, rng)[0].rarity] += 1
	assert_int(counts[BoonData.Rarity.COMMON]).is_greater(counts[BoonData.Rarity.RARE])
	assert_int(counts[BoonData.Rarity.RARE]).is_greater(counts[BoonData.Rarity.EPIC])

func test_a_boon_offered_before_is_less_likely_next_time() -> void:
	var pool: Array[BoonData] = [
		_boon("a", BoonData.Effect.DAMAGE, 0.1),
		_boon("b", BoonData.Effect.DAMAGE, 0.1),
	]
	var rng := _rng(3)
	var picked_a := 0
	for i in 400:
		var build := RunBuild.new()
		build.roll_offers([pool[0]] as Array[BoonData], 1, _rng(i))  # "a" has now been shown once
		if build.roll_offers(pool, 1, rng)[0].id == "a":
			picked_a += 1
	assert_int(picked_a).is_less(160)  # 50% without the penalty, 1/(1+1.5) = 40% share with it

func test_flask_boons_add_charges() -> void:
	var build := RunBuild.new()
	assert_int(build.bonus_flask_charges()).is_equal(0)
	build.apply(_boon("f", BoonData.Effect.FLASK_CHARGE, 1.0))
	assert_int(build.bonus_flask_charges()).is_equal(1)
	build.clear()
	assert_int(build.bonus_flask_charges()).is_equal(0)
