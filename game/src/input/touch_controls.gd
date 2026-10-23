class_name TouchControls
extends CanvasLayer
## Wild Rift style touch controls, drawn as crisp vectors.
## Left: a floating stick that appears under the left thumb, ring and knob. Right: one big Attack button in the
## corner with the other seven fanned round it on two arcs (Roll, Parry, Jump close in; Storm, Rend, Flask, Swap
## further out), each with an icon instead of a word. Abilities dim and show a recharge sweep while the mana is
## short, the flask dims when empty and wears a charge badge, and a pressed button shrinks a little.
## Positions are authored on the 384x216 base screen; on a wider or taller screen the stick keeps its distance to the
## left and bottom edges, the buttons to the right and bottom edges.
## Talks to the game only through InputRouter.set_virtual_*; it never marks events handled, so keyboard and gamepad
## keep working while it is shown. It reads the player only to dim buttons (bind).

const STICK_CENTER_TILES := Vector2(3.5, 10.0)
const STICK_RADIUS_TILES: float = 2.5
## The stick may appear anywhere in the left part of the screen below the HUD.
const STICK_ZONE_RIGHT_EDGE_TILES: float = 10.0
const STICK_ZONE_TOP_TILES: float = 4.5
const STICK_EDGE_MARGIN_TILES: float = 0.4
const STICK_DEADZONE: float = 0.25

## The attack button sits in the corner; the others are fanned round it on two arcs of this radius (tiles).
const ATTACK_CENTER_TILES := Vector2(21.3, 10.5)
const INNER_ARC_TILES: float = 3.9
const OUTER_ARC_TILES: float = 6.6
const BUTTON_CENTERS_TILES := {
	&"attack": Vector2(21.3, 10.5),
	&"roll": Vector2(17.4, 10.5),
	&"parry": Vector2(18.54, 7.74),
	&"jump": Vector2(21.3, 6.6),
	&"skill1": Vector2(14.7, 10.62),
	&"skill2": Vector2(15.22, 7.92),
	&"flask": Vector2(16.8, 5.67),
	&"swap_weapon": Vector2(19.15, 4.26),
}
const BUTTON_RADII_TILES := {
	&"attack": 2.0, &"roll": 1.3, &"parry": 1.3, &"jump": 1.3,
	&"skill1": 1.1, &"skill2": 1.1, &"flask": 1.1, &"swap_weapon": 0.95,
}
const PRESSED_SCALE: float = 0.9
const FILL_STEPS: float = 50.0

const GOLD := Color(0.88, 0.74, 0.4)
const GOLD_DARK := Color(0.4, 0.3, 0.12)
const BODY := Color(0.05, 0.05, 0.09)
const ICON := Color(0.95, 0.92, 0.85)
const STORM_BLUE := Color(0.55, 0.82, 1.0)
const REND_RED := Color(1.0, 0.4, 0.34)
const FLASK_RED := Color(0.9, 0.2, 0.25)

## Show even without a touchscreen (desktop testing).
@export var force_visible: bool = false

## How many times the overlay has been drawn (tests check it only redraws when something changed).
var redraw_count: int = 0

var _stick_finger: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_pos: Vector2 = Vector2.ZERO
var _button_fingers: Dictionary = {}
var _stick_value: float = 0.0
var _player: Player
var _enabled: Dictionary = {}
var _fill: Dictionary = {}
var _badge: int = -1

@onready var _overlay: Control = $Overlay


func _ready() -> void:
	visible = force_visible or DisplayServer.is_touchscreen_available()
	_overlay.draw.connect(_draw_overlay)
	get_viewport().size_changed.connect(_overlay.queue_redraw)
	_overlay.queue_redraw()


## Lets the buttons dim with the player's mana and flask.
func bind(player: Player) -> void:
	_player = player
	_refresh_states()
	_overlay.queue_redraw()


func _process(_delta: float) -> void:
	if _player != null and _refresh_states():
		_overlay.queue_redraw()


func button_center(action: StringName, view: Vector2) -> Vector2:
	var base := GameConfig.tiles_v(BUTTON_CENTERS_TILES[action].x, BUTTON_CENTERS_TILES[action].y)
	return Vector2(view.x - (GameConfig.BASE_WIDTH - base.x), view.y - (GameConfig.BASE_HEIGHT - base.y))


