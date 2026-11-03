extends GdUnitTestSuite
## Fixes for the playtest report of 2026-11-03 (Design/QA/2026-11-03-playtest.md).

const LEVEL := "res://levels/generated_level.tscn"
const SANDBOX := "res://levels/sandbox.tscn"
const RECORDER := preload("res://tests/support/strike_recorder.gd")

var _level: Node


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_level):
		_level.queue_free()
	for action in [&"roll", &"flask", &"attack", &"jump"]:
		InputRouter.set_virtual_button(action, false)
	InputRouter.set_virtual_axis(0.0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _sandbox() -> Sandbox:
	_level = load(SANDBOX).instantiate()
	add_child(_level)
	return _level


func _run(seed_value: int = 5) -> GeneratedLevel:
	_level = load(LEVEL).instantiate()
	_level.level_seed = seed_value
	add_child(_level)
	return _level


# H4: a moment of invulnerability after a hit, so hits cannot stack in one breath
func test_after_a_hit_the_hero_cannot_be_hurt_again_for_a_moment() -> void:
	var level := _sandbox()
	await _frames(30)
	var health: Health = level.player.get_node("Health")
	var before := health.current
	level.player.take_hit(10, level.player.global_position.x - 10.0)
	level.player.take_hit(10, level.player.global_position.x - 10.0)
	assert_int(health.current).is_equal(before - 10)
	assert_bool(level.player.is_invincible()).is_true()
	await _frames(int(Player.HIT_GRACE_SECONDS * 60.0) + 10)
	level.player.take_hit(10, level.player.global_position.x - 10.0)
	assert_int(health.current).is_equal(before - 20)


func test_the_hero_blinks_while_he_cannot_be_hurt() -> void:
	var level := _sandbox()
	await _frames(30)
	level.player.take_hit(5, level.player.global_position.x - 10.0)
	var seen := {}
	for i in 20:
		await _frames(1)
		seen[(level.player.get_node("Visual") as CanvasItem).visible] = true
	assert_int(seen.size()).is_equal(2)
	await _frames(int(Player.HIT_GRACE_SECONDS * 60.0) + 5)
	assert_bool((level.player.get_node("Visual") as CanvasItem).visible).is_true()


# M2: the hero is drawn in front of enemies
func test_the_hero_is_drawn_in_front_of_enemies() -> void:
	var level := _sandbox()
	var enemy := level.spawn_enemy_at(load("res://data/enemies/shambler.tres"), level.player.global_position + Vector2(10, 0))
	assert_int(level.player.z_index).is_greater(enemy.z_index)


# H3: a boss attacks a hero standing on a ledge above it
func test_a_boss_attacks_a_hero_on_a_ledge_above_it() -> void:
	var hero: Node2D = auto_free(RECORDER.new())
	add_child(hero)
	var data: EnemyData = load("res://data/bosses/hollow_bishop.tres")
	var boss: Enemy = load("res://src/enemies/enemy.tscn").instantiate()
	add_child(boss)
	boss.configure(data)
	boss.target = hero
	boss.set_physics_process(false)
	hero.global_position = boss.global_position + GameConfig.tiles_v(1.0, -4.5)
	boss._think_move(hero, 0.016)
	assert_int(boss._state).is_equal(Enemy.State.TELEGRAPH)
	boss.queue_free()


# M6: every boss has something to parry
func test_every_boss_has_a_move_that_can_be_parried() -> void:
	for biome in BiomeData.load_all():
		var parryable := (biome.boss.moves + biome.boss.phase_two_moves).filter(func(m: EnemyMove) -> bool: return m.parryable)
		assert_bool(parryable.is_empty()).override_failure_message(biome.boss.display_name).is_false()


# H5: the first boss is not a pushover, and later waves do not swell without end
func test_the_first_boss_has_enough_health_to_be_a_fight() -> void:
	assert_int((load("res://data/bosses/hollow_bishop.tres") as EnemyData).max_health).is_greater_equal(700)


func test_wave_budgets_grow_more_slowly_in_the_last_world() -> void:
	var early := WaveGenerator.budget_for(5) - WaveGenerator.budget_for(4)
	var late := WaveGenerator.budget_for(10) - WaveGenerator.budget_for(9)
	assert_int(late).is_less(early)


# M5: the next room's wave waits while the previous one is still mostly alive
func test_a_new_wave_waits_while_the_room_is_still_full() -> void:
	var level := _run(7)
	await _frames(5)
	for i in GeneratedLevel.MAX_LIVE_BEFORE_NEXT_WAVE + 1:
		level.spawn_enemy_at(load("res://data/enemies/shambler.tres"), level.player.global_position + Vector2(300 + i * 10, -20))
	var before := level.enemy_count()
	for encounter in level._encounters:
		level.player.global_position.x = GameConfig.tiles(encounter.start + GeneratedLevel.ENCOUNTER_TRIGGER_TILES + 1.0)
		await _frames(2)
		await get_tree().process_frame
	assert_int(level.enemy_count()).is_equal(before)


# M1: standing in the exit when the last enemy falls still offers the boons
func test_standing_in_the_exit_when_it_opens_offers_the_boons() -> void:
	var level := _run(7)
	await _frames(5)
	for encounter in level._encounters:
		encounter.spawned = true   # no room waves: only this one enemy keeps the gate shut
	var enemy := level.spawn_enemy_at(load("res://data/enemies/shambler.tres"), level.player.global_position + Vector2(300, -20))
	var rooms := level.get_node("Rooms").get_children()
	level.player.global_position = (rooms[rooms.size() - 1].get_node("ExitZone") as Area2D).global_position
	await _frames(5)
	await get_tree().process_frame
	assert_bool((level.get_node("BoonPicker") as BoonPicker).is_open()).is_false()
	enemy.take_hit(100000, 0.0)
	await _frames(40)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool((level.get_node("BoonPicker") as BoonPicker).is_open()).is_true()


# H1: beating the last boss ends the run with a victory screen
func test_beating_the_last_boss_shows_the_victory_screen_instead_of_more_levels() -> void:
	MetaSave.path = "user://test_qa_victory.json"
	var level := _run(5)
	level.set_depth(BiomeData.load_all().back().boss_depth())
	level.regenerate(5)
	level._on_boss_died(BiomeData.load_all().back().boss)
	await _frames(2)
	var screen := level.get_node("VictoryScreen") as VictoryScreen
	assert_bool(screen.is_open()).is_true()
	assert_int(MetaSave.wins()).is_greater(0)
	screen.press_new_run()
	await _frames(2)
	assert_int(level.depth()).is_equal(0)
	assert_bool(screen.is_open()).is_false()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_qa_victory.json"))
	MetaSave.path = MetaSave.DEFAULT_PATH


func test_the_run_never_goes_deeper_than_the_last_boss() -> void:
	var level := _run(5)
	var last: int = BiomeData.load_all().back().boss_depth()
	level.set_depth(last)
	level._on_boon_chosen(load("res://data/boons/keen_edge.tres"))
	assert_int(level.depth()).is_less_equal(last)


# H2: the right-hand buttons are see-through enough to watch the fight under them, and the camera leads the hero
func test_idle_buttons_are_mostly_see_through() -> void:
	assert_float(TouchControls.BUTTON_IDLE_ALPHA).is_less_equal(0.4)


func test_the_camera_shows_more_of_the_room_ahead_of_the_hero_than_behind() -> void:
	var level := _sandbox()
	assert_float((level.get_node("Camera") as Camera2D).offset.x).is_greater(0.0)


# M4: HUD text stays readable over bright ice
func test_hud_text_has_a_dark_outline() -> void:
	var level := _sandbox()
	var label := level.get_node("Hud/WeaponLabel") as Label
	assert_int(label.get_theme_constant("outline_size")).is_greater_equal(3)


# M3: banners are drawn above the touch buttons
func test_banners_are_drawn_above_the_touch_buttons() -> void:
	var level := _sandbox()
	var banner := level.get_node("Hud").banner_layer() as CanvasLayer
	assert_int(banner.layer).is_greater((level.get_node("TouchControls") as CanvasLayer).layer)


# M7: a hazard's warning is a tall, bright glow, easy to see on a phone
func test_a_hazard_warns_with_a_tall_glow() -> void:
	assert_float(GroundHazard.WARN_GLOW_HEIGHT).is_greater_equal(10.0)
