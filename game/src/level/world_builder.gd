class_name WorldBuilder
extends RefCounted

## Builds level geometry from tile-space rectangles.
##
## Exists because the resolution rule was only half honoured. Gameplay code
## was clean -- every speed and hitbox went through GameConfig -- but the
## world itself was hand-placed pixels in .tscn files. Raising TILE_SIZE
## would have scaled the player, the enemies, every hitbox, the jump height
## and the roll distance while the floor stayed 32px thick and the platforms
## stayed where they were. The player would no longer have fit between the
## floor and the first platform.
##
## So the documented upgrade path -- "change TILE_SIZE and the viewport" --
## only works if the world is derived too. Everything here takes Rect2 in
## TILES and converts once.


## Adds a solid rectangle: a collision shape on `body` plus a matching
## ColorRect on `visuals`, both sized and placed from tile space.
static func add_solid(
	body: StaticBody2D, visuals: Node2D, rect_tiles: Rect2, colour: Color
) -> void:
	var size_px := GameConfig.tiles_v(rect_tiles.size.x, rect_tiles.size.y)
	var origin_px := GameConfig.tiles_v(rect_tiles.position.x, rect_tiles.position.y)

	var shape := RectangleShape2D.new()
	shape.size = size_px
	var collider := CollisionShape2D.new()
	collider.shape = shape
	# Collision shapes are centred; ColorRects are corner-anchored.
	collider.position = origin_px + size_px * 0.5
	body.add_child(collider)

	var rect := ColorRect.new()
	rect.position = origin_px
	rect.size = size_px
	rect.color = colour
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visuals.add_child(rect)
