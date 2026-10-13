extends CanvasLayer

## On-screen controls for touch devices: a left-hand stick and right-hand
## Attack / Jump / Roll buttons.
##
## This layer never implements game logic. Its only output is
## InputRouter.set_virtual_axis() and set_virtual_button(), so a tap is
## indistinguishable from a key by the time gameplay sees it.
##
## Everything is sized in tiles through GameConfig, per the project's
## resolution rule -- so these controls stay proportionate if the base
## resolution moves toward Dead Cells-scale art.

## Stick travel before the axis reads full tilt.
const STICK_RADIUS_TILES: float = 1.5

## Below this fraction of the radius the stick reads as centred, so a
## resting thumb does not creep the player sideways.
const DEADZONE_FRACTION: float = 0.2

@onready var _stick_base: Control = %StickBase
@onready var _stick_knob: Control = %StickKnob

var _stick_touch_index: int = -1
var _stick_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Hidden on desktop, but kept in the tree so a device with both a
	# touchscreen and a keyboard can use either. The router sums sources,
	# so showing these never suppresses the keyboard.
	visible = DisplayServer.is_touchscreen_available()

	%AttackButton.button_down.connect(_on_button.bind(&"attack", true))
	%AttackButton.button_up.connect(_on_button.bind(&"attack", false))
	%JumpButton.button_down.connect(_on_button.bind(&"jump", true))
	%JumpButton.button_up.connect(_on_button.bind(&"jump", false))
	%RollButton.button_down.connect(_on_button.bind(&"roll", true))
	%RollButton.button_up.connect(_on_button.bind(&"roll", false))
	%SwapButton.button_down.connect(_on_button.bind(&"swap_weapon", true))
	%SwapButton.button_up.connect(_on_button.bind(&"swap_weapon", false))

	var diameter := GameConfig.tiles(STICK_RADIUS_TILES * 2.0)
	_stick_base.custom_minimum_size = Vector2(diameter, diameter)
	_reset_knob()


func _on_button(action: StringName, pressed: bool) -> void:
	InputRouter.set_virtual_button(action, pressed)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _stick_touch_index == -1 and _is_in_stick_area(touch.position):
			_stick_touch_index = touch.index
			_stick_origin = touch.position
		elif not touch.pressed and touch.index == _stick_touch_index:
			_release_stick()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_touch_index:
			_update_stick(drag.position)


func _is_in_stick_area(position: Vector2) -> bool:
	# The whole left half is the stick's catch area, so the player does not
	# have to find a small circle without looking.
	return position.x < get_viewport().get_visible_rect().size.x * 0.5


func _update_stick(position: Vector2) -> void:
	var radius := GameConfig.tiles(STICK_RADIUS_TILES)
	var offset := (position - _stick_origin).limit_length(radius)
	var normalized := offset.x / radius
	if absf(normalized) < DEADZONE_FRACTION:
		normalized = 0.0
	InputRouter.set_virtual_axis(normalized)
	_stick_knob.position = _stick_base.position + _stick_base.size * 0.5 \
		+ Vector2(offset.x, 0.0) - _stick_knob.size * 0.5


func _release_stick() -> void:
	_stick_touch_index = -1
	InputRouter.set_virtual_axis(0.0)
	_reset_knob()


func _reset_knob() -> void:
	_stick_knob.position = _stick_base.position + _stick_base.size * 0.5 \
		- _stick_knob.size * 0.5
