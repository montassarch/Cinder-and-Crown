extends RefCounted
## Particle helpers shared by cars and power-ups. GPU particles, additive blend.

static var enabled: bool = true


static func burst(parent: Node3D, pos: Vector3, color: Color, amount: int, lifetime: float, speed: float) -> void:
	if not enabled:
		return
	var particles := _make(color, amount, lifetime, true, 0.12)
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = speed * 0.4
	material.initial_velocity_max = speed
	material.gravity = Vector3(0.0, -8.0, 0.0)
	particles.process_material = material
	_spawn(parent, particles, pos, lifetime)


static func ring(parent: Node3D, pos: Vector3, color: Color, radius_speed: float) -> void:
	if not enabled:
		return
	var particles := _make(color, 300, 0.7, true, 0.12)
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_axis = Vector3.UP
	material.emission_ring_height = 0.3
	material.emission_ring_radius = 1.0
	material.emission_ring_inner_radius = 0.8
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 0.0
	material.radial_velocity_min = radius_speed * 0.9
	material.radial_velocity_max = radius_speed
	material.gravity = Vector3.ZERO
	particles.process_material = material
	_spawn(parent, particles, pos, 0.7)


## A continuous emitter that leaves a trail in world space; the caller toggles `emitting`.
static func make_trail(color: Color, amount: int, lifetime: float) -> GPUParticles3D:
	var particles := _make(color, amount, lifetime, false, 0.16)
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 35.0
	material.initial_velocity_min = 0.3
	material.initial_velocity_max = 1.5
	material.gravity = Vector3.ZERO
	particles.process_material = material
	particles.local_coords = false
	return particles


static func _make(color: Color, amount: int, lifetime: float, one_shot: bool, size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.explosiveness = 0.9 if one_shot else 0.0
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-40, -6, -40), Vector3(80, 24, 80))
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = material
	particles.draw_pass_1 = mesh
	return particles


static func _spawn(parent: Node3D, particles: GPUParticles3D, pos: Vector3, lifetime: float) -> void:
	parent.add_child(particles)
	particles.position = pos
	particles.emitting = true
	parent.get_tree().create_timer(lifetime + 0.6).timeout.connect(particles.queue_free)
