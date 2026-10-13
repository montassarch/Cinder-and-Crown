class_name SandboxTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# The sandbox is the workbench the human tunes feel on, so what matters
# here is that it boots, spawns, clears and resets -- and that its menu
# discovers content by scanning disk rather than by a hardcoded list.
# That last one is the data-driven rule's only real proof: if the menu
# needs editing to show a new weapon, the system has regressed.

const MenuScript := preload("res://src/ui/sandbox_menu.gd")


func _spawn_sandbox() -> Node2D:
	var sandbox: Node2D = auto_free(
		(load("res://levels/sandbox.tscn") as PackedScene).instantiate()
	)
	add_child(sandbox)
	return sandbox


# --- boot ---

func test_sandbox_boots_with_a_player_and_no_enemies() -> void:
	var sandbox := _spawn_sandbox()
	assert_object(sandbox.player).is_not_null()
	assert_int(sandbox.enemy_count()).is_equal(0)


# --- spawning ---

func test_spawn_enemy_adds_a_live_enemy() -> void:
	var sandbox := _spawn_sandbox()
	sandbox.spawn_enemy(load("res://data/enemies/shambler.tres"))
	assert_int(sandbox.enemy_count()).is_equal(1)


func test_spawned_enemy_targets_the_player() -> void:
	# An enemy with no target just stands there, which would make the
	# sandbox useless for judging combat.
	var sandbox := _spawn_sandbox()
	var enemy: Enemy = sandbox.spawn_enemy(load("res://data/enemies/shambler.tres"))
	assert_object(enemy.target).is_same(sandbox.player)


func test_spawning_null_data_is_refused() -> void:
	var sandbox := _spawn_sandbox()
	assert_object(sandbox.spawn_enemy(null)).is_null()
	assert_int(sandbox.enemy_count()).is_equal(0)


func test_repeated_spawns_alternate_sides() -> void:
	# Otherwise every spawn lands inside the previous one.
	var sandbox := _spawn_sandbox()
	var first: Enemy = sandbox.spawn_enemy(load("res://data/enemies/shambler.tres"))
	var second: Enemy = sandbox.spawn_enemy(load("res://data/enemies/shambler.tres"))
	var player_x: float = sandbox.player.global_position.x
	assert_bool(
		signf(first.global_position.x - player_x)
		!= signf(second.global_position.x - player_x)
	).is_true()


func test_enemy_count_ignores_dead_enemies() -> void:
	var sandbox := _spawn_sandbox()
	var enemy: Enemy = sandbox.spawn_enemy(load("res://data/enemies/cinder_bat.tres"))
	enemy.health.take_damage(enemy.health.max_health)
	assert_int(sandbox.enemy_count()).is_equal(0)


func test_clear_enemies_removes_them() -> void:
	var sandbox := _spawn_sandbox()
	sandbox.spawn_enemy(load("res://data/enemies/shambler.tres"))
	sandbox.spawn_enemy(load("res://data/enemies/crown_brute.tres"))
	sandbox.clear_enemies()
	await get_tree().process_frame
	assert_int(sandbox.enemy_count()).is_equal(0)


# --- reset ---

func test_reset_player_restores_health() -> void:
	var sandbox := _spawn_sandbox()
	sandbox.player.take_hit(40, Vector2.ZERO)
	assert_int(sandbox.player.health.current).is_less(Player.MAX_HEALTH)
	sandbox.reset_player()
	assert_int(sandbox.player.health.current).is_equal(Player.MAX_HEALTH)


func test_reset_player_returns_them_to_the_spawn_point() -> void:
	var sandbox := _spawn_sandbox()
	var spawn: Vector2 = (sandbox.get_node("%PlayerSpawn") as Marker2D).global_position
	sandbox.player.global_position = Vector2(600.0, 20.0)
	sandbox.reset_player()
	assert_vector(sandbox.player.global_position).is_equal(spawn)


func test_player_death_resets_rather_than_ending_the_run() -> void:
	# The sandbox is a workbench: dying should cost nothing but position.
	var sandbox := _spawn_sandbox()
	sandbox.player.take_hit(Player.MAX_HEALTH, Vector2.ZERO)
	assert_int(sandbox.player.health.current).is_equal(Player.MAX_HEALTH)


