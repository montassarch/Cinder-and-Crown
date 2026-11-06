extends Node3D
## Item pads, the four items (boost, homing shot, mine, shock) and their projectiles and mines.

const Car := preload("res://car.gd")
const Track := preload("res://track.gd")
const Fx := preload("res://fx.gd")

const PAD_RADIUS: float = 2.6
const PAD_RESPAWN_SECONDS: float = 6.0
const PAD_INDICES: Array[int] = [30, 95, 160, 225, 290, 355]
const PAD_LANES: Array[float] = [-3.5, 0.0, 3.5]
const SHOT_SPEED: float = 75.0
const SHOT_STUN: float = 1.6
const MINE_STUN: float = 1.4
const SHOCK_STUN: float = 1.0
const SHOCK_RADIUS: float = 35.0
const ITEM_NAMES: Array[String] = ["", "BOOST", "SHOT", "MINE", "SHOCK"]

var collected_count: int = 0
var used_count: int = 0
var hit_count: int = 0

var _cars: Array[Car] = []
var _track: Track
var _pads: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _mines: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(track: Track, cars: Array[Car]) -> void:
	_track = track
	_cars = cars
	_rng.seed = 11
	for index in PAD_INDICES:
		for lane in PAD_LANES:
			_add_pad(track.points[index] + track.rights[index] * lane)


func reset() -> void:
	for shot in _shots:
		(shot["node"] as Node3D).queue_free()
	for mine in _mines:
		(mine["node"] as Node3D).queue_free()
	_shots.clear()
	_mines.clear()
	for pad in _pads:
		pad["active"] = true
		(pad["node"] as Node3D).visible = true
	collected_count = 0
	used_count = 0
	hit_count = 0


func item_name(item: int) -> String:
	return ITEM_NAMES[item]


func update(dt: float) -> void:
	_update_pads(dt)
	_update_shots(dt)
	_update_mines(dt)


func use_item(car: Car) -> void:
	var item: int = car.item
	if item == Car.Item.NONE:
		return
	car.item = Car.Item.NONE
	used_count += 1
	match item:
		Car.Item.BOOST:
			car.apply_boost(2.0)
			Fx.burst(self, car.position + Vector3.UP * 0.5 - car.forward() * 2.0, Color(1.0, 0.6, 0.2), 60, 0.5, 6.0)
		Car.Item.SHOT:
			_fire_shot(car)
		Car.Item.MINE:
			_drop_mine(car)
		Car.Item.SHOCK:
			_shock(car)


# --- pads -----------------------------------------------------------------------

func _add_pad(pos: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.15
	mesh.radial_segments = 12
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.9, 1.0, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	node.mesh = mesh
	add_child(node)
	node.position = pos + Vector3.UP * 0.4
	_pads.append({"node": node, "pos": pos, "active": true, "timer": 0.0})


func _update_pads(dt: float) -> void:
	for pad in _pads:
		var node: Node3D = pad["node"]
		if not pad["active"]:
			pad["timer"] = (pad["timer"] as float) - dt
			if pad["timer"] <= 0.0:
				pad["active"] = true
				node.visible = true
			continue
		node.rotation.y += dt * 2.0
		var pos: Vector3 = pad["pos"]
		for car in _cars:
			if car.item != Car.Item.NONE:
				continue
			if car.position.distance_to(pos) < PAD_RADIUS:
				car.item = _rng.randi_range(1, 4)
				car.item_use_timer = _rng.randf_range(1.0, 4.0)
				collected_count += 1
				pad["active"] = false
				pad["timer"] = PAD_RESPAWN_SECONDS
				node.visible = false
				break


# --- items ----------------------------------------------------------------------

func _fire_shot(owner_car: Car) -> void:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.35, 0.2)
	sphere.material = material
	mesh.mesh = sphere
	node.add_child(mesh)
	var trail: GPUParticles3D = Fx.make_trail(Color(1.0, 0.4, 0.15), 80, 0.5)
	trail.emitting = Fx.enabled
	node.add_child(trail)
	add_child(node)
	node.position = owner_car.position + Vector3.UP * 0.8 + owner_car.forward() * 3.0
	_shots.append({"node": node, "dir": owner_car.forward(), "life": 3.0,
		"owner": owner_car, "target": _target_ahead(owner_car)})


func _target_ahead(owner_car: Car) -> Car:
	var best: Car = null
	var best_gap: float = INF
	var own: float = _progress(owner_car)
	for car in _cars:
		var gap: float = _progress(car) - own
		if car != owner_car and gap > 0.0 and gap < best_gap and gap < 80.0 / _track.spacing:
			best_gap = gap
			best = car
	return best


func _progress(car: Car) -> float:
	return float(car.lap * Track.SAMPLE_COUNT + car.track_index)


func _update_shots(dt: float) -> void:
	for shot in _shots.duplicate():
		var node: Node3D = shot["node"]
		var target: Car = shot["target"]
		var direction: Vector3 = shot["dir"]
		if target != null:
			var wanted: Vector3 = (target.position + Vector3.UP * 0.8 - node.position).normalized()
			direction = direction.lerp(wanted, 1.0 - exp(-6.0 * dt)).normalized()
			shot["dir"] = direction
		node.position += direction * SHOT_SPEED * dt
		shot["life"] = (shot["life"] as float) - dt
		var victim: Car = null
		for car in _cars:
			if car != shot["owner"] and car.position.distance_to(node.position - Vector3.UP * 0.8) < 2.4:
				victim = car
				break
		if victim != null:
			victim.apply_stun(SHOT_STUN)
			hit_count += 1
			Fx.burst(self, node.position, Color(1.0, 0.5, 0.2), 120, 0.7, 8.0)
		if victim != null or shot["life"] <= 0.0:
			node.queue_free()
			_shots.erase(shot)


func _drop_mine(owner_car: Car) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 0.7
	mesh.height = 0.25
	mesh.radial_segments = 10
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.1, 0.1)
	mesh.material = material
	node.mesh = mesh
	add_child(node)
	node.position = owner_car.position - owner_car.forward() * 3.5 + Vector3.UP * 0.2
	_mines.append({"node": node, "owner": owner_car, "arm": 0.8, "life": 25.0})


func _update_mines(dt: float) -> void:
	for mine in _mines.duplicate():
		var node: Node3D = mine["node"]
		mine["arm"] = (mine["arm"] as float) - dt
		mine["life"] = (mine["life"] as float) - dt
		var victim: Car = null
		for car in _cars:
			if car == mine["owner"] and mine["arm"] > 0.0:
				continue
			if car.position.distance_to(node.position) < 2.2:
				victim = car
				break
		if victim != null:
			victim.apply_stun(MINE_STUN)
			hit_count += 1
			Fx.burst(self, node.position + Vector3.UP * 0.5, Color(1.0, 0.45, 0.15), 140, 0.8, 9.0)
		if victim != null or mine["life"] <= 0.0:
			node.queue_free()
			_mines.erase(mine)


func _shock(owner_car: Car) -> void:
	Fx.ring(self, owner_car.position + Vector3.UP * 0.4, Color(0.5, 0.7, 1.0), 30.0)
	for car in _cars:
		if car != owner_car and car.position.distance_to(owner_car.position) < SHOCK_RADIUS:
			car.apply_stun(SHOCK_STUN)
			hit_count += 1
			Fx.burst(self, car.position + Vector3.UP, Color(0.6, 0.8, 1.0), 60, 0.5, 6.0)
