extends Node

## Single source of truth for the game's spatial scale.
##
## Every gameplay distance, size, offset and speed in this project is
## expressed in TILES and converted here. Nothing outside this file may
## contain a raw pixel literal.
##
## That rule exists for one reason: the prototype starts at 384x216
## placeholder art, but the intended destination is Dead Cells-scale
## detail. When that move happens, TILE_SIZE and the viewport size in
## project.godot are the only values that change — not every speed,
## hitbox and jump height scattered across the codebase.

## Pixels per tile. Raise this together with the viewport size to move
## toward higher-resolution art.
const TILE_SIZE: int = 16

## Base viewport, mirrored from project.godot. Integer-scales x5 to 1080p.
const BASE_WIDTH: int = 384
const BASE_HEIGHT: int = 216

## Downward acceleration in tiles/second^2.
##
## A property of the world, not of the player: enemies fall by it too, and
## so will any projectile or dropped item. It lives here so there is one
## gravity in the game rather than one per falling thing.
const GRAVITY_TILES: float = 56.0


## Converts a distance in tiles to pixels.
static func tiles(n: float) -> float:
	return n * float(TILE_SIZE)


## Converts a tile-space pair to a pixel-space Vector2.
static func tiles_v(x: float, y: float) -> Vector2:
	return Vector2(tiles(x), tiles(y))
