extends Node3D
## Throwaway feasibility probe for an isometric action RPG on iPhone Safari.
## Stresses the renderer with many enemies, particle-heavy skills, shadows and render scale,
## and shows a frame-rate readout. Not game code; do not build on it.

const Hud := preload("res://hud.gd")

const WORLD_HALF: float = 60.0
const START_ENEMIES: int = 40
const PLAYER_SPEED: float = 7.0
const ENEMY_SPEED: float = 2.6
const ENEMY_HP: int = 3
const CAM_OFFSET: Vector3 = Vector3(17.0, 23.0, 17.0)
const FPS_WINDOW_SEC: float = 5.0
const FIREBALL_SPEED: float = 18.0
const STORM_SECONDS: float = 3.0


class Enemy extends Node3D:
	var hp: int = 3
	var knock: Vector3 = Vector3.ZERO


var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _hud: Node
var _enemies: Array[Enemy] = []
var _target_enemies: int = START_ENEMIES
var _facing: Vector3 = Vector3(-1, 0, -1).normalized()
var _fireballs: Array[Dictionary] = []
var _storm_left: float = 0.0
var _storm_tick: float = 0.0
var _particles_on: bool = true
var _kills: int = 0
var _frame_log: Array[Vector2] = []  # x = timestamp (sec), y = frame time (sec)


func _ready() -> void:
	_rng.seed = 7
	_build_environment()
	_build_ground()
	_scatter(_tree_mesh(), 500, Color(0.12, 0.38, 0.16), 0.7, 1.4, 1.5)
	_scatter(_rock_mesh(), 200, Color(0.45, 0.45, 0.48), 0.6, 1.8, 0.3)
	_build_player()
	_build_camera()
	_hud = Hud.new()
	add_child(_hud)
	_hud.skill_pressed.connect(_use_skill)
	_hud.shadows_toggled.connect(func(on: bool) -> void: _sun.shadow_enabled = on)
	_hud.particles_toggled.connect(func(on: bool) -> void: _particles_on = on)
	_hud.render_scale_changed.connect(func(value: float) -> void: get_viewport().scaling_3d_scale = value)
	_hud.enemies_added.connect(_add_enemies)
	_top_up_enemies()
	if "--selftest" in OS.get_cmdline_user_args():
		_run_selftest()


func _process(delta: float) -> void:
	_move_player(delta)
	_update_camera(delta)
	_update_enemies(delta)
	_update_fireballs(delta)
	_update_storm(delta)
	_record_frame(delta)


# --- world building -------------------------------------------------------------

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.7, 0.85)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.8, 0.9)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-60.0, 40.0, 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * WORLD_HALF * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.55, 0.28)
	plane.material = material
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	add_child(ground)


func _tree_mesh() -> Mesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.9
	cone.height = 3.0
	cone.radial_segments = 6
	cone.rings = 1
	return cone


func _rock_mesh() -> Mesh:
	var rock := SphereMesh.new()
	rock.radius = 0.8
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	return rock


func _scatter(mesh: Mesh, count: int, color: Color, min_scale: float, max_scale: float, lift: float) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = count
	for i in count:
		var pos := Vector3(
			_rng.randf_range(-WORLD_HALF, WORLD_HALF), 0.0, _rng.randf_range(-WORLD_HALF, WORLD_HALF))
		if Vector2(pos.x, pos.z).length() < 5.0:
			pos.x += 8.0
		var s: float = _rng.randf_range(min_scale, max_scale)
		var rot := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
		multimesh.set_instance_transform(i, Transform3D(rot, pos + Vector3(0.0, lift * s, 0.0)))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	add_child(instance)


func _build_player() -> void:
	_player = Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	body.material_override = _flat_material(Color(0.2, 0.45, 0.95))
	_player.add_child(body)
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.25, 0.5)
	nose.mesh = box
	nose.position = Vector3(0.0, 1.3, 0.45)
	nose.material_override = _flat_material(Color(1.0, 0.9, 0.4))
	_player.add_child(nose)
	add_child(_player)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_camera.far = 150.0
	add_child(_camera)
	_camera.position = CAM_OFFSET
	_camera.look_at(Vector3.ZERO)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


# --- player and camera ----------------------------------------------------------

func _move_player(delta: float) -> void:
	var input: Vector2 = _hud.move_vector + Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input = input.limit_length(1.0)
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, PI / 4.0)
	if direction.length() > 0.05:
		_player.position += direction * PLAYER_SPEED * delta
		_player.position.x = clampf(_player.position.x, -WORLD_HALF + 2.0, WORLD_HALF - 2.0)
		_player.position.z = clampf(_player.position.z, -WORLD_HALF + 2.0, WORLD_HALF - 2.0)
		_facing = direction.normalized()
		_player.rotation.y = atan2(_facing.x, _facing.z)


