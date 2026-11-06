extends Node3D
## Throwaway feasibility probe for a Blur-style arcade racer on iPhone Safari.
## One player car and seven AI cars race three laps with four items and particle effects.
## Not game code; do not build on it.

const Car := preload("res://car.gd")
const Track := preload("res://track.gd")
const AiDriver := preload("res://ai_driver.gd")
const Powerups := preload("res://powerups.gd")
const Fx := preload("res://fx.gd")
const Hud := preload("res://hud.gd")

enum State { COUNTDOWN, RACING, FINISHED }

const LAPS: int = 3
const CAR_COUNT: int = 8
const PLAYER_GRID_SLOT: int = 5
const COUNTDOWN_SECONDS: float = 3.0
const CAR_RADIUS: float = 1.2
const FPS_WINDOW_SEC: float = 5.0
const CAR_COLORS: Array[Color] = [
	Color(0.15, 0.45, 0.95), Color(0.9, 0.2, 0.2), Color(0.95, 0.8, 0.15), Color(0.2, 0.75, 0.35),
	Color(0.7, 0.3, 0.9), Color(0.95, 0.55, 0.15), Color(0.15, 0.8, 0.85), Color(0.9, 0.9, 0.9),
]

var _rng := RandomNumberGenerator.new()
var _track: Track
var _cars: Array[Car] = []
var _drivers: Array[AiDriver] = []
var _player: Car
var _powerups: Powerups
var _hud: Node
var _camera: Camera3D
var _sun: DirectionalLight3D
var _state: State = State.COUNTDOWN
var _countdown: float = COUNTDOWN_SECONDS
var _race_time: float = 0.0
var _player_brake: bool = false
var _auto_player: bool = false
var _frame_log: Array[Vector2] = []  # x = timestamp (sec), y = frame time (sec)
var _max_lateral_seen: float = 0.0


func _ready() -> void:
	_rng.seed = 5
	_track = Track.new()
	_build_environment()
	_build_track_and_scenery()
	_build_cars()
	_powerups = Powerups.new()
	add_child(_powerups)
	_powerups.setup(_track, _cars)
	_build_camera()
	_hud = Hud.new()
	add_child(_hud)
	_hud.brake_changed.connect(func(pressed: bool) -> void: _player_brake = pressed)
	_hud.use_pressed.connect(func() -> void: _powerups.use_item(_player))
	_hud.restart_pressed.connect(_restart)
	_hud.shadows_toggled.connect(func(on: bool) -> void: _sun.shadow_enabled = on)
	_hud.particles_toggled.connect(func(on: bool) -> void: Fx.enabled = on)
	_hud.render_scale_changed.connect(func(value: float) -> void: get_viewport().scaling_3d_scale = value)
	_restart()
	if "--selftest" in OS.get_cmdline_user_args():
		_run_selftest()


func _process(delta: float) -> void:
	_sim_step(minf(delta, 1.0 / 30.0))
	_update_camera(delta)
	_update_hud(delta)


# --- setup ----------------------------------------------------------------------

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.75, 0.9)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.85, 0.95)
	environment.ambient_light_energy = 0.6
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.6, 0.75, 0.9)
	environment.fog_density = 0.004
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 60.0
	add_child(_sun)


func _build_track_and_scenery() -> void:
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(900.0, 900.0)
	ground_mesh.material = _flat_material(Color(0.32, 0.52, 0.28))
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.position.y = -0.02
	add_child(ground)
	var road := MeshInstance3D.new()
	road.mesh = _track.build_mesh()
	var road_material := StandardMaterial3D.new()
	road_material.vertex_color_use_as_albedo = true
	road_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.material_override = road_material
	add_child(road)
	_scatter_trees(300)


