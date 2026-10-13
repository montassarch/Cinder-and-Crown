extends SceneTree

func _initialize() -> void:
	# C2: airborne with zero vertical velocity
	var SM := load("res://src/player/player_state_machine.gd")
	var ctx := {
		&"on_floor": false, &"move_axis": 1.0, &"jump_buffered": false,
		&"attack_buffered": false, &"roll_buffered": false, &"hurt": false,
		&"state_finished": true, &"coyote_time": 0.016, &"vertical_velocity": 0.0,
	}
	var got: int = SM.next_state(SM.State.RUN, ctx)
	print("C2: RUN + airborne + vy=0.0 -> state %d  (JUMP=%d FALL=%d)" % [got, SM.State.JUMP, SM.State.FALL])

	# C1: does the player's hitbox overlap their own hurtbox?
	var player: Node = load("res://src/player/player.tscn").instantiate()
	root.add_child(player)
	var hurt: Area2D = player.get_node("Hurtbox")
	print("C1: hitbox mask=%d  player hurtbox layer=%d  hurtbox.owner is player: %s"
		% [4 & 0xFF, hurt.collision_layer, str(hurt.owner == player)])
	var wd = player.active_weapon_data()
	var half_w: float = wd.hitbox_size_tiles.x * 16.0 * 0.5
	var cx: float = wd.hitbox_offset_tiles.x * 16.0
	print("C1: hitbox x range [%.1f, %.1f]   player hurtbox x range [-8.0, 8.0]  -> overlap: %s"
		% [cx - half_w, cx + half_w, str(cx - half_w < 8.0)])
	quit()
