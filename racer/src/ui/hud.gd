extends CanvasLayer
## Touch HUD: steering drag zone, DRIFT and USE buttons, debug toggles, race stats, a centre
## message, a loading cover and the settings panel. Layout and sensitivity come from Settings.

signal brake_changed(pressed: bool)
signal use_pressed
signal restart_pressed
signal car_cycle_pressed
signal give_item_pressed
signal shadows_toggled(enabled: bool)
signal glow_toggled(enabled: bool)
signal particles_toggled(enabled: bool)
signal render_scale_changed(value: float)
signal settings_opened(is_open: bool)

const Settings := preload("res://src/core/settings.gd")
const ItemDefs := preload("res://src/items/item_defs.gd")

const BASE_STEER_RANGE: float = 110.0  ## Drag distance for full lock at sensitivity 1.
const BUTTON_AREA: Vector2 = Vector2(380.0, 300.0)
const SCREEN_MARGIN: float = 28.0
const RENDER_SCALES: Array[float] = [1.0, 0.75, 0.5]

var settings: Settings  ## Assign before adding this node to the tree.
var steer_input: float = 0.0

var _steer_index: int = -1
var _steer_origin: Vector2 = Vector2.ZERO
var _steer_view: SteerView
var _button_holder: Control
var _action_buttons: Array[Button] = []
var _stats: Label
var _message: Label
var _scale_step: int = 0
var _cover: ColorRect
var _panel: PanelContainer
var _mirror_check: CheckButton
var _slider_rows: Dictionary = {}
var _status_view: StatusView
var _flash: ColorRect


class SteerView extends Control:
	var active: bool = false
	var origin: Vector2 = Vector2.ZERO
	var value: float = 0.0
	var reach: float = 110.0

	func _draw() -> void:
		if not active:
			return
		draw_line(origin - Vector2(reach, 0), origin + Vector2(reach, 0), Color(1, 1, 1, 0.35), 6.0)
		draw_circle(origin + Vector2(value * reach, 0), 34.0, Color(1, 1, 1, 0.45))


## Health bar and the three item slots, drawn at the top centre.
class StatusView extends Control:
	const BAR_SIZE: Vector2 = Vector2(340.0, 18.0)
	const SLOT_SIZE: float = 74.0
	const SLOT_GAP: float = 12.0

	var health_ratio: float = 1.0
	var items: Array[int] = []

	func _draw() -> void:
		var centre_x: float = size.x * 0.70  # clear of the stats text (left) and Settings (right)
		var bar_origin := Vector2(centre_x - BAR_SIZE.x / 2.0, 14.0)
		draw_rect(Rect2(bar_origin - Vector2(3, 3), BAR_SIZE + Vector2(6, 6)), Color(0, 0, 0, 0.55))
		var fill: Color = Color(0.35, 1.0, 0.35).lerp(Color(1.0, 0.25, 0.2), 1.0 - clampf(health_ratio * 1.6, 0.0, 1.0))
		draw_rect(Rect2(bar_origin, Vector2(BAR_SIZE.x * clampf(health_ratio, 0.0, 1.0), BAR_SIZE.y)), fill)
		var font: Font = ThemeDB.fallback_font
		var total: float = ItemDefs.SLOT_COUNT * SLOT_SIZE + (ItemDefs.SLOT_COUNT - 1) * SLOT_GAP
		var left: float = centre_x - total / 2.0
		for i in ItemDefs.SLOT_COUNT:
			var rect := Rect2(Vector2(left + i * (SLOT_SIZE + SLOT_GAP), 46.0), Vector2(SLOT_SIZE, SLOT_SIZE))
			draw_rect(rect, Color(0, 0, 0, 0.55))
			if i < items.size():
				var color: Color = ItemDefs.color(items[i])
				draw_rect(rect.grow(-6.0), color.darkened(0.15 if i == 0 else 0.45))
				draw_string(font, rect.position + Vector2(0, SLOT_SIZE / 2.0 + 7.0), ItemDefs.item_name(items[i]),
					HORIZONTAL_ALIGNMENT_CENTER, SLOT_SIZE, 18, Color.BLACK if i == 0 else Color(0, 0, 0, 0.6))
			draw_rect(rect, Color(1, 1, 1, 0.95 if i == 0 else 0.3), false, 3.0 if i == 0 else 1.5)


func _ready() -> void:
	_steer_view = SteerView.new()
	_steer_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_steer_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_steer_view)
	_build_buttons()
	_build_top_left()
	_build_settings_button()
	_build_settings_panel()
	_build_status()
	_build_message()
	_build_flash()
	_build_cover()
	settings.changed.connect(_apply_settings)
	_apply_settings()


## Updates the health bar and item slots.
func set_player_status(health_ratio: float, held_items: Array[int]) -> void:
	if _status_view.health_ratio != health_ratio or _status_view.items != held_items:
		_status_view.health_ratio = health_ratio
		_status_view.items = held_items.duplicate()
		_status_view.queue_redraw()