func _scatter_trees(count: int) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.6
	cone.height = 5.0
	cone.radial_segments = 6
	cone.rings = 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = cone
	var placed: Array[Transform3D] = []
	while placed.size() < count:
		var pos := Vector3(_rng.randf_range(-380.0, 380.0), 0.0, _rng.randf_range(-380.0, 380.0))
		if _track.distance_to_track(pos) < Track.HALF_WIDTH + 12.0:
			continue
		var s: float = _rng.randf_range(0.8, 1.6)
		var rot := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
		placed.append(Transform3D(rot, pos + Vector3(0.0, 2.5 * s, 0.0)))
	multimesh.instance_count = placed.size()
	for i in placed.size():
		multimesh.set_instance_transform(i, placed[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _flat_material(Color(0.12, 0.38, 0.16))
	add_child(instance)


func _build_cars() -> void:
	for slot in CAR_COUNT:
		var car := Car.new()
		car.setup(CAR_COLORS[slot], "YOU" if slot == PLAYER_GRID_SLOT else "CPU %d" % slot)
		car.is_player = slot == PLAYER_GRID_SLOT
		car.top_speed_factor = 1.0 if car.is_player else _rng.randf_range(0.92, 1.0)
		add_child(car)
		_cars.append(car)
		var driver := AiDriver.new()
		driver.lane_offset = _rng.randf_range(-3.5, 3.5)
		driver.caution = _rng.randf_range(0.9, 1.15)
		_drivers.append(driver)
		if car.is_player:
			_player = car


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 68.0
	_camera.far = 500.0
	add_child(_camera)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _restart() -> void:
	for slot in CAR_COUNT:
		var row: int = slot / 2
		var index: int = _track.wrap_index(Track.SAMPLE_COUNT - 3 - row * 3)
		var lane: float = -2.5 if slot % 2 == 0 else 2.5
		var pos: Vector3 = _track.points[index] + _track.rights[index] * lane
		_cars[slot].place(pos, _track.heading_at(index))
		_cars[slot].track_index = index
		_cars[slot].steer = 0.0
		_cars[slot].braking = false
		_cars[slot].throttle = 1.0
	_powerups.reset()
	_state = State.COUNTDOWN
	_countdown = COUNTDOWN_SECONDS
	_race_time = 0.0


# --- simulation (no rendering; the self-test calls this directly) ----------------

func _sim_step(dt: float) -> void:
	if _state == State.COUNTDOWN:
		_countdown -= dt
		if _countdown <= 0.0:
			_state = State.RACING
		return
	_race_time += dt
	for slot in CAR_COUNT:
		var car: Car = _cars[slot]
		if car.is_player and not _auto_player:
			_apply_player_input(car)
		else:
			_drivers[slot].drive(car, _track)
		car.step(dt)
		_keep_on_track(car)
		_update_progress(car)
		if not car.is_player or _auto_player:
			_ai_use_items(car, dt)
	_collide_cars()
	_powerups.update(dt)
	if _player.finished and _state == State.RACING:
		_state = State.FINISHED


func _apply_player_input(car: Car) -> void:
	var steer: float = _hud.steer_input + Input.get_axis("ui_left", "ui_right")
	car.steer = clampf(steer, -1.0, 1.0)
	car.braking = _player_brake or Input.is_key_pressed(KEY_SPACE)
	car.throttle = 1.0


func _ai_use_items(car: Car, dt: float) -> void:
	if car.item == Car.Item.NONE:
		return
	car.item_use_timer -= dt
	if car.item_use_timer <= 0.0:
		_powerups.use_item(car)


func _keep_on_track(car: Car) -> void:
	var index: int = _track.nearest_index(car.position, car.track_index)
	var lateral: float = _track.lateral_offset(car.position, index)
	_max_lateral_seen = maxf(_max_lateral_seen, absf(lateral))
	var limit: float = Track.HALF_WIDTH - CAR_RADIUS
	if absf(lateral) <= limit:
		return
	var side: float = signf(lateral)
	var right: Vector3 = _track.rights[index]
	car.position -= right * (lateral - side * limit)
	var inward: Vector3 = -right * side
	var into_wall: float = car.velocity.dot(inward)
	if into_wall < 0.0:
		car.velocity -= inward * into_wall * 1.3
	car.velocity *= 0.92
	car.heading = lerp_angle(car.heading, _track.heading_at(index), 0.08)


func _update_progress(car: Car) -> void:
	var index: int = _track.nearest_index(car.position, car.track_index)
	var count: int = Track.SAMPLE_COUNT
	if car.track_index > count * 3 / 4 and index < count / 4:
		car.lap += 1
		if car.lap > LAPS and not car.finished:
			car.finished = true
			car.finish_time = _race_time
	elif car.track_index < count / 4 and index > count * 3 / 4:
		car.lap -= 1
	car.track_index = index


func _collide_cars() -> void:
	var min_gap: float = CAR_RADIUS * 2.0
	for i in CAR_COUNT:
		for j in range(i + 1, CAR_COUNT):
			var offset: Vector3 = _cars[j].position - _cars[i].position
			offset.y = 0.0
			var distance: float = offset.length()
			if distance >= min_gap or distance < 0.001:
				continue
			var normal: Vector3 = offset / distance
			var push: float = (min_gap - distance) * 0.5
			_cars[i].position -= normal * push
			_cars[j].position += normal * push
			var closing: float = (_cars[j].velocity - _cars[i].velocity).dot(normal)
			if closing < 0.0:
				_cars[i].velocity += normal * closing * 0.5
				_cars[j].velocity -= normal * closing * 0.5


func _race_place(car: Car) -> int:
	var place: int = 1
	var own: int = car.lap * Track.SAMPLE_COUNT + car.track_index
	for other in _cars:
		if other != car and other.lap * Track.SAMPLE_COUNT + other.track_index > own:
			place += 1
	return place


# --- camera and HUD -------------------------------------------------------------

func _update_camera(delta: float) -> void:
	var forward: Vector3 = _player.forward()
	var target: Vector3 = _player.position - forward * 7.5 + Vector3(0.0, 3.2, 0.0)
	_camera.position = _camera.position.lerp(target, 1.0 - exp(-7.0 * delta))
	_camera.look_at(_player.position + forward * 8.0 + Vector3.UP, Vector3.UP)
	var boost_fov: float = 10.0 if _player.boost_time > 0.0 else 0.0
	_camera.fov = lerpf(_camera.fov, 68.0 + _player.speed() * 0.35 + boost_fov, 1.0 - exp(-4.0 * delta))


func _update_hud(delta: float) -> void:
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
	var item_text: String = _powerups.item_name(_player.item)
	_hud.set_stats("P %d/%d  LAP %d/%d  %d km/h  ITEM %s\nFPS %d  avg %d  worst %d ms" % [
		_race_place(_player), CAR_COUNT, clampi(_player.lap, 1, LAPS), LAPS,
		roundi(absf(_player.speed()) * 3.6), item_text if item_text != "" else "-",
		Engine.get_frames_per_second(), roundi(average_fps), roundi(worst * 1000.0)])
	match _state:
		State.COUNTDOWN:
			_hud.set_message(str(ceili(_countdown)))
		State.RACING:
			_hud.set_message("GO!" if _race_time < 1.0 else "")
		State.FINISHED:
			_hud.set_message("FINISH  P%d\n%.1f s" % [_race_place(_player), _player.finish_time])


# --- self test (run: godot --headless --path . -- --selftest) -------------------

func _run_selftest() -> void:
	await get_tree().process_frame
	set_process(false)
	var failures: Array[String] = []
	_auto_player = true
	_restart()
	var step: float = 1.0 / 60.0
	var elapsed: float = 0.0
	while elapsed < 150.0 and not _all_finished():
		_sim_step(step)
		elapsed += step
		for car in _cars:
			if not (is_finite(car.position.x) and is_finite(car.position.z)):
				failures.append("%s position is not finite" % car.display_name)
	var radius: float = _track.min_turn_radius()
	if radius < 25.0:
		failures.append("track too tight: min turn radius %.1f m" % radius)
	if _max_lateral_seen > Track.HALF_WIDTH + 0.5:
		failures.append("a car left the track: lateral %.2f" % _max_lateral_seen)
	var finishers: int = 0
	for car in _cars:
		if car.finished:
			finishers += 1
	if finishers == 0:
		failures.append("no car finished %d laps in %.0f s" % [LAPS, elapsed])
	if _powerups.collected_count == 0:
		failures.append("no item was collected")
	if _powerups.used_count == 0:
		failures.append("no item was used")
	print("SELFTEST stats: sim=%.0fs finishers=%d collected=%d used=%d hits=%d max_lateral=%.2f min_turn_radius=%.1fm track=%.0fm" % [
		elapsed, finishers, _powerups.collected_count, _powerups.used_count, _powerups.hit_count,
		_max_lateral_seen, radius, _track.length])
	# Player input path: steering and the USE button must change the player's state.
	_restart()
	_auto_player = false
	_state = State.RACING
	_player_brake = true
	_sim_step(step)
	if not _player.braking:
		failures.append("brake input did not reach the player car")
	_player.item = Car.Item.BOOST
	_hud.use_pressed.emit()
	if _player.boost_time <= 0.0:
		failures.append("USE button did not trigger the boost item")
	if failures.is_empty():
		print("SELFTEST OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SELFTEST FAIL: " + failure)
		get_tree().quit(1)


func _all_finished() -> bool:
	for car in _cars:
		if not car.finished:
			return false
	return true
