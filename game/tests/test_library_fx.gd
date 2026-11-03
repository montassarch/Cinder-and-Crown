extends GdUnitTestSuite
## The free effect packs (art/fx_packs: CodeManu, MatheusGG28, xyezawr) and where the game plays them.
## The xyezawr packs are kept out of the public repo (their licence forbids redistributing the files), so tests that
## need them are skipped when they are absent.

const SCENE := "res://levels/sandbox.tscn"
const PACKS := ["codemanu_pixel_fx", "matheusgg28_pixel_fx"]
const XYEZAWR := ["xyezawr_pack_1", "xyezawr_pack_2", "xyezawr_pack_2_extra", "xyezawr_pack_3"]

var _level: Sandbox


func before_test() -> void:
	_level = load(SCENE).instantiate()
	add_child(_level)


func after_test() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_level.queue_free()
	for action in [&"roll", &"flask", &"skill1", &"skill2", &"parry", &"attack"]:
		InputRouter.set_virtual_button(action, false)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _library(cue: String, root: Node = null) -> Array:
	var found := []
	for child in (root if root != null else _level).get_children():
		if child is AnimatedSprite2D and child.has_meta(&"library_fx") and child.get_meta(&"library_fx") == cue:
			found.append(child)
	return found


func _enemy(path: String = "res://data/enemies/shambler.tres") -> Enemy:
	return _level.spawn_enemy_at(load(path), _level.player.global_position + Vector2(40.0, 0.0))


# ------------------------------------------------------------------ the packs

func test_every_effect_of_the_shipped_packs_loads_all_its_frames() -> void:
	for pack in PACKS:
		var effects := LibraryFx.effects(pack)
		assert_int(effects.size()).override_failure_message(pack).is_greater(5)
		for effect in effects:
			var frames := LibraryFx.frames(pack, effect)
			assert_object(frames).override_failure_message("%s/%s" % [pack, effect]).is_not_null()
			assert_int(frames.get_frame_count(&"play")).is_equal(int(LibraryFx.info(pack, effect)["frames"]))


func test_the_xyezawr_packs_load_when_they_are_present() -> void:
	for pack in XYEZAWR:
		if not LibraryFx.has_pack(pack):
			continue
		for effect in LibraryFx.effects(pack):
			assert_object(LibraryFx.frames(pack, effect)).is_not_null()


func test_an_effect_plays_once_where_it_is_put_then_goes() -> void:
	var fx := LibraryFx.spawn(_level, "matheusgg28_pixel_fx/explosion_small", Vector2(100, 100))
	assert_object(fx).is_not_null()
	assert_vector(fx.global_position).is_equal(Vector2(100, 100))
	assert_bool(fx.is_playing()).is_true()
	await _frames(60)
	assert_bool(is_instance_valid(fx)).is_false()


func test_glowing_effects_are_added_over_the_scene() -> void:
	var fx := LibraryFx.spawn(_level, "codemanu_pixel_fx/magicspell", Vector2.ZERO)
	assert_int((fx.material as CanvasItemMaterial).blend_mode).is_equal(CanvasItemMaterial.BLEND_MODE_ADD)


func test_an_unknown_effect_is_quietly_skipped() -> void:
	assert_object(LibraryFx.spawn(_level, "no_pack/no_effect", Vector2.ZERO)).is_null()
	assert_object(LibraryFx.spawn(_level, "codemanu_pixel_fx/no_effect", Vector2.ZERO)).is_null()


# ------------------------------------------------------------------ where they play

func test_a_gauntlet_punch_lands_with_a_punch_impact() -> void:
	_level.player.set_weapon(0, load("res://data/weapons/iron_gauntlet.tres"))
	_level.player._weapon.start_attack()
	_level.player.hit_landed.emit(_enemy(), 6)
	assert_int(_library(CombatFx.CUE_PUNCH).size()).is_equal(1)


func test_a_bow_shot_lands_with_a_projectile_impact_and_a_wand_shot_with_a_magic_one() -> void:
	_level.player.set_weapon(0, load("res://data/weapons/hunters_bow.tres"))
	_level.player._weapon.start_attack()
	_level.player.hit_landed.emit(_enemy(), 7)
	assert_int(_library(CombatFx.CUE_ARROW_HIT).size()).is_equal(1)
	_level.player.set_weapon(0, load("res://data/weapons/ash_wand.tres"))
	_level.player._weapon.start_attack()
	_level.player.hit_landed.emit(_enemy(), 6)
	assert_int(_library(CombatFx.CUE_MAGIC_HIT).size()).is_equal(1)


