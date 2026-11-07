extends Node3D
## Item pads and the seven items. Shots, mines and lightning arcs come from fixed pools created at
## startup, so using an item never allocates or compiles a shader in the middle of a race.

signal event(text: String)
signal car_hit(car: Node3D, kind: int, damage: float)

const Car := preload("res://src/cars/car.gd")
const Track := preload("res://src/track/track.gd")
const Fx := preload("res://src/fx/fx.gd")
const ItemDefs := preload("res://src/items/item_defs.gd")

const PAD_RADIUS: float = 3.0
const PAD_RESPAWN_SECONDS: float = 6.0
const PAD_INDICES: Array[int] = [30, 95, 160, 225, 290, 355]
const PAD_LANE_FRACTIONS: Array[float] = [-0.5, 0.0, 0.5]  ## Of the track half-width.
const SHOT_POOL_SIZE: int = 6
const MINE_POOL_SIZE: int = 16
const ARC_POOL_SIZE: int = 24
const ARC_SEGMENTS: int = 3
const ARC_SECONDS: float = 0.3
const HIDDEN_POSITION: Vector3 = Vector3(0.0, -50.0, 0.0)
const AI_SENSE_AHEAD: float = 80.0

var collected_count: int = 0
var used_count: int = 0
var hit_count: int = 0
var used_by_kind: Dictionary = {}

var _cars: Array[Car] = []
var _track: Track
var _pads: Array[Dictionary] = []
var _pad_materials: Dictionary = {}
var _shot_pools: Dictionary = {}
var _mine_pool: Array[Node3D] = []
var _arc_pool: Array[MeshInstance3D] = []
var _shots: Array[Dictionary] = []
var _mines: Array[Dictionary] = []
var _arcs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func setup(track: Track, cars: Array[Car]) -> void:
	_track = track
	_cars = cars
	_rng.seed = 11
	for kind in ItemDefs.ALL_KINDS:
		_pad_materials[kind] = _make_pad_material(ItemDefs.color(kind))
	for index in PAD_INDICES:
		for fraction in PAD_LANE_FRACTIONS:
			_add_pad(track.points[index] + track.rights[index] * fraction * Track.HALF_WIDTH)
	for kind in [ItemDefs.Kind.BOLT, ItemDefs.Kind.SHUNT]:
		var pool: Array[Node3D] = []
		for i in SHOT_POOL_SIZE:
			pool.append(_make_shot_node(kind))
		_shot_pools[kind] = pool
	for i in MINE_POOL_SIZE:
		_mine_pool.append(_make_mine_node())
	var arc_material := _unshaded_additive(Color(0.6, 0.8, 1.0, 1.0))
	for i in ARC_POOL_SIZE:
		_arc_pool.append(_make_arc_box(arc_material))
	for kind in ItemDefs.ALL_KINDS:
		used_by_kind[kind] = 0


func reset() -> void:
	for shot in _shots.duplicate():
		_release_shot(shot)
	for mine in _mines.duplicate():
		_release_mine(mine)
	for arc in _arcs.duplicate():
		_release_arc(arc)
	for pad in _pads:
		_set_pad_active(pad, true)
	collected_count = 0
	used_count = 0
	hit_count = 0
	for kind in ItemDefs.ALL_KINDS:
		used_by_kind[kind] = 0


## Shows one of each pooled object in front of the camera so shaders compile before the race.
func prewarm(pos: Vector3) -> void:
	for kind in _shot_pools:
		var node: Node3D = _shot_pools[kind][0]
		node.visible = true
		node.position = pos
		(node.get_node("Trail") as GPUParticles3D).emitting = true
	_mine_pool[0].visible = true
	_mine_pool[0].position = pos
	for k in ARC_SEGMENTS:
		_arc_pool[k].visible = true
		_arc_pool[k].position = pos + Vector3(0.0, 0.5 * k, 0.0)


func end_prewarm() -> void:
	for kind in _shot_pools:
		var node: Node3D = _shot_pools[kind][0]
		node.visible = false
		node.position = HIDDEN_POSITION
		(node.get_node("Trail") as GPUParticles3D).emitting = false
	_mine_pool[0].visible = false
	_mine_pool[0].position = HIDDEN_POSITION
	for k in ARC_SEGMENTS:
		_arc_pool[k].visible = false
		_arc_pool[k].position = HIDDEN_POSITION


func update(dt: float) -> void:
	_update_pads(dt)
	_update_shots(dt)
	_update_mines(dt)
	_update_arcs(dt)


