extends GdUnitTestSuite
## An ember an enemy throws: it flies straight, hurts the hero through take_strike (so it can be
## parried), and a parry sends it back at the enemies for more damage.

const RECORDER := preload("res://tests/support/strike_recorder.gd")
const DUMMY := preload("res://tests/support/hurtable_dummy.gd")
const SAVE_PATH := "user://test_projectile_meta.json"

func after_test() -> void:
	get_tree().paused = false
	MetaSave.path = MetaSave.DEFAULT_PATH

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _shot(direction: float = 1.0, speed_px: float = 200.0, max_px: float = 1000.0, damage: int = 5) -> EnemyProjectile:
	var p: EnemyProjectile = auto_free(EnemyProjectile.new())
	add_child(p)
	p.global_position = Vector2.ZERO
	p.launch(direction, speed_px, max_px, damage, null)
	return p

## A stand-in hero: records strikes, with a hurtbox on the hero's hurtbox layer.
func _hero_at(x: float, parry_it: bool = false) -> Node2D:
	var hero: Node2D = auto_free(RECORDER.new())
	hero.parry_it = parry_it
	add_child(hero)
	hero.global_position = Vector2(x, 0.0)
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16.0, 32.0)
	shape.shape = rect
	area.add_child(shape)
	hero.add_child(area)
	return hero

func _enemy_at(x: float) -> Node2D:
	var dummy: Node2D = auto_free(DUMMY.new())
	add_child(dummy)
	dummy.global_position = Vector2(x, 0.0)
	return dummy

func test_it_flies_at_its_speed_in_its_direction() -> void:
	var p := _shot(1.0, 200.0)
	await _frames(30)
	assert_float(p.global_position.x).is_between(90.0, 110.0)
	var q := _shot(-1.0, 200.0)
	await _frames(30)
	assert_float(q.global_position.x).is_between(-110.0, -90.0)

func test_it_frees_itself_past_its_range() -> void:
	var p := _shot(1.0, 200.0, 50.0)
	await _frames(40)
	assert_bool(not is_instance_valid(p) or p.is_queued_for_deletion()).is_true()

func test_it_frees_itself_on_a_wall() -> void:
	var wall: StaticBody2D = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8.0, 64.0)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(60.0, 0.0)
	add_child(wall)
	var p := _shot(1.0, 200.0, 5000.0)
	await _frames(30)
	assert_bool(not is_instance_valid(p) or p.is_queued_for_deletion()).is_true()

func test_it_hurts_the_hero_through_take_strike() -> void:
	var hero := _hero_at(60.0)
	var p := _shot(1.0, 200.0, 1000.0, 8)
	await _frames(30)
	assert_int(hero.strikes.size()).is_equal(1)
	assert_int(hero.strikes[0][0]).is_equal(8)
	assert_object(hero.strikes[0][2]).is_same(p)
	assert_bool(not is_instance_valid(p) or p.is_queued_for_deletion()).is_true()

func test_a_parry_sends_it_back_and_it_then_hits_enemies_not_the_hero() -> void:
	var hero := _hero_at(60.0, true)
	var enemy := _enemy_at(-60.0)
	var p := _shot(1.0, 200.0, 1000.0, 5)
	await _frames(60)
	assert_int(hero.strikes.size()).is_equal(1)  # the hero is struck once, never again
	assert_int(enemy.hits.size()).is_equal(1)
	assert_bool(not is_instance_valid(p) or p.is_queued_for_deletion()).is_true()

func test_a_reflected_projectile_deals_double_damage() -> void:
	var enemy := _enemy_at(-60.0)
	var p := _shot(1.0, 200.0, 1000.0, 5)
	p.on_parried(false, 0.0)
	await _frames(40)
	assert_int(enemy.hits[0][0]).is_equal(10)

func test_a_perfectly_parried_projectile_deals_triple_damage() -> void:
	var enemy := _enemy_at(-60.0)
	var p := _shot(1.0, 200.0, 1000.0, 5)
	p.on_parried(true, 0.0)
	await _frames(40)
	assert_int(enemy.hits[0][0]).is_equal(15)

func test_a_reflected_shot_that_kills_the_last_enemy_pays_cells_and_opens_the_gate() -> void:
	MetaSave.path = SAVE_PATH
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(SAVE_PATH + suffix)
	MetaSave.path = SAVE_PATH
	var level: GeneratedLevel = auto_free(load("res://levels/generated_level.tscn").instantiate())
	level.level_seed = 7
	level.room_count = 5
	add_child(level)
	await _frames(10)
	var start := 0.0
	for room in level.layout().slice(0, 1):
		start += room.size_tiles.x
	level.player.global_position = GameConfig.tiles_v(start + 4.0, 10.0)
	await _frames(5)
	var enemies: Array[Enemy] = []
	for child in level.get_children():
		if child is Enemy:
			enemies.append(child)
	assert_int(enemies.size()).is_greater(0)
	for i in range(1, enemies.size()):
		enemies[i].take_hit(9999, enemies[i].global_position.x - 10.0)
	var last := enemies[0]
	last.health().current = 1
	var before := MetaSave.cells()
	var shot: EnemyProjectile = auto_free(EnemyProjectile.new())
	level.add_child(shot)
	shot.global_position = last.global_position + Vector2(-40.0, 0.0)
	shot.launch(1.0, 200.0, 1000.0, 1, null)
	shot.on_parried(false, 0.0)
	shot.global_position = last.global_position + Vector2(40.0, 0.0)
	await _frames(30)
	assert_bool(last.is_dead()).is_true()
	assert_int(level.enemy_count()).is_equal(0)
	assert_int(MetaSave.cells()).is_greater(before)

func test_a_move_can_colour_its_shot() -> void:
	var data := EnemyData.new()
	var move := EnemyMove.new()
	move.id = "blue"
	move.kind = EnemyMove.Kind.PROJECTILE
	move.speed_tiles = 5.0
	move.range_tiles = 5.0
	move.tint = Color(0.4, 0.7, 1.0)
	data.moves = [move]
	var enemy: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	add_child(enemy)
	enemy.configure(data)
	enemy._fire_projectile(move)
	var shots := get_children().filter(func(n: Node) -> bool: return n is EnemyProjectile)
	assert_int(shots.size()).is_equal(1)
	assert_object(shots[0].color).is_equal(Color(0.4, 0.7, 1.0))

func test_a_shot_without_a_colour_is_an_ember() -> void:
	var p := _shot()
	assert_object(p.color).is_equal(EnemyProjectile.COLOR)
