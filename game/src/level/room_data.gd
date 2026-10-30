class_name RoomData
extends Resource
## One room chunk. The scene holds the geometry; this resource says what it is for.
## Rooms are authored at the base tile size, laid left to right by LevelGenerator.

## BOSS rooms are only used on a world's last level (see GeneratedLevel); the generator never picks them otherwise.
enum Kind { SPAWN, NORMAL, EXIT, BOSS }

@export var scene: PackedScene
@export var kind: Kind = Kind.NORMAL
@export var size_tiles: Vector2i = Vector2i(24, 14)
