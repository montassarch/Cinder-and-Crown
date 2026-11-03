class_name VictoryScreen
extends CanvasLayer
## Shown when the last world's boss falls: the run is won. Pauses the game; one big button starts a new run.

signal new_run_requested

const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.82)
const TITLE_COLOR := Color(1.0, 0.84, 0.45)
const BUTTON_HEIGHT_TILES: float = 1.8

var _root: Control
var _title: Label
var _lines: Label
var _button: Button
var _open: bool = false


func _ready() -> void:
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	var theme := Theme.new()
	theme.default_font_size = GameConfig.UI_FONT_SIZE
	_root.theme = theme
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(GameConfig.tiles(0.4)))
	column.custom_minimum_size.x = GameConfig.tiles(16.0)
	center.add_child(column)
	_title = Label.new()
	_title.text = "VICTORY"
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	_title.add_theme_constant_override("outline_size", 8)
	_lines = Label.new()
	for label: Label in [_title, _lines]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	_button = Button.new()
	_button.text = "Begin a new run"
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size.y = GameConfig.tiles(BUTTON_HEIGHT_TILES)
	_button.pressed.connect(_on_new_run)
	column.add_child(_button)


func open(boss_name: String, cells: int, wins: int) -> void:
	_lines.text = "%s has fallen. The crown is yours.\nCells gathered this run: %d    Runs won: %d" % [boss_name, cells, wins]
	_root.visible = true
	_open = true
	get_tree().paused = true


func is_open() -> bool:
	return _open


func press_new_run() -> void:
	_button.pressed.emit()


func _on_new_run() -> void:
	_root.visible = false
	_open = false
	get_tree().paused = false
	new_run_requested.emit()
