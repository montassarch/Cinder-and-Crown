class_name MetaShop
extends CanvasLayer
## Between runs: spend cells on permanent upgrades, then start the next run. Pauses the
## game while open. Every row is one big tap target.

signal start_requested

const PANEL_WIDTH_TILES: float = 21.0
const ROW_HEIGHT_TILES: float = 1.5
const START_HEIGHT_TILES: float = 1.5
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.8)
const PANEL_COLOR := Color(0.09, 0.08, 0.12, 1.0)
const CELL_COLOR := Color(0.55, 0.95, 1.0)
const BORDER_COLOR := Color(0.66, 0.62, 0.7)
const BORDER_READY_COLOR := Color(1.0, 0.82, 0.3)

var _upgrades: Array[MetaUpgradeData] = []
var _root: Control
var _column: VBoxContainer
var _cells_label: Label
var _run_label: Label
var _rows: Array[Button] = []
var _start_button: Button
var _open: bool = false


func _ready() -> void:
	layer = 26
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
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.custom_minimum_size.x = GameConfig.tiles(PANEL_WIDTH_TILES)
	_column.add_theme_constant_override("separation", int(GameConfig.tiles(0.2)))
	center.add_child(_column)
	var heading := Label.new()
	heading.text = "YOU FELL  -  SPEND YOUR CELLS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(heading)
	var tally := HBoxContainer.new()
	tally.alignment = BoxContainer.ALIGNMENT_CENTER
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally.add_theme_constant_override("separation", int(GameConfig.tiles(2.0)))
	_column.add_child(tally)
	_cells_label = Label.new()
	_cells_label.add_theme_color_override("font_color", CELL_COLOR)
	tally.add_child(_cells_label)
	_run_label = Label.new()
	tally.add_child(_run_label)


func is_open() -> bool:
	return _open


## Show the shop with these upgrades. `cells_this_run` is only for the summary line.
func open(upgrades: Array[MetaUpgradeData], cells_this_run: int) -> void:
	_upgrades = upgrades.duplicate()
	_run_label.text = "Found this run: +%d" % cells_this_run
	_rebuild_rows()
	_open = true
	_root.visible = true
	get_tree().paused = true


func row_count() -> int:
	return _rows.size()


func row_text(index: int) -> String:
	return _rows[index].text


func cells_text() -> String:
	return _cells_label.text


func run_text() -> String:
	return _run_label.text


func buy_enabled(index: int) -> bool:
	return not _rows[index].disabled


func press_buy(index: int) -> void:
	_rows[index].pressed.emit()


func press_start() -> void:
	_start_button.pressed.emit()


func _rebuild_rows() -> void:
	for row in _rows:
		_column.remove_child(row)
		row.queue_free()
	_rows.clear()
	if _start_button != null:
		_column.remove_child(_start_button)
		_start_button.queue_free()
	for index in _upgrades.size():
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size.y = GameConfig.tiles(ROW_HEIGHT_TILES)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(_on_row_pressed.bind(index))
		_column.add_child(row)
		_rows.append(row)
	_start_button = Button.new()
	_start_button.text = "DESCEND AGAIN"
	_start_button.focus_mode = Control.FOCUS_NONE
	_start_button.custom_minimum_size.y = GameConfig.tiles(START_HEIGHT_TILES)
	_start_button.pressed.connect(_on_start_pressed)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.2, 0.14, 0.05) if state != "pressed" else Color(0.32, 0.22, 0.08)
		box.set_border_width_all(2)
		box.border_color = BORDER_READY_COLOR
		_start_button.add_theme_stylebox_override(state, box)
	_column.add_child(_start_button)
	_refresh()


func _refresh() -> void:
	_cells_label.text = "Cells: %d" % MetaSave.cells()
	for index in _upgrades.size():
		var upgrade := _upgrades[index]
		var owned := MetaSave.rank(upgrade.id)
		var cost := MetaSave.next_cost(upgrade)
		var price := "MAX" if cost < 0 else "%d cells" % cost
		var row := _rows[index]
		row.text = "%s  [%d/%d]   %s\n%s" % [upgrade.display_name, owned, upgrade.costs.size(), price, upgrade.description]
		row.disabled = not MetaSave.can_afford(upgrade)
		var border := BORDER_READY_COLOR if not row.disabled else BORDER_COLOR
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = PANEL_COLOR.lightened(0.12) if state == "pressed" else PANEL_COLOR
			box.set_border_width_all(2)
			box.border_color = border
			box.set_content_margin_all(int(GameConfig.tiles(0.15)))
			row.add_theme_stylebox_override(state, box)


func _on_row_pressed(index: int) -> void:
	if not _open or index >= _upgrades.size():
		return
	if MetaSave.buy(_upgrades[index]):
		_refresh()


func _on_start_pressed() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	start_requested.emit()
