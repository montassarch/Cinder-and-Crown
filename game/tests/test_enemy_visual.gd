extends GdUnitTestSuite
## Enemies are drawn from their pre-rendered sprites (art/enemies/<id>/), driven by what the enemy is doing.

const State := Enemy.State


func _enemy(id: String) -> Enemy:
	var enemy: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	enemy.data = load("res://data/enemies/%s.tres" % id)
	add_child(enemy)
	return enemy


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _all_ids() -> Array[String]:
	var ids: Array[String] = []
	for file in DirAccess.get_files_at("res://data/enemies"):
		if file.ends_with(".tres"):
			ids.append(file.get_basename())
	return ids


func test_every_enemy_names_its_art_and_has_every_animation() -> void:
	for id in _all_ids():
		var data: EnemyData = load("res://data/enemies/%s.tres" % id)
		assert_str(data.art).is_not_empty()
		assert_bool(EnemyVisual.has_art(data.art)).is_true()
		var frames := EnemyVisual.frames_for(data.art)
		for anim in EnemyVisual.REQUIRED_ANIMS:
			assert_bool(frames.has_animation(anim)).is_true()
			assert_int(frames.get_frame_count(anim)).is_greater(0)


func test_the_animation_follows_what_the_enemy_is_doing() -> void:
	assert_str(EnemyVisual.animation_for(State.MOVE, true, EnemyMove.Kind.MELEE)).is_equal("Move")
	assert_str(EnemyVisual.animation_for(State.MOVE, false, EnemyMove.Kind.MELEE)).is_equal("Idle")
	assert_str(EnemyVisual.animation_for(State.TELEGRAPH, false, EnemyMove.Kind.MELEE)).is_equal("Windup")
	assert_str(EnemyVisual.animation_for(State.STRIKE, false, EnemyMove.Kind.MELEE)).is_equal("Strike")
	assert_str(EnemyVisual.animation_for(State.STRIKE, true, EnemyMove.Kind.DASH)).is_equal("Dash")
	assert_str(EnemyVisual.animation_for(State.RECOVER, false, EnemyMove.Kind.MELEE)).is_equal("Recover")
	assert_str(EnemyVisual.animation_for(State.STUNNED, false, EnemyMove.Kind.MELEE)).is_equal("Stun")
	assert_str(EnemyVisual.animation_for(State.DEAD, false, EnemyMove.Kind.MELEE)).is_equal("Death")


func test_an_enemy_with_art_hides_its_box_and_shows_a_sprite() -> void:
	var enemy := _enemy("shambler")
	var art: AnimatedSprite2D = enemy.get_node("Art")
	assert_bool(art.visible).is_true()
	assert_bool((enemy.get_node("Body") as ColorRect).visible).is_false()


func test_the_sprite_turns_with_the_enemy() -> void:
	var enemy := _enemy("shambler")
	var art: AnimatedSprite2D = enemy.get_node("Art")
	enemy._facing = 1.0
	await _frames(3)
	assert_bool(art.flip_h).is_false()
	enemy._facing = -1.0
	await _frames(3)
	assert_bool(art.flip_h).is_true()


func test_the_sprite_stands_on_the_enemys_feet() -> void:
	var enemy := _enemy("crown_guard")
	var art: AnimatedSprite2D = enemy.get_node("Art")
	await _frames(2)
	var tex := art.sprite_frames.get_frame_texture(art.animation, 0)
	var bottom := art.position.y + tex.get_height() - 2.0   # art leaves a 2 px margin under the feet
	assert_float(bottom).is_equal_approx(GameConfig.tiles(enemy.data.body_size_tiles.y) / 2.0, 0.6)


func test_a_wind_up_plays_the_windup_animation_over_the_telegraph_time() -> void:
	var enemy := _enemy("crown_guard")
	var art: AnimatedSprite2D = enemy.get_node("Art")
	enemy.begin_telegraph()
	await _frames(2)
	assert_str(art.animation).is_equal("Windup")
	var frames := art.sprite_frames.get_frame_count(&"Windup")
	var fps := art.sprite_frames.get_animation_speed(&"Windup") * art.speed_scale
	assert_float(float(frames) / fps).is_equal_approx(enemy.data.effective_moves()[0].telegraph_seconds, 0.05)


func test_a_stunned_enemy_is_tinted_and_a_normal_one_is_not() -> void:
	var enemy := _enemy("shambler")
	var art: AnimatedSprite2D = enemy.get_node("Art")
	await _frames(2)
	assert_object(art.modulate).is_equal(Color.WHITE)
	enemy.stun(0.5)
	await _frames(2)
	assert_object(art.modulate).is_not_equal(Color.WHITE)
	assert_str(art.animation).is_equal("Stun")


func test_a_killed_enemy_plays_its_death_then_goes() -> void:
	var enemy := _enemy("shambler")
	var art: AnimatedSprite2D = enemy.get_node("Art")
	enemy.take_hit(9999, enemy.global_position.x - 10.0)
	await _frames(2)
	assert_str(art.animation).is_equal("Death")
	assert_bool(art.visible).is_true()
	await _frames(int(Enemy.DEATH_LINGER * 60.0) + 12)
	assert_bool(is_instance_valid(enemy)).is_false()


func test_a_blown_up_enemy_leaves_no_corpse_sprite() -> void:
	var enemy := _enemy("powder_pilgrim")
	var art: AnimatedSprite2D = enemy.get_node("Art")
	enemy._explode(enemy.data.effective_moves()[0])
	assert_bool(art.visible).is_false()


func test_the_tell_ring_floats_above_the_sprites_head() -> void:
	for id in ["crown_brute", "crown_guard"]:
		var enemy := _enemy(id)
		var hitbox_top := -GameConfig.tiles(enemy.data.body_size_tiles.y) / 2.0
		assert_float(enemy.head_top()).is_less_equal(hitbox_top)


## Each enemy's glowing eye (one exact colour, painted by the art tool) must sit at the front of its own head:
## in front of the centre of the pixels around it (a weapon held out front would skew the whole body's centre).
func test_every_enemy_looks_the_way_it_faces() -> void:
	for id in _all_ids():
		var enemy := _enemy(id)
		var art: AnimatedSprite2D = enemy.get_node("Art")
		var eye := EnemyVisual.eye_colour(enemy.data.art)
		for facing in [1.0, -1.0]:
			enemy._facing = facing
			await _frames(3)
			for anim in [&"Idle", &"Move"]:
				var img := art.sprite_frames.get_frame_texture(anim, 0).get_image()
				var w := img.get_width()
				var eye_x := 0.0
				var eye_y := 0.0
				var eye_n := 0
				for y in img.get_height():
					for x in w:
						if img.get_pixel(x, y).is_equal_approx(eye):
							eye_x += (w - 1 - x) if art.flip_h else x
							eye_y += y
							eye_n += 1
				assert_int(eye_n).is_greater(0)
				eye_x /= eye_n
				eye_y /= eye_n
				var near_sum := 0.0
				var near_n := 0
				for y in range(int(eye_y) - 4, int(eye_y) + 5):
					for x in w:
						var shown := (w - 1 - x) if art.flip_h else x
						if y >= 0 and y < img.get_height() and absf(shown - eye_x) <= 10.0 and img.get_pixel(x, y).a > 0.0 and not img.get_pixel(x, y).is_equal_approx(eye):
							near_sum += shown
							near_n += 1
				assert_int(near_n).is_greater(0)
				# facing right: the eye is right of its neighbours; facing left: left of them
				assert_float((eye_x - near_sum / near_n) * facing).is_greater(0.0)
