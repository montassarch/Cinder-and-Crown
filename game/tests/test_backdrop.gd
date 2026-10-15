extends GdUnitTestSuite

const DIR := "res://art/cathedral"
const LAYER_FILES := ["far", "mid_far", "mid", "near"]

func _backdrop() -> Backdrop:
	var backdrop: Backdrop = auto_free(Backdrop.new())
	add_child(backdrop)
	return backdrop

func _image(name: String) -> Image:
	return (load("%s/%s.png" % [DIR, name]) as Texture2D).get_image()

func _column_difference(image: Image, a: int, b: int) -> float:
	var total := 0.0
	for y in image.get_height():
		var ca := image.get_pixel(a, y)
		var cb := image.get_pixel(b, y)
		total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) + absf(ca.a - cb.a)
	return total / image.get_height()

func test_every_layer_texture_exists_and_fills_the_screen_height() -> void:
	for name in LAYER_FILES:
		var image := _image("layer_" + name)
		assert_int(image.get_height()).is_equal(GameConfig.BASE_HEIGHT)
		assert_int(image.get_width()).is_greater_equal(GameConfig.BASE_WIDTH)

func test_layers_tile_without_a_visible_seam() -> void:
	for name in LAYER_FILES:
		var image := _image("layer_" + name)
		var seam := _column_difference(image, image.get_width() - 1, 0)
		var typical := _column_difference(image, 10, 11) + 0.15
		assert_float(seam).is_less(typical * 3.0 + 0.3)

func test_backdrop_builds_four_scrolling_layers_deeper_ones_slower() -> void:
	var backdrop := _backdrop()
	var layers := backdrop.layers()
	assert_int(layers.size()).is_equal(4)
	for i in range(1, layers.size()):
		assert_float(layers[i].scroll_scale.x).is_greater(layers[i - 1].scroll_scale.x)
	assert_float(layers[0].scroll_scale.x).is_less(0.3)
	assert_float(layers[layers.size() - 1].scroll_scale.x).is_less(1.0)

func test_each_layer_repeats_horizontally_by_its_own_width() -> void:
	var backdrop := _backdrop()
	for layer in backdrop.layers():
		var sprite: Sprite2D = layer.get_node("Art")
		assert_float(layer.repeat_size.x).is_equal(float(sprite.texture.get_width()))

func test_braziers_burn_with_animated_flames() -> void:
	var backdrop := _backdrop()
	var flames := backdrop.flames()
	assert_int(flames.size()).is_greater_equal(2)
	for flame in flames:
		assert_bool(flame.is_playing()).is_true()
		assert_int(flame.sprite_frames.get_frame_count(&"burn")).is_greater_equal(4)

func test_embers_drift_across_the_screen() -> void:
	var backdrop := _backdrop()
	var embers := backdrop.embers()
	assert_bool(embers.emitting).is_true()
	assert_int(embers.amount).is_greater_equal(20)

func test_the_walking_line_is_lit_so_a_black_hero_reads_against_it() -> void:
	# The hero is near-black; the strip just above the floor must be clearly lighter than he is.
	var composite := Image.create(GameConfig.BASE_WIDTH, GameConfig.BASE_HEIGHT, false, Image.FORMAT_RGBA8)
	for name in LAYER_FILES:
		var image := _image("layer_" + name)
		image = image.duplicate()
		image.crop(GameConfig.BASE_WIDTH, GameConfig.BASE_HEIGHT)
		composite.blend_rect(image, Rect2i(0, 0, GameConfig.BASE_WIDTH, GameConfig.BASE_HEIGHT), Vector2i.ZERO)
	var y := int(GameConfig.tiles(Sandbox.GROUND_TOP_TILES)) - 14
	var luminance := 0.0
	for x in range(0, GameConfig.BASE_WIDTH, 4):
		var c := composite.get_pixel(x, y)
		luminance += 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
	luminance /= GameConfig.BASE_WIDTH / 4.0
	assert_float(luminance).is_greater(0.2)

func test_the_sandbox_and_generated_levels_both_get_the_hall() -> void:
	var sandbox: Sandbox = auto_free(load("res://levels/sandbox.tscn").instantiate())
	add_child(sandbox)
	assert_object(sandbox.get_node_or_null("Backdrop")).is_instanceof(Backdrop)
	var generated: GeneratedLevel = auto_free(load("res://levels/generated_level.tscn").instantiate())
	add_child(generated)
	assert_object(generated.get_node_or_null("Backdrop")).is_instanceof(Backdrop)

func test_ground_and_platforms_use_stone_textures_not_flat_colour() -> void:
	var sandbox: Sandbox = auto_free(load("res://levels/sandbox.tscn").instantiate())
	add_child(sandbox)
	var stone := 0
	for child in sandbox.get_children():
		if child is StaticBody2D:
			for part in child.get_children():
				if part is TextureRect and part.texture != null:
					stone += 1
	assert_int(stone).is_greater_equal(1 + sandbox.platform_rects_tiles().size())
