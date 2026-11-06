extends CanvasLayer
## Touch HUD: steering drag zone (left), BRAKE/DRIFT and USE buttons (right),
## debug toggles, race stats and a centre message.

signal brake_changed(pressed: bool)
signal use_pressed
signal restart_pressed
signal shadows_toggled(enabled: bool)
signal particles_toggled(enabled: bool)
signal render_scale_changed(value: float)

const STEER_RANGE: float = 110.0
const RENDER_SCALES: Array[float] = [1.0, 0.75, 0.5]

var steer_input: float = 0.0

var _steer_index: int = -1
var _steer_origin: Vector2 = Vector2.ZERO
var _steer_view: SteerView
var _stats: Label
var _message: Label
var _scale_step: int = 0
var _cover: ColorRect


class SteerView extends Control:
	var active: bool = false
	var origin: Vector2 = Vector2.ZERO
	var value: float = 0.0

	func _draw() -> void:
		if not active:
			return
		draw_line(origin - Vector2(110, 0), origin + Vector2(110, 0), Color(1, 1, 1, 0.35), 6.0)
		draw_circle(origin + Vector2(value * 110.0, 0), 34.0, Color(1, 1, 1, 0.45))


func _ready() -> void:
	_steer_view = SteerView.new()
	_steer_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_steer_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_steer_view)
	_build_buttons()
	_build_top_left()
	_build_cover()
	_message = Label.new()
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.position = Vector2(-300, 150)
	_message.size = Vector2(600, 100)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 72)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 10)
	add_child(_message)


func set_stats(text: String) -> void:
	_stats.text = text


func set_message(text: String) -> void:
	_message.text = text


## Black cover with a loading label; hides the effect warm-up at startup.
func set_cover(visible_now: bool) -> void:
	_cover.visible = visible_now


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


func _input(event: InputEvent) -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _steer_index == -1 \
				and touch.position.x < view_size.x * 0.5 and touch.position.y > view_size.y * 0.3:
			_steer_index = touch.index
			_steer_origin = touch.position
			_set_steer(0.0, true)
		elif not touch.pressed and touch.index == _steer_index:
			_steer_index = -1
			_set_steer(0.0, false)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _steer_index:
			var value: float = clampf((drag.position.x - _steer_origin.x) / STEER_RANGE, -1.0, 1.0)
			_set_steer(0.0 if absf(value) < 0.08 else value, true)


func _set_steer(value: float, active: bool) -> void:
	steer_input = value
	_steer_view.active = active
	_steer_view.origin = _steer_origin
	_steer_view.value = value
	_steer_view.queue_redraw()


func _build_buttons() -> void:
	var holder := Control.new()
	holder.anchor_left = 1.0
	holder.anchor_top = 1.0
	holder.anchor_right = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = -380.0
	holder.offset_top = -300.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var brake := _action_button("DRIFT", Rect2(230, 150, 140, 140))
	brake.button_down.connect(brake_changed.emit.bind(true))
	brake.button_up.connect(brake_changed.emit.bind(false))
	holder.add_child(brake)
	var use := _action_button("USE", Rect2(110, 150, 110, 140))
	use.button_down.connect(use_pressed.emit)
	holder.add_child(use)


func _action_button(label: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 26)
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
	row.add_child(_toggle("Particles", particles_toggled))
	var scale_button := _plain_button("Scale 100%")
	scale_button.pressed.connect(_cycle_scale.bind(scale_button))
	row.add_child(scale_button)
	var restart := _plain_button("Restart")
	restart.pressed.connect(restart_pressed.emit)
	row.add_child(restart)


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
