extends GdUnitTestSuite
## What the closing ring over a winding-up enemy says: red parry it, orange dodge it,
## yellow once the strike is committed.

func _enemy(parryable: bool) -> Enemy:
	var m := EnemyMove.new()
	m.kind = EnemyMove.Kind.MELEE
	m.telegraph_seconds = 0.5
	m.parryable = parryable
	var d := EnemyData.new()
	d.max_health = 100
	d.move_speed_tiles = 0.0
	d.moves = [m] as Array[EnemyMove]
	d.body_size_tiles = Vector2(1.0, 1.0)
	var enemy: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	add_child(enemy)
	enemy.configure(d)
	return enemy

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func test_a_parryable_wind_up_shows_the_red_tell() -> void:
	var enemy := _enemy(true)
	enemy.begin_telegraph()
	assert_object(enemy.tell_color()).is_equal(Enemy.TELL_COLOR)

func test_a_dodge_only_wind_up_shows_the_orange_tell() -> void:
	var enemy := _enemy(false)
	enemy.begin_telegraph()
	assert_object(enemy.tell_color()).is_equal(Enemy.TELL_DODGE_COLOR)

func test_a_committed_wind_up_shows_yellow() -> void:
	var enemy := _enemy(true)
	enemy.begin_telegraph()
	await _frames(int(0.5 * 60.0 * Enemy.COMMIT_FRACTION) + 5)
	assert_bool(enemy.is_committed()).is_true()
	assert_object(enemy.tell_color()).is_equal(Enemy.TELL_COMMITTED_COLOR)

func test_a_committed_dodge_only_wind_up_also_shows_yellow() -> void:
	var enemy := _enemy(false)
	enemy.begin_telegraph()
	await _frames(int(0.5 * 60.0 * Enemy.COMMIT_FRACTION) + 5)
	assert_object(enemy.tell_color()).is_equal(Enemy.TELL_COMMITTED_COLOR)

func test_there_is_no_tell_when_not_winding_up() -> void:
	assert_object(_enemy(true).tell_color()).is_equal(Color.TRANSPARENT)

func test_the_two_tells_are_different_colours() -> void:
	assert_object(Enemy.TELL_COLOR).is_not_equal(Enemy.TELL_DODGE_COLOR)
	assert_object(Enemy.TELL_DODGE_COLOR).is_not_equal(Enemy.TELL_COMMITTED_COLOR)