## Where the stick rests when nobody is touching it (and where its faint ring is drawn).
func stick_center(view: Vector2) -> Vector2:
	var base := GameConfig.tiles_v(STICK_CENTER_TILES.x, STICK_CENTER_TILES.y)
	return Vector2(base.x, view.y - (GameConfig.BASE_HEIGHT - base.y))


## Where the stick is now: under the thumb while held, else at rest.
func stick_origin() -> Vector2:
	return _stick_origin if _stick_finger != -1 else stick_center(_view_size())


func button_enabled(action: StringName) -> bool:
	return _enabled.get(action, true)


## 1 when the button is ready; below 1 while the mana for an ability is still short (the recharge sweep).
func button_fill(action: StringName) -> float:
	return _fill.get(action, 1.0)


func button_scale(action: StringName) -> float:
	return PRESSED_SCALE if _button_fingers.values().has(action) else 1.0


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
	var view := _view_size()
	for action in BUTTON_CENTERS_TILES:
		var center := button_center(action, view)
		if pos.distance_to(center) <= GameConfig.tiles(BUTTON_RADII_TILES[action]):
			_button_fingers[finger] = action
			InputRouter.set_virtual_button(action, true)
			_overlay.queue_redraw()
			return
	var zone_top := view.y - (GameConfig.BASE_HEIGHT - GameConfig.tiles(STICK_ZONE_TOP_TILES))
	if _stick_finger == -1 and pos.x <= GameConfig.tiles(STICK_ZONE_RIGHT_EDGE_TILES) and pos.y >= zone_top:
		_stick_finger = finger
		_stick_origin = _keep_ring_on_screen(pos, view)
		_update_stick(pos)


## The ring appears under the thumb, nudged in just enough to stay on screen.
func _keep_ring_on_screen(pos: Vector2, view: Vector2) -> Vector2:
	var reach := GameConfig.tiles(STICK_RADIUS_TILES + STICK_EDGE_MARGIN_TILES)
	var zone_top := view.y - (GameConfig.BASE_HEIGHT - GameConfig.tiles(STICK_ZONE_TOP_TILES))
	return Vector2(
		clampf(pos.x, reach, GameConfig.tiles(STICK_ZONE_RIGHT_EDGE_TILES)),
		clampf(pos.y, zone_top + reach * 0.5, view.y - reach))


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
	_stick_pos = pos
	var raw := (pos.x - _stick_origin.x) / GameConfig.tiles(STICK_RADIUS_TILES)
	_stick_value = clampf(raw, -1.0, 1.0)
	InputRouter.set_virtual_axis(0.0 if absf(_stick_value) < STICK_DEADZONE else _stick_value)
	_overlay.queue_redraw()


## Re-reads what the player can afford. Returns true when anything the buttons show has changed.
func _refresh_states() -> bool:
	var changed := false
	var mana := _player.mana()
	for pair in [[&"skill1", Player.STORM_COST], [&"skill2", Player.REND_COST]]:
		var cost: float = pair[1]
		var fill := snappedf(clampf(mana.current / cost, 0.0, 1.0), 1.0 / FILL_STEPS)
		var usable := mana.can_afford(cost)
		if fill != _fill.get(pair[0], -1.0) or usable != _enabled.get(pair[0], null):
			changed = true
		_fill[pair[0]] = fill
		_enabled[pair[0]] = usable
	var charges := _player.flask_charges()
	var has_charge := charges > 0
	if has_charge != _enabled.get(&"flask", null) or charges != _badge:
		changed = true
	_enabled[&"flask"] = has_charge
	_badge = charges
	return changed


# ---------------------------------------------------------------- drawing

func _draw_overlay() -> void:
	redraw_count += 1
	var view := _view_size()
	_draw_stick()
	for action in BUTTON_CENTERS_TILES:
		_draw_button(action, button_center(action, view))


