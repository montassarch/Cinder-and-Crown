extends GdUnitTestSuite
## The combat effect kit: Blender-rendered glowing sprites added over the scene, screen shake, damage numbers.

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func test_every_effect_set_loads_with_the_right_frame_count_and_size() -> void:
	for art in FxArt.FRAME_COUNTS:
		var frames := FxArt.frames(art, 24.0)
		assert_int(frames.get_frame_count(&"default")).is_equal(FxArt.FRAME_COUNTS[art])
		var size := frames.get_frame_texture(&"default", 0).get_size()
		assert_vector(Vector2(size)).is_equal(Vector2(FxArt.FRAME_SIZES[art]))


func test_effects_are_added_over_the_scene_and_scaled_to_the_games_pixels() -> void:
	var sprite := FxArt.sprite(&"spark", 24.0)
	auto_free(sprite)
	assert_int((sprite.material as CanvasItemMaterial).blend_mode).is_equal(CanvasItemMaterial.BLEND_MODE_ADD)
	assert_float(sprite.scale.x).is_equal_approx(FxArt.GAME_PIXELS_PER_METRE / FxArt.PIXELS_PER_METRE, 0.0001)
	assert_vector(sprite.offset).is_equal(-FxArt.PIVOTS[&"spark"])
	assert_bool(sprite.sprite_frames.get_animation_loop(&"default")).is_false()


func test_a_spawned_effect_plays_once_and_removes_itself() -> void:
	var fx := FxSprite.spawn(self, &"spark", Vector2(10.0, 20.0))
	assert_vector(fx.global_position).is_equal(Vector2(10.0, 20.0))
	assert_bool(fx.is_playing()).is_true()
	await _frames(60)
	assert_bool(is_instance_valid(fx)).is_false()


func test_a_spawned_effect_can_be_turned_tinted_and_scaled() -> void:
	var fx := FxSprite.spawn(self, &"slash_a", Vector2.ZERO, 0.5, true, Color(0.4, 0.7, 1.0), 2.0)
	auto_free(fx)
	assert_float(fx.rotation).is_equal_approx(0.5, 0.0001)
	assert_float(signf(fx.scale.x)).is_equal(-1.0)               # facing left: mirrored about the pivot
	assert_float(absf(fx.scale.x)).is_equal_approx(FxArt.scale_for(&"slash_a") * 2.0, 0.0001)
	assert_object(fx.modulate).is_equal(Color(0.4, 0.7, 1.0))


# --- screen shake ---

func _shaker() -> CameraShake:
	var camera: Camera2D = auto_free(Camera2D.new())
	add_child(camera)
	var shake := CameraShake.new()
	camera.add_child(shake)
	return shake


func test_a_kick_adds_trauma_up_to_one() -> void:
	var shake := _shaker()
	shake.kick(0.4)
	assert_float(shake.trauma).is_equal(0.4)
	shake.kick(0.9)
	assert_float(shake.trauma).is_equal(1.0)


func test_the_camera_shakes_while_there_is_trauma_and_settles_back() -> void:
	var shake := _shaker()
	var camera := shake.get_parent() as Camera2D
	shake.kick(1.0)
	var moved := false
	for i in 8:
		await get_tree().process_frame
		if camera.offset.length() > 0.1:
			moved = true
		assert_float(camera.offset.length()).is_less_equal(CameraShake.MAX_OFFSET * 1.5)
	assert_bool(moved).is_true()
	await get_tree().create_timer(1.0 / CameraShake.DECAY_PER_SECOND + 0.4).timeout
	assert_float(shake.trauma).is_equal(0.0)
	assert_vector(camera.offset).is_equal(Vector2.ZERO)


func test_screen_shake_can_be_switched_off() -> void:
	var shake := _shaker()
	shake.enabled = false
	shake.kick(1.0)
	assert_float(shake.trauma).is_equal(0.0)


# --- damage numbers ---

func test_a_damage_number_shows_the_damage_floats_up_and_goes() -> void:
	var number := DamageNumber.spawn(self, 12, Vector2(50.0, 40.0))
	assert_str(number.text).is_equal("12")
	var start := number.global_position.y
	await _frames(10)
	assert_float(number.global_position.y).is_less(start)
	await get_tree().create_timer(DamageNumber.LIFETIME + 0.3).timeout
	assert_bool(is_instance_valid(number)).is_false()


func test_big_hits_get_a_bigger_warmer_number() -> void:
	var small := DamageNumber.spawn(self, 3, Vector2.ZERO)
	var big := DamageNumber.spawn(self, DamageNumber.BIG_HIT, Vector2.ZERO)
	auto_free(small)
	auto_free(big)
	assert_int(big.get_theme_font_size(&"font_size")).is_greater(small.get_theme_font_size(&"font_size"))
	assert_object(big.get_theme_color(&"font_color")).is_not_equal(small.get_theme_color(&"font_color"))
