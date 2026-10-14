extends Node
## Brief global slow-down on impact. Real-time based, so it cannot hold itself open.

const FROZEN_TIME_SCALE: float = 0.05

var _release_at_msec: int = 0


func _ready() -> void:
	# Keep ticking while the sandbox menu pauses the tree, or time_scale could stay frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func freeze(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_release_at_msec = maxi(_release_at_msec, Time.get_ticks_msec() + int(seconds * 1000.0))
	Engine.time_scale = FROZEN_TIME_SCALE
	set_process(true)


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() >= _release_at_msec:
		Engine.time_scale = 1.0
		set_process(false)
