extends GdUnitTestSuite

func test_tile_size_is_sixteen() -> void:
	assert_int(GameConfig.TILE_SIZE).is_equal(16)

func test_base_resolution_integer_scales_to_1080p() -> void:
	assert_int(1920 / GameConfig.BASE_WIDTH).is_equal(5)
	assert_int(1080 / GameConfig.BASE_HEIGHT).is_equal(5)
	assert_int(1920 % GameConfig.BASE_WIDTH).is_equal(0)
	assert_int(1080 % GameConfig.BASE_HEIGHT).is_equal(0)

func test_tiles_converts_to_pixels() -> void:
	assert_float(GameConfig.tiles(1.0)).is_equal(16.0)
	assert_float(GameConfig.tiles(2.5)).is_equal(40.0)

func test_tiles_v_converts_both_axes() -> void:
	assert_vector(GameConfig.tiles_v(1.0, 2.0)).is_equal(Vector2(16.0, 32.0))
