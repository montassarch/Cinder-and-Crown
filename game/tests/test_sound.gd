extends GdUnitTestSuite
## Music, ambience and sound effects (the Sound autoload, files in audio/, picked by tools/audio/pick_audio.py).

const LEVEL := "res://levels/generated_level.tscn"
const SANDBOX := "res://levels/sandbox.tscn"

var _level: Node


func before_test() -> void:
	Sound.clear_history()
	Sound.set_muted(false)


func after_test() -> void:
	get_tree().paused = false
	Sound.set_muted(false)
	if is_instance_valid(_level):
		_level.queue_free()
	for action in [&"roll", &"jump", &"attack", &"swap_weapon"]:
		InputRouter.set_virtual_button(action, false)
	InputRouter.set_virtual_axis(0.0)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _played(cue: StringName) -> bool:
	return Sound.history().has(cue)


func _sandbox() -> Sandbox:
	_level = load(SANDBOX).instantiate()
	add_child(_level)
	return _level


func _run() -> GeneratedLevel:
	_level = load(LEVEL).instantiate()
	_level.level_seed = 5
	add_child(_level)
	return _level


func _goto(level: GeneratedLevel, depth: int) -> void:
	level.set_depth(depth)
	level.regenerate(level.level_seed)


# ------------------------------------------------------------------ the bank

func test_every_cue_and_track_loads() -> void:
	for cue in SoundBank.CUES:
		for file in SoundBank.CUES[cue]["files"]:
			assert_object(load("%s/sfx/%s.ogg" % [SoundBank.DIR, file])).override_failure_message("%s: %s" % [cue, file]).is_not_null()
	for world in BiomeData.load_all():
		for track in [world.music, world.boss_music]:
			assert_object(load("%s/music/%s.ogg" % [SoundBank.DIR, track])).override_failure_message(str(track)).is_not_null()
		assert_object(load("%s/ambience/%s.ogg" % [SoundBank.DIR, world.ambience])).is_not_null()
	for track in [SoundBank.VICTORY_MUSIC, SoundBank.FALLEN_MUSIC]:
		assert_object(load("%s/music/%s.ogg" % [SoundBank.DIR, track])).is_not_null()


func test_playing_a_cue_plays_one_of_its_files() -> void:
	var player := Sound.play(&"swing")
	assert_object(player).is_not_null()
	assert_bool(player.playing).is_true()
	assert_bool(_played(&"swing")).is_true()


func test_an_unknown_cue_is_quietly_ignored() -> void:
	assert_object(Sound.play(&"no_such_sound")).is_null()


func test_music_loops_and_switching_to_the_same_track_does_not_restart_it() -> void:
	Sound.music(&"cathedral")
	assert_str(String(Sound.current_music())).is_equal("cathedral")
	var stream := Sound.music_player().stream as AudioStreamOggVorbis
	assert_bool(stream.loop).is_true()
	var player := Sound.music_player()
	Sound.music(&"cathedral")
	assert_object(Sound.music_player()).is_same(player)
	Sound.music(&"spire")
	assert_str(String(Sound.current_music())).is_equal("spire")


func test_muting_silences_everything() -> void:
	Sound.set_muted(true)
	assert_bool(AudioServer.is_bus_mute(0)).is_true()
	Sound.set_muted(false)
	assert_bool(AudioServer.is_bus_mute(0)).is_false()


# ------------------------------------------------------------------ music follows the run

func test_each_world_plays_its_own_music_and_ambience() -> void:
	var level := _run()
	assert_str(String(Sound.current_music())).is_equal(String(level.biome().music))
	_goto(level, 4)
	assert_str(String(Sound.current_music())).is_equal("ossuary")
	assert_str(String(Sound.current_ambience())).is_equal("ossuary")


func test_a_boss_brings_its_own_music_and_a_roar() -> void:
	var level := _run()
	_goto(level, 2)
	var x := 0.0
	for room in level.layout():
		if room.kind == RoomData.Kind.BOSS:
			break
		x += room.size_tiles.x
	level.player.global_position.x = GameConfig.tiles(x + 6.0)
	await _frames(3)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(String(Sound.current_music())).is_equal(String(level.biome().boss_music))
	assert_bool(_played(&"roar")).is_true()


func test_the_last_boss_has_the_final_theme() -> void:
	var spire: BiomeData = BiomeData.load_all().back()
	assert_str(String(spire.boss_music)).is_equal("final_boss")


