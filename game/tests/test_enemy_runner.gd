extends GdUnitTestSuite
## The move runner: how an enemy plays EnemyMove attacks.

const ENEMY_SCENE := "res://src/enemies/enemy.tscn"
const RECORDER := preload("res://tests/support/strike_recorder.gd")

func _move(kind: EnemyMove.Kind = EnemyMove.Kind.MELEE, parryable: bool = true) -> EnemyMove:
	var m := EnemyMove.new()
	m.id = "test"
	m.kind = kind
	m.telegraph_seconds = 0.1
	m.active_seconds = 0.1
	m.recovery_seconds = 0.1
	m.damage = 7
	m.reach_tiles = 2.0
	m.speed_tiles = 6.0
	m.range_tiles = 8.0
	m.parryable = parryable
	return m

func _data(moves: Array[EnemyMove] = []) -> EnemyData:
	var d := EnemyData.new()
	d.display_name = "Test"
	d.max_health = 100
	d.move_speed_tiles = 0.0
	d.attack_range_tiles = 2.0
	d.moves = moves
	d.body_size_tiles = Vector2(1.0, 1.0)
	return d

func _spawn(data: EnemyData) -> Enemy:
	var enemy: Enemy = auto_free(load(ENEMY_SCENE).instantiate())
	add_child(enemy)
	enemy.configure(data)
	return enemy

func _victim_beside(enemy: Enemy) -> Node2D:
	var victim: Node2D = auto_free(RECORDER.new())
	add_child(victim)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(1.0, 0.0)
	enemy.target = victim
	return victim

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func test_the_current_move_is_set_while_winding_up_and_cleared_after_recovery() -> void:
	var enemy := _spawn(_data([_move()] as Array[EnemyMove]))
	assert_object(enemy.current_move()).is_null()
	enemy.begin_telegraph()
	assert_object(enemy.current_move()).is_not_null()
	assert_int(enemy.current_move().kind).is_equal(EnemyMove.Kind.MELEE)
	assert_int(enemy.move_index()).is_equal(0)
	await _frames(40)
	assert_object(enemy.current_move()).is_null()

func test_an_enemy_without_moves_plays_its_implicit_move() -> void:
	var enemy := _spawn(_data())
	enemy.begin_telegraph()
	assert_str(enemy.current_move().id).is_equal("implicit")

func test_a_parryable_move_hits_through_take_strike() -> void:
	var enemy := _spawn(_data([_move(EnemyMove.Kind.MELEE, true)] as Array[EnemyMove]))
	var victim := _victim_beside(enemy)
	enemy.begin_telegraph()
	await _frames(20)
	assert_int(victim.strikes.size()).is_equal(1)
	assert_int(victim.strikes[0][0]).is_equal(7)
	assert_int(victim.hits.size()).is_equal(0)

func test_a_non_parryable_move_hits_through_take_hit_not_take_strike() -> void:
	var enemy := _spawn(_data([_move(EnemyMove.Kind.MELEE, false)] as Array[EnemyMove]))
	var victim := _victim_beside(enemy)
	enemy.begin_telegraph()
	await _frames(20)
	assert_int(victim.hits.size()).is_equal(1)
	assert_int(victim.hits[0][0]).is_equal(7)
	assert_int(victim.strikes.size()).is_equal(0)

func test_a_dash_move_rushes_and_hits_on_contact_without_being_parryable() -> void:
	var dash := _move(EnemyMove.Kind.DASH, false)
	dash.reach_tiles = 1.2
	dash.speed_tiles = 20.0
	dash.active_seconds = 0.2  # 4 tiles of rush: enough to reach a hero 3 tiles away
	var data := _data([dash] as Array[EnemyMove])
	data.behaviour = EnemyData.Behaviour.FLYER  # no gravity, so the test needs no floor
	var enemy := _spawn(data)
	var victim := _victim_beside(enemy)
	victim.global_position = enemy.global_position + GameConfig.tiles_v(3.0, 0.0)
	enemy.begin_telegraph()
	await _frames(22)  # one rush: hit lands around frame 12, the next attack cannot start before frame 30
	assert_int(victim.hits.size()).is_equal(1)
	assert_int(victim.strikes.size()).is_equal(0)
