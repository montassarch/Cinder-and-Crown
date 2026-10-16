extends GdUnitTestSuite

func _player() -> Player:
	var player: Player = auto_free(load("res://src/player/player.tscn").instantiate())
	add_child(player)
	return player

func test_the_player_carries_a_parry_effect_that_starts_idle() -> void:
	var effect: ParryEffect = _player().get_node("ParryEffect")
	assert_bool(effect.is_active()).is_false()

func test_a_deflect_makes_it_flash_in_front_of_the_hero() -> void:
	var player := _player()
	var effect: ParryEffect = player.get_node("ParryEffect")
	player.parried.emit(false)
	assert_bool(effect.is_active()).is_true()
	assert_bool(effect.is_perfect()).is_false()
	assert_float(effect.position.x).is_greater(0.0)

func test_a_perfect_deflect_is_marked_perfect() -> void:
	var player := _player()
	var effect: ParryEffect = player.get_node("ParryEffect")
	player.parried.emit(true)
	assert_bool(effect.is_perfect()).is_true()

func test_the_flash_fades_out_and_a_perfect_one_lasts_longer() -> void:
	var player := _player()
	var effect: ParryEffect = player.get_node("ParryEffect")
	player.parried.emit(false)
	effect.advance(ParryEffect.SECONDS + 0.01)
	assert_bool(effect.is_active()).is_false()
	player.parried.emit(true)
	effect.advance(ParryEffect.SECONDS + 0.01)
	assert_bool(effect.is_active()).is_true()
	effect.advance(ParryEffect.PERFECT_SECONDS)
	assert_bool(effect.is_active()).is_false()

func test_progress_runs_from_zero_to_one() -> void:
	var player := _player()
	var effect: ParryEffect = player.get_node("ParryEffect")
	player.parried.emit(false)
	assert_float(effect.progress()).is_equal(0.0)
	effect.advance(ParryEffect.SECONDS / 2.0)
	assert_float(effect.progress()).is_equal_approx(0.5, 0.001)
