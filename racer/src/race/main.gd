extends Node3D
## Throwaway feasibility probe for a Blur-style arcade racer on iPhone Safari.
## One player car and seven AI cars race three laps with seven items, car health and particle effects.
## Not game code; do not build on it.

const Car := preload("res://src/cars/car.gd")
const Track := preload("res://src/track/track.gd")
const AiDriver := preload("res://src/cars/ai_driver.gd")
const Powerups := preload("res://src/items/powerups.gd")
const Fx := preload("res://src/fx/fx.gd")
const Hud := preload("res://src/ui/hud.gd")
const CarCatalog := preload("res://src/cars/car_catalog.gd")
const CarSpec := preload("res://src/cars/car_spec.gd")
const Look := preload("res://src/fx/look.gd")
const TrackScenery := preload("res://src/track/track_scenery.gd")
const Settings := preload("res://src/core/settings.gd")
const ItemDefs := preload("res://src/items/item_defs.gd")

enum State { LOADING, COUNTDOWN, RACING, FINISHED }

const LAPS: int = 3
const CAR_COUNT: int = 8
const PLAYER_GRID_SLOT: int = 5
const COUNTDOWN_SECONDS: float = 3.0
const CAR_RADIUS: float = 1.2
const WALL_DAMAGE_SPEED: float = 14.0   ## Impact speed (m/s) below which a wall does no damage.
const WALL_DAMAGE_PER_MS: float = 0.5
const BARGE_SHOVE: float = 12.0
const FPS_WINDOW_SEC: float = 5.0
const HITCH_MS: float = 40.0
const PREWARM_FRAMES: int = 10
const CAR_COLORS: Array[Color] = [
	Color(0.15, 0.45, 0.95), Color(0.9, 0.2, 0.2), Color(0.95, 0.8, 0.15), Color(0.2, 0.75, 0.35),
	Color(0.7, 0.3, 0.9), Color(0.95, 0.55, 0.15), Color(0.15, 0.8, 0.85), Color(0.9, 0.9, 0.9),
]

var _rng := RandomNumberGenerator.new()
var _track: Track
var _cars: Array[Car] = []
var _specs: Array[CarSpec] = []
var _player_spec_index: int = 0
var _drivers: Array[AiDriver] = []
var _player: Car
var _powerups: Powerups
var _hud: Node
var _settings: Settings
var _settings_open: bool = false
var _camera: Camera3D
var _sun: DirectionalLight3D
var _environment: Environment
var _state: State = State.LOADING
var _countdown: float = COUNTDOWN_SECONDS
var _race_time: float = 0.0
var _player_brake: bool = false
var _auto_player: bool = false
var _frame_log: Array[Vector2] = []  # x = timestamp (sec), y = frame time (sec)
var _max_lateral_seen: float = 0.0
var _hitch_count: int = 0
var _staged_uses: Dictionary = {}  ## Self-test only: item kind -> times used in staged tests.
var _last_hitch_text: String = "-"
var _last_event: String = "-"
var _last_event_msec: int = 0


func _ready() -> void:
	_rng.seed = 5
	_track = Track.new()
	var testing: bool = "--selftest" in OS.get_cmdline_user_args()
	_settings = Settings.new("user://racer_settings_selftest.cfg" if testing else Settings.DEFAULT_PATH)
	_specs = CarCatalog.load_all()
	_build_environment()
	_build_track_and_scenery()
	_build_cars()
	Fx.setup(self)
	_powerups = Powerups.new()
	add_child(_powerups)
	_powerups.event.connect(_note_event)
	_powerups.setup(_track, _cars)
	_build_camera()
	_hud = Hud.new()
	_hud.settings = _settings
	add_child(_hud)
	_hud.settings_opened.connect(func(is_open: bool) -> void: _settings_open = is_open)
	_hud.brake_changed.connect(func(pressed: bool) -> void: _player_brake = pressed)
	_hud.use_pressed.connect(func() -> void: _powerups.use_item(_player))
	_hud.restart_pressed.connect(_restart)
	_hud.car_cycle_pressed.connect(_cycle_player_car)
	_hud.shadows_toggled.connect(func(on: bool) -> void: _sun.shadow_enabled = on)
	_hud.glow_toggled.connect(func(on: bool) -> void: _environment.glow_enabled = on)
	_hud.particles_toggled.connect(func(on: bool) -> void: Fx.enabled = on)
	_hud.render_scale_changed.connect(func(value: float) -> void: get_viewport().scaling_3d_scale = value)
	await _prewarm()
	_restart()
	if "--selftest" in OS.get_cmdline_user_args():
		_run_selftest()


