extends GdUnitTestSuite

const DUMMY := preload("res://tests/support/hurtable_dummy.gd")
const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const SHIPPED := [
	"res://data/enemies/shambler.tres",
	"res://data/enemies/cinder_bat.tres",
	"res://data/enemies/crown_brute.tres",
]

func _fast_data(behaviour: EnemyData.Behaviour = EnemyData.Behaviour.CHASER) -> EnemyData:
	var d := EnemyData.new()
	d.display_name = "Test"
	d.max_health = 20
	d.move_speed_tiles = 3.0
	d.attack_damage = 7
	d.attack_range_tiles = 2.0
	d.telegraph_seconds = 0.05
	d.recovery_seconds = 0.05
	d.behaviour = behaviour
	d.body_size_tiles = Vector2(1.0, 1.0)
	return d

func _spawn(data: EnemyData) -> Enemy:
	var enemy: Enemy = auto_free(load(ENEMY_SCENE).instantiate())
	add_child(enemy)
	enemy.configure(data)
	return enemy

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _add_floor() -> void:
	var floor_body: StaticBody2D = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(80.0, 1.0)
	shape.shape = rect
	floor_body.add_child(shape)
	floor_body.position = GameConfig.tiles_v(0.0, 6.0)
	add_child(floor_body)

func test_all_three_shipped_enemies_load_from_disk() -> void:
	for path in SHIPPED:
		assert_object(load(path)).is_instanceof(EnemyData)
		assert_str(load(path).display_name).is_not_empty()

func test_shipped_enemies_have_positive_health_and_nonzero_telegraph() -> void:
	# A telegraph of 0 is unreadable and unfair; assert every enemy telegraphs.
	for path in SHIPPED:
		var d: EnemyData = load(path)
		assert_int(d.max_health).is_greater(0)
		assert_float(d.telegraph_seconds).is_greater(0.0)

func test_three_behaviours_are_all_represented_by_shipped_data() -> void:
	var seen := []
	for path in SHIPPED:
		seen.append(load(path).behaviour)
	assert_array(seen).contains_exactly_in_any_order([
		EnemyData.Behaviour.CHASER, EnemyData.Behaviour.FLYER, EnemyData.Behaviour.CHARGER])

func test_configure_sets_health_from_data() -> void:
	var enemy := _spawn(_fast_data())
	assert_int(enemy.health().max_health).is_equal(20)
	assert_int(enemy.health().current).is_equal(20)

func test_configure_before_entering_the_tree_still_applies() -> void:
	var enemy: Enemy = auto_free(load(ENEMY_SCENE).instantiate())
	enemy.configure(_fast_data())
	add_child(enemy)
	assert_int(enemy.health().current).is_equal(20)

func test_telegraph_releases_attack_after_telegraph_seconds() -> void:
	var enemy := _spawn(_fast_data())
	var released := []
	enemy.attack_released.connect(func(damage: int) -> void: released.append(damage))
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_true()
	assert_array(released).is_empty()
	await await_millis(200)
	assert_array(released).is_equal([7])
	assert_bool(enemy.is_telegraphing()).is_false()

func test_death_during_telegraph_cancels_the_attack() -> void:
	# Review Focus 4: kill mid-wind-up -> attack_released never fires.
	var enemy := _spawn(_fast_data())
	var released := []
	enemy.attack_released.connect(func(damage: int) -> void: released.append(damage))
	enemy.begin_telegraph()
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	await await_millis(200)
	assert_array(released).is_empty()
	assert_bool(enemy.is_telegraphing()).is_false()

func test_dead_enemy_cannot_begin_a_new_telegraph() -> void:
	var enemy := _spawn(_fast_data())
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	enemy.begin_telegraph()
	assert_bool(enemy.is_telegraphing()).is_false()

func test_death_emits_died_once() -> void:
	var enemy := _spawn(_fast_data())
	var deaths := [0]
	enemy.died.connect(func() -> void: deaths[0] += 1)
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	enemy.take_hit(999, enemy.global_position.x - 10.0)
	assert_int(deaths[0]).is_equal(1)

func test_take_hit_reduces_health() -> void:
	var enemy := _spawn(_fast_data())
	enemy.take_hit(5, enemy.global_position.x - 10.0)
	assert_int(enemy.health().current).is_equal(15)

func _enemy_with_target_at(offset_tiles: float) -> Array:
	var data := _fast_data()
	data.recovery_seconds = 5.0  # one swing only; the AI must not re-attack mid-test
	var enemy := _spawn(data)
	var foe: Node2D = auto_free(DUMMY.new())
	add_child(foe)
	foe.global_position = enemy.global_position + GameConfig.tiles_v(offset_tiles, 0.0)
	enemy.target = foe
	return [enemy, foe]

func test_release_hits_a_target_in_range() -> void:
	var pair := _enemy_with_target_at(1.0)
	pair[0].begin_telegraph()
	await await_millis(200)
	assert_int(pair[1].hits.size()).is_equal(1)
	assert_int(pair[1].hits[0][0]).is_equal(7)

func test_a_target_that_steps_out_of_range_during_the_telegraph_takes_nothing() -> void:
	var pair := _enemy_with_target_at(1.0)
	pair[0].begin_telegraph()
	pair[1].global_position = pair[0].global_position + GameConfig.tiles_v(10.0, 0.0)
	await await_millis(200)
	assert_int(pair[1].hits.size()).is_equal(0)

func test_chaser_walks_toward_its_target() -> void:
	_add_floor()
	var enemy := _spawn(_fast_data())
	enemy.global_position = GameConfig.tiles_v(0.0, 5.0)
	var target: Node2D = auto_free(DUMMY.new())
	add_child(target)
	target.global_position = GameConfig.tiles_v(12.0, 5.0)
	enemy.target = target
	await _frames(40)
	assert_float(enemy.global_position.x).is_greater(GameConfig.tiles(1.0))

func test_flyer_does_not_fall() -> void:
	var enemy := _spawn(_fast_data(EnemyData.Behaviour.FLYER))
	enemy.global_position = GameConfig.tiles_v(0.0, 0.0)
	await _frames(40)
	assert_float(enemy.global_position.y).is_less(GameConfig.tiles(2.0))

func test_charger_winds_up_when_target_is_in_trigger_range() -> void:
	_add_floor()
	var data := _fast_data(EnemyData.Behaviour.CHARGER)
	data.attack_range_tiles = 6.0
	data.telegraph_seconds = 0.5
	var enemy := _spawn(data)
	enemy.global_position = GameConfig.tiles_v(0.0, 5.0)
	var target: Node2D = auto_free(DUMMY.new())
	add_child(target)
	target.global_position = GameConfig.tiles_v(4.0, 5.0)
	enemy.target = target
	await _frames(10)
	assert_bool(enemy.is_telegraphing()).is_true()
