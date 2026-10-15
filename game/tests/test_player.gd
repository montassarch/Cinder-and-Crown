extends GdUnitTestSuite
## Wiring check for player.tscn: real physics, real scene, virtual input.

const State := PlayerStateMachine.PlayerState

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
	for action in [&"jump", &"attack", &"roll"]:
		InputRouter.set_virtual_button(action, false)
	InputRouter.consume_jump()
	InputRouter.consume_attack()
	InputRouter.consume_roll()

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _land() -> void:
	await _frames(60)

func test_player_falls_and_settles_idle_on_the_floor() -> void:
	await _land()
	assert_bool(_player.is_on_floor()).is_true()
	assert_int(_player.state()).is_equal(State.IDLE)

func test_jump_input_lifts_the_player() -> void:
	await _land()
	var ground_y := _player.position.y
	InputRouter.set_virtual_button(&"jump", true)
	await _frames(10)
	assert_float(_player.position.y).is_less(ground_y - GameConfig.tiles(0.5))
	assert_int(_player.state()).is_equal(State.JUMP)

func test_roll_grants_iframes_then_ends() -> void:
	await _land()
	InputRouter.set_virtual_button(&"roll", true)
	await _frames(5)
	assert_int(_player.state()).is_equal(State.ROLL)
	assert_bool(_player.is_invincible()).is_true()
	InputRouter.set_virtual_button(&"roll", false)
	await _frames(30)
	assert_bool(_player.is_invincible()).is_false()
	assert_int(_player.state()).is_equal(State.IDLE)

func test_hit_outside_a_roll_staggers_and_costs_health() -> void:
	await _land()
	_player.take_hit(10, _player.global_position.x - 20.0)
	await _frames(2)
	assert_int(_player.state()).is_equal(State.HURT)
	assert_int(_player.get_node("Health").current).is_equal(90)

func test_hit_during_iframes_is_ignored() -> void:
	await _land()
	InputRouter.set_virtual_button(&"roll", true)
	await _frames(5)
	_player.take_hit(10, _player.global_position.x - 20.0)
	assert_int(_player.get_node("Health").current).is_equal(100)
	assert_int(_player.state()).is_equal(State.ROLL)

func test_player_starts_with_blade_in_slot_zero_and_spear_in_slot_one() -> void:
	assert_str(_player.weapon_in_slot(0).display_name).is_equal("Rusty Blade")
	assert_str(_player.weapon_in_slot(1).display_name).is_equal("Ember Spear")
	assert_int(_player.active_slot()).is_equal(0)

func test_swap_is_always_allowed_and_toggles_slots() -> void:
	_player.swap_weapons()
	assert_int(_player.active_slot()).is_equal(1)
	_player.swap_weapons()
	assert_int(_player.active_slot()).is_equal(0)

func test_swap_input_toggles_slots() -> void:
	await _land()
	Input.action_press("swap_weapon")
	await _frames(2)
	Input.action_release("swap_weapon")
	assert_int(_player.active_slot()).is_equal(1)

func test_attack_input_opens_the_equipped_weapons_hitbox_during_its_window() -> void:
	await _land()
	var weapon: Weapon = _player.get_node("Weapon")
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(2)
	assert_int(_player.state()).is_equal(State.ATTACK)
	assert_bool(weapon.is_hitbox_active()).is_false()
	await _frames(8)
	assert_bool(weapon.is_hitbox_active()).is_true()
	InputRouter.set_virtual_button(&"attack", false)

func test_swapping_mid_swing_leaves_no_live_hitbox() -> void:
	await _land()
	var weapon: Weapon = _player.get_node("Weapon")
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(10)
	InputRouter.set_virtual_button(&"attack", false)
	assert_bool(weapon.is_hitbox_active()).is_true()
	_player.swap_weapons()
	assert_bool(weapon.is_hitbox_active()).is_false()

func test_reset_restores_health_position_and_idle_state() -> void:
	await _land()
	_player.take_hit(30, _player.global_position.x - 10.0)
	await _frames(2)
	assert_int(_player.state()).is_equal(State.HURT)
	var spot := GameConfig.tiles_v(2.0, 3.0)
	_player.reset(spot)
	assert_vector(_player.global_position).is_equal(spot)
	assert_int(_player.get_node("Health").current).is_equal(100)
	assert_int(_player.state()).is_equal(State.IDLE)
	assert_vector(_player.velocity).is_equal(Vector2.ZERO)

func test_a_dead_player_ignores_input() -> void:
	await _land()
	_player.take_hit(999, _player.global_position.x - 10.0)
	var x_before := _player.global_position.x
	InputRouter.set_virtual_axis(1.0)
	await _frames(20)
	InputRouter.set_virtual_axis(0.0)
	assert_float(_player.global_position.x).is_equal_approx(x_before, 1.0)

