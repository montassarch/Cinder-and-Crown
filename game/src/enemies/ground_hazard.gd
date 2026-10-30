class_name GroundHazard
extends Node2D
## A spot on the floor a boss has marked: first a glowing warning, then a painted effect (fire pillar, falling ice
## sword, lightning...) that hurts the hero if he is still standing in it. It hits once, cannot be parried (roll out
## of it or jump clear), and clears itself away when its picture has played out.

const WARN_COLOR := Color(1.0, 0.3, 0.12)
const FPS: float = 14.0

var damage: int = 0
var _art: StringName
var _half_width: float = 0.0
var _height: float = 0.0
var _warn_left: float = 0.0
var _active_left: float = 0.0
var _warn_total: float = 0.0
var _source_x: float = 0.0
var _target: Node2D
var _struck: bool = false
var _sprite: AnimatedSprite2D
var _done_playing: bool = false


## floor_point: where the effect stands; half_width and height: the zone that hurts, in pixels, above the floor.
static func spawn(parent: Node, art: StringName, floor_point: Vector2, half_width: float, height: float, warn_seconds: float,
		active_seconds: float, hit_damage: int, source_x: float, target: Node2D) -> GroundHazard:
	var h := GroundHazard.new()
	h._art = art
	h._half_width = half_width
	h._height = height
	h._warn_left = warn_seconds
	h._warn_total = maxf(warn_seconds, 0.001)
	h._active_left = active_seconds
	h.damage = hit_damage
	h._source_x = source_x
	h._target = target
	h.add_to_group(Enemy.ATTACK_GROUP)
	h.z_index = 15
	parent.add_child(h)
	h.global_position = floor_point
	return h


func is_warning() -> bool:
	return _warn_left > 0.0


func is_active() -> bool:
	return _warn_left <= 0.0 and _active_left > 0.0


func _physics_process(delta: float) -> void:
	if _warn_left > 0.0:
		_warn_left -= delta
		queue_redraw()
		if _warn_left <= 0.0:
			_erupt()
		return
	if _active_left > 0.0:
		_active_left -= delta
		_try_hit()
	elif _done_playing:
		queue_free()


func _erupt() -> void:
	queue_redraw()
	_sprite = PaintedFx.sprite(_art, FPS)
	add_child(_sprite)
	_sprite.animation_finished.connect(func() -> void:
		_done_playing = true
		_sprite.visible = false)
	_sprite.play(&"play")
	_try_hit()


func _try_hit() -> void:
	if _struck or not is_instance_valid(_target):
		return
	var at := _target.global_position - global_position
	if absf(at.x) <= _half_width and at.y <= 0.0 + 8.0 and at.y >= -_height:
		_struck = true
		if _target.has_method("take_hit"):
			_target.take_hit(damage, _source_x)


func _draw() -> void:
	if _warn_left <= 0.0:
		return
	var t := 1.0 - _warn_left / _warn_total
	var pulse := 0.5 + 0.5 * sin(t * TAU * 3.0)
	var colour := Color(WARN_COLOR, 0.25 + 0.45 * t + 0.15 * pulse)
	# a flat glowing ellipse on the floor and a faint column of light rising from it
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append(Vector2(cos(a) * _half_width, sin(a) * 3.0))
	draw_colored_polygon(points, colour)
	draw_rect(Rect2(-_half_width * 0.6, -_height * t, _half_width * 1.2, _height * t), Color(WARN_COLOR, 0.12 * t))
