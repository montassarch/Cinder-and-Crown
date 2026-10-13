extends Node2D

## Draws hitboxes and hurtboxes on demand.
##
## Tuning reach and timing by feel alone is guesswork: you cannot tell a
## hitbox that is too short from a hit window that opens too late. This
## makes both visible.

const HITBOX_COLOUR := Color(1.0, 0.3, 0.2, 0.45)
const HURTBOX_COLOUR := Color(0.3, 0.7, 1.0, 0.30)
const IFRAME_COLOUR := Color(1.0, 0.95, 0.4, 0.55)

@onready var _sandbox: Node2D = get_parent() as Node2D


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var player: Player = _sandbox.player
	if player == null:
		return

	# The player's hurtbox, tinted differently while the roll's i-frames
	# are open -- so "was I actually invincible there?" is answerable.
	_draw_area(
		player.get_node_or_null("Hurtbox") as Area2D,
		IFRAME_COLOUR if player.is_invincible() else HURTBOX_COLOUR
	)

	# The weapon hitbox, only while it can actually deal damage.
	if player.weapon != null and player.weapon.is_hitbox_active():
		_draw_area(player.weapon.get_node_or_null("Hitbox") as Area2D, HITBOX_COLOUR)

	for child: Node in (_sandbox.get_node("%Enemies") as Node).get_children():
		if child is Enemy:
			_draw_area(child.get_node_or_null("Hurtbox") as Area2D, HURTBOX_COLOUR)


func _draw_area(area: Area2D, colour: Color) -> void:
	if area == null:
		return
	for child: Node in area.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null:
			continue
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape == null:
			continue
		var centre := area.global_position + shape_node.position - global_position
		draw_rect(
			Rect2(centre - rect_shape.size * 0.5, rect_shape.size),
			colour,
			true
		)
