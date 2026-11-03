extends GdUnitTestSuite
## Weapons found in a run: a pickup on the floor swaps into the hero's hand, leaving his old weapon in its place.

const SANDBOX := "res://levels/sandbox.tscn"
const LEVEL := "res://levels/generated_level.tscn"
const BOW := "res://data/weapons/hunters_bow.tres"

var _level: Node


func after_test() -> void:
	get_tree().paused = false
	if is_instance_valid(_level):
		_level.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _sandbox() -> Sandbox:
	_level = load(SANDBOX).instantiate()
	add_child(_level)
	return _level


func test_a_pickup_shows_its_weapons_icon() -> void:
	var level := _sandbox()
	var pickup := WeaponPickup.spawn(level, load(BOW), level.player.global_position + Vector2(120, 0))
	assert_str((pickup.get_node("Icon") as Sprite2D).texture.resource_path).contains("bow")


func test_walking_into_a_pickup_swaps_it_into_the_heros_hand() -> void:
	var level := _sandbox()
	await _frames(30)
	var old := level.player.weapon_in_slot(level.player.active_slot())
	var pickup := WeaponPickup.spawn(level, load(BOW), level.player.global_position + Vector2(60, 0))
	await _frames(2)
	pickup.global_position = level.player.global_position
	await _frames(4)
	assert_str(level.player.weapon_in_slot(level.player.active_slot()).display_name).is_equal("Hunter's Bow")
	assert_object(pickup.weapon()).is_same(old)


func test_the_old_weapon_is_not_picked_straight_back_up() -> void:
	var level := _sandbox()
	await _frames(30)
	var pickup := WeaponPickup.spawn(level, load(BOW), level.player.global_position)
	await _frames(10)
	assert_str(level.player.weapon_in_slot(level.player.active_slot()).display_name).is_equal("Hunter's Bow")
	await _frames(30)
	assert_str(level.player.weapon_in_slot(level.player.active_slot()).display_name).is_equal("Hunter's Bow")


func test_a_beaten_boss_drops_a_weapon_the_hero_does_not_carry() -> void:
	_level = load(LEVEL).instantiate()
	_level.level_seed = 5
	add_child(_level)
	var level := _level as GeneratedLevel
	level.set_depth(2)
	level.regenerate(5)
	level._on_boss_died(level.biome().boss)
	var drops := level.get_children().filter(func(n: Node) -> bool: return n is WeaponPickup)
	assert_int(drops.size()).is_equal(1)
	var held := [level.player.weapon_in_slot(0), level.player.weapon_in_slot(1)].map(func(w: WeaponData) -> String: return w.resource_path)
	assert_bool(held.has((drops[0] as WeaponPickup).weapon().resource_path)).is_false()
