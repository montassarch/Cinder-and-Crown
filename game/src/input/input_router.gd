extends Node

## The single gate between engine input and gameplay.
##
## Nothing in src/player, src/weapons or src/enemies may call Input.*
## directly. Keyboard, gamepad and touch are equal first-class paths, and
## they all arrive here: physical input through the provider seams below,
## touch through set_virtual_axis() / set_virtual_button().
##
## The three Callable seams exist so this is testable. Godot delivers no
## InputEvents in headless mode, so a router that called Input.get_axis()
## inline could not be tested at all -- including the case where keyboard
## and touch disagree on the same frame.

## How long a press stays queued. Jump, attack and roll are all buffered so
## a press landing a few frames early still fires, which is most of what
## makes this combat model feel responsive rather than strict.
const BUFFER_SECONDS: float = 0.12

## The actions this router queues. Held-only actions are not listed.
const BUFFERED_ACTIONS: Array[StringName] = [&"jump", &"attack", &"roll", &"swap_weapon"]

## Seams. Replaced in tests; left alone in the running game.
var time_provider: Callable = func() -> float:
	return Time.get_ticks_msec() / 1000.0

var physical_axis_provider: Callable = func() -> float:
	return Input.get_axis(&"move_left", &"move_right")

var physical_pressed_provider: Callable = func(action: StringName) -> bool:
	return Input.is_action_pressed(action)

var _virtual_axis: float = 0.0
var _virtual_held: Dictionary = {}
var _buffer: Dictionary = {}


func _process(_delta: float) -> void:
	# Physical presses are polled rather than taken from _input(), so one
	# code path serves keyboard and gamepad alike.
	for action: StringName in BUFFERED_ACTIONS:
		if Input.is_action_just_pressed(action):
			press(action)


# --- axis ---

## Horizontal movement intent, -1.0 to 1.0.
##
## Sources are summed and then clamped, which is what makes disagreement
## deterministic: keyboard-left plus touch-right is 0.0 every frame, never
## an alternating value that depends on which source was written last.
func move_axis() -> float:
	var physical: float = physical_axis_provider.call()
	return clampf(physical + _virtual_axis, -1.0, 1.0)


func set_virtual_axis(value: float) -> void:
	_virtual_axis = clampf(value, -1.0, 1.0)


# --- buffered presses ---

## Queues an action. Called by _process for physical input and by the touch
## layer through set_virtual_button().
func press(action: StringName) -> void:
	_buffer[action] = float(time_provider.call())


func is_buffered(action: StringName) -> bool:
	if not _buffer.has(action):
		return false
	return float(time_provider.call()) - float(_buffer[action]) < BUFFER_SECONDS


func consume(action: StringName) -> void:
	_buffer.erase(action)


func jump_buffered() -> bool:
	return is_buffered(&"jump")


func consume_jump() -> void:
	consume(&"jump")


func attack_buffered() -> bool:
	return is_buffered(&"attack")


func consume_attack() -> void:
	consume(&"attack")


func roll_buffered() -> bool:
	return is_buffered(&"roll")


func consume_roll() -> void:
	consume(&"roll")


func swap_weapon_pressed() -> bool:
	return is_buffered(&"swap_weapon")


func consume_swap_weapon() -> void:
	consume(&"swap_weapon")


# --- held state ---

func is_held(action: StringName) -> bool:
	if _virtual_held.get(action, false):
		return true
	return bool(physical_pressed_provider.call(action))


## Held rather than buffered, because jump height scales with how long the
## button stays down.
func jump_held() -> bool:
	return is_held(&"jump")


# --- touch entry point ---

## The only way the touch layer talks to this router. A virtual press
## queues the same buffer a key would, so gameplay cannot tell them apart.
func set_virtual_button(action: StringName, pressed: bool) -> void:
	if pressed:
		_virtual_held[action] = true
		press(action)
	else:
		_virtual_held.erase(action)