func _peak_rise_tiles(hold_frames: int) -> float:
	await _land()
	var ground_y := _player.position.y
	var peak := ground_y
	InputRouter.set_virtual_button(&"jump", true)
	for i in 50:
		await get_tree().physics_frame
		if i == hold_frames:
			InputRouter.set_virtual_button(&"jump", false)
		peak = minf(peak, _player.position.y)
	return (ground_y - peak) / GameConfig.TILE_SIZE

func test_holding_jump_reaches_the_full_jump_height() -> void:
	var rise: float = await _peak_rise_tiles(49)
	assert_float(rise).is_between(Player.JUMP_HEIGHT * 0.9, Player.JUMP_HEIGHT * 1.05)

func test_tapping_jump_gives_a_short_hop_not_nothing() -> void:
	# Releasing jump while rising damps the rise every frame, so a tap hops (~0.8 tile measured).
	var rise: float = await _peak_rise_tiles(1)
	assert_float(rise).is_between(0.6, 1.6)

func test_jump_height_grows_with_how_long_jump_is_held() -> void:
	var tap: float = await _peak_rise_tiles(1)
	_player.reset(GameConfig.tiles_v(0.0, 3.0))
	var medium: float = await _peak_rise_tiles(4)
	_player.reset(GameConfig.tiles_v(0.0, 3.0))
	var long_hold: float = await _peak_rise_tiles(8)
	assert_float(medium).is_greater(tap + 0.3)
	assert_float(long_hold).is_greater(medium + 0.3)

func test_hero_plays_the_animation_for_each_state() -> void:
	# The hand-drawn knight follows the state machine; attacks follow the combo step.
	assert_str(PlayerVisual.animation_for(State.IDLE, 0)).is_equal("idle")
	assert_str(PlayerVisual.animation_for(State.RUN, 0)).is_equal("run")
	assert_str(PlayerVisual.animation_for(State.JUMP, 0)).is_equal("jump")
	assert_str(PlayerVisual.animation_for(State.FALL, 0)).is_equal("fall")
	assert_str(PlayerVisual.animation_for(State.ROLL, 0)).is_equal("roll")
	assert_str(PlayerVisual.animation_for(State.HURT, 0)).is_equal("hurt")
	assert_str(PlayerVisual.animation_for(State.ATTACK, 0)).is_equal("attack1")
	assert_str(PlayerVisual.animation_for(State.ATTACK, 1)).is_equal("attack2")
	assert_str(PlayerVisual.animation_for(State.ATTACK, 2)).is_equal("attack3")

func test_every_hero_animation_loads_all_its_frames() -> void:
	var visual: PlayerVisual = _player.get_node("Visual")
	var expected := {"idle": 8, "run": 10, "jump": 3, "fall": 4, "roll": 9, "hurt": 3,
		"attack1": 6, "attack2": 6, "attack3": 8, "death": 10}
	for anim in expected:
		assert_bool(visual.sprite_frames.has_animation(anim)).is_true()
		assert_int(visual.sprite_frames.get_frame_count(anim)).is_equal(expected[anim])

func test_a_dead_hero_plays_the_death_animation() -> void:
	await _land()
	_player.take_hit(999, _player.global_position.x - 10.0)
	await _frames(3)
	assert_str((_player.get_node("Visual") as PlayerVisual).animation).is_equal("death")

func test_hero_sprite_runs_when_the_player_runs_and_faces_the_way_it_moves() -> void:
	await _land()
	var visual: PlayerVisual = _player.get_node("Visual")
	assert_str(visual.animation).is_equal("idle")
	InputRouter.set_virtual_axis(-1.0)
	await _frames(6)
	InputRouter.set_virtual_axis(0.0)
	assert_str(visual.animation).is_equal("run")
	assert_bool(visual.flip_h).is_true()

func test_hero_sprite_swings_when_attacking_and_rolls_when_rolling() -> void:
	await _land()
	var visual: PlayerVisual = _player.get_node("Visual")
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(3)
	InputRouter.set_virtual_button(&"attack", false)
	assert_str(visual.animation).is_equal("attack1")
	await _frames(40)
	InputRouter.set_virtual_button(&"roll", true)
	await _frames(3)
	InputRouter.set_virtual_button(&"roll", false)
	assert_str(visual.animation).is_equal("roll")

func _tap_attack() -> void:
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(1)
	InputRouter.set_virtual_button(&"attack", false)

func test_quick_attacks_chain_slash_uppercut_slam_then_restart() -> void:
	await _land()
	var steps := []
	for i in 4:
		await _tap_attack()
		await _frames(3)
		steps.append(_player.combo_step())
		await _frames(int(Player.COMBO_WINDOW * 60.0 * 0.5) + int(0.3 * 60.0))
	assert_array(steps).is_equal([0, 1, 2, 0])

