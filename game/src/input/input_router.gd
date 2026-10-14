extends Node
## Single entry point for player intent. Keyboard and gamepad arrive through the
## InputMap; touch arrives through the set_virtual_* calls. Gameplay never reads Input.*.

const BUFFER_SECONDS: float = 0.12
const BUFFERED_ACTIONS: Array[StringName] = [&"jump", &"attack", &"roll"]

var _virtual_axis: float = 0.0
var _virtual_held: Dictionary = {}
var _virtual_swap: bool = false
var _stamps: Dictionary = {}


func _input(event: InputEvent) -> void:
	for action in BUFFERED_ACTIONS:
		if event.is_action_pressed(action) and not event.is_echo():
			_stamp(action)


## Physical and virtual axes are summed then clamped, so opposing inputs
## (left key + right touch, or either device pushing both ways) cancel to 0.
func move_axis() -> float:
	return clampf(Input.get_axis(&"move_left", &"move_right") + _virtual_axis, -1.0, 1.0)


func jump_held() -> bool:
	return Input.is_action_pressed(&"jump") or _virtual_held.get(&"jump", false)


func jump_buffered() -> bool:
	return _is_buffered(&"jump")


func consume_jump() -> void:
	_stamps.erase(&"jump")


func attack_buffered() -> bool:
	return _is_buffered(&"attack")


func consume_attack() -> void:
	_stamps.erase(&"attack")


func roll_buffered() -> bool:
	return _is_buffered(&"roll")


func consume_roll() -> void:
	_stamps.erase(&"roll")


## True once per press. The physical half is an edge; the touch half is a flag that
## is consumed by this read, so a tap swaps once however often it is polled.
func swap_weapon_pressed() -> bool:
	var virtual_tap := _virtual_swap
	_virtual_swap = false
	return Input.is_action_just_pressed(&"swap_weapon") or virtual_tap


func set_virtual_axis(value: float) -> void:
	_virtual_axis = clampf(value, -1.0, 1.0)


func set_virtual_button(action: StringName, pressed: bool) -> void:
	_virtual_held[action] = pressed
	if action == &"swap_weapon" and pressed:
		_virtual_swap = true
	if pressed and action in BUFFERED_ACTIONS:
		_stamp(action)


func _stamp(action: StringName) -> void:
	_stamps[action] = Time.get_ticks_msec()


func _is_buffered(action: StringName) -> bool:
	if not _stamps.has(action):
		return false
	return (Time.get_ticks_msec() - _stamps[action]) < BUFFER_SECONDS * 1000.0