func _update_camera(delta: float) -> void:
	var target: Vector3 = _player.position + CAM_OFFSET
	_camera.position = _camera.position.lerp(target, 1.0 - exp(-8.0 * delta))


# --- enemies --------------------------------------------------------------------

func _add_enemies(count: int) -> void:
	_target_enemies += count
	_top_up_enemies()


func _top_up_enemies() -> void:
	while _enemies.size() < _target_enemies:
		_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy := Enemy.new()
	enemy.hp = ENEMY_HP
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.7
	mesh.mesh = capsule
	mesh.position.y = 0.85
	mesh.material_override = _flat_material(Color(0.8, 0.2, 0.2))
	enemy.add_child(mesh)
	var angle: float = _rng.randf() * TAU
	var distance: float = _rng.randf_range(18.0, 35.0)
	var pos: Vector3 = _player.position + Vector3(cos(angle), 0.0, sin(angle)) * distance
	pos.x = clampf(pos.x, -WORLD_HALF + 1.0, WORLD_HALF - 1.0)
	pos.z = clampf(pos.z, -WORLD_HALF + 1.0, WORLD_HALF - 1.0)
	add_child(enemy)
	enemy.position = pos
	_enemies.append(enemy)


func _update_enemies(delta: float) -> void:
	for enemy in _enemies:
		var to_player: Vector3 = _player.position - enemy.position
		to_player.y = 0.0
		if to_player.length() > 1.3:
			enemy.position += to_player.normalized() * ENEMY_SPEED * delta
		enemy.position += enemy.knock * delta
		enemy.knock = enemy.knock.move_toward(Vector3.ZERO, 30.0 * delta)


func _kill_enemy(enemy: Enemy) -> void:
	_burst(enemy.position + Vector3.UP, Color(1.0, 0.4, 0.2), 30, 0.5, 4.0)
	_enemies.erase(enemy)
	enemy.queue_free()
	_kills += 1
	_top_up_enemies()


func _damage_area(center: Vector3, radius: float, damage: int, knock_strength: float) -> void:
	for enemy in _enemies.duplicate():
		var offset: Vector3 = enemy.position - center
		offset.y = 0.0
		if offset.length() > radius:
			continue
		enemy.hp -= damage
		enemy.knock = offset.normalized() * knock_strength
		if enemy.hp <= 0:
			_kill_enemy(enemy)


# --- skills ---------------------------------------------------------------------

func _use_skill(index: int) -> void:
	match index:
		0: _skill_slash()
		1: _skill_nova()
		2: _skill_fireball()
		3: _skill_storm()


func _skill_slash() -> void:
	var center: Vector3 = _player.position + _facing * 1.8
	_damage_area(center, 2.6, 1, 8.0)
	_burst(center + Vector3.UP, Color(1.0, 0.95, 0.7), 40, 0.3, 4.0)


func _skill_nova() -> void:
	_damage_area(_player.position, 6.0, 2, 14.0)
	if not _particles_on:
		return
	var particles := _make_particles(Color(0.4, 0.7, 1.0), 400, 0.8, true)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_axis = Vector3.UP
	material.emission_ring_height = 0.3
	material.emission_ring_radius = 1.0
	material.emission_ring_inner_radius = 0.8
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 0.0
	material.radial_velocity_min = 7.0
	material.radial_velocity_max = 9.0
	material.gravity = Vector3.ZERO
	particles.process_material = material
	_spawn_fx(particles, _player.position + Vector3.UP * 0.4, 0.8)


func _skill_fireball() -> void:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.6, 0.15)
	mesh.material_override = material
	node.add_child(mesh)
	if _particles_on:
		var trail := _make_particles(Color(1.0, 0.45, 0.1), 80, 0.5, false)
		var trail_material := ParticleProcessMaterial.new()
		trail_material.direction = Vector3.UP
		trail_material.spread = 40.0
		trail_material.initial_velocity_min = 0.2
		trail_material.initial_velocity_max = 1.0
		trail_material.gravity = Vector3.ZERO
		trail.process_material = trail_material
		trail.local_coords = false
		trail.emitting = true
		node.add_child(trail)
	add_child(node)
	node.position = _player.position + Vector3.UP * 1.0 + _facing
	_fireballs.append({"node": node, "direction": _facing, "life": 1.2})


