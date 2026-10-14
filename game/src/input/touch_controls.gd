extends CanvasLayer
## On-screen stick (left) plus Attack / Jump / Roll buttons (right).
## Talks to the game only through InputRouter.set_virtual_*; it never marks
## events handled, so keyboard and gamepad keep working while it is shown.

const STICK_CENTER_TILES := Vector2(3.5, 10.0)
const STICK_RADIUS_TILES: float = 2.5
const STICK_ZONE_RIGHT_EDGE_TILES: float = 8.0
## Touches above this line belong to menus and the HUD, not the stick.
const STICK_ZONE_TOP_TILES: float = 7.0
const STICK_DEADZONE: float = 0.25
const BUTTON_RADIUS_TILES: float = 1.4
const BUTTON_CENTERS_TILES := {
	&"attack": Vector2(21.5, 10.0),
	&"jump": Vector2(21.5, 6.8),
	&"roll": Vector2(18.5, 10.8),
	&"swap_weapon": Vector2(18.5, 7.4),
}
const BUTTON_LABELS := {&"attack": "ATK", &"jump": "JMP", &"roll": "ROLL", &"swap_weapon": "SWAP"}

## Show even without a touchscreen (desktop testing).
@export var force_visible: bool = false

var _stick_finger: int = -1
var _button_fingers: Dictionary = {}
var _stick_value: float = 0.0

@onready var _overlay: Control = $Overlay


func _ready() -> void:
	visible = force_visible or DisplayServer.is_touchscreen_available()
	_overlay.draw.connect(_draw_overlay)
	_overlay.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag and event.index == _stick_finger:
		_update_stick(event.position)


## Lets go of every finger; used when a menu takes over and touch-ups would be missed.
func release_all() -> void:
	for finger in _button_fingers.keys():
		InputRouter.set_virtual_button(_button_fingers[finger], false)
	_button_fingers.clear()
	_stick_finger = -1
	_stick_value = 0.0
	InputRouter.set_virtual_axis(0.0)
	_overlay.queue_redraw()


func _touch_down(finger: int, pos: Vector2) -> void:
	for action in BUTTON_CENTERS_TILES:
		var center: Vector2 = GameConfig.tiles_v(BUTTON_CENTERS_TILES[action].x, BUTTON_CENTERS_TILES[action].y)
		if pos.distance_to(center) <= GameConfig.tiles(BUTTON_RADIUS_TILES):
			_button_fingers[finger] = action
			InputRouter.set_virtual_button(action, true)
			_overlay.queue_redraw()
			return
	if _stick_finger == -1 and pos.x <= GameConfig.tiles(STICK_ZONE_RIGHT_EDGE_TILES) and pos.y >= GameConfig.tiles(STICK_ZONE_TOP_TILES):
		_stick_finger = finger
		_update_stick(pos)


func _touch_up(finger: int) -> void:
	if finger == _stick_finger:
		_stick_finger = -1
		_stick_value = 0.0
		InputRouter.set_virtual_axis(0.0)
	elif _button_fingers.has(finger):
		InputRouter.set_virtual_button(_button_fingers[finger], false)
		_button_fingers.erase(finger)
	_overlay.queue_redraw()


func _update_stick(pos: Vector2) -> void:
	var center := GameConfig.tiles_v(STICK_CENTER_TILES.x, STICK_CENTER_TILES.y)
	var raw := (pos.x - center.x) / GameConfig.tiles(STICK_RADIUS_TILES)
	_stick_value = clampf(raw, -1.0, 1.0)
	InputRouter.set_virtual_axis(0.0 if absf(_stick_value) < STICK_DEADZONE else _stick_value)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	var idle := Color(1, 1, 1, 0.18)
	var active := Color(1, 1, 1, 0.4)
	var stick_center := GameConfig.tiles_v(STICK_CENTER_TILES.x, STICK_CENTER_TILES.y)
	_overlay.draw_circle(stick_center, GameConfig.tiles(STICK_RADIUS_TILES), idle)
	var knob := stick_center + Vector2(_stick_value * GameConfig.tiles(STICK_RADIUS_TILES), 0.0)
	_overlay.draw_circle(knob, GameConfig.tiles(1.0), active)
	for action in BUTTON_CENTERS_TILES:
		var center := GameConfig.tiles_v(BUTTON_CENTERS_TILES[action].x, BUTTON_CENTERS_TILES[action].y)
		var pressed := _button_fingers.values().has(action)
		_overlay.draw_circle(center, GameConfig.tiles(BUTTON_RADIUS_TILES), active if pressed else idle)
		var width := GameConfig.tiles(BUTTON_RADIUS_TILES * 2.0)
		var label_pos := center + Vector2(-width / 2.0, GameConfig.UI_FONT_SIZE / 3.0)
		_overlay.draw_string(ThemeDB.fallback_font, label_pos, BUTTON_LABELS[action], HORIZONTAL_ALIGNMENT_CENTER, width, GameConfig.UI_FONT_SIZE, Color(1, 1, 1, 0.8))
