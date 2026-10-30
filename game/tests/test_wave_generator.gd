extends GdUnitTestSuite

func _enemy(name: String, threat: int, unlock: int = 0, max_per_wave: int = 3) -> EnemyData:
	var d := EnemyData.new()
	d.display_name = name
	d.threat = threat
	d.unlock_depth = unlock
	d.max_per_wave = max_per_wave
	return d

func _pool() -> Array[EnemyData]:
	return [_enemy("Grunt", 2, 0, 4), _enemy("Bat", 3, 1, 2), _enemy("Brute", 5, 2, 1)]

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _names(wave: Array[EnemyData]) -> Array:
	return wave.map(func(e: EnemyData) -> String: return e.display_name)

func _threat(wave: Array[EnemyData]) -> int:
	var total := 0
	for e in wave:
		total += e.threat
	return total

func test_the_budget_grows_with_depth() -> void:
	assert_int(WaveGenerator.budget_for(1)).is_greater(WaveGenerator.budget_for(0))
	assert_int(WaveGenerator.budget_for(5)).is_greater(WaveGenerator.budget_for(1))

func test_the_same_seed_rolls_the_same_wave() -> void:
	assert_array(_names(WaveGenerator.roll(_pool(), 3, _rng(11)))).is_equal(_names(WaveGenerator.roll(_pool(), 3, _rng(11))))

func test_a_wave_never_spends_more_than_its_budget() -> void:
	for seed_value in 50:
		for depth in 6:
			assert_int(_threat(WaveGenerator.roll(_pool(), depth, _rng(seed_value)))).is_less_equal(WaveGenerator.budget_for(depth))

func test_a_wave_is_never_empty_when_something_can_spawn() -> void:
	var pool: Array[EnemyData] = [_enemy("Costly", 99)]
	assert_int(WaveGenerator.roll(pool, 0, _rng(1)).size()).is_equal(1)

func test_an_empty_pool_rolls_an_empty_wave() -> void:
	assert_int(WaveGenerator.roll([] as Array[EnemyData], 3, _rng(1)).size()).is_equal(0)

func test_enemies_do_not_appear_before_their_unlock_depth() -> void:
	for seed_value in 40:
		assert_array(_names(WaveGenerator.roll(_pool(), 0, _rng(seed_value)))).not_contains(["Bat"])
		assert_array(_names(WaveGenerator.roll(_pool(), 1, _rng(seed_value)))).not_contains(["Brute"])

func test_deeper_waves_do_bring_in_the_heavier_enemies() -> void:
	var seen := {}
	for seed_value in 60:
		for name in _names(WaveGenerator.roll(_pool(), 6, _rng(seed_value))):
			seen[name] = true
	assert_bool(seen.has("Brute")).is_true()
	assert_bool(seen.has("Bat")).is_true()

func test_no_wave_has_more_of_a_kind_than_its_limit() -> void:
	for seed_value in 60:
		var names := _names(WaveGenerator.roll(_pool(), 8, _rng(seed_value)))
		assert_int(names.count("Brute")).is_less_equal(1)
		assert_int(names.count("Bat")).is_less_equal(2)
		assert_int(names.count("Grunt")).is_less_equal(4)

func test_a_wave_is_capped_in_size() -> void:
	var pool: Array[EnemyData] = [_enemy("Rat", 1, 0, 99)]
	assert_int(WaveGenerator.roll(pool, 20, _rng(1)).size()).is_equal(WaveGenerator.MAX_WAVE_SIZE)

func test_deeper_waves_have_more_threat_on_average() -> void:
	var shallow := 0
	var deep := 0
	for seed_value in 80:
		shallow += _threat(WaveGenerator.roll(_pool(), 0, _rng(seed_value)))
		deep += _threat(WaveGenerator.roll(_pool(), 5, _rng(seed_value)))
	assert_int(deep).is_greater(shallow)

func test_shipped_enemies_unlock_in_order_light_to_heavy() -> void:
	var shambler: EnemyData = load("res://data/enemies/shambler.tres")
	var bat: EnemyData = load("res://data/enemies/cinder_bat.tres")
	var brute: EnemyData = load("res://data/enemies/crown_brute.tres")
	assert_int(shambler.unlock_depth).is_equal(0)
	assert_int(bat.unlock_depth).is_greater(shambler.unlock_depth - 1)
	assert_int(brute.unlock_depth).is_greater(bat.unlock_depth - 1)
	assert_int(brute.threat).is_greater(shambler.threat)
	assert_int(brute.max_per_wave).is_equal(1)

# --- The full shipped roster ---

func _roster() -> Array[EnemyData]:
	var pool: Array[EnemyData] = []
	for path in DataScanner.list("res://data/enemies"):
		pool.append(load(path) as EnemyData)
	return pool

func _unlock(file: String) -> int:
	return (load("res://data/enemies/%s.tres" % file) as EnemyData).unlock_depth

func test_every_shipped_enemy_unlocks_in_the_spec_order() -> void:
	assert_int(_unlock("shambler")).is_equal(0)
	assert_int(_unlock("crown_guard")).is_equal(1)
	assert_int(_unlock("cinder_bat")).is_equal(1)
	assert_int(_unlock("ember_wisp")).is_equal(2)
	assert_int(_unlock("powder_pilgrim")).is_equal(3)
	assert_int(_unlock("penitent")).is_equal(3)
	assert_int(_unlock("crown_brute")).is_equal(4)

func test_no_wave_at_any_depth_exceeds_its_budget_with_the_full_roster() -> void:
	var pool := _roster()
	assert_int(pool.size()).is_equal(DataScanner.list("res://data/enemies").size())
	for depth in 13:
		for seed_value in 40:
			var wave := WaveGenerator.roll(pool, depth, _rng(seed_value))
			assert_int(wave.size()).is_between(1, WaveGenerator.MAX_WAVE_SIZE)
			assert_int(_threat(wave)).is_less_equal(WaveGenerator.budget_for(depth))
			for enemy in pool:
				assert_int(wave.count(enemy)).is_less_equal(enemy.max_per_wave)

func test_the_heaviest_enemies_never_appear_before_their_depth() -> void:
	var pool := _roster()
	for seed_value in 60:
		for enemy in WaveGenerator.roll(pool, 0, _rng(seed_value)):
			assert_str(enemy.display_name).is_equal("Shambler")
		for enemy in WaveGenerator.roll(pool, 3, _rng(seed_value)):
			assert_str(enemy.display_name).is_not_equal("Crown Brute")
