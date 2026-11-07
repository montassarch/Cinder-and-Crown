extends RefCounted
## Pooled particle effects. Every emitter is created once at startup and reused, so nothing is
## allocated or shader-compiled in the middle of a race (a first-use compile is a visible hitch
## in browsers). Call setup() once, then prewarm() behind a loading cover.

enum Kind { SPARK_ORANGE, SPARK_BLUE, SPARK_WHITE, RING_BLUE, SPARK_GREEN, SPARK_MINT, SPARK_PINK, SPARK_YELLOW }

const DEFINITIONS: Dictionary = {
	Kind.SPARK_ORANGE: {"color": Color(1.0, 0.5, 0.15), "amount": 120, "lifetime": 0.7, "speed": 8.0, "ring": false, "pool": 6},
	Kind.SPARK_BLUE: {"color": Color(0.55, 0.75, 1.0), "amount": 60, "lifetime": 0.5, "speed": 6.0, "ring": false, "pool": 6},
	Kind.SPARK_WHITE: {"color": Color(1.0, 1.0, 0.9), "amount": 30, "lifetime": 0.4, "speed": 5.0, "ring": false, "pool": 4},
	Kind.RING_BLUE: {"color": Color(0.5, 0.7, 1.0), "amount": 300, "lifetime": 0.7, "speed": 30.0, "ring": true, "pool": 2},
	Kind.SPARK_GREEN: {"color": Color(0.35, 1.0, 0.35), "amount": 70, "lifetime": 0.7, "speed": 5.0, "ring": false, "pool": 3},
	Kind.SPARK_MINT: {"color": Color(0.3, 1.0, 0.85), "amount": 60, "lifetime": 0.5, "speed": 6.0, "ring": false, "pool": 4},
	Kind.SPARK_PINK: {"color": Color(0.95, 0.15, 0.55), "amount": 120, "lifetime": 0.7, "speed": 8.0, "ring": false, "pool": 3},
	Kind.SPARK_YELLOW: {"color": Color(1.0, 0.95, 0.3), "amount": 70, "lifetime": 0.45, "speed": 7.0, "ring": false, "pool": 4},
}

static var enabled: bool = true

static var _pools: Dictionary = {}
static var _next: Dictionary = {}


## Creates every pooled emitter under `parent`. Call once.
static func setup(parent: Node3D) -> void:
	_pools.clear()
	_next.clear()
	for kind in DEFINITIONS:
		var definition: Dictionary = DEFINITIONS[kind]
		var pool: Array[GPUParticles3D] = []
		for i in int(definition["pool"]):
			var emitter := _make_emitter(definition, true)
			parent.add_child(emitter)
			pool.append(emitter)
		_pools[kind] = pool
		_next[kind] = 0


## Plays one pooled effect at a world position.
static func emit(kind: Kind, pos: Vector3) -> void:
	if not enabled:
		return
	var pool: Array = _pools[kind]
	var index: int = _next[kind]
	_next[kind] = (index + 1) % pool.size()
	var emitter: GPUParticles3D = pool[index]
	emitter.position = pos
	emitter.restart()


## Plays every effect once so the browser compiles its shaders before the race starts.
static func prewarm(pos: Vector3) -> void:
	var was_enabled: bool = enabled
	enabled = true
	for kind in DEFINITIONS:
		emit(kind, pos)
	enabled = was_enabled


## A continuous emitter that leaves a trail in world space; the caller toggles `emitting`.
static func make_trail(color: Color, amount: int, lifetime: float) -> GPUParticles3D:
	var particles := _make_emitter({"color": color, "amount": amount, "lifetime": lifetime, "speed": 1.5, "ring": false}, false)
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 35.0
	material.initial_velocity_min = 0.3
	material.initial_velocity_max = 1.5
	material.gravity = Vector3.ZERO
	particles.process_material = material
	particles.local_coords = false
	return particles


static func _make_emitter(definition: Dictionary, one_shot: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = int(definition["amount"])
	particles.lifetime = float(definition["lifetime"])
	particles.one_shot = one_shot
	particles.explosiveness = 0.9 if one_shot else 0.0
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-40, -6, -40), Vector3(80, 24, 80))
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = definition["color"]
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = material
	particles.draw_pass_1 = mesh
	if one_shot:
		particles.process_material = _burst_material(definition)
	return particles


static func _burst_material(definition: Dictionary) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	var speed: float = definition["speed"]
	if definition["ring"]:
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		material.emission_ring_axis = Vector3.UP
		material.emission_ring_height = 0.3
		material.emission_ring_radius = 1.0
		material.emission_ring_inner_radius = 0.8
		material.initial_velocity_min = 0.0
		material.initial_velocity_max = 0.0
		material.radial_velocity_min = speed * 0.9
		material.radial_velocity_max = speed
		material.gravity = Vector3.ZERO
	else:
		material.direction = Vector3.UP
		material.spread = 180.0
		material.initial_velocity_min = speed * 0.4
		material.initial_velocity_max = speed
		material.gravity = Vector3(0.0, -8.0, 0.0)
	return material
