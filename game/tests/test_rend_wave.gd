extends GdUnitTestSuite

const DUMMY := preload("res://tests/support/hurtable_dummy.gd")

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _wave(direction: float = 1.0) -> RendWave:
	var wave: RendWave = auto_free(RendWave.new())
	wave.direction = direction
	add_child(wave)
	return wave

func _dummy_at(tiles_x: float) -> Node2D:
	var dummy: Node2D = auto_free(DUMMY.new())
	add_child(dummy)
	dummy.global_position = GameConfig.tiles_v(tiles_x, -1.0)
	return dummy

func test_the_wave_travels_forward_in_its_direction() -> void:
	var right := _wave(1.0)
	var left := _wave(-1.0)
	await _frames(15)
	assert_float(right.global_position.x).is_greater(GameConfig.tiles(2.0))
	assert_float(left.global_position.x).is_less(-GameConfig.tiles(2.0))

func test_the_wave_hits_every_enemy_in_its_path_once() -> void:
	var a := _dummy_at(3.0)
	var b := _dummy_at(6.0)
	_wave(1.0)
	await _frames(45)
	assert_int(a.hits.size()).is_equal(1)
	assert_int(b.hits.size()).is_equal(1)
	assert_int(a.hits[0][0]).is_equal(RendWave.DAMAGE)

func test_the_wave_fades_out_after_its_range() -> void:
	var wave := _wave(1.0)
	await _frames(int(RendWave.RANGE_TILES / RendWave.SPEED_TILES * 60.0) + 10)
	assert_bool(is_instance_valid(wave) and not wave.is_queued_for_deletion()).is_false()

func test_a_wall_stops_the_wave() -> void:
	var wall: StaticBody2D = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(1.0, 8.0)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = GameConfig.tiles_v(3.0, -2.0)
	add_child(wall)
	var behind := _dummy_at(6.0)
	_wave(1.0)
	await _frames(45)
	assert_int(behind.hits.size()).is_equal(0)

# --- Pre-rendered red lightning (the old drawn bolts are gone) ---

func test_nothing_is_drawn_per_frame_any_more() -> void:
	assert_bool(_wave().has_method("_draw")).is_false()

func test_the_wave_is_a_red_lightning_sprite_facing_the_way_it_travels() -> void:
	var right: AnimatedSprite2D = _wave(1.0).get_node("Art")
	var left: AnimatedSprite2D = _wave(-1.0).get_node("Art")
	assert_int(right.sprite_frames.get_frame_count(&"default")).is_equal(6)
	assert_vector(Vector2(right.sprite_frames.get_frame_texture(&"default", 0).get_size())).is_equal(Vector2(64, 48))
	assert_bool(right.flip_h).is_false()
	assert_bool(left.flip_h).is_true()

func test_the_sprite_head_sits_at_the_front_of_the_wave() -> void:
	var right: AnimatedSprite2D = _wave(1.0).get_node("Art")
	var left: AnimatedSprite2D = _wave(-1.0).get_node("Art")
	# art faces right with its head on the right edge; the head must be at the node's origin
	assert_float(right.position.x + 62.0).is_equal_approx(0.0, 1.0)
	assert_float(left.position.x + 1.0).is_equal_approx(0.0, 1.0)

func test_the_wave_fades_toward_the_end_of_its_range() -> void:
	var wave := _wave()
	var art: AnimatedSprite2D = wave.get_node("Art")
	await _frames(2)
	assert_float(art.modulate.a).is_equal(1.0)
	wave._travelled = GameConfig.tiles(RendWave.RANGE_TILES) * 0.95
	await _frames(1)
	assert_float(art.modulate.a).is_less(0.6)