func use_item(car: Car) -> void:
	var kind: int = car.pop_item()
	if kind == ItemDefs.Kind.NONE:
		return
	used_count += 1
	used_by_kind[kind] += 1
	event.emit("USE %s" % ItemDefs.item_name(kind))
	match kind:
		ItemDefs.Kind.NITRO:
			car.apply_boost(2.0)
			Fx.emit(Fx.Kind.SPARK_ORANGE, car.position + Vector3.UP * 0.5 - car.forward() * 2.0)
		ItemDefs.Kind.BOLT, ItemDefs.Kind.SHUNT:
			_fire_shot(car, kind)
		ItemDefs.Kind.MINE:
			_drop_mine(car)
		ItemDefs.Kind.SHOCK:
			_shock(car)
		ItemDefs.Kind.BARGE:
			car.barge_time = ItemDefs.value(kind, "seconds")
			Fx.emit(Fx.Kind.SPARK_MINT, car.position + Vector3.UP)
		ItemDefs.Kind.REPAIR:
			car.heal(ItemDefs.value(kind, "heal"))
			Fx.emit(Fx.Kind.SPARK_GREEN, car.position + Vector3.UP)


## Damages and stuns a car, unless its shield stops it. Returns true if it landed.
func hit_car(victim: Car, kind: int, damage: float, stun: float) -> bool:
	if victim.has_shield():
		Fx.emit(Fx.Kind.SPARK_MINT, victim.position + Vector3.UP)
		return false
	var landed: bool = victim.take_damage(damage)
	if landed:
		victim.apply_stun(stun)
		hit_count += 1
		car_hit.emit(victim, kind, damage)
	return landed


## True if an AI car should use its first item right now.
func ai_wants_to_use(car: Car) -> bool:
	var kind: int = car.first_item()
	match kind:
		ItemDefs.Kind.NONE:
			return false
		ItemDefs.Kind.REPAIR:
			return car.health < 70.0
		ItemDefs.Kind.NITRO:
			return car.boost_time <= 0.0 and _straight_ahead(car)
		ItemDefs.Kind.BARGE:
			return _any_car_within(car, 14.0)
		ItemDefs.Kind.SHOCK:
			return _any_car_within(car, 25.0)
		ItemDefs.Kind.MINE:
			return _any_car_behind_within(car, 28.0)
		ItemDefs.Kind.BOLT:
			return _car_in_front(car, 45.0, 0.92) != null
		ItemDefs.Kind.SHUNT:
			return _target_ahead(car) != null
	return false


# --- pads -----------------------------------------------------------------------