## Tints the whole screen briefly, for hits and wrecks.
func flash(color: Color, strength: float) -> void:
	_flash.color = Color(color.r, color.g, color.b, clampf(strength, 0.0, 0.8))


func _process(delta: float) -> void:
	if _flash.color.a > 0.0:
		_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 1.8)


func set_stats(text: String) -> void:
	_stats.text = text


func set_message(text: String) -> void:
	_message.text = text


## Black cover with a loading label; hides the effect warm-up at startup.
func set_cover(visible_now: bool) -> void:
	_cover.visible = visible_now


func is_settings_open() -> bool:
	return _panel.visible


# --- steering input -------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _panel.visible:
		return
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _steer_index == -1 and _in_steer_zone(touch.position, view_size):
			_steer_index = touch.index
			_steer_origin = touch.position
			_set_steer(0.0, true)
		elif not touch.pressed and touch.index == _steer_index:
			_steer_index = -1
			_set_steer(0.0, false)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _steer_index:
			_set_steer(_steer_from_drag(drag.position.x - _steer_origin.x), true)


func _in_steer_zone(position: Vector2, view_size: Vector2) -> bool:
	var on_side: bool = position.x > view_size.x * 0.5 if settings.mirror_layout else position.x < view_size.x * 0.5
	return on_side and position.y > view_size.y * 0.3


## Drag distance in screen units to a -1..1 steering value, after sensitivity and dead zone.
func _steer_from_drag(distance: float) -> float:
	var reach: float = _steer_reach()
	var raw: float = clampf(distance / reach, -1.0, 1.0)
	var dead: float = settings.steer_deadzone
	if absf(raw) <= dead:
		return 0.0
	return signf(raw) * (absf(raw) - dead) / (1.0 - dead)


func _steer_reach() -> float:
	return BASE_STEER_RANGE / settings.steer_sensitivity


func _set_steer(value: float, active: bool) -> void:
	steer_input = value
	_steer_view.active = active
	_steer_view.origin = _steer_origin
	_steer_view.value = value
	_steer_view.reach = _steer_reach()
	_steer_view.queue_redraw()


# --- building the UI ------------------------------------------------------------

func _build_buttons() -> void:
	_button_holder = Control.new()
	_button_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_button_holder)
	var brake := _action_button("DRIFT")
	brake.button_down.connect(brake_changed.emit.bind(true))
	brake.button_up.connect(brake_changed.emit.bind(false))
	var use := _action_button("USE")
	use.button_down.connect(use_pressed.emit)
	# Order matches BUTTON_RECTS: DRIFT is the big one, USE sits beside it.
	_action_buttons = [brake, use]


func _action_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 26)
	_button_holder.add_child(button)
	return button


func _build_top_left() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16, 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.add_theme_color_override("font_outline_color", Color.BLACK)
	_stats.add_theme_constant_override("outline_size", 6)
	box.add_child(_stats)
	var row := HBoxContainer.new()
	box.add_child(row)
	row.add_child(_toggle("Shadows", shadows_toggled))
	row.add_child(_toggle("Glow", glow_toggled))
	row.add_child(_toggle("Particles", particles_toggled))
	var scale_button := _plain_button("Scale 100%")
	scale_button.pressed.connect(_cycle_scale.bind(scale_button))
	row.add_child(scale_button)
	var car_button := _plain_button("Car")
	car_button.pressed.connect(car_cycle_pressed.emit)
	row.add_child(car_button)
	var item_button := _plain_button("+Item")
	item_button.pressed.connect(give_item_pressed.emit)
	row.add_child(item_button)
	var restart := _plain_button("Restart")
	restart.pressed.connect(restart_pressed.emit)
	row.add_child(restart)


func _build_settings_button() -> void:
	var button := _plain_button("Settings")
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -170.0
	button.offset_right = -SCREEN_MARGIN
	button.offset_top = 12.0
	button.offset_bottom = 64.0
	button.pressed.connect(_open_settings.bind(true))
	add_child(button)


func _build_settings_panel() -> void:
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(820, 0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.04, 0.09, 0.97)
	background.border_color = Color(0.55, 0.35, 0.75)
	background.set_border_width_all(2)
	background.set_corner_radius_all(14)
	_panel.add_theme_stylebox_override("panel", background)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	box.add_child(_slider_row("steer_sensitivity", "Steering sensitivity", "%.2fx"))
	box.add_child(_slider_row("steer_deadzone", "Steering dead zone", "%d%%", 100.0))
	box.add_child(_slider_row("button_scale", "Button size", "%d%%", 100.0))
	box.add_child(_slider_row("button_opacity", "Button opacity", "%d%%", 100.0))
	box.add_child(_slider_row("camera_distance", "Camera distance", "%.1f m"))
	_mirror_check = CheckButton.new()
	_mirror_check.text = "Swap sides (steer on the right, buttons on the left)"
	_mirror_check.add_theme_font_size_override("font_size", 22)
	_mirror_check.focus_mode = Control.FOCUS_NONE
	_mirror_check.toggled.connect(func(on: bool) -> void: settings.set_value("mirror_layout", on))
	box.add_child(_mirror_check)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var reset := _plain_button("Reset to defaults")
	reset.pressed.connect(func() -> void: settings.reset())
	row.add_child(reset)
	var close := _plain_button("Done")
	close.custom_minimum_size = Vector2(160, 52)
	close.pressed.connect(_open_settings.bind(false))
	row.add_child(close)
	box.add_child(row)
	add_child(_panel)


