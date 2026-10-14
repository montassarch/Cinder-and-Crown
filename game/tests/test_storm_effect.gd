extends GdUnitTestSuite

const PLAYER_SCENE := "res://src/player/player.tscn"

func _player() -> Player:
	var player: Player = auto_free(load(PLAYER_SCENE).instantiate())
	add_child(player)
	return player

func test_player_carries_a_storm_effect_bound_to_it() -> void:
	var effect: StormEffect = _player().get_node("StormEffect")
	assert_float(effect.charge_alpha()).is_equal(0.0)
	assert_bool(effect.bolt_active()).is_false()

func test_bolt_shows_when_the_storm_strikes_and_charge_fades_over_the_last_seconds() -> void:
	var player := _player()
	var effect: StormEffect = player.get_node("StormEffect")
	player.storm_struck.emit()
	assert_bool(effect.bolt_active()).is_true()
	player._storm_left = Player.STORM_SECONDS
	assert_float(effect.charge_alpha()).is_equal(1.0)
	player._storm_left = Player.STORM_FADE_SECONDS / 2.0
	assert_float(effect.charge_alpha()).is_equal_approx(0.5, 0.001)
