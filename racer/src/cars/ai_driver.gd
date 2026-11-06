extends RefCounted
## Steers a car along the track centre line with a per-driver lane offset,
## braking for upcoming sharp corners.

const Car := preload("res://src/cars/car.gd")
const Track := preload("res://src/track/track.gd")

var lane_offset: float = 0.0
var caution: float = 1.0  ## Scales how early the driver slows for corners.


func drive(car: Car, track: Track) -> void:
	var speed: float = car.speed()
	var ahead_steps: int = clampi(int(speed * 0.45 / track.spacing), 5, 28)
	var target_index: int = track.wrap_index(car.track_index + ahead_steps)
	var target: Vector3 = track.points[target_index] + track.rights[target_index] * lane_offset
	var to_target: Vector3 = target - car.position
	var diff: float = wrapf(atan2(to_target.x, to_target.z) - car.heading, -PI, PI)
	car.steer = clampf(-diff * 2.2, -1.0, 1.0)
	var sharpness: float = 0.0
	for k in 12:
		sharpness += track.turn[track.wrap_index(car.track_index + 2 + k * 2)]
	var target_speed: float = lerpf(48.0, 22.0, clampf((sharpness * caution - 0.15) / 0.45, 0.0, 1.0))
	car.throttle = 1.0 if speed < target_speed else 0.2
	car.braking = speed > target_speed + 10.0