func test_an_enemy_falls_into_dust_with_a_shock_burst() -> void:
	var enemy := _enemy()
	enemy.take_hit(100000, 0.0)
	assert_int(_library(CombatFx.CUE_DEATH_DUST).size()).is_equal(1)
	assert_int(_library(CombatFx.CUE_DEATH_BURST).size()).is_equal(1)


func test_a_boss_goes_out_in_a_chain_of_big_explosions() -> void:
	var boss := _enemy("res://data/bosses/hollow_bishop.tres")
	boss.take_hit(100000, 0.0)
	await _frames(40)
	assert_int(_library(CombatFx.CUE_BOSS_BLAST).size()).is_greater_equal(1)


func test_a_bosses_second_phase_bursts_out_of_it() -> void:
	var boss := _enemy("res://data/bosses/rime_colossus.tres")
	boss.take_hit(boss.health().max_health / 2 + 1, 0.0)
	assert_int(_library(CombatFx.CUE_PHASE).size()).is_equal(1)


func test_a_parry_rings_out_blue_and_a_perfect_one_violet() -> void:
	_level.player.parried.emit(false)
	assert_int(_library(CombatFx.CUE_PARRY).size()).is_equal(1)
	_level.player.parried.emit(true)
	assert_int(_library(CombatFx.CUE_PERFECT_PARRY).size()).is_equal(1)


func test_a_roll_kicks_up_dust_at_the_heros_feet() -> void:
	await _frames(30)
	InputRouter.set_virtual_button(&"roll", true)
	await _frames(3)
	InputRouter.set_virtual_button(&"roll", false)
	var dust := _library(CombatFx.CUE_ROLL_DUST)
	assert_int(dust.size()).is_equal(1)
	assert_float(dust[0].global_position.y).is_greater(_level.player.global_position.y)


func test_landing_from_a_fall_puffs_dust() -> void:
	await _frames(20)
	_level.player.global_position.y -= GameConfig.tiles(4.0)
	await _frames(60)
	assert_int(_library(CombatFx.CUE_LAND_DUST).size()).is_greater_equal(1)


func test_drinking_the_flask_bubbles() -> void:
	_level.player.drank.emit()
	assert_int(_library(CombatFx.CUE_DRINK).size()).is_equal(1)


func test_casting_storm_and_rend_shows_their_casts() -> void:
	_level.player.ability_cast.emit(&"storm")
	assert_int(_library(CombatFx.CUE_STORM_CAST).size()).is_equal(1)
	_level.player.ability_cast.emit(&"rend")
	assert_int(_library(CombatFx.CUE_REND_CAST).size()).is_equal(1)


func test_a_powder_keg_blows_up_in_a_big_explosion() -> void:
	var pilgrim := _enemy("res://data/enemies/powder_pilgrim.tres")
	pilgrim.exploded.emit()
	assert_int(_library(CombatFx.CUE_KEG).size()).is_equal(1)


func test_a_slam_sends_out_a_shockwave() -> void:
	var brute := _enemy("res://data/enemies/crown_brute.tres")
	brute.slammed.emit(brute.global_position)
	assert_int(_library(CombatFx.CUE_SLAM).size()).is_equal(1)


func test_a_summon_draws_a_circle_where_each_minion_appears() -> void:
	var boss := _enemy("res://data/bosses/hollow_bishop.tres")
	boss.summoned.emit(Vector2(10, 10))
	assert_int(_library(CombatFx.CUE_SUMMON).size()).is_equal(1)


func test_wand_shots_fly_as_animated_spells() -> void:
	var bolt := (load("res://data/weapons/ash_wand.tres") as WeaponData).chain[0]
	assert_str(String(bolt.projectile_fx)).is_not_empty()
	var shot := PlayerProjectile.new()
	_level.add_child(shot)
	shot.launch(_level.player._weapon, bolt, Vector2.RIGHT)
	assert_int(_library(String(bolt.projectile_fx), shot).size()).is_equal(1)
	shot.queue_free()


func test_a_double_jump_bursts_a_ring_under_the_feet_and_an_air_dash_leaves_a_trail() -> void:
	Sound.clear_history()
	_level.player.double_jumped.emit()
	assert_int(_library(CombatFx.CUE_DOUBLE_JUMP).size()).is_equal(1)
	_level.player.air_dashed.emit()
	assert_int(_library(CombatFx.CUE_AIR_DASH).size()).is_equal(1)
	assert_bool(Sound.history().has(&"roll")).is_true()
