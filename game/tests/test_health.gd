extends GdUnitTestSuite

func _make_health(max_hp: int) -> Health:
	var health: Health = auto_free(Health.new())
	health.max_health = max_hp
	add_child(health)
	return health

func test_take_damage_reduces_current() -> void:
	var health := _make_health(100)
	var absorbed := health.take_damage(30)
	assert_int(health.current).is_equal(70)
	assert_int(absorbed).is_equal(30)

func test_overkill_reports_only_absorbed_damage() -> void:
	var health := _make_health(10)
	var absorbed := health.take_damage(999)
	assert_int(health.current).is_equal(0)
	assert_int(absorbed).is_equal(10)

func test_death_emits_died_once() -> void:
	var health := _make_health(10)
	var deaths := [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	health.take_damage(10)
	health.take_damage(10)
	assert_int(deaths[0]).is_equal(1)

func test_damage_after_death_absorbs_nothing() -> void:
	var health := _make_health(10)
	health.take_damage(10)
	assert_int(health.take_damage(5)).is_equal(0)
	assert_int(health.current).is_equal(0)
	assert_bool(health.is_alive()).is_false()

func test_heal_cannot_exceed_max() -> void:
	var health := _make_health(100)
	health.take_damage(10)
	health.heal(50)
	assert_int(health.current).is_equal(100)

func test_health_changed_carries_current_and_max() -> void:
	var health := _make_health(100)
	var seen := []
	health.health_changed.connect(func(cur: int, mx: int) -> void: seen.append([cur, mx]))
	health.take_damage(25)
	assert_array(seen).is_equal([[75, 100]])

func test_negative_damage_never_heals() -> void:
	var health := _make_health(100)
	health.take_damage(40)
	var absorbed := health.take_damage(-30)
	assert_int(absorbed).is_equal(0)
	assert_int(health.current).is_equal(60)

func test_setup_sets_max_and_fills_current() -> void:
	var health := _make_health(100)
	health.take_damage(60)
	var seen := []
	health.health_changed.connect(func(cur: int, mx: int) -> void: seen.append([cur, mx]))
	health.setup(30)
	assert_int(health.max_health).is_equal(30)
	assert_int(health.current).is_equal(30)
	assert_array(seen).is_equal([[30, 30]])
