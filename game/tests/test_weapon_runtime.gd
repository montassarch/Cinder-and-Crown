extends GdUnitTestSuite
## The Weapon plays one move at a time: melee moves open a hitbox, projectile moves fire shots.

const DUMMY := preload("res://tests/support/hurtable_dummy.gd")

var _weapon: Weapon
var _holder: Node2D


func before_test() -> void:
	_holder = auto_free(Node2D.new())
	add_child(_holder)
	_weapon = Weapon.new()
	_weapon.projectile_parent = _holder
	_holder.add_child(_weapon)
	var data := WeaponData.new()
	data.display_name = "Test"
	data.damage = 10
	_weapon.equip(data)


func after_test() -> void:
	Engine.time_scale = 1.0


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _melee(multiplier: float = 1.0, window: Vector2 = Vector2(0.1, 0.2), duration: float = 0.4) -> WeaponMove:
	var m := WeaponMove.new()
	m.damage_multiplier = multiplier
	m.duration = duration
	m.hit_window = window
	m.hitbox_size_tiles = Vector2(1.0, 1.0)
	m.hitbox_offset_tiles = Vector2(1.0, 0.0)
	return m


func _shot(count: int = 1, angle: float = 0.0, spread: float = 0.0) -> WeaponMove:
	var m := _melee(1.0, Vector2(0.1, 0.2))
	m.kind = WeaponMove.Kind.PROJECTILE
	m.projectile_count = count
	m.projectile_angle_degrees = angle
	m.projectile_spread_degrees = spread
	m.projectile_speed_tiles = 20.0
	m.projectile_range_tiles = 10.0
	return m


func _shots() -> Array:
	return _holder.get_children().filter(func(n: Node) -> bool: return n is PlayerProjectile)


func test_a_move_brings_its_own_hit_window_and_duration() -> void:
	_weapon.start_move(_melee(1.0, Vector2(0.3, 0.4), 0.6))
	_weapon.advance(0.1)
	assert_bool(_weapon.is_hitbox_active()).is_false()
	_weapon.advance(0.25)
	assert_bool(_weapon.is_hitbox_active()).is_true()
	_weapon.advance(0.1)
	assert_bool(_weapon.is_hitbox_active()).is_false()
	assert_bool(_weapon.is_recovering()).is_true()
	_weapon.advance(0.2)
	assert_bool(_weapon.is_recovering()).is_false()


func test_a_move_brings_its_own_hitbox_shape() -> void:
	var move := _melee()
	move.hitbox_size_tiles = Vector2(3.0, 0.5)
	move.hitbox_offset_tiles = Vector2(2.0, 0.25)
	_weapon.start_move(move)
	assert_vector(_weapon.hitbox_size()).is_equal(GameConfig.tiles_v(3.0, 0.5))
	assert_vector(_weapon.hitbox_center()).is_equal(GameConfig.tiles_v(2.0, 0.25))
	_weapon.set_facing(-1.0)
	assert_vector(_weapon.hitbox_center()).is_equal(GameConfig.tiles_v(-2.0, 0.25))


func test_a_melee_move_hits_for_the_weapon_damage_times_its_multiplier() -> void:
	var dummy = auto_free(DUMMY.new())
	dummy.position = GameConfig.tiles_v(1.0, 0.0)
	add_child(dummy)
	_weapon.start_move(_melee(2.0))
	await _frames(40)
	assert_int(dummy.hits.size()).is_equal(1)
	assert_int(dummy.hits[0][0]).is_equal(20)


func test_a_move_hits_with_its_own_knockback_and_hit_stop() -> void:
	var dummy = auto_free(DUMMY.new())
	dummy.position = GameConfig.tiles_v(1.0, 0.0)
	add_child(dummy)
	var move := _melee()
	move.knockback_tiles = 4.5
	_weapon.start_move(move)
	await _frames(40)
	assert_float(dummy.hits[0][2]).is_equal(4.5)


func test_a_projectile_move_opens_no_melee_hitbox() -> void:
	_weapon.start_move(_shot())
	_weapon.advance(0.15)
	assert_bool(_weapon.is_hitbox_active()).is_false()


func test_a_shot_is_fired_when_the_window_opens_not_before() -> void:
	_weapon.start_move(_shot())
	_weapon.advance(0.05)
	assert_int(_shots().size()).is_equal(0)
	_weapon.advance(0.1)
	assert_int(_shots().size()).is_equal(1)
	_weapon.advance(0.1)
	assert_int(_shots().size()).is_equal(1)    # one volley per move


func test_cancelling_before_the_window_fires_nothing() -> void:
	_weapon.start_move(_shot())
	_weapon.advance(0.05)
	_weapon.cancel_attack()
	_weapon.advance(0.2)
	assert_int(_shots().size()).is_equal(0)


func test_a_volley_fans_out_around_the_aim() -> void:
	_weapon.start_move(_shot(3, 0.0, 30.0))
	_weapon.advance(0.15)
	var angles := _shots().map(func(s: PlayerProjectile) -> float: return snappedf(rad_to_deg(s.direction().angle()), 0.1))
	angles.sort()
	assert_array(angles).is_equal([-15.0, 0.0, 15.0])


func test_a_downward_shot_aims_at_the_ground_and_mirrors_when_facing_left() -> void:
	_weapon.start_move(_shot(1, 40.0))
	_weapon.advance(0.15)
	var right: PlayerProjectile = _shots()[0]
	assert_float(right.direction().x).is_greater(0.0)
	assert_float(right.direction().y).is_greater(0.0)
	right.queue_free()
	_weapon.set_facing(-1.0)
	_weapon.start_move(_shot(1, 40.0))
	_weapon.advance(0.15)
	var left: PlayerProjectile = _shots().filter(func(s: PlayerProjectile) -> bool: return not s.is_queued_for_deletion())[0]
	assert_float(left.direction().x).is_less(0.0)
	assert_float(left.direction().y).is_greater(0.0)


func test_a_shot_flies_hits_an_enemy_once_and_is_spent() -> void:
	var dummy = auto_free(DUMMY.new())
	dummy.position = GameConfig.tiles_v(4.0, 0.0)
	add_child(dummy)
	_weapon.start_move(_shot())
	await _frames(60)
	assert_int(dummy.hits.size()).is_equal(1)
	assert_int(dummy.hits[0][0]).is_equal(10)
	assert_int(_shots().size()).is_equal(0)


func test_a_piercing_shot_passes_through_to_the_next_enemy() -> void:
	var first = auto_free(DUMMY.new())
	first.position = GameConfig.tiles_v(3.0, 0.0)
	add_child(first)
	var second = auto_free(DUMMY.new())
	second.position = GameConfig.tiles_v(6.0, 0.0)
	add_child(second)
	var move := _shot()
	move.projectile_pierce = 1
	_weapon.start_move(move)
	await _frames(80)
	assert_int(first.hits.size()).is_equal(1)
	assert_int(second.hits.size()).is_equal(1)


func test_a_shot_falls_away_after_its_range() -> void:
	_weapon.start_move(_shot())
	await _frames(90)
	assert_int(_shots().size()).is_equal(0)


func test_a_shot_that_lands_reports_the_hit() -> void:
	var dummy = auto_free(DUMMY.new())
	dummy.position = GameConfig.tiles_v(4.0, 0.0)
	add_child(dummy)
	var landed := []
	_weapon.hit_landed.connect(func(target: Node, damage: int) -> void: landed.append([target, damage]))
	_weapon.start_move(_shot())
	await _frames(60)
	assert_int(landed.size()).is_equal(1)