# --- the data-driven rule ---

func test_menu_discovers_every_shipped_enemy_from_disk() -> void:
	# Count asserted as a floor, not an equality: the suite must not break
	# when someone adds a fourth enemy .tres, which is the entire point of
	# the data-driven rule these tests exist to defend.
	var found: Array[String] = MenuScript.list_resources(MenuScript.ENEMY_DIR)
	assert_int(found.size()).is_greater_equal(3)
	for path: String in found:
		assert_object(load(path)).is_instanceof(EnemyData)


func test_menu_discovers_every_shipped_weapon_from_disk() -> void:
	var found: Array[String] = MenuScript.list_resources(MenuScript.WEAPON_DIR)
	assert_int(found.size()).is_greater_equal(2)
	for path: String in found:
		assert_object(load(path)).is_instanceof(WeaponData)


func test_resource_scan_tolerates_export_renaming() -> void:
	# The previous version of this test asserted only that a real folder is
	# non-empty and a fake one is empty -- it passed with the ".res" and
	# ".remap" handling deleted, so it pinned nothing. data/ holds only
	# .tres files, so the renaming has to be fed in deliberately.
	var dir := "user://scan_probe"
	DirAccess.make_dir_recursive_absolute(dir)
	for name: String in ["a.tres", "b.res", "c.tres.remap", "d.png", "e.gd"]:
		var handle := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
		if handle != null:
			handle.close()

	var found: Array[String] = MenuScript.list_resources(dir)
	assert_int(found.size()).override_failure_message(
		"expected a.tres, b.res and the de-remapped c.tres; got %s" % str(found)
	).is_equal(3)
	assert_array(found).contains([dir.path_join("c.tres")])
	assert_array(found).not_contains([dir.path_join("d.png")])

	for name: String in ["a.tres", "b.res", "c.tres.remap"]:
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir.path_join("d.png"))
	DirAccess.remove_absolute(dir.path_join("e.gd"))


func test_resource_scan_of_a_missing_directory_is_empty() -> void:
	assert_array(MenuScript.list_resources("res://does/not/exist")).is_empty()


# --- the resolution rule, applied to the world ---

func test_sandbox_floor_is_built_from_tiles_not_pixels() -> void:
	# Final review I14. Gameplay code honoured the tile rule but the world
	# did not: the floor, walls and platforms were hand-placed pixels in
	# the .tscn. Raising TILE_SIZE would have scaled the player, hitboxes,
	# jump height and roll distance while the floor stayed 32px thick --
	# the player would no longer have fit between floor and platform, so
	# the documented upgrade path did not actually work.
	var sandbox := _spawn_sandbox()
	var world := sandbox.get_node("%World") as StaticBody2D
	assert_int(world.get_child_count()).override_failure_message(
		"world geometry was not built at runtime"
	).is_greater(0)

	var floor_shape := world.get_child(0) as CollisionShape2D
	assert_vector((floor_shape.shape as RectangleShape2D).size).is_equal(
		GameConfig.tiles_v(
			sandbox.ROOM_WIDTH_TILES, sandbox.FLOOR_THICKNESS_TILES
		)
	)


func test_every_platform_is_within_a_jump_of_the_surface_below() -> void:
	# The plan requires platform heights be derived from the player's jump,
	# not guessed. A platform one pixel too high is invisible in a diff and
	# obvious the moment you play.
	var rises: Array[Rect2] = (load("res://src/level/sandbox.gd") as GDScript).platform_rects()
	assert_int(rises.size()).is_greater(0)
	for platform: Rect2 in rises:
		var rise_from_floor: float = 11.0 - platform.position.y
		assert_float(rise_from_floor).override_failure_message(
			"a platform sits %.2f tiles up; the jump clears %.2f" % [
				rise_from_floor, Player.JUMP_HEIGHT_TILES
			]
		).is_less_equal(Player.JUMP_HEIGHT_TILES * 2.0)


func test_platform_heights_are_derived_from_the_jump_height() -> void:
	# Pins the derivation itself: change JUMP_HEIGHT_TILES and the
	# platforms must move with it, or this fails.
	var expected := 11.0 - Player.JUMP_HEIGHT_TILES * 0.78
	var rects: Array[Rect2] = (load("res://src/level/sandbox.gd") as GDScript).platform_rects()
	assert_float(rects[0].position.y).is_equal_approx(expected, 0.001)


