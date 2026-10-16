extends GdUnitTestSuite

const State := PlayerStateMachine.PlayerState

func _ctx(overrides: Dictionary = {}) -> Dictionary:
	var ctx := {
		"on_floor": true,
		"move_axis": 0.0,
		"jump_buffered": false,
		"attack_buffered": false,
		"roll_buffered": false,
		"state_time": 0.0,
		"coyote_time": 0.0,
		"hurt": false,
		"vel_y": 0.0,
		"attack_duration": 0.3,
	}
	ctx.merge(overrides, true)
	return ctx

func test_idle_to_run_on_move_input() -> void:
	assert_int(PlayerStateMachine.next_state(State.IDLE, _ctx({"move_axis": 1.0}))).is_equal(State.RUN)

func test_run_to_idle_when_input_releases() -> void:
	assert_int(PlayerStateMachine.next_state(State.RUN, _ctx({"move_axis": 0.0}))).is_equal(State.IDLE)

func test_jump_buffered_on_floor_enters_jump() -> void:
	assert_int(PlayerStateMachine.next_state(State.IDLE, _ctx({"jump_buffered": true}))).is_equal(State.JUMP)

func test_jump_within_coyote_time_still_jumps_off_floor() -> void:
	var ctx := _ctx({"on_floor": false, "coyote_time": 0.05, "jump_buffered": true})
	assert_int(PlayerStateMachine.next_state(State.RUN, ctx)).is_equal(State.JUMP)

func test_jump_after_coyote_time_expires_is_refused() -> void:
	var ctx := _ctx({"on_floor": false, "coyote_time": 0.0, "jump_buffered": true})
	assert_int(PlayerStateMachine.next_state(State.FALL, ctx)).is_equal(State.FALL)

func test_roll_cannot_be_interrupted_before_duration_elapses() -> void:
	var ctx := _ctx({
		"state_time": PlayerStateMachine.ROLL_DURATION * 0.5,
		"jump_buffered": true, "attack_buffered": true, "roll_buffered": true, "hurt": true,
	})
	assert_int(PlayerStateMachine.next_state(State.ROLL, ctx)).is_equal(State.ROLL)

func test_roll_returns_to_idle_after_duration() -> void:
	var ctx := _ctx({"state_time": PlayerStateMachine.ROLL_DURATION})
	assert_int(PlayerStateMachine.next_state(State.ROLL, ctx)).is_equal(State.IDLE)

func test_attack_from_idle_enters_attack() -> void:
	assert_int(PlayerStateMachine.next_state(State.IDLE, _ctx({"attack_buffered": true}))).is_equal(State.ATTACK)

func test_hurt_overrides_every_state_except_roll() -> void:
	# roll's i-frames are the point of the move; a hit landing mid-roll is ignored
	for state in [State.IDLE, State.RUN, State.JUMP, State.FALL, State.ATTACK, State.HURT]:
		var next := PlayerStateMachine.next_state(state, _ctx({"hurt": true, "state_time": 0.01, "vel_y": -5.0}))
		assert_int(next).is_equal(State.HURT)
	var rolling := _ctx({"hurt": true, "state_time": PlayerStateMachine.ROLL_DURATION * 0.5})
	assert_int(PlayerStateMachine.next_state(State.ROLL, rolling)).is_equal(State.ROLL)

func test_falling_when_airborne_without_upward_velocity() -> void:
	var airborne := _ctx({"on_floor": false, "vel_y": 0.0})
	assert_int(PlayerStateMachine.next_state(State.IDLE, airborne)).is_equal(State.FALL)
	assert_int(PlayerStateMachine.next_state(State.JUMP, airborne)).is_equal(State.FALL)
	var rising := _ctx({"on_floor": false, "vel_y": -8.0})
	assert_int(PlayerStateMachine.next_state(State.JUMP, rising)).is_equal(State.JUMP)

func test_landing_returns_to_ground_state() -> void:
	assert_int(PlayerStateMachine.next_state(State.FALL, _ctx())).is_equal(State.IDLE)
	assert_int(PlayerStateMachine.next_state(State.FALL, _ctx({"move_axis": -1.0}))).is_equal(State.RUN)

func test_attack_runs_for_its_duration_then_ends() -> void:
	assert_int(PlayerStateMachine.next_state(State.ATTACK, _ctx({"state_time": 0.1}))).is_equal(State.ATTACK)
	assert_int(PlayerStateMachine.next_state(State.ATTACK, _ctx({"state_time": 0.3}))).is_equal(State.IDLE)

func test_roll_requires_the_floor() -> void:
	var ctx := _ctx({"on_floor": false, "roll_buffered": true})
	assert_int(PlayerStateMachine.next_state(State.FALL, ctx)).is_equal(State.FALL)

func test_hurt_ends_after_hurt_duration() -> void:
	assert_int(PlayerStateMachine.next_state(State.HURT, _ctx({"state_time": PlayerStateMachine.HURT_DURATION}))).is_equal(State.IDLE)

func test_jump_cancels_an_attack_once_its_hit_has_landed() -> void:
	var ctx := _ctx({"state_time": 0.2, "attack_duration": 0.3, "jump_buffered": true, "attack_cancelable": true})
	assert_int(PlayerStateMachine.next_state(State.ATTACK, ctx)).is_equal(State.JUMP)

