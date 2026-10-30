extends GdUnitTestSuite

const SCENE := "res://levels/sandbox.tscn"
const MENU_SCENE := "res://src/ui/sandbox_menu.tscn"
const BAT := "res://data/enemies/cinder_bat.tres"
const BRUTE := "res://data/enemies/crown_brute.tres"
const SPEAR := "res://data/weapons/ember_spear.tres"

var _sandbox: Sandbox

func before_test() -> void:
	_sandbox = load(SCENE).instantiate()
	add_child(_sandbox)

func after_test() -> void:
	get_tree().paused = false
	_sandbox.queue_free()
	for action in [&"attack", &"jump", &"roll"]:
		InputRouter.set_virtual_button(action, false)
		InputRouter.call(&"consume_" + str(action))
	InputRouter.set_virtual_axis(0.0)

func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func test_sandbox_contains_player_camera_hud_menu_and_touch_controls() -> void:
	assert_object(_sandbox.player).is_instanceof(Player)
	assert_object(_sandbox.get_node("Camera")).is_instanceof(Camera2D)
	assert_object(_sandbox.get_node("Hud")).is_not_null()
	assert_object(_sandbox.get_node("Menu")).is_not_null()
	assert_object(_sandbox.get_node("TouchControls")).is_not_null()

func test_every_platform_step_is_within_the_players_jump_height() -> void:
	# Derived from Player.JUMP_HEIGHT, not guessed: a step must be clearable with margin.
	assert_float(Sandbox.PLATFORM_STEP_TILES).is_less(Player.JUMP_HEIGHT)
	for rect in _sandbox.platform_rects_tiles():
		var rise := Sandbox.GROUND_TOP_TILES - rect.position.y
		var steps := rise / Sandbox.PLATFORM_STEP_TILES
		assert_float(absf(steps - roundf(steps))).is_less(0.001)

func test_player_lands_on_the_sandbox_floor() -> void:
	await _frames(90)
	assert_bool(_sandbox.player.is_on_floor()).is_true()

func test_spawn_adds_a_configured_enemy_that_hunts_the_player() -> void:
	var enemy := _sandbox.spawn_enemy(load(BRUTE))
	assert_bool(enemy.is_in_group("enemy")).is_true()
	assert_int(enemy.health().max_health).is_equal(load(BRUTE).max_health)
	assert_object(enemy.target).is_same(_sandbox.player)

func test_flyers_spawn_in_the_air_and_ground_enemies_near_the_floor() -> void:
	var bat := _sandbox.spawn_enemy(load(BAT))
	var brute := _sandbox.spawn_enemy(load(BRUTE))
	assert_float(bat.global_position.y).is_less(brute.global_position.y)

func test_clear_removes_every_enemy() -> void:
	_sandbox.spawn_enemy(load(BAT))
	_sandbox.spawn_enemy(load(BRUTE))
	assert_int(_sandbox.enemy_count()).is_equal(2)
	_sandbox.clear_enemies()
	await _frames(2)
	assert_int(_sandbox.enemy_count()).is_equal(0)

func test_assign_weapon_changes_the_slot() -> void:
	_sandbox.assign_weapon(0, load(SPEAR))
	assert_str(_sandbox.player.weapon_in_slot(0).display_name).is_equal("Ember Spear")

func test_reset_player_restores_health_and_position() -> void:
	await _frames(60)
	_sandbox.player.take_hit(40, _sandbox.player.global_position.x - 10.0)
	_sandbox.player.global_position = GameConfig.tiles_v(30.0, 5.0)
	_sandbox.reset_player()
	assert_int(_sandbox.player.get_node("Health").current).is_equal(100)
	assert_vector(_sandbox.player.global_position).is_equal(_sandbox.spawn_point())

func test_player_death_resets_after_a_beat() -> void:
	_sandbox.player.take_hit(999, _sandbox.player.global_position.x - 10.0)
	assert_bool(_sandbox.player.get_node("Health").is_alive()).is_false()
	await await_millis(int(Sandbox.RESPAWN_DELAY * 1000.0) + 400)
	assert_bool(_sandbox.player.get_node("Health").is_alive()).is_true()

func test_hud_health_bar_follows_the_players_health() -> void:
	var hud: Node = _sandbox.get_node("Hud")
	assert_float(hud.health_fraction()).is_equal(1.0)
	_sandbox.player.take_hit(25, _sandbox.player.global_position.x - 10.0)
	assert_float(hud.health_fraction()).is_equal(0.75)

func test_hud_mana_bar_follows_mana_and_flashes_when_denied() -> void:
	var hud: Node = _sandbox.get_node("Hud")
	var player: Player = _sandbox.player
	assert_float(hud.mana_fraction()).is_equal(1.0)
	player.mana().spend(25.0)
	assert_float(hud.mana_fraction()).is_equal_approx(0.75, 0.001)
	assert_bool(hud.mana_flashing()).is_false()
	player.mana_denied.emit()
	assert_bool(hud.mana_flashing()).is_true()

