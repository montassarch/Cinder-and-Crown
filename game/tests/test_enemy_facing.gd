extends GdUnitTestSuite
## An enemy looks at the hero while it walks toward him (not only when it winds up an attack).

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _hero(x: float) -> Node2D:
	var hero: Node2D = auto_free(load("res://tests/support/hurtable_dummy.gd").new())
	hero.position = Vector2(x, 0.0)
	add_child(hero)
	return hero


func _enemy(id: String, hero: Node2D, x: float) -> Enemy:
	var enemy: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	enemy.data = load("res://data/enemies/%s.tres" % id)
	enemy.target = hero
	add_child(enemy)
	enemy.global_position = Vector2(x, 0.0)
	return enemy


func test_an_enemy_to_the_right_of_the_hero_faces_left_as_it_walks_to_him() -> void:
	var hero := _hero(0.0)
	var enemy := _enemy("shambler", hero, 300.0)
	await _frames(5)
	assert_float(enemy.facing()).is_equal(-1.0)


func test_an_enemy_to_the_left_of_the_hero_faces_right() -> void:
	var hero := _hero(0.0)
	var enemy := _enemy("shambler", hero, -300.0)
	await _frames(5)
	assert_float(enemy.facing()).is_equal(1.0)


func test_the_enemy_turns_round_when_the_hero_crosses_over() -> void:
	var hero := _hero(0.0)
	var enemy := _enemy("shambler", hero, 300.0)
	await _frames(5)
	hero.position.x = 600.0
	await _frames(5)
	assert_float(enemy.facing()).is_equal(1.0)


func test_a_ranged_enemy_that_backs_away_still_faces_the_hero() -> void:
	var hero := _hero(0.0)
	var wisp := _enemy("ember_wisp", hero, 40.0)   # closer than it likes: it retreats to the right
	await _frames(10)
	assert_float(wisp.velocity.x).is_greater(0.0)
	assert_float(wisp.facing()).is_equal(-1.0)


func test_a_committed_attack_keeps_its_direction_when_the_hero_leaps_over() -> void:
	var hero := _hero(0.0)
	var enemy := _enemy("shambler", hero, 20.0)
	enemy.begin_telegraph()
	assert_float(enemy.facing()).is_equal(-1.0)
	hero.position.x = 200.0   # the hero is now behind it
	await _frames(5)
	assert_float(enemy.facing()).is_equal(-1.0)
