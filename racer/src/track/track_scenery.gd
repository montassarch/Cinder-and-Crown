extends RefCounted
## Everything around the road: markings, glowing barrier strips, street lamps with light pools,
## a skyline of lit buildings and the start-finish gantry. All of it is static geometry built
## once at startup from a Track, using a handful of draw calls.

const Track := preload("res://src/track/track.gd")
const Look := preload("res://src/fx/look.gd")

const LAMP_EVERY: int = 24          ## Track samples between lamps.
const LAMP_HEIGHT: float = 7.0
const NEON_LEFT: Color = Color(0.25, 0.65, 1.0)
const NEON_RIGHT: Color = Color(1.0, 0.45, 0.12)


static func build(parent: Node3D, track: Track, rng: RandomNumberGenerator) -> void:
	_add_ground(parent)
	_add_markings_and_neon(parent, track)
	_add_lamps(parent, track)
	_add_skyline(parent, track, rng)
	_add_gantry(parent, track)


# --- ground ---------------------------------------------------------------------

static func _add_ground(parent: Node3D) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400.0, 1400.0)
	plane.material = _flat(Color(0.05, 0.06, 0.09), 0.9)
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.position.y = -0.03
	parent.add_child(ground)


# --- road markings and neon strips ---------------------------------------------

static func _add_markings_and_neon(parent: Node3D, track: Track) -> void:
	var marks := SurfaceTool.new()
	marks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var neon := SurfaceTool.new()
	neon.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = Track.SAMPLE_COUNT
	for i in count:
		var j: int = track.wrap_index(i + 1)
		# centre dashes
		if (i % 6) < 3:
			_strip(marks, track, i, j, 0.0, 0.16, 0.035, Color(0.85, 0.85, 0.8))
		# solid edge lines just inside the kerb
		for side in [-1.0, 1.0]:
			_strip(marks, track, i, j, float(side) * (Track.HALF_WIDTH - 0.9), 0.14, 0.035, Color(0.9, 0.9, 0.85))
		# glowing strips along the top of both barriers
		_strip(neon, track, i, j, -(Track.HALF_WIDTH + 0.3), 0.30, Track.BARRIER_HEIGHT + 0.03, NEON_LEFT)
		_strip(neon, track, i, j, Track.HALF_WIDTH + 0.3, 0.30, Track.BARRIER_HEIGHT + 0.03, NEON_RIGHT)
	_add_mesh(parent, marks.commit(), _vertex_colour_material(false))
	_add_mesh(parent, neon.commit(), _vertex_colour_material(true))


## A flat strip centred `offset` metres to the right of the centre line between samples i and j.
static func _strip(st: SurfaceTool, track: Track, i: int, j: int, offset: float, width: float, height: float, color: Color) -> void:
	var half: float = width / 2.0
	var a: Vector3 = track.points[i] + track.rights[i] * (offset - half) + Vector3.UP * height
	var b: Vector3 = track.points[i] + track.rights[i] * (offset + half) + Vector3.UP * height
	var c: Vector3 = track.points[j] + track.rights[j] * (offset + half) + Vector3.UP * height
	var d: Vector3 = track.points[j] + track.rights[j] * (offset - half) + Vector3.UP * height
	for vertex in [a, b, c, a, c, d]:
		st.set_normal(Vector3.UP)
		st.set_color(color)
		st.add_vertex(vertex)


# --- street lamps ---------------------------------------------------------------

static func _add_lamps(parent: Node3D, track: Track) -> void:
	var posts := MultiMesh.new()
	var heads := MultiMesh.new()
	var pools := MultiMesh.new()
	var lamp_indices: Array[int] = []
	for i in range(8, Track.SAMPLE_COUNT, LAMP_EVERY):
		lamp_indices.append(i)
	for multimesh in [posts, heads, pools]:
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.instance_count = lamp_indices.size()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.28, LAMP_HEIGHT, 0.28)
	posts.mesh = post_mesh
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.7, 0.22, 1.5)
	heads.mesh = head_mesh
	var pool_mesh := QuadMesh.new()
	pool_mesh.size = Vector2(22.0, 22.0)
	pool_mesh.orientation = PlaneMesh.FACE_Y
	pools.mesh = pool_mesh
	for n in lamp_indices.size():
		var i: int = lamp_indices[n]
		var side: float = 1.0 if n % 2 == 0 else -1.0
		var base: Vector3 = track.points[i] + track.rights[i] * side * (Track.HALF_WIDTH + 1.4)
		var basis := Basis.looking_at(track.rights[i] * -side, Vector3.UP)
		posts.set_instance_transform(n, Transform3D(Basis.IDENTITY, base + Vector3.UP * LAMP_HEIGHT / 2.0))
		heads.set_instance_transform(n, Transform3D(basis, base + Vector3.UP * LAMP_HEIGHT - track.rights[i] * side * 0.7))
		pools.set_instance_transform(n, Transform3D(Basis.IDENTITY, base - track.rights[i] * side * 6.0 + Vector3.UP * 0.05))
	_add_multimesh(parent, posts, _flat(Color(0.08, 0.08, 0.1), 0.6))
	var head_material := StandardMaterial3D.new()
	head_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head_material.albedo_color = Color(1.0, 0.85, 0.55)
	_add_multimesh(parent, heads, head_material)
	var pool_material := StandardMaterial3D.new()
	pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_material.albedo_texture = Look.glow_texture()
	pool_material.albedo_color = Color(1.0, 0.72, 0.38, 0.55)
	pool_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_multimesh(parent, pools, pool_material)