func _process(delta: float) -> void:
	if not _settings_open:
		_sim_step(minf(delta, 1.0 / 30.0))
	_update_camera(delta)
	_update_hud(delta)


# --- setup ----------------------------------------------------------------------

func _build_environment() -> void:
	_environment = Look.make_environment()
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	_sun = Look.make_sun()
	add_child(_sun)


func _build_track_and_scenery() -> void:
	var road := MeshInstance3D.new()
	road.mesh = _track.build_mesh()
	var road_material := StandardMaterial3D.new()
	road_material.vertex_color_use_as_albedo = true
	road_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	road_material.roughness = 0.55
	road.material_override = road_material
	add_child(road)
	TrackScenery.build(self, _track, _rng)


func _build_cars() -> void:
	for slot in CAR_COUNT:
		var car := Car.new()
		car.is_player = slot == PLAYER_GRID_SLOT
		var spec: CarSpec = _specs[_player_spec_index if car.is_player else slot % _specs.size()]
		car.apply_spec(spec, CAR_COLORS[slot], "YOU" if car.is_player else "CPU %d" % slot)
		car.top_speed_factor = 1.0 if car.is_player else _rng.randf_range(0.92, 1.0)
		add_child(car)
		_cars.append(car)
		var driver := AiDriver.new()
		driver.lane_offset = _rng.randf_range(-0.5, 0.5) * Track.HALF_WIDTH
		driver.caution = _rng.randf_range(0.9, 1.15)
		_drivers.append(driver)
		if car.is_player:
			_player = car


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 68.0
	_camera.far = 600.0
	add_child(_camera)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _cycle_player_car() -> void:
	_player_spec_index = (_player_spec_index + 1) % _specs.size()
	_player.apply_spec(_specs[_player_spec_index], CAR_COLORS[PLAYER_GRID_SLOT], "YOU")
	_restart()


func _restart() -> void:
	for slot in CAR_COUNT:
		var row: int = slot / 2
		var index: int = _track.wrap_index(Track.SAMPLE_COUNT - 3 - row * 3)
		var lane: float = Track.HALF_WIDTH * (-0.3 if slot % 2 == 0 else 0.3)
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
	_hitch_count = 0
	_last_hitch_text = "-"


# --- loading ---------------------------------------------------------------------

## Plays every effect once in front of the camera, behind a cover, so the browser compiles
## its shaders now instead of as a hitch in the middle of the race.
func _prewarm() -> void:
	_hud.set_cover(true)
	_update_camera(1.0)
	var spot: Vector3 = _camera.global_position - _camera.global_transform.basis.z * 6.0
	Fx.prewarm(spot)
	_powerups.prewarm(spot)
	_player.prewarm_shield(true)
	for frame in PREWARM_FRAMES:
		await get_tree().process_frame
	_powerups.end_prewarm()
	_player.prewarm_shield(false)
	_hud.set_cover(false)


func _note_event(text: String) -> void:
	_last_event = text
	_last_event_msec = Time.get_ticks_msec()


# --- simulation (no rendering; the self-test calls this directly) ----------------

func _sim_step(dt: float) -> void:
	if _state == State.LOADING:
		return
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
	if car.items.is_empty():
		return
	car.item_use_timer -= dt
	if car.item_use_timer <= 0.0 and _powerups.ai_wants_to_use(car):
		_powerups.use_item(car)
		car.item_use_timer = _rng.randf_range(0.6, 1.6)


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
		if -into_wall > WALL_DAMAGE_SPEED:
			car.take_damage((-into_wall - WALL_DAMAGE_SPEED) * WALL_DAMAGE_PER_MS)
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
			if _barge_ram(_cars[i], _cars[j], normal) or _barge_ram(_cars[j], _cars[i], -normal):
				continue
			var closing: float = (_cars[j].velocity - _cars[i].velocity).dot(normal)
			if closing < 0.0:
				_cars[i].velocity += normal * closing * 0.5
				_cars[j].velocity -= normal * closing * 0.5


