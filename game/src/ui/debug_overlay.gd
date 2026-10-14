class_name DebugOverlay
extends Node2D
## Draws bodies, hurtboxes and any live weapon hitbox so reach and timing can be judged.

const BODY_COLOR := Color(0.3, 0.5, 1.0, 0.35)
const HURTBOX_COLOR := Color(0.2, 1.0, 0.3, 0.35)
const HITBOX_COLOR := Color(1.0, 0.2, 0.2, 0.5)

var enabled: bool = false:
	set(value):
		enabled = value
		visible = value
		queue_redraw()


func _ready() -> void:
	visible = enabled


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	for group in [&"player", &"enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			_draw_shapes(node)


func _draw_shapes(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D and not child.disabled and child.shape is RectangleShape2D:
			var size: Vector2 = child.shape.size
			var color := HURTBOX_COLOR if child.get_parent() is Area2D else BODY_COLOR
			draw_rect(Rect2(child.global_position - size / 2.0, size), color)
		elif child is Weapon and child.is_hitbox_active():
			draw_rect(child.hitbox_global_rect(), HITBOX_COLOR)
		_draw_shapes(child)