func _make_pad_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _add_pad(pos: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.15
	mesh.radial_segments = 12
	node.mesh = mesh
	add_child(node)
	node.position = pos + Vector3.UP * 0.4
	var pad: Dictionary = {"node": node, "pos": pos, "active": true, "timer": 0.0, "kind": ItemDefs.Kind.NITRO}
	_pads.append(pad)
	_set_pad_active(pad, true)


## (Re)activates a pad with a freshly rolled item, coloured to match so drivers can choose.
func _set_pad_active(pad: Dictionary, active: bool) -> void:
	pad["active"] = active
	var node: MeshInstance3D = pad["node"]
	node.visible = active
	if active:
		var kind: int = ItemDefs.ALL_KINDS[_rng.randi_range(0, ItemDefs.ALL_KINDS.size() - 1)]
		pad["kind"] = kind
		node.material_override = _pad_materials[kind]


func _update_pads(dt: float) -> void:
	for pad in _pads:
		if not pad["active"]:
			pad["timer"] = (pad["timer"] as float) - dt
			if pad["timer"] <= 0.0:
				_set_pad_active(pad, true)
			continue
		(pad["node"] as Node3D).rotation.y += dt * 2.0
		var pos: Vector3 = pad["pos"]
		for car in _cars:
			if not car.has_free_slot() or car.position.distance_to(pos) >= PAD_RADIUS:
				continue
			var kind: int = pad["kind"]
			car.add_item(kind)
			car.item_use_timer = _rng.randf_range(0.8, 3.0)
			collected_count += 1
			pad["timer"] = PAD_RESPAWN_SECONDS
			_set_pad_active(pad, false)
			Fx.emit(Fx.Kind.SPARK_WHITE, pos + Vector3.UP * 0.5)
			event.emit("PICKUP %s" % car.display_name)
			break


# --- shots (bolt and shunt) -----------------------------------------------------

func _make_shot_node(kind: int) -> Node3D:
	var color: Color = ItemDefs.color(kind)
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35 if kind == ItemDefs.Kind.BOLT else 0.5
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	sphere.material = material
	mesh.mesh = sphere
	node.add_child(mesh)
	var trail: GPUParticles3D = Fx.make_trail(color, 80, 0.5)
	trail.name = "Trail"
	node.add_child(trail)
	add_child(node)
	node.visible = false
	node.position = HIDDEN_POSITION
	return node


func _fire_shot(owner_car: Car, kind: int) -> void:
	var pool: Array = _shot_pools[kind]
	if pool.is_empty():
		return
	var node: Node3D = pool.pop_back()
	node.visible = true
	node.position = owner_car.position + Vector3.UP * 0.8 + owner_car.forward() * 3.0
	(node.get_node("Trail") as GPUParticles3D).emitting = Fx.enabled
	var target: Car = _target_ahead(owner_car) if kind == ItemDefs.Kind.SHUNT else null
	_shots.append({"node": node, "kind": kind, "dir": owner_car.forward(), "life": 3.0,
		"owner": owner_car, "target": target})


func _release_shot(shot: Dictionary) -> void:
	var node: Node3D = shot["node"]
	node.visible = false
	node.position = HIDDEN_POSITION
	(node.get_node("Trail") as GPUParticles3D).emitting = false
	_shots.erase(shot)
	(_shot_pools[shot["kind"]] as Array).append(node)


func _update_shots(dt: float) -> void:
	for shot in _shots.duplicate():
		var node: Node3D = shot["node"]
		var kind: int = shot["kind"]
		var target: Car = shot["target"]
		var direction: Vector3 = shot["dir"]
		if target != null:
			var wanted: Vector3 = (target.position + Vector3.UP * 0.8 - node.position).normalized()
			direction = direction.lerp(wanted, 1.0 - exp(-6.0 * dt)).normalized()
			shot["dir"] = direction
		node.position += direction * ItemDefs.value(kind, "speed") * dt
		shot["life"] = (shot["life"] as float) - dt
		var victim: Car = null
		for car in _cars:
			if car != shot["owner"] and car.position.distance_to(node.position - Vector3.UP * 0.8) < 2.4:
				victim = car
				break
		if victim != null:
			hit_car(victim, kind, ItemDefs.value(kind, "damage"), ItemDefs.value(kind, "stun"))
			Fx.emit(Fx.Kind.SPARK_YELLOW if kind == ItemDefs.Kind.BOLT else Fx.Kind.SPARK_ORANGE, node.position)
			event.emit("HIT %s" % ItemDefs.item_name(kind))
		if victim != null or shot["life"] <= 0.0:
			_release_shot(shot)


## The nearest car ahead of `owner_car` (by race progress) within the homing range.
func _target_ahead(owner_car: Car) -> Car:
	var best: Car = null
	var best_gap: float = INF
	var own: float = _progress(owner_car)
	for car in _cars:
		var gap: float = _progress(car) - own
		if car != owner_car and gap > 0.0 and gap < best_gap and gap < AI_SENSE_AHEAD / _track.spacing:
			best_gap = gap
			best = car
	return best


func _progress(car: Car) -> float:
	return float(car.lap * Track.SAMPLE_COUNT + car.track_index)


# --- mines ----------------------------------------------------------------------

func _make_mine_node() -> Node3D:
	var node := Node3D.new()
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.25
	disc.radial_segments = 10
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.05, 0.1)
	disc.material = material
	base.mesh = disc
	node.add_child(base)
	var light := MeshInstance3D.new()
	light.name = "Light"
	var bulb := SphereMesh.new()
	bulb.radius = 0.28
	bulb.height = 0.56
	bulb.radial_segments = 8
	bulb.rings = 4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = ItemDefs.color(ItemDefs.Kind.MINE)
	bulb.material = glow
	light.mesh = bulb
	light.position = Vector3(0.0, 0.3, 0.0)
	node.add_child(light)
	add_child(node)
	node.visible = false
	node.position = HIDDEN_POSITION
	return node


func _drop_mine(owner_car: Car) -> void:
	if _mine_pool.is_empty():
		return
	var node: Node3D = _mine_pool.pop_back()
	node.visible = true
	node.position = owner_car.position - owner_car.forward() * 3.5 + Vector3.UP * 0.2
	_mines.append({"node": node, "owner": owner_car, "arm": 0.8, "life": 25.0, "age": 0.0})


func _release_mine(mine: Dictionary) -> void:
	var node: Node3D = mine["node"]
	node.visible = false
	node.position = HIDDEN_POSITION
	_mines.erase(mine)
	_mine_pool.append(node)


