class_name RoomData
extends Resource

## One room chunk, as data. A new room is a .tscn plus a .tres pointing at
## it -- the generator never names a room in code.

enum Kind {
	## Where the player starts. Exactly one, always first.
	SPAWN,
	## Everything in between.
	NORMAL,
	## Where the player leaves. Exactly one, always last.
	EXIT,
}

@export var display_name: String = "Unnamed Room"

## The scene instanced when this room is placed.
@export var scene: PackedScene = null

@export var kind: Kind = Kind.NORMAL

## Footprint in tiles, used to place the next room end to end.
@export var size_tiles: Vector2i = Vector2i(24, 14)
