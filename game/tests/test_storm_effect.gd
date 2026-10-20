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


# --- Pre-rendered lightning (the old drawn trail, wrap and bolt are gone) ---

const State := PlayerStateMachine.PlayerState


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func test_nothing_is_drawn_per_frame_any_more() -> void:
	var effect: StormEffect = _player().get_node("StormEffect")
	assert_bool(effect.has_method("_draw")).is_false()
	assert_bool(effect.has_method("_draw_crescent")).is_false()


func test_a_blue_bolt_sprite_plays_when_the_storm_strikes_then_goes() -> void:
	var player := _player()
	var effect: StormEffect = player.get_node("StormEffect")
	var bolt: AnimatedSprite2D = effect.get_node("Bolt")
	assert_bool(bolt.visible).is_false()
	player.storm_struck.emit()
	assert_bool(bolt.visible).is_true()
	assert_int(bolt.sprite_frames.get_frame_count(&"default")).is_equal(8)
	assert_int(bolt.frame).is_equal(0)
	await _frames(int(StormEffect.BOLT_SECONDS * 60.0) + 6)
	assert_bool(bolt.visible).is_false()


func test_the_bolt_lands_on_the_sword_tip() -> void:
	var player := _player()
	var effect: StormEffect = player.get_node("StormEffect")
	var bolt: AnimatedSprite2D = effect.get_node("Bolt")
	player.storm_struck.emit()
	await _frames(2)
	var tip := effect.blade()[1]
	# the sprite's bottom edge sits on the tip, horizontally centred
	var size := Vector2(bolt.sprite_frames.get_frame_texture(&"default", 0).get_size())
	assert_vector(bolt.position + Vector2(size.x / 2.0, size.y)).is_equal_approx(tip, Vector2(1.5, 1.5))


func test_the_sword_crackles_blue_while_charged_and_stops_when_the_charge_ends() -> void:
	var player := _player()
	var effect: StormEffect = player.get_node("StormEffect")
	var blue: Array = effect.get_node("Blue").get_children()
	var red: Array = effect.get_node("Red").get_children()
	await _frames(2)
	assert_bool(blue[0].visible).is_false()
	player._storm_left = Player.STORM_SECONDS
	await _frames(2)
	for sprite: AnimatedSprite2D in blue:
		assert_bool(sprite.visible).is_true()
	for sprite: AnimatedSprite2D in red:
		assert_bool(sprite.visible).is_false()
	player._storm_left = 0.0
	await _frames(2)
	assert_bool(blue[0].visible).is_false()


func test_a_fading_charge_fades_the_crackle() -> void:
	var player := _player()
	var effect: StormEffect = player.get_node("StormEffect")
	player._storm_left = Player.STORM_FADE_SECONDS / 2.0
	await _frames(2)
	var sprite: AnimatedSprite2D = effect.get_node("Blue").get_child(0)
	assert_float(sprite.modulate.a).is_equal_approx(0.5, 0.05)


func test_the_sword_crackles_red_during_rend() -> void:
	var player := _player()
	var effect: StormEffect = player.get_node("StormEffect")
	player._state = State.REND
	await _frames(2)
	for sprite: AnimatedSprite2D in effect.get_node("Red").get_children():
		assert_bool(sprite.visible).is_true()
	for sprite: AnimatedSprite2D in effect.get_node("Blue").get_children():
		assert_bool(sprite.visible).is_false()
