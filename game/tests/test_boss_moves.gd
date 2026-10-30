extends GdUnitTestSuite
## What bosses do that other enemies do not: floor hazards, summons and a second phase.

const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const RECORDER := preload("res://tests/support/strike_recorder.gd")
const SHAMBLER := "res://data/enemies/shambler.tres"


func after_test() -> void:
	for child in get_children():
		if child is GroundHazard or child is Enemy:
			child.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _hazard_move(count: int = 3) -> EnemyMove:
	var m := EnemyMove.new()
	m.id = "pillars"
	m.kind = EnemyMove.Kind.HAZARD
	m.telegraph_seconds = 0.3
	m.active_seconds = 0.3
	m.recovery_seconds = 0.2
	m.damage = 11
	m.reach_tiles = 1.0
	m.count = count
	m.spacing_tiles = 4.0
	m.hazard_art = &"fire_pillar"
	m.parryable = false
	return m


func _summon_move(count: int = 2) -> EnemyMove:
	var m := EnemyMove.new()
	m.id = "call"
	m.kind = EnemyMove.Kind.SUMMON
	m.telegraph_seconds = 0.2
	m.recovery_seconds = 0.2
	m.count = count
	m.summon = load(SHAMBLER)
	m.parryable = false
	return m


func _data(moves: Array[EnemyMove], phase_two: Array[EnemyMove] = []) -> EnemyData:
	var d := EnemyData.new()
	d.display_name = "Boss"
	d.max_health = 100
	d.move_speed_tiles = 0.0
	d.attack_range_tiles = 30.0
	d.moves = moves
	d.phase_two_moves = phase_two
	d.body_size_tiles = Vector2(1.0, 1.0)
	return d


func _hero(x: float) -> Node2D:
	var hero: Node2D = auto_free(RECORDER.new())
	add_child(hero)
	hero.global_position = Vector2(x, 0.0)
	return hero


func _spawn(data: EnemyData, hero: Node2D) -> Enemy:
	var enemy: Enemy = load(ENEMY_SCENE).instantiate()
	add_child(enemy)
	enemy.configure(data)
	enemy.target = hero
	enemy.set_physics_process(false)
	return enemy


func _hazards() -> Array:
	return get_children().filter(func(n: Node) -> bool: return n is GroundHazard and not n.is_queued_for_deletion())


## The suite stands in for a level: summons ask it for enemies.
func spawn_enemy_at(data: EnemyData, at: Vector2) -> Enemy:
	var enemy: Enemy = load(ENEMY_SCENE).instantiate()
	add_child(enemy)
	enemy.configure(data)
	enemy.global_position = at
	enemy.set_physics_process(false)
	return enemy


# ------------------------------------------------------------------ data

func test_hazard_and_summon_moves_need_their_numbers_and_cannot_be_parried() -> void:
	assert_bool(_hazard_move().is_valid()).is_true()
	assert_bool(_summon_move().is_valid()).is_true()
	var no_art := _hazard_move()
	no_art.hazard_art = &""
	assert_bool(no_art.is_valid()).is_false()
	var parry := _hazard_move()
	parry.parryable = true
	assert_bool(parry.is_valid()).is_false()
	var nobody := _summon_move()
	nobody.summon = null
	assert_bool(nobody.is_valid()).is_false()


# ------------------------------------------------------------------ hazards

func test_a_hazard_warns_then_hurts_a_hero_standing_in_it_once() -> void:
	var hero := _hero(0.0)
	var hazard := GroundHazard.spawn(self, &"fire_pillar", Vector2(0.0, 8.0), 16.0, 64.0, 0.2, 0.3, 9, 40.0, hero)
	assert_bool(hazard.is_warning()).is_true()
	await _frames(6)
	assert_int(hero.hits.size()).is_equal(0)          # a warning never hurts
	await _frames(14)
	assert_bool(hazard.is_active()).is_true()
	assert_int(hero.hits.size()).is_equal(1)
	assert_int(hero.hits[0][0]).is_equal(9)
	await _frames(10)
	assert_int(hero.hits.size()).is_equal(1)          # once


func test_a_hero_beside_a_hazard_is_not_hurt() -> void:
	var hero := _hero(60.0)
	GroundHazard.spawn(self, &"fire_pillar", Vector2(0.0, 8.0), 16.0, 64.0, 0.1, 0.3, 9, 40.0, hero)
	await _frames(30)
	assert_int(hero.hits.size()).is_equal(0)


func test_a_hazard_clears_itself_away() -> void:
	var hero := _hero(200.0)
	GroundHazard.spawn(self, &"lightning_strike", Vector2(0.0, 8.0), 16.0, 64.0, 0.1, 0.2, 9, 40.0, hero)
	await _frames(90)
	assert_int(_hazards().size()).is_equal(0)


