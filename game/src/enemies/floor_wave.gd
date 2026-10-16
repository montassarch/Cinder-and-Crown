class_name FloorWave
extends Area2D
## The slam's shockwave: a thin strip racing along the floor. It hurts a hero standing on the
## floor (through take_hit, so it cannot be parried) and passes harmlessly under one who is in
## the air. Hurts once per wave, then travels on until its range runs out.
## Physics layers: 4 hero hurtbox (8).

const HERO_HURTBOX_MASK: int = 8
const STRIP_SIZE := Vector2(10.0, 6.0)
const COLOR := Color(1.0, 0.55, 0.1, 0.85)

var damage: int = 0

var _direction: float = 1.0
var _speed: float = 0.0
var _range: float = 0.0
var _travelled: float = 0.0
var _spent: bool = false


func _init() -> void:
	collision_layer = 0
	collision_mask = HERO_HURTBOX_MASK
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = STRIP_SIZE
	shape.shape = rect
	add_child(shape)
	area_entered.connect(_on_area_entered)


## Place the wave on the floor first; direction is +1 right, -1 left. Distances in pixels.
func launch(direction: float, speed_px: float, range_px: float, hit_damage: int) -> void:
	_direction = signf(direction) if direction != 0.0 else 1.0
	_speed = speed_px
	_range = range_px
	damage = hit_damage
	queue_redraw()


func _physics_process(delta: float) -> void:
	var step := _speed * delta
	global_position.x += _direction * step
	_travelled += step
	if _travelled >= _range:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _spent:
		return
	var target := area.get_parent()
	if target != null and target.has_method("take_hit"):
		_spent = true
		target.take_hit(damage, global_position.x - _direction * STRIP_SIZE.x)


func _draw() -> void:
	draw_rect(Rect2(-STRIP_SIZE / 2.0, STRIP_SIZE), COLOR)
