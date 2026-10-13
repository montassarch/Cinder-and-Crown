class_name DamageTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# Damage.compute is deliberately pure arithmetic with no engine access, so
# every clamping rule is provable here rather than guessed at from play.


func test_applies_multiplier_then_subtracts_defense() -> void:
	# Order matters: 10 * 2.0 = 20, then -5 defense = 15.
	# Subtracting defense first would give (10-5)*2.0 = 10.
	assert_int(Damage.compute(10, 2.0, 5)).is_equal(15)


func test_rounds_down_fractional_damage() -> void:
	# 10 * 1.55 = 15.5 -> 15. Always floor, so damage never rounds up
	# into a breakpoint the designer did not author.
	assert_int(Damage.compute(10, 1.55, 0)).is_equal(15)


func test_defense_exceeding_damage_clamps_to_zero() -> void:
	assert_int(Damage.compute(5, 1.0, 99)).is_equal(0)


func test_negative_base_never_heals() -> void:
	# Review Focus 5: a negative value must not become healing.
	assert_int(Damage.compute(-10, 1.0, 0)).is_equal(0)


func test_zero_multiplier_deals_nothing() -> void:
	assert_int(Damage.compute(50, 0.0, 0)).is_equal(0)


func test_negative_multiplier_never_heals() -> void:
	# Review Focus 5, the other direction into the same hole.
	assert_int(Damage.compute(50, -2.0, 0)).is_equal(0)


func test_negative_defense_does_not_amplify_damage() -> void:
	# Review Focus 5: negative defense must not act as a damage bonus,
	# or a badly authored .tres file silently becomes a damage multiplier.
	assert_int(Damage.compute(10, 1.0, -50)).is_equal(10)
