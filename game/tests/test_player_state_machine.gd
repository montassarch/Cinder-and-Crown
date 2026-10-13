class_name PlayerStateMachineTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# PlayerStateMachine is a pure transition table: no Input, no get_node, no
# delta. It receives a context dictionary and returns the next state. That
# is the whole reason the player's rules are provable headlessly, while the
# feel of them is not -- speeds and arcs live in Player and get judged by
# playing the game.

const SM := preload("res://src/player/player_state_machine.gd")


func _ctx(overrides: Dictionary = {}) -> Dictionary:
	# A grounded, idle, unharmed player with nothing buffered.
	var ctx := {
		&"on_floor": true,
		&"move_axis": 0.0,
		&"jump_buffered": false,
		&"attack_buffered": false,
		&"roll_buffered": false,
		&"hurt": false,
		&"state_finished": true,
		&"coyote_time": 0.0,
		&"vertical_velocity": 0.0,
	}
	for key: StringName in overrides:
		ctx[key] = overrides[key]
	return ctx


# --- ground movement ---

func test_idle_to_run_on_move_input() -> void:
	var next: int = SM.next_state(SM.State.IDLE, _ctx({&"move_axis": 1.0}))
	assert_int(next).is_equal(SM.State.RUN)


func test_run_to_idle_when_input_releases() -> void:
	var next: int = SM.next_state(SM.State.RUN, _ctx({&"move_axis": 0.0}))
	assert_int(next).is_equal(SM.State.IDLE)


func test_tiny_axis_input_does_not_trigger_run() -> void:
	# A resting gamepad stick or a drifting touch knob must not make the
	# player jog on the spot.
	var next: int = SM.next_state(SM.State.IDLE, _ctx({&"move_axis": 0.05}))
	assert_int(next).is_equal(SM.State.IDLE)


# --- jumping ---

func test_jump_buffered_on_floor_enters_jump() -> void:
	var next: int = SM.next_state(SM.State.IDLE, _ctx({&"jump_buffered": true}))
	assert_int(next).is_equal(SM.State.JUMP)


func test_jump_within_coyote_time_still_jumps_off_floor() -> void:
	# Walking off a ledge and pressing jump a few frames later should still
	# jump. Without this the platforming feels broken rather than strict.
	var next: int = SM.next_state(SM.State.FALL, _ctx({
		&"on_floor": false,
		&"jump_buffered": true,
		&"coyote_time": SM.COYOTE_TIME * 0.5,
		&"vertical_velocity": 50.0,
	}))
	assert_int(next).is_equal(SM.State.JUMP)


func test_jump_after_coyote_time_expires_is_refused() -> void:
	var next: int = SM.next_state(SM.State.FALL, _ctx({
		&"on_floor": false,
		&"jump_buffered": true,
		&"coyote_time": SM.COYOTE_TIME * 2.0,
		&"vertical_velocity": 50.0,
	}))
	assert_int(next).is_equal(SM.State.FALL)


func test_falling_when_airborne_without_upward_velocity() -> void:
	var next: int = SM.next_state(SM.State.JUMP, _ctx({
		&"on_floor": false,
		&"vertical_velocity": 120.0,
	}))
	assert_int(next).is_equal(SM.State.FALL)


func test_rising_stays_in_jump() -> void:
	var next: int = SM.next_state(SM.State.JUMP, _ctx({
		&"on_floor": false,
		&"vertical_velocity": -200.0,
	}))
	assert_int(next).is_equal(SM.State.JUMP)


func test_landing_from_fall_returns_to_idle() -> void:
	var next: int = SM.next_state(SM.State.FALL, _ctx())
	assert_int(next).is_equal(SM.State.IDLE)


# --- roll ---

func test_roll_cannot_be_interrupted_before_duration_elapses() -> void:
	# The roll is a commitment. Letting attack or jump cancel it would
	# remove the risk that makes its invincibility worth having.
	var next: int = SM.next_state(SM.State.ROLL, _ctx({
		&"state_finished": false,
		&"attack_buffered": true,
		&"jump_buffered": true,
		&"move_axis": 1.0,
	}))
	assert_int(next).is_equal(SM.State.ROLL)


func test_roll_returns_to_idle_after_duration() -> void:
	var next: int = SM.next_state(SM.State.ROLL, _ctx({&"state_finished": true}))
	assert_int(next).is_equal(SM.State.IDLE)


func test_roll_takes_priority_over_attack_from_idle() -> void:
	# Both buffered on one frame: the defensive option wins, because the
	# player pressing both is trying not to die.
	var next: int = SM.next_state(SM.State.IDLE, _ctx({
		&"roll_buffered": true,
		&"attack_buffered": true,
	}))
	assert_int(next).is_equal(SM.State.ROLL)


# --- attack ---

func test_attack_from_idle_enters_attack() -> void:
	var next: int = SM.next_state(SM.State.IDLE, _ctx({&"attack_buffered": true}))
	assert_int(next).is_equal(SM.State.ATTACK)


func test_attack_cannot_be_interrupted_before_it_finishes() -> void:
	var next: int = SM.next_state(SM.State.ATTACK, _ctx({
		&"state_finished": false,
		&"move_axis": 1.0,
	}))
	assert_int(next).is_equal(SM.State.ATTACK)


func test_attack_is_allowed_in_the_air() -> void:
	var next: int = SM.next_state(SM.State.FALL, _ctx({
		&"on_floor": false,
		&"attack_buffered": true,
		&"vertical_velocity": 100.0,
	}))
	assert_int(next).is_equal(SM.State.ATTACK)


# --- hurt ---

func test_hurt_overrides_every_state_including_roll() -> void:
	# Invincibility is gated in Player, not here: the hurtbox ignores damage
	# while is_invincible(), so ctx.hurt can only be true when the player is
	# genuinely vulnerable -- including the roll's first 0.04s and last
	# 0.06s, which fall outside IFRAME_WINDOW. One rule, no exceptions.
	for state: int in [
		SM.State.IDLE, SM.State.RUN, SM.State.JUMP,
		SM.State.FALL, SM.State.ROLL, SM.State.ATTACK,
	]:
		var next: int = SM.next_state(state, _ctx({
			&"hurt": true,
			&"state_finished": false,
		}))
		assert_int(next).is_equal(SM.State.HURT)


func test_hurt_runs_to_completion_before_releasing_control() -> void:
	var next: int = SM.next_state(SM.State.HURT, _ctx({
		&"state_finished": false,
		&"move_axis": 1.0,
		&"attack_buffered": true,
	}))
	assert_int(next).is_equal(SM.State.HURT)


func test_hurt_releases_to_idle_when_finished() -> void:
	var next: int = SM.next_state(SM.State.HURT, _ctx({&"state_finished": true}))
	assert_int(next).is_equal(SM.State.IDLE)


func test_already_hurt_is_not_restarted_by_the_same_hit() -> void:
	# ctx.hurt stays true for the frame the hit landed. Re-entering HURT
	# would reset state_time and lock the player in a permanent stunlock.
	var next: int = SM.next_state(SM.State.HURT, _ctx({
		&"hurt": true,
		&"state_finished": true,
	}))
	assert_int(next).is_equal(SM.State.IDLE)
