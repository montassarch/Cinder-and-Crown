class_name BoonPicker
extends CanvasLayer
## The pick-one-of-three screen after a level. Pauses the game while open; a tap on a
## card (or its number key) takes that boon. Cards are sized for thumbs.

signal chosen(boon: BoonData)

const CARD_SIZE_TILES := Vector2(7.0, 5.0)
const CARD_GAP_TILES: float = 0.5
const DIM_COLOR := Color(0.0, 0.0, 0.0, 0.72)
const CARD_COLOR := Color(0.09, 0.08, 0.12, 1.0)
const RARITY_COLORS := {
	BoonData.Rarity.COMMON: Color(0.66, 0.62, 0.7),
	BoonData.Rarity.RARE: Color(0.5, 0.83, 1.0),
	BoonData.Rarity.EPIC: Color(1.0, 0.7, 0.28),
}
const RARITY_NAMES := {
	BoonData.Rarity.COMMON: "COMMON",
	BoonData.Rarity.RARE: "RARE",
	BoonData.Rarity.EPIC: "EPIC",
}
const KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]

var _offers: Array[BoonData] = []
var _root: Control
var _row: HBoxContainer
var _cards: Array[Button] = []
var _titles: Array[Label] = []
var _descriptions: Array[Label] = []
var _open: bool = false


func _ready() -> void:
	layer = 25
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
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", int(GameConfig.tiles(0.5)))
	center.add_child(column)
	var heading := Label.new()
	heading.text = "CHOOSE A BOON"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", int(GameConfig.tiles(CARD_GAP_TILES)))
	column.add_child(_row)


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var index := KEYS.find(event.keycode)
	if index >= 0 and index < _offers.size():
		choose(index)
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _open


## Show these boons and pause the game until one is chosen. An empty offer stays closed.
func offer(boons: Array[BoonData]) -> void:
	_clear_cards()
	_offers = boons.duplicate()
	if _offers.is_empty():
		return
	for index in _offers.size():
		_add_card(index, _offers[index])
	_open = true
	_root.visible = true
	get_tree().paused = true


func choose(index: int) -> void:
	if not _open or index < 0 or index >= _offers.size():
		return
	var boon := _offers[index]
	_open = false
	_root.visible = false
	get_tree().paused = false
	chosen.emit(boon)


func offered(index: int) -> BoonData:
	return _offers[index]


func card_count() -> int:
	return _cards.size()


func card_title(index: int) -> String:
	return _titles[index].text


func card_description(index: int) -> String:
	return _descriptions[index].text


func card_color(index: int) -> Color:
	return RARITY_COLORS[_offers[index].rarity]


func press_card(index: int) -> void:
	_cards[index].pressed.emit()


func _clear_cards() -> void:
	for card in _cards:
		_row.remove_child(card)
		card.queue_free()
	_cards.clear()
	_titles.clear()
	_descriptions.clear()


func _add_card(index: int, boon: BoonData) -> void:
	var color: Color = RARITY_COLORS[boon.rarity]
	var card := Button.new()
	card.custom_minimum_size = GameConfig.tiles_v(CARD_SIZE_TILES.x, CARD_SIZE_TILES.y)
	card.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = CARD_COLOR.lightened(0.12) if state == "pressed" else CARD_COLOR
		box.set_border_width_all(2)
		box.border_color = color
		card.add_theme_stylebox_override(state, box)
	card.pressed.connect(choose.bind(index))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(GameConfig.tiles(0.4)))
	card.add_child(margin)
	var box_column := VBoxContainer.new()
	box_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_column.add_theme_constant_override("separation", int(GameConfig.tiles(0.35)))
	margin.add_child(box_column)
	var tag := _label("%d  %s" % [index + 1, RARITY_NAMES[boon.rarity]], color)
	var title := _label(boon.display_name, Color.WHITE)
	var description := _label(boon.description, Color(0.85, 0.83, 0.9))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for label in [tag, title, description]:
		box_column.add_child(label)
	_row.add_child(card)
	_cards.append(card)
	_titles.append(title)
	_descriptions.append(description)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