func _skill_storm() -> void:
	_storm_left = STORM_SECONDS
	_storm_tick = 0.0
	if not _particles_on:
		return
	var particles := _make_particles(Color(0.7, 0.5, 1.0), 800, 0.9, false)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(5.0, 0.2, 5.0)
	material.direction = Vector3.DOWN
	material.spread = 5.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 12.0
	material.gravity = Vector3.ZERO
	particles.process_material = material
	particles.emitting = true
	add_child(particles)
	particles.position = _player.position + Vector3.UP * 8.0
	get_tree().create_timer(STORM_SECONDS).timeout.connect(func() -> void: particles.emitting = false)
	get_tree().create_timer(STORM_SECONDS + 1.5).timeout.connect(particles.queue_free)


func _update_fireballs(delta: float) -> void:
	for fireball in _fireballs.duplicate():
		var node: Node3D = fireball["node"]
		node.position += (fireball["direction"] as Vector3) * FIREBALL_SPEED * delta
		fireball["life"] = (fireball["life"] as float) - delta
		var hit: bool = false
		for enemy in _enemies:
			if enemy.position.distance_to(node.position) < 1.4:
				hit = true
				break
		if hit or fireball["life"] <= 0.0:
			_damage_area(node.position, 4.0, 3, 16.0)
			_burst(node.position, Color(1.0, 0.5, 0.15), 120, 0.7, 7.0)
			_fireballs.erase(fireball)
			node.queue_free()


func _update_storm(delta: float) -> void:
	if _storm_left <= 0.0:
		return
	_storm_left -= delta
	_storm_tick -= delta
	if _storm_tick <= 0.0:
		_storm_tick = 0.5
		_damage_area(_player.position, 5.0, 1, 6.0)


# --- particles ------------------------------------------------------------------

func _make_particles(color: Color, amount: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.explosiveness = 0.9 if one_shot else 0.0
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 16, 24))
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = material
	particles.draw_pass_1 = mesh
	return particles


func _burst(pos: Vector3, color: Color, amount: int, lifetime: float, speed: float) -> void:
	if not _particles_on:
		return
	var particles := _make_particles(color, amount, lifetime, true)
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = speed * 0.4
	material.initial_velocity_max = speed
	material.gravity = Vector3(0.0, -6.0, 0.0)
	particles.process_material = material
	_spawn_fx(particles, pos, lifetime)


func _spawn_fx(particles: GPUParticles3D, pos: Vector3, lifetime: float) -> void:
	add_child(particles)
	particles.position = pos
	particles.emitting = true
	get_tree().create_timer(lifetime + 0.6).timeout.connect(particles.queue_free)


# --- stats ----------------------------------------------------------------------

func _record_frame(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_frame_log.append(Vector2(now, delta))
	while _frame_log.size() > 1 and now - _frame_log[0].x > FPS_WINDOW_SEC:
		_frame_log.pop_front()
	var worst: float = 0.0
	var total: float = 0.0
	for sample in _frame_log:
		worst = maxf(worst, sample.y)
		total += sample.y
	var average_fps: float = float(_frame_log.size()) / maxf(total, 0.0001)
	_hud.set_stats("FPS %d  avg %d  worst %d ms  enemies %d  kills %d" % [
		Engine.get_frames_per_second(), roundi(average_fps), roundi(worst * 1000.0),
		_enemies.size(), _kills])


# --- self test (run: godot --headless --path . -- --selftest) -------------------

func _run_selftest() -> void:
	await get_tree().process_frame
	var failures: Array[String] = []
	_player.position = Vector3.ZERO
	for i in 4:
		_use_skill(i)
		await get_tree().create_timer(0.4).timeout
	_hud.enemies_added.emit(20)
	_hud.shadows_toggled.emit(false)
	_hud.particles_toggled.emit(false)
	_hud.render_scale_changed.emit(0.75)
	await get_tree().create_timer(3.5).timeout
	if _enemies.size() != _target_enemies:
		failures.append("enemy count %d != target %d" % [_enemies.size(), _target_enemies])
	if _target_enemies != START_ENEMIES + 20:
		failures.append("+20 enemies button did not raise the target")
	if _sun.shadow_enabled:
		failures.append("shadow toggle did not turn shadows off")
	if _frame_log.is_empty():
		failures.append("no frames recorded")
	if failures.is_empty():
		print("SELFTEST OK enemies=%d kills=%d frames=%d" % [_enemies.size(), _kills, _frame_log.size()])
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SELFTEST FAIL: " + failure)
		get_tree().quit(1)
