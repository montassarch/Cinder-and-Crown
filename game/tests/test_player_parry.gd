extends GdUnitTestSuite
## A timed parry deflects a strike, staggers the attacker and banks a stronger counter-hit.

const State := PlayerStateMachine.PlayerState
const TARGET := preload("res://tests/support/parry_target.gd")

var _player: Player
var _floor: StaticBody2D

func before_test() -> void:
	_floor = auto_free(StaticBody2D.new())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameConfig.tiles_v(40.0, 1.0)
	shape.shape = rect
	_floor.add_child(shape)
	_floor.position = GameConfig.tiles_v(0.0, 6.0)
	add_child(_floor)
	_player = load("res://src/player/player.tscn").instantiate()
	_player.position = GameConfig.tiles_v(0.0, 3.0)
	add_child(_player)

func after_test() -> void:
	_player.queue_free()
	for action in [&"attack", &"parry", &"roll"]:
		InputRouter.set_virtual_button(action, false)
	InputRouter.consume_attack()
	InputRouter.consume_parry()
	InputRouter.consume_roll()
	Engine.time_scale = 1.0

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _land() -> void:
	await _frames(60)

func _tap(action: StringName) -> void:
	InputRouter.set_virtual_button(action, true)
	await _frames(1)
	InputRouter.set_virtual_button(action, false)

func _health() -> Health:
	return _player.get_node("Health")

func _attacker() -> Node2D:
	var node: Node2D = auto_free(TARGET.new())
	add_child(node)
	node.global_position = _player.global_position + GameConfig.tiles_v(1.2, 0.0)
	return node

## A blade-range dummy to hit with the sword.
func _dummy() -> Node2D:
	var dummy: Node2D = auto_free(load("res://tests/support/hurtable_dummy.gd").new())
	add_child(dummy)
	dummy.global_position = _player.global_position + GameConfig.tiles_v(1.3, 0.0)
	return dummy

func _swing() -> void:
	await _tap(&"attack")
	await _frames(25)

func test_pressing_parry_enters_the_parry_state() -> void:
	await _land()
	await _tap(&"parry")
	await _frames(1)
	assert_int(_player.state()).is_equal(State.PARRY)

func test_a_strike_inside_the_window_is_deflected_without_damage() -> void:
	await _land()
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(8)
	_player.take_strike(20, enemy.global_position.x, enemy)
	assert_int(_health().current).is_equal(100)
	await _frames(2)
	assert_int(_player.state()).is_equal(State.PARRY)
	assert_int(enemy.parried.size()).is_equal(1)

func test_the_attacker_learns_which_side_it_was_parried_from() -> void:
	await _land()
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(5)
	_player.take_strike(20, enemy.global_position.x, enemy)
	assert_float(enemy.parried[0][1]).is_equal_approx(_player.global_position.x, 1.0)

func test_a_parry_right_on_time_is_perfect() -> void:
	await _land()
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(2)
	_player.take_strike(20, enemy.global_position.x, enemy)
	assert_bool(enemy.parried[0][0]).is_true()

func test_a_parry_late_in_the_window_still_works_but_is_not_perfect() -> void:
	await _land()
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(12)
	_player.take_strike(20, enemy.global_position.x, enemy)
	assert_int(_health().current).is_equal(100)
	assert_bool(enemy.parried[0][0]).is_false()

func test_a_strike_after_the_window_closes_hurts() -> void:
	await _land()
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(22)
	_player.take_strike(20, enemy.global_position.x, enemy)
	assert_int(_health().current).is_equal(80)
	assert_int(enemy.parried.size()).is_equal(0)

func test_a_strike_before_any_parry_hurts_as_always() -> void:
	await _land()
	var enemy := _attacker()
	_player.take_strike(20, enemy.global_position.x, enemy)
	assert_int(_health().current).is_equal(80)

func test_a_parried_strike_does_not_put_the_mask_on() -> void:
	await _land()
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(5)
	_player.take_strike(20, enemy.global_position.x, enemy)
	assert_float(_player.mask_seconds_left()).is_equal(0.0)

func test_parrying_announces_itself_with_its_quality() -> void:
	await _land()
	var enemy := _attacker()
	var seen := []
	_player.parried.connect(func(perfect: bool) -> void: seen.append(perfect))
	await _tap(&"parry")
	await _frames(2)
	_player.take_strike(20, enemy.global_position.x, enemy)
	assert_array(seen).is_equal([true])