func test_a_hazard_move_marks_spots_round_the_hero_as_the_wind_up_starts() -> void:
	var hero := _hero(100.0)
	var boss := _spawn(_data([_hazard_move(3)]), hero)
	boss.begin_telegraph()
	var spots := _hazards()
	assert_int(spots.size()).is_equal(3)
	var xs := spots.map(func(h: GroundHazard) -> float: return h.global_position.x)
	xs.sort()
	assert_float(xs[1]).is_equal_approx(100.0, 0.5)
	assert_float(xs[2] - xs[1]).is_equal_approx(GameConfig.tiles(4.0), 0.5)
	for h in spots:
		assert_bool(h.is_warning()).is_true()


func test_a_hazard_move_hurts_a_hero_who_stays_put() -> void:
	var hero := _hero(100.0)
	var boss := _spawn(_data([_hazard_move(1)]), hero)
	boss.begin_telegraph()
	await _frames(40)
	assert_int(hero.hits.size()).is_equal(1)
	assert_int(hero.strikes.size()).is_equal(0)      # it is not a parryable strike


# ------------------------------------------------------------------ summons

func test_a_summon_brings_enemies_through_the_level() -> void:
	var hero := _hero(100.0)
	var boss := _spawn(_data([_summon_move(2)]), hero)
	boss.begin_telegraph()
	await _frames(20)
	var shamblers := get_children().filter(func(n: Node) -> bool: return n is Enemy and n.data.display_name == "Shambler")
	assert_int(shamblers.size()).is_equal(2)
	for s in shamblers:
		assert_object(s.target).is_same(hero)


func test_a_summon_holds_back_when_the_room_is_already_crowded() -> void:
	var hero := _hero(100.0)
	var boss := _spawn(_data([_summon_move(3)]), hero)
	for i in Enemy.SUMMON_CAP:
		spawn_enemy_at(load(SHAMBLER), Vector2(300.0 + i * 20.0, 0.0))
	boss.begin_telegraph()
	await _frames(20)
	var alive := get_children().filter(func(n: Node) -> bool: return n is Enemy and not n.is_dead())
	assert_int(alive.size()).is_less_equal(Enemy.SUMMON_CAP + 1)


# ------------------------------------------------------------------ phases

func test_below_half_health_a_boss_switches_to_its_second_phase_once() -> void:
	var hero := _hero(100.0)
	var first: Array[EnemyMove] = [_hazard_move(1)]
	var second: Array[EnemyMove] = [_summon_move(1)]
	var boss := _spawn(_data(first, second), hero)
	var changes := []
	boss.phase_changed.connect(func(phase: int) -> void: changes.append(phase))
	assert_int(boss.phase()).is_equal(1)
	boss.take_hit(40, 0.0)
	assert_int(boss.phase()).is_equal(1)
	boss.take_hit(15, 0.0)
	assert_int(boss.phase()).is_equal(2)
	boss.take_hit(5, 0.0)
	assert_array(changes).is_equal([2])
	assert_object(boss.moves()[0]).is_same(second[0])


func test_an_enemy_without_a_second_phase_keeps_its_moves() -> void:
	var hero := _hero(100.0)
	var only: Array[EnemyMove] = [_hazard_move(1)]
	var boss := _spawn(_data(only), hero)
	boss.take_hit(80, 0.0)
	assert_int(boss.phase()).is_equal(1)
	assert_object(boss.moves()[0]).is_same(only[0])


func test_a_boss_is_not_knocked_about_by_hits() -> void:
	var hero := _hero(100.0)
	var data := _data([_hazard_move(1)])
	data.boss = true
	var boss := _spawn(data, hero)
	boss.take_hit(5, -50.0, 6.0)
	assert_float(boss._knockback_x).is_equal(0.0)


func _melee_move() -> EnemyMove:
	var m := EnemyMove.new()
	m.id = "sweep"
	m.kind = EnemyMove.Kind.MELEE
	m.telegraph_seconds = 0.3
	m.active_seconds = 0.1
	m.recovery_seconds = 0.2
	m.damage = 5
	m.reach_tiles = 2.0
	return m


func test_a_boss_far_from_the_hero_only_picks_moves_that_reach_him() -> void:
	var hero := _hero(GameConfig.tiles(7.0))
	var data := _data([_melee_move(), _hazard_move(1)])
	data.boss = true
	data.pattern = EnemyData.Pattern.RANDOM
	var boss := _spawn(data, hero)
	for i in 30:
		boss.rng.seed = i
		boss._state = Enemy.State.MOVE
		boss._rest_left = 0.0
		boss.begin_telegraph()
		assert_int(boss.current_move().kind).is_equal(EnemyMove.Kind.HAZARD)
		boss._telegraph_timer.stop()
		for h in _hazards():
			h.free()


func test_a_boss_with_nothing_in_reach_keeps_walking_at_the_hero() -> void:
	var hero := _hero(GameConfig.tiles(6.0))
	var data := _data([_melee_move()])
	data.boss = true
	data.move_speed_tiles = 2.0
	data.attack_range_tiles = 8.0
	var boss := _spawn(data, hero)
	var vx: float = boss._think_move(hero, 0.016)
	assert_float(vx).is_greater(0.0)
	assert_int(boss._state).is_equal(Enemy.State.MOVE)