## A shielded car shoves its victim aside and damages it, and loses no speed itself.
## `away` points from the rammer toward the victim. Returns true if `rammer` had a shield.
func _barge_ram(rammer: Car, victim: Car, away: Vector3) -> bool:
	if not rammer.has_shield():
		return false
	victim.velocity += away * BARGE_SHOVE
	if victim.stun_time <= 0.0:
		_powerups.hit_car(victim, ItemDefs.Kind.BARGE, ItemDefs.value(ItemDefs.Kind.BARGE, "ram_damage"),
			ItemDefs.value(ItemDefs.Kind.BARGE, "ram_stun"))
	return true


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
	var distance: float = _settings.camera_distance
	var target: Vector3 = _player.position - forward * distance + Vector3(0.0, _settings.camera_height(), 0.0)
	_camera.position = _camera.position.lerp(target, 1.0 - exp(-7.0 * delta))
	_camera.look_at(_player.position + forward * distance * 1.1 + Vector3.UP, Vector3.UP)
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
	if _state == State.RACING and delta * 1000.0 > HITCH_MS:
		_hitch_count += 1
		_last_hitch_text = "%d ms, %.1f s after %s" % [
			roundi(delta * 1000.0), float(Time.get_ticks_msec() - _last_event_msec) / 1000.0, _last_event]
	var held: PackedStringArray = []
	for kind in _player.items:
		held.append(ItemDefs.item_name(kind))
	var item_text: String = " ".join(held)
	_hud.set_stats(_player.spec.summary() + "\nP %d/%d  LAP %d/%d  %d km/h  ITEM %s\nFPS %d  avg %d  worst %d ms" % [
		_race_place(_player), CAR_COUNT, clampi(_player.lap, 1, LAPS), LAPS,
		roundi(absf(_player.speed()) * 3.6), item_text if item_text != "" else "-",
		Engine.get_frames_per_second(), roundi(average_fps), roundi(worst * 1000.0)]
		+ "\nHITCHES >%d ms: %d  last: %s" % [roundi(HITCH_MS), _hitch_count, _last_hitch_text])
	match _state:
		State.LOADING:
			_hud.set_message("")
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
	# Car data and models: every spec loads, maps to sane handling, and its model has four wheels.
	if _specs.size() < 4:
		failures.append("expected at least 4 car specs, found %d" % _specs.size())
	for spec in _specs:
		if spec.game_top_speed() < 35.0 or spec.game_top_speed() > 55.0:
			failures.append("%s game top speed %.1f out of range" % [spec.id, spec.game_top_speed()])
		if spec.game_accel() < 15.0 or spec.game_accel() > 40.0:
			failures.append("%s game accel %.1f out of range" % [spec.id, spec.game_accel()])
		var probe := Car.new()
		probe.apply_spec(spec, Color.RED, "probe")
		if probe._wheels_front.size() != 2 or probe._wheels_rear.size() != 2:
			failures.append("%s model has %d front / %d rear wheels, expected 2 / 2" % [spec.id, probe._wheels_front.size(), probe._wheels_rear.size()])
		probe.free()
	for spec in _specs:
		if spec.id == "ferrari_f80" and absf(spec.game_accel() - 30.1) > 0.3:
			failures.append("F80 accel mapping changed: %.2f" % spec.game_accel())
	var before: String = _player.spec.id
	_cycle_player_car()
	if _player.spec.id == before:
		failures.append("car cycle button did not change the player's car")
	# Settings: values clamp, persist across instances, and drive the HUD and camera.
	var path: String = "user://racer_settings_unit_test.cfg"
	var stored := Settings.new(path)
	stored.reset()
	stored.set_value("steer_sensitivity", 9.0)
	stored.set_value("camera_distance", 6.0)
	var reloaded := Settings.new(path)
	if not is_equal_approx(reloaded.steer_sensitivity, 2.5):
		failures.append("sensitivity was not clamped to its limit: %.2f" % reloaded.steer_sensitivity)
	if not is_equal_approx(reloaded.camera_distance, 6.0):
		failures.append("camera distance did not persist: %.2f" % reloaded.camera_distance)
	stored.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_settings.reset()
	_hud._steer_index = -1
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = Vector2(200, 500)
	_hud._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(255, 500)
	_hud._input(drag)
	var expected: float = (0.5 - 0.08) / (1.0 - 0.08)
	if absf(_hud.steer_input - expected) > 0.01:
		failures.append("steer at default sensitivity: %.3f, expected %.3f" % [_hud.steer_input, expected])
	_settings.set_value("steer_sensitivity", 2.0)
	_hud._input(drag)
	if absf(_hud.steer_input - 1.0) > 0.01:
		failures.append("double sensitivity should give full lock for a half-range drag, got %.3f" % _hud.steer_input)
	drag.position = Vector2(203, 500)  # 3 px of a 55 px range: inside the 8% dead zone
	_hud._input(drag)
	if _hud.steer_input != 0.0:
		failures.append("a drag inside the dead zone should not steer, got %.3f" % _hud.steer_input)
	touch.pressed = false
	_hud._input(touch)
	_settings.set_value("mirror_layout", true)
	touch.pressed = true
	_hud._input(touch)
	if _hud._steer_index != -1:
		failures.append("a touch on the button side started steering after swapping sides")
	touch.position = Vector2(1000, 500)
	_hud._input(touch)
	if _hud._steer_index != 0:
		failures.append("a touch on the right half did not start steering after swapping sides")
	touch.pressed = false
	_hud._input(touch)
	_settings.set_value("button_scale", 1.4)
	_settings.set_value("button_opacity", 0.5)
	if not is_equal_approx(_hud._button_holder.scale.x, 1.4) or not is_equal_approx(_hud._button_holder.modulate.a, 0.5):
		failures.append("button size or opacity did not reach the HUD")
	if _hud._button_holder.anchor_left != 0.0:
		failures.append("buttons did not move to the left when sides were swapped")
	_settings.reset()
	var horizontal_distances: Array[float] = []
	for distance in [4.0, 8.0]:
		_settings.set_value("camera_distance", distance)
		_update_camera(10.0)
		horizontal_distances.append(Vector2(_camera.position.x - _player.position.x, _camera.position.z - _player.position.z).length())
	if absf(horizontal_distances[0] - 4.0) > 0.3 or absf(horizontal_distances[1] - 8.0) > 0.3:
		failures.append("camera distance setting not applied: %s" % [horizontal_distances])
	_settings.reset()
	# Player input path: steering and the USE button must change the player's state.
	_restart()
	_auto_player = false
	_state = State.RACING
	_player_brake = true
	_sim_step(step)
	if not _player.braking:
		failures.append("brake input did not reach the player car")
	_player.add_item(ItemDefs.Kind.NITRO)
	_hud.use_pressed.emit()
	if _player.boost_time <= 0.0:
		failures.append("USE button did not trigger the nitro item")
	_selftest_items(failures)
	if failures.is_empty():
		print("SELFTEST OK")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("SELFTEST FAIL: " + failure)
		get_tree().quit(1)