# --- skyline --------------------------------------------------------------------

static func _add_skyline(parent: Node3D, track: Track, rng: RandomNumberGenerator) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	for i in range(0, Track.SAMPLE_COUNT, 3):
		for side in [-1.0, 1.0]:
			var offset: float = Track.HALF_WIDTH + rng.randf_range(16.0, 70.0)
			var centre: Vector3 = track.points[i] + track.rights[i] * float(side) * offset
			var half_a: float = rng.randf_range(7.0, 15.0)
			var half_b: float = rng.randf_range(7.0, 15.0)
			if track.distance_to_track(centre) < Track.HALF_WIDTH + 12.0 + maxf(half_a, half_b):
				continue
			var height: float = rng.randf_range(14.0, 80.0)
			_add_building(st, centre, track.tangents[i], track.rights[i], half_a, half_b, height, rng)
			count += 1
	var material := StandardMaterial3D.new()
	material.albedo_texture = Look.window_texture()
	material.emission_enabled = true
	material.emission_texture = material.albedo_texture
	material.emission_energy_multiplier = 1.6
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh(parent, st.commit(), material)


static func _add_building(st: SurfaceTool, centre: Vector3, along: Vector3, across: Vector3, half_a: float, half_b: float, height: float, rng: RandomNumberGenerator) -> void:
	var u_scale: float = 1.0 / (Look.WINDOW_COLUMNS * 3.0)   # one texture unit = 8 windows of 3 m
	var v_scale: float = 1.0 / (Look.WINDOW_ROWS * 3.2)
	var u0: float = rng.randf()
	var v0: float = rng.randf()
	var corners: Array[Vector3] = [
		centre - along * half_a - across * half_b,
		centre + along * half_a - across * half_b,
		centre + along * half_a + across * half_b,
		centre - along * half_a + across * half_b,
	]
	for k in 4:
		var p0: Vector3 = corners[k]
		var p1: Vector3 = corners[(k + 1) % 4]
		var outward: Vector3 = ((p0 + p1) / 2.0 - centre).normalized()
		var face_width: float = p0.distance_to(p1)
		var uv_left := Vector2(u0, v0 + height * v_scale)
		var uv_right := Vector2(u0 + face_width * u_scale, v0 + height * v_scale)
		var uv_bottom_left := Vector2(u0, v0)
		var uv_bottom_right := Vector2(u0 + face_width * u_scale, v0)
		_vertex(st, p0, outward, uv_bottom_left)
		_vertex(st, p1, outward, uv_bottom_right)
		_vertex(st, p1 + Vector3.UP * height, outward, uv_right)
		_vertex(st, p0, outward, uv_bottom_left)
		_vertex(st, p1 + Vector3.UP * height, outward, uv_right)
		_vertex(st, p0 + Vector3.UP * height, outward, uv_left)
	# flat dark roof, sampled from a dark texel
	var roof_uv := Vector2(0.001, 0.001)
	for index in [0, 1, 2, 0, 2, 3]:
		_vertex(st, corners[index] + Vector3.UP * height, Vector3.UP, roof_uv)


static func _vertex(st: SurfaceTool, pos: Vector3, normal: Vector3, uv: Vector2) -> void:
	st.set_normal(normal)
	st.set_uv(uv)
	st.add_vertex(pos)


# --- start-finish gantry --------------------------------------------------------

static func _add_gantry(parent: Node3D, track: Track) -> void:
	var index: int = 1
	var base: Vector3 = track.points[index]
	var right: Vector3 = track.rights[index]
	var basis := Basis.looking_at(track.tangents[index], Vector3.UP)
	var span: float = Track.HALF_WIDTH + 1.6
	var dark: StandardMaterial3D = _flat(Color(0.06, 0.06, 0.08), 0.5)
	for side in [-1.0, 1.0]:
		_add_box(parent, Vector3(1.0, 9.0, 1.0), base + right * float(side) * span + Vector3.UP * 4.5, basis, dark)
	_add_box(parent, Vector3(span * 2.0 + 1.0, 1.6, 1.0), base + Vector3.UP * 9.0, basis, dark)
	var banner := StandardMaterial3D.new()
	banner.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	banner.albedo_color = Color(1.0, 0.95, 0.85)
	_add_box(parent, Vector3(span * 2.0 - 1.0, 0.5, 1.05), base + Vector3.UP * 9.0, basis, banner)
	for k in 6:
		var stripe := StandardMaterial3D.new()
		stripe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stripe.albedo_color = NEON_LEFT if k % 2 == 0 else NEON_RIGHT
		var x: float = (float(k) - 2.5) * (span * 2.0 / 7.0)
		_add_box(parent, Vector3(span * 2.0 / 8.0, 0.5, 1.1), base + right * x + Vector3.UP * 9.0, basis, stripe)


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, basis: Basis, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	instance.global_transform = Transform3D(basis, pos)


# --- shared helpers -------------------------------------------------------------

static func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


static func _vertex_colour_material(unshaded: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func _add_mesh(parent: Node3D, mesh: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


static func _add_multimesh(parent: Node3D, multimesh: MultiMesh, material: Material) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	parent.add_child(instance)
