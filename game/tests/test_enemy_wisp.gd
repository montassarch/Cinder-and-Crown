extends GdUnitTestSuite
## The real Ember Wisp against the real hero: parry its ember and it flies back.

func before_test() -> void:
	var floor_body: StaticBody2D = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(60.0, 1.0)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = GameConfig.tiles_v(10.0, 6.0)
	add_child(floor_body)

func after_test() -> void:
	InputRouter.set_virtual_button(&"parry", false)
	InputRouter.consume_parry()

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func test_parrying_a_wisp_bolt_damages_the_wisp_when_it_comes_back() -> void:
	var player: Player = auto_free(load("res://src/player/player.tscn").instantiate())
	player.position = GameConfig.tiles_v(0.0, 3.0)
	add_child(player)
	var wisp: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	add_child(wisp)
	wisp.configure(load("res://data/enemies/ember_wisp.tres"))
	wisp.global_position = GameConfig.tiles_v(7.0, 3.0)
	wisp.target = player
	await _frames(70)  # both settle on the floor; the wisp holds its range and winds up
	var pressed := false
	for i in 240:
		await _frames(1)
		for child in get_children():
			if child is EnemyProjectile and not child.is_reflected() and not pressed:
				if absf(child.global_position.x - player.global_position.x) < GameConfig.tiles(1.3):
					InputRouter.set_virtual_button(&"parry", true)
					await _frames(1)
					InputRouter.set_virtual_button(&"parry", false)
					pressed = true
		if pressed:
			break
	assert_bool(pressed).is_true()
	assert_int(player.get_node("Health").current).is_equal(100)
	await _frames(90)
	assert_int(wisp.health().current).is_less(wisp.data.max_health)
