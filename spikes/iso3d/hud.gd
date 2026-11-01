extends CanvasLayer
## Touch HUD: virtual stick (left), skill buttons (right), debug toggles and stats (top-left).

signal skill_pressed(index: int)
signal shadows_toggled(enabled: bool)
signal particles_toggled(enabled: bool)
signal render_scale_changed(value: float)
signal enemies_added(count: int)

const STICK_RADIUS: float = 90.0
const SKILL_NAMES: Array[String] = ["SLASH", "NOVA", "FIRE", "STORM"]
const RENDER_SCALES: Array[float] = [1.0, 0.75, 0.5]

var move_vector: Vector2 = Vector2.ZERO

var _stick_index: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_view: StickView
var _stats: Label
var _scale_step: int = 0


class StickView extends Control:
	var active: bool = false
	var origin: Vector2 = Vector2.ZERO
	var vector: Vector2 = Vector2.ZERO

	func _draw() -> void:
		if not active:
			return
		draw_circle(origin, 90.0, Color(1, 1, 1, 0.10))
		draw_arc(origin, 90.0, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(origin + vector * 90.0, 36.0, Color(1, 1, 1, 0.35))


func _ready() -> void:
	_stick_view = StickView.new()
	_stick_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stick_view)
	_build_skill_buttons()
	_build_debug_panel()


func set_stats(text: String) -> void:
	_stats.text = text


func _input(event: InputEvent) -> void:
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _stick_index == -1 \
				and touch.position.x < view_size.x * 0.45 and touch.position.y > view_size.y * 0.3:
			_stick_index = touch.index
			_stick_origin = touch.position
			_update_stick(Vector2.ZERO, true)
		elif not touch.pressed and touch.index == _stick_index:
			_stick_index = -1
			move_vector = Vector2.ZERO
			_update_stick(Vector2.ZERO, false)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_index:
			move_vector = ((drag.position - _stick_origin) / STICK_RADIUS).limit_length(1.0)
			_update_stick(move_vector, true)


func _update_stick(vector: Vector2, active: bool) -> void:
	_stick_view.active = active
	_stick_view.origin = _stick_origin
	_stick_view.vector = vector
	_stick_view.queue_redraw()


func _build_skill_buttons() -> void:
	var holder := Control.new()
	holder.anchor_left = 1.0
	holder.anchor_top = 1.0
	holder.anchor_right = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = -380.0
	holder.offset_top = -300.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	# Slash is the big primary button; the three skills arc around it.
	var layout: Array[Rect2] = [
		Rect2(230, 150, 140, 140),
		Rect2(110, 190, 100, 100),
		Rect2(140, 70, 100, 100),
		Rect2(250, 20, 100, 100),
	]
	for i in SKILL_NAMES.size():
		var button := Button.new()
		button.text = SKILL_NAMES[i]
		button.focus_mode = Control.FOCUS_NONE
		button.position = layout[i].position
		button.size = layout[i].size
		button.add_theme_font_size_override("font_size", 22)
		button.button_down.connect(skill_pressed.emit.bind(i))
		holder.add_child(button)


func _build_debug_panel() -> void:
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
	row.add_child(_toggle("Shadows", true, shadows_toggled))
	row.add_child(_toggle("Particles", true, particles_toggled))
	var scale_button := _plain_button("Scale 100%")
	scale_button.pressed.connect(_cycle_scale.bind(scale_button))
	row.add_child(scale_button)
	var add_button := _plain_button("+20 enemies")
	add_button.pressed.connect(enemies_added.emit.bind(20))
	row.add_child(add_button)


func _toggle(label: String, initial: bool, target: Signal) -> Button:
	var button := _plain_button(label)
	button.toggle_mode = true
	button.button_pressed = initial
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
