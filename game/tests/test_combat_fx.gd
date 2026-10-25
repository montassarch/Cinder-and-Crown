extends GdUnitTestSuite
## The combat effects hooked to what happens in the level: swings, hits, deaths, parries.

const SCENE := "res://levels/sandbox.tscn"
const DUMMY := preload("res://tests/support/hurtable_dummy.gd")

var _level: Sandbox


func before_test() -> void:
	_level = load(SCENE).instantiate()
	add_child(_level)


func after_test() -> void:
	Engine.time_scale = 1.0
	_level.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _fx_of(art: StringName) -> Array:
	var found := []
	for child in _level.get_children():
		if child is AnimatedSprite2D and child.has_meta(&"fx_art") and child.get_meta(&"fx_art") == art:
			found.append(child)
	return found


func _numbers() -> Array:
	var found := []
	for child in _level.get_children():
		if child is DamageNumber:
			found.append(child)
	return found


func _enemy() -> Enemy:
	return _level.spawn_enemy_at(load("res://data/enemies/shambler.tres"), _level.player.global_position + Vector2(40.0, 0.0))


func test_the_player_announces_each_swing_with_its_combo_step() -> void:
	var seen := []
	_level.player.swung.connect(func(step: int, facing: float) -> void: seen.append([step, facing]))
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(3)
	InputRouter.set_virtual_button(&"attack", false)
	await _frames(40)
	assert_int(seen.size()).is_greater(0)
	assert_int(seen[0][0]).is_equal(0)


func _sword_move(step: int) -> WeaponMove:
	return _level.player.weapon_in_slot(0).chain_move(step)


func test_each_move_shows_the_arc_it_asks_for_on_the_heros_side() -> void:
	var player := _level.player
	for step in 3:
		var move := _sword_move(step)
		player.move_started.emit(move, 1.0)
		var arcs := _fx_of(move.fx)
		assert_int(arcs.size()).is_equal(1)
		assert_float(arcs[0].global_position.x).is_greater(player.global_position.x)   # ahead of him
	player.move_started.emit(_sword_move(0), -1.0)
	var left := _fx_of(&"slash_a")
	assert_float(left[left.size() - 1].global_position.x).is_less(player.global_position.x)
	assert_float(left[left.size() - 1].scale.x).is_less(0.0)


func test_a_move_without_an_arc_shows_none() -> void:
	var bow := load("res://data/weapons/hunters_bow.tres") as WeaponData
	_level.player.move_started.emit(bow.chain[0], 1.0)
	for art in [&"slash_a", &"slash_b", &"slash_c"]:
		assert_int(_fx_of(art).size()).is_equal(0)


func test_a_longer_reaching_move_draws_its_arc_further_out_and_bigger() -> void:
	var player := _level.player
	var plain := WeaponMove.new()
	plain.fx = &"slash_a"
	player.move_started.emit(plain, 1.0)
	var far := WeaponMove.new()
	far.fx = &"slash_b"
	far.fx_forward_tiles = 2.0
	far.fx_scale = 2.0
	player.move_started.emit(far, 1.0)
	var near_arc = _fx_of(&"slash_a")[0]
	var far_arc = _fx_of(&"slash_b")[0]
	assert_float(far_arc.global_position.x - near_arc.global_position.x).is_greater(GameConfig.tiles(1.5))
	assert_float(far_arc.scale.x).is_greater(near_arc.scale.x * 1.5)


func test_a_landed_hit_sparks_shows_the_damage_and_shakes_the_screen() -> void:
	var enemy := _enemy()
	var shake: CameraShake = _level.get_node("Camera/CameraShake")
	_level.player.hit_landed.emit(enemy, 12)
	assert_int(_fx_of(&"spark").size()).is_equal(1)
	assert_float(_fx_of(&"spark")[0].global_position.distance_to(enemy.global_position)).is_less(40.0)
	var numbers := _numbers()
	assert_int(numbers.size()).is_equal(1)
	assert_str(numbers[0].text).is_equal("12")
	assert_float(shake.trauma).is_greater(0.0)


func test_a_heavier_hit_shakes_the_screen_more() -> void:
	var enemy := _enemy()
	var shake: CameraShake = _level.get_node("Camera/CameraShake")
	_level.player.hit_landed.emit(enemy, 3)
	var light := shake.trauma
	shake.trauma = 0.0
	_level.player.hit_landed.emit(enemy, 25)
	assert_float(shake.trauma).is_greater(light)


func test_a_dying_enemy_bursts() -> void:
	var enemy := _enemy()
	var spot := enemy.global_position
	enemy.take_hit(9999, spot.x - 10.0)
	assert_int(_fx_of(&"ring").size()).is_greater(0)
	assert_float(_fx_of(&"ring")[0].global_position.distance_to(spot)).is_less(40.0)
	assert_int(_fx_of(&"spark").size()).is_greater(0)


func test_a_parry_rings_out_and_a_perfect_one_is_bigger() -> void:
	var player := _level.player
	player.parried.emit(false)
	var plain := _fx_of(&"ring")
	assert_int(plain.size()).is_equal(1)
	player.parried.emit(true)
	var all := _fx_of(&"ring")
	assert_int(all.size()).is_equal(2)
	assert_float(absf(all[1].scale.x)).is_greater(absf(all[0].scale.x))


func test_enemies_spawned_later_are_watched_too() -> void:
	var enemy := _level.spawn_enemy(load("res://data/enemies/crown_guard.tres"))
	var before := _fx_of(&"ring").size()
	enemy.take_hit(9999, enemy.global_position.x - 5.0)
	assert_int(_fx_of(&"ring").size()).is_greater(before)


# --- the enemy flashes white when hit ---

func test_a_hit_enemy_flashes_white_then_settles() -> void:
	var enemy := _enemy()
	var art: AnimatedSprite2D = enemy.get_node("Art")
	var material := art.material as ShaderMaterial
	assert_float(material.get_shader_parameter(&"amount")).is_equal(0.0)
	enemy.take_hit(2, enemy.global_position.x - 10.0)
	await _frames(2)
	assert_float(material.get_shader_parameter(&"amount")).is_greater(0.5)
	await _frames(int(EnemyVisual.FLASH_SECONDS * 60.0) + 8)
	assert_float(material.get_shader_parameter(&"amount")).is_equal(0.0)


func test_the_screen_shakes_when_the_hero_is_hurt_but_not_when_he_heals() -> void:
	var shake: CameraShake = _level.get_node("Camera/CameraShake")
	var health: Health = _level.player.get_node("Health")
	health.take_damage(10)
	assert_float(shake.trauma).is_greater(0.0)
	shake.trauma = 0.0
	health.heal(5)
	assert_float(shake.trauma).is_equal(0.0)