func test_hud_reports_live_enemy_count_and_weapon_names() -> void:
	var hud: Node = _sandbox.get_node("Hud")
	_sandbox.spawn_enemy(load(BAT))
	await _frames(2)
	assert_str(hud.enemy_text()).contains("1")
	assert_str(hud.weapon_text()).contains("Rusty Blade")
	assert_str(hud.weapon_text()).contains("Ember Spear")

func test_hud_shows_the_flask_charges() -> void:
	var hud: Node = _sandbox.get_node("Hud")
	assert_str(hud.flask_text()).contains("%d/%d" % [Player.FLASK_BASE_CHARGES, Player.FLASK_BASE_CHARGES])
	_sandbox.player.set_flask_charges(1)
	assert_str(hud.flask_text()).contains("1/%d" % Player.FLASK_BASE_CHARGES)

func test_menu_lists_every_shipped_enemy_and_both_weapon_slots() -> void:
	var menu: SandboxMenu = _sandbox.get_node("Menu")
	assert_int(menu.spawn_button_count()).is_equal(DataScanner.list("res://data/enemies").size())
	assert_int(menu.weapon_choice_count()).is_equal(DataScanner.list("res://data/weapons").size())

func test_menu_buttons_drive_the_sandbox() -> void:
	var menu: SandboxMenu = _sandbox.get_node("Menu")
	menu.press_spawn(2)
	assert_int(_sandbox.enemy_count()).is_equal(1)
	menu.press_clear()
	await _frames(2)
	assert_int(_sandbox.enemy_count()).is_equal(0)

func test_opening_the_menu_pauses_and_releases_held_touch_input() -> void:
	var menu: SandboxMenu = _sandbox.get_node("Menu")
	InputRouter.set_virtual_axis(1.0)
	menu.set_open(true)
	assert_bool(get_tree().paused).is_true()
	assert_float(InputRouter.move_axis()).is_equal(0.0)
	menu.set_open(false)
	assert_bool(get_tree().paused).is_false()

func test_menu_toggle_is_drawn_above_the_panel_so_it_can_close_it() -> void:
	# The panel swallows clicks over its area; a toggle underneath it could never close the menu.
	var menu: SandboxMenu = _sandbox.get_node("Menu")
	var panel := menu.find_child("Panel", true, false)
	var toggle := menu.find_child("Toggle", true, false)
	assert_int(toggle.get_index()).is_greater(panel.get_index())

func test_menu_panel_is_opaque_so_the_hud_does_not_bleed_through() -> void:
	var menu: SandboxMenu = _sandbox.get_node("Menu")
	var panel: PanelContainer = menu.find_child("Panel", true, false)
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	assert_float(style.bg_color.a).is_equal(1.0)

func test_the_menu_offers_a_way_to_the_generated_level() -> void:
	var menu: SandboxMenu = _sandbox.get_node("Menu")
	assert_str(menu.scene_switch_target()).is_equal("res://levels/generated_level.tscn")

func test_pressing_the_scene_switch_asks_for_that_scene() -> void:
	var menu: SandboxMenu = auto_free(load(MENU_SCENE).instantiate())
	add_child(menu)
	menu.set_scene_switch("Go", "res://levels/somewhere.tscn")
	var asked := []
	menu.scene_requested.connect(func(path: String) -> void: asked.append(path))
	menu.press_scene_switch()
	assert_array(asked).is_equal(["res://levels/somewhere.tscn"])

func test_the_sandbox_camera_also_runs_past_both_ends() -> void:
	var camera: Camera2D = _sandbox.get_node("Camera")
	var margin := GameConfig.tiles(Sandbox.CAMERA_MARGIN_TILES)
	assert_int(camera.limit_left).is_equal(int(-margin))
	assert_int(camera.limit_right).is_equal(int(GameConfig.tiles(_sandbox.arena_width_tiles()) + margin))

func test_the_menu_lists_every_world() -> void:
	var menu := _sandbox.get_node("Menu") as SandboxMenu
	assert_int(menu.world_choice_count()).is_equal(BiomeData.load_all().size())

func test_choosing_a_world_dresses_the_sandbox_in_it() -> void:
	var menu := _sandbox.get_node("Menu") as SandboxMenu
	menu.choose_world(2)
	var forge := BiomeData.load_all()[2]
	assert_str(_sandbox.biome().id).is_equal(forge.id)
	assert_str((_sandbox.get_node("Backdrop") as Backdrop).biome().id).is_equal(forge.id)
	var ground := load(forge.art_path("ground_tile"))
	var floors := _sandbox.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D)
	assert_int(floors.size()).is_greater(0)
	for body in floors:
		var visual := body.get_node("Visual") as TextureRect
		var one_way: bool = (body.get_child(0) as CollisionShape2D).one_way_collision
		if not one_way:
			assert_object(visual.texture).is_same(ground)
