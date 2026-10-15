extends Node2D
## Minimal stand-in for an enemy: an enemy-hurtbox Area2D plus take_hit().

var hits: Array = []
var stuns: Array = []

func _init() -> void:
	var area := Area2D.new()
	area.collision_layer = 16
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16.0, 16.0)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)

func hurtbox() -> Area2D:
	return get_child(0)

func take_hit(damage: int, source_x: float, knockback_tiles: float = 0.0) -> void:
	hits.append([damage, source_x, knockback_tiles])

func stun(seconds: float) -> void:
	stuns.append(seconds)
