extends Node3D
## Arcade car: a simple velocity model with drift, boost and stun, driving a 3D model.
## Heading 0 faces +Z; positive steer turns right. Handling numbers come from a CarSpec.

const Fx := preload("res://src/fx/fx.gd")
const CarSpec := preload("res://src/cars/car_spec.gd")

enum Item { NONE, BOOST, SHOT, MINE, SHOCK }

const BRAKE_DECEL: float = 30.0
const STEER_RATE: float = 2.1
const BOOST_SPEED_MULT: float = 1.35
const WHEEL_RADIUS: float = 0.35
const MAX_WHEEL_STEER: float = 0.45

var heading: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var top_speed_factor: float = 1.0
var steer: float = 0.0
var throttle: float = 1.0
var braking: bool = false
var boost_time: float = 0.0
var stun_time: float = 0.0
var item: int = Item.NONE
var item_use_timer: float = 0.0
var is_player: bool = false
var track_index: int = 0
var lap: int = 0
var finished: bool = false
var finish_time: float = 0.0
var display_name: String = ""
var spec: CarSpec

# Handling, set from the spec.
var max_speed: float = 46.0
var accel: float = 24.0
var grip: float = 9.0
var drift_grip: float = 2.4

var _model_holder: Node3D
var _wheels_front: Array[Node3D] = []
var _wheels_rear: Array[Node3D] = []
var _wheel_roll: float = 0.0
var _trail: GPUParticles3D


func _init() -> void:
	_model_holder = Node3D.new()
	add_child(_model_holder)
	_trail = Fx.make_trail(Color(1.0, 0.5, 0.1), 60, 0.4)
	add_child(_trail)
	_trail.position = Vector3(0.0, 0.5, -2.5)


## Swaps in a car model and its handling. Safe to call again to change the car.
func apply_spec(new_spec: CarSpec, paint: Color, car_name: String) -> void:
	spec = new_spec
	display_name = car_name
	max_speed = spec.game_top_speed()
	accel = spec.game_accel()
	grip = spec.game_grip()
	drift_grip = spec.game_drift_grip()
	for child in _model_holder.get_children():
		child.queue_free()
	_wheels_front.clear()
	_wheels_rear.clear()
	var packed: PackedScene = load(spec.model_path) as PackedScene
	var model: Node3D = packed.instantiate() as Node3D
	_model_holder.add_child(model)
	_find_parts(model, paint)


func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))


func right_vector() -> Vector3:
	return Vector3(-cos(heading), 0.0, sin(heading))


func speed() -> float:
	return velocity.dot(forward())


func apply_stun(seconds: float) -> void:
	stun_time = maxf(stun_time, seconds)
	boost_time = 0.0
	velocity *= 0.5


func apply_boost(seconds: float) -> void:
	boost_time = maxf(boost_time, seconds)


func place(pos: Vector3, new_heading: float) -> void:
	position = pos
	heading = new_heading
	velocity = Vector3.ZERO
	boost_time = 0.0
	stun_time = 0.0
	item = Item.NONE
	finished = false
	lap = 0
	rotation.y = heading


func step(dt: float) -> void:
	boost_time = maxf(0.0, boost_time - dt)
	var stunned: bool = stun_time > 0.0
	stun_time = maxf(0.0, stun_time - dt)
	var forward_speed: float = speed()
	if stunned:
		heading -= 9.0 * dt  # spin out
	else:
		var low_speed_factor: float = clampf(absf(forward_speed) / 12.0, 0.0, 1.0)
		var high_speed_damping: float = 1.0 - 0.35 * clampf(forward_speed / max_speed, 0.0, 1.0)
		var drift_assist: float = 1.35 if braking else 1.0
		heading -= steer * STEER_RATE * low_speed_factor * high_speed_damping * drift_assist * dt
	var fwd: Vector3 = forward()
	var right: Vector3 = right_vector()
	forward_speed = velocity.dot(fwd)
	var lateral: float = velocity.dot(right)
	var top: float = max_speed * top_speed_factor * (BOOST_SPEED_MULT if boost_time > 0.0 else 1.0)
	var drifting: bool = braking and forward_speed > 15.0 and not stunned
	if stunned:
		forward_speed = move_toward(forward_speed, 0.0, 30.0 * dt)
	elif braking and not drifting:
		forward_speed = move_toward(forward_speed, 0.0, BRAKE_DECEL * dt)
	else:
		var push: float = accel * (2.2 if boost_time > 0.0 else 1.0)
		forward_speed += push * throttle * maxf(1.0 - forward_speed / top, 0.0) * dt
		if forward_speed > top:
			forward_speed = move_toward(forward_speed, top, 40.0 * dt)
	lateral *= exp(-(drift_grip if drifting else grip) * dt)
	velocity = fwd * forward_speed + right * lateral
	position += velocity * dt
	position.y = 0.0
	rotation.y = heading
	var roll: float = clampf(lateral * 0.02 + steer * 0.05, -0.25, 0.25)
	_model_holder.rotation.z = lerpf(_model_holder.rotation.z, roll, 1.0 - exp(-10.0 * dt))
	_spin_wheels(forward_speed, dt)
	_trail.emitting = Fx.enabled and boost_time > 0.0


func _spin_wheels(forward_speed: float, dt: float) -> void:
	_wheel_roll += forward_speed / WHEEL_RADIUS * dt
	var spin := Basis(Vector3.RIGHT, _wheel_roll)
	var turned := Basis(Vector3.UP, -steer * MAX_WHEEL_STEER) * spin
	for wheel in _wheels_front:
		wheel.basis = turned
	for wheel in _wheels_rear:
		wheel.basis = spin


func _find_parts(node: Node, paint: Color) -> void:
	if node.name.begins_with("Wheel_F"):
		_wheels_front.append(node as Node3D)
	elif node.name.begins_with("Wheel_R"):
		_wheels_rear.append(node as Node3D)
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material: Material = mesh_instance.mesh.surface_get_material(surface)
			if material is StandardMaterial3D and material.resource_name == "Paint":
				var painted: StandardMaterial3D = (material as StandardMaterial3D).duplicate()
				painted.albedo_color = paint
				mesh_instance.set_surface_override_material(surface, painted)
	for child in node.get_children():
		_find_parts(child, paint)