func _update_mines(dt: float) -> void:
	for mine in _mines.duplicate():
		var node: Node3D = mine["node"]
		mine["arm"] = (mine["arm"] as float) - dt
		mine["life"] = (mine["life"] as float) - dt
		mine["age"] = (mine["age"] as float) + dt
		(node.get_node("Light") as Node3D).scale = Vector3.ONE * (1.0 + 0.45 * sin(float(mine["age"]) * 9.0))
		var victim: Car = null
		for car in _cars:
			if car == mine["owner"] and mine["arm"] > 0.0:
				continue
			if car.position.distance_to(node.position) < 2.2:
				victim = car
				break
		if victim != null:
			var kind: int = ItemDefs.Kind.MINE
			hit_car(victim, kind, ItemDefs.value(kind, "damage"), ItemDefs.value(kind, "stun"))
			Fx.emit(Fx.Kind.SPARK_PINK, node.position + Vector3.UP * 0.5)
			event.emit("HIT MINE")
		if victim != null or mine["life"] <= 0.0:
			_release_mine(mine)


# --- shock ----------------------------------------------------------------------

func _shock(owner_car: Car) -> void:
	var kind: int = ItemDefs.Kind.SHOCK
	Fx.emit(Fx.Kind.RING_BLUE, owner_car.position + Vector3.UP * 0.4)
	var radius: float = ItemDefs.value(kind, "radius")
	for car in _cars:
		if car == owner_car or car.position.distance_to(owner_car.position) >= radius:
			continue
		hit_car(car, kind, ItemDefs.value(kind, "damage"), ItemDefs.value(kind, "stun"))
		Fx.emit(Fx.Kind.SPARK_BLUE, car.position + Vector3.UP)
		_start_arc(owner_car.position + Vector3.UP * 0.8, car.position + Vector3.UP * 0.8)
	event.emit("HIT SHOCK")


func _make_arc_box(material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 1.0)
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	add_child(instance)
	instance.visible = false
	instance.position = HIDDEN_POSITION
	return instance


func _unshaded_additive(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material


## A jagged lightning bolt of ARC_SEGMENTS boxes from `from` to `to`, shown for ARC_SECONDS.
func _start_arc(from: Vector3, to: Vector3) -> void:
	if _arc_pool.size() < ARC_SEGMENTS or not Fx.enabled:
		return
	var points: Array[Vector3] = [from]
	for k in range(1, ARC_SEGMENTS):
		var along: Vector3 = from.lerp(to, float(k) / float(ARC_SEGMENTS))
		points.append(along + Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-0.6, 0.9), _rng.randf_range(-1.2, 1.2)))
	points.append(to)
	var boxes: Array[MeshInstance3D] = []
	for k in ARC_SEGMENTS:
		var box: MeshInstance3D = _arc_pool.pop_back()
		var a: Vector3 = points[k]
		var b: Vector3 = points[k + 1]
		var length: float = maxf(a.distance_to(b), 0.01)
		box.visible = true
		box.global_transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP).scaled(Vector3(1, 1, length)), (a + b) / 2.0)
		boxes.append(box)
	_arcs.append({"boxes": boxes, "life": ARC_SECONDS})


func _release_arc(arc: Dictionary) -> void:
	for box in arc["boxes"]:
		(box as MeshInstance3D).visible = false
		(box as MeshInstance3D).position = HIDDEN_POSITION
		_arc_pool.append(box)
	_arcs.erase(arc)


func _update_arcs(dt: float) -> void:
	for arc in _arcs.duplicate():
		arc["life"] = (arc["life"] as float) - dt
		if arc["life"] <= 0.0:
			_release_arc(arc)


# --- situation sensing for the AI -----------------------------------------------

func _any_car_within(car: Car, distance: float) -> bool:
	for other in _cars:
		if other != car and other.position.distance_to(car.position) < distance:
			return true
	return false


func _any_car_behind_within(car: Car, distance: float) -> bool:
	for other in _cars:
		var offset: Vector3 = other.position - car.position
		if other != car and offset.length() < distance and offset.dot(car.forward()) < 0.0:
			return true
	return false


## A car roughly in front of `car` within `distance`; `cone` is the minimum dot product with forward.
func _car_in_front(car: Car, distance: float, cone: float) -> Car:
	for other in _cars:
		var offset: Vector3 = other.position - car.position
		offset.y = 0.0
		if other != car and offset.length() < distance and offset.length() > 1.0 \
				and offset.normalized().dot(car.forward()) > cone:
			return other
	return null


func _straight_ahead(car: Car) -> bool:
	var sharpness: float = 0.0
	for k in 12:
		sharpness += _track.turn[_track.wrap_index(car.track_index + 2 + k * 2)]
	return sharpness < 0.25
