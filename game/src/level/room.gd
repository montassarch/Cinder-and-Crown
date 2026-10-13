extends Node2D

## One room chunk's geometry, built from tile space.
##
## Shared by every room scene. The floor and walls are derived from
## `width_tiles` rather than authored as pixels, for the same reason the
## sandbox is: pixel-baked geometry does not survive a TILE_SIZE change,
## and the whole point of expressing gameplay in tiles is that the move to
## higher-resolution art stays a config change.

## Room footprint in tiles. Must match the width in this room's RoomData,
## or rooms will overlap or leave a gap when laid end to end.
@export var width_tiles: float = 24.0

## Kept in step with Sandbox so a generated level and the test room have
## the same floor height and thickness.
const FLOOR_TOP_TILES: float = 11.0
const FLOOR_THICKNESS_TILES: float = 2.0

const FLOOR_COLOUR := Color(0.18, 0.16, 0.2)

@onready var _solid: StaticBody2D = %Solid
@onready var _visuals: Node2D = %Visuals


func _ready() -> void:
	WorldBuilder.add_solid(
		_solid, _visuals,
		Rect2(0.0, FLOOR_TOP_TILES, width_tiles, FLOOR_THICKNESS_TILES),
		FLOOR_COLOUR
	)
	_place_markers()


## Markers are authored as children but positioned here, so a room's spawn
## and exit land correctly whatever TILE_SIZE is.
func _place_markers() -> void:
	var spawn := get_node_or_null("SpawnPoint") as Marker2D
	if spawn != null:
		spawn.position = GameConfig.tiles_v(2.0, FLOOR_TOP_TILES - 1.0)

	var exit_marker := get_node_or_null("ExitPoint") as Marker2D
	if exit_marker != null:
		exit_marker.position = GameConfig.tiles_v(
			width_tiles - 2.0, FLOOR_TOP_TILES - 1.0
		)

	var spawns := get_node_or_null("EnemySpawns")
	if spawns == null:
		return
	var slots := spawns.get_child_count()
	for i: int in range(slots):
		var marker := spawns.get_child(i) as Marker2D
		if marker == null:
			continue
		# Spread evenly across the room, inset from both edges.
		var fraction := float(i + 1) / float(slots + 1)
		marker.position = GameConfig.tiles_v(
			width_tiles * fraction, FLOOR_TOP_TILES - 1.0
		)