func test_room_scenes_build_their_floors_from_tiles() -> void:
	for room: RoomData in Content.rooms():
		var instance: Node2D = auto_free(room.scene.instantiate())
		add_child(instance)
		var solid := instance.get_node("%Solid") as StaticBody2D
		assert_int(solid.get_child_count()).override_failure_message(
			"%s built no geometry" % room.display_name
		).is_greater(0)
		var floor_shape := solid.get_child(0) as CollisionShape2D
		assert_float((floor_shape.shape as RectangleShape2D).size.x).is_equal(
			GameConfig.tiles(instance.width_tiles)
		)


func test_room_scene_width_matches_its_data_width() -> void:
	# Load-bearing now that rooms are laid end to end from size_tiles: a
	# mismatch means overlapping rooms or a gap to fall through.
	for room: RoomData in Content.rooms():
		var instance: Node2D = auto_free(room.scene.instantiate())
		add_child(instance)
		assert_float(instance.width_tiles).override_failure_message(
			"%s: scene is %.1f tiles wide, data says %d" % [
				room.display_name, instance.width_tiles, room.size_tiles.x
			]
		).is_equal(float(room.size_tiles.x))


# --- UI must not steal gameplay keys ---

func _all_buttons(node: Node, found: Array[Node] = []) -> Array[Node]:
	if node is BaseButton:
		found.append(node)
	for child: Node in node.get_children():
		_all_buttons(child, found)
	return found


func test_no_ui_button_accepts_keyboard_focus() -> void:
	# Reported from play: pressing Space jumped AND toggled the menu.
	# Godot's BaseButton takes focus, and ui_accept (Space/Enter) fires the
	# focused button -- so every gameplay key that overlaps ui_accept also
	# presses whatever button happens to be focused. The fix is that no
	# in-game button is focusable at all; they are pointer/touch targets.
	var sandbox := _spawn_sandbox()
	await get_tree().process_frame

	var buttons := _all_buttons(sandbox)
	assert_int(buttons.size()).override_failure_message(
		"found no buttons to check -- the menu did not build"
	).is_greater(0)

	for button: Node in buttons:
		assert_int((button as BaseButton).focus_mode).override_failure_message(
			"%s accepts focus, so Space/Enter can trigger it" % button.name
		).is_equal(Control.FOCUS_NONE)


func test_no_ui_button_is_currently_focused() -> void:
	var sandbox := _spawn_sandbox()
	await get_tree().process_frame
	for button: Node in _all_buttons(sandbox):
		assert_bool((button as BaseButton).has_focus()).override_failure_message(
			"%s holds focus at startup" % button.name
		).is_false()


# --- UI must not obscure the game ---

func test_menu_starts_collapsed_so_the_play_area_is_clear() -> void:
	# Seen on video: the panel is ~158x188 against a 384x216 viewport --
	# 87% of the height -- so with it open the player is barely visible.
	# It is a workbench drawer, not a permanent fixture.
	var sandbox := _spawn_sandbox()
	await get_tree().process_frame
	var panel := sandbox.get_node("%SandboxMenu").get_node("%Panel") as Control
	assert_bool(panel.visible).override_failure_message(
		"the sandbox menu covers the play area on startup"
	).is_false()


func test_hud_weapon_text_fits_inside_the_hud() -> void:
	# Seen on video: "Rusty Blade | [Emb<spawn>ear]" -- the slot label
	# overflowed its container and collided with the menu panel's heading.
	var sandbox := _spawn_sandbox()
	await get_tree().process_frame
	var hud := sandbox.get_node("%HUD")
	var label := hud.get_node("%SlotsLabel") as Label
	var root := hud.get_node("Root") as Control

	var widest := 0.0
	for line: String in label.text.split("\n"):
		var w: float = label.get_theme_font("font").get_string_size(
			line, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size("font_size")
		).x
		widest = maxf(widest, w)

	assert_float(widest).override_failure_message(
		"slot text is %.0fpx wide in a %.0fpx HUD: '%s'" % [
			widest, root.size.x, label.text
		]
	).is_less_equal(root.size.x)