func test_winning_plays_the_victory_music_and_falling_the_lament() -> void:
	var level := _run()
	_goto(level, BiomeData.load_all().back().boss_depth())
	MetaSave.path = "user://test_sound_meta.json"
	level._on_boss_died(level.biome().boss)
	assert_str(String(Sound.current_music())).is_equal(String(SoundBank.VICTORY_MUSIC))
	(level.get_node("VictoryScreen") as VictoryScreen).press_new_run()
	level._on_player_died()
	assert_str(String(Sound.current_music())).is_equal(String(SoundBank.FALLEN_MUSIC))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_sound_meta.json"))
	MetaSave.path = MetaSave.DEFAULT_PATH


# ------------------------------------------------------------------ combat and movement sounds

func test_a_swing_whooshes_and_a_hit_lands_with_a_blade_sound() -> void:
	var level := _sandbox()
	await _frames(30)
	InputRouter.set_virtual_button(&"attack", true)
	await _frames(3)
	InputRouter.set_virtual_button(&"attack", false)
	assert_bool(_played(&"swing")).is_true()
	var enemy := level.spawn_enemy_at(load("res://data/enemies/shambler.tres"), level.player.global_position + Vector2(20, 0))
	level.player.hit_landed.emit(enemy, 8)
	assert_bool(_played(&"hit")).is_true()


func test_a_gauntlet_hit_thuds() -> void:
	var level := _sandbox()
	level.player.set_weapon(0, load("res://data/weapons/iron_gauntlet.tres"))
	level.player._weapon.start_attack()
	var enemy := level.spawn_enemy_at(load("res://data/enemies/shambler.tres"), level.player.global_position + Vector2(20, 0))
	level.player.hit_landed.emit(enemy, 6)
	assert_bool(_played(&"punch")).is_true()


func test_a_parry_clashes() -> void:
	var level := _sandbox()
	level.player.parried.emit(false)
	assert_bool(_played(&"clash")).is_true()


func test_rolling_jumping_landing_and_running_make_their_sounds() -> void:
	var level := _sandbox()
	await _frames(30)
	level.player.rolled.emit()
	level.player.landed.emit()
	assert_bool(_played(&"roll")).is_true()
	assert_bool(_played(&"land")).is_true()
	InputRouter.set_virtual_button(&"jump", true)
	await _frames(3)
	InputRouter.set_virtual_button(&"jump", false)
	assert_bool(_played(&"jump")).is_true()
	await _frames(60)
	Sound.clear_history()
	InputRouter.set_virtual_axis(1.0)
	await _frames(40)
	assert_bool(_played(&"step")).is_true()


func test_drinking_casting_and_swapping_weapons_make_their_sounds() -> void:
	var level := _sandbox()
	level.player.drank.emit()
	level.player.ability_cast.emit(&"storm")
	level.player.swap_weapons()
	assert_bool(_played(&"drink")).is_true()
	assert_bool(_played(&"cast")).is_true()
	assert_bool(_played(&"draw")).is_true()


func test_the_hero_grunts_when_hurt() -> void:
	var level := _sandbox()
	await _frames(30)
	level.player.take_hit(5, level.player.global_position.x - 10.0)
	assert_bool(_played(&"hero_hurt")).is_true()


func test_enemies_cry_out_when_hurt_and_when_they_die() -> void:
	var level := _sandbox()
	var enemy := level.spawn_enemy_at(load("res://data/enemies/shambler.tres"), level.player.global_position + Vector2(40, 0))
	enemy.take_hit(3, 0.0)
	assert_bool(_played(&"enemy_hurt")).is_true()
	enemy.take_hit(100000, 0.0)
	assert_bool(_played(&"enemy_die")).is_true()


func test_slams_explosions_and_summons_are_heard() -> void:
	var level := _sandbox()
	var brute := level.spawn_enemy_at(load("res://data/enemies/crown_brute.tres"), level.player.global_position + Vector2(40, 0))
	brute.slammed.emit(brute.global_position)
	brute.exploded.emit()
	brute.summoned.emit(brute.global_position)
	assert_bool(_played(&"slam")).is_true()
	assert_bool(_played(&"blast")).is_true()
	assert_bool(_played(&"summon")).is_true()


func test_a_hazard_erupts_with_a_sound() -> void:
	var level := _sandbox()
	GroundHazard.spawn(level, &"fire_pillar", level.player.global_position + Vector2(100, 16), 16.0, 64.0, 0.05, 0.2, 5, 0.0, level.player)
	await _frames(10)
	assert_bool(_played(&"hazard")).is_true()


func test_the_menu_can_turn_the_sound_off() -> void:
	var level := _sandbox()
	var menu := level.get_node("Menu") as SandboxMenu
	menu.press_sound_toggle()
	assert_bool(Sound.is_muted()).is_true()
	menu.press_sound_toggle()
	assert_bool(Sound.is_muted()).is_false()