func test_a_whiffed_parry_ends_then_idles() -> void:
	await _land()
	await _tap(&"parry")
	await _frames(int(Player.PARRY_DURATION * 60.0) + 6)
	assert_int(_player.state()).is_equal(State.IDLE)

func test_a_second_parry_must_wait_for_the_cooldown() -> void:
	await _land()
	await _tap(&"parry")
	await _frames(int(Player.PARRY_DURATION * 60.0) + 3)
	assert_int(_player.state()).is_equal(State.IDLE)
	await _tap(&"parry")
	await _frames(2)
	assert_int(_player.state()).is_not_equal(State.PARRY)
	await _frames(int(Player.PARRY_COOLDOWN * 60.0) + 4)
	await _tap(&"parry")
	await _frames(2)
	assert_int(_player.state()).is_equal(State.PARRY)

func test_after_a_successful_parry_attack_cuts_the_recovery_short() -> void:
	await _land()
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(3)
	_player.take_strike(20, enemy.global_position.x, enemy)
	await _tap(&"attack")
	await _frames(2)
	assert_int(_player.state()).is_equal(State.ATTACK)

# --- Riposte ---

func test_the_hit_after_a_parry_is_a_riposte_for_double_damage() -> void:
	await _land()
	var base: int = _player.weapon_in_slot(0).damage
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(12)
	_player.take_strike(20, enemy.global_position.x, enemy)
	var dummy := _dummy()
	await _swing()
	assert_int(dummy.hits.size()).is_equal(1)
	assert_int(dummy.hits[0][0]).is_equal(floori(base * Player.RIPOSTE_MULTIPLIER))

func test_a_perfect_parry_makes_the_riposte_hit_harder() -> void:
	await _land()
	var base: int = _player.weapon_in_slot(0).damage
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(2)
	_player.take_strike(20, enemy.global_position.x, enemy)
	var dummy := _dummy()
	await _swing()
	assert_int(dummy.hits[0][0]).is_equal(floori(base * Player.PERFECT_RIPOSTE_MULTIPLIER))
	assert_float(Player.PERFECT_RIPOSTE_MULTIPLIER).is_greater(Player.RIPOSTE_MULTIPLIER)

func test_only_one_hit_is_a_riposte() -> void:
	await _land()
	var base: int = _player.weapon_in_slot(0).damage
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(12)
	_player.take_strike(20, enemy.global_position.x, enemy)
	var dummy := _dummy()
	await _swing()
	await _frames(30)
	await _swing()
	assert_int(dummy.hits.size()).is_equal(2)
	assert_int(dummy.hits[1][0]).is_equal(base)

func test_the_riposte_window_expires() -> void:
	await _land()
	var base: int = _player.weapon_in_slot(0).damage
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(12)
	_player.take_strike(20, enemy.global_position.x, enemy)
	await _frames(int(Player.RIPOSTE_SECONDS * 60.0) + 10)
	var dummy := _dummy()
	await _swing()
	assert_int(dummy.hits[0][0]).is_equal(base)

func test_a_new_run_clears_a_banked_riposte() -> void:
	await _land()
	var base: int = _player.weapon_in_slot(0).damage
	var enemy := _attacker()
	await _tap(&"parry")
	await _frames(12)
	_player.take_strike(20, enemy.global_position.x, enemy)
	_player.start_new_run()
	_player.reset(GameConfig.tiles_v(0.0, 3.0))
	await _land()
	var dummy := _dummy()
	await _swing()
	assert_int(dummy.hits[0][0]).is_equal(base)

# --- Wiring with a real enemy ---

func test_a_real_enemy_striking_into_a_parry_is_staggered_and_the_hero_unhurt() -> void:
	await _land()
	var data := EnemyData.new()
	data.display_name = "Test"
	data.max_health = 30
	data.attack_damage = 12
	data.attack_range_tiles = 2.0
	data.telegraph_seconds = 0.3
	data.recovery_seconds = 0.3
	data.body_size_tiles = Vector2(1.0, 1.8)
	var enemy: Enemy = auto_free(load("res://src/enemies/enemy.tscn").instantiate())
	add_child(enemy)
	enemy.configure(data)
	enemy.global_position = _player.global_position + GameConfig.tiles_v(1.2, 0.0)
	enemy.target = _player
	enemy.begin_telegraph()
	await _frames(4)
	await _tap(&"parry")
	await _frames(int(0.3 * 60.0) + 2)
	assert_int(_health().current).is_equal(100)
	assert_bool(enemy.is_stunned()).is_true()