## Each item's effect, shields, wrecks, wall damage and the AI's item rules, on staged cars.
func _selftest_items(failures: Array[String]) -> void:
	_restart()
	_state = State.RACING
	var user: Car = _cars[0]
	var other: Car = _cars[1]
	for k in 4:
		user.add_item(ItemDefs.Kind.NITRO)
	if user.items.size() != ItemDefs.SLOT_COUNT:
		failures.append("item slots hold %d items, expected %d" % [user.items.size(), ItemDefs.SLOT_COUNT])
	user.items.clear()
	user.add_item(ItemDefs.Kind.NITRO)
	user.add_item(ItemDefs.Kind.BOLT)
	if user.pop_item() != ItemDefs.Kind.NITRO or user.first_item() != ItemDefs.Kind.BOLT:
		failures.append("items are not used first in, first out")
	user.items.clear()
	_use_staged(user, ItemDefs.Kind.NITRO)
	if user.boost_time <= 0.0:
		failures.append("nitro did not boost")
	user.health = 40.0
	_use_staged(user, ItemDefs.Kind.REPAIR)
	if absf(user.health - 90.0) > 0.01:
		failures.append("repair gave %.1f health, expected 90" % user.health)
	_use_staged(user, ItemDefs.Kind.BARGE)
	var shielded_health: float = user.health
	if not user.has_shield() or user.take_damage(30.0) or user.health != shielded_health:
		failures.append("barge shield did not block damage")
	user.barge_time = 0.0
	user.health = 5.0
	var wrecks: int = user.wreck_count
	user.take_damage(10.0)
	if user.wreck_count != wrecks + 1 or user.health != Car.WRECK_RESPAWN_HEALTH or user.stun_time <= 0.0:
		failures.append("a car at zero health did not wreck and recover")
	for kind in [ItemDefs.Kind.BOLT, ItemDefs.Kind.SHUNT, ItemDefs.Kind.MINE, ItemDefs.Kind.SHOCK]:
		_stage_pair(user, other, 20.0)
		if kind == ItemDefs.Kind.MINE:
			other.position = user.position - user.forward() * 3.5
		_use_staged(user, kind)
		for frame in 90:
			_powerups.update(1.0 / 60.0)
		if other.health >= Car.MAX_HEALTH:
			failures.append("%s did not damage the car it should hit" % ItemDefs.item_name(kind))
		if kind != ItemDefs.Kind.BOLT and other.stun_time <= 0.0 and other.health >= Car.MAX_HEALTH:
			failures.append("%s did not stun" % ItemDefs.item_name(kind))
		_stage_pair(user, other, 20.0)
		other.barge_time = 4.0
		if kind == ItemDefs.Kind.MINE:
			other.position = user.position - user.forward() * 3.5
		_use_staged(user, kind)
		for frame in 90:
			_powerups.update(1.0 / 60.0)
		if other.health < Car.MAX_HEALTH:
			failures.append("a shielded car was hurt by %s" % ItemDefs.item_name(kind))
	_stage_pair(user, other, 1.5)
	user.barge_time = 4.0
	_collide_cars()
	if other.health >= Car.MAX_HEALTH:
		failures.append("a shielded car ramming another did no damage")
	_stage_pair(user, other, 20.0)
	var right: Vector3 = _track.rights[user.track_index]
	user.position += right * (Track.HALF_WIDTH + 1.0)
	user.velocity = right * 30.0  # outward, into the wall on the right side
	_keep_on_track(user)
	if user.health >= Car.MAX_HEALTH:
		failures.append("a hard wall hit did no damage")
	_stage_pair(user, other, 20.0)
	user.velocity = right * 5.0
	user.position += right * (Track.HALF_WIDTH + 1.0)
	_keep_on_track(user)
	if user.health < Car.MAX_HEALTH:
		failures.append("a gentle wall scrape should not damage")
	# AI item rules
	_stage_pair(user, other, 20.0)
	user.health = 40.0
	user.add_item(ItemDefs.Kind.REPAIR)
	if not _powerups.ai_wants_to_use(user):
		failures.append("AI should repair at low health")
	user.health = 100.0
	if _powerups.ai_wants_to_use(user):
		failures.append("AI should not repair at full health")
	user.items.clear()
	user.add_item(ItemDefs.Kind.SHOCK)
	if not _powerups.ai_wants_to_use(user):
		failures.append("AI should shock with a car 20 m away")
	other.position += user.forward() * 80.0
	if _powerups.ai_wants_to_use(user):
		failures.append("AI should not shock with nobody near")
	for kind in ItemDefs.ALL_KINDS:
		if int(_staged_uses.get(kind, 0)) == 0:
			failures.append("%s was never used in the item tests" % ItemDefs.item_name(kind))
	_restart()


## Puts `user` on the track with `other` `gap` metres directly ahead, both with fresh state.
func _stage_pair(user: Car, other: Car, gap: float) -> void:
	_restart()
	_state = State.RACING
	var index: int = 100
	var heading: float = _track.heading_at(index)
	user.place(_track.points[index], heading)
	user.track_index = index
	other.place(_track.points[index] + user.forward() * gap, heading)
	other.track_index = _track.nearest_index(other.position, index)


func _use_staged(car: Car, kind: int) -> void:
	car.items.clear()
	car.add_item(kind)
	_staged_uses[kind] = int(_staged_uses.get(kind, 0)) + 1
	_powerups.use_item(car)


func _all_finished() -> bool:
	for car in _cars:
		if not car.finished:
			return false
	return true
