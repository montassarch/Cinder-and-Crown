extends CanvasLayer

## The controls list, built from the actual InputMap.
##
## Deliberately not a hand-written table. A hardcoded list drifts the first
## time a binding changes and then lies to the player, which is worse than
## no list at all. This reads InputMap at runtime, so it is correct by
## construction -- rebind a key in Project Settings and this follows.

## Actions shown, in the order a player wants to learn them, paired with
## what they do. Anything in InputMap but absent here is editor plumbing.
const ACTIONS: Array = [
	[&"move_left", "Move left"],
	[&"move_right", "Move right"],
	[&"jump", "Jump"],
	[&"attack", "Attack"],
	[&"roll", "Roll (brief invincibility)"],
	[&"swap_weapon", "Swap weapon"],
	[&"toggle_help", "Show / hide this list"],
]

@onready var _grid: GridContainer = %Grid
@onready var _panel: Control = %Panel


func _ready() -> void:
	_build()
	# Visible on launch: a player who has never seen the game should not
	# have to guess which key opens the key list.
	_panel.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_help"):
		_panel.visible = not _panel.visible
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible


## Human-readable bindings for one action, e.g. "A, Left" or "Space, Pad A".
static func bindings_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "unbound"
	var names: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var label := _describe(event)
		if label != "" and label not in names:
			names.append(label)
	return ", ".join(names) if not names.is_empty() else "unbound"


static func _describe(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		return "Left click" if button.button_index == MOUSE_BUTTON_LEFT else "Mouse %d" % button.button_index
	if event is InputEventJoypadButton:
		# Named rather than numbered: "Pad 0" means nothing to a player.
		const PAD := {0: "Pad A", 1: "Pad B", 2: "Pad X", 3: "Pad Y",
			13: "Pad Left", 14: "Pad Right"}
		var pad := event as InputEventJoypadButton
		return PAD.get(pad.button_index, "Pad %d" % pad.button_index)
	if event is InputEventJoypadMotion:
		return "Stick"
	return ""


func _build() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	for entry: Array in ACTIONS:
		var action: StringName = entry[0]
		var keys := Label.new()
		keys.text = bindings_for(action)
		keys.custom_minimum_size.x = GameConfig.tiles(5.0)
		_grid.add_child(keys)

		var what := Label.new()
		what.text = entry[1]
		_grid.add_child(what)
