class_name SandboxMenu
extends CanvasLayer
## Test-room control panel. Lists whatever .tres files exist in the data folders
## at runtime, so new content shows up here with no code change. Opening it
## pauses the game, which also keeps touch controls out of the way.

signal spawn_requested(data: EnemyData)
signal clear_requested
signal weapon_assigned(slot: int, data: WeaponData)
signal reset_requested
signal debug_toggled(enabled: bool)
signal opened(is_open: bool)

const ENEMY_DIR := "res://data/enemies"
const WEAPON_DIR := "res://data/weapons"
const PANEL_MARGIN_TILES: float = 0.25
const TOGGLE_SIZE_TILES := Vector2(2.75, 1.1)
const PANEL_COLOR := Color(0.07, 0.06, 0.1, 1.0)

var _enemies: Array[EnemyData] = []
var _weapons: Array[WeaponData] = []
var _panel: PanelContainer
var _toggle: Button
var _spawn_buttons: Array[Button] = []
var _clear_button: Button
var _pickers: Array[OptionButton] = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in DataScanner.list(ENEMY_DIR):
		var enemy := load(path) as EnemyData
		if enemy != null:
			_enemies.append(enemy)
	for path in DataScanner.list(WEAPON_DIR):
		var weapon := load(path) as WeaponData
		if weapon != null:
			_weapons.append(weapon)
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_menu"):
		set_open(not is_open())
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


func set_open(open: bool) -> void:
	_panel.visible = open
	_toggle.text = "Close" if open else "Menu"
	get_tree().paused = open
	opened.emit(open)


func spawn_button_count() -> int:
	return _spawn_buttons.size()


func weapon_choice_count() -> int:
	return _weapons.size()


func press_spawn(index: int) -> void:
	_spawn_buttons[index].pressed.emit()


func press_clear() -> void:
	_clear_button.pressed.emit()


## Point each slot picker at what the player is actually holding.
func sync_weapons(player: Player) -> void:
	for slot in _pickers.size():
		var held := player.weapon_in_slot(slot)
		for i in _weapons.size():
			if held != null and _weapons[i].resource_path == held.resource_path:
				_pickers[slot].select(i)


func _build_ui() -> void:
	var theme := Theme.new()
	theme.default_font_size = GameConfig.UI_FONT_SIZE
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := GameConfig.tiles(PANEL_MARGIN_TILES)
	_panel.offset_left = margin
	_panel.offset_top = margin
	_panel.offset_right = -margin
	_panel.offset_bottom = -margin
	_panel.visible = false
	var background := StyleBoxFlat.new()
	background.bg_color = PANEL_COLOR
	background.set_content_margin_all(GameConfig.tiles(0.5))
	_panel.add_theme_stylebox_override("panel", background)
	root.add_child(_panel)

	var column := VBoxContainer.new()
	_panel.add_child(column)
	column.add_child(_make_label("SANDBOX"))

	var spawn_row := HFlowContainer.new()
	spawn_row.add_child(_make_label("Spawn:"))
	for data in _enemies:
		var button := _make_button(data.display_name)
		button.pressed.connect(func() -> void: spawn_requested.emit(data))
		spawn_row.add_child(button)
		_spawn_buttons.append(button)
	column.add_child(spawn_row)

	for slot in Player.WEAPON_SLOTS:
		var row := HBoxContainer.new()
		row.add_child(_make_label("Slot %s:" % "AB"[slot]))
		var picker := OptionButton.new()
		picker.focus_mode = Control.FOCUS_NONE
		for weapon in _weapons:
			picker.add_item(weapon.display_name)
		picker.item_selected.connect(func(index: int) -> void: weapon_assigned.emit(slot, _weapons[index]))
		row.add_child(picker)
		column.add_child(row)
		_pickers.append(picker)

	var actions := HFlowContainer.new()
	_clear_button = _make_button("Clear enemies")
	_clear_button.pressed.connect(func() -> void: clear_requested.emit())
	actions.add_child(_clear_button)
	var reset := _make_button("Reset player")
	reset.pressed.connect(func() -> void: reset_requested.emit())
	actions.add_child(reset)
	var debug := CheckButton.new()
	debug.text = "Debug boxes"
	debug.focus_mode = Control.FOCUS_NONE
	debug.toggled.connect(func(on: bool) -> void: debug_toggled.emit(on))
	actions.add_child(debug)
	column.add_child(actions)

	_toggle = _make_button("Menu")
	_toggle.name = "Toggle"
	_toggle.anchor_left = 1.0
	_toggle.anchor_right = 1.0
	_toggle.offset_left = -GameConfig.tiles(TOGGLE_SIZE_TILES.x + 0.25)
	_toggle.offset_right = -GameConfig.tiles(0.25)
	_toggle.offset_top = GameConfig.tiles(0.25)
	_toggle.offset_bottom = GameConfig.tiles(0.25 + TOGGLE_SIZE_TILES.y)
	_toggle.pressed.connect(func() -> void: set_open(not is_open()))
	root.add_child(_toggle)  # added last so it stays above the panel and can close it


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	return button


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
