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

func test_blade_table_covers_every_frame_of_every_animation() -> void:
	for anim in PlayerVisual.ANIMS:
		var spec: Dictionary = PlayerVisual.ANIMS[anim]
		var frames: int = spec["frames"].size() if spec.has("frames") else spec["count"]
		assert_int(HeroBlade.SEGMENTS[anim].size()).is_equal(frames)
		for seg: Vector4 in HeroBlade.SEGMENTS[anim]:
			var length := Vector2(seg.x, seg.y).distance_to(Vector2(seg.z, seg.w))
			assert_float(length).is_between(8.0, 40.0)

func test_effect_blade_follows_the_sprite_and_mirrors_with_facing() -> void:
	var player := _player()
	var effect: StormEffect = player.get_node("StormEffect")
	var visual: PlayerVisual = player.get_node("Visual")
	visual.flip_h = false
	visual.position = Vector2(-10.0, -20.0)
	var seg := HeroBlade.segment(visual.animation, visual.frame)
	var plain := effect.blade()
	assert_vector(plain[1]).is_equal_approx(Vector2(-10.0 + seg.z, -20.0 + seg.w), Vector2(0.01, 0.01))
	visual.flip_h = true
	var mirrored := effect.blade()
	assert_float(mirrored[1].x).is_equal_approx(-10.0 + PlayerVisual.FRAME.x - seg.z, 0.01)