func _draw_stick() -> void:
	var held := _stick_finger != -1
	var origin := stick_origin()
	var radius := GameConfig.tiles(STICK_RADIUS_TILES)
	var fade := 0.9 if held else 0.45
	_overlay.draw_circle(origin + Vector2(0.0, 1.5), radius, Color(0.0, 0.0, 0.0, 0.25 * fade))
	_overlay.draw_circle(origin, radius, Color(BODY, 0.5 * fade))
	_overlay.draw_arc(origin, radius - 1.0, 0.0, TAU, 56, Color(GOLD, 0.85 * fade), 1.6, true)
	_overlay.draw_arc(origin, radius * 0.62, 0.0, TAU, 40, Color(GOLD, 0.25 * fade), 1.0, true)
	for side in [-1.0, 1.0]:                      # direction chevrons on the ring
		var tip := origin + Vector2(side * radius * 0.8, 0.0)
		var back := Vector2(-side * radius * 0.1, radius * 0.1)
		_overlay.draw_polyline(PackedVector2Array([tip + back, tip, tip + Vector2(back.x, -back.y)]), Color(GOLD, 0.6 * fade), 1.4, true)
	var offset := Vector2.ZERO
	if held:
		offset = (_stick_pos - _stick_origin).limit_length(radius)
	var knob := origin + offset
	var knob_radius := radius * 0.42
	_overlay.draw_circle(knob + Vector2(0.0, 1.5), knob_radius, Color(0.0, 0.0, 0.0, 0.3))
	_overlay.draw_circle(knob, knob_radius, Color(0.12, 0.11, 0.16, 0.95 if held else 0.6))
	_overlay.draw_arc(knob, knob_radius - 0.8, 0.0, TAU, 32, Color(GOLD, 1.0 if held else 0.6), 1.6, true)
	_overlay.draw_circle(knob, knob_radius * 0.35, Color(GOLD, 0.35 if held else 0.18))


func _draw_button(action: StringName, centre: Vector2) -> void:
	var radius := GameConfig.tiles(BUTTON_RADII_TILES[action]) * button_scale(action)
	var pressed := button_scale(action) < 1.0
	var usable := button_enabled(action)
	var overall := 0.95 if pressed else 0.82
	_overlay.draw_circle(centre + Vector2(0.0, 1.8), radius, Color(0.0, 0.0, 0.0, 0.35))
	_overlay.draw_circle(centre, radius, Color(BODY, 0.8 if not pressed else 0.92))
	_overlay.draw_arc(centre, radius * 0.84, deg_to_rad(200.0), deg_to_rad(290.0), 16, Color(1, 1, 1, 0.14), 2.0, true)
	_draw_icon(action, centre, radius * (1.0 if usable else 0.9), overall if usable else overall * 0.5)
	if not usable or button_fill(action) < 1.0:
		var sweep := TAU * (1.0 - button_fill(action))
		if sweep > 0.0:
			var pie := PackedVector2Array([centre])
			for i in 33:
				pie.append(centre + Vector2.from_angle(-PI / 2.0 + sweep * float(i) / 32.0) * (radius - 1.0))
			_overlay.draw_colored_polygon(pie, Color(0.0, 0.0, 0.0, 0.62))
		elif not usable:
			_overlay.draw_circle(centre, radius - 1.0, Color(0.0, 0.0, 0.0, 0.5))
	var rim := GOLD if usable else GOLD_DARK
	_overlay.draw_arc(centre, radius - 0.8, 0.0, TAU, 48, Color(rim, 1.0 if pressed else 0.9), 1.8 if pressed else 1.5, true)
	_overlay.draw_arc(centre, radius - 2.4, 0.0, TAU, 48, Color(GOLD_DARK, 0.7), 0.8, true)
	if action == &"flask" and _badge >= 0:
		var at := centre + Vector2(radius * 0.62, radius * 0.62)
		_overlay.draw_circle(at, GameConfig.tiles(0.5), Color(0.08, 0.08, 0.12, 0.95))
		_overlay.draw_arc(at, GameConfig.tiles(0.5) - 0.5, 0.0, TAU, 20, GOLD, 1.0, true)
		var text := str(_badge)
		_overlay.draw_string(ThemeDB.fallback_font, at + Vector2(-GameConfig.tiles(0.5), GameConfig.UI_FONT_SIZE / 3.0), text, HORIZONTAL_ALIGNMENT_CENTER, GameConfig.tiles(1.0), GameConfig.UI_FONT_SIZE, ICON)


