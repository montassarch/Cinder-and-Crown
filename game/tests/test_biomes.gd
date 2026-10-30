extends GdUnitTestSuite
## A run crosses four worlds: each has its own depth range, art, weather, light and enemies.

const IDS := ["cathedral", "frost_ossuary", "molten_forge", "storm_spire"]
const LAYERS := ["layer_far", "layer_mid_far", "layer_mid", "layer_near"]


func _biomes() -> Array[BiomeData]:
	return BiomeData.load_all()


func test_four_biomes_in_depth_order_starting_at_the_first_level() -> void:
	var biomes := _biomes()
	assert_array(biomes.map(func(b: BiomeData) -> String: return b.id)).is_equal(IDS)
	assert_int(biomes[0].first_depth).is_equal(0)
	for i in range(1, biomes.size()):
		assert_int(biomes[i].first_depth).is_greater(biomes[i - 1].first_depth)


func test_the_biome_for_a_depth_is_the_last_one_that_has_started() -> void:
	var biomes := _biomes()
	var expect := {0: "cathedral", 2: "cathedral", 3: "frost_ossuary", 5: "frost_ossuary", 6: "molten_forge", 9: "storm_spire", 40: "storm_spire"}
	for depth in expect:
		assert_str(BiomeData.for_depth(biomes, depth).id).override_failure_message("depth %d" % depth).is_equal(expect[depth])


func test_every_biome_has_its_painted_layers_tiles_fog_and_lights() -> void:
	for biome in _biomes():
		for name in LAYERS:
			var tex := load(biome.art_path(name)) as Texture2D
			assert_object(tex).override_failure_message("%s %s" % [biome.id, name]).is_not_null()
			assert_int(tex.get_height()).is_equal(GameConfig.BASE_HEIGHT)
			assert_int(tex.get_width()).is_greater_equal(GameConfig.BASE_WIDTH)
		for name in ["ground_tile", "ledge_tile", "fog", "glow"]:
			assert_object(load(biome.art_path(name))).override_failure_message("%s %s" % [biome.id, name]).is_not_null()
		for i in 4:
			assert_object(load(biome.art_path("%s_%d" % [biome.light_prefix, i]))).is_not_null()


func test_the_worlds_look_and_feel_different() -> void:
	var biomes := _biomes()
	var colours := {}
	var weathers := {}
	for biome in biomes:
		colours[biome.clear_color.to_html()] = true
		weathers[biome.weather] = true
		assert_str(biome.display_name).is_not_empty()
	assert_int(colours.size()).is_equal(biomes.size())
	assert_int(weathers.size()).is_greater_equal(3)


func test_each_later_world_brings_at_least_two_enemies_not_seen_before() -> void:
	var seen := {}
	for biome in _biomes():
		assert_int(biome.enemies.size()).is_greater_equal(3)
		var fresh := 0
		for enemy in biome.enemies:
			if not seen.has(enemy.resource_path):
				fresh += 1
			seen[enemy.resource_path] = true
		assert_int(fresh).override_failure_message(biome.id).is_greater_equal(2)


func test_in_every_world_the_walking_line_is_lit_so_the_dark_hero_reads_against_it() -> void:
	for biome in _biomes():
		var composite := Image.create(GameConfig.BASE_WIDTH, GameConfig.BASE_HEIGHT, false, Image.FORMAT_RGBA8)
		for name in LAYERS:
			var image := (load(biome.art_path(name)) as Texture2D).get_image().duplicate()
			image.convert(Image.FORMAT_RGBA8)
			image.crop(GameConfig.BASE_WIDTH, GameConfig.BASE_HEIGHT)
			composite.blend_rect(image, Rect2i(0, 0, GameConfig.BASE_WIDTH, GameConfig.BASE_HEIGHT), Vector2i.ZERO)
		var y := int(GameConfig.tiles(Sandbox.GROUND_TOP_TILES)) - 14
		var luminance := 0.0
		for x in range(0, GameConfig.BASE_WIDTH, 4):
			var c := composite.get_pixel(x, y)
			luminance += 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
		luminance /= GameConfig.BASE_WIDTH / 4.0
		assert_float(luminance).override_failure_message(biome.id).is_greater(0.2)


func test_every_world_enemy_has_its_own_art() -> void:
	for biome in _biomes():
		for enemy in biome.enemies:
			assert_bool(EnemyVisual.has_art(enemy.art)).override_failure_message("%s: %s" % [biome.id, enemy.art]).is_true()