func test_a_pause_resets_the_combo_to_the_first_swing() -> void:
	await _land()
	await _tap_attack()
	await _frames(25)
	await _tap_attack()
	await _frames(3)
	assert_int(_player.combo_step()).is_equal(1)
	await _frames(int((0.3 + Player.COMBO_WINDOW) * 60.0) + 20)
	await _tap_attack()
	await _frames(3)
	assert_int(_player.combo_step()).is_equal(0)

func test_a_tap_early_in_a_swing_is_remembered_for_the_next_one() -> void:
	await _land()
	await _tap_attack()
	await _frames(3)
	await _tap_attack()                     # well before this swing ends: plain input buffering would drop it
	await _frames(30)
	assert_int(_player.combo_step()).is_equal(1)

func test_the_combo_finisher_lasts_longer_than_a_normal_swing() -> void:
	await _land()
	await _tap_attack()
	await _frames(22)
	await _tap_attack()
	await _frames(22)
	await _tap_attack()
	await _frames(3)
	assert_int(_player.combo_step()).is_equal(2)
	var duration: float = _player.get_node("Weapon").data.attack_duration
	await _frames(int(duration * 60.0) + 4)
	assert_int(_player.state()).is_equal(State.ATTACK)    # a normal swing would be over by now

func test_running_covers_ground_fast_like_a_dead_cells_sprint() -> void:
	await _land()
	var start_x := _player.global_position.x
	InputRouter.set_virtual_axis(1.0)
	await _frames(60)
	InputRouter.set_virtual_axis(0.0)
	assert_float(_player.global_position.x - start_x).is_greater(GameConfig.tiles(12.0))

func test_getting_hit_puts_the_mask_on_for_a_few_seconds() -> void:
	await _land()
	var visual: PlayerVisual = _player.get_node("Visual")
	assert_bool(visual.is_masked()).is_false()
	_player.take_hit(10, _player.global_position.x - 20.0)
	await _frames(3)
	assert_float(_player.mask_seconds_left()).is_greater(Player.MASK_SECONDS - 0.5)
	assert_bool(visual.is_masked()).is_true()
	await _frames(int(Player.MASK_SECONDS * 60.0) + 15)
	assert_float(_player.mask_seconds_left()).is_equal(0.0)
	assert_bool(visual.is_masked()).is_false()

func test_a_hit_dodged_by_roll_invincibility_does_not_summon_the_mask() -> void:
	await _land()
	InputRouter.set_virtual_button(&"roll", true)
	await _frames(5)
	_player.take_hit(10, _player.global_position.x - 20.0)
	assert_float(_player.mask_seconds_left()).is_equal(0.0)

func test_a_second_hit_restarts_the_mask_timer() -> void:
	await _land()
	_player.take_hit(5, _player.global_position.x - 20.0)
	await _frames(int(Player.MASK_SECONDS * 60.0 * 0.6))
	var mid := _player.mask_seconds_left()
	await _frames(int(Player.HURT_DURATION * 60.0) + 10)
	_player.take_hit(5, _player.global_position.x - 20.0)
	assert_float(_player.mask_seconds_left()).is_greater(mid)

func test_resetting_the_player_takes_the_mask_off() -> void:
	await _land()
	_player.take_hit(5, _player.global_position.x - 20.0)
	_player.reset(GameConfig.tiles_v(0.0, 3.0))
	assert_float(_player.mask_seconds_left()).is_equal(0.0)

func test_masked_art_covers_the_face_in_every_animation() -> void:
	var visual: PlayerVisual = _player.get_node("Visual")
	# Frame 0 of "hurt" is the pack's pure-white hit flash (no face to cover), so it is skipped.
	for anim in ["idle", "run", "attack1", "attack2", "attack3", "jump", "fall", "roll"]:
		for index in [0, 1]:
			var plain := visual.frame_image(anim, index, false)
			var masked := visual.frame_image(anim, index, true)
			assert_bool(plain.get_data() == masked.get_data()).is_false()
	assert_bool(visual.frame_image("hurt", 1, false).get_data() == visual.frame_image("hurt", 1, true).get_data()).is_false()

func test_switching_to_the_mask_keeps_the_animation_and_frame() -> void:
	await _land()
	var visual: PlayerVisual = _player.get_node("Visual")
	InputRouter.set_virtual_axis(1.0)
	await _frames(8)
	var anim := visual.animation
	var frame := visual.frame
	visual.set_masked(true)
	assert_str(visual.animation).is_equal(anim)
	assert_int(visual.frame).is_equal(frame)
	InputRouter.set_virtual_axis(0.0)
