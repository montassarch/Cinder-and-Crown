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
	var found: Array[String] = MenuScript.list_resources(MenuScript.ENEMY_DIR)
	assert_int(found.size()).is_equal(3)
	for path: String in found:
		assert_object(load(path)).is_instanceof(EnemyData)


func test_menu_discovers_every_shipped_weapon_from_disk() -> void:
	var found: Array[String] = MenuScript.list_resources(MenuScript.WEAPON_DIR)
	assert_int(found.size()).is_equal(2)
	for path: String in found:
		assert_object(load(path)).is_instanceof(WeaponData)


func test_resource_scan_tolerates_export_renaming() -> void:
	# Export can turn a .tres into .res and can append .remap. A scan that
	# only matched ".tres" would find nothing in an exported build, so the
	# menu would come up empty on the very build we ship to the phone.
	assert_array(MenuScript.list_resources("res://data/weapons")).is_not_empty()
	assert_array(MenuScript.list_resources("res://does/not/exist")).is_empty()