func test_jump_cannot_cancel_an_attack_before_its_hit_lands() -> void:
	var ctx := _ctx({"state_time": 0.05, "attack_duration": 0.3, "jump_buffered": true, "attack_cancelable": false})
	assert_int(PlayerStateMachine.next_state(State.ATTACK, ctx)).is_equal(State.ATTACK)

func test_storm_casts_from_the_ground_when_affordable() -> void:
	var ctx := _ctx({"skill1_buffered": true, "storm_ready": true})
	assert_int(PlayerStateMachine.next_state(State.IDLE, ctx)).is_equal(State.STORM)

func test_storm_needs_the_ground_and_the_mana() -> void:
	assert_int(PlayerStateMachine.next_state(State.FALL, _ctx({"on_floor": false, "skill1_buffered": true, "storm_ready": true}))).is_equal(State.FALL)
	assert_int(PlayerStateMachine.next_state(State.IDLE, _ctx({"skill1_buffered": true, "storm_ready": false}))).is_equal(State.IDLE)

func test_rend_casts_on_the_ground_or_in_the_air() -> void:
	assert_int(PlayerStateMachine.next_state(State.RUN, _ctx({"move_axis": 1.0, "skill2_buffered": true, "rend_ready": true}))).is_equal(State.REND)
	assert_int(PlayerStateMachine.next_state(State.FALL, _ctx({"on_floor": false, "skill2_buffered": true, "rend_ready": true}))).is_equal(State.REND)

func test_a_cast_is_committed_until_it_finishes() -> void:
	var busy := _ctx({"state_time": 0.3, "cast_duration": 0.6, "roll_buffered": true, "jump_buffered": true, "attack_buffered": true})
	assert_int(PlayerStateMachine.next_state(State.STORM, busy)).is_equal(State.STORM)
	assert_int(PlayerStateMachine.next_state(State.STORM, _ctx({"state_time": 0.6, "cast_duration": 0.6}))).is_equal(State.IDLE)
	assert_int(PlayerStateMachine.next_state(State.REND, _ctx({"state_time": 0.45, "cast_duration": 0.45}))).is_equal(State.IDLE)

func test_a_hit_interrupts_a_cast() -> void:
	var ctx := _ctx({"state_time": 0.2, "cast_duration": 0.6, "hurt": true})
	assert_int(PlayerStateMachine.next_state(State.STORM, ctx)).is_equal(State.HURT)

# --- Parry ---

func test_parry_starts_from_the_ground_or_the_air() -> void:
	assert_int(PlayerStateMachine.next_state(State.IDLE, _ctx({"parry_buffered": true, "parry_ready": true}))).is_equal(State.PARRY)
	assert_int(PlayerStateMachine.next_state(State.RUN, _ctx({"move_axis": 1.0, "parry_buffered": true, "parry_ready": true}))).is_equal(State.PARRY)
	assert_int(PlayerStateMachine.next_state(State.FALL, _ctx({"on_floor": false, "parry_buffered": true, "parry_ready": true}))).is_equal(State.PARRY)

func test_parry_waits_for_its_cooldown() -> void:
	assert_int(PlayerStateMachine.next_state(State.IDLE, _ctx({"parry_buffered": true, "parry_ready": false}))).is_equal(State.IDLE)

func test_a_parry_is_committed_until_it_ends() -> void:
	var busy := _ctx({"state_time": 0.1, "parry_duration": 0.5, "move_axis": 1.0, "jump_buffered": true, "attack_buffered": true})
	assert_int(PlayerStateMachine.next_state(State.PARRY, busy)).is_equal(State.PARRY)
	assert_int(PlayerStateMachine.next_state(State.PARRY, _ctx({"state_time": 0.5, "parry_duration": 0.5}))).is_equal(State.IDLE)

func test_a_hit_that_lands_during_a_parry_still_hurts() -> void:
	var ctx := _ctx({"state_time": 0.1, "parry_duration": 0.5, "hurt": true})
	assert_int(PlayerStateMachine.next_state(State.PARRY, ctx)).is_equal(State.HURT)

func test_a_successful_parry_can_be_cut_short_by_an_attack_or_a_roll() -> void:
	var ctx := _ctx({"state_time": 0.15, "parry_duration": 0.5, "parry_succeeded": true, "attack_buffered": true})
	assert_int(PlayerStateMachine.next_state(State.PARRY, ctx)).is_equal(State.ATTACK)
	ctx = _ctx({"state_time": 0.15, "parry_duration": 0.5, "parry_succeeded": true, "roll_buffered": true})
	assert_int(PlayerStateMachine.next_state(State.PARRY, ctx)).is_equal(State.ROLL)

func test_a_whiffed_parry_cannot_be_cut_short() -> void:
	var ctx := _ctx({"state_time": 0.15, "parry_duration": 0.5, "parry_succeeded": false, "attack_buffered": true})
	assert_int(PlayerStateMachine.next_state(State.PARRY, ctx)).is_equal(State.PARRY)

func test_attacks_and_casts_are_not_interrupted_by_a_parry_press() -> void:
	var attacking := _ctx({"state_time": 0.1, "attack_duration": 0.3, "parry_buffered": true, "parry_ready": true})
	assert_int(PlayerStateMachine.next_state(State.ATTACK, attacking)).is_equal(State.ATTACK)
	var casting := _ctx({"state_time": 0.1, "cast_duration": 0.6, "parry_buffered": true, "parry_ready": true})
	assert_int(PlayerStateMachine.next_state(State.STORM, casting)).is_equal(State.STORM)
