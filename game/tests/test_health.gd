class_name HealthTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# Health is a Node so it can sit on the player and on every enemy, but it
# is configured by an explicit call rather than _ready(), which is what
# lets these tests exercise it without a scene tree.


func _make(max_health: int) -> Health:
	var health: Health = auto_free(Health.new())
	health.configure(max_health)
	return health


func test_take_damage_reduces_current() -> void:
	var health := _make(100)
	var absorbed := health.take_damage(30)
	assert_int(health.current).is_equal(70)
	assert_int(absorbed).is_equal(30)


func test_overkill_reports_only_absorbed_damage() -> void:
	# A 999 hit on 10 hp absorbs 10. Reporting 999 would let an overkill
	# bonus or damage-numbers UI show a figure the target never had.
	var health := _make(10)
	var absorbed := health.take_damage(999)
	assert_int(health.current).is_equal(0)
	assert_int(absorbed).is_equal(10)


func test_death_emits_died_once() -> void:
	var health := _make(10)
	var deaths := [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	health.take_damage(10)
	health.take_damage(10)
	assert_int(deaths[0]).is_equal(1)


func test_damage_after_death_absorbs_nothing() -> void:
	var health := _make(10)
	health.take_damage(10)
	var absorbed := health.take_damage(5)
	assert_int(absorbed).is_equal(0)
	assert_int(health.current).is_equal(0)


func test_negative_damage_does_not_heal() -> void:
	# Review Focus 5 at the component level.
	var health := _make(100)
	var absorbed := health.take_damage(-40)
	assert_int(health.current).is_equal(100)
	assert_int(absorbed).is_equal(0)


func test_heal_cannot_exceed_max() -> void:
	var health := _make(100)
	health.take_damage(10)
	health.heal(50)
	assert_int(health.current).is_equal(100)


func test_heal_does_not_resurrect() -> void:
	# Death is a state the Health component cannot undo on its own; a
	# revive has to be an explicit configure(), not a stray heal tick.
	var health := _make(10)
	health.take_damage(10)
	health.heal(10)
	assert_int(health.current).is_equal(0)
	assert_bool(health.is_alive()).is_false()


func test_health_changed_carries_current_and_max() -> void:
	var health := _make(100)
	var seen := []
	health.health_changed.connect(
		func(current: int, max_health: int) -> void:
			seen.append([current, max_health])
	)
	health.take_damage(25)
	assert_int(seen.size()).is_equal(1)
	assert_int(seen[0][0]).is_equal(75)
	assert_int(seen[0][1]).is_equal(100)


func test_is_alive_is_false_at_zero() -> void:
	var health := _make(10)
	assert_bool(health.is_alive()).is_true()
	health.take_damage(10)
	assert_bool(health.is_alive()).is_false()
