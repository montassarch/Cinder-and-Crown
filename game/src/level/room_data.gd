class_name RoomData
extends Resource
## One room chunk. The scene holds the geometry; this resource says what it is for.
## Rooms are authored at the base tile size, laid left to right by LevelGenerator.

enum Kind { SPAWN, NORMAL, EXIT }

@export var scene: PackedScene
@export var kind: Kind = Kind.NORMAL
@export var size_tiles: Vector2i = Vector2i(24, 14)