## Each button's picture, drawn from simple shapes (crisp at any screen size).
func _draw_icon(action: StringName, centre: Vector2, radius: float, alpha: float) -> void:
	var s := radius * 0.62
	var ink := Color(ICON, alpha)
	match action:
		&"attack":
			_overlay.draw_set_transform(centre, deg_to_rad(35.0), Vector2.ONE * s)
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(0, -1.05), Vector2(0.15, -0.82), Vector2(0.15, 0.15), Vector2(-0.15, 0.15), Vector2(-0.15, -0.82)]), ink)
			_overlay.draw_rect(Rect2(-0.45, 0.15, 0.9, 0.13), Color(GOLD, alpha))
			_overlay.draw_rect(Rect2(-0.07, 0.28, 0.14, 0.42), Color(ink, alpha * 0.8))
			_overlay.draw_circle(Vector2(0, 0.78), 0.1, Color(GOLD, alpha))
		&"jump":
			_overlay.draw_set_transform(centre, 0.0, Vector2.ONE * s)
			for k in 2:
				var y := 0.32 - 0.5 * k
				_overlay.draw_polyline(PackedVector2Array([Vector2(-0.6, y + 0.3), Vector2(0, y - 0.3), Vector2(0.6, y + 0.3)]), Color(ink, alpha * (1.0 - 0.35 * k)), 0.2, true)
		&"roll":
			_overlay.draw_set_transform(centre, 0.0, Vector2.ONE)
			_overlay.draw_arc(Vector2.ZERO, s * 0.62, deg_to_rad(40.0), deg_to_rad(310.0), 28, ink, maxf(radius * 0.14, 1.5), true)
			var end := Vector2.from_angle(deg_to_rad(310.0)) * s * 0.62
			_overlay.draw_colored_polygon(PackedVector2Array([end + Vector2(-0.34, -0.5) * s, end + Vector2(0.45, -0.05) * s, end + Vector2(-0.4, 0.38) * s]), ink)
		&"parry":
			_overlay.draw_set_transform(centre, 0.0, Vector2.ONE * s)
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(-0.62, -0.7), Vector2(0.62, -0.7), Vector2(0.62, 0.05), Vector2(0, 0.85), Vector2(-0.62, 0.05)]), ink)
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(-0.4, -0.5), Vector2(0.4, -0.5), Vector2(0.4, -0.02), Vector2(0, 0.55), Vector2(-0.4, -0.02)]), Color(BODY, alpha * 0.85))
			_overlay.draw_rect(Rect2(-0.07, -0.42, 0.14, 0.8), Color(GOLD, alpha))
		&"skill1":
			_overlay.draw_set_transform(centre, 0.0, Vector2.ONE * s)
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(0.22, -0.95), Vector2(-0.5, 0.12), Vector2(-0.06, 0.12), Vector2(-0.25, 0.95), Vector2(0.55, -0.25), Vector2(0.08, -0.25)]), Color(STORM_BLUE, alpha))
		&"skill2":
			_overlay.draw_set_transform(centre, 0.0, Vector2.ONE * s)
			var pts := PackedVector2Array([Vector2(-0.9, 0.45), Vector2(-0.5, 0.15), Vector2(-0.3, 0.5), Vector2(0.05, 0.05), Vector2(0.3, 0.45), Vector2(0.9, 0.12)])
			_overlay.draw_polyline(pts, Color(REND_RED, alpha), 0.22, true)
			_overlay.draw_polyline(PackedVector2Array([Vector2(0.05, 0.05), Vector2(0.2, -0.45), Vector2(0.08, -0.9)]), Color(REND_RED, alpha), 0.18, true)
			_overlay.draw_polyline(PackedVector2Array([Vector2(-0.5, 0.15), Vector2(-0.42, -0.35)]), Color(REND_RED, alpha * 0.8), 0.16, true)
		&"flask":
			_overlay.draw_set_transform(centre, 0.0, Vector2.ONE * s)
			_overlay.draw_rect(Rect2(-0.17, -0.85, 0.34, 0.45), Color(ink, alpha * 0.9))
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(-0.17, -0.4), Vector2(0.17, -0.4), Vector2(0.62, 0.6), Vector2(-0.62, 0.6)]), Color(ink, alpha * 0.9))
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(-0.4, 0.05), Vector2(0.4, 0.05), Vector2(0.56, 0.5), Vector2(-0.56, 0.5)]), Color(FLASK_RED, alpha))
		&"swap_weapon":
			_overlay.draw_set_transform(centre, 0.0, Vector2.ONE * s)
			_overlay.draw_polyline(PackedVector2Array([Vector2(-0.7, -0.3), Vector2(0.7, -0.3), Vector2(0.4, -0.62)]), ink, 0.2, true)
			_overlay.draw_polyline(PackedVector2Array([Vector2(0.7, 0.3), Vector2(-0.7, 0.3), Vector2(-0.4, 0.62)]), ink, 0.2, true)
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size