func _slider_row(key: String, label_text: String, value_format: String, display_scale: float = 1.0) -> HBoxContainer:
	var limits: Vector2 = Settings.LIMITS[key]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(270, 0)
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = limits.x
	slider.max_value = limits.y
	slider.step = (limits.y - limits.x) / 100.0
	slider.custom_minimum_size = Vector2(340, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(90, 0)
	readout.add_theme_font_size_override("font_size", 22)
	row.add_child(readout)
	slider.value_changed.connect(func(value: float) -> void: settings.set_value(key, value))
	_slider_rows[key] = {"slider": slider, "readout": readout, "format": value_format, "scale": display_scale}
	return row


func _build_status() -> void:
	_status_view = StatusView.new()
	_status_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_view)


func _build_flash() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _build_message() -> void:
	_message = Label.new()
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.position = Vector2(-300, 150)
	_message.size = Vector2(600, 100)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 72)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 10)
	add_child(_message)


func _build_cover() -> void:
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = "LOADING"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	_cover.add_child(label)
	add_child(_cover)


func _toggle(label: String, target: Signal) -> Button:
	var button := _plain_button(label)
	button.toggle_mode = true
	button.button_pressed = true
	button.toggled.connect(func(on: bool) -> void: target.emit(on))
	return button


func _plain_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 20)
	return button


func _cycle_scale(button: Button) -> void:
	_scale_step = (_scale_step + 1) % RENDER_SCALES.size()
	var value: float = RENDER_SCALES[_scale_step]
	button.text = "Scale %d%%" % roundi(value * 100.0)
	render_scale_changed.emit(value)


# --- applying settings ----------------------------------------------------------

func _open_settings(open: bool) -> void:
	_panel.visible = open
	_stats.visible = not open
	_message.visible = not open
	if open:
		_steer_index = -1
		_set_steer(0.0, false)
		brake_changed.emit(false)
	settings_opened.emit(open)


## Pushes the current settings into every control that shows or uses them.
func _apply_settings() -> void:
	for key in _slider_rows:
		var row: Dictionary = _slider_rows[key]
		var slider: HSlider = row["slider"]
		var value: float = settings.get(key)
		if not is_equal_approx(slider.value, value):
			slider.set_value_no_signal(value)
		(row["readout"] as Label).text = (row["format"] as String) % (value * float(row["scale"]))
	if _mirror_check.button_pressed != settings.mirror_layout:
		_mirror_check.set_pressed_no_signal(settings.mirror_layout)
	_layout_buttons()


## Places the buttons in the bottom corner chosen by the layout setting, scaled about that corner.
func _layout_buttons() -> void:
	var mirrored: bool = settings.mirror_layout
	# Rects are for the right-hand layout; mirrored ones are flipped inside the holder.
	var rects: Array[Rect2] = [Rect2(230, 150, 140, 140), Rect2(110, 150, 110, 140)]
	for i in _action_buttons.size():
		var rect: Rect2 = rects[i]
		if mirrored:
			rect.position.x = BUTTON_AREA.x - rect.position.x - rect.size.x
		_action_buttons[i].position = rect.position
		_action_buttons[i].size = rect.size
	_button_holder.anchor_top = 1.0
	_button_holder.anchor_bottom = 1.0
	_button_holder.anchor_left = 0.0 if mirrored else 1.0
	_button_holder.anchor_right = 0.0 if mirrored else 1.0
	if mirrored:
		_button_holder.offset_left = SCREEN_MARGIN
		_button_holder.offset_right = SCREEN_MARGIN + BUTTON_AREA.x
		_button_holder.pivot_offset = Vector2(0.0, BUTTON_AREA.y)
	else:
		_button_holder.offset_left = -SCREEN_MARGIN - BUTTON_AREA.x
		_button_holder.offset_right = -SCREEN_MARGIN
		_button_holder.pivot_offset = Vector2(BUTTON_AREA.x, BUTTON_AREA.y)
	_button_holder.offset_top = -SCREEN_MARGIN - BUTTON_AREA.y
	_button_holder.offset_bottom = -SCREEN_MARGIN
	_button_holder.scale = Vector2.ONE * settings.button_scale
	_button_holder.modulate.a = settings.button_opacity
