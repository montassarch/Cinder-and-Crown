extends Node3D
## Arcade car: a simple velocity model with drift, boost and stun, plus a low-poly body.
## Heading 0 faces +Z; positive steer turns right.

const Fx := preload("res://fx.gd")

enum Item { NONE, BOOST, SHOT, MINE, SHOCK }

const MAX_SPEED: float = 46.0
const ACCEL: float = 24.0
const BRAKE_DECEL: float = 30.0
const STEER_RATE: float = 2.1
const GRIP: float = 9.0
const DRIFT_GRIP: float = 2.4
const BOOST_SPEED_MULT: float = 1.35

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

var _model: Node3D
var _trail: GPUParticles3D


func setup(body_color: Color, car_name: String) -> void:
	display_name = car_name
	_model = Node3D.new()
	add_child(_model)
	_add_box(Vector3(1.8, 0.55, 4.0), Vector3(0.0, 0.5, 0.0), body_color)
	_add_box(Vector3(1.4, 0.5, 1.8), Vector3(0.0, 1.0, -0.2), body_color.darkened(0.35))
	_add_box(Vector3(1.5, 0.12, 0.5), Vector3(0.0, 1.05, -1.9), body_color.darkened(0.5))  # spoiler
	_add_box(Vector3(1.2, 0.18, 0.1), Vector3(0.0, 0.55, 2.0), Color(1.0, 0.95, 0.6))      # headlights
	_add_box(Vector3(1.2, 0.18, 0.1), Vector3(0.0, 0.55, -2.0), Color(1.0, 0.15, 0.15))    # tail lights
	for wheel in [Vector3(-0.95, 0.35, 1.3), Vector3(0.95, 0.35, 1.3), Vector3(-0.95, 0.35, -1.3), Vector3(0.95, 0.35, -1.3)]:
		_add_box(Vector3(0.3, 0.7, 0.7), wheel, Color(0.08, 0.08, 0.08))
	_trail = Fx.make_trail(Color(1.0, 0.5, 0.1), 60, 0.4)
	add_child(_trail)
	_trail.position = Vector3(0.0, 0.5, -2.2)


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
		var high_speed_damping: float = 1.0 - 0.35 * clampf(forward_speed / MAX_SPEED, 0.0, 1.0)
		var drift_assist: float = 1.35 if braking else 1.0
		heading -= steer * STEER_RATE * low_speed_factor * high_speed_damping * drift_assist * dt
	var fwd: Vector3 = forward()
	var right: Vector3 = right_vector()
	forward_speed = velocity.dot(fwd)
	var lateral: float = velocity.dot(right)
	var top: float = MAX_SPEED * top_speed_factor * (BOOST_SPEED_MULT if boost_time > 0.0 else 1.0)
	var drifting: bool = braking and forward_speed > 15.0 and not stunned
	if stunned:
		forward_speed = move_toward(forward_speed, 0.0, 30.0 * dt)
	elif braking and not drifting:
		forward_speed = move_toward(forward_speed, 0.0, BRAKE_DECEL * dt)
	else:
		var accel: float = ACCEL * (2.2 if boost_time > 0.0 else 1.0)
		forward_speed += accel * throttle * maxf(1.0 - forward_speed / top, 0.0) * dt
		if forward_speed > top:
			forward_speed = move_toward(forward_speed, top, 40.0 * dt)
	lateral *= exp(-(DRIFT_GRIP if drifting else GRIP) * dt)
	velocity = fwd * forward_speed + right * lateral
	position += velocity * dt
	position.y = 0.0
	rotation.y = heading
	var roll: float = clampf(lateral * 0.02 + steer * 0.05, -0.25, 0.25)
	_model.rotation.z = lerpf(_model.rotation.z, roll, 1.0 - exp(-10.0 * dt))
	_trail.emitting = Fx.enabled and boost_time > 0.0


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	_model.add_child(mesh)
