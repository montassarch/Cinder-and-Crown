extends RefCounted
## Closed-loop race track. A centre line is sampled into points with tangent and right
## vectors, and a single vertex-coloured mesh (road, start line, barriers) is built from it.
## The track is flat for now.

const SAMPLE_COUNT: int = 400
const HALF_WIDTH: float = 11.0
const BARRIER_HEIGHT: float = 1.0

var points: Array[Vector3] = []
var tangents: Array[Vector3] = []
var rights: Array[Vector3] = []
var turn: Array[float] = []  ## Angle (rad) between the tangent at sample i and at i + 1.
var length: float = 0.0
var spacing: float = 0.0


func _init() -> void:
	for i in SAMPLE_COUNT:
		var t: float = TAU * float(i) / float(SAMPLE_COUNT)
		var r: float = 130.0 + 28.0 * sin(3.0 * t) + 14.0 * cos(5.0 * t + 1.0)
		points.append(Vector3(cos(t) * r * 1.3, 0.0, sin(t) * r))
	for i in SAMPLE_COUNT:
		var next: Vector3 = points[wrap_index(i + 1)]
		var tangent: Vector3 = (next - points[wrap_index(i - 1)]).normalized()
		tangents.append(tangent)
		rights.append(tangent.cross(Vector3.UP).normalized())
		length += points[i].distance_to(next)
	spacing = length / float(SAMPLE_COUNT)
	for i in SAMPLE_COUNT:
		turn.append(tangents[i].angle_to(tangents[wrap_index(i + 1)]))


func wrap_index(index: int) -> int:
	return posmod(index, SAMPLE_COUNT)


func heading_at(index: int) -> float:
	var tangent: Vector3 = tangents[wrap_index(index)]
	return atan2(tangent.x, tangent.z)


## Nearest centre-line sample. With a hint, only a window around it is searched.
func nearest_index(pos: Vector3, hint: int = -1) -> int:
	var best: int = 0
	var best_distance: float = INF
	var from: int = 0
	var count: int = SAMPLE_COUNT
	if hint >= 0:
		from = hint - 15
		count = 31
	for k in count:
		var i: int = wrap_index(from + k)
		var d: float = pos.distance_squared_to(points[i])
		if d < best_distance:
			best_distance = d
			best = i
	return best


func lateral_offset(pos: Vector3, index: int) -> float:
	return (pos - points[index]).dot(rights[index])


## Distance from a point to the centre line (used to keep scenery off the road).
func distance_to_track(pos: Vector3) -> float:
	return pos.distance_to(points[nearest_index(pos)])


func min_turn_radius() -> float:
	var sharpest: float = 0.0
	for angle in turn:
		sharpest = maxf(sharpest, angle)
	return spacing / maxf(sharpest, 0.0001)


func build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lift := Vector3.UP * 0.02
	for i in SAMPLE_COUNT:
		var j: int = wrap_index(i + 1)
		var shade: float = 0.30 if (i % 12) < 6 else 0.34
		var road_color := Color(shade, shade, shade + 0.02)
		if i < 2:
			road_color = Color(0.9, 0.9, 0.9)  # start line
		_quad(st,
			points[i] - rights[i] * HALF_WIDTH + lift, points[i] + rights[i] * HALF_WIDTH + lift,
			points[j] + rights[j] * HALF_WIDTH + lift, points[j] - rights[j] * HALF_WIDTH + lift,
			Vector3.UP, road_color)
		var barrier_color := Color(0.85, 0.15, 0.15) if (i % 16) < 8 else Color(0.92, 0.92, 0.92)
		for side in [-1.0, 1.0]:
			var offset: float = float(side) * (HALF_WIDTH + 0.3)
			var base_a: Vector3 = points[i] + rights[i] * offset
			var base_b: Vector3 = points[j] + rights[j] * offset
			_quad(st, base_a, base_a + Vector3.UP * BARRIER_HEIGHT,
				base_b + Vector3.UP * BARRIER_HEIGHT, base_b, -float(side) * rights[i], barrier_color)
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	for vertex in [a, b, c, a, c, d]:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(vertex)
