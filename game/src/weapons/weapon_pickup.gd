class_name WeaponPickup
extends Area2D
## A weapon lying on the floor (a beaten boss drops one). Walking into it puts it in the hero's hand and leaves his old
## weapon lying here instead; it will not swap again until he has stepped off it. It glows and bobs so it is seen.
## Physics: it watches the hero's body (layer 2).

const ICON_DIR := "res://art/weapon_icons"
const HERO_BODY_MASK: int = 2
const SIZE := Vector2(20.0, 26.0)
const BOB_PIXELS: float = 2.0
const BOB_HZ: float = 1.2
const GLOW := Color(1.0, 0.82, 0.4)

var _weapon: WeaponData
var _icon: Sprite2D
var _armed: bool = true
var _age: float = 0.0


static func spawn(parent: Node, data: WeaponData, at: Vector2) -> WeaponPickup:
	var p := WeaponPickup.new()
	parent.add_child(p)
	p.global_position = at
	p.set_weapon(data)
	return p


func _init() -> void:
	collision_layer = 0
	collision_mask = HERO_BODY_MASK
	monitorable = false
	z_index = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE
	shape.shape = rect
	add_child(shape)
	_icon = Sprite2D.new()
	_icon.name = "Icon"
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_icon)
	body_entered.connect(_on_body_entered)
	body_exited.connect(func(body: Node) -> void:
		if body is Player:
			_armed = true)


func set_weapon(data: WeaponData) -> void:
	_weapon = data
	_icon.texture = load("%s/%s.png" % [ICON_DIR, data.icon]) as Texture2D
	queue_redraw()


func weapon() -> WeaponData:
	return _weapon


func _physics_process(delta: float) -> void:
	_age += delta
	_icon.position.y = -6.0 + sin(_age * TAU * BOB_HZ) * BOB_PIXELS
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if not (body is Player) or not _armed or _weapon == null:
		return
	var hero := body as Player
	var slot := hero.active_slot()
	var old := hero.weapon_in_slot(slot)
	hero.set_weapon(slot, _weapon)
	hero.weapon_swapped.emit()
	_armed = false
	if old == null:
		queue_free()
	else:
		set_weapon(old)


func _draw() -> void:
	# a soft pulsing glow under the weapon and a ring of light on the floor
	var pulse := 0.5 + 0.5 * sin(_age * TAU * 0.8)
	draw_circle(Vector2(0, -6), 12.0, Color(GLOW, 0.12 + 0.08 * pulse))
	draw_circle(Vector2(0, -6), 7.0, Color(GLOW, 0.14 + 0.1 * pulse))
	draw_arc(Vector2(0, 10), 10.0, PI, TAU, 16, Color(GLOW, 0.5), 1.0)
