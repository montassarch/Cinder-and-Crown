extends GdUnitTestSuite
## The slam's shockwave: a thin strip racing along the floor that a hero in the air passes over.
## The floor's top is y = 0 in these tests.

const RECORDER := preload("res://tests/support/strike_recorder.gd")

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

## A stand-in hero with `boxes` hurtboxes (layer 8), its feet at `feet_y`.
func _hero_at(x: float, feet_y: float, boxes: int = 1) -> Node2D:
	var hero: Node2D = auto_free(RECORDER.new())
	add_child(hero)
	hero.global_position = Vector2(x, 0.0)
	for i in boxes:
		var area := Area2D.new()
		area.collision_layer = 8
		area.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16.0, 32.0)
		shape.shape = rect
		area.add_child(shape)
		area.position = Vector2(0.0, feet_y - 16.0)
		hero.add_child(area)
	return hero

func _wave(direction: float = 1.0, speed_px: float = 200.0, range_px: float = 1000.0, damage: int = 9) -> FloorWave:
	var wave: FloorWave = auto_free(FloorWave.new())
	add_child(wave)
	wave.global_position = Vector2(0.0, -3.0)
	wave.launch(direction, speed_px, range_px, damage)
	return wave

func test_a_wave_hurts_a_hero_standing_on_the_floor() -> void:
	var hero := _hero_at(60.0, 0.0)
	_wave()
	await _frames(30)
	assert_int(hero.hits.size()).is_equal(1)
	assert_int(hero.hits[0][0]).is_equal(9)
	assert_int(hero.strikes.size()).is_equal(0)

func test_a_wave_misses_a_hero_who_is_jumping() -> void:
	var hero := _hero_at(60.0, -24.0)  # feet well above the strip
	_wave()
	await _frames(30)
	assert_int(hero.hits.size()).is_equal(0)

func test_a_wave_hurts_only_once() -> void:
	var hero := _hero_at(60.0, 0.0, 2)  # two hurtboxes: two entry events
	_wave()
	await _frames(40)
	assert_int(hero.hits.size()).is_equal(1)

func test_a_wave_goes_left_when_launched_left() -> void:
	var hero := _hero_at(-60.0, 0.0)
	_wave(-1.0)
	await _frames(30)
	assert_int(hero.hits.size()).is_equal(1)

func test_a_wave_is_freed_after_its_range() -> void:
	var wave := _wave(1.0, 200.0, 40.0)
	await _frames(40)
	assert_bool(not is_instance_valid(wave) or wave.is_queued_for_deletion()).is_true()

func test_a_wave_cannot_be_parried_by_the_real_hero() -> void:
	var floor_body: StaticBody2D = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(40.0, 1.0)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = GameConfig.tiles_v(0.0, 6.0)
	add_child(floor_body)
	var player: Player = auto_free(load("res://src/player/player.tscn").instantiate())
	player.position = GameConfig.tiles_v(0.0, 3.0)
	add_child(player)
	await _frames(60)
	InputRouter.set_virtual_button(&"parry", true)
	await _frames(1)
	InputRouter.set_virtual_button(&"parry", false)
	await _frames(3)
	assert_int(player.state()).is_equal(PlayerStateMachine.PlayerState.PARRY)
	var wave: FloorWave = auto_free(FloorWave.new())
	add_child(wave)
	wave.global_position = player.global_position + Vector2(-20.0, 16.0 - 3.0)
	wave.launch(1.0, 200.0, 500.0, 12)
	await _frames(20)
	assert_int(player.get_node("Health").current).is_less(100)
	InputRouter.consume_parry()
