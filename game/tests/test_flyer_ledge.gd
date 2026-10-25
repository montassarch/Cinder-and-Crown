extends GdUnitTestSuite
## A flyer must not hover on a ledge over the hero's head, winding up dives it cannot make:
## it slides off the ledge until it has a clear line, and only then attacks.

const HERO_POS := Vector2(0.0, 0.0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ledge() -> StaticBody2D:
	var body: StaticBody2D = auto_free(StaticBody2D.new())
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(160.0, 8.0)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(0.0, -40.0)
	add_child(body)
	return body


func _hero() -> Node2D:
	var hero: Node2D = auto_free(load("res://tests/support/hurtable_dummy.gd").new())
	hero.position = HERO_POS
	add_child(hero)
	return hero


func _bat(hero: Node2D, at: Vector2) -> Enemy:
	var bat: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	bat.data = load("res://data/enemies/cinder_bat.tres")
	bat.target = hero
	add_child(bat)
	bat.global_position = at
	return bat


func test_a_ledge_between_a_bat_and_the_hero_blocks_the_path() -> void:
	_ledge()
	var hero := _hero()
	var bat := _bat(hero, Vector2(0.0, -70.0))
	assert_bool(bat.has_clear_path_to(hero)).is_false()
	var free_bat := _bat(hero, Vector2(200.0, -40.0))
	assert_bool(free_bat.has_clear_path_to(hero)).is_true()


func test_a_bat_does_not_wind_up_a_dive_through_a_ledge() -> void:
	_ledge()
	var hero := _hero()
	var bat := _bat(hero, Vector2(0.0, -70.0))
	await _frames(30)
	assert_int(bat._state).is_equal(Enemy.State.MOVE)


func test_a_bat_slides_off_the_ledge_until_it_has_a_clear_line() -> void:
	_ledge()
	var hero := _hero()
	var bat := _bat(hero, Vector2(0.0, -70.0))
	var cleared := false
	for i in 480:
		await get_tree().physics_frame
		if bat.has_clear_path_to(hero):
			cleared = true
			break
	assert_bool(cleared).is_true()


func test_with_nothing_in_the_way_a_bat_still_dives() -> void:
	var hero := _hero()
	var bat := _bat(hero, Vector2(0.0, -50.0))
	await _frames(20)
	assert_int(bat._state).is_equal(Enemy.State.TELEGRAPH)
