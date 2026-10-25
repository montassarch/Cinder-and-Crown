class_name CameraShake
extends Node
## Screen shake for the Camera2D it is a child of. Hits `kick` it; the shake grows with the square of the trauma
## (small kicks are a tremor, big ones a jolt) and dies away on its own. It runs on game time, so it freezes with the
## hit-stop and stops with the pause menu.

const MAX_OFFSET: float = 5.0
const DECAY_PER_SECOND: float = 2.4

## Switch off for players who find shaking uncomfortable.
var enabled: bool = true
var trauma: float = 0.0


func kick(amount: float) -> void:
	if not enabled:
		return
	trauma = minf(1.0, trauma + amount)


func _process(delta: float) -> void:
	var camera := get_parent() as Camera2D
	if camera == null:
		return
	if trauma <= 0.0:
		camera.offset = Vector2.ZERO
		return
	trauma = maxf(0.0, trauma - DECAY_PER_SECOND * delta)
	var shake := trauma * trauma * MAX_OFFSET
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake if trauma > 0.0 else Vector2.ZERO
